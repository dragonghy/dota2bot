-- [ratchet] [smokescan] [strategy 2026-09-19] THE GATE ON THE ALLY SCAN IS AN
-- `OR` WHERE THE SENTENCE IT STANDS FOR IS AN `AND`.
--
-- X.ConsiderItemDesire['item_smoke_of_deceit'] in
-- bots/ability_item_usage_generic.lua:
--
--   local nInRangeAlly   = J.GetAllyList(bot, 1200)
--   local nInRangeEnemy  = J.GetNearbyHeroes(bot, 1200, true, BOT_MODE_NONE)
--   local nInRangeTower  = bot:GetNearbyTowers(1200, true)
--   if (nInRangeEnemy ~= nil and #nInRangeEnemy == 0)
--   or (nInRangeTower ~= nil and #nInRangeTower == 0) then      -- <= THIS
--       for _, allyHero in pairs(nInRangeAlly) do ...
--           isThereEnemyNearby = true                           -- only writer
--   end
--   if not isThereEnemyNearby then ... BOT_ACTION_DESIRE_HIGH ... end
--
-- Read aloud the gate says "my own ring is clean, so let me go ask my allies".
-- "Clean" is `#enemy == 0 AND #tower == 0`. An OR of two `== 0` tests is FALSE
-- exactly when BOTH lists are non-empty -- an enemy hero AND an enemy tower
-- within 1200 of the caster, the most dangerous configuration this function can
-- be asked about. There the scan never runs and the flag keeps the `false` it
-- was born with.
--
-- ⛔ SKIPPING A MONOTONE LOOP IS NOT AN OPTIMISATION, IT IS AN ANSWER. The loop
-- body's only statement about the flag is `isThereEnemyNearby = true`, so it can
-- only ever move the answer one way. Not running it does not save work on a
-- question already settled -- it settles the question as FALSE, in the direction
-- that casts smoke.
--
-- READ THE HEADER OF J.ShouldScanAlliesForSmokeBreaker (bots/FunLib/jmz_func.lua)
-- FIRST: the closed-form direction proof, the uncertifiable half, and -- stated
-- there rather than left to be rediscovered -- that 'smokeself' SUBSUMES this
-- lever's whole domain, so the two must never be armed in the same wave. This
-- file drives all of it on real frames; §7 asserts the subsumption rather than
-- trusting the algebra.
--
-- ⛔ THE CORPUS WALK IS NOT IN THIS FILE. It is tests/_smokescan_sweep.lua, run
-- by hand (1039 loads is minutes; tools/agent/lua_gate.py kills an unmeasured
-- new test at hook_timeout_seconds = 20.0, mid-`ss.arm`, which leaves the global
-- switch on disk and breaks every OTHER gate test's "gate off" precondition).
-- Readings 2026-09-19, 112 fixtures / 1039 live subject frames, ring = the
-- shipped 1200:
--
--   gate TRUE  (the scan runs)                       1007
--   gate FALSE (both lists non-empty; scan skipped)    32   <= the whole domain
--   of those 32, the skipped scan would have found a dirty ally:
--   FLIP (shipped flag false, armed flag true)         20   over 10 fixtures
--     nearest breaker  > 1025:   1   <= the only number this lever claims
--     nearest breaker <= 1025:  19   <= UNCERTIFIABLE, neither zero nor full
--   flips outside 'smokeself''s domain                  0   (by construction)
--
-- ⭐ THE 32 IS A CROSS-CHECK, NOT A COINCIDENCE: it is case (A) of
-- tests/_smokeself_sweep.lua to the unit, measured by a second walk written
-- against the gate rather than against the seed.
--
-- ⚠️ WHY THE CLAIMABLE HALF IS ONE FRAME AND NOT THIRTY-THREE. The real item
-- cannot be USED with an enemy hero or tower inside 1025, and whether the
-- engine's IsFullyCastable() (which J.CanCastAbility calls before the desire
-- function is ever reached) models that is not answerable from this container
-- (no bot-side debugging; AGENTS.md). 'smokeself' could claim every flip whose
-- nearest breaker sat beyond 1025. THIS lever's domain already requires one of
-- EACH inside 1200, so a frame that is legal whatever the engine does needs BOTH
-- breakers in the shell (1025, 1200] -- a thin shell, and the corpus holds
-- exactly one frame in it. ⛔ One is what the lever is claimed on; the other
-- nineteen are registered UNCERTIFIABLE, which is neither zero nor full.
--
-- ⛔ WHAT NO ASSERTION BELOW CLAIMS. Nothing here drives the item desire end to
-- end, and on this corpus nothing could: tests/test_itemdesire_world_assertion.lua
-- measures `slot_castable == 0` on every alive frame and X.ItemUsageThink taking
-- ZERO actions on all 928 drivable frames. An end-to-end smoke witness is
-- STRUCTURALLY unavailable here, not rare, and is not claimed. What IS driven is
-- the gate, on real frames, plus the direction as arithmetic in §6.
--
-- ⛔ WHY [ratchet]-TAGGED AND NOT IN tools/agent/lua_gate_manifest.json: same
-- arithmetic as tests/test_smokeself_caster_ring.lua (GH #901 -- the 2x fallback
-- leaves ~2.1s for the whole repo). 开工自检's fast Lua leg reads tagged files.
-- ⛔ That is a weaker guarantee and is not dressed up as the same one: the push
-- hook does not run this file unless it has budget left, so a red here can be
-- found by the next desk rather than by the author (GH #624/#884).

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')
local ss = require('mock.soak_side')

ss.assert_clean('test_smokescan_ally_scan_gate load time')

local tests = {}
local R = 1200   -- the shipped radius at the call site, mirrored exactly

-- THE CLAIM. Jakiro, dire, t=391.5: enemy hero and enemy tower both inside 1200
-- and the NEAREST of them is 1128u away -- beyond the 1025 at which a smoke is
-- dispelled, so the cast is legal whatever IsFullyCastable() does. The gate is
-- false, the scan never runs, and his one ally inside 1200 reads dirty.
local W_FAR = { 'tests/fixtures/f_260820_102645_cm_es_reach.lua',
                'npc_dota_hero_jakiro', 'dire' }
-- THE UNCERTIFIABLE HALF, one of nineteen. Lich, dire, t=631.5: two enemy
-- heroes and an enemy tower inside 1200, nearest 396u -- inside 1025, so the
-- engine may already refuse the cast and this frame's value depends on the
-- question this container cannot answer.
local W_NEAR = { 'tests/fixtures/f_260819_222559_od_eclipse_pair.lua',
                 'npc_dota_hero_lich', 'dire' }
-- ⭐ THE SEPARATING CONTROL, and it is the same shape AND the same shell as the
-- claim. Dragon Knight, dire, t=309.4: enemy hero and enemy tower both inside
-- 1200 (gate false), nearest 1099u (the same (1025,1200] shell as W_FAR), one
-- ally inside 1200 -- and that ally's own ring is CLEAN. So arming runs the scan
-- and the scan answers nothing: the flag lands on the same false. This is what
-- separates "the gate let the scan run" from "the scan found something", and a
-- mutant that seeds the flag true instead of running the scan dies here.
local W_CLEANALLY = { 'tests/fixtures/f_260819_183613_storm_collapse_outnumbered.lua',
                      'npc_dota_hero_dragon_knight', 'dire' }
-- CONTROL, the other side of the gate. Juggernaut, radiant, t=201.3: nothing of
-- either kind inside 1200, so the shipped gate is already TRUE and arming cannot
-- move it. 1007 of 1039 live frames are this case.
local W_OPEN = { 'tests/fixtures/f_260819_122930_lich_rescue_doomed.lua',
                 'npc_dota_hero_juggernaut', 'radiant' }
-- ⭐ THE TWO HALF-OPEN WITNESSES, and they exist for the DISARMED leg. W_OPEN
-- has both lists empty, so it cannot tell an `or` from an `and` (both answer
-- true) nor a two-term expression from a one-term one. These two have exactly
-- ONE list empty, so the shipped `or` answers TRUE while both an `and` and
-- either term alone answer FALSE on one of them. Without this pair, "disarmed is
-- the shipped expression term for term" is a claim only the source text carries.
--   Lion, radiant, t=235.0: an enemy hero inside 1200, no enemy tower.
local W_HALF_HERO = { 'tests/fixtures/f_20260909_212625_lion_235.lua',
                      'npc_dota_hero_lion', 'radiant' }
--   Zeus, radiant, t=278.5: an enemy tower inside 1200, no enemy hero.
local W_HALF_TOWER = { 'tests/fixtures/f_260819_142047_zuus_ult_denied.lua',
                       'npc_dota_hero_zuus', 'radiant' }

local function turbo()
    GAMEMODE_TURBO = 23                    -- luacheck: ignore
    GetGameMode = function() return 23 end -- luacheck: ignore
end

local function unprobe()
    GAMEMODE_TURBO = nil                               -- luacheck: ignore
    GetGameMode = function() return GAMEMODE_TURBO end -- luacheck: ignore
end

--- ⛔ NOT-TURBO IS A MODE, NOT THE ABSENCE OF A PROBE. With GAMEMODE_TURBO nil
--- J.IsModeTurbo skips the authoritative branch and falls through to the
--- courier-speed heuristic, which on a .dem slice can answer either way -- so a
--- "must be inert outside turbo" leg written with unprobe() tests the fallback,
--- not the scope (0NEXT49, learned the hard way one round ago).
local function normal_mode()
    GAMEMODE_TURBO = 23                   -- luacheck: ignore
    GetGameMode = function() return 1 end -- luacheck: ignore
end

--- ONE real load. ⛔ Never reuse a load to read the other game mode:
--- J.IsModeTurbo memoises into a module-level cache on its FIRST call.
local function load(w)
    unprobe()
    local J, bot = rf.load(w[1], w[2])
    turbo()
    return J, bot
end

--- The caster's own two readings, from the same producers the call site uses.
local function self_rings(J, bot)
    return J.GetNearbyHeroes(bot, R, true, BOT_MODE_NONE) or {},
           bot:GetNearbyTowers(R, true) or {}
end

--- The SHIPPED gate, rebuilt term for term, so "the shipped answer" in every
--- assertion below is produced by the shipped shape and not by a remembered
--- number.
local function shipped_gate(tE, tT)
    return (tE ~= nil and #tE == 0)
        or (tT ~= nil and #tT == 0)
end

--- What the guarded loop would answer if it ran: the ONLY thing the gate can
--- suppress.
local function dirty_ally(J, bot)
    for _, hAlly in pairs(J.GetAllyList(bot, R) or {}) do
        if J.IsValidHero(hAlly) then
            local aE = J.GetNearbyHeroes(hAlly, R, true, BOT_MODE_NONE) or {}
            local aT = hAlly:GetNearbyTowers(R, true) or {}
            if #aE >= 1 or #aT >= 1 then return true end
        end
    end
    return false
end

--- The FINAL flag the desire hangs off, for a given gate answer. The seed is the
--- shipped `false` (this file measures the GATE with 'smokeself' unarmed, which
--- is also the only configuration in which this lever can be attributed).
local function flag_for(J, bot, bGate)
    if not bGate then return false end
    return dirty_ally(J, bot)
end

--- Nearest breaker of either kind, the quantity the 1025 rule is about.
local function nearest_breaker(bot, tE, tT)
    local n = nil
    for _, h in pairs(tE) do
        local d = GetUnitToUnitDistance(bot, h)
        if n == nil or d < n then n = d end
    end
    for _, h in pairs(tT) do
        local d = GetUnitToUnitDistance(bot, h)
        if n == nil or d < n then n = d end
    end
    return n
end

-- ============================================== 1. the source, pinned

local function slurp(path)
    local fh = assert(io.open(path, 'r'))
    local s = fh:read('*a'); fh:close()
    return s
end

--- Comments stripped: a claim about what the CODE does must not be satisfiable
--- by the prose describing it (both headers quote every one of these tokens).
local function code_of(path)
    return (slurp(path):gsub('%-%-[^\n]*', ''))
end

local function helper_code()
    local s = code_of('bots/FunLib/jmz_func.lua')
    local at = assert(s:find('function J.ShouldScanAlliesForSmokeBreaker', 1, true),
        'J.ShouldScanAlliesForSmokeBreaker is gone from jmz_func.lua')
    local fin = assert(s:find('\nend\n', at, true))
    return s:sub(at, fin)
end

local function smoke_site_code()
    local s = code_of('bots/ability_item_usage_generic.lua')
    local at = assert(s:find("ConsiderItemDesire%['item_smoke_of_deceit'%]"),
        'the smoke-of-deceit desire is gone from ability_item_usage_generic.lua')
    local fin = assert(s:find('\nend\n', at, true))
    return s:sub(at, fin)
end

tests['[smokescan] the ally scan is guarded by the helper, and the shipped OR is '
    .. 'gone from the call site'] = function()
    local site = smoke_site_code()
    -- ⭐ THE SEMANTIC NAIL, FIRST: the scan's guard is the helper, handed the
    -- caster's own two lists. Putting it first matters -- a mutant that only
    -- breaks the wiring must not be scored by a counting assertion that happens
    -- to fire earlier (0NEXT47/0NEXT48).
    assert(site:find('if%s+J%.ShouldScanAlliesForSmokeBreaker%s*%('
        .. '%s*nInRangeEnemy%s*,%s*nInRangeTower%s*%)'),
        'the ally scan is no longer guarded by J.ShouldScanAlliesForSmokeBreaker '
        .. 'reading the caster\'s own two lists -- this lever is exactly that guard')
    assert(not site:find('#nInRangeEnemy%s*==%s*0'),
        'the shipped `#nInRangeEnemy == 0` gate came back at the call site; the '
        .. 'backwards OR is live again')
    -- ⛔ ONE ring, named once, read by the caster's lists AND the ally scan.
    local _, nLit = site:gsub('1200', '')
    assert(nLit == 1, 'expected the 1200 to appear exactly once (the `local '
        .. 'nRadius = 1200`); found ' .. nLit .. ' -- a second copy is a ring '
        .. 'that can drift, which is what roamring/tormring cost')
    -- The scan body is untouched: still exactly one write, still `= true`.
    local _, nWrite = site:gsub('isThereEnemyNearby%s*=%s*true', '')
    assert(nWrite == 1, 'expected exactly one ally-scan write of '
        .. 'isThereEnemyNearby; found ' .. nWrite)
    -- ⭐ THE MONOTONICITY THE DIRECTION PROOF RESTS ON, pinned as source rather
    -- than argued: the flag is never assigned `false` anywhere below its seed,
    -- so running the scan more often can only ever ADD a `true`.
    assert(not site:find('isThereEnemyNearby%s*=%s*false'),
        'something now writes `false` into the flag below its seed -- running '
        .. 'the scan more often is no longer monotone and the direction proof '
        .. 'in the helper header no longer holds')
    -- ⭐ And the flag's only reader is still the negated one, under which every
    -- return is a smoke cast: that is why "scan more" means "smoke less".
    local _, nRead = site:gsub('if%s+not%s+isThereEnemyNearby', '')
    assert(nRead == 1, 'expected exactly one `if not isThereEnemyNearby` reader; '
        .. 'found ' .. nRead)
end

tests['[smokescan] the repair is gated, turbo-scoped, and fails to the shipped '
    .. 'expression'] = function()
    local code = helper_code()
    assert(code:find("IsSoakCandidate%(%s*'smokescan'%s*%)"),
        "the 'smokescan' gate is gone from J.ShouldScanAlliesForSmokeBreaker")
    assert(code:find('IsModeTurbo', 1, true),
        'the turbo scope disappeared -- this must be inert outside turbo')
    -- ⛔ The disarmed leg must be the shipped expression, term for term --
    -- including both nil guards, which are what make an engine list that came
    -- back nil read as "not clean" exactly as it shipped.
    assert(code:find('tEnemyHeroes%s*~=%s*nil%s+and%s+#tEnemyHeroes%s*==%s*0'),
        'the disarmed leg no longer carries the shipped enemy-list term')
    assert(code:find('tEnemyTowers%s*~=%s*nil%s+and%s+#tEnemyTowers%s*==%s*0'),
        'the disarmed leg no longer carries the shipped tower-list term')
    -- ⛔ Not a conjunction: no OTHER candidate id may appear inside it
    -- ('pullcad', GH #606/#576) -- and in particular NOT 'smokeself', whose
    -- domain contains this one's (§7).
    local _, nIds = code:gsub("IsSoakCandidate%(%s*'[%w_]+'%s*%)", '')
    assert(nIds == 1, 'J.ShouldScanAlliesForSmokeBreaker now names ' .. nIds
        .. ' soak ids -- a gate inside a gate is the conjunction of two levers')
end

-- ============================================== 2. the claim: the far shell

tests['[smokescan] the one frame whose cast is legal whatever IsFullyCastable '
    .. 'does'] = function()
    local J, bot = load(W_FAR)
    local tE, tT = self_rings(J, bot)
    assert(#tE >= 1 and #tT >= 1,
        'the claim witness no longer has BOTH an enemy hero and an enemy tower '
        .. 'inside ' .. R .. ' (read e=' .. #tE .. ' tw=' .. #tT .. ')')
    assert(shipped_gate(tE, tT) == false,
        'the shipped gate no longer skips the scan on the claim frame')
    assert(J.ShouldScanAlliesForSmokeBreaker(tE, tT) == false,
        'the helper answers armed while the gate is OFF')
    -- ⭐ THE SHELL, which is what makes this frame the claim and the other
    -- nineteen uncertifiable.
    local d = nearest_breaker(bot, tE, tT)
    assert(d ~= nil and d > 1025,
        'the claim witness left the (1025, 1200] shell (nearest=' ..
        tostring(d and math.floor(d)) .. ') -- the cast is no longer legal '
        .. 'whatever the engine does, and this file would be claiming the '
        .. 'uncertifiable half')
    -- The suppressed scan is the one that would have caught it.
    assert(dirty_ally(J, bot),
        'the claim witness lost its dirty ally; the skipped scan would have '
        .. 'answered false too and this is no longer a flip')
    assert(flag_for(J, bot, shipped_gate(tE, tT)) == false,
        'the shipped flag is true here; the claim frame is not a flip')
    unprobe()

    local J2, bot2 = load(W_FAR)
    ss.with_candidate('smokescan', function()
        local e2, t2 = self_rings(J2, bot2)
        local bArmed = J2.ShouldScanAlliesForSmokeBreaker(e2, t2)
        assert(bArmed == true,
            'armed, the scan is STILL skipped on the frame this lever is '
            .. 'claimed on')
        assert(flag_for(J2, bot2, bArmed) == true,
            'armed, the scan runs and still answers "nobody can see us" -- the '
            .. 'flip is gone')
    end, W_FAR[3])
    unprobe()
end

-- ============================================== 3. the uncertifiable half

tests['[smokescan] the same flip inside 1025, registered as uncertifiable and '
    .. 'not as value'] = function()
    local J, bot = load(W_NEAR)
    local tE, tT = self_rings(J, bot)
    assert(#tE >= 2 and #tT >= 1,
        'the near witness changed shape (read e=' .. #tE .. ' tw=' .. #tT .. ')')
    local d = nearest_breaker(bot, tE, tT)
    assert(d ~= nil and d <= 1025,
        'the near witness left the inside-1025 band (nearest=' ..
        tostring(d and math.floor(d)) .. '); it no longer stands for the '
        .. 'uncertifiable nineteen')
    assert(shipped_gate(tE, tT) == false and dirty_ally(J, bot),
        'the near witness is no longer a flip')
    unprobe()

    local J2, bot2 = load(W_NEAR)
    ss.with_candidate('smokescan', function()
        local e2, t2 = self_rings(J2, bot2)
        -- ⛔ The PREDICATE flips here exactly as it does on the claim frame.
        -- What is uncertifiable is whether the engine ever reaches this desire
        -- function with a breaker 396u away -- not whether the lever moved.
        assert(J2.ShouldScanAlliesForSmokeBreaker(e2, t2) == true,
            'armed, the scan is still skipped on the near witness')
        assert(flag_for(J2, bot2, true) == true,
            'armed, the scan runs and answers clear on the near witness')
    end, W_NEAR[3])
    unprobe()
end

-- ============================================== 4. the separating control

tests['[control] same shape, same shell, clean ally: arming runs the scan and '
    .. 'the scan answers nothing'] = function()
    local J, bot = load(W_CLEANALLY)
    local tE, tT = self_rings(J, bot)
    assert(#tE >= 1 and #tT >= 1 and shipped_gate(tE, tT) == false,
        'the separating control no longer has the gate-false shape (read e='
        .. #tE .. ' tw=' .. #tT .. ')')
    local d = nearest_breaker(bot, tE, tT)
    assert(d ~= nil and d > 1025,
        'the separating control left the (1025, 1200] shell -- it no longer '
        .. 'controls the claim frame at the same distance band')
    assert(#(J.GetAllyList(bot, R) or {}) >= 1,
        'the separating control lost its ally; the next assertion is vacuous')
    assert(dirty_ally(J, bot) == false,
        'the separating control\'s ally is dirty now -- it has become a flip '
        .. 'and separates nothing')
    unprobe()

    local J2, bot2 = load(W_CLEANALLY)
    ss.with_candidate('smokescan', function()
        local e2, t2 = self_rings(J2, bot2)
        assert(J2.ShouldScanAlliesForSmokeBreaker(e2, t2) == true,
            'armed, the helper does not open the gate on a gate-false frame')
        -- ⭐ THE POINT: the gate opened, the scan ran, and the ANSWER did not
        -- move. A mutant that sets the flag true instead of letting the scan
        -- decide passes §2 and dies right here.
        assert(flag_for(J2, bot2, true) == false,
            'armed, the flag became true on a frame whose ally census is clean '
            .. '-- this lever is supposed to RUN the scan, not to answer for it')
    end, W_CLEANALLY[3])
    unprobe()
end

tests['[control] where the shipped gate is already open, arming moves '
    .. 'nothing'] = function()
    local J, bot = load(W_OPEN)
    local tE, tT = self_rings(J, bot)
    assert(#tE == 0 and #tT == 0,
        'the open-gate control grew something inside ' .. R .. ' -- it no longer '
        .. 'controls for anything')
    assert(shipped_gate(tE, tT) == true,
        'the open-gate control no longer passes the shipped gate')
    assert(J.ShouldScanAlliesForSmokeBreaker(tE, tT) == true,
        'disarmed, the helper closed a gate the shipped expression opens')
    unprobe()

    local J2, bot2 = load(W_OPEN)
    ss.with_candidate('smokescan', function()
        local e2, t2 = self_rings(J2, bot2)
        assert(J2.ShouldScanAlliesForSmokeBreaker(e2, t2) == true,
            'armed, the helper disagrees with itself on an already-open gate')
    end, W_OPEN[3])
    unprobe()
end

-- ============================================== 5. direction, exhausted

tests['[smokescan] direction: armed can only withhold a smoke, never add '
    .. 'one'] = function()
    local J, bot = load(W_OPEN)
    local nFlip = 0
    ss.with_candidate('smokescan', function()
        for _, nE in ipairs({ 0, 1, 2 }) do
            for _, nT in ipairs({ 0, 1, 2 }) do
                local tE, tT = {}, {}
                for i = 1, nE do tE[i] = true end
                for i = 1, nT do tT[i] = true end
                local bArmed   = J.ShouldScanAlliesForSmokeBreaker(tE, tT)
                local bShipped = shipped_gate(tE, tT)
                -- ⭐ THE DIRECTION FIRST, as arithmetic: armed's scan set is a
                -- SUPERSET of shipped's. The suppressed body only ever writes
                -- `true`, and the flag's only reader casts smoke when it is
                -- false, so a superset of scans is a subset of smokes.
                -- ⛔ It is FIRST on purpose: a mutant that reverses the
                -- direction must die at the assertion that NAMES the direction,
                -- not at a weaker one that happens to run earlier
                -- (evidence-discipline 2; 0NEXT47/0NEXT48).
                assert(not (bShipped == true and bArmed == false),
                    'armed closed a gate the shipped expression opened at e='
                    .. nE .. ' tw=' .. nT .. ' -- that direction would ADD smokes')
                assert(bArmed == true,
                    'armed answer is not the unconditional scan at e=' .. nE
                    .. ' tw=' .. nT)
                if bArmed ~= bShipped then nFlip = nFlip + 1 end
            end
        end
    end, W_OPEN[3])
    unprobe()
    -- ⛔ A grid that flips nothing proves nothing -- it would pass against a
    -- helper that returned the shipped expression always. Four of the nine
    -- cells have both lists non-empty; those are the flips.
    assert(nFlip == 4, 'the grid flipped ' .. nFlip .. ' of 9 cells; expected '
        .. 'the 4 with BOTH lists non-empty')
    -- nil-tolerance: the call site can only hand over engine lists, but a nil
    -- must not become a crash in a shipped item-desire path, and disarmed it
    -- must answer exactly what the shipped `~= nil` guards answered: false.
    -- ⛔ ONE ARMING CONTEXT PER LOAD. J.IsSoakCandidate caches the switch into
    -- the module instance on its first read, so a handle first driven disarmed
    -- answers disarmed for the rest of its life -- which presents as "the gate
    -- did not fire", the direction a gate harness must never fail in
    -- (tests/mock/soak_side.lua's own note). Two loads, not one.
    local J2, bot2 = load(W_OPEN)
    assert(bot2 ~= nil, 'the nil-tolerance load came back without a bot')
    assert(J2.ShouldScanAlliesForSmokeBreaker(nil, nil) == false,
        'disarmed, nil lists no longer read as the shipped `false`')
    unprobe()

    local J3, bot3 = load(W_OPEN)
    assert(bot3 ~= nil, 'the armed nil-tolerance load came back without a bot')
    ss.with_candidate('smokescan', function()
        assert(J3.ShouldScanAlliesForSmokeBreaker(nil, nil) == true,
            'armed, nil lists must still open the gate, not error')
    end, W_OPEN[3])
    unprobe()
end

-- ============================================== 6. disarmed / wrong side / mode

tests['[smokescan] disarmed, wrong-sided and outside turbo it is the literal '
    .. 'shipped expression'] = function()
    local J, bot = load(W_FAR)
    local tE, tT = self_rings(J, bot)
    assert(#tE >= 1 and #tT >= 1, 'the claim witness lost its shape')
    assert(J.ShouldScanAlliesForSmokeBreaker(tE, tT) == false,
        'with no candidate armed the helper is not the shipped expression')
    unprobe()

    -- armed, but on the OTHER side: same frame, same lists, must stay shipped
    local J2, bot2 = load(W_FAR)
    local sOther = (W_FAR[3] == 'dire') and 'radiant' or 'dire'
    ss.with_candidate('smokescan', function()
        local e2, t2 = self_rings(J2, bot2)
        assert(J2.ShouldScanAlliesForSmokeBreaker(e2, t2) == false,
            'the helper fires for the side the wave did not arm')
    end, sOther)
    unprobe()

    -- armed, right side, but the engine says a DIFFERENT game mode. ⛔ Not
    -- unprobe(): see normal_mode()'s note.
    local J3, bot3 = rf.load(W_FAR[1], W_FAR[2])
    normal_mode()
    ss.with_candidate('smokescan', function()
        local e3, t3 = self_rings(J3, bot3)
        assert(J3.ShouldScanAlliesForSmokeBreaker(e3, t3) == false,
            'the helper fires outside turbo -- the scope is gone')
    end, W_FAR[3])
    unprobe()
end

-- ============================================== 6b. the disarmed leg, driven

tests['[smokescan] disarmed, a HALF-open ring still reads the shipped `or` and '
    .. 'not an `and`'] = function()
    -- ⭐ These two frames are the only ones in this file that can tell the
    -- shipped disjunction from a conjunction, or from either term standing
    -- alone: each has exactly one of the two lists empty.
    local J, bot = load(W_HALF_HERO)
    local tE, tT = self_rings(J, bot)
    assert(#tE >= 1 and #tT == 0,
        'the hero-half witness changed shape (read e=' .. #tE .. ' tw=' .. #tT
        .. ') -- it no longer separates `or` from `and`')
    assert(shipped_gate(tE, tT) == true, 'the shipped gate is false here')
    assert(J.ShouldScanAlliesForSmokeBreaker(tE, tT) == true,
        'disarmed with an enemy hero in the ring and no tower, the helper '
        .. 'closed a gate the shipped `or` opens -- the disarmed leg is not the '
        .. 'shipped expression')
    unprobe()

    local J2, bot2 = load(W_HALF_TOWER)
    local e2, t2 = self_rings(J2, bot2)
    assert(#e2 == 0 and #t2 >= 1,
        'the tower-half witness changed shape (read e=' .. #e2 .. ' tw=' .. #t2
        .. ')')
    assert(shipped_gate(e2, t2) == true, 'the shipped gate is false here')
    assert(J2.ShouldScanAlliesForSmokeBreaker(e2, t2) == true,
        'disarmed with an enemy tower in the ring and no hero, the helper '
        .. 'closed a gate the shipped `or` opens -- the enemy-list term is '
        .. 'carrying the whole disarmed answer')
    unprobe()
end

-- ============================================== 7. the subsumption, asserted

tests['[smokescan] every frame this lever can move is inside smokeself\'s '
    .. 'domain, and the two gates are disjoint'] = function()
    -- ⭐ ALGEBRA, DRIVEN RATHER THAN TRUSTED. This lever's domain is "both lists
    -- non-empty"; 'smokeself' answers true on "either list non-empty". both ⊂
    -- either, so with 'smokeself' armed the flag is ALREADY true everywhere
    -- this lever could change it and a wave arming both cannot attribute
    -- anything to this one. The sweep prints the same containment over the
    -- corpus as `flip_outside_smokeself 0`; this drives it exhaustively.
    local J, bot = load(W_OPEN)
    ss.with_candidate('smokescan', function()
        for _, nE in ipairs({ 0, 1, 2 }) do
            for _, nT in ipairs({ 0, 1, 2 }) do
                local tE, tT = {}, {}
                for i = 1, nE do tE[i] = true end
                for i = 1, nT do tT[i] = true end
                local bMoves = (shipped_gate(tE, tT) == false)
                if bMoves then
                    assert(nE > 0 and nT > 0,
                        'a cell this lever moves is not both-non-empty')
                    -- 'smokeself' reads true on either non-empty: it covers it.
                    assert(nE > 0 or nT > 0,
                        'a cell this lever moves sits OUTSIDE smokeself\'s '
                        .. 'domain -- the subsumption registered in both headers '
                        .. 'is wrong and the waves must be re-planned')
                end
            end
        end
    end, W_OPEN[3])
    unprobe()
    -- ⛔ DISJOINT GATES, not a conjunction: neither helper may name the other's
    -- id, or promoting either freezes the other FALSE ('pullcad').
    local mine = helper_code()
    assert(not mine:find("'smokeself'", 1, true),
        "J.ShouldScanAlliesForSmokeBreaker names 'smokeself' -- that is the "
        .. 'pullcad trap, and it would also make this lever unattributable')
    local s = code_of('bots/FunLib/jmz_func.lua')
    local at = assert(s:find('function J.IsSmokeBreakerNearSelf', 1, true))
    local fin = assert(s:find('\nend\n', at, true))
    assert(not s:sub(at, fin):find("'smokescan'", 1, true),
        "J.IsSmokeBreakerNearSelf names 'smokescan' -- same trap, other side")
end

return tests

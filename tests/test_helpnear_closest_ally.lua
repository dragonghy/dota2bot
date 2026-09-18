-- [helpnear] J.GetClosestAlly returns the FIRST eligible ally in team-ROSTER
-- order, not the nearest one. Its only production consumer is ConsiderHelpAlly
-- (mode_team_roam_generic.lua:500), which calls the answer `nClosestAlly` and
-- then anchors its HP guard, its range guard, its parity point and the enemy
-- it commits to on that one pick.
--
-- READ THE HEADER OF J.GetClosestAlly FIRST (bots/FunLib/jmz_func.lua): the
-- defect, what is NOT being claimed, and the domain readings live there. This
-- file is what drives them on real frames.
--
-- ⛔ WHY THE CORPUS WALK IS NOT IN THIS FILE. It is in tests/_helpnear_sweep.lua
-- and is run BY HAND: 1039 loads is minutes, and tools/agent/lua_gate.py kills
-- an unmeasured new test at hook_timeout_seconds = 20.0 -- mid-`ss.arm`, which
-- leaves the global switch on disk and breaks every OTHER gate test's "gate
-- off" precondition. Same reason tests/_roamring_sweep.lua sits outside.
-- Numbers quoted below were taken by that sweep on 2026-09-18:
--
--   live 1039 | reached 679 | same hero 579 | differ 100 | fixtures 48 of 112
--   gap_max 3187u | hpguard_flip 21 | parity_flip 2 | cand_max 4
--
-- ⛔ THE DIRECTION COLUMN THAT IS MISSING IS MISSING ON PURPOSE. 'roamring' and
-- 'helpself' could each report `up 0` against a non-zero `down` because a
-- superset can only grow a count. This lever moves a PRODUCT -- which ally the
-- branch is about -- so it has no direction to report and none is claimed.
-- What is claimed is in section 4: the armed answer is always the distance
-- minimum over the SHIPPED loop's own eligibility test.
--
-- ⚠️ INSTRUMENT LIMIT, stated rather than left for a wave: ConsiderHelpAlly
-- sits behind a mode/activity chain built out of bot:GetActiveModeDesire() and
-- J.IsGoingOnSomeone, which is bot-VM state a .dem does not carry (GH #27), so
-- `differ 100` is a CEILING on how often the BRANCH changes, not a fire rate.
-- Every assertion below is about the PICK and the guard that reads it, both of
-- which are hero geometry and HP -- ground truth in the dump.

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')
local ss = require('mock.soak_side')

ss.assert_clean('test_helpnear_closest_ally load time')

local tests = {}

local HELP_RADIUS = 3500   -- ConsiderHelpAlly's own nRadius

-- Witness A (radiant). Bot = obsidian_destroyer, roster slot 3. The shipped
-- picker answers lina, in roster slot 1, at 3192u; phantom_assassin stands at
-- 252u in slot 4. The frame also flips the very next guard at the call site:
-- hp(bot) = 0.648 >= hp(lina) = 0.581 is TRUE (walk 3192u to "help" her),
-- while hp(pa) = 1.000 makes it FALSE (the ally actually next to us needs
-- nothing).
local W_A = { 'tests/fixtures/f_045650_lion_meatgrinder.lua',
              'npc_dota_hero_obsidian_destroyer', 'radiant',
              'npc_dota_hero_lina', 'npc_dota_hero_phantom_assassin' }
-- Witness B (dire), so the pick is exercised on both physical sides. Bot =
-- zuus; shipped answers bristleback at 2976u while earthshaker stands at 93u.
local W_B = { 'tests/fixtures/f_260820_103216_cm_es_aftershock.lua',
              'npc_dota_hero_zuus', 'dire',
              'npc_dota_hero_bristleback', 'npc_dota_hero_earthshaker' }
-- The control: FOUR eligible allies and the shipped pick already IS the
-- nearest, so arming must be a no-op -- and not because the picker had no
-- choice to get wrong.
local W_CTRL = { 'tests/fixtures/f_260819_222052_zuus_w2_leak.lua',
                 'npc_dota_hero_dragon_knight', 'radiant',
                 'npc_dota_hero_chaos_knight', 'npc_dota_hero_chaos_knight' }

local function turbo()
    GAMEMODE_TURBO = 23                    -- luacheck: ignore
    GetGameMode = function() return 23 end -- luacheck: ignore
end

local function unprobe()
    GAMEMODE_TURBO = nil                               -- luacheck: ignore
    GetGameMode = function() return GAMEMODE_TURBO end -- luacheck: ignore
end

--- ONE real load. ⛔ Never reuse a load to read the other game mode:
--- J.IsModeTurbo memoises into a module-level cache on its FIRST call, so a
--- second reading taken after flipping GetGameMode is the FIRST reading.
local function load(w)
    unprobe()
    local J, bot = rf.load(w[1], w[2])
    turbo()
    return J, bot
end

local function name(h)
    return h and h:GetUnitName() or 'nil'
end

--- The eligible set, rebuilt from the shipped loop's OWN four clauses. Used
--- only to state what the armed answer must be a minimum over.
local function eligible(J, bot)
    local t = {}
    for i = 1, #GetTeamPlayers(GetTeam()) do
        local m = GetTeamMember(i)
        if m ~= nil and m:IsAlive() and m ~= bot
            and GetUnitToUnitDistance(bot, m) <= HELP_RADIUS
            and not J.IsSuspiciousIllusion(m)
        then t[#t + 1] = m end
    end
    return t
end

-- ================================================ 1. the source, pinned

local function slurp(path)
    local fh = assert(io.open(path, 'r'))
    local s = fh:read('*a'); fh:close()
    return s
end

--- Comments stripped: a claim about what the CODE does must not be satisfiable
--- by the prose describing it (the header quotes every one of these tokens).
local function code_of(path)
    return (slurp(path):gsub('%-%-[^\n]*', ''))
end

local function helper_code()
    local s = code_of('bots/FunLib/jmz_func.lua')
    local at = assert(s:find('function J.GetClosestAlly(bot, nRadius)', 1, true),
        'J.GetClosestAlly is gone from jmz_func.lua')
    local fin = assert(s:find('\nend\n', at, true))
    return s:sub(at, fin)
end

tests['[helpnear] the repair is gated, turbo-scoped, and fails to the shipped '
    .. 'pick'] = function()
    local code = helper_code()
    assert(code:find("IsSoakCandidate%(%s*'helpnear'%s*%)"),
        "the 'helpnear' gate is gone from J.GetClosestAlly")
    assert(code:find('IsModeTurbo', 1, true),
        'the turbo scope disappeared -- this must be inert outside turbo')
    -- ⛔ The disarmed path must still be the early `return member`. A rewrite
    -- that computes the nearest and then picks between the two answers passes
    -- every behavioural assertion below and changes the shipped cost of a
    -- function called on the roam path every frame.
    assert(code:find('if not bNearest then return member end', 1, true),
        'the disarmed early return is gone -- disarmed must be the shipped '
        .. 'loop, not a second pass over a computed answer')
    -- The four eligibility clauses are the shipped loop's; none may be dropped
    -- or gained, armed or not.
    for _, clause in ipairs({ 'member:IsAlive()', 'member ~= bot',
                              'GetUnitToUnitDistance(bot, member) <= nRadius',
                              'J.IsSuspiciousIllusion(member)' }) do
        assert(code:find(clause, 1, true),
            'eligibility clause vanished from J.GetClosestAlly: ' .. clause)
    end
end

tests['[helpnear] one production consumer, and it is the help site'] = function()
    -- ⛔ The whole argument for gating inside the function is that it has
    -- exactly one caller. A second one makes this a bundle without anybody
    -- editing the helper.
    -- ⚠️ The pattern carries the `(` on purpose: `GetClosestAllyPos` in
    -- aba_defend.lua is a DIFFERENT function and a bare name match counts
    -- eight of its lines as call sites of this one.
    local p = assert(io.popen(
        "grep -rn 'J\\.GetClosestAlly(' bots/ "
        .. "| grep -v 'function J.GetClosestAlly'"))
    local sites = {}
    for line in p:lines() do
        if not line:match('^%s*bots/[%w_/]+%.lua:%d+:%s*%-%-') then
            sites[#sites + 1] = line
        end
    end
    p:close()
    assert(#sites == 1,
        'expected exactly one production call site for J.GetClosestAlly, '
        .. 'found ' .. #sites .. ': ' .. table.concat(sites, ' ;; '))
    assert(sites[1]:find('mode_team_roam_generic.lua', 1, true),
        'the single call site moved out of the roam mode: ' .. sites[1])
    -- ⛔ A SUBSTRING match is not enough, and the mutation stand proved it:
    -- `... = J.GetClosestAlly(bot, nRadius) or J.GetClosestCore(bot, nRadius)`
    -- contains the expected text, changes what the anchor is, and passed.
    -- The binding is pinned as the WHOLE statement instead.
    local sStmt = sites[1]:match('^[^:]+:%d+:%s*(.-)%s*$')
    assert(sStmt == 'local nClosestAlly = J.GetClosestAlly(bot, nRadius)',
        'the call site no longer binds the pick to nClosestAlly and nothing '
        .. 'else; it reads: ' .. tostring(sStmt))
end

-- ================================================ 2. the real frames, no stubs

local function pick_case(w)
    local J, bot = load(w)
    ss.assert_clean('helpnear shipped leg ' .. w[2])
    local hShipped = J.GetClosestAlly(bot, HELP_RADIUS)
    assert(name(hShipped) == w[4],
        w[2] .. ': the shipped picker no longer answers ' .. w[4]
        .. ' -- it answered ' .. name(hShipped))
    unprobe()

    local J2, bot2 = load(w)
    local hArmed
    ss.with_candidate('helpnear', function()
        hArmed = J2.GetClosestAlly(bot2, HELP_RADIUS)
    end, w[3])
    assert(name(hArmed) == w[5],
        w[2] .. ': armed, the picker must answer ' .. w[5] .. '; it answered '
        .. name(hArmed))
    unprobe()
end

tests['[helpnear] witness A (radiant): the anchor moves from 3192u to 252u'] =
function()
    pick_case(W_A)
    -- The witness is the DISTANCE, not the roster: state both so a fixture
    -- that quietly changes shape cannot keep this test green for free.
    local J, bot = load(W_A)
    local d = {}
    for _, m in ipairs(eligible(J, bot)) do
        d[m:GetUnitName()] = GetUnitToUnitDistance(bot, m)
    end
    assert(d['npc_dota_hero_lina'] ~= nil and d['npc_dota_hero_lina'] > 3000,
        'lina stopped being the far ally on this frame')
    assert(d['npc_dota_hero_phantom_assassin'] ~= nil
        and d['npc_dota_hero_phantom_assassin'] < 300,
        'phantom_assassin stopped being the near ally on this frame')
    unprobe()
end

tests['[helpnear] witness A: the guard on the very next line flips with the '
    .. 'anchor'] = function()
    -- `J.GetHP(bot) >= J.GetHP(nClosestAlly)` is mode_team_roam_generic.lua's
    -- line after the pick. On this frame the shipped anchor passes it and the
    -- nearest ally does not -- i.e. the defect does not merely pick a
    -- different hero, it turns a refusal into a 3192u walk.
    local J, bot = load(W_A)
    local hFar, hNear = nil, nil
    for _, m in ipairs(eligible(J, bot)) do
        if m:GetUnitName() == W_A[4] then hFar = m end
        if m:GetUnitName() == W_A[5] then hNear = m end
    end
    assert(hFar ~= nil and hNear ~= nil, 'the witness heroes left the frame')
    assert(J.GetHP(bot) >= J.GetHP(hFar) == true,
        'the shipped anchor no longer passes the HP guard')
    assert(J.GetHP(bot) >= J.GetHP(hNear) == false,
        'the nearest ally no longer fails the HP guard -- this frame no longer '
        .. 'shows the consequence it was chosen for')
    unprobe()
end

tests['[helpnear] witness B (dire): the anchor moves from 2976u to 93u'] =
function()
    pick_case(W_B)
    local J, bot = load(W_B)
    local d = {}
    for _, m in ipairs(eligible(J, bot)) do
        d[m:GetUnitName()] = GetUnitToUnitDistance(bot, m)
    end
    assert(d[W_B[5]] ~= nil and d[W_B[5]] < 200,
        'earthshaker stopped standing on top of the bot on this frame')
    assert(d[W_B[4]] ~= nil and d[W_B[4]] > 2500,
        'bristleback stopped being the far ally on this frame')
    unprobe()
end

-- ================================================ 3. inertness

tests['[helpnear] disarmed, the pick is the shipped pick'] = function()
    local J, bot = load(W_A)
    ss.assert_clean('helpnear inertness')
    assert(name(J.GetClosestAlly(bot, HELP_RADIUS)) == W_A[4],
        'disarmed, the pick moved')
    -- A different armed id must not arm this one.
    ss.with_candidate('roamring', function()
        assert(name(J.GetClosestAlly(bot, HELP_RADIUS)) == W_A[4],
            'another armed id switched the nearest-ally pick on')
    end, W_A[3])
    unprobe()
end

tests['[helpnear] armed but NOT turbo is the shipped pick'] = function()
    -- ⛔ The mode is flipped AFTER the load and BEFORE the first reading,
    -- because J.IsModeTurbo memoises into a module-level cache on its FIRST
    -- call. `J.IsModeTurbo() == false` is asserted first so a silently
    -- ineffective override cannot make the real claim pass for free.
    unprobe()
    local J, bot = rf.load(W_A[1], W_A[2])
    GAMEMODE_TURBO = 23                     -- luacheck: ignore
    GetGameMode = function() return 1 end   -- luacheck: ignore
    ss.with_candidate('helpnear', function()
        assert(J.IsModeTurbo() == false, 'the mode override did not take')
        assert(name(J.GetClosestAlly(bot, HELP_RADIUS)) == W_A[4],
            'armed outside turbo moved the pick -- this must be turbo-only')
    end, W_A[3])
    unprobe()
end

tests['[helpnear] armed on the OTHER side is the shipped pick'] = function()
    local J, bot = load(W_A)
    ss.with_candidate('helpnear', function()
        assert(name(J.GetClosestAlly(bot, HELP_RADIUS)) == W_A[4],
            'the dire-armed leg changed a radiant bot')
    end, 'dire')
    unprobe()
end

tests['[helpnear] an empty radius still answers nil, armed'] = function()
    -- The shipped `return nil` and the armed `return hNearest` must agree when
    -- nothing is eligible; otherwise the caller's `nClosestAlly ~= nil` guard
    -- is reading a different question armed.
    local J, bot = load(W_A)
    assert(J.GetClosestAlly(bot, 1) == nil, 'disarmed, a 1u radius found an ally')
    unprobe()
    local J2, bot2 = load(W_A)
    ss.with_candidate('helpnear', function()
        assert(J2.GetClosestAlly(bot2, 1) == nil,
            'armed, a 1u radius found an ally')
    end, W_A[3])
    unprobe()
end

-- ================================================ 4. what IS claimed

tests['[helpnear] armed, the answer is the distance minimum over the shipped '
    .. 'eligible set'] = function()
    -- This lever has no direction column (see the file header), so the claim
    -- it makes instead is checked on every witness: armed, the answer is an
    -- element of the SHIPPED loop's eligible set, and no element of that set
    -- is nearer.
    for _, w in ipairs({ W_A, W_B, W_CTRL }) do
        local J, bot = load(w)
        local tEligible = eligible(J, bot)
        assert(#tEligible >= 2,
            w[2] .. ': fewer than two eligible allies -- the picker has no '
            .. 'choice to get wrong here')
        unprobe()

        local J2, bot2 = load(w)
        ss.with_candidate('helpnear', function()
            local hArmed = J2.GetClosestAlly(bot2, HELP_RADIUS)
            local tE2 = eligible(J2, bot2)
            local bMember, nBest = false, nil
            for _, m in ipairs(tE2) do
                local d = GetUnitToUnitDistance(bot2, m)
                if m == hArmed then bMember = true end
                if nBest == nil or d < nBest then nBest = d end
            end
            assert(bMember, w[2] .. ': armed answered a hero outside the '
                .. 'shipped eligible set -- eligibility changed')
            assert(GetUnitToUnitDistance(bot2, hArmed) == nBest,
                w[2] .. ': armed answered a hero that is not the nearest')
        end, w[3])
        unprobe()
    end
end

-- ================================================ 5. control

tests['[control] a frame where the shipped pick is ALREADY the nearest is '
    .. 'unchanged by arming'] = function()
    local J, bot = load(W_CTRL)
    local tEligible = eligible(J, bot)
    assert(#tEligible == 4,
        'the control frame stopped having four eligible allies (' .. #tEligible
        .. ') -- it no longer controls for "the picker had a choice"')
    assert(name(J.GetClosestAlly(bot, HELP_RADIUS)) == W_CTRL[4],
        'the control frame shipped pick moved')
    unprobe()

    local J2, bot2 = load(W_CTRL)
    ss.with_candidate('helpnear', function()
        assert(name(J2.GetClosestAlly(bot2, HELP_RADIUS)) == W_CTRL[5],
            'arming moved a pick that was already the nearest -- the flips in '
            .. 'section 2 are not the roster order')
    end, W_CTRL[3])
    unprobe()
end

tests['[control] the witnesses and the control are distinct populations'] =
function()
    -- ⛔ Without this, all three cases could be the same shape and section 5
    -- would control for nothing.
    local bDiffer, bSame = false, false
    for _, w in ipairs({ W_A, W_B, W_CTRL }) do
        if w[4] == w[5] then bSame = true else bDiffer = true end
    end
    assert(bDiffer and bSame,
        'the case list lost either its differing frames or its control')
end

return tests

-- [hero] `axecallbkb_i` / `axecallbkb_ii` -- X.ConsiderQ refuses a spell-immune
-- enemy, and Berserker's Call is not stopped by spell immunity.  Written
-- 2026-09-05 under OWNER_PRIORITIES P4.4 (bots/ 主体配额); SPLIT INTO TWO IDS
-- 2026-09-06 (GH #577), which is what sections 4 and 6 are now for.
--
-- THE SPLIT, AND WHY THE TEST CHANGED SHAPE
-- -----------------------------------------
-- The 2026-09-05 version of this file registered, before any wave, that the two
-- branches shared one id and that a negative read could therefore not be
-- attributed to either.  hero-30's archive census (GH #577,
-- iterations/reports/replay-check/domain_scan_hero_2_30_31.md §8) sized them:
-- branch (i) 35 in-domain instants over 3 games, branch (ii) 1,519 over 36 --
-- 38x apart, so one id would have bought a number (ii) dominates and (i) cannot
-- be seen inside.  The pre-registered next rung was to SPLIT, and this is it:
--
--   branch (i)  X.IsCallPierceInterruptOn -> `axecallbkb_i`
--   branch (ii) X.IsCallPierceInitiateOn  -> `axecallbkb_ii`
--
-- The premise came back CONFIRMED by that census (1,141 Call landings on enemy
-- heroes in 69 games, 27 of them on a spell-immune hero across 19 games), so
-- nothing below is weakened; what is NEW is that the two ids must be provably
-- INDEPENDENT.  Section 6 is that proof, and it is the only part of this file
-- that a real frame -- not a source read -- can carry.
--
-- THE DEFECT
-- ----------
-- bots/BotLib/hero_axe.lua X.ConsiderQ carried TWO spell-immunity vetoes:
--
--   (i)  the interrupt branch   `npcEnemy:IsChanneling() and not npcEnemy:IsMagicImmune()`
--   (ii) the initiation branch  `J.CanCastOnNonMagicImmune( botTarget )`
--
-- axe_berserkers_call is `bkbpierce: "Yes"` and `behavior: "No Target"`
-- (odota/dotaconstants build/abilities.json, read 2026-09-05 -- the same file and
-- the same field tests/test_axe_cull_immune_veto.lua anchors `axecull` on).  So
-- both vetoes describe a restriction the game does not impose.
--
-- (ii) is the wider error and it is not only an immunity mistake: Call is a
-- no-target AoE taunt centred on Axe, and gating it on one enemy's properties
-- discards every OTHER enemy standing in the same ring.
--
-- WHY IT IS TWO SOURCES AND NOT ONE
-- ---------------------------------
-- Unlike `axecull`, whose anchor is RECORDED-only because that test cannot reach
-- the network, this ability's numbers are cross-checkable from inside the repo:
-- tests/mock/special_value_shapes.lua carries axe_berserkers_call radius 315,
-- AbilityCooldown `18 16 14 12`, AbilityManaCost `90 100 110 120`, generated from
-- the game's own npc_dota_hero_axe.txt.  Section KV drives that cross-check off
-- the fixture's own KV block.  It does NOT make `bkbpierce` network-verified --
-- that field has no KV counterpart and is recalled from the read above, exactly
-- as GH #516 established for GetAOERadius.  It makes a silent drift between the
-- recalled ability shape and the shipped data impossible.
--
-- HONEST BOUNDS -- READ BEFORE QUOTING ANY NUMBER FROM HERE
-- ---------------------------------------------------------
--   * SECTION 3 IS A THREE-FIELD COUNTERFACTUAL, not a firing frame.  `axecull`
--     needed one flip because its branch already fires on the untouched frame.
--     This one needs three, and section 2 measures WHY rather than asserting it:
--     across the 7 Axe-subject fixtures, "Call is ready" and "an enemy stands
--     inside the Call ring" NEVER co-occur, and no hero-instant anywhere in them
--     is channeling.  The three flips are (a) Call's remaining cooldown 17.0 -> 0,
--     (b) skywrath IsChanneling false -> true, (c) skywrath IsMagicImmune false ->
--     true.  They are applied in a 2x2 so each one's role is visible: (a) alone
--     still bids 0, (a)+(b) fires on BOTH legs, and only (a)+(b)+(c) separates
--     them.  Everything else on the frame -- positions, health, mana, levels,
--     modifiers, the other nine heroes -- is the replay's.
--   * BRANCH (ii) HAS SOURCE-LEVEL COVERAGE ONLY.  That is the `zusaether`
--     disposition and section 5 pins the three independent reasons, each measured
--     on this frame rather than recalled: `botTarget` is J.GetProperTarget and is
--     structurally nil on every fixture frame (GH #474); J.IsGoingOnSomeone is
--     false here; and J.IsDisabled answers TRUE for the only in-ring enemy.  A
--     test that stubbed all three would be gate plumbing, which AGENTS.md
--     explicitly says is not local validation -- so this file does not pretend to
--     it, and section 5 asserts the blockers so the label cannot rot into a
--     habit after one of them is fixed.
--   * CONSEQUENCE FOR THE VERDICT, registered before the wave and PAID on
--     2026-09-06: both branches used to share one id, so a negative wave read
--     could not be attributed to either.  The pre-registered next rung was to
--     SPLIT the id rather than reject the fact, and section 6 now holds the two
--     ids apart.  What the split does NOT buy is a behavioural case for (ii) --
--     that bound is unchanged and is the bullet above.
--   * Section 2's ring ignores vision, which makes it an UPPER bound; a "nothing
--     reaches it" claim measured against an over-large ring errs safe.
--   * Corpus counts come from `dofile` via the loader, never from a regex over
--     the fixture files -- the Axe threshold pre-flight's first pass under-counted
--     its Axe frames 10 to 26 exactly that way.

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')

local SRC = 'bots/BotLib/hero_axe.lua'
local FIXTURE = 'tests/fixtures/f_260820_043637_axe_ring_close.lua'
local AXE = 'npc_dota_hero_axe'
local SKY = 'npc_dota_hero_skywrath_mage'
local CALL = 'axe_berserkers_call'
local CAND_I = 'axecallbkb_i'    -- branch (i), the interrupt leg
local CAND_II = 'axecallbkb_ii'  -- branch (ii), the initiation leg
-- The id both branches shared until 2026-09-06.  It is RETIRED, not renamed: no
-- gate in bots/ names it any more, and section 6 asserts that, so a wave arming
-- the old string cannot silently arm nothing while looking wired.
local CAND_RETIRED = 'axecallbkb'

-- Recorded 2026-09-05 from odota/dotaconstants build/abilities.json.
local Q_RADIUS = 315
local Q_COOLDOWN = { 18, 16, 14, 12 }
local Q_MANA = { 90, 100, 110, 120 }
local RING = Q_RADIUS - 50  -- the interrupt branch's GetAroundEnemyHeroList arg
local DESIRE_HIGH = 0.75    -- BOT_ACTION_DESIRE_HIGH

-- Every Axe-SUBJECT fixture in the corpus, listed rather than globbed so a new
-- one is a deliberate edit and section 2's counts move with a named cause.
local AXE_FRAMES = {
    'tests/fixtures/f_260819_123546_axe_rescue_ok.lua',
    'tests/fixtures/f_260820_042612_axe_blink_init_573.lua',
    'tests/fixtures/f_260820_043124_axe_blink_flee_529.lua',
    'tests/fixtures/f_260820_043124_axe_blink_flee_555.lua',
    'tests/fixtures/f_260820_043124_axe_blink_kill.lua',
    'tests/fixtures/f_260820_043637_axe_ring_alone.lua',
    'tests/fixtures/f_260820_043637_axe_ring_close.lua',
}

local tests = {}

local function read_file(path)
    local fh = assert(io.open(path, 'r'), 'cannot open ' .. path)
    local body = fh:read('*a')
    fh:close()
    return body
end

local function consider_q_body(src)
    local from = src:find('function X%.ConsiderQ%s*%(%s*%)')
    assert(from, 'X.ConsiderQ not found in ' .. SRC)
    local rest = src:sub(from)
    local to = rest:find('\nfunction X%.')
    return to and rest:sub(1, to) or rest
end

--- Load the real frame, arm any subset of the two candidate ids, optionally apply
--- any of the three declared flips, then drive the REAL X.ConsiderQ.
---
--- `opt.arm` is a LIST of ids, never a boolean: after the split, "armed" is not a
--- state this lever has -- arming (i), arming (ii) and arming both are three
--- different worlds, and section 6 exists precisely because they must not be the
--- same one.  `opt.arm = {}` (or absent) is the shipped, disarmed world.
local function bid(opt)
    opt = opt or {}
    local armed = {}
    for _, id in ipairs(opt.arm or {}) do
        assert(id == CAND_I or id == CAND_II,
            'bid() asked to arm ' .. tostring(id) .. ', which is not one of this '
            .. "lever's ids -- a typo here would arm nothing and look like a finding")
        armed[id] = true
    end
    local J, bot, heroes, fx = rf.load(FIXTURE)
    -- `== true` and not a bare lookup: an absent key would make this return nil,
    -- and a helper asserted `== false` then fails on a nil that is behaviourally
    -- identical.  The distinction is the test's, not the gate's.
    J.IsSoakCandidate = function(id) return armed[id] == true end
    if opt.nonTurbo then
        -- rf.load's install() forces turbo; undo it AFTER load, exactly as
        -- tests/test_axe_cull_immune_veto.lua does.
        GetGameMode = function() return 1 end
    end
    if opt.ready then
        rawget(bot:GetAbilityByName(CALL), '__spec').GetCooldownTimeRemaining = 0
    end
    if opt.channeling then
        rawget(heroes[SKY], '__spec').IsChanneling = true
    end
    if opt.immune then
        rawget(heroes[SKY], '__spec').IsMagicImmune = true
    end
    local X = rf.load_hero('axe')
    local d, m = X.ConsiderQ()
    return d, m, J, bot, heroes, fx, X
end

-- ---------------------------------------------------------------- section 1 --
-- Ground truth on the untouched frame.

tests['ground truth: 6:33, skywrath stands 188u inside the 265u Call ring'] = function()
    local _, _, _, bot, heroes, fx = bid()
    assert(fx.self == AXE and fx.time == 393.4, 'the decision instant')
    assert(bot:GetLevel() == 6 and bot:GetMana() == 286, 'real Axe state')
    local sky = heroes[SKY]
    assert(sky:GetTeam() ~= bot:GetTeam(), 'skywrath is the enemy on this frame')
    local d = GetUnitToUnitDistance(bot, sky)
    assert(d > 187 and d < 189, 'skywrath really is ~188u away, got ' .. tostring(d))
    assert(d <= RING, 'and inside the interrupt branch ring of ' .. RING)
end

tests['ground truth: Call is at 17.0s of its own 18s rank-1 cooldown'] = function()
    -- This is not colour.  It is the fact that forces flip (a): the ONE corpus
    -- frame that puts an enemy inside the ring is a frame on which Axe had just
    -- cast Berserker's Call.
    local _, _, _, bot = bid()
    local q = bot:GetAbilityByName(CALL)
    assert(q:GetLevel() == 1, 'Call really is rank 1 here')
    assert(q:GetCooldownTimeRemaining() == 17, 'remaining cooldown, got '
        .. tostring(q:GetCooldownTimeRemaining()))
    assert(q:IsFullyCastable() == false, 'so the shipped first line bails')
    assert(bot:GetMana() >= Q_MANA[1],
        'and it is the COOLDOWN that bails it, not the mana: 286 covers the 90 cost')
end

tests['ground truth: nobody is spell-immune and nobody is channeling here'] = function()
    local _, _, _, _, heroes = bid()
    for name, h in pairs(heroes) do
        assert(h:IsMagicImmune() == false,
            name .. ' reads spell-immune on the untouched frame; the counterfactual '
            .. 'would then not be isolating what it claims to isolate')
        assert(h:IsChanneling() == false,
            name .. ' reads channeling on the untouched frame; same problem')
    end
end

tests['shipped path: the untouched frame bids nothing'] = function()
    local d, m = bid()
    assert(d == 0, 'shipped desire on the untouched frame, got ' .. tostring(d))
    assert(m == nil, 'and no motive, got ' .. tostring(m))
end

-- ---------------------------------------------------------------- section 2 --
-- The supply, measured.  One-sided tripwires: more fixtures can only strengthen
-- them, and the day one reaches the domain it goes RED and names the frame --
-- which is the real frame this lever needs before anyone promotes it.

tests['supply: "Call ready" and "enemy in the ring" never co-occur in the corpus'] = function()
    local nReady, nInRing, nBoth, sBoth = 0, 0, 0, nil
    for _, path in ipairs(AXE_FRAMES) do
        local J, bot, heroes, fx = rf.load(path)
        J.IsSoakCandidate = function() return false end
        assert(fx.self == AXE, path .. ' is not an Axe-subject frame; AXE_FRAMES is stale')
        local q = bot:GetAbilityByName(CALL)
        local bReady = q ~= nil and q:IsFullyCastable()
        local bInRing = false
        for _, h in pairs(heroes) do
            if h:GetTeam() ~= bot:GetTeam()
                and GetUnitToUnitDistance(bot, h) <= RING
            then bInRing = true end
        end
        if bReady then nReady = nReady + 1 end
        if bInRing then nInRing = nInRing + 1 end
        if bReady and bInRing then nBoth = nBoth + 1; sBoth = path end
    end
    assert(#AXE_FRAMES == 7, 'AXE_FRAMES grew; re-read the counts below before trusting them')
    assert(nReady >= 5, 'Call-ready frames dropped below the measured 5, got ' .. nReady)
    assert(nInRing >= 1, 'in-ring frames dropped below the measured 1, got ' .. nInRing)
    assert(nBoth == 0,
        'GOOD NEWS, NOT A REGRESSION: ' .. tostring(sBoth) .. ' now has Call ready AND an '
        .. 'enemy inside ' .. RING .. 'u.  This lever no longer needs flip (a).  Rewrite '
        .. 'section 3 against that frame and re-read the HONEST BOUNDS header; do NOT '
        .. 'relax this assertion.')
end

tests['supply: no channeling hero-instant exists in any Axe-subject frame'] = function()
    local n, sWhere = 0, nil
    for _, path in ipairs(AXE_FRAMES) do
        local J, _, heroes = rf.load(path)
        J.IsSoakCandidate = function() return false end
        for name, h in pairs(heroes) do
            if h:IsChanneling() then n = n + 1; sWhere = path .. ' / ' .. name end
        end
    end
    assert(n == 0,
        'GOOD NEWS: a channeling instant appeared at ' .. tostring(sWhere) .. '.  Branch '
        .. '(i) can now be pinned with one fewer flip; rewrite section 3 rather than '
        .. 'relaxing this.')
end

-- ---------------------------------------------------------------- section 3 --
-- The counterfactual, as a 2x2 so each flip's role is visible rather than pooled.

tests['2x2 (a) alone: Call ready, nobody channeling -- still bids nothing'] = function()
    -- Isolates flip (a): making the ability castable does not by itself create a
    -- bid, so section 3's later readings are not "the cooldown flip did it".
    local dOff = bid({ ready = true })
    local dOn = bid({ ready = true, arm = { CAND_I, CAND_II } })
    assert(dOff == 0, 'gate OFF, got ' .. tostring(dOff))
    assert(dOn == 0, 'both gates ON must be identical here, got ' .. tostring(dOn))
end

tests['2x2 (a)+(b): a channeling, NON-immune skywrath fires on BOTH legs'] = function()
    -- Isolates flip (b) and doubles as the anti-regression half: whatever the
    -- gate does, it must do NOTHING on a frame where nobody is immune -- which is
    -- every frame in this corpus and the overwhelming majority of a real game.
    local dOff, mOff = bid({ ready = true, channeling = true })
    local dOn, mOn = bid({ ready = true, channeling = true, arm = { CAND_I, CAND_II } })
    assert(dOff == DESIRE_HIGH, 'shipped desire, got ' .. tostring(dOff))
    assert(type(mOff) == 'string' and mOff:find('Q%-'), 'shipped motive, got ' .. tostring(mOff))
    assert(dOn == dOff, 'armed desire drifted on a non-immune frame: '
        .. tostring(dOn) .. ' vs ' .. tostring(dOff))
    assert(mOn == mOff, 'armed motive drifted: ' .. tostring(mOn) .. ' vs ' .. tostring(mOff))
end

tests['2x2 (a)+(b)+(c), gate OFF: the immune channeler is refused -- the defect'] = function()
    local d, m = bid({ ready = true, channeling = true, immune = true })
    assert(d == 0, 'shipped code declines an interrupt it could land, got ' .. tostring(d))
    assert(m == nil, 'and reports no motive, got ' .. tostring(m))
end

tests['2x2 (a)+(b)+(c), gate ON: the same frame breaks the channel'] = function()
    -- `axecallbkb_i` alone, not both: this branch is (i)'s, and arming (ii) here
    -- would make the case pass for a reason section 6 is about to forbid.
    local d, m = bid({ ready = true, channeling = true, immune = true, arm = { CAND_I } })
    assert(d == DESIRE_HIGH, 'armed desire, got ' .. tostring(d))
    assert(type(m) == 'string' and m:find('Q%-'),
        'motive still reported, got ' .. tostring(m))
end

tests['gate ON but NOT turbo: still refused'] = function()
    -- The turbo half of the gate carries the whole "shipped normal-mode behaviour
    -- is unchanged" promise; without this case the gate could be turbo-less and
    -- every other case here would still pass.
    local d = bid({ ready = true, channeling = true, immune = true,
                    arm = { CAND_I, CAND_II }, nonTurbo = true })
    assert(d == 0, 'outside turbo the candidate must be inert, got ' .. tostring(d))
end

-- ---------------------------------------------------------------- section 4 --
-- The gate helpers themselves -- one per branch since the 2026-09-06 split.

--- The helper body, read out of the shipped source by name.  Reading the SOURCE
--- rather than calling the function is what makes the id assertions below able to
--- fail: a helper that named the wrong id would still answer true/false correctly
--- for whatever id it does name.
--- The window ends at the helper's own `end`, not at a fixed byte count: the two
--- helpers are adjacent in the file, so a 300-byte window off the first one runs
--- straight into the second and reports BOTH ids for it.  (That is not a
--- hypothetical -- it is what this function did on its first run.)
local function helper_body(src, fname)
    local from = src:find('function X%.' .. fname .. '%s*%(%s*%)')
    assert(from, 'X.' .. fname .. ' not found in ' .. SRC)
    local rest = src:sub(from)
    local to = rest:find('\nend')
    assert(to, 'X.' .. fname .. ' has no terminating `end` -- the reader would '
        .. 'otherwise scan the rest of the file and report a neighbour\'s id')
    return rest:sub(1, to)
end

local HELPERS = {
    { fname = 'IsCallPierceInterruptOn', id = CAND_I, branch = '(i) interrupt' },
    { fname = 'IsCallPierceInitiateOn', id = CAND_II, branch = '(ii) initiation' },
}

tests['each gate helper is turbo AND its own candidate, not either'] = function()
    -- Each leg gets a FRESH world: J.IsModeTurbo memoises into bModeTurboCache on
    -- its first call, so flipping GetGameMode after the helper has run once
    -- changes nothing.
    for _, h in ipairs(HELPERS) do
        local _, _, _, _, _, _, Xturbo = bid({ arm = { h.id } })
        assert(type(Xturbo[h.fname]) == 'function',
            'X.' .. h.fname .. ' is gone or renamed -- branch ' .. h.branch)
        assert(Xturbo[h.fname]() == true, h.fname .. ': armed + turbo must be on')

        local _, _, _, _, _, _, Xnormal = bid({ arm = { h.id }, nonTurbo = true })
        assert(Xnormal[h.fname]() == false, h.fname .. ': armed but not turbo must be off')

        local _, _, _, _, _, _, Xdisarmed = bid()
        assert(Xdisarmed[h.fname]() == false, h.fname .. ': turbo but not armed must be off')
    end
end

tests['each helper names exactly its own candidate id and nothing else'] = function()
    -- The `pullcad` trap, and after the split it is no longer hypothetical: the
    -- two ids are siblings in the same function, so a helper naming the OTHER
    -- one's id would freeze FALSE the day that one is promoted, and
    -- check_armed_wiring.py would still call it WIRED.  Each helper is STANDALONE.
    local src = read_file(SRC)
    for _, h in ipairs(HELPERS) do
        local body = helper_body(src, h.fname)
        local ids = {}
        for id in body:gmatch("IsSoakCandidate%s*%(%s*'([%w_]+)'") do ids[#ids + 1] = id end
        assert(#ids == 1 and ids[1] == h.id,
            'X.' .. h.fname .. ' must name exactly one candidate id (' .. h.id
            .. '), found ' .. table.concat(ids, ','))
        assert(body:find('IsModeTurbo'), 'X.' .. h.fname .. ' lost its turbo half')
    end
end

-- ---------------------------------------------------------------- section 5 --
-- Branch (ii): SOURCE-LEVEL COVERAGE ONLY, with its three blockers measured.
-- These assertions exist so the label cannot rot into a habit: the day a blocker
-- is fixed, the case that names it goes red and says so.

tests['branch (ii) is wired, and gate OFF reduces it to the shipped predicate'] = function()
    local body = consider_q_body(read_file(SRC))
    local from = body:find('J%.IsGoingOnSomeone')
    assert(from, 'the initiation branch is gone from X.ConsiderQ')
    local clause = body:sub(from, from + 500)
    assert(clause:find('J%.CanCastOnNonMagicImmune%(%s*botTarget%s*%)'),
        'the shipped operand must stay FIRST -- it is what makes gate-off byte-equivalent')
    assert(clause:find('X%.IsCallPierceInitiateOn%(%)%s*and%s*J%.CanCastOnMagicImmune'),
        'the widened operand must be gated AND must use the magic-immune-piercing helper')
    assert(not clause:find('IsCallPierceInterruptOn'),
        "branch (ii) is wired to branch (i)'s helper -- the split is cosmetic and a "
        .. 'wave arming ' .. CAND_I .. ' would move BOTH branches')
    -- The two helpers differ by exactly the IsMagicImmune term, which is what makes
    -- "every other veto still applies" a property of the code rather than a promise.
    local fun = read_file('bots/FunLib/jmz_func.lua')
    for _, term in ipairs({ 'CanBeSeen', 'IsInvulnerable', 'IsSuspiciousIllusion',
                            'HasForbiddenModifier' }) do
        local pierce = fun:find('function J%.CanCastOnMagicImmune.-' .. term)
        assert(pierce, 'J.CanCastOnMagicImmune no longer checks ' .. term
            .. ' -- the widened operand would then drop a veto the shipped one keeps')
    end
end

tests['branch (ii) blocker 1: botTarget is nil on this frame (GH #474)'] = function()
    local _, _, J, bot = bid({ ready = true })
    assert(J.GetProperTarget(bot) == nil,
        'GOOD NEWS: J.GetProperTarget answers on a fixture frame now.  Branch (ii) may '
        .. 'be reachable without stubs -- write that case and drop this one.')
end

tests['branch (ii) blocker 2: J.IsGoingOnSomeone is false on this frame'] = function()
    local _, _, J, bot = bid({ ready = true })
    assert(J.IsGoingOnSomeone(bot) == false,
        'GOOD NEWS: the frame now reaches the initiation branch premise; re-read '
        .. 'section 5 before quoting "source-level coverage only".')
end

tests['branch (ii) blocker 3: J.IsDisabled is true for the only in-ring enemy'] = function()
    local _, _, J, _, heroes = bid({ ready = true })
    assert(J.IsDisabled(heroes[SKY]) == true,
        'GOOD NEWS: the last guard on the initiation branch now passes for skywrath; '
        .. 'combined with blockers 1 and 2 this frame would become a real (ii) case.')
end

-- ---------------------------------------------------------------- section 6 --
-- THE SPLIT IS SEPARABLE (GH #577).  hero-30 measured the two branches 38x
-- apart, so the whole point of carrying two ids is that a wave can arm one
-- without moving the other.  A cosmetic split -- two helpers that both answer to
-- the same armed string, or a branch wired to the wrong helper -- would look
-- exactly like this one in the source and buy nothing at the verdict.  These
-- cases are the difference, and the first one is carried by the REAL FRAME:
-- section 3's (a)+(b)+(c) world is the only place in this file where a gate is
-- observed changing a decision, so it is also the only place where "arming the
-- other id does nothing" can be observed rather than argued.
--
-- ⚠️ ASYMMETRY, stated so nobody reads it as a gap.  Only branch (i) can be shown
-- this way, because only branch (i) has a reachable frame (section 5's three
-- blockers).  "Arming (i) does not move branch (ii)" is therefore asserted at the
-- SOURCE, in section 5's last assertion, and not here.

tests['separable: arming (ii) ALONE leaves branch (i) refusing the immune channeler'] = function()
    -- The same three-flip frame section 3 uses.  Gate off it bids 0; armed on
    -- `axecallbkb_i` it bids HIGH; armed on `axecallbkb_ii` it must bid 0 again,
    -- because branch (ii) has nothing to do with an interrupt.
    local dOff = bid({ ready = true, channeling = true, immune = true })
    local dII = bid({ ready = true, channeling = true, immune = true, arm = { CAND_II } })
    local dI = bid({ ready = true, channeling = true, immune = true, arm = { CAND_I } })
    assert(dOff == 0, 'the disarmed baseline moved, got ' .. tostring(dOff))
    assert(dI == DESIRE_HIGH,
        CAND_I .. ' no longer fires branch (i) on this frame, got ' .. tostring(dI))
    assert(dII == dOff,
        CAND_II .. ' moved branch (i) (got ' .. tostring(dII) .. ' vs the disarmed '
        .. tostring(dOff) .. ') -- the two ids are not separable, so a wave arming '
        .. 'either one buys the composite reading GH #577 split them to avoid')
end

tests['separable: arming BOTH is branch (i) armed, not something new'] = function()
    -- Guards the other direction: if the two ids had been ANDed rather than kept
    -- independent, arming both would be the only world in which (i) fires, and the
    -- case above would still pass.
    local dBoth = bid({ ready = true, channeling = true, immune = true,
                        arm = { CAND_I, CAND_II } })
    local dI = bid({ ready = true, channeling = true, immune = true, arm = { CAND_I } })
    assert(dBoth == dI, 'arming both differs from arming ' .. CAND_I .. ' alone: '
        .. tostring(dBoth) .. ' vs ' .. tostring(dI))
end

tests['the retired id `axecallbkb` names no gate anywhere in bots/'] = function()
    -- Retired, not renamed.  It was never in any armed set (W49_wave.json records
    -- it landing gated and staying out), which is the only reason retiring it is
    -- safe -- and this assertion is what keeps "safe" true: if the string came
    -- back as a live gate, a wave could arm it and get a composite reading again,
    -- or arm one of the split ids and silently move a branch this file does not
    -- know about.
    local sawGate, sawWhere = false, nil
    local fh = assert(io.popen("grep -rn \"IsSoakCandidate( '\" bots/ 2>/dev/null", 'r'))
    local all = fh:read('*a')
    fh:close()
    assert(all:find(CAND_I, 1, true), 'the grep found no ' .. CAND_I
        .. ' at all -- this scan is vacuous, not passing; check that it ran')
    for line in all:gmatch('[^\n]+') do
        for id in line:gmatch("IsSoakCandidate%(%s*'([%w_]+)'") do
            if id == CAND_RETIRED then sawGate = true; sawWhere = line end
        end
    end
    assert(sawGate == false,
        'the retired id ' .. CAND_RETIRED .. ' is a live gate again at: '
        .. tostring(sawWhere) .. '.  Either finish the split or re-register the id; '
        .. 'do not leave both shapes in the tree.')
end

-- ---------------------------------------------------------------- section KV --
-- The recalled ability shape against the fixture's own KV block.  If this goes
-- red, do NOT edit the anchor to match: either a patch moved Berserker's Call
-- (update the anchor AND the helper header, and re-read every claim quoting the
-- numbers) or the loader/snapshot drifted (fix that, the anchor is fine).

tests['KV: the recalled Call anchor matches the fixture KV on all four ranks'] = function()
    local _, _, _, bot = bid()
    local h = bot:GetAbilityByName(CALL)
    assert(h ~= nil, 'no ' .. CALL .. ' handle on the frame')
    local sp = rawget(h, '__spec')
    assert(sp ~= nil and sp.GetSpecialValueFloat ~= nil,
        'the loader installed no KV spec on ' .. CALL .. ' -- this cross-check is '
        .. 'vacuous, not passing; find out why before quoting this section')
    local lv0 = sp.GetLevel
    for rank = 1, 4 do
        sp.GetLevel = rank
        assert(h:GetSpecialValueInt('radius') == Q_RADIUS,
            ('rank %d radius: anchor %d, fixture KV %s'):format(
                rank, Q_RADIUS, tostring(h:GetSpecialValueInt('radius'))))
        assert(h:GetManaCost() == Q_MANA[rank],
            ('rank %d mana: anchor %d, fixture KV %s'):format(
                rank, Q_MANA[rank], tostring(h:GetManaCost())))
        assert(h:GetCooldown() == Q_COOLDOWN[rank],
            ('rank %d cooldown: anchor %d, fixture KV %s'):format(
                rank, Q_COOLDOWN[rank], tostring(h:GetCooldown())))
    end
    sp.GetLevel = lv0
    assert(Q_COOLDOWN[1] == 18,
        'the "17.0 of 18" reading in section 1 is built from this anchor')
end

return tests

-- [hero] `axecallbkb` -- X.ConsiderQ refuses a spell-immune enemy, and
-- Berserker's Call is not stopped by spell immunity.  Written 2026-09-05 under
-- OWNER_PRIORITIES P4.4 (bots/ 主体配额).
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
--   * CONSEQUENCE FOR THE VERDICT, registered before the wave.  Both branches
--     share one id, so a negative wave read cannot be attributed to either.  The
--     next rung then is to SPLIT the id, not to reject the fact.
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
local CAND = 'axecallbkb'

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

--- Load the real frame, optionally arm `axecallbkb`, optionally apply any of the
--- three declared flips, then drive the REAL X.ConsiderQ.
local function bid(opt)
    opt = opt or {}
    local J, bot, heroes, fx = rf.load(FIXTURE)
    -- `opt.armed == true` and not `opt.armed`: an absent key would make this
    -- return nil, and a helper asserted `== false` then fails on a nil that is
    -- behaviourally identical.  The distinction is the test's, not the gate's.
    J.IsSoakCandidate = function(id) return opt.armed == true and id == CAND end
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
    local dOn = bid({ ready = true, armed = true })
    assert(dOff == 0, 'gate OFF, got ' .. tostring(dOff))
    assert(dOn == 0, 'gate ON must be identical here, got ' .. tostring(dOn))
end

tests['2x2 (a)+(b): a channeling, NON-immune skywrath fires on BOTH legs'] = function()
    -- Isolates flip (b) and doubles as the anti-regression half: whatever the
    -- gate does, it must do NOTHING on a frame where nobody is immune -- which is
    -- every frame in this corpus and the overwhelming majority of a real game.
    local dOff, mOff = bid({ ready = true, channeling = true })
    local dOn, mOn = bid({ ready = true, channeling = true, armed = true })
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
    local d, m = bid({ ready = true, channeling = true, immune = true, armed = true })
    assert(d == DESIRE_HIGH, 'armed desire, got ' .. tostring(d))
    assert(type(m) == 'string' and m:find('Q%-'),
        'motive still reported, got ' .. tostring(m))
end

tests['gate ON but NOT turbo: still refused'] = function()
    -- The turbo half of the gate carries the whole "shipped normal-mode behaviour
    -- is unchanged" promise; without this case the gate could be turbo-less and
    -- every other case here would still pass.
    local d = bid({ ready = true, channeling = true, immune = true, armed = true, nonTurbo = true })
    assert(d == 0, 'outside turbo the candidate must be inert, got ' .. tostring(d))
end

-- ---------------------------------------------------------------- section 4 --
-- The gate helper itself.

tests['the gate helper is turbo AND candidate, not either'] = function()
    -- Each leg gets a FRESH world: J.IsModeTurbo memoises into bModeTurboCache on
    -- its first call, so flipping GetGameMode after the helper has run once
    -- changes nothing.
    local _, _, _, _, _, _, Xturbo = bid({ armed = true })
    assert(type(Xturbo.IsCallPierceOn) == 'function', 'X.IsCallPierceOn is gone or renamed')
    assert(Xturbo.IsCallPierceOn() == true, 'armed + turbo must be on')

    local _, _, _, _, _, _, Xnormal = bid({ armed = true, nonTurbo = true })
    assert(Xnormal.IsCallPierceOn() == false, 'armed but not turbo must be off')

    local _, _, _, _, _, _, Xdisarmed = bid()
    assert(Xdisarmed.IsCallPierceOn() == false, 'turbo but not armed must be off')
end

tests['the helper names exactly this candidate id and nothing else'] = function()
    -- The `pullcad` trap: a gate whose condition names a SIBLING id freezes FALSE
    -- the day that sibling is promoted, and no wiring check notices.  This helper
    -- must be STANDALONE.
    local src = read_file(SRC)
    local from = src:find('function X%.IsCallPierceOn%s*%(%s*%)')
    assert(from, 'X.IsCallPierceOn not found in ' .. SRC)
    local body = src:sub(from, from + 300)
    local ids = {}
    for id in body:gmatch("IsSoakCandidate%s*%(%s*'([%w_]+)'") do ids[#ids + 1] = id end
    assert(#ids == 1 and ids[1] == CAND,
        'the helper must name exactly one candidate id (' .. CAND .. '), found '
        .. table.concat(ids, ','))
    assert(body:find('IsModeTurbo'), 'the helper lost its turbo half')
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
    assert(clause:find('X%.IsCallPierceOn%(%)%s*and%s*J%.CanCastOnMagicImmune'),
        'the widened operand must be gated AND must use the magic-immune-piercing helper')
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

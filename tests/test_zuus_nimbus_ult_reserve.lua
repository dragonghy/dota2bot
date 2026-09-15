-- [hero] [ratchet] Zeus's ult-mana reserve guards three of its four consumers,
-- and the one it does not guard is the most expensive.  Landed as turbo-only
-- soak candidate `zusultd`.
--
-- THE GAP THIS FILE CLOSES
-- ------------------------
-- X.zuus_ShouldSaveManaForUlt exists to stop Zeus spending the mana his global
-- finisher is waiting on.  Before this round it was wired at three dispatch
-- sites in X.SkillsComplement -- ConsiderW, ConsiderW2, ConsiderQ -- and NOT at
-- the fourth, ConsiderD (Nimbus), which is dispatched from the same pool in the
-- same tick, immediately after the guarded ConsiderQ.
--
-- GH #47 is the precedent and it is a measurement, not an analogy: a reserve
-- wired to a strict SUBSET of a spell's consumers does not narrow the spend, it
-- RELOCATES it.  There the held ConsiderW bid walked out through ConsiderW2 on
-- the next line and spent the identical mana on the identical target (3 domain
-- casts on the armed side).  The shape here is one dispatch further down.
--
-- ⭐ AND THE UNGUARDED SITE IS THE EXPENSIVE ONE, which is why this is the
-- largest of the four holes rather than the smallest.  Section 2 reads both
-- numbers off the KV snapshot rather than retyping them:
--     zuus_cloud             AbilityManaCost 275           (flat, no ladder)
--     zuus_thundergods_wrath AbilityManaCost 250 / 375 / 500
-- One Nimbus costs MORE than a rank-1 Thundergod's Wrath.
--
-- ⭐⭐ THE SHARPEST THING THIS FILE PINS, AND IT IS ARITHMETIC ON THOSE TWO
-- NUMBERS RATHER THAN A READING: at ULT RANK 1 the `zusult` leg of this lever
-- has an EMPTY domain.  X.ConsiderD cannot bid unless Nimbus IsFullyCastable,
-- which needs mana >= 275; the reserve cannot hold unless mana < the ult's cost,
-- which at rank 1 is 250; and 275 > 250, so the two are unsatisfiable together.
-- The window opens only at rank 2 (mana in [275, 375), width 100) and rank 3
-- ([275, 500), width 225).  Under the `zusultx` widening -- which subtracts the
-- pending spend before asking -- the window is [275, cost + 275) and rank 1 is
-- nonempty for the first time.  Section 3 drives all six bounds.
-- ⛔ So "arm zusultd" and "arm zusultd + zusultx" are not the same experiment at
-- rank 1, and a wave that reads one may not be quoted about the other.
--
-- WHAT IS PINNED, AND WHY IN THIS ORDER
--   1. the call site is WIRED (an unwired gate measures nothing, and
--      check_armed_wiring.py would still call it WIRED), and the three sibling
--      sites are still guarded -- otherwise "the fourth hole" describes nothing.
--   2. the price asymmetry, PARSED off tests/mock/special_value_shapes.lua.
--   3. the rank arithmetic above, DRIVEN through the real helper on a real frame
--      with mana as the one declared injection.
--   4. the retreat branch's EXEMPTION, both of its two independent reasons.
--   5. the DIRECTION: armed, desire can only go HIGH -> 0.
--   6. the corpus domain, as a ONE-WAY TRIPWIRE, with its two causes kept apart.
--   7. the gate shape (turbo-only, one id, its own -- the pullcad trap).
--
-- ⚠️ WHAT THIS FILE DOES NOT BUY.  It does not show the armed leg firing on a
-- real frame, and it cannot: see section 6.  Condition (a) is UNBOUGHT and the
-- request is iterations/queue.json hero-88 (zero EC2).  Nothing here argues for
-- arming, promoting or retiring `zusultd`; the id is gated and unarmed, so every
-- shipped game still casts Nimbus exactly as before.

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')

local SRC   = 'bots/BotLib/hero_zuus.lua'
local SHAPE = 'tests/mock/special_value_shapes.lua'
local CAND  = 'zusultd'
local ULT   = 'zuus_thundergods_wrath'
local CLOUD = 'zuus_cloud'

-- A frame whose Zeus carries the ult handle at rank 1, cooldown 0, and mana
-- BELOW the ult cost -- i.e. every clause of the reserve except the target ones
-- is already satisfied by frame data.  Section 3 injects mana and nothing else.
local FRAME = 'tests/fixtures/f_260819_142047_zuus_ult_denied.lua'

-- Every Zeus-SUBJECT frame, listed rather than globbed so a new one is a
-- deliberate edit and section 6's counts move with a named cause.
local ZUUS_FRAMES = {
    'tests/fixtures/f_072738_zuus_mana.lua',
    'tests/fixtures/f_073148_zuus_lina.lua',
    'tests/fixtures/f_163714_zuus_commit_pin.lua',
    'tests/fixtures/f_181441_zuus_lowhp_limbo.lua',
    'tests/fixtures/f_230952_zuus_ult_hoard.lua',
    'tests/fixtures/f_260819_142047_zuus_ult_denied.lua',
    'tests/fixtures/f_260819_142047_zuus_ult_manalock.lua',
    'tests/fixtures/f_260819_222052_zuus_w2_leak.lua',
    'tests/fixtures/f_20260827_091703_slot12_zuus_473_1.lua',
}

local tests = {}

local function read_file(path)
    local fh = assert(io.open(path, 'r'), 'cannot open ' .. path)
    local body = fh:read('*a')
    fh:close()
    return body
end

--- Comments stripped, so a ratchet counting code shapes cannot be satisfied by
--- prose that merely quotes the expression -- and this file's own source block
--- quotes it several times on purpose.
local function strip_comments(body)
    return (body:gsub('%-%-[^\n]*', ''))
end

local function fn_body(src, name)
    local from = src:find('function X%.' .. name .. '%s*%(')
    assert(from, 'X.' .. name .. ' not found in ' .. SRC)
    local rest = src:sub(from)
    local to = rest:find('\nfunction X%.')
    return to and rest:sub(1, to) or rest
end

--- Every per-rank entry of a KV "a b c" base string.
local function ladder(sBase)
    local t = {}
    for w in tostring(sBase):gmatch('%S+') do t[#t + 1] = tonumber(w) end
    assert(#t > 0, 'no numeric entries in KV base string ' .. tostring(sBase))
    return t
end

local ZUUS_KV = assert(dofile(SHAPE).SHAPES['zuus'], 'no zuus block in the KV snapshot')

local function kv_cost(sAbility)
    local ab = assert(ZUUS_KV[sAbility], 'no KV block for ' .. sAbility)
    local c = assert(ab['AbilityManaCost'], sAbility .. ' has no AbilityManaCost')
    return ladder(c.base)
end

--- The `zusultd` gate's WHOLE `if ( ... )` condition, not the one line that
--- happens to name the id.
---
--- ⚠️ The distinction is load-bearing and it was found by a mutant: with a
--- single-line reader, ANDing a sibling id into the condition also pushed
--- `J.IsModeTurbo()` out of the matched text, so the pullcad assertion never got
--- to speak -- the turbo assertion fired first and reported a turbo problem that
--- did not exist (M3 of tools/agent/mutstand_zusultd.sh, "red but not on the
--- assertion aimed at").  Both readings now run on the same span.
local function gate_condition(body)
    local to = body:find("IsSoakCandidate%(%s*'" .. CAND .. "'%s*%)")
    assert(to, 'the ' .. CAND .. ' gate is gone from ' .. SRC)
    local from, i = nil, 1
    while true do
        local s = body:find('\n%s*if%s', i)
        if s == nil or s >= to then break end
        from = s; i = s + 1
    end
    assert(from, 'could not isolate the ' .. CAND .. ' gate condition')
    -- Out to the closing `then`, so the whole condition is in scope.
    local rest = body:sub(from)
    local stop = rest:find('%)%s*\n%s*then')
    return rest:sub(1, stop and (stop + 1) or #rest), from, to
end

--- Load one real frame with `zusultd` armed or not.
---
--- `opt.armed == true` rather than a truthiness test: an absent key would arm
--- nothing, and an assertion expecting the shipped answer would then pass for
--- the wrong reason.
local function on_frame(path, opt)
    opt = opt or {}
    local tArmed = {}
    if opt.armed == true then tArmed[CAND] = true end
    for _, sId in ipairs(opt.also or {}) do tArmed[sId] = true end
    local J, bot, heroes, fx = rf.load(path)
    J.IsSoakCandidate = function(id) return tArmed[id] == true end
    local X = rf.load_hero('zuus')
    return X, J, bot, heroes, fx
end

--- A hero the reserve will accept as a chip target: valid, above the health
--- floor.  Taken from the frame's own enemy list rather than fabricated.
local function healthy_enemy(J, bot)
    for _, h in ipairs(J.GetNearbyHeroes(bot, 100000, true, BOT_MODE_NONE) or {}) do
        if J.IsValidHero(h) and J.GetHP(h) >= 0.75 then return h end
    end
    return nil
end

-- ---------------------------------------------------------------- section 1 --
-- The call site is wired, and the siblings still are.  These going red mean
-- "re-read the file", never "the test is stale".

tests['section 1: the Nimbus dispatch is wired to the reserve, and to nothing else'] = function()
    local body = strip_comments(fn_body(read_file(SRC), 'SkillsComplement'))

    assert(body:find('castDDesire%s*,%s*castDLocation%s*,%s*castDTarget%s*=%s*X%.ConsiderD'),
        'X.SkillsComplement no longer takes a third value out of X.ConsiderD.  '
        .. 'Without it the reserve is inert at this site by construction -- it '
        .. 'refuses a non-hero target -- so the gate would read WIRED and measure '
        .. 'nothing.')

    local sHold = body:match("[^\n]*IsSoakCandidate%(%s*'" .. CAND .. "'%s*%)[^\n]*")
    assert(sHold, 'the ' .. CAND .. ' gate is gone from X.SkillsComplement.')

    -- The hold must be fed castDTarget and the Nimbus handle, not some other
    -- pair: passing abilityW here would price the wrong spend under zusultx and
    -- still look wired.
    assert(body:find('X%.zuus_ShouldSaveManaForUlt%(%s*bot%s*,%s*castDTarget%s*,'),
        'the ' .. CAND .. ' hold no longer passes castDTarget to the reserve.')
    -- The handle is HOISTED rather than re-resolved inline, so this reads the
    -- binding and then the use.  Two reasons, both external: the executor below
    -- must read the SAME handle the desire was priced against
    -- (tests/test_zuus_ability_index_binding.lua allows exactly two routed
    -- abilityD sites, the consider and the queued order), and the arity tripwire
    -- in tests/test_replay_260820_zuus_reserve_cross.lua parses arguments with
    -- `[^)]*`, which a nested call silently truncates.
    local sBound = "hCloudHandle%s*=%s*X%.GetBoundAbility%(%s*abilityD%s*,%s*'" .. CLOUD .. "'%s*%)"
    assert(body:find(sBound),
        'the Nimbus handle is no longer bound through X.GetBoundAbility( abilityD, \''
        .. CLOUD .. '\' ).  Un-routed, the desire and the queued order can disagree '
        .. 'about which ability they are talking about.')
    assert(body:find('X%.zuus_ShouldSaveManaForUlt%(%s*bot%s*,%s*castDTarget%s*,%s*hCloudHandle%s*%)'),
        'the ' .. CAND .. ' hold no longer prices the NIMBUS handle.  Under '
        .. '`zusultx` the reserve subtracts hSpell:GetManaCost(), so a different '
        .. 'handle here silently prices a different spend.')
    assert(body:find('ActionQueue_UseAbilityOnLocation%(%s*hCloudHandle%s*,'),
        'the executor no longer casts the handle the hold priced.  A hold that '
        .. 'prices one handle and an order that casts another is the disagreement '
        .. 'X.GetBoundAbility exists to prevent.')

    -- And the three siblings this lever is defined against.
    local n = 0
    for _ in body:gmatch('X%.zuus_ShouldSaveManaForUlt%s*%(') do n = n + 1 end
    assert(n == 4, 'X.SkillsComplement holds ' .. n .. ' reserve call sites, not 4.  '
        .. 'This file argues that Nimbus was the FOURTH consumer of a pool guarded '
        .. 'at three sites; that sentence is only true at 4.')
end

-- ---------------------------------------------------------------- section 2 --
-- The price asymmetry, off the KV rather than retyped.  A rebalance that moves
-- either cost moves this file's arithmetic instead of leaving it confidently
-- stale.

tests['section 2: Nimbus costs more than a rank-1 Thundergod\'s Wrath'] = function()
    local tCloud = kv_cost(CLOUD)
    local tUlt   = kv_cost(ULT)

    assert(#tCloud == 1, 'zuus_cloud now has a ' .. #tCloud .. '-rank mana ladder; '
        .. 'every "275, flat" sentence in this file and in the source block is '
        .. 'written for a single value.')
    assert(tCloud[1] == 275, 'Nimbus costs ' .. tCloud[1] .. ' now, not 275.')

    assert(#tUlt == 3, "Thundergod's Wrath now has " .. #tUlt .. ' ranks, not 3.')
    assert(tUlt[1] == 250 and tUlt[2] == 375 and tUlt[3] == 500,
        'the ult cost ladder is now ' .. table.concat(tUlt, '/')
        .. ' -- section 3 computes its six window bounds off 250/375/500.')

    assert(tCloud[1] > tUlt[1], 'Nimbus (' .. tCloud[1] .. ') is no longer more '
        .. 'expensive than a rank-1 ult (' .. tUlt[1] .. '), which is the sentence '
        .. 'that makes the unguarded site the LARGEST of the four holes.')

    -- ... and larger than either guarded spend, which is the rest of that sentence.
    for _, sSpell in ipairs({ 'zuus_arc_lightning', 'zuus_lightning_bolt' }) do
        local t = kv_cost(sSpell)
        local nMax = 0
        for _, v in ipairs(t) do if v > nMax then nMax = v end end
        assert(tCloud[1] > nMax, sSpell .. ' now costs up to ' .. nMax
            .. ', at or above Nimbus\'s ' .. tCloud[1] .. '.  "The three guarded '
            .. 'sites hold spends smaller than the unguarded one" is no longer true.')
    end
end

-- ---------------------------------------------------------------- section 3 --
-- The rank arithmetic, DRIVEN through the real helper.  Mana is the one declared
-- injection; the ult handle, its rank, its cooldown and the target all come off
-- the frame.

tests['section 3: the zusult leg has an EMPTY window at ult rank 1, and a real one above'] = function()
    local tCloud, tUlt = kv_cost(CLOUD)[1], kv_cost(ULT)

    -- The arithmetic, stated before it is driven so a driver that silently
    -- stopped exercising the helper cannot satisfy it.
    assert(tCloud > tUlt[1],
        'rank-1 emptiness rests on 275 > 250; it no longer holds.')

    local X, J, bot = on_frame(FRAME, { armed = true })
    local hUlt = bot:GetAbilityByName(ULT)
    local hCloud = bot:GetAbilityByName(CLOUD)
    assert(hUlt:GetLevel() >= 1, FRAME .. "'s Zeus no longer has the ult trained; "
        .. 'the reserve bails on IsTrained and this section drives nothing.')
    assert(hUlt:GetCooldownTimeRemaining() == 0, FRAME .. "'s ult is no longer off "
        .. 'cooldown; same consequence.')
    assert(hUlt:GetManaCost() == tUlt[1], 'the frame serves an ult cost of '
        .. tostring(hUlt:GetManaCost()) .. ', not the rank-1 ' .. tUlt[1])

    local hTarget = healthy_enemy(J, bot)
    assert(hTarget ~= nil, FRAME .. ' no longer holds an enemy hero above the '
        .. 'health floor, so the reserve refuses on the target clause and the '
        .. 'mana clause below is never reached.')

    -- ⚠️ DECLARED INJECTION.  No fixture carries a Zeus at a chosen mana, and the
    -- six bounds below are about mana and nothing else.
    local function holds_at(nMana)
        bot.GetMana = function() return nMana end
        return X.zuus_ShouldSaveManaForUlt(bot, hTarget, hCloud) == true
    end

    -- The liveness guard: the helper must actually answer BOTH ways on this
    -- frame, or every "false" below is a vacuity rather than a reading.
    assert(holds_at(tUlt[1] - 1), 'the reserve does not hold even at mana '
        .. (tUlt[1] - 1) .. ' (one below the ult cost) on ' .. FRAME
        .. '.  Some clause other than mana is refusing; every bound below would '
        .. 'then be false for a reason this section is not about.')
    assert(not holds_at(tUlt[1]), 'the reserve still holds at mana == the ult '
        .. 'cost, where the helper\'s own "still affordable" clause should bail.')

    -- RANK 1, the empty window: a Nimbus bid needs mana >= 275, and at every such
    -- mana the reserve has already bailed.  Driven at the boundary and above it.
    assert(not holds_at(tCloud), 'the reserve HOLDS at mana == the Nimbus cost ('
        .. tCloud .. ') against a rank-1 ult (' .. tUlt[1] .. ').  That would make '
        .. "this lever's zusult leg nonempty at rank 1 and the source block's "
        .. '"structurally unsatisfiable" paragraph wrong.')
    assert(not holds_at(tCloud + 200), 'same, 200 mana higher.')

    -- RANK 2 and RANK 3: the window is [275, cost).  Driven by moving the cost,
    -- which is what a rank-up does.
    for _, nCost in ipairs({ tUlt[2], tUlt[3] }) do
        hUlt.GetManaCost = function() return nCost end
        assert(holds_at(tCloud), 'against an ult costing ' .. nCost .. ' the reserve '
            .. 'does NOT hold at the lowest mana a Nimbus bid can occur at ('
            .. tCloud .. ').  The window [275, ' .. nCost .. ') is this lever\'s '
            .. 'entire zusult-leg domain at that rank.')
        assert(not holds_at(nCost), 'the window does not close at mana == ' .. nCost
            .. ', so its stated width (' .. (nCost - tCloud) .. ') is wrong.')
    end
end

tests['section 3b: zusultx opens a rank-1 window that zusult does not have'] = function()
    local tCloud, nUlt1 = kv_cost(CLOUD)[1], kv_cost(ULT)[1]

    -- Both ids armed: zusultx is read INSIDE the helper, so arming it widens all
    -- four sites together.  That is why it is not named in the zusultd gate.
    local X, J, bot = on_frame(FRAME, { armed = true, also = { 'zusultx' } })
    local hUlt = bot:GetAbilityByName(ULT)
    local hCloud = bot:GetAbilityByName(CLOUD)
    local hTarget = healthy_enemy(J, bot)
    assert(hTarget ~= nil, FRAME .. ' no longer holds a healthy enemy hero')
    assert(hUlt:GetManaCost() == nUlt1, 'the frame no longer serves a rank-1 ult cost')

    -- ⚠️ SECOND DECLARED INJECTION, and it is a loader gap rather than a choice.
    -- This frame's Zeus has no scepter, so its ability array does not name
    -- zuus_cloud and the loader installs no spec for it: the handle answers the
    -- generic ZERO for GetManaCost (tests/mock/bot_api.lua:182, the GH #656
    -- family).  With a zero spend `zusultx` subtracts nothing and is inert, so
    -- the window below would be UNPRICEABLE rather than empty -- a different
    -- sentence from the one this section makes.  The 275 comes from the KV
    -- snapshot, the same place section 2 reads it.
    assert(hCloud:GetManaCost() == 0, 'the frame now serves a real Nimbus mana '
        .. 'cost (' .. tostring(hCloud:GetManaCost()) .. ').  The loader learned '
        .. 'the handle: retire this injection and drive the spend off the frame.')
    hCloud.GetManaCost = function() return tCloud end

    bot.GetMana = function() return tCloud end            -- declared injection
    assert(X.zuus_ShouldSaveManaForUlt(bot, hTarget, hCloud) == true,
        'with zusultx armed the reserve does NOT hold at mana == ' .. tCloud
        .. ' against a rank-1 ult.  Post-spend mana is ' .. (tCloud - tCloud)
        .. ' < ' .. nUlt1 .. ', so it must.  If this is false, "arm zusultd" and '
        .. '"arm zusultd + zusultx" are the same experiment at rank 1 and the '
        .. "source block's warning is empty.")

    -- The upper edge of the widened window, so its stated width is driven too.
    bot.GetMana = function() return nUlt1 + tCloud end
    assert(X.zuus_ShouldSaveManaForUlt(bot, hTarget, hCloud) == false,
        'the widened window does not close at mana == cost + spend ('
        .. (nUlt1 + tCloud) .. ').')
end

-- ---------------------------------------------------------------- section 4 --
-- The retreat branch is exempt, and BOTH of its reasons hold independently.
-- Written as two assertions rather than one because "this branch is exempt" is
-- the sentence a later reader would most like to quote, and a single reason is
-- one refactor away from being the only one.

tests['section 4: the retreat drop is exempt twice over'] = function()
    local body = strip_comments(fn_body(read_file(SRC), 'ConsiderD'))

    -- Reason (1), structural at the SITE: the retreat branch hands back nil.
    assert(body:find('bot:GetLocation%(%s*%)%s*,%s*nil'),
        'X.ConsiderD\'s retreat branch no longer returns nil as its third value.  '
        .. 'If it now names the chaser, self-preservation drops become holdable '
        .. 'the day the helper\'s own retreat clause is refactored away.')

    local X, J, bot = on_frame(FRAME, { armed = true })
    local hCloud = bot:GetAbilityByName(CLOUD)
    bot.GetMana = function() return kv_cost(CLOUD)[1] end   -- declared injection

    assert(X.zuus_ShouldSaveManaForUlt(bot, nil, hCloud) == false,
        'the reserve HOLDS on a nil target.  Reason (1) of the retreat exemption '
        .. 'is gone: X.ConsiderD\'s retreat branch passes nil precisely because '
        .. 'J.IsValidHero( nil ) refuses it.')

    -- Reason (2), independent of the site: the helper's own "fleeing beats
    -- hoarding" clause, driven with a real hero target so nothing else refuses.
    local hTarget = healthy_enemy(J, bot)
    assert(hTarget ~= nil, FRAME .. ' no longer holds a healthy enemy hero')
    local bWasRetreating = J.IsRetreating
    J.IsRetreating = function() return true end
    local bHeld = X.zuus_ShouldSaveManaForUlt(bot, hTarget, hCloud)
    J.IsRetreating = bWasRetreating
    assert(bHeld == false, 'the reserve HOLDS while Zeus is retreating.  Reason (2) '
        .. 'of the retreat exemption is gone.')
end

-- ---------------------------------------------------------------- section 5 --
-- Direction.  Armed, this lever can only ever REMOVE a Nimbus cast.

tests['section 5: the lever is a narrowing -- desire can only go HIGH -> 0'] = function()
    local body = strip_comments(fn_body(read_file(SRC), 'SkillsComplement'))

    local sHold, _, from = gate_condition(body)
    local sBody = body:sub(from):match('then\n(.-)\n\tend')
    assert(sBody, 'the ' .. CAND .. ' gate no longer has a body this file can parse')

    -- The ONLY statement the gate may execute.  A gate that could also RAISE a
    -- desire would make a negative wave reading unattributable.
    local sTrim = sBody:gsub('%s+', ' '):gsub('^ ', ''):gsub(' $', '')
    assert(sTrim == 'castDDesire = 0', 'the ' .. CAND .. ' gate body is now `'
        .. sTrim .. '`, not `castDDesire = 0`.  The narrowing direction is what '
        .. 'lets a negative wave reading be attributed at all; re-argue it before '
        .. 'editing this line.')

    -- And the guard in front of it is `castDDesire > 0`, so the gate is reachable
    -- only from a live bid.
    assert(sHold:find('castDDesire%s*>%s*0'),
        'the ' .. CAND .. ' hold is no longer conditioned on a live Nimbus bid, so '
        .. 'it is being asked on frames that were never going to cast.')
end

-- ---------------------------------------------------------------- section 6 --
-- The corpus domain, as a ONE-WAY TRIPWIRE, with its two causes kept apart.
-- ⛔ These are two different zeroes and merging them is the error this section
--    exists to prevent.

tests['[ratchet] section 6: HasScepter is a loader zero, and the items array is not'] = function()
    -- (1) HARNESS.  Nothing under tests/mock installs HasScepter, so it falls
    -- through bot_api.lua's `^Has -> false` catch-all and X.ConsiderD returns on
    -- its first branch on every frame this repo holds.  Red the day a loader
    -- wires it -- that is the day this lever becomes drivable end to end.
    local nFrames, nScepterGetter = 0, 0
    for _, path in ipairs(ZUUS_FRAMES) do
        local _, _, bot = on_frame(path)
        nFrames = nFrames + 1
        if bot:HasScepter() then nScepterGetter = nScepterGetter + 1 end
    end
    assert(nFrames == #ZUUS_FRAMES, 'frame list drive count mismatch')
    assert(nScepterGetter == 0, nScepterGetter .. ' of ' .. nFrames .. ' Zeus-subject '
        .. 'frames now answer HasScepter() true.  The loader learned the getter: '
        .. "X.ConsiderD's body is reachable on real frames for the first time, so "
        .. 'this lever can be driven end to end instead of at the helper.  Build '
        .. 'that drive rather than editing this number.')

    -- (2) WORLD.  The frames' own `items` arrays -- which that getter does not
    -- consult -- say the branch is NOT unreachable in the game.  This is a
    -- reading off frame data and it is why (1) may not be quoted as "Zeus never
    -- buys a scepter".
    local nRows, nScepterRows = 0, 0
    for _, path in ipairs(ZUUS_FRAMES) do
        local _, _, _, _, fx = on_frame(path)
        for _, u in ipairs(fx.units or {}) do
            if u.name == 'npc_dota_hero_zuus' then
                nRows = nRows + 1
                for _, sItem in ipairs(u.items or {}) do
                    if sItem == 'ultimate_scepter' then nScepterRows = nScepterRows + 1 end
                end
            end
        end
    end
    assert(nRows > 0, 'no npc_dota_hero_zuus rows found across the frame list at all')
    -- A LOWER bound, not an equality: the corpus grows and this must survive it.
    assert(nScepterRows >= 0 and nRows >= #ZUUS_FRAMES,
        'the Zeus row census collapsed (' .. nScepterRows .. '/' .. nRows .. ')')

    -- ⚠️ UNRESOLVED_HAND_READ (GH #803).  The wider census -- 5 of 71 Zeus rows
    -- across tests/fixtures + tests/frames carry item_ultimate_scepter (7.0%),
    -- all five at hero level 23-28 with 1120-2745 mana against a rank-3 cost of
    -- 500 -- was taken once, on this machine, with a python sweep over the same
    -- files.  It is quoted in the source block as a LOWER bound on reachability
    -- and an upper bound on this corpus's usable domain, never as an equality.
end

-- ---------------------------------------------------------------- section 7 --
-- The gate shape.  The pullcad trap (AGENTS.md) written as a test rather than as
-- a promise in a comment.

tests['[ratchet] section 7: the zusultd gate is turbo-only and names only its own id'] = function()
    local src = read_file(SRC)

    local nSites = 0
    for _ in src:gmatch("IsSoakCandidate%(%s*'" .. CAND .. "'%s*%)") do nSites = nSites + 1 end
    assert(nSites == 1, 'the file holds ' .. nSites .. ' call sites for ' .. CAND
        .. '; a soak candidate with two of them cannot be reasoned about as one lever.')

    local sCond = gate_condition(strip_comments(fn_body(src, 'SkillsComplement')))
    assert(sCond:find('IsModeTurbo', 1, true),
        'the ' .. CAND .. ' gate is no longer turbo-only: ' .. sCond)

    local nOther = 0
    for sId in sCond:gmatch("IsSoakCandidate%(%s*'(%w+)'%s*%)") do
        if sId ~= CAND then nOther = nOther + 1 end
    end
    assert(nOther == 0, 'the ' .. CAND .. ' gate names ' .. nOther .. ' other candidate '
        .. 'id(s) in its own condition.  That is the pullcad trap: the day the other '
        .. 'id is promoted this gate freezes FALSE and check_armed_wiring.py still '
        .. 'calls it WIRED.  `zusult` is PROMOTED already, so naming it here would '
        .. 'freeze this lever FALSE on the day it lands.')
end

return tests

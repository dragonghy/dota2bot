-- [hero] [ratchet] Zeus's ult-mana reserve is wired at four of the FIVE places
-- his mana leaves X.SkillsComplement, and the fifth is the LAST arm of the
-- dispatch -- i.e. the sink every held bid above it falls into.  Landed as
-- turbo-only soak candidate `zusulte`.
--
-- THE GAP THIS FILE CLOSES
-- ------------------------
-- X.zuus_ShouldSaveManaForUlt exists to stop Zeus spending the mana his global
-- finisher is waiting on.  It is consulted at ConsiderW, ConsiderW2, ConsiderQ
-- and (since `zusultd`) ConsiderD.  X.ConsiderE -- Heavenly Jump -- is
-- dispatched after all four, out of the same pool, in the same call, and is
-- asked nothing.
--
-- GH #47 is the precedent and it is a measurement rather than an analogy: a
-- reserve wired to a strict SUBSET of a pool's consumers does not narrow the
-- spend, it RELOCATES it.  There the held ConsiderW bid walked out through
-- ConsiderW2 on the next line and spent the identical mana on the identical
-- target.  This site is the bottom of the same chain, and there is no sixth arm
-- below it (section 1 drives that ordering rather than asserting it).
--
-- ⭐⭐ AND THIS SITE IS NOT AN ANALOGY TO THE FOUNDING INCIDENT EITHER -- IT IS
-- HALF OF IT, WORD FOR WORD.  The `zusult` note in hero_zuus.lua names the
-- watched game: 20260819_142047_slot1, Zeus dinged 6 holding 55 mana, then
-- "spent 94 on Arc Lightning (t=225.5) and 49 on Heavenly Jump (t=241.5), both
-- into a dragon_knight sitting at 971/1072 HP".  Arc Lightning is ConsiderQ,
-- guarded since GH #47.  The other half of that sentence is THIS dispatch.
-- Section 6 pins that the corpus's two frames from that very game are the
-- frames where this lever's domain lives, and that the dragon_knight is one of
-- the targets held.
--
-- ⭐ THE WINDOW ARITHMETIC RUNS THE OTHER WAY FROM `zusultd`, AND THAT IS THE
-- SHARPEST THING HERE.  A bid needs its own spell IsFullyCastable (mana >= its
-- cost); the reserve needs mana < the ult's cost; so the window is
-- [spell cost, ult cost).  For Nimbus that is [275, 250) at rank 1 -- EMPTY, as
-- tests/test_zuus_nimbus_ult_reserve.lua section 3 drives.  For Heavenly Jump
-- it is [50..80, 250..500) -- NONEMPTY AT EVERY RANK PAIRING, width 170..450.
-- Section 2 computes all of it off the KV snapshot instead of retyping it.
-- ⚠️ That cuts both ways and this file does not pick a side: widest window also
-- means smallest mana saved per refusal (50..80, against a Bolt's ~130 and a
-- Nimbus's 275).  Which dominates is a corpus question -- queue.json hero-95.
--
-- WHAT IS PINNED, AND WHY IN THIS ORDER
--   1. the conjunct is WIRED, at the ATTACKING firing point and nowhere else,
--      and the four sibling sites are still guarded -- otherwise "the fifth
--      consumer" describes nothing.
--   2. the window arithmetic, PARSED off tests/mock/special_value_shapes.lua.
--   3. the window DRIVEN through the real helper on a real frame, with mana as
--      the one declared injection, plus a liveness guard.
--   4. the retreat firing point's EXEMPTION, both of its independent reasons.
--   5. the DIRECTION: armed, the attacking bid can only go HIGH -> NONE, driven
--      over every Zeus-subject frame in the repo.
--   6. the corpus domain as a ONE-WAY TRIPWIRE, with the helper-level reading
--      and the end-to-end zero kept apart and the zero's cause named.
--   7. the gate shape (turbo-only, one id, its own, call-time -- pullcad trap).
--
-- ⚠️ WHAT THIS FILE DOES NOT BUY.  It does not show the armed leg changing
-- X.ConsiderE's answer on a real frame, and it CANNOT: section 6.2 drives that
-- `J.IsGoingOnSomeone` is structurally false on every frame this repo holds,
-- because it reads `GetActiveMode()` and the loader answers the generic `^Get`
-- zero -- and 0 is not a member of the BOT_MODE namespace at all (the constants
-- start at 1001).  That is the `-185` ruling verbatim: a reading of 0 taken on
-- an instrument with no positive control anywhere is UNASKABLE, not a domain.
-- Condition (a) is UNBOUGHT and the request is iterations/queue.json hero-95.
-- Nothing here argues for arming, promoting or retiring `zusulte`; the id is
-- gated and unarmed, so every shipped game jumps exactly as before.

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')

local SRC   = 'bots/BotLib/hero_zuus.lua'
local SHAPE = 'tests/mock/special_value_shapes.lua'
local CAND  = 'zusulte'
local HELP  = 'zuus_IsJumpChipHeldForUlt'
local ULT   = 'zuus_thundergods_wrath'
local JUMP  = 'zuus_heavenly_jump'

-- The frame section 3 drives: a Zeus from the founding incident's own game with
-- the ult trained at rank 1, cooldown 0, and mana BELOW the ult cost -- i.e.
-- every clause of the reserve except the mana bound is satisfied by frame data.
local FRAME = 'tests/fixtures/f_260819_142047_zuus_ult_denied.lua'

-- Every Zeus-SUBJECT frame in the repo, listed rather than globbed so a new one
-- is a deliberate edit and section 6's counts move with a named cause.  (Same
-- reason tests/test_zuus_nimbus_ult_reserve.lua lists its nine; this list adds
-- the two later fixtures and the eight tests/frames/ bodies.)
local ZUUS_FRAMES = {
    'tests/fixtures/f_072738_zuus_mana.lua',
    'tests/fixtures/f_073148_zuus_lina.lua',
    'tests/fixtures/f_163714_zuus_commit_pin.lua',
    'tests/fixtures/f_181441_zuus_lowhp_limbo.lua',
    'tests/fixtures/f_20260827_091703_slot12_zuus_473_1.lua',
    'tests/fixtures/f_230952_zuus_ult_hoard.lua',
    'tests/fixtures/f_260819_142047_zuus_ult_denied.lua',
    'tests/fixtures/f_260819_142047_zuus_ult_manalock.lua',
    'tests/fixtures/f_260819_222052_zuus_w2_leak.lua',
    'tests/fixtures/f_260820_042607_zuus_reserve_cross.lua',
    'tests/fixtures/f_260820_042607_zuus_reserve_safe.lua',
    'tests/frames/f_260909_215227_zeus_arc_od_79.lua',
    'tests/frames/f_260909_215227_zeus_bolt_od_1084.lua',
    'tests/frames/f_260909_215227_zeus_bolt_wk_434.lua',
    'tests/frames/f_260909_215227_zeus_exec_od_1467.lua',
    'tests/frames/f_260909_215227_zeus_exec_wk_615.lua',
    'tests/frames/f_260909_215227_zeus_jump_283.lua',
    'tests/frames/f_260909_215227_zeus_ult_1008.lua',
    'tests/frames/f_260909_215227_zeus_ult_396.lua',
}

-- Measured 2026-09-16 on the list above.  These are not targets, they are the
-- readings this file's prose quotes; a move means re-read the prose.
local N_FRAMES       = 19
local N_DOMAIN_FRAME = 3    -- frames holding >= 1 enemy
local N_DOMAIN_PAIR  = 12   -- (frame, enemy) pairs held

local tests = {}

local function read_file(path)
    local fh = assert(io.open(path, 'r'), 'cannot open ' .. path)
    local body = fh:read('*a')
    fh:close()
    return body
end

--- Comments stripped, so a ratchet counting code shapes cannot be satisfied by
--- prose that merely quotes the expression -- and this lever's own header block
--- quotes several of the spellings counted below on purpose.
local function strip_comments(body)
    return (body:gsub('%-%-[^\n]*', ''))
end

--- A function's body, cut at column-0 `end` rather than at the next
--- `function X.` -- the latter swallows the NEXT function's header comment,
--- which makes any "this string is NOT here" assertion wrong.  (That trap cost
--- a round in tools/agent/mutstand_axecullbm.sh; recorded there, reused here.)
local function fn_code(src, name)
    local from = src:find('\nfunction%s+X%.' .. name .. '%s*%(')
    assert(from, 'X.' .. name .. ' not found in ' .. SRC)
    local rest = src:sub(from + 1)
    local to = assert(rest:find('\nend\n'), 'X.' .. name .. ' has no closing end')
    return strip_comments(rest:sub(1, to))
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

--- Load one real frame.  The arming table is returned so a caller can flip the
--- gate WITHOUT paying a second frame load: `zusulte` is read at CALL time
--- inside X.zuus_IsJumpChipHeldForUlt, never at module scope (section 7.2
--- drives exactly that, so this shortcut cannot silently become wrong).
local function on_frame(path)
    local tArmed = {}
    local J, bot, heroes, fx = rf.load(path)
    J.IsSoakCandidate = function(id) return tArmed[id] == true end
    local X = rf.load_hero('zuus')
    return X, J, bot, tArmed, heroes, fx
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
-- The conjunct is wired, at ONE firing point, and the siblings still are.
-- These going red mean "re-read the file", never "the test is stale".

tests['section 1.1: the conjunct sits on X.ConsiderE\'s ATTACKING branch only'] = function()
    local body = fn_code(read_file(SRC), 'ConsiderE')

    local n = select(2, body:gsub('X%.' .. HELP .. '%s*%(', ''))
    assert(n == 1, 'X.' .. HELP .. ' is called at ' .. n .. ' points inside '
        .. 'X.ConsiderE, not 1.  At 0 the lever is unwired and measures nothing '
        .. 'while check_armed_wiring.py still calls it WIRED; at 2 the retreat '
        .. 'firing point is routed through it too and section 4.1 -- which is '
        .. 'this file\'s whole "fleeing is untouched" claim -- is void.')

    -- ...and it is the LAST conjunct of the targeted branch, fed that branch's
    -- own target and the jump handle.  A different handle here would silently
    -- price a different spend under `zusultx` and still read as wired.
    assert(body:find('and%s+not%s+X%.' .. HELP
        .. '%(%s*bot%s*,%s*targetHero%s*,%s*abilityE%s*%)'),
        'the ' .. CAND .. ' conjunct no longer reads '
        .. '`and not X.' .. HELP .. '( bot, targetHero, abilityE )`.  The '
        .. 'negation, the branch\'s own targetHero and the jump handle are three '
        .. 'separate things this file leans on: drop the `not` and the lever '
        .. 'INVERTS (section 5 is the tripwire), pass another hero and the '
        .. 'reserve prices a target the bid is not about, pass another handle '
        .. 'and `zusultx` subtracts the wrong cost.')

    -- The retreat branch fires BEFORE the targeted one, and is not routed here.
    local iRetreat = assert(body:find('zuus_FindRetreatJumpThreat'),
        'the retreat firing point is gone from X.ConsiderE')
    local iHold = assert(body:find('X%.' .. HELP))
    assert(iRetreat < iHold, 'the retreat firing point now sits AFTER the '
        .. CAND .. ' conjunct.  It returns before the conjunct is reached today, '
        .. 'which is half of why section 4.1 holds.')
end

tests['section 1.2: the four sibling reserve sites are still guarded'] = function()
    local body = fn_code(read_file(SRC), 'SkillsComplement')
    local n = select(2, body:gsub('X%.zuus_ShouldSaveManaForUlt%s*%(', ''))
    assert(n == 4, 'X.SkillsComplement holds ' .. n .. ' reserve call sites, not '
        .. '4.  This file argues Heavenly Jump was the FIFTH consumer of a pool '
        .. 'guarded at four dispatch sites; that sentence is only true at 4.')

    -- And X.ConsiderE really is the last arm, which is what makes this site the
    -- sink rather than just another hole.  Driven off the dispatch order.
    local iE = assert(body:find('X%.ConsiderE%s*%('), 'the X.ConsiderE dispatch is gone')
    for _, sOther in ipairs({ 'ConsiderR', 'ConsiderW', 'ConsiderW2', 'ConsiderQ', 'ConsiderD' }) do
        local i = assert(body:find('X%.' .. sOther .. '%s*%('), sOther .. ' dispatch is gone')
        assert(i < iE, sOther .. ' is now dispatched AFTER X.ConsiderE.  The '
            .. '"sink" argument is exactly the claim that nothing spends this '
            .. 'pool below the jump.')
    end
end

-- ---------------------------------------------------------------- section 2 --
-- The window arithmetic, off the KV rather than retyped.  A rebalance that
-- moves either ladder moves this file instead of leaving it confidently stale.

tests['section 2: the jump window is nonempty at EVERY rank pairing'] = function()
    local tJump = kv_cost(JUMP)
    local tUlt  = kv_cost(ULT)

    assert(#tJump == 4, 'Heavenly Jump now has a ' .. #tJump .. '-rank mana '
        .. 'ladder; every "50/60/70/80" sentence here is written for four.')
    assert(tJump[1] == 50 and tJump[4] == 80, 'the jump cost ladder is now '
        .. table.concat(tJump, '/') .. ', not 50/60/70/80.')
    assert(#tUlt == 3 and tUlt[1] == 250 and tUlt[3] == 500,
        'the ult cost ladder is now ' .. table.concat(tUlt, '/') .. ', not 250/375/500.')

    -- 12 pairings, all nonempty.  This is the contrast with `zusultd`, whose
    -- rank-1 window is empty because 275 > 250.
    local nMin, nMax
    for _, nJ in ipairs(tJump) do
        for _, nU in ipairs(tUlt) do
            assert(nJ < nU, 'the jump costs ' .. nJ .. ' against an ult costing '
                .. nU .. ', so the window [' .. nJ .. ', ' .. nU .. ') is EMPTY '
                .. 'and this lever has no domain at that pairing.  The header '
                .. 'says "nonempty at every rank pairing".')
            local w = nU - nJ
            if nMin == nil or w < nMin then nMin = w end
            if nMax == nil or w > nMax then nMax = w end
        end
    end
    assert(nMin == 170 and nMax == 450, 'the window widths now run ' .. nMin
        .. '..' .. nMax .. ', not 170..450 -- the header quotes those two.')

    -- The other half of the header's honest bound: this is the SMALLEST spend
    -- of the wired sites, which is the argument against the lever, stated here
    -- so it cannot quietly stop being true.
    for _, sSpell in ipairs({ 'zuus_arc_lightning', 'zuus_lightning_bolt', 'zuus_cloud' }) do
        local nMaxCost = 0
        for _, v in ipairs(kv_cost(sSpell)) do if v > nMaxCost then nMaxCost = v end end
        assert(tJump[4] < nMaxCost, 'Heavenly Jump now costs up to ' .. tJump[4]
            .. ', at or above ' .. sSpell .. '\'s ' .. nMaxCost .. '.  "The '
            .. 'widest window holds the smallest spend" is no longer true and '
            .. 'the header\'s both-ways paragraph needs rewriting, not relaxing.')
    end
end

-- ---------------------------------------------------------------- section 3 --
-- The window DRIVEN through the real helper on a real frame.  Mana is the one
-- declared injection; the ult handle, its rank, its cooldown and the target all
-- come off the frame.

tests['section 3: the window is driven on a real frame, with a liveness guard'] = function()
    local nUlt1 = kv_cost(ULT)[1]
    local X, J, bot, tArmed = on_frame(FRAME)
    tArmed[CAND] = true

    local hUlt  = bot:GetAbilityByName(ULT)
    local hJump = bot:GetAbilityByName(JUMP)
    assert(hUlt:GetLevel() >= 1, FRAME .. "'s Zeus no longer has the ult trained; "
        .. 'the reserve bails on IsTrained and this section drives nothing.')
    assert(hUlt:GetCooldownTimeRemaining() == 0, FRAME .. "'s ult is no longer "
        .. 'off cooldown; same consequence.')
    assert(hUlt:GetManaCost() == nUlt1, 'the frame serves an ult cost of '
        .. tostring(hUlt:GetManaCost()) .. ', not the rank-1 ' .. nUlt1)
    assert(hJump:IsFullyCastable(), FRAME .. "'s Zeus can no longer cast Heavenly "
        .. 'Jump, so X.ConsiderE returns NONE on its first line and every bound '
        .. 'below is about a bid that could not happen.')

    local hTarget = healthy_enemy(J, bot)
    assert(hTarget ~= nil, FRAME .. ' no longer holds an enemy hero above the '
        .. 'health floor, so the reserve refuses on the target clause and the '
        .. 'mana clause below is never reached.')

    -- ⚠️ DECLARED INJECTION.  No fixture carries a Zeus at a chosen mana, and
    -- the bounds below are about mana and nothing else.
    local function holds_at(nMana)
        bot.GetMana = function() return nMana end
        return X.zuus_IsJumpChipHeldForUlt(bot, hTarget, hJump) == true
    end

    -- LIVENESS: the helper must answer BOTH ways on this frame, or every
    -- `false` below is a vacuity rather than a reading.
    assert(holds_at(nUlt1 - 1), 'the hold does not fire even at mana '
        .. (nUlt1 - 1) .. ' (one below the ult cost) on ' .. FRAME .. '.  Some '
        .. 'clause other than mana is refusing; every bound below would then be '
        .. 'false for a reason this section is not about.')
    assert(not holds_at(nUlt1), 'the hold still fires at mana == the ult cost, '
        .. 'where the reserve\'s own "still affordable" clause should bail.')

    -- The window's LOWER bound is the jump's own cost, because below it there is
    -- no bid to hold.  Driven at the boundary, at rank 1 and at rank 3.
    local tJump = kv_cost(JUMP)
    for _, nJ in ipairs({ tJump[1], tJump[4] }) do
        hJump.GetManaCost = function() return nJ end
        for _, nU in ipairs({ nUlt1, kv_cost(ULT)[3] }) do
            hUlt.GetManaCost = function() return nU end
            assert(holds_at(nJ), 'against an ult costing ' .. nU .. ' the hold '
                .. 'does NOT fire at the lowest mana a jump bid can occur at ('
                .. nJ .. ').  [' .. nJ .. ', ' .. nU .. ') is this lever\'s '
                .. 'entire domain at that pairing.')
            assert(not holds_at(nU), 'the window does not close at mana == '
                .. nU .. ', so its stated width (' .. (nU - nJ) .. ') is wrong.')
        end
    end
end

tests['section 3b: zusultx is nearly inert HERE, and that is arithmetic'] = function()
    local nUlt1 = kv_cost(ULT)[1]
    local X, J, bot, tArmed = on_frame(FRAME)
    tArmed[CAND] = true
    tArmed['zusultx'] = true

    local hUlt  = bot:GetAbilityByName(ULT)
    local hJump = bot:GetAbilityByName(JUMP)
    local hTarget = healthy_enemy(J, bot)
    assert(hTarget ~= nil, FRAME .. ' no longer holds a healthy enemy hero')

    local nSpend = hJump:GetManaCost()
    assert(type(nSpend) == 'number' and nSpend > 0, FRAME .. "'s jump handle "
        .. 'answers ' .. tostring(nSpend) .. ' for GetManaCost, so `zusultx` '
        .. 'subtracts nothing and this section would read UNPRICEABLE rather '
        .. 'than narrow -- a different claim (the GH #656 family).')

    local function holds_at(nMana)
        bot.GetMana = function() return nMana end
        return X.zuus_IsJumpChipHeldForUlt(bot, hTarget, hJump) == true
    end

    -- The widened band is exactly [ult cost, ult cost + spend): inside it the
    -- post-spend leg holds where the plain one does not.
    assert(holds_at(nUlt1 + nSpend - 1), '`zusultx` does not hold one mana below '
        .. 'the top of its own band [' .. nUlt1 .. ', ' .. (nUlt1 + nSpend)
        .. '), so the band is not what the header says it is.')
    assert(not holds_at(nUlt1 + nSpend), '`zusultx` still holds AT the top of '
        .. 'its band, so the band is wider than ' .. nSpend .. ' mana.')

    -- ...and that band is narrower than the ones the other wired sites carry,
    -- which is the whole "do not quote a zusultx read from there about here".
    for _, sSpell in ipairs({ 'zuus_lightning_bolt', 'zuus_cloud' }) do
        local nMaxCost = 0
        for _, v in ipairs(kv_cost(sSpell)) do if v > nMaxCost then nMaxCost = v end end
        assert(nSpend < nMaxCost, 'the jump now spends ' .. nSpend .. ', at or '
            .. 'above ' .. sSpell .. '\'s ' .. nMaxCost .. '; `zusultx` is no '
            .. 'longer narrower here than there.')
    end
end

-- ---------------------------------------------------------------- section 4 --
-- The retreat exemption, both of its independent reasons.  Either alone would
-- do; this file leans on both because one of them is a source-layout fact and
-- the next group is allowed to change source layout.

tests['section 4.1: fleeing is exempt because the reserve itself says so'] = function()
    local X, J, bot, tArmed = on_frame(FRAME)
    tArmed[CAND] = true
    local hJump = bot:GetAbilityByName(JUMP)
    local hTarget = healthy_enemy(J, bot)
    assert(hTarget ~= nil, FRAME .. ' no longer holds a healthy enemy hero')

    -- Put mana inside the window so the hold is otherwise live...
    bot.GetMana = function() return kv_cost(ULT)[1] - 1 end
    assert(X.zuus_IsJumpChipHeldForUlt(bot, hTarget, hJump) == true,
        'the hold is not live on this frame even inside the window, so the '
        .. 'retreat flip below proves nothing.')

    -- ...then declare retreat.  "Fleeing beats hoarding" is the reserve's own
    -- sentence and this lever must not be able to overrule it.
    local fWas = J.IsRetreating
    J.IsRetreating = function() return true end
    local bHeld = X.zuus_IsJumpChipHeldForUlt(bot, hTarget, hJump)
    J.IsRetreating = fWas
    assert(bHeld == false, 'the hold fires on a RETREATING Zeus.  Even if a '
        .. 'future reader routes X.ConsiderE\'s retreat firing point through '
        .. 'this helper, the escape must survive -- that is reason (2) in the '
        .. 'lever\'s header and it belongs to X.zuus_ShouldSaveManaForUlt.')
end

tests['section 4.2: and because the retreat branch is not routed through it'] = function()
    -- Reason (1), a source fact: the retreat firing point returns before the
    -- conjunct exists.  Section 1.1 pins the ordering; here we pin that the
    -- retreat branch carries no target expression the conjunct could be fed.
    local body = fn_code(read_file(SRC), 'ConsiderE')
    local iRetreat = assert(body:find('J%.IsRetreating%s*%(%s*bot%s*%)'),
        'X.ConsiderE no longer branches on J.IsRetreating')
    local iGoing = assert(body:find('J%.IsGoingOnSomeone%s*%(%s*bot%s*%)'),
        'X.ConsiderE no longer branches on J.IsGoingOnSomeone')
    assert(iRetreat < iGoing, 'the retreat branch no longer precedes the '
        .. 'attacking one')

    local sRetreatBlock = body:sub(iRetreat, iGoing)
    assert(not sRetreatBlock:find('X%.' .. HELP),
        'the ' .. CAND .. ' conjunct has moved into the RETREAT block.  Reason '
        .. '(1) of the exemption is gone; only reason (2) is left and section '
        .. '4.1 becomes load-bearing on its own.')
    assert(not sRetreatBlock:find('targetHero'),
        'the retreat block now names targetHero.  This file states the retreat '
        .. 'branch "hands no target to anybody"; that is what makes routing it '
        .. 'through a hero-target reserve structurally impossible rather than '
        .. 'merely absent.')
end

-- ---------------------------------------------------------------- section 5 --
-- DIRECTION.  Armed, the attacking bid can only go HIGH -> NONE.  Driven over
-- every Zeus-subject frame rather than argued from the `not`.

tests['section 5.1: as recorded, no frame moves -- and that is 6.2\'s zero'] = function()
    local nSeen, nShippedHigh, nArmedHigh = 0, 0, 0
    for _, path in ipairs(ZUUS_FRAMES) do
        local X, J, bot, tArmed = on_frame(path)
        assert(bot:GetUnitName() == 'npc_dota_hero_zuus',
            path .. ' is no longer a Zeus-subject frame; this list is the '
            .. 'denominator of sections 5 and 6.')
        nSeen = nSeen + 1

        tArmed[CAND] = nil
        local nShipped = X.ConsiderE()
        tArmed[CAND] = true
        local nArmed = X.ConsiderE()

        if nShipped > 0 then nShippedHigh = nShippedHigh + 1 end
        if nArmed > 0 then nArmedHigh = nArmedHigh + 1 end
        assert(nArmed <= nShipped, path .. ': armed X.ConsiderE bids ' .. nArmed
            .. ' where shipped bids ' .. nShipped .. '.')
    end
    assert(nSeen == N_FRAMES, 'the Zeus-subject corpus is ' .. nSeen
        .. ' frames, recorded ' .. N_FRAMES .. '.  Frames were added or removed; '
        .. 're-read every count in this file before quoting one.')
    assert(nArmedHigh == nShippedHigh, 'shipped bids on ' .. nShippedHigh
        .. ' frames and armed on ' .. nArmedHigh .. '.  Section 6.2 records this '
        .. 'end-to-end difference as ZERO with a named cause; if it is nonzero '
        .. 'now, that cause is gone and 6.2 must be rewritten, not relaxed.')
    -- ⛔ AND THIS SECTION ON ITS OWN PROVES NOTHING ABOUT DIRECTION.  Both legs
    -- bid NONE on every frame because J.IsGoingOnSomeone is structurally false
    -- (6.2), so `armed <= shipped` here is 0 <= 0 nineteen times: a mutant that
    -- DROPPED the `not` would sail through it.  5.2 is the direction tripwire.
end

tests['section 5.2: counterfactual -- armed narrows, and only narrows'] = function()
    -- ⚠️ DECLARED COUNTERFACTUAL, and it is the only way to ask this offline.
    -- Two getters are injected: J.IsGoingOnSomeone (the dump cannot carry the
    -- bot's mode, 6.2) and J.GetProperTarget (which reads GetTarget /
    -- GetAttackTarget, both handle-getters the loader answers with nil).  The
    -- TARGET ITSELF is the frame's own healthiest visible enemy hero -- a real
    -- body at its recorded health, not a fabricated one -- and everything the
    -- decision then turns on (mana, ult rank, ult cooldown, jump castability,
    -- distances, that enemy's health) comes off the frame untouched.
    -- ⛔ So the READINGS below are counterfactual and are labelled as such
    -- wherever the report quotes them; what is NOT counterfactual is the
    -- INEQUALITY, which is the thing this section exists to pin.
    local nLive, nFlip, sFlip, nAffordableHeld = 0, 0, nil, 0
    for _, path in ipairs(ZUUS_FRAMES) do
        local X, J, bot, tArmed = on_frame(path)
        local hPick
        for _, h in ipairs(J.GetNearbyHeroes(bot, 100000, true, BOT_MODE_NONE) or {}) do
            if J.IsValidHero(h) and (hPick == nil or J.GetHP(h) > J.GetHP(hPick)) then
                hPick = h
            end
        end
        J.IsGoingOnSomeone = function() return true end
        J.GetProperTarget = function() return hPick end

        tArmed[CAND] = nil
        local nShipped = X.ConsiderE()
        tArmed[CAND] = true
        local nArmed = X.ConsiderE()

        assert(nArmed <= nShipped, path .. ': armed X.ConsiderE bids ' .. nArmed
            .. ' where shipped bids ' .. nShipped .. '.  This lever is a '
            .. 'NARROWING by construction -- a frame that GAINS a jump means the '
            .. '`not` in section 1.1 was dropped or inverted, and every "the only '
            .. 'thing a negative wave can mean" sentence in the header is wrong.')
        if nShipped > 0 then
            nLive = nLive + 1
            if nArmed < nShipped then
                nFlip = nFlip + 1; sFlip = path
            else
                -- The negative control: a shipped bid the reserve LETS THROUGH.
                local hUlt = bot:GetAbilityByName(ULT)
                if bot:GetMana() >= hUlt:GetManaCost() then
                    nAffordableHeld = nAffordableHeld + 1
                end
            end
        end
    end

    -- LIVENESS: without this the inequality above is 0 <= 0 all the way down,
    -- exactly as it is in 5.1.
    assert(nLive == 2, 'the counterfactual puts a shipped jump bid on ' .. nLive
        .. ' frames, recorded 2.  At 0 this section is as vacuous as 5.1 and the '
        .. 'direction is unpinned; at any other number re-read the report.')
    assert(nFlip == 1, 'armed changes the answer on ' .. nFlip .. ' of those, '
        .. 'recorded 1.  ⛔ TRIPWIRE, not a bar.')
    assert(sFlip == 'tests/fixtures/f_260819_222052_zuus_w2_leak.lua',
        'the frame the lever moves is now ' .. tostring(sFlip) .. '.  The report '
        .. 'names f_260819_222052_zuus_w2_leak (Zeus 152/812 mana, ult rank 1 '
        .. 'ready at 250, a shadow_shaman at full health) as the chip case.')

    -- ⭐ AND THE FRAME IT DOES NOT MOVE IS THE NEGATIVE CONTROL, for a reason
    -- the reserve itself states: that Zeus can already afford the ult, so
    -- "nothing is being denied".  Without it, "1 of 2" could equally mean the
    -- helper answers true at random.
    assert(nAffordableHeld == 1, 'the counterfactual\'s un-moved shipped bid is '
        .. 'no longer explained by "mana >= ult cost" (' .. nAffordableHeld
        .. ' of them are).  Something else is now refusing, and this section\'s '
        .. 'negative control is measuring that instead.')
end

-- ---------------------------------------------------------------- section 6 --
-- The corpus domain, as a ONE-WAY TRIPWIRE, with the two readings kept apart.
-- ⛔ The helper-level number is NOT a frequency: these frames were cut for other
-- investigations (the reserve's own, mostly), so they are enriched for exactly
-- the state this lever is about.  hero-95 buys the frequency.

tests['section 6.1: helper-level domain, and the founding incident is in it'] = function()
    local nFrames, nPairs, tWhere = 0, 0, {}
    for _, path in ipairs(ZUUS_FRAMES) do
        local X, J, bot, tArmed = on_frame(path)
        tArmed[CAND] = true
        local hJump = bot:GetAbilityByName(JUMP)
        local nHere = 0
        for _, h in ipairs(J.GetNearbyHeroes(bot, 100000, true, BOT_MODE_NONE) or {}) do
            if J.IsValidHero(h) and X.zuus_IsJumpChipHeldForUlt(bot, h, hJump) then
                nHere = nHere + 1
            end
        end
        if nHere > 0 then
            nFrames = nFrames + 1
            nPairs = nPairs + nHere
            tWhere[path] = nHere
        end
    end

    assert(nFrames == N_DOMAIN_FRAME and nPairs == N_DOMAIN_PAIR,
        'the helper-level domain is now ' .. nFrames .. ' frames / ' .. nPairs
        .. ' (frame, enemy) pairs, recorded ' .. N_DOMAIN_FRAME .. ' / '
        .. N_DOMAIN_PAIR .. '.  ⛔ This is a TRIPWIRE, not a bar: re-derive the '
        .. 'number and rewrite the report that quotes it -- do not move the '
        .. 'constant to match.')

    -- ⭐ And the domain is not anonymous.  Both frames from 20260819_142047 --
    -- the game the `zusult` note names, the one where the watched Zeus spent 49
    -- mana on Heavenly Jump into a healthy dragon_knight -- are in it.
    assert(tWhere['tests/fixtures/f_260819_142047_zuus_ult_denied.lua'],
        'the founding incident\'s own frame is no longer in this lever\'s '
        .. 'domain.  The header\'s "half of it, word for word" paragraph rests '
        .. 'on exactly that.')
    assert(tWhere['tests/fixtures/f_260819_142047_zuus_ult_manalock.lua'],
        'the second frame from 20260819_142047 left the domain; same paragraph.')

    -- ...and the dragon_knight named in that sentence is one of the held ones.
    local X, J, bot, tArmed = on_frame('tests/fixtures/f_260819_142047_zuus_ult_denied.lua')
    tArmed[CAND] = true
    local hJump = bot:GetAbilityByName(JUMP)
    local bDK = false
    for _, h in ipairs(J.GetNearbyHeroes(bot, 100000, true, BOT_MODE_NONE) or {}) do
        if h:GetUnitName() == 'npc_dota_hero_dragon_knight'
            and X.zuus_IsJumpChipHeldForUlt(bot, h, hJump)
        then bDK = true end
    end
    assert(bDK, 'the dragon_knight the founding sentence names is no longer held '
        .. 'on that frame.  Either his health crossed X.nUltSaveHealthFloor or '
        .. 'the frame changed; the header quotes him by name.')
end

tests['section 6.2: the end-to-end zero is UNASKABLE, and here is why'] = function()
    -- ⛔ This is the `-185` ruling applied: a 0 read on an instrument that has
    -- NO positive control anywhere in the corpus is not a reading.  The proof
    -- is cheaper than a census here -- the value the loader serves is not even
    -- in the namespace the predicate compares against.
    local tModes = { BOT_MODE_ROAM, BOT_MODE_TEAM_ROAM, BOT_MODE_GANK,
                     BOT_MODE_ATTACK, BOT_MODE_DEFEND_ALLY }
    for _, path in ipairs({ FRAME, 'tests/frames/f_260909_215227_zeus_jump_283.lua' }) do
        local X, J, bot = on_frame(path)
        local nMode = bot:GetActiveMode()
        for _, m in ipairs(tModes) do
            assert(nMode ~= m, path .. ': GetActiveMode() now answers a REAL '
                .. 'BOT_MODE (' .. tostring(nMode) .. ').  J.IsGoingOnSomeone '
                .. 'can be true, so the end-to-end zero this file records is no '
                .. 'longer a harness artefact -- re-measure it and rewrite the '
                .. 'header, and tell hero-95 its question got cheaper.')
        end
        assert(J.IsGoingOnSomeone(bot) == false, path .. ': J.IsGoingOnSomeone '
            .. 'is true while GetActiveMode answers something outside the mode '
            .. 'namespace.  Two readings of the same fact just disagreed.')
    end

    -- The positive control the `-185` ruling demands: name the cause rather
    -- than the symptom.  `GetActiveMode` is on no spec under tests/mock, so it
    -- falls through bot_api.lua's generic `^Get -> 0`, and no BOT_MODE_* is 0.
    for _, m in ipairs(tModes) do
        assert(m ~= 0, 'a BOT_MODE constant is 0 now, so the generic `^Get` '
            .. 'default is indistinguishable from a real mode and the argument '
            .. 'above collapses.')
    end
end

-- ---------------------------------------------------------------- section 7 --
-- The gate shape: turbo-only, one id, its own, and read at CALL time.

tests['section 7.1: turbo-only, and the gate names exactly one id'] = function()
    local body = fn_code(read_file(SRC), HELP)

    assert(body:find('J%.IsModeTurbo%s*%(%s*%)'),
        'X.' .. HELP .. ' no longer asks J.IsModeTurbo.  Every behaviour change '
        .. 'in this repo ships turbo-only.')
    assert(body:find("J%.IsSoakCandidate%(%s*'" .. CAND .. "'%s*%)"),
        'the ' .. CAND .. ' gate is gone from X.' .. HELP)

    -- The pullcad trap: a gate that names a SECOND id is frozen FALSE the day
    -- that id is promoted, and check_armed_wiring.py still calls it WIRED.
    local n = select(2, body:gsub('IsSoakCandidate%s*%(', ''))
    assert(n == 1, 'X.' .. HELP .. ' consults IsSoakCandidate ' .. n .. ' times, '
        .. 'not 1.  A second id here freezes this gate the day that id is '
        .. 'promoted (`zusult` already is, 2026-09-11) -- the pullcad trap.')
    for _, sOther in ipairs({ 'zusult', 'zusultd', 'zusultx', 'zusjumpland', 'zusjumpany' }) do
        assert(not body:find("'" .. sOther .. "'", 1, true),
            'X.' .. HELP .. ' names `' .. sOther .. '`.  Quoted literally rather '
            .. 'than by bare match because `zusult` is a SUBSTRING of `'
            .. CAND .. '` and a bare match self-reports on an unmutated tree.')
    end
end

tests['section 7.2: the id is read at CALL time, never at module scope'] = function()
    local src = strip_comments(read_file(SRC))
    local n = select(2, src:gsub("IsSoakCandidate%(%s*'" .. CAND .. "'%s*%)", ''))
    assert(n == 1, 'the ' .. CAND .. ' id appears at ' .. n .. ' gate sites in '
        .. SRC .. ', not 1.')

    -- Module-scope gates are evaluated once at load; every section above flips
    -- the arming table AFTER rf.load_hero and would silently read one leg twice.
    local iGate = assert(src:find("IsSoakCandidate%(%s*'" .. CAND .. "'%s*%)"))
    local iFn = src:sub(1, iGate):find('function%s+X%.' .. HELP .. '%s*%(')
    assert(iFn ~= nil and iFn < iGate, 'the ' .. CAND .. ' gate is no longer '
        .. 'inside X.' .. HELP .. '.  If it moved to module scope, on_frame\'s '
        .. 'flip-after-load shortcut reads the SAME leg twice and sections 5 '
        .. 'and 6.1 pass by comparing a thing to itself.')
end

return tests

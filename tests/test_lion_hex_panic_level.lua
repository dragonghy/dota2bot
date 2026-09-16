-- [ratchet] [hero] `lionwpanic` -- X.ConsiderW's 保护自己 (protect-self) Hex
-- firing point is switched off below hero level 10 by a term that measures
-- nothing about the situation, and the gated widening that removes it.
--
-- ===========================================================================
-- §0  WHAT IS WRONG
-- ===========================================================================
--
-- bots/BotLib/hero_lion.lua X.ConsiderW, 保护自己 branch:
--
--     if bot:WasRecentlyDamagedByAnyHero( 3.0 ) and nLV >= 10
--         and bot:GetActiveMode() ~= BOT_MODE_RETREAT
--         and #nInRangeEnemyList >= 1
--
-- Three of the four terms measure the situation this branch exists for.  The
-- fourth measures the hero's level.  It is not rationing mana or cooldown
-- either: X.ConsiderW's first line returns 0 unless `abilityW:IsFullyCastable()`,
-- so trained + affordable + off cooldown are settled before any branch runs.
--
-- ⭐ THE SIBLING SHIPS THE OTHER ANSWER.  There are exactly two 保护自己
-- branches in the focus five; the other is Crystal Maiden's Frostbite, the same
-- class of thing (her one reliable single-target disable), the same trigger --
-- and no level term.  §2 pins that by reading her source, so the argument
-- cannot rot the day somebody edits her branch.
--
-- ===========================================================================
-- §0.1  WHAT THIS FILE IS ENTITLED TO SAY, AND WHAT IT IS NOT
-- ===========================================================================
--
-- GATE LAYER (§3) is a real corpus reading: over every live-Lion instant in
-- tests/fixtures/ + tests/frames/, how many sit below the shipped line, i.e.
-- on how many frames does this predicate's answer differ between the legs.
--
-- BRANCH LAYER (§4) is ZERO, and the zero is the CORPUS's, not the lever's:
-- the instants where a hero had damaged Lion inside 3.0s are exactly the
-- instants where Hex is on cooldown, so no archived frame carries the whole
-- premise.  ⛔ Nobody may report a number of Hexes this lever adds.
--
-- ⭐ §4 also carries the sharpest thing the corpus does say, and it cuts BOTH
-- ways: on all six damaged instants Hex had already been spent (5.2s-22.7s of
-- cooldown left, four of them cast inside the previous six seconds) by one of
-- the firing points that has NO level term.  Read one way that is "the level
-- term is not what keeps Hex in the bank early, so removing it costs less than
-- it looks"; read the other it is "Hex is already being spent early, so this
-- lever mostly moves WHICH frame gets it".  Both are true; which dominates is
-- a wave question (iterations/queue.json hero-96), not a sentence here.
--
-- END TO END (§5) needs ONE counterfactual field -- Hex off cooldown -- and it
-- is labelled as one at the injection, in the case name, and here.  Everything
-- else on that frame is as recorded: the level (5), the damage history, the
-- roster, the geometry.
--
-- ===========================================================================
-- §0.2  DIRECTION AND THE BOUND ON RELOCATION
-- ===========================================================================
--
-- Armed the predicate is the constant true, so the branch's admitted set is a
-- strict SUPERSET of the shipped one: arming can only ADD a defensive Hex at
-- levels 1-9, never remove or re-target one.  It CAN displace a later branch,
-- and §6 pins the bound rather than denying it: `GetActiveMode() ~=
-- BOT_MODE_RETREAT` is not the complement of J.IsRetreating (which also
-- answers true under EVASIVE_MANEUVERS, a rupture, and FARM at absolute
-- desire), and both loops walk the same cast-range ring in the same order with
-- 撤退's filter strictly stronger -- so a displaced Hex can only move to a
-- member EARLIER in the same ring, never further away.

package.path = 'tests/?.lua;' .. package.path
local rf   = require('mock.replay_fixture')
local soak = require('mock.soak_side')

local SRC    = 'bots/BotLib/hero_lion.lua'
local CM_SRC = 'bots/BotLib/hero_crystal_maiden.lua'
local JMZ    = 'bots/FunLib/jmz_func.lua'
local CAND   = 'lionwpanic'
local HELPER = 'lion_IsPanicHexLevelOpen'
local UNIT   = 'npc_dota_hero_lion'
local HEX    = 'lion_voodoo'
local SPIKE  = 'lion_impale'
local DRAIN  = 'lion_mana_drain'
local FINGER = 'lion_finger_of_death'

local SHIPPED_LEVEL = 10        -- the literal this lever is about
local DAMAGE_WINDOW = 3.0       -- the branch's own trigger window

-- The one frame §5 drives: Lion at level 5 (below the line), a hero had hit
-- him inside the window, one enemy inside Hex's cast ring, Hex on cooldown.
local FRAME = 'tests/fixtures/f_260819_182855_lion_drain_midchannel.lua'

local FIXTURE_DIR = 'tests/fixtures'
local STAGED_DIR  = 'tests/frames'

local tests = {}

local function read_file(path)
    local fh = assert(io.open(path, 'r'), 'cannot open ' .. path)
    local body = fh:read('*a')
    fh:close()
    return body
end

--- The same file with LINE COMMENTS removed, for assertions that are about
--- code rather than prose.  A header that quotes the shipped comparison it
--- replaced is not a second call site -- the previous round learned this the
--- expensive way on `tests/_wkreinctr_sweep.lua`, where a doc comment naming a
--- helper was counted as a caller.  ⚠️ LIMIT: line comments only; a `--[[ ]]`
--- block would still be counted (bots/ has none today).  A smaller hole is not
--- no hole.
local function read_code(path)
    local out = {}
    for line in (read_file(path) .. '\n'):gmatch('(.-)\n') do
        out[#out + 1] = line:gsub('%-%-.*$', '')
    end
    return table.concat(out, '\n')
end

--- Both corpus directories, enumerated -- never a hardcoded list.  An empty
--- enumerator and an empty corpus are the same integer, and the assert is the
--- only thing that tells them apart.
--- ⚠️ io.popen directory walk: this file belongs on the hand-read list of
--- tests/test_bots_walk_farm_only.py (GH #774).
local function corpus_paths()
    local out = {}
    for _, dir in ipairs({ FIXTURE_DIR, STAGED_DIR }) do
        local n = 0
        local p = assert(io.popen('ls ' .. dir .. ' 2>/dev/null'))
        for name in p:lines() do
            if name:match('^f_.*%.lua$') then
                out[#out + 1] = dir .. '/' .. name
                n = n + 1
            end
        end
        p:close()
        assert(n > 0, 'corpus directory ' .. dir .. ' yielded no f_*.lua frame')
    end
    table.sort(out)
    return out
end

--- Install `v` as the answer to `h:k()` and drop any lazily-cached method (the
--- two steps rf.record_actions takes).  Setting only the spec entry leaves an
--- already-materialised method in place, and the injection then silently does
--- not take -- which reads exactly like a lever that does nothing.
local function inject(h, k, v)
    rawget(h, '__spec')[k] = v
    rawset(h, k, nil)
end

--- The cast ring X.ConsiderW itself computes: `abilityW:GetCastRange() +
--- aetherRange`, with the lens bonus rebuilt out of the real helpers rather
--- than a constant (a census on GetCastRange alone overstates nothing here but
--- understates the ring on any Lion holding the lens).
local function w_cast_range(J, bot)
    local hW = bot:GetAbilityByName(HEX)
    local nAether = 0
    local hLens = J.IsItemAvailable('item_aether_lens')
    if hLens ~= nil then nAether = J.GetAetherLensRangeBonus(hLens, 250) end
    return (hW and hW:GetCastRange() or 0) + nAether
end

--- ONE pass over the archive, cached: every live-Lion instant with the
--- loader's real answers for the four things this file counts.
local tRows = nil
local function rows()
    if tRows ~= nil then return tRows end
    tRows = {}
    for _, path in ipairs(corpus_paths()) do
        local ok, chunk = pcall(dofile, path)
        if ok and type(chunk) == 'table' then
            local present = false
            for _, u in ipairs(chunk.units or {}) do
                if u.name == UNIT and u.alive ~= false then present = true end
            end
            if present then
                local J, bot = rf.load(path, UNIT)
                local hW = bot:GetAbilityByName(HEX)
                local nRing = w_cast_range(J, bot)
                tRows[#tRows + 1] = {
                    path     = path,
                    nLV      = bot:GetLevel() or 0,
                    rank     = hW and hW:GetLevel() or 0,
                    cd       = hW and hW:GetCooldownTimeRemaining() or 0,
                    castable = (hW ~= nil and hW:IsFullyCastable()) and true or false,
                    ring     = nRing,
                    nEnemy   = #J.GetNearbyHeroes(bot, nRing > 0 and nRing or 575,
                                                  true, BOT_MODE_NONE),
                    damaged  = bot:WasRecentlyDamagedByAnyHero(DAMAGE_WINDOW) and true or false,
                }
            end
        end
    end
    assert(#tRows > 0, 'no live-Lion instant in the archive: this file would '
        .. 'then be counting an empty set and calling every claim true')
    return tRows
end

--- The real helper, off a freshly loaded hero module, with the two gate
--- readers stubbed to a named world.  `bArmed == nil` means "the id is armed
--- but some OTHER id" -- the control that a wrong id string cannot pass.
local function helper_answer(nLV, bArmed, bNonTurbo, sOtherId)
    local J = rf.load(FRAME, UNIT)
    J.IsSoakCandidate = function(id)
        if sOtherId ~= nil then return id == sOtherId end
        return bArmed and id == CAND
    end
    J.IsModeTurbo = function() return not bNonTurbo end
    local X = rf.load_hero('lion')
    return X.lion_IsPanicHexLevelOpen(nLV)
end

--- Drive the REAL X.SkillsComplement dispatch on FRAME with the candidate
--- armed or not, then ask X.ConsiderW directly for its motive (the dispatch
--- sets the file-level locals the branch reads).  `nLevel` overrides the
--- recorded hero level; `bReadyHex` is the ONE counterfactual (see §0.1).
local function drive(bArmed, bReadyHex, nLevel, bNonTurbo)
    local J, bot = rf.load(FRAME, UNIT)
    J.IsSoakCandidate = function(id) return bArmed and id == CAND end
    J.IsModeTurbo = function() return not bNonTurbo end

    local X = rf.load_hero('lion')

    -- E / R / Q are considered before W and would act first; shut them so the
    -- dispatch reaches the W branch at all.
    local tShut = {}
    for _, s in ipairs({ DRAIN, FINGER, SPIKE }) do
        local h = bot:GetAbilityByName(s)
        if h ~= nil then inject(h, 'IsFullyCastable', false) end
        tShut[s] = h
    end

    local hW = bot:GetAbilityByName(HEX)
    if bReadyHex then
        -- ⚠️ THE COUNTERFACTUAL, and the only one: on the recording Hex has
        -- 18.0s of cooldown left.  Nothing else is moved.
        inject(hW, 'GetCooldownTimeRemaining', 0)
        inject(hW, 'IsFullyCastable', true)
    end
    if nLevel ~= nil then inject(bot, 'GetLevel', nLevel) end

    local log = rf.record_actions(bot)
    X.SkillsComplement()
    local nDesire, hTarget, sMotive = X.ConsiderW()
    return {
        log = log, J = J, bot = bot, X = X, hW = hW, tShut = tShut,
        desire = nDesire, target = hTarget, motive = sMotive,
    }
end

-- ---------------------------------------------------------------- section 1 --
-- The call site and the gate, read off the source.

tests['§1.1 the call site is the helper, the shipped literal lives in one place'] = function()
    local src = read_code(SRC)

    local _, nCall = src:gsub('X%.' .. HELPER .. '%( nLV %)', '')
    assert(nCall == 1, 'expected exactly one `X.' .. HELPER .. '( nLV )` call '
        .. 'site in ' .. SRC .. ', found ' .. nCall)

    -- The shipped comparison must survive as the gate-off answer, in ONE place,
    -- and must no longer appear as a bare conjunct anywhere.
    local _, nConst = src:gsub('X%.nWPanicLevelShipped = ' .. SHIPPED_LEVEL, '')
    assert(nConst == 1, 'X.nWPanicLevelShipped = ' .. SHIPPED_LEVEL
        .. ' appears ' .. nConst .. ' times, expected once')
    local _, nBare = src:gsub('nLV >= ' .. SHIPPED_LEVEL, '')
    assert(nBare == 0, 'a bare `nLV >= ' .. SHIPPED_LEVEL .. '` is still in '
        .. SRC .. ' (' .. nBare .. 'x) -- the lever is then only half wired')

    -- ⚠️ The OTHER level term in this file is a different firing point
    -- (X.ConsiderQ's 15) and this lever does not touch it.  Asserted so a
    -- later round cannot read this file as having argued it down.
    local _, n15 = src:gsub('nLV >= 15', '')
    assert(n15 == 1, 'X.ConsiderQ\'s `nLV >= 15` is no longer exactly once in '
        .. SRC .. ' (' .. n15 .. 'x) -- that is a different firing point and '
        .. 'this lever must not have moved it')
end

tests['§1.2 the gate names exactly one id (the pullcad trap)'] = function()
    local src = read_file(SRC)
    local body = src:match('function X%.' .. HELPER .. '%b()(.-)\nend')
    assert(body ~= nil, 'cannot slice ' .. HELPER .. ' out of ' .. SRC)

    local tIds = {}
    for id in body:gmatch("IsSoakCandidate%(%s*'([%w_]+)'%s*%)") do
        tIds[#tIds + 1] = id
    end
    assert(#tIds == 1, HELPER .. ' names ' .. #tIds .. ' candidate ids, expected 1')
    assert(tIds[1] == CAND, 'the gate names `' .. tIds[1] .. '`, not `' .. CAND .. '`')

    -- A gate that ANDs a SECOND id freezes FALSE the day that id is promoted
    -- (a promoted id appears in no armed string), and check_armed_wiring.py
    -- still calls the site WIRED.  The quoted-literal form is what keeps this
    -- file out of tests/test_gate_claim_consistency.lua's comment-only register.
    assert(body:find("J%.IsModeTurbo%(%)") ~= nil,
        HELPER .. ' is not turbo-gated')
end

-- ---------------------------------------------------------------- section 2 --
-- The (c) argument's evidence: the sibling branch in the focus five.

tests['§2 CM\'s own 保护自己 branch carries no level term'] = function()
    local cm = read_file(CM_SRC)
    local at = cm:find('\t--保护自己\n')
    assert(at ~= nil, 'no 保护自己 branch in ' .. CM_SRC .. ' -- the (c) '
        .. 'argument in the helper header names one, so this is not a passing '
        .. 'condition, it is a stale claim')
    -- The branch header: from the comment to the `then` that opens the body.
    local head = cm:sub(at, at + 400)
    head = head:match('^(.-)\n%s*then') or head
    assert(head:find('WasRecentlyDamagedByAnyHero') ~= nil,
        'CM\'s 保护自己 branch no longer reads WasRecentlyDamagedByAnyHero; the '
        .. 'analogy in ' .. SRC .. ' rests on the trigger being the same one')
    assert(head:find('GetLevel') == nil and head:find('nLV') == nil,
        'CM\'s 保护自己 branch has grown a level term: ' .. head)

    -- And Lion's own branch still carries the three direct measurements the
    -- helper header says are already there -- the level term is not standing
    -- in for a missing one.
    local src = read_file(SRC)
    local lion = src:match('\t%-%-保护自己\n(.-)\n%s*then')
    assert(lion ~= nil, 'cannot slice Lion\'s 保护自己 branch header')
    assert(lion:find('WasRecentlyDamagedByAnyHero%( ' .. DAMAGE_WINDOW) ~= nil,
        'Lion\'s branch no longer triggers on WasRecentlyDamagedByAnyHero( '
        .. DAMAGE_WINDOW .. ' ): ' .. lion)
    assert(lion:find('GetActiveMode%(%) ~= BOT_MODE_RETREAT') ~= nil,
        'Lion\'s branch no longer excludes the retreat mode: ' .. lion)
    assert(lion:find('#nInRangeEnemyList >= 1') ~= nil,
        'Lion\'s branch no longer demands an enemy inside the cast ring: ' .. lion)
end

-- ---------------------------------------------------------------- section 3 --
-- GATE LAYER domain, counted on real frames.
--
-- ⚠️ The case name carries no corpus-size number on purpose: the counts live
-- in the asserts, so the archive growing puts exactly one thing out of date.

tests['§3.1 the corpus straddles the shipped line, and both sides are non-empty'] = function()
    local nBelow, nAbove = 0, 0
    for _, r in ipairs(rows()) do
        if r.nLV < SHIPPED_LEVEL then nBelow = nBelow + 1 else nAbove = nAbove + 1 end
    end
    assert(nBelow == 28, 'live-Lion instants below hero level ' .. SHIPPED_LEVEL
        .. ' is ' .. nBelow .. ', was 28 when this lever was written')
    assert(nAbove == 14, 'live-Lion instants at or above hero level '
        .. SHIPPED_LEVEL .. ' is ' .. nAbove .. ', was 14')
    -- Both non-empty is the thing that makes §3.2's reading a comparison
    -- rather than a tautology over an empty half.
    assert(nBelow > 0 and nAbove > 0)
end

tests['§3.2 armed flips exactly the instants below the line, and nothing else'] = function()
    local nFlip, nSame = 0, 0
    for _, r in ipairs(rows()) do
        local bShipped = helper_answer(r.nLV, false)
        local bArmed   = helper_answer(r.nLV, true)
        assert(bArmed == true, r.path .. ': armed must be the constant true '
            .. '(lv ' .. r.nLV .. ')')
        assert(bShipped == (r.nLV >= SHIPPED_LEVEL), r.path
            .. ': gate off must be `nLV >= ' .. SHIPPED_LEVEL .. '` byte for '
            .. 'byte (lv ' .. r.nLV .. ' answered ' .. tostring(bShipped) .. ')')
        if bShipped ~= bArmed then nFlip = nFlip + 1 else nSame = nSame + 1 end
    end
    assert(nFlip == 28, 'gate-layer domain is ' .. nFlip .. ', was 28')
    assert(nSame == 14, 'unchanged instants ' .. nSame .. ', was 14')
end

-- ---------------------------------------------------------------- section 4 --
-- BRANCH LAYER: the honest zero, and the reading that comes with it.

tests['§4.1 no archived frame carries the whole branch premise -- domain 0'] = function()
    local nPremise, nDamaged, nReadyRing = 0, 0, 0
    for _, r in ipairs(rows()) do
        if r.damaged then nDamaged = nDamaged + 1 end
        if r.castable and r.nEnemy >= 1 then nReadyRing = nReadyRing + 1 end
        if r.damaged and r.castable and r.nEnemy >= 1 and r.nLV < SHIPPED_LEVEL then
            nPremise = nPremise + 1
        end
    end
    assert(nDamaged == 6, 'instants damaged by a hero inside ' .. DAMAGE_WINDOW
        .. 's is ' .. nDamaged .. ', was 6')
    -- ⛔ THE RATCHET.  The day a frame carries the whole premise this fails,
    -- and that failure is the signal to write the end-to-end reading this file
    -- is not entitled to.  Read the message, do not bump the number.
    assert(nPremise == 0, 'the archive now has ' .. nPremise .. ' frame(s) with '
        .. 'the whole 保护自己 premise below the level line. This file\'s §5 '
        .. 'counterfactual is no longer necessary: drive THOSE frames instead, '
        .. 'and report a real end-to-end domain.')
    -- The supply that does exist, so the zero above is not read as "Lion is
    -- never ready" or "no enemy is ever in the ring".
    assert(nReadyRing >= 2, 'instants with Hex ready AND an enemy inside the '
        .. 'cast ring is ' .. nReadyRing .. ', was 2 -- if this reaches 0 the '
        .. 'zero above stops being about the damage term')
end

tests['§4.2 ⭐ the six damaged instants all have Hex ALREADY SPENT'] = function()
    local n, nRecent = 0, 0
    for _, r in ipairs(rows()) do
        if r.damaged then
            n = n + 1
            assert(r.castable == false, r.path .. ': a damaged instant with Hex '
                .. 'castable exists now -- §4.1\'s zero has a different cause '
                .. 'than this file says')
            assert(r.rank >= 1, r.path .. ': damaged instant with Hex untrained '
                .. '(rank ' .. r.rank .. ') -- then the cooldown reading below '
                .. 'is 0-for-nothing, not a spend')
            assert(r.cd > 0, r.path .. ': Hex is not on cooldown (cd ' .. r.cd
                .. ') yet IsFullyCastable is false -- the cause is mana, and '
                .. 'this section\'s reading is wrong')
            -- Rank 1-4 cooldown is 24/20/16/12; more than half of it left
            -- means the cast is inside the previous ~6 seconds at any rank.
            if r.cd >= 12 then nRecent = nRecent + 1 end
        end
    end
    assert(n == 6, 'damaged instants ' .. n .. ', was 6')
    assert(nRecent == 4, 'damaged instants that had spent Hex inside the '
        .. 'previous few seconds is ' .. nRecent .. ', was 4')
end

-- ---------------------------------------------------------------- section 5 --
-- END TO END on one real frame, with ONE counterfactual field.

tests['§5.1 the frame is what this file says it is'] = function()
    local J, bot = rf.load(FRAME, UNIT)
    assert(bot:GetLevel() == 5, FRAME .. ': Lion is level ' .. bot:GetLevel()
        .. ', expected 5 (below the shipped line, which is the whole point)')
    assert(bot:WasRecentlyDamagedByAnyHero(DAMAGE_WINDOW) == true,
        FRAME .. ': nobody had hit Lion inside ' .. DAMAGE_WINDOW .. 's, so the '
        .. 'branch trigger is not real on this frame')
    local nRing = w_cast_range(J, bot)
    assert(nRing == 575, FRAME .. ': cast ring ' .. nRing .. ', expected 575 '
        .. '(Hex rank 1, no Aether Lens)')
    assert(#J.GetNearbyHeroes(bot, nRing, true, BOT_MODE_NONE) >= 1,
        FRAME .. ': no enemy hero inside the cast ring')
    local hW = bot:GetAbilityByName(HEX)
    assert(hW:GetCooldownTimeRemaining() > 0 and hW:IsFullyCastable() == false,
        FRAME .. ': Hex is ready as recorded, so §5 does not need a '
        .. 'counterfactual and must be rewritten without one')
end

tests['§5.2 gate off refuses (level), armed hexes -- and it is the 保护自己 branch'] = function()
    local shipped = drive(false, true)
    assert(shipped.desire == BOT_ACTION_DESIRE_NONE or shipped.desire == 0,
        'gate off, X.ConsiderW bid ' .. tostring(shipped.desire) .. ' with motive '
        .. tostring(shipped.motive) .. ' -- something OTHER than the level term '
        .. 'is deciding this frame and §5 is not reading this lever')

    local armed = drive(true, true)
    assert(armed.desire == BOT_ACTION_DESIRE_HIGH, 'armed, X.ConsiderW bid '
        .. tostring(armed.desire) .. ', expected HIGH')
    assert(armed.motive == 'W-保护自己', 'armed fired, but through the `'
        .. tostring(armed.motive) .. '` branch -- this lever only touches 保护自己')
    assert(armed.target ~= nil and armed.target.GetUnitName ~= nil,
        'armed returned no unit handle to hex')
end

tests['§5.3 the counterfactual took, and it is the ONLY thing injected'] = function()
    local armed = drive(true, true)
    assert(armed.hW:IsFullyCastable() == true and armed.hW:GetCooldownTimeRemaining() == 0,
        'the Hex readiness injection did not take, so §5.2 read a dead branch')
    -- Everything else is the recording: level, damage history, ring.
    assert(armed.bot:GetLevel() == 5, 'the level was moved; §5 must read the '
        .. 'recorded 5')
    assert(armed.bot:WasRecentlyDamagedByAnyHero(DAMAGE_WINDOW) == true,
        'the damage history was moved')
    -- And without the readiness injection BOTH legs are silent -- which is
    -- what makes §0.1\'s "the zero is the corpus\'s" a measurement.
    assert((drive(true, false).desire or 0) == 0,
        'armed fired with Hex on its recorded cooldown: X.ConsiderW\'s first '
        .. 'line is supposed to have returned 0 long before the branch')
end

tests['§5.4 above the line the two legs agree (armed adds nothing there)'] = function()
    local shipped = drive(false, true, SHIPPED_LEVEL)
    local armed   = drive(true,  true, SHIPPED_LEVEL)
    assert(shipped.desire == BOT_ACTION_DESIRE_HIGH, 'at level ' .. SHIPPED_LEVEL
        .. ' the shipped tree must already fire here; it bid '
        .. tostring(shipped.desire) .. ' (' .. tostring(shipped.motive) .. ')')
    assert(armed.desire == shipped.desire and armed.motive == shipped.motive,
        'armed changed the answer above the line: ' .. tostring(armed.motive))
    assert(armed.target:GetUnitName() == shipped.target:GetUnitName(),
        'armed re-targeted above the line, which this lever cannot do')
end

-- ---------------------------------------------------------------- section 6 --
-- The relocation bound, pinned at its source rather than asserted in prose.

tests['§6 J.IsRetreating is NOT the complement of the branch\'s mode test'] = function()
    local body = read_file(JMZ):match('function J%.IsRetreating%b()(.-)\nend')
    assert(body ~= nil, 'cannot slice J.IsRetreating out of ' .. JMZ)
    for _, sShape in ipairs({ 'BOT_MODE_EVASIVE_MANEUVERS',
                              'modifier_bloodseeker_rupture',
                              'BOT_MODE_FARM' }) do
        assert(body:find(sShape, 1, true) ~= nil, 'J.IsRetreating no longer '
            .. 'answers true under ' .. sShape .. ' -- the helper header\'s '
            .. 'relocation paragraph names it, so the two have drifted')
    end
    -- The bound itself: 撤退's filter is the 保护自己 filter plus a strictly
    -- extra demand, over the same list.
    local src = read_file(SRC)
    local retreat = src:match('\t%-%-撤退\n(.-)\n%s*%-%-roshan')
    assert(retreat ~= nil, 'cannot slice X.ConsiderW\'s 撤退 branch')
    assert(retreat:find('nInRangeEnemyList', 1, true) ~= nil,
        'the 撤退 loop no longer walks nInRangeEnemyList, so "same ring, same '
        .. 'order" is no longer the bound')
    assert(retreat:find('WasRecentlyDamagedByHero%( npcEnemy, 4%.0 %)') ~= nil
        and retreat:find('<= 600') ~= nil,
        'the 撤退 loop no longer carries its strictly stronger demand')
end

-- ---------------------------------------------------------------- section 7 --
-- Gate off, non-turbo, and the real reader.

tests['§7.1 outside Turbo the armed leg is the shipped answer, at every level'] = function()
    for _, nLV in ipairs({ 1, 5, 9, 10, 11, 25 }) do
        assert(helper_answer(nLV, true, true) == (nLV >= SHIPPED_LEVEL),
            'non-turbo at level ' .. nLV .. ' must answer the shipped comparison')
        assert(helper_answer(nLV, false) == (nLV >= SHIPPED_LEVEL),
            'gate off at level ' .. nLV .. ' must answer the shipped comparison')
    end
end

tests['§7.2 some OTHER armed id does not open this gate'] = function()
    for _, nLV in ipairs({ 1, 5, 9 }) do
        assert(helper_answer(nLV, nil, false, 'lionwreach') == false,
            'level ' .. nLV .. ': a sibling id armed opened this gate -- the '
            .. 'predicate is reading the wrong string')
    end
end

tests['§7.3 the REAL J.IsSoakCandidate answers to this exact literal'] = function()
    -- The stubs above prove the call site; they cannot prove the id string is
    -- one the shipped reader recognises.  This case arms the real switch.
    local J, bot = rf.load(FRAME, UNIT)
    local sSide = (GetTeam() == TEAM_RADIANT) and 'radiant' or 'dire'
    soak.with_candidate(CAND, function()
        local J2, bot2 = rf.load(FRAME, UNIT)
        J2.IsModeTurbo = function() return true end
        local X = rf.load_hero('lion')
        assert(X.lion_IsPanicHexLevelOpen(5) == true,
            'the real J.IsSoakCandidate did not recognise `' .. CAND .. '` with '
            .. 'the switch armed on side ' .. sSide)
    end, sSide)
    -- And with the switch gone the predicate is the shipped comparison again.
    -- ⚠️ THE RELOAD IS LOAD-BEARING, not tidiness: jmz_func caches the switch
    -- in `tSoakSideCache` on first read and never re-reads it, so asking the
    -- SAME module world after the disarm answers from the cache and this case
    -- fails for a reason that has nothing to do with the lever.
    local J3 = rf.load(FRAME, UNIT)
    J3.IsModeTurbo = function() return true end
    local X = rf.load_hero('lion')
    assert(X.lion_IsPanicHexLevelOpen(5) == false,
        'the predicate is still open after the switch was removed')
    assert(bot ~= nil and J ~= nil)
end

return tests

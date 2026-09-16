-- [ratchet] [hero] `cmlanepoor` -- the 对线期消耗 block's LAST firing point is
-- its FIRST one with both of the first one's conditions deleted, and the gated
-- change that restores one of them.
--
-- ===========================================================================
-- §0  WHAT IS WRONG
-- ===========================================================================
--
-- bots/BotLib/hero_crystal_maiden.lua X.ConsiderW, the 对线期消耗 block.  Four
-- firing points, all inside `GetActiveMode() == BOT_MODE_LANING and #nTowers == 0`.
-- The first and the last bid on the SAME subject expression,
-- `nWeakestEnemyHeroInRange`, six lines apart:
--
--     first    (nMP > 0.5 or bot:GetMana() > nKeepMana)   <- a wallet test
--              and not J.IsDisabled( target )             <- a waste test
--     last     target health ratio < 0.5                  <- and NOTHING else
--
-- ⭐ THE BLOCK IS STRAIGHT-LINE, so the only way to REACH the last firing point
-- is for one of those two terms to have refused: sub-branch 1 `return`s
-- whenever both hold on a valid target.  The file therefore ships "if she
-- cannot afford it, or the target is already locked down, cast it anyway
-- provided the target is under half health".  That is not a fallback under the
-- guard, it is an override of it.  §1 pins the reachability argument off the
-- source, so it cannot rot the day somebody reorders the block.
--
-- Armed, `cmlanepoor` applies sub-branch 1's own wallet disjunction -- the same
-- expression, evaluated at the call site and passed in -- to the last branch.
-- Gate off, the added conjunct is the constant `true`.
--
-- ===========================================================================
-- §0.1  WHAT THIS FILE IS ENTITLED TO SAY, AND WHAT IT IS NOT
-- ===========================================================================
--
-- GATE LAYER (§4.1) is a real corpus reading: over every live-CM instant in
-- tests/fixtures/ + tests/frames/, how many fail the shipped wallet test, i.e.
-- on how many frames do the two legs of this helper differ.
--
-- BRANCH LAYER (§4.2) is ZERO, and the zero is the CORPUS's, not the lever's:
-- no archived instant carries Frostbite fully castable AND a failing wallet AND
-- a weakest-in-ring enemy under half health at the same time.  ⛔ Nobody may
-- report a number of Frostbites this lever deletes.
--
-- END TO END (§5) is in two parts and they are different readings.
--   §5.1 AS RECORDED is NONE on both legs, and the reason is the harness, not
--        the game: `bot:GetActiveMode()` is bot-VM state that is in no .dem, so
--        the loader's generic `^Get -> 0` answers 0 -- and 0 is not in the
--        BOT_MODE namespace at all (the constants start at 1001).  The whole
--        block is unreachable offline BY CONSTRUCTION.  Same finding as the
--        `zusulte` round's UNASKABLE and as tests/test_cm_t10_payoff.lua's own
--        `assert(bot:GetActiveMode() == 0)`.
--   §5.2 DECLARATIVE COUNTERFACTUAL names its two injections and changes
--        nothing else: the mode the loader cannot answer, and Frostbite off
--        cooldown (the recording has 0.7s left).  The mana (145/485) and the
--        target's health (Axe at 0.25) are AS RECORDED -- they are the two
--        facts the lever is about, and neither is injected.
--
-- ===========================================================================
-- §0.2  HOW §5.2 KNOWS WHICH BRANCH FIRED
-- ===========================================================================
--
-- X.ConsiderW returns (desire, target) and no motive string, so the branch
-- cannot be read off the return value.  It does not need to be.  The armed leg
-- changes exactly one conjunct, inside the last firing point, and nothing else
-- in the file; so a bid that DISAPPEARS when the id is armed can only have come
-- from that firing point.  The difference itself is the identification, and it
-- is stronger than a motive string would be.
--
-- ===========================================================================
-- §0.3  DIRECTION
-- ===========================================================================
--
-- Gate off the helper is the constant `true`, so armed it can only ever turn a
-- shipped TRUE into FALSE: the armed admitted set is a strict SUBSET.  Arming
-- DELETES lane Frostbites and can never add or re-target one, so a negative
-- wave reading may not be read as "CM cast more".  It cannot relocate the
-- refused cast inside this function either -- every firing point below the
-- 对线期消耗 block takes a different target class and re-derives its own target.

package.path = 'tests/?.lua;' .. package.path
local rf   = require('mock.replay_fixture')
local soak = require('mock.soak_side')

local SRC   = 'bots/BotLib/hero_crystal_maiden.lua'
local CAND  = 'cmlanepoor'
local HELPER = 'cm_IsLaneFallbackAffordable'
local UNIT  = 'npc_dota_hero_crystal_maiden'
local FB    = 'crystal_maiden_frostbite'

local KEEP_MANA = 220           -- the shipped nKeepMana this lever reads through
local HURT      = 0.5           -- sub-branch 4's own health ratio

-- The one frame §5 drives.  CM at 145/485 mana (the wallet test FAILS as
-- recorded), Axe inside Frostbite's ring at 0.25 health (sub-branch 4's own
-- test passes as recorded), Frostbite trained at rank 1 with 0.7s of cooldown.
local FRAME = 'tests/fixtures/f_260819_123546_axe_rescue_ok.lua'

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
--- code rather than prose.  This helper's header QUOTES the shipped conjuncts
--- it is about, so a census over the raw text would count the documentation as
--- call sites.  ⚠️ LIMIT: line comments only; a `--[[ ]]` block would still be
--- counted (bots/ has none today).  A smaller hole is not no hole.
local function read_code(path)
    local out = {}
    for line in (read_file(path) .. '\n'):gmatch('(.-)\n') do
        out[#out + 1] = line:gsub('%-%-.*$', '')
    end
    return table.concat(out, '\n')
end

--- Both corpus directories, enumerated -- never a hardcoded list.  An empty
--- enumerator and an empty corpus are the same integer and only the assert
--- tells them apart.
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
--- two steps rf.record_actions takes).
--- ⚠️ IN THIS FILE THE SECOND LINE IS DEFENSIVE, NOT LOAD-BEARING, and saying
--- so is the point: every injection below happens BEFORE anything has called
--- the method being injected, so nothing is materialised yet and dropping the
--- cache is a no-op.  Measured, not assumed -- mutstand_cmlanepoor.sh's first
--- M12 deleted that line and the suite stayed GREEN.  The line stays because
--- the order is an accident of how `drive` is written today (rf.record_actions
--- runs after the injections) and a later edit that moves a read above an
--- injection would otherwise fail for a reason that has nothing to do with the
--- lever.  M12 now deletes the line that IS load-bearing, the spec write.
local function inject(h, k, v)
    rawget(h, '__spec')[k] = v
    rawset(h, k, nil)
end

--- The cast ring X.ConsiderW itself builds, with the lens bonus rebuilt out of
--- the real helpers rather than frozen at one of today's values.
local function w_cast_range(J, bot)
    local hW = bot:GetAbilityByName(FB)
    local nAether = 0
    local hLens = J.IsItemAvailable('item_aether_lens')
    if hLens ~= nil then nAether = J.GetAetherLensRangeBonus(hLens, 250) end
    local nCastRange = (hW and hW:GetCastRange() or 0) + 30 + nAether
    local view = J.GetNearbyHeroes(bot, 1600, true, BOT_MODE_NONE)
    if #view <= 1 and nCastRange < bot:GetAttackRange() then
        nCastRange = bot:GetAttackRange() + 60
    end
    return nCastRange
end

--- ONE pass over the archive, cached: every live-CM instant with the loader's
--- real answers for the things this file counts.
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
                local hW = bot:GetAbilityByName(FB)
                local nRing = w_cast_range(J, bot)
                local nMana, nMax = bot:GetMana(), bot:GetMaxMana()
                local nMP = (nMax > 0) and (nMana / nMax) or 0
                -- sub-branch 1's wallet disjunction, verbatim.
                local bWallet = (nMP > 0.5) or (nMana > KEEP_MANA)
                -- X.cm_GetWeakestUnit picks by ABSOLUTE health, not ratio.
                local hWeakest, nLowest = nil, nil
                for _, h in ipairs(J.GetNearbyHeroes(bot, nRing, true, BOT_MODE_NONE)) do
                    if J.IsValid(h) and (nLowest == nil or h:GetHealth() < nLowest) then
                        hWeakest, nLowest = h, h:GetHealth()
                    end
                end
                local bHurt, bDisabled = false, false
                if hWeakest ~= nil then
                    bHurt = (hWeakest:GetHealth() / hWeakest:GetMaxHealth()) < HURT
                    bDisabled = J.IsDisabled(hWeakest) and true or false
                end
                tRows[#tRows + 1] = {
                    path     = path,
                    castable = (hW ~= nil and hW:IsFullyCastable()) and true or false,
                    mana     = nMana,
                    mp       = nMP,
                    wallet   = bWallet,
                    target   = hWeakest ~= nil,
                    hurt     = bHurt,
                    disabled = bDisabled,
                }
            end
        end
    end
    assert(#tRows > 0, 'no live-CM instant in the archive: this file would then '
        .. 'be counting an empty set and calling every claim true')
    return tRows
end

--- The real helper, off a freshly loaded hero module, with the two gate readers
--- stubbed to a named world.  `sOtherId` means "the id is armed but some OTHER
--- id" -- the control a wrong id string cannot pass.
local function helper_answer(bShippedWallet, bArmed, bNonTurbo, sOtherId)
    local J = rf.load(FRAME, UNIT)
    J.IsSoakCandidate = function(id)
        if sOtherId ~= nil then return id == sOtherId end
        return bArmed and id == CAND
    end
    J.IsModeTurbo = function() return not bNonTurbo end
    local X = rf.load_hero('crystal_maiden')
    return X.cm_IsLaneFallbackAffordable(bShippedWallet)
end

--- Drive the REAL X.SkillsComplement dispatch on FRAME, then ask X.ConsiderW
--- for its bid (the dispatch sets the file-level locals nMP/nHP/nLV/nKeepMana
--- the branch reads; without it the branch raises on a nil comparison).
--- `bLane` and `bReady` are the two declared injections of §5.2; `nMana`
--- overrides the recorded mana and is used ONLY by the negative control that
--- proves the refusal is the wallet term.
local function drive(bArmed, bLane, bReady, nMana, bNonTurbo)
    local J, bot = rf.load(FRAME, UNIT)
    J.IsSoakCandidate = function(id) return bArmed and id == CAND end
    J.IsModeTurbo = function() return not bNonTurbo end

    local X = rf.load_hero('crystal_maiden')

    if bLane  then inject(bot, 'GetActiveMode', BOT_MODE_LANING) end
    if nMana  then inject(bot, 'GetMana', nMana) end
    local hW = bot:GetAbilityByName(FB)
    if bReady then
        inject(hW, 'GetCooldownTimeRemaining', 0)
        inject(hW, 'IsFullyCastable', true)
    end

    local log = rf.record_actions(bot)
    X.SkillsComplement()
    local nDesire, hTarget = X.ConsiderW()
    return { log = log, J = J, bot = bot, X = X, hW = hW,
             desire = nDesire, target = hTarget }
end

-- ---------------------------------------------------------------- section 1 --
-- The defect, and the lever, read off the source.

tests['§1.1 the last firing point is reachable only because sub-branch 1 refused'] = function()
    local src = read_code(SRC)
    local block = src:match('BOT_MODE_LANING and #nTowers == 0(.-)\n\tend\n')
    assert(block ~= nil, 'cannot slice the 对线期消耗 block out of ' .. SRC
        .. ' -- the whole reachability argument is about that block\'s shape')

    -- Sub-branch 1: the wallet test and the waste test, on the weakest in-ring
    -- enemy, with an unconditional `return` under them.
    local first = block:match('(nMP > 0.5 or bot:GetMana%(%)> nKeepMana.-return BOT_ACTION_DESIRE_HIGH, nWeakestEnemyHeroInRange)')
    assert(first ~= nil, 'sub-branch 1 no longer reads `nMP > 0.5 or '
        .. 'bot:GetMana()> nKeepMana` and return HIGH on nWeakestEnemyHeroInRange')
    assert(first:find('not J.IsDisabled( nWeakestEnemyHeroInRange )', 1, true) ~= nil,
        'sub-branch 1 lost its `not J.IsDisabled` term; the claim that the last '
        .. 'branch is reached BECAUSE one of two terms refused is then wrong')

    -- ...and there is nothing between it and the last firing point that could
    -- make the block exit some other way: the block's only exits are HIGH
    -- returns, so control reaching the last branch means every earlier
    -- condition was false.
    local _, nReturns = block:gsub('return BOT_ACTION_DESIRE_HIGH', '')
    assert(nReturns == 4, 'the 对线期消耗 block has ' .. nReturns
        .. ' firing points, expected 4 -- §0\'s reachability argument is about '
        .. 'a straight-line block of exactly those four')
end

tests['§1.2 the call site is the helper, with the shipped disjunction passed IN'] = function()
    local src = read_code(SRC)

    local _, nCall = src:gsub('X%.' .. HELPER .. '%( nMP > 0%.5 or bot:GetMana%(%) > nKeepMana %)', '')
    assert(nCall == 1, 'expected exactly one `X.' .. HELPER
        .. '( nMP > 0.5 or bot:GetMana() > nKeepMana )` call site in ' .. SRC
        .. ', found ' .. nCall)

    -- The expression must stay at the CALL SITE, never rebuilt inside the
    -- helper: tests/_cm_t10_payoff_sweep.lua parses this file's mana gates out
    -- of the source text, and a gate hidden behind a renamed parameter leaves
    -- that sweep modelling one gate fewer with every assertion here still green.
    local body = read_file(SRC):match('function X%.' .. HELPER .. '%b()(.-)\nend')
    assert(body ~= nil, 'cannot slice ' .. HELPER .. ' out of ' .. SRC)
    assert(body:find('nKeepMana', 1, true) == nil and body:find('nMP', 1, true) == nil,
        HELPER .. ' now rebuilds the wallet expression itself; it must take it '
        .. 'as bShippedWallet so _cm_t10_payoff_sweep.lua can still see the gate')

    -- The shipped literal `0.5` must still be there for the sweep to parse, and
    -- in CODE exactly twice: sub-branch 1's own test and this lever's call site.
    -- ⚠️ The count is over comment-stripped source on purpose -- this helper's
    -- header QUOTES the disjunction, so a census over the raw text reads 3 and
    -- would call a documentation line a gate.
    local _, nFrac = src:gsub('nMP > 0%.5', '')
    assert(nFrac == 2, '`nMP > 0.5` appears ' .. nFrac .. ' times in the CODE of '
        .. SRC .. ', expected 2 (sub-branch 1, and this lever\'s call site). '
        .. 'If this reads 3 the comment stripper stopped working; if it reads 1 '
        .. 'the lever or the shipped test is gone.')
    assert(read_file(SRC):find('nKeepMana = ' .. KEEP_MANA, 1, true) ~= nil,
        'the shipped mana reserve moved off ' .. KEEP_MANA .. '; this lever '
        .. 'rations against it, so re-read the header before relaxing this')
end

tests['§1.3 the gate names exactly one id (the pullcad trap)'] = function()
    local body = read_file(SRC):match('function X%.' .. HELPER .. '%b()(.-)\nend')
    assert(body ~= nil, 'cannot slice ' .. HELPER .. ' out of ' .. SRC)

    local tIds = {}
    for id in body:gmatch("IsSoakCandidate%(%s*'([%w_]+)'%s*%)") do
        tIds[#tIds + 1] = id
    end
    assert(#tIds == 1, HELPER .. ' names ' .. #tIds .. ' candidate ids, expected 1')
    assert(tIds[1] == CAND, 'the gate names `' .. tIds[1] .. '`, not `' .. CAND .. '`')
    assert(body:find('J%.IsModeTurbo%(%)') ~= nil, HELPER .. ' is not turbo-gated')

    -- A gate that ANDs a SECOND id freezes FALSE the day that id is promoted (a
    -- promoted id is in no armed string) while check_armed_wiring.py still
    -- calls the site WIRED.
    for _, sSibling in ipairs({ 'cmlaneband', 'cmqpoke', 'cmwhit', 'cmwface', 'cmtfclock' }) do
        assert(body:find(sSibling, 1, true) == nil,
            HELPER .. ' conjoins the sibling id `' .. sSibling .. '`')
    end
end

-- ---------------------------------------------------------------- section 2 --
-- The helper's own truth table, off a freshly loaded module each time.

tests['§2.1 gate off is the constant true -- the shipped conjunction, unchanged'] = function()
    assert(helper_answer(false, false) == true,
        'gate off with a FAILING shipped wallet must still be true: gate off '
        .. 'this conjunct has to be a no-op or the lever is not inert')
    assert(helper_answer(true, false) == true, 'gate off with a passing wallet')
end

tests['§2.2 armed, the helper IS the shipped wallet answer'] = function()
    assert(helper_answer(false, true) == false,
        'armed with a failing wallet must refuse -- that is the whole lever')
    assert(helper_answer(true, true) == true,
        'armed with a passing wallet must admit; the lever adds no new threshold')
end

tests['§2.3 non-turbo and a foreign id both leave it inert'] = function()
    assert(helper_answer(false, true, true) == true,
        'armed but NOT turbo must be inert: every lever in this repo is turbo-only')
    assert(helper_answer(false, nil, false, 'cmlaneband') == true,
        'some OTHER id armed must leave this helper inert -- a helper that fires '
        .. 'on any armed id is not gated on its own name')
end

tests['§2.4 the real J.IsSoakCandidate recognises this literal'] = function()
    -- The stubs above prove the call site; they cannot prove the id string is
    -- one the shipped reader recognises.  This case arms the real switch.
    -- ⚠️ THE RELOAD IS LOAD-BEARING, not tidiness: jmz_func caches the switch in
    -- `tSoakSideCache` on first read and never re-reads it, so asking the SAME
    -- module world after an arm/disarm answers from the cache and the case then
    -- fails for a reason that has nothing to do with the lever.
    local sSide = (GetTeam() == TEAM_RADIANT) and 'radiant' or 'dire'
    soak.with_candidate(CAND, function()
        local J = rf.load(FRAME, UNIT)
        J.IsModeTurbo = function() return true end
        local X = rf.load_hero('crystal_maiden')
        assert(X.cm_IsLaneFallbackAffordable(false) == false,
            'the real J.IsSoakCandidate did not recognise `' .. CAND
            .. '` with the switch armed on side ' .. sSide
            .. ' -- the id would be dead on the farm')
    end, sSide)

    local J2 = rf.load(FRAME, UNIT)
    J2.IsModeTurbo = function() return true end
    local X2 = rf.load_hero('crystal_maiden')
    assert(X2.cm_IsLaneFallbackAffordable(false) == true,
        'the helper is still refusing after the switch was removed')
end

-- ---------------------------------------------------------------- section 3 --
-- The frame §5 drives, as recorded.  Asserted so §5's two injections stay the
-- only two, and so the facts the lever is about are visibly NOT injected.

tests['§3 the recorded frame carries the lever\'s premises without injection'] = function()
    local J, bot = rf.load(FRAME, UNIT)
    local nMana, nMax = bot:GetMana(), bot:GetMaxMana()
    assert(nMana < 200 and nMax > 400,
        'FRAME no longer holds the low-mana CM it was chosen for: '
        .. nMana .. '/' .. nMax)
    assert(not ((nMana / nMax) > 0.5 or nMana > KEEP_MANA),
        'FRAME\'s shipped wallet test now PASSES (' .. nMana .. '/' .. nMax
        .. ') -- §5.2 would then be measuring nothing')

    local nRing = w_cast_range(J, bot)
    local hWeakest, nLowest = nil, nil
    for _, h in ipairs(J.GetNearbyHeroes(bot, nRing, true, BOT_MODE_NONE)) do
        if J.IsValid(h) and (nLowest == nil or h:GetHealth() < nLowest) then
            hWeakest, nLowest = h, h:GetHealth()
        end
    end
    assert(hWeakest ~= nil, 'FRAME has no enemy hero inside Frostbite\'s ring')
    assert((hWeakest:GetHealth() / hWeakest:GetMaxHealth()) < HURT,
        'FRAME\'s weakest in-ring enemy is no longer under ' .. HURT .. ' health; '
        .. 'sub-branch 4\'s own test would not pass and §5.2 would flip nothing')

    -- Frostbite is trained and on cooldown: the ONE ability-state injection.
    local hW = bot:GetAbilityByName(FB)
    assert(hW ~= nil and hW:GetLevel() >= 1, 'Frostbite is not trained on FRAME')
    assert(hW:GetCooldownTimeRemaining() > 0,
        'Frostbite is already off cooldown on FRAME -- §5.2 declares an '
        .. 'injection that is then not an injection, and the label is wrong')
end

-- ---------------------------------------------------------------- section 4 --
-- The corpus.  Two layers, registered separately, because they are different
-- numbers and a reader who conflates them has invented a verification.

tests['§4.1 GATE LAYER: the legs differ on a measured, non-empty set'] = function()
    local t = rows()
    local nAll, nWalletFail, nCastable, nCastableFail = #t, 0, 0, 0
    for _, r in ipairs(t) do
        if not r.wallet then nWalletFail = nWalletFail + 1 end
        if r.castable then
            nCastable = nCastable + 1
            if not r.wallet then nCastableFail = nCastableFail + 1 end
        end
    end
    -- The readings this file is entitled to quote.  Registered as inequalities
    -- so a grown corpus does not turn a true statement red, and with a floor so
    -- an emptied corpus cannot pass silently.
    assert(nAll >= 70, 'live-CM instants: ' .. nAll .. ' (was 70 when written)')
    assert(nWalletFail >= 17, 'instants failing the shipped wallet test: '
        .. nWalletFail .. ' (was 17 of 70)')
    assert(nCastable >= 44, 'instants with Frostbite fully castable: ' .. nCastable)
    assert(nCastableFail >= 3, 'instants BOTH castable and wallet-failing: '
        .. nCastableFail .. ' (was 3 of 44) -- this is the set on which the two '
        .. 'legs of this helper can differ inside a reachable X.ConsiderW')
end

tests['§4.2 BRANCH LAYER is ZERO, and the zero belongs to the corpus'] = function()
    local t = rows()
    local nBranch, nTarget, nHurt, nDisabled = 0, 0, 0, 0
    for _, r in ipairs(t) do
        if r.target then
            nTarget = nTarget + 1
            if r.hurt then nHurt = nHurt + 1 end
            if r.disabled then nDisabled = nDisabled + 1 end
        end
        if r.castable and not r.wallet and r.hurt then nBranch = nBranch + 1 end
    end
    assert(nTarget >= 19, 'instants with a weakest enemy inside the ring: ' .. nTarget)
    assert(nHurt >= 5, 'instants whose weakest in-ring enemy is under half health: '
        .. nHurt)

    -- ⭐ THE ZERO BELOW HAS TO BE AN EMPTY INTERSECTION, NOT AN EMPTY
    -- ENUMERATOR.  "Measured zero" and "measured nothing" are the same integer,
    -- and only this liveness check tells them apart: each factor of the
    -- conjunction must be non-empty on its own before the conjunction's zero
    -- may be read as a fact about the corpus.
    local nCastableFail = 0
    for _, r in ipairs(t) do
        if r.castable and not r.wallet then nCastableFail = nCastableFail + 1 end
    end
    assert(nCastableFail >= 3 and nHurt >= 5,
        'a factor of the branch-layer conjunction is empty (castable&wallet-fail='
        .. nCastableFail .. ', hurt=' .. nHurt .. '), so the zero below would be '
        .. 'the enumerator\'s, not the corpus\'s, and this file may not report it')

    assert(nBranch == 0,
        'the corpus now carries ' .. nBranch .. ' instant(s) with ALL of '
        .. '(Frostbite castable, wallet failing, weakest in-ring enemy under half '
        .. 'health).  That is GOOD NEWS, not a failure: §0.1 says the branch-layer '
        .. 'zero is the corpus\'s.  Re-read §5, drive those frames as recorded, '
        .. 'and REPLACE this assertion with the reading -- do not just relax it.')

    -- The OTHER deleted term, measured and deliberately not taken.  If a later
    -- corpus grows a disabled target this stops being a construction and starts
    -- being a domain, and the helper header's "one lever at a time" note is the
    -- thing that should then move.
    assert(nDisabled == 0,
        'J.IsDisabled now answers true on ' .. nDisabled .. ' of the in-ring '
        .. 'targets.  X.' .. HELPER .. '\'s header says this lever skipped the '
        .. '`not J.IsDisabled` term because that number was ZERO; it is not any '
        .. 'more, so that paragraph is now false -- fix the header, then decide.')
end

-- ---------------------------------------------------------------- section 5 --
-- End to end, in two parts that are different readings.

tests['§5.1 AS RECORDED both legs are NONE, and the reason is the harness'] = function()
    -- The loader answers 0 for GetActiveMode -- bot-VM state is in no .dem --
    -- and 0 is not in the BOT_MODE namespace at all.
    local _, bot = rf.load(FRAME, UNIT)
    assert(bot:GetActiveMode() == 0,
        'the loader now answers ' .. tostring(bot:GetActiveMode())
        .. ' for GetActiveMode.  If it can answer for real, §5.2 no longer '
        .. 'needs its mode injection -- drive the block as recorded instead.')
    assert(BOT_MODE_LANING > 1000,
        'BOT_MODE_LANING is ' .. tostring(BOT_MODE_LANING) .. '; the argument '
        .. 'that a 0 cannot be any mode rests on the namespace starting high')

    local off = drive(false, false, false)
    local on  = drive(true,  false, false)
    assert(off.desire == BOT_ACTION_DESIRE_NONE and on.desire == BOT_ACTION_DESIRE_NONE,
        'as recorded the block is unreachable, so both legs must answer NONE; '
        .. 'got off=' .. tostring(off.desire) .. ' on=' .. tostring(on.desire))
end

tests['§5.2 DECLARATIVE COUNTERFACTUAL: the bid flips, and only the lever flips it'] = function()
    -- TWO injections, both named here and in §0.1: the mode the loader cannot
    -- answer, and Frostbite off cooldown.  The mana and the target's health --
    -- the two facts this lever is about -- are AS RECORDED.
    local off = drive(false, true, true)
    assert(off.desire == BOT_ACTION_DESIRE_HIGH,
        'gate off, the shipped tree must bid HIGH here; got ' .. tostring(off.desire))
    assert(off.target ~= nil and type(off.target) == 'table'
        and off.target:GetUnitName() == 'npc_dota_hero_axe',
        'gate off, the shipped bid is on the recorded weakest in-ring enemy')

    local on = drive(true, true, true)
    assert(on.desire == BOT_ACTION_DESIRE_NONE,
        'armed, the bid must be gone; got ' .. tostring(on.desire)
        .. '.  §0.2: the armed leg changes exactly one conjunct inside the last '
        .. 'firing point, so this disappearance is what identifies the branch.')
end

tests['§5.3 the refusal is the WALLET, not the injection'] = function()
    -- Same two injections, but the shipped wallet test is made to PASS.  If the
    -- armed leg still refused, the refusal would be coming from something other
    -- than the term this lever is about.
    local on = drive(true, true, true, KEEP_MANA + 180)
    assert(on.desire == BOT_ACTION_DESIRE_HIGH,
        'armed, with mana above the shipped reserve, X.ConsiderW must bid again; '
        .. 'got ' .. tostring(on.desire) .. '.  ⚠️ this control says the armed '
        .. 'refusal tracks the wallet; it does NOT say the bid comes back from '
        .. 'the same firing point (above the bar, sub-branch 1 is open too).')
end

tests['§5.4 non-turbo and a foreign id leave the driven bid untouched'] = function()
    local nonTurbo = drive(true, true, true, nil, true)
    assert(nonTurbo.desire == BOT_ACTION_DESIRE_HIGH,
        'armed but not turbo must be byte-identical to shipped; got '
        .. tostring(nonTurbo.desire))
end

-- ---------------------------------------------------------------- section 6 --
-- Limits, stated as limits.

tests['§6 what this file does NOT establish'] = function()
    -- (a) The added conjunct evaluates `bot:GetMana()` on frames where the
    -- shipped tree did not.  GetMana is a pure read, so gate-off behaviour is
    -- unchanged -- but the CALL COUNT is not, and a later census that counts
    -- GetMana calls must know that.
    local src = read_code(SRC)
    local _, nGetMana = src:gsub('bot:GetMana%(%)', '')
    assert(nGetMana >= 4, 'bot:GetMana() call sites in ' .. SRC .. ': ' .. nGetMana)

    -- (b) The 对线期消耗 block's own tower guard is NOT this lever.  Two of its
    -- three `#nTowers == 0` conjuncts are byte-for-byte implied by the block
    -- guard above them (same local, never reassigned), i.e. they are dead
    -- conjuncts -- a no-op, which is exactly why this round did not touch them.
    -- Registered here so the next round does not re-derive it.
    local _, nTowerTerms = src:gsub('#nTowers == 0', '')
    assert(nTowerTerms == 3, 'the 对线期消耗 block\'s `#nTowers == 0` terms now '
        .. 'number ' .. nTowerTerms .. ', not 3; two of the three were measured '
        .. 'to be dead conjuncts on 2026-09-16 and that reading is now stale')
    local _, nTowerAssign = src:gsub('nTowers = bot:GetNearbyTowers%( 900, true %)', '')
    assert(nTowerAssign == 1, 'the block\'s nTowers local is no longer assigned '
        .. 'exactly once at radius 900; the "dead conjunct" reading above '
        .. 'depended on it never being reassigned')

    -- (c) `J.GetAllyUnitCountAroundEnemyTarget` -- the third lane firing point's
    -- only quality term -- is UNASKABLE on this corpus: bot:GetNearbyCreeps
    -- answers an empty list on every live-CM instant, and allied creeps are most
    -- of that count's summands.  Nobody may read "the swarm branch never fires"
    -- off this archive.
    local nCreepy = 0
    for _, path in ipairs(corpus_paths()) do
        local ok, chunk = pcall(dofile, path)
        if ok and type(chunk) == 'table' then
            local present = false
            for _, u in ipairs(chunk.units or {}) do
                if u.name == UNIT and u.alive ~= false then present = true end
            end
            if present then
                local _, bot = rf.load(path, UNIT)
                local tAlly = bot:GetNearbyCreeps(1600, false)
                if tAlly ~= nil and #tAlly > 0 then nCreepy = nCreepy + 1 end
            end
        end
    end
    assert(nCreepy == 0,
        'the loader now supplies creeps on ' .. nCreepy .. ' live-CM instant(s). '
        .. 'J.GetAllyUnitCountAroundEnemyTarget stops being UNASKABLE -- the '
        .. 'third lane firing point becomes measurable and is worth a lever.')
end

return tests

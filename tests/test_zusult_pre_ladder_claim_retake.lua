-- GH #416 acceptance, criteria (1)(2)(3): re-take, one by one, every durable
-- claim of the form "on fixture F the `zusult` gate reached / did not reach a
-- decision" that was written BEFORE 2026-09-01 -- i.e. while the fixture
-- loader answered 0 to every `GetManaCost()` and the gate therefore returned
-- false at its fourth line, before reading its second operand.
--
-- WHAT #416 ESTABLISHED (not re-argued here; `tests/test_focus_mana_cost_
-- consumer_census.lua` §6/§6b own it): `X.zuus_ShouldSaveManaForUlt`'s fourth
-- line is `if nCost == nil or nCost <= 0 then return false end`, so before
-- c386d5f3 the gate's fixture domain was EMPTY -- 0 of the 16 Zeus frames whose
-- ult is trained-and-ready ever got past that line; today 7 do. Real Turbo
-- games were never affected (the engine has always priced abilities), so the
-- farm's `zusult` readings stand. What needed re-taking is the fixture-level
-- claims.
--
-- WHAT THIS FILE ADDS -- the three things #416 asked for:
--   (1) the DOMAIN of such claims, enumerated by scanning tests/ rather than
--       recalled (§1), so a new arming file cannot join it silently;
--   (2) `zusultx` checked alongside `zusult` (§3, §5) -- same body, same line;
--   (3) each claim either re-read UNCHANGED with the reason it does not depend
--       on the price line (§2, §3), or landed with a new reading (§4).
--
-- HEADLINE OF THE RE-TAKE: **all five frame-level verdicts are unchanged**, and
-- the reason is not luck -- every arming file hand-anchors the ult price onto
-- the handle (`rawget(abilityR, '__spec').GetManaCost = N`), i.e. those claims
-- were never taken through the loader's 0 in the first place. §4 is where the
-- re-take is nevertheless worth its keep: on the SAFE control frame the
-- anchored margin of 26 mana becomes a margin of EXACTLY 0 under the ladder's
-- own prices, so that verdict now rests on the `>=` in the comparison. Same
-- answer, one mana of room.
--
-- ⚠️ NOT CLAIMED HERE: that the ladder's prices are more correct than the
-- files' replay-measured anchors. §4 registers only that they differ, that the
-- difference has ONE sign across all six (ladder >= anchor, every time), and
-- that mana regen between two 0.5s dumper snapshots can only ever make a
-- measured spend look SMALLER than it was -- which is the same sign. Whether
-- the engine's live number is 250 is not a desk question.
--
-- `bots/` and `game/`: zero lines. No gate, no id, no arm request, no AWS.

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')

local CROSS  = 'tests/fixtures/f_260820_042607_zuus_reserve_cross.lua'
local SAFE   = 'tests/fixtures/f_260820_042607_zuus_reserve_safe.lua'
local LOCK   = 'tests/fixtures/f_260819_142047_zuus_ult_manalock.lua'
local DENIED = 'tests/fixtures/f_260819_142047_zuus_ult_denied.lua'
local W2LEAK = 'tests/fixtures/f_260819_222052_zuus_w2_leak.lua'

local BOLT = 'zuus_lightning_bolt'

--- Drive the REAL gate on a real frame, with the loader's own prices.
--- @param sFrame  fixture path
--- @param tIds    soak-candidate ids to arm
--- @param sTarget enemy hero name (nil = no target)
--- @param opts    { zeroUlt=true -> put the pre-2026-09-01 0 back on the ult
---                  handle and nothing else; zeroSpend=true -> same, on the
---                  bidding ability's handle }
--- @return the gate's answer, how many times the SPEND price was read, and the
---         two prices the gate saw.
local function gate(sFrame, tIds, sTarget, opts)
    opts = opts or {}
    local J, bot, heroes = rf.load(sFrame)
    J.IsSoakCandidate = function(id) return tIds[id] == true end
    local X = rf.load_hero('zuus')

    local sAbilityList = J.Skill.GetAbilityList(bot)
    -- GH #36 tripwire: if the ultimate slot is unreachable every case below is
    -- a false green, because the gate bails two lines before the price.
    assert(sAbilityList[6] == 'zuus_thundergods_wrath',
        'the ultimate must be reachable in the fixture world (GH #36)')
    local hR = bot:GetAbilityByName(sAbilityList[6])
    local nUltPrice = hR:GetManaCost()
    if opts.zeroUlt then rawget(hR, '__spec').GetManaCost = function() return 0 end end

    local hSpell = bot:GetAbilityByName(BOLT)
    local nSpendPrice = hSpell:GetManaCost()
    -- Counting the reads is what separates "the body ran and changed nothing"
    -- from "the body was never reached" -- the two look identical in the return
    -- value, and telling them apart is the whole subject of this file.
    local nSpendReads = 0
    rawget(hSpell, '__spec').GetManaCost = function()
        nSpendReads = nSpendReads + 1
        return opts.zeroSpend and 0 or nSpendPrice
    end

    local hTarget = sTarget and heroes[sTarget] or nil
    local bAnswer = X.zuus_ShouldSaveManaForUlt(bot, hTarget, hSpell)
    return bAnswer, nSpendReads, nUltPrice, nSpendPrice, bot:GetMana()
end

local tests = {}

-- ---------------------------------------------------------------------------
-- 1.  The domain, enumerated -- which test files can carry such a claim at all.
-- ---------------------------------------------------------------------------
-- A file can only make a claim about this gate's decision if it ARMS one of the
-- two ids: with neither armed the gate returns false on its third line, before
-- the price is read, so its answer is independent of the ladder by
-- construction. So the domain is exactly the arming files -- and it is scanned,
-- not recalled, because the failure mode #416 documents is a claim nobody
-- remembered was resting on a zero.

-- The three that hand-anchor the ult price (§2) -- the pre-2026-09-01 claims.
local T_MANALOCK = 'tests/test_replay_260819_zuus_ult_manalock.lua'
local T_W2LEAK   = 'tests/test_replay_260819_zuus_w2_leak.lua'
local T_CROSS    = 'tests/test_replay_260820_zuus_reserve_cross.lua'
-- Arms the id inside a whole-test-set sweep on a RETREAT mode file (§3).
local T_TOWERFEAR = 'tests/test_towerfear_clock_leg.lua'
-- Born 2026-09-02, i.e. AFTER c386d5f3: it is the file that MEASURED the empty
-- domain (#416 §6). Nothing in it was ever taken through the loader's 0, so it
-- is in the arming set but has nothing to re-take. Listed rather than filtered
-- out, because "the scan found a file I did not expect" is the signal §1 is for.
local T_CENSUS = 'tests/test_focus_mana_cost_consumer_census.lua'
-- Born 2026-09-04 (GH #477, candidate `zusboltdom`), i.e. also after c386d5f3
-- and also with nothing to re-take. It arms `zusult` because the leak it pins
-- is only observable while the reserve gate is armed -- an unarmed run cannot
-- tell "the branch reported no target" from "there was nothing to report to".
-- It hand-anchors the ult price on the handle exactly as §2 requires, and is
-- asserted to do so there.
local T_BOLTDOM = 'tests/test_replay_260819_zuus_boltdom.lua'

local ARMING_FILES = {
    T_CENSUS, T_MANALOCK, T_W2LEAK, T_CROSS, T_TOWERFEAR, T_BOLTDOM,
}
table.sort(ARMING_FILES)

local function read_file(sPath)
    local f = assert(io.open(sPath, 'r'), 'cannot read ' .. sPath)
    local s = f:read('*a')
    f:close()
    return s
end

--- Does this source arm `zusult` or `zusultx`? It must both quote the id and
--- install its own `IsSoakCandidate`, which is how every fixture test arms one.
local function arms_zusult(src)
    if not src:find('IsSoakCandidate', 1, true) then return false end
    return src:find("'zusult'", 1, true) ~= nil or src:find("'zusultx'", 1, true) ~= nil
end

tests['[1] domain: exactly five test files arm the ids, four predate the ladder'] = function()
    local tFound, nScanned = {}, 0
    local p = assert(io.popen('ls tests/test_*.lua'))
    for sPath in p:lines() do
        nScanned = nScanned + 1
        if sPath ~= 'tests/test_zusult_pre_ladder_claim_retake.lua'
            and arms_zusult(read_file(sPath)) then
            table.insert(tFound, sPath)
        end
    end
    p:close()
    assert(nScanned > 100, 'the scan must actually see the suite, saw ' .. nScanned)
    table.sort(tFound)

    local sGot = table.concat(tFound, '\n  ')
    local sWant = table.concat(ARMING_FILES, '\n  ')
    assert(sGot == sWant,
        'the set of files that arm zusult/zusultx moved. Every member carries a '
            .. 'claim about a gate whose fixture domain was empty before '
            .. '2026-09-01 (GH #416) and must be re-taken here.\n  got:\n  '
            .. sGot .. '\n  want:\n  ' .. sWant)
end

-- ---------------------------------------------------------------------------
-- 2.  Reason (a) the claims survive: the price was never the loader's.
-- ---------------------------------------------------------------------------
-- Three of the four hand-anchor the ult's mana cost onto the handle before
-- calling anything. That anchor is why their pre-2026-09-01 readings were not
-- vacuous -- and it is a fact about the file, quoted here so that deleting the
-- anchor (which today would silently hand the reading back to the ladder) fails
-- loudly instead.

local ANCHOR = "rawget(abilityR, '__spec').GetManaCost"

tests['[2] the three hero-gate files each anchor the ult price themselves'] = function()
    -- T_BOLTDOM is post-ladder and has nothing to re-take, but it is held to
    -- the same standard: without the anchor its readings would ride the
    -- ladder's price silently.
    for _, sPath in ipairs({ T_MANALOCK, T_W2LEAK, T_CROSS, T_BOLTDOM }) do
        local src = read_file(sPath)
        assert(src:find(ANCHOR, 1, true) ~= nil,
            sPath .. ' must anchor the ult price on the handle -- without it '
                .. 'its readings were taken through the loader\'s 0 (GH #416)')
    end
end

-- ---------------------------------------------------------------------------
-- 3.  Reason (b): the fourth file cannot reach the gate at all.
-- ---------------------------------------------------------------------------
-- test_towerfear_clock_leg.lua arms `zusult` as one member of the whole test set
-- and asserts that no member moves a RETREAT-mode bid. That claim cannot depend
-- on the price line for a structural reason: the helper has no call site outside
-- hero_zuus.lua, so no mode script can reach it. Stated as a fact about bots/.

tests['[3] the gate has no call site outside hero_zuus.lua (consumer-side)'] = function()
    local p = assert(io.popen(
        "grep -rln 'zuus_ShouldSaveManaForUlt' bots/ game/ 2>/dev/null"))
    local tFiles = {}
    for sPath in p:lines() do table.insert(tFiles, sPath) end
    p:close()
    table.sort(tFiles)
    -- hero_lion.lua names it in a comment only; the call sites are all in Zeus.
    local src = read_file('bots/BotLib/hero_zuus.lua')
    -- Whitespace-tolerant on purpose: a reformat must not read as a moved call
    -- site. `bot` as the first argument separates the three calls from the
    -- definition (`hBot`) and from the prose mention at the bottom of the file.
    local _, nCalls = src:gsub('X%.zuus_ShouldSaveManaForUlt%s*%(%s*bot%s*,', '')
    assert(nCalls == 3,
        'the three SkillsComplement bids are the only call sites, found ' .. nCalls)
    local lion = read_file('bots/BotLib/hero_lion.lua')
    assert(lion:find('zuus_ShouldSaveManaForUlt', 1, true) ~= nil
        and lion:find('X.zuus_ShouldSaveManaForUlt(', 1, true) == nil,
        'hero_lion.lua may name the helper in prose but must not call it')
    assert(#tFiles == 2, 'only two files mention it at all, got ' .. #tFiles)
    -- No mode script mentions it => the retreat bid towerfear measures cannot
    -- route through this gate, whatever the ult costs.
    for _, sPath in ipairs(tFiles) do
        assert(sPath:find('bots/BotLib/hero_', 1, true) == 1,
            'a non-hero file reached the gate: ' .. sPath)
    end
end

-- ---------------------------------------------------------------------------
-- 4.  The re-take itself: five frames, loader prices only, no anchors.
-- ---------------------------------------------------------------------------
-- Every verdict below is the one its own file asserts under its hand anchors.
-- Re-taken here with the LADDER's prices instead, i.e. the world a reader who
-- did not anchor would land in today.

tests['[4a] CROSS re-taken on ladder prices: zusult stands aside, zusultx holds'] = function()
    local bBase, nBaseReads, nUlt, nSpend, nMana = gate(CROSS, { zusult = true },
        'npc_dota_hero_lion')
    assert(nMana == 256 and nUlt == 250 and nSpend == 135,
        'ladder world on CROSS: 256 mana, ult 250, bolt 135; got '
            .. nMana .. ' / ' .. nUlt .. ' / ' .. nSpend)
    assert(bBase == false,
        'GH #59 unchanged: 256 >= 250 reads as "nothing is being denied"')
    assert(nBaseReads == 0,
        'and the narrow id never reads the spend price at all -- that read is '
            .. 'the whole of the widening')

    local bWide, nWideReads = gate(CROSS, { zusultx = true }, 'npc_dota_hero_lion')
    assert(bWide == true and nWideReads == 1,
        '256 - 135 = 121 does not pay 250, so the spend is held (reads='
            .. nWideReads .. ')')
end

tests['[4b] LOCK / DENIED / W2LEAK re-taken: hold, release, hold -- unchanged'] = function()
    local bLock = gate(LOCK, { zusult = true }, 'npc_dota_hero_dragon_knight')
    assert(bLock == true, 'LOCK: 99 mana under a 250 ult, healthy target => hold')

    local bDenied = gate(DENIED, { zusult = true }, 'npc_dota_hero_lich')
    assert(bDenied == false,
        'DENIED: the 21%-HP lich is a kill window -- the gate never stands '
            .. 'between Zeus and a dying enemy')

    local bLeak = gate(W2LEAK, { zusult = true }, 'npc_dota_hero_shadow_shaman')
    assert(bLeak == true, 'W2LEAK: 152 mana under a 250 ult, full-HP target => hold')
end

tests['[4c] SAFE re-taken: same verdict, and the margin is now EXACTLY 0'] = function()
    local bWide, nReads, nUlt, nSpend, nMana = gate(SAFE, { zusultx = true },
        'npc_dota_hero_ember_spirit')
    assert(nMana == 380 and nUlt == 250 and nSpend == 130,
        'ladder world on SAFE: 380 mana, ult 250, bolt 130; got '
            .. nMana .. ' / ' .. nUlt .. ' / ' .. nSpend)
    assert(bWide == false and nReads == 1,
        'the widened gate still allows this poke (reads=' .. nReads .. ')')
    -- ⭐ The knife edge, exposed rather than smoothed over (README 计量 (ii)):
    -- the file's own anchors leave 380 - 129 = 251 against a 225 ult, a margin
    -- of 26. The ladder leaves 380 - 130 = 250 against 250: the verdict is
    -- carried by the `=` in `>=` and nothing else.
    assert(nMana - nSpend == nUlt,
        'the re-taken control sits exactly on the comparison boundary: '
            .. nMana .. ' - ' .. nSpend .. ' == ' .. nUlt)
end

tests['[4d] every hand anchor is <= the ladder price, all six, one sign'] = function()
    -- The six external anchors in the three files, paired with the ladder price
    -- for the same ability at the same rank on the same frame. Regen between
    -- two 0.5s snapshots can only DEFLATE a measured spend, so a replay-measured
    -- price is a lower bound -- and every pair below has that sign. This is a
    -- registration of a systematic direction, NOT a claim that 250 is right.
    local tPairs = {
        { 'manalock ult',  246, 250 },   -- header: 253 -> 7 across the cast
        { 'w2leak ult',    225, 250 },   -- header band [216, 248]
        { 'cross ult',     225, 250 },   -- header band [216, 248]
        { 'cross bolt',    130, 135 },   -- rank 4; header measured 133
        { 'safe bolt',     129, 130 },   -- rank 3; header measured 129
        { 'cross arc',      91,  95 },   -- rank 3
    }
    for _, e in ipairs(tPairs) do
        assert(e[2] <= e[3],
            e[1] .. ': the anchor (' .. e[2] .. ') is above the ladder ('
                .. e[3] .. ') -- that breaks the regen argument, look again')
    end
    -- And the ladder really is the source of those numbers on the live frames.
    local _, _, nUltCross, nBoltCross = gate(CROSS, {}, nil)
    local _, _, _, nBoltSafe = gate(SAFE, {}, nil)
    assert(nUltCross == 250 and nBoltCross == 135 and nBoltSafe == 130,
        'the ladder column must be read off the frames, got ' .. nUltCross
            .. ' / ' .. nBoltCross .. ' / ' .. nBoltSafe)
end

-- ---------------------------------------------------------------------------
-- 5.  ⭐ The new shape: pre-2026-09-01, `zusultx` was `zusult`.
-- ---------------------------------------------------------------------------
-- #416 answered criterion (2) as "same body, same line". It is worse than that,
-- and only on the widened id: the widening lives entirely in
--
--     local nSpellCost = hSpell:GetManaCost()
--     if type(nSpellCost) == 'number' and nSpellCost > 0 then nSpend = nSpellCost end
--
-- so a 0 does not merely end the call -- it silently sets the increment to
-- zero and lets the SHIPPED clause answer. A pre-ladder fixture that armed
-- `zusultx` therefore measured `zusult`, and measured it while looking like it
-- had measured the widening. The only reason no such reading exists in the repo
-- is that `zusultx`'s single consumer anchors both operands by hand (§2).

tests['[5] pre-ladder, the zusultx increment collapses to zero on its own frame'] = function()
    -- Same frame, same armed id, one operand put back to its pre-ladder 0.
    local bToday = gate(CROSS, { zusultx = true }, 'npc_dota_hero_lion')
    local bNoSpend, nReads = gate(CROSS, { zusultx = true }, 'npc_dota_hero_lion',
        { zeroSpend = true })
    local bNarrow = gate(CROSS, { zusult = true }, 'npc_dota_hero_lion')

    assert(bToday == true, 'sanity: today the widened gate holds this spend')
    assert(bNoSpend == false and bNoSpend == bNarrow,
        'with a 0 spend price the widened id returns the NARROW id\'s answer -- '
            .. 'the increment it exists to measure is gone, not merely wrong')
    -- The control that makes the collapse a reading instead of a short circuit:
    -- the body DID reach the spend read here (unlike §6 below, where it does
    -- not), so this is the widening evaluating to nothing, not code that never
    -- ran.
    assert(nReads == 1,
        'the spend price must actually have been read on the collapsed leg, '
            .. 'reads=' .. nReads)
end

-- ---------------------------------------------------------------------------
-- 6.  The other half of the same control: where the body does NOT run.
-- ---------------------------------------------------------------------------

tests['[6] with the ult price back at 0 the gate dies before the spend read'] = function()
    for _, e in ipairs({ { CROSS, 'npc_dota_hero_lion' },
                         { LOCK,  'npc_dota_hero_dragon_knight' },
                         { W2LEAK, 'npc_dota_hero_shadow_shaman' } }) do
        local bPre, nReads = gate(e[1], { zusult = true, zusultx = true }, e[2],
            { zeroUlt = true })
        assert(bPre == false,
            e[1] .. ': a 0 ult price must end the call at `nCost <= 0`')
        assert(nReads == 0,
            e[1] .. ': and it must end BEFORE the spend price is read, got '
                .. nReads .. ' read(s) -- if this ever becomes non-zero the '
                .. 'pre-ladder world was not what §5 says it was')
    end
    -- The same three frames DO get past that line today; without this the block
    -- above would pass just as well on frames where nothing was ever reachable.
    local _, nCross = gate(CROSS, { zusultx = true }, 'npc_dota_hero_lion')
    assert(nCross == 1, 'sanity: the CROSS frame reaches the spend read today')
end

return tests

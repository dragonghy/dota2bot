-- [grenharass] The bot buys a 25-gold laning consumable on 51 hero builds and
-- only ever throws it as an execute.
--
-- WHAT THIS FILE ASSERTS
-- ----------------------
-- X.ConsiderItemDesire['item_blood_grenade']
-- (bots/ability_item_usage_generic.lua ~:7209) is SHIPPED and un-gated, and
-- BOTH of its branches are kill-confirms:
--
--   loop 1  `J.CanKillTarget(enemyHero, totalDmg, DAMAGE_TYPE_MAGICAL)` --
--           the grenade's own 125 (50 impact + 15/s for 5s) must finish the
--           target.  There is an extension to 275, but it is guarded by
--           `bot:IsFacingLocation(enemyHero:GetLocation(), 15)` -- a
--           15-DEGREE cone -- on top of being inside `bot:GetAttackRange()`.
--   loop 2  `J.IsGoingOnSomeone(bot)` AND an ally who is already chasing the
--           same hero AND
--           `J.GetTotalEstimatedDamageToTarget(nInRangeAlly, enemyHero)
--            >= enemyHero:GetHealth()` -- i.e. the allies' own damage already
--           kills, and the grenade is decoration on a corpse.
--
-- Nothing in the entry throws a grenade to WIN A TRADE, which is the use the
-- item exists for: 25 gold, max stock 2, restocked all through the lane, on the
-- buy list of 51 hero files under bots/BotLib.  Section 4 counts that 51 rather
-- than asserting a flag, because a flag reads the same whether the item is on
-- one build or on fifty (the 'stayurn' M6 survivor).
--
-- MEASURED ON THE CORPUS (section 3, tests/_grenharass_sweep.lua):
--
--     1012 live hero frames / 109 fixtures
--      238 carry a grenade SOMEWHERE, 100 in a MAIN slot (0-5)
--       40 of those 100 see an enemy hero inside the 900 cast range
--       40 of those 40 clear valid / non-magic-immune / not-illusion
--        0 of those 40 can be killed by the grenade's 125            <- loop 1
--        3 could be killed by 275, and loop 1 reaches that number only
--          through the 15-degree facing cone
--
-- ⭐ AND THE DRIVEN COLUMN AGREES WITH THE PREFIX COLUMN, WHICH IS THE POINT.
-- Running the shipped `_G.ItemUsageThink` on all 40 frames and reading the
-- recorded engine action: 0 grenade casts shipped, 8 armed -- the same 8 the
-- conjunct walk calls the domain.  Two independent instruments, one number.
-- Neither stands in for the other and both are asserted.
--
-- THE LEVER, in the item's own yardstick rather than a taste threshold: throw
-- when `enemyHero:GetHealth() <= totalDmg * 3`, i.e. when the grenade removes
-- at least a third of what the target has left.  Domain 8 of the 40; the target
-- healths are 225-363 (section 3 lists all eight frames).
--
-- ⛔ DIRECTION IS FIXED BY CONSTRUCTION, AND SECTION 2 PARSES THAT RATHER THAN
-- QUOTING THE COMMENT.  The gated block is appended AFTER both shipped loops
-- return and BEFORE the entry's final `return BOT_ACTION_DESIRE_NONE`, so
-- arming can only turn NONE into a cast: it can never redirect, delay or outbid
-- a throw the shipped code already makes.  `flip_true_to_false` is therefore 0
-- over the whole corpus -- and because an all-zero counter cannot tell "the
-- direction holds" from "the tally never ran" (the M14/M15 lesson of the
-- 'staytower' and 'wkreinctr' rounds), the sweep runs BOTH directions through
-- ONE `tally()` and calls it a second time with the legs SWAPPED.  The branch
-- that must read 0 on the real call is the branch that must report all 8 on the
-- swapped call, and section 3 asserts both.
--
-- HONEST BOUNDS, stated rather than buried:
--   * The corpus cannot reach this entry through the shipped dispatcher at all.
--     `J.CanCastAbility` short-circuits on `not IsTrained()` for every fixture
--     item handle -- the sixteenth world assertion,
--     tests/test_itemdesire_world_assertion.lua.  The sweep supplies
--     IsTrained/IsActivated/IsFullyCastable to the GRENADE handle and to it
--     only, exactly as the 'urnself' round did.  Every other conjunct of the
--     decision is left to the shipped code.
--   * The mock applies NO magic resistance (`GetActualIncomingDamage` returns
--     the raw damage), so every CanKillTarget reading here is an UPPER bound.
--     That is the safe direction for "the shipped kill-confirm fires on zero
--     frames" and the unsafe direction for any claim that a throw kills.  This
--     lever claims no kill and nothing below asserts one.
--   * `nHealth > nHealthCost * 2` is TRUE on all 40 frames.  It does not bind
--     on this corpus; it is kept because it is the shipped entry's own
--     self-preservation rule, not because it was measured to matter.  Recorded
--     as a number (section 3) rather than smoothed over.
--   * 2 of the 40 frames could not be DRIVEN (the file re-load raised).  They
--     are counted, and `driven + undriven == loop` is asserted, so a drive that
--     dies cannot quietly shrink the denominator the flip columns are read
--     against.
--
-- Mutation stand: tools/agent/mutstand_grenharass.sh

package.path = 'tests/?.lua;' .. package.path
local cs = require('corpus_scale')

local AIUG = 'bots/ability_item_usage_generic.lua'

local tests = {}

-- ==========================================================================
-- 1. The entry, read off the tree
-- ==========================================================================

local function read_file(path)
    local f = assert(io.open(path, 'r'), path .. ' is not readable')
    local s = f:read('*a')
    f:close()
    return s
end

-- The lever ships with a long comment that quotes both shipped loops, the id
-- name and the threshold.  Reading the raw block would let the COMMENT satisfy
-- every assertion below (the §EN mistake), so it is stripped first.
local function strip_comments(s) return (s:gsub('%-%-[^\n]*', '')) end

local body_cache = nil
local function entry()
    if body_cache ~= nil then return body_cache end
    local src = read_file(AIUG)
    local at = assert(src:find("X.ConsiderItemDesire['item_blood_grenade'] = function",
        1, true), 'the blood grenade item-desire entry is gone from ' .. AIUG)
    local stop = src:find('\nX.ConsiderItemDesire[', at + 10, true) or #src
    body_cache = strip_comments(src:sub(at, stop))
    return body_cache
end

tests['[ship] both shipped branches of the grenade entry are kill-confirms'] = function()
    local b = entry()
    local n = 0
    for _ in b:gmatch('J%.CanKillTarget') do n = n + 1 end
    assert(n == 2, 'the shipped entry now makes ' .. n .. ' CanKillTarget '
        .. 'calls, not 2 -- the finding this lever rests on is that loop 1 is a '
        .. 'kill-confirm; re-read it before re-baselining')
    assert(b:find('J.IsGoingOnSomeone(bot)', 1, true),
        "loop 2's IsGoingOnSomeone guard is gone -- on this corpus it is the "
        .. 'clause that makes loop 2 structurally unreachable')
    assert(b:find('J.GetTotalEstimatedDamageToTarget', 1, true),
        "loop 2 no longer requires the allies' own damage to already kill the "
        .. 'target; that requirement is half of the finding')
    local cone = b:match('IsFacingLocation%(enemyHero:GetLocation%(%), (%d+)%)')
    assert(tonumber(cone) == 15, 'the attack-range extension of loop 1 now uses '
        .. 'a ' .. tostring(cone) .. '-degree facing cone, not 15')
end

tests["[ship] the item's own numbers are read off the entry, not restated"] = function()
    local b = entry()
    local function num(pat, label)
        local v = tonumber(b:match(pat))
        assert(v ~= nil, 'the grenade entry no longer declares ' .. label)
        return v
    end
    assert(num('local nCastRange = (%d+)', 'nCastRange') == 900,
        'the declared cast range moved off 900')
    assert(num('local nRadius = (%d+)', 'nRadius') == 300,
        'the declared radius moved off 300')
    assert(num('local nImpactDamage = (%d+)', 'nImpactDamage') == 50,
        'the declared impact damage moved off 50')
    assert(num('local nDPS = (%d+)', 'nDPS') == 15,
        'the declared damage per second moved off 15')
    assert(num('local nDuration = (%d+)', 'nDuration') == 5,
        'the declared bleed duration moved off 5')
    assert(num('local nHealthCost = (%d+)', 'nHealthCost') == 75,
        'the declared health cost moved off 75')
    -- totalDmg is what the lever's threshold is written in, so the entry must
    -- keep computing it rather than carrying a literal 125.
    assert(b:find('local totalDmg = nImpactDamage + (nDPS * nDuration)', 1, true),
        'totalDmg is no longer derived from the declared constants; the '
        .. "lever's threshold is written in it and would silently drift")
end

-- ==========================================================================
-- 2. The gate: standalone, first conjunct, appended after both returns
-- ==========================================================================

tests['[gate] the id is the first conjunct and turbo is written out'] = function()
    local b = entry()
    local g = assert(b:find("J.IsSoakCandidate('grenharass')", 1, true),
        "the 'grenharass' gate is gone from the grenade entry")
    local t = assert(b:find('J.IsModeTurbo()', 1, true),
        'the grenade entry has no IsModeTurbo above it, so turbo must be '
        .. 'written out in the gate itself -- it is not')
    local h = assert(b:find('totalDmg %* 3'),
        "the lever's health threshold is gone")
    assert(g < t and t < h, 'the gate is no longer the FIRST conjunct '
        .. '(gate/turbo/threshold read at ' .. g .. '/' .. t .. '/' .. h
        .. '); unarmed, this is what makes the shipped evaluation '
        .. 'byte-identical -- neither IsModeTurbo nor any engine call is reached')
end

tests['[gate] exactly one candidate id, and never two in one condition'] = function()
    local b = entry()
    local n = 0
    for _ in b:gmatch('IsSoakCandidate') do n = n + 1 end
    assert(n == 1, 'the grenade entry now names ' .. n .. ' candidate ids, not '
        .. '1; a second one here needs its own isolation story')
    -- The 'pullcad' trap: `IsSoakCandidate('X') and IsSoakCandidate('Y')`
    -- freezes FALSE the day Y is promoted, and check_armed_wiring.py still
    -- calls it WIRED.  Read as the maximum PER CONDITION, and the conditions
    -- are split on a frontier-anchored `then` so a `then` inside an identifier
    -- cannot re-open the scan mid-word (GH #550/#555).
    local most = 0
    for cond in b:gmatch('%f[%w]if%f[%W](.-)%f[%w]then%f[%W]') do
        local k = 0
        for _ in cond:gmatch('IsSoakCandidate') do k = k + 1 end
        if k > most then most = k end
    end
    assert(most <= 1, 'a condition in the grenade entry now carries ' .. most
        .. ' candidate ids; a conjunction of two ids is frozen FALSE the day '
        .. 'either is promoted')
end

tests['[gate] the block is appended after both shipped returns'] = function()
    local b = entry()
    local g = assert(b:find("IsSoakCandidate('grenharass')", 1, true))
    local none = assert(b:find('return BOT_ACTION_DESIRE_NONE', 1, true),
        'the entry no longer ends on BOT_ACTION_DESIRE_NONE')
    local lastHigh, i = nil, nil
    repeat
        i = b:find('return BOT_ACTION_DESIRE_HIGH', (i or 0) + 1, true)
        if i and i < g then lastHigh = i end
    until i == nil
    assert(lastHigh ~= nil, 'no shipped `return BOT_ACTION_DESIRE_HIGH` precedes '
        .. 'the gate -- the whole direction argument is that arming cannot '
        .. 'preempt a throw the shipped code already makes')
    assert(lastHigh < g and g < none,
        'the gated block is no longer between the last shipped return and the '
        .. 'final NONE; direction is no longer fixed by construction')
end

tests['[gate] every conjunct but the threshold is copied from loop 1'] = function()
    local b = entry()
    -- Each of these must appear THREE times: twice in the two shipped loops,
    -- once in the gated one.  Counted, not flagged, so a drift in either copy
    -- is visible as a number.
    for _, k in ipairs({ 'J.IsValidHero', 'J.CanCastOnNonMagicImmune',
        'J.IsSuspiciousIllusion', 'nHealth > nHealthCost * 2',
        'J.GetEnemiesNearLoc', 'J.GetCenterOfUnits' }) do
        local n, i = 0, 0
        while true do
            i = b:find(k, i + 1, true)
            if i == nil then break end
            n = n + 1
        end
        assert(n == 3, '`' .. k .. '` appears ' .. n .. ' times in the grenade '
            .. 'entry, not 3 (two shipped loops + the gated copy) -- either a '
            .. 'shipped loop changed or the copy drifted')
    end
end

-- ==========================================================================
-- 3. The corpus, driven
-- ==========================================================================

-- Memoised: the sweep re-loads ability_item_usage_generic.lua twice per driven
-- frame and costs minutes.  Several bodies read it and a mutation stand runs
-- the whole file a dozen times; the sweep is a pure function of the tree and
-- the tree does not change inside one process.
local sweep_cache = nil
local function sweep()
    if sweep_cache ~= nil then return unpack(sweep_cache) end
    local p = assert(io.popen('lua5.1 tests/_grenharass_sweep.lua 2>/dev/null'))
    local s = p:read('*a')
    p:close()
    assert(s:find('\nDONE', 1, true) or s:find('^DONE'),
        'tests/_grenharass_sweep.lua did not reach its DONE line -- the '
        .. 'subprocess failed, and a truncated manifest must never be read as a '
        .. 'small measurement')
    local G, C, F, W = {}, {}, {}, {}
    for line in s:gmatch('[^\n]+') do
        local k, v = line:match('^G (%S+) (%S+)$')
        if k then G[k] = tonumber(v) or v end
        local ck, cv = line:match('^C (%S+) (%-?%d+)$')
        if ck then C[ck] = tonumber(cv) end
        if line:match('^F ') then F[#F + 1] = line end
        if line:match('^W ') then W[#W + 1] = line end
    end
    sweep_cache = { G, C, F, W }
    return G, C, F, W
end

tests['[corpus] the funnel down to the enemy loop'] = function()
    local _, C = sweep()
    -- These two restate the SIZE of tests/fixtures/ and nothing else, so they
    -- go through corpus_scale: an equality here is the GH #106/#127 defect and
    -- turns red on the next fixture anybody lands (GH #585 is the fourth
    -- instance of it, three of them landed by this stream).
    cs.ratchet(C.live, 1012, 'live hero frames')
    cs.corpus(C.fixtures, 'fixture corpus')
    assert(C.raises == 0, tostring(C.raises) .. ' frame(s) raised inside the '
        .. 'enemy ring walk; a raise is not a measurement')
    -- Carrier counts are sums over fixtures too.
    cs.ratchet(C.carrier_any, 238, 'frames carrying a grenade anywhere')
    cs.ratchet(C.carrier_main, 100, 'frames carrying a grenade in a main slot')
    cs.ratchet(C.loop, 40, 'carrier frames with an enemy hero in cast range')
    -- The candidate filter is a claim about THIS corpus's geometry, not about
    -- its size: on all 40 frames every enemy in range is a valid,
    -- non-magic-immune, non-illusion hero.  If that stops holding, the domain
    -- reading below is being taken through a different filter and must be
    -- re-read, so it stays an equality against `loop`.
    assert(C.cand == C.loop, 'the valid/non-immune/not-illusion filter now '
        .. 'removes frames (' .. C.cand .. ' of ' .. C.loop .. '); the domain '
        .. 'below was measured through a filter that removed none')
end

tests['[corpus] the shipped kill-confirm fires on zero frames'] = function()
    local _, C = sweep()
    -- ⛔ ZERO-CLAIM, deliberately an equality: it is already growth-immune, and
    -- it is the assertion the whole finding is argued from.  It must go red the
    -- moment the corpus grows a counter-example -- that is the point of it.
    assert(C.ship_kill125 == 0, 'the shipped loop-1 kill-confirm now fires on '
        .. C.ship_kill125 .. ' frame(s); "the tree only throws this item as an '
        .. 'execute, and never gets to" is the finding -- re-read it')
    -- The 275 extension is the honest counterweight: 3 frames COULD be killed
    -- at that number, and loop 1 reaches it only through the 15-degree facing
    -- cone.  Reported so the zero above cannot be read as "no enemy was ever
    -- killable by anything".
    assert(C.ship_kill275 == 3, 'the 275-damage extension now reaches '
        .. C.ship_kill275 .. ' frame(s), not 3')
    -- And the driven column says the same thing with a different instrument.
    assert(C.cast_ship == 0, 'the shipped tree now throws a grenade on '
        .. C.cast_ship .. ' driven frame(s); it threw none when this lever was '
        .. 'written')
end

tests['[corpus] the lever lands 8 flips, all of them NONE -> cast'] = function()
    local _, C, F = sweep()
    assert(C.domain == 8, 'the conjunct walk now puts the domain at '
        .. C.domain .. ', not 8')
    assert(C.cast_armed == 8, 'the DRIVEN column now reports ' .. C.cast_armed
        .. ' armed grenade casts, not 8')
    assert(C.domain == C.cast_armed, 'the conjunct walk (' .. C.domain
        .. ') and the driven engine actions (' .. C.cast_armed .. ') disagree; '
        .. 'they are two independent instruments on one number and neither may '
        .. 'stand in for the other')
    assert(#F == C.flips, 'the manifest lists ' .. #F .. ' flip rows but counts '
        .. C.flips)
    assert(C.flips == 8, 'the flip set is now ' .. C.flips .. ', not 8')
    -- ⛔ Direction. `flip_true_to_false` must be 0 because the block is
    -- appended after both returns -- and an all-zero counter cannot tell "the
    -- direction holds" from "the tally never ran".  The SAME tally is called
    -- with the legs swapped, so the branch that reads 0 here is the branch that
    -- must report the whole flip set there.  Deleting either bump moves the
    -- manifest.
    assert(C.flip_true_to_false == 0, 'arming turned a shipped cast OFF on '
        .. C.flip_true_to_false .. ' frame(s); this block is appended after '
        .. 'both shipped returns and cannot do that')
    assert(C.flips_swapped == 0, 'the swapped leg reports ' .. C.flips_swapped
        .. ' where it must report 0')
    assert(C.flip_true_to_false_swapped == C.flips,
        'the swapped leg reports ' .. C.flip_true_to_false_swapped
        .. ' but the flip set is ' .. C.flips .. '; without this the zero '
        .. 'above cannot be told from a tally that never ran')
end

tests['[corpus] the domain is attributable to this id alone'] = function()
    local _, C = sweep()
    assert(C.arm_leak == 0, 'the sweep\'s J.IsSoakCandidate stub answered TRUE '
        .. 'for another live id on ' .. C.arm_leak .. ' frame(s); the flips '
        .. 'could then belong to that id')
    -- The self-preservation floor does not bind on this corpus.  Recorded as a
    -- number so that "the lever is guarded" is not read as "the guard did work".
    assert(C.hp_floor == C.loop, 'the `nHealth > nHealthCost * 2` floor now '
        .. 'removes frames (' .. C.hp_floor .. ' of ' .. C.loop .. '); when '
        .. 'this lever was written it removed none, and the domain reading was '
        .. 'taken with it non-binding')
    assert(C.domain_no_hpfloor == C.domain, 'dropping the health floor now '
        .. 'changes the domain (' .. C.domain_no_hpfloor .. ' vs ' .. C.domain
        .. ')')
    -- A drive that dies must not quietly shrink the denominator.
    assert(C.driven + C.undriven == C.loop, 'driven (' .. C.driven
        .. ') + undriven (' .. C.undriven .. ') is not the ' .. C.loop
        .. ' frames that reach the loop')
    assert(C.think_crash == 0, C.think_crash .. ' frame(s) crashed inside '
        .. 'ItemUsageThink')
end

-- ==========================================================================
-- 4. The sweep's own structural parse, cross-checked against section 1-2
-- ==========================================================================
--
-- ⛔ WHY THE SAME FACTS ARE READ TWICE, and why that is not redundancy.  The
-- sweep parses the entry in a SUBPROCESS, and its numbers (the cast range it
-- walks the enemy ring with, the damage it feeds CanKillTarget) come out of
-- that parse.  If the sweep's parse drifts from this file's, the corpus columns
-- in section 3 are measurements of a DIFFERENT predicate than the one section 2
-- proved is in the tree -- and nothing would say so.  This block ties the two
-- parsers together, which is also what makes the sweep's own strip_comments
-- load-bearing: without these lines the mutation stand's M12 (strip_comments
-- becomes the identity) SURVIVED, because the sweep's structural half was
-- computed and then read by nobody.

tests['[cross] the sweep parses the same entry this file does'] = function()
    local G = sweep()
    local b = entry()
    -- The numbers the sweep MEASURES WITH.
    assert(G.CAST_RANGE == 900 and G.RADIUS == 300 and G.IMPACT == 50
        and G.DPS == 15 and G.DURATION == 5 and G.HEALTH_COST == 75,
        'the sweep read cast=' .. tostring(G.CAST_RANGE) .. ' radius='
        .. tostring(G.RADIUS) .. ' impact=' .. tostring(G.IMPACT) .. ' dps='
        .. tostring(G.DPS) .. ' dur=' .. tostring(G.DURATION) .. ' hpcost='
        .. tostring(G.HEALTH_COST) .. ' -- it walks the enemy ring and feeds '
        .. 'CanKillTarget with these, so a drift here makes section 3 a '
        .. 'measurement of a different predicate')
    -- The structure, agreeing with sections 1 and 2 read by a second parser.
    assert(G.FN == 1 and G.GATE == 1 and G.TURBO == 1 and G.GATE_FIRST == 1,
        'the sweep no longer sees the gate as the first conjunct of a turbo '
        .. 'condition inside the entry (FN=' .. tostring(G.FN) .. ' GATE='
        .. tostring(G.GATE) .. ' TURBO=' .. tostring(G.TURBO) .. ' FIRST='
        .. tostring(G.GATE_FIRST) .. ')')
    assert(G.APPENDED_AFTER_RETURN == 1,
        'the sweep no longer sees the gated block between the last shipped '
        .. 'return and the final NONE')
    assert(G.NIDS == 1 and G.IDS_MAX_PER_COND == 1,
        'the sweep counts ' .. tostring(G.NIDS) .. ' candidate id(s), at most '
        .. tostring(G.IDS_MAX_PER_COND) .. ' per condition -- section 2 counts '
        .. '1 and 1; the two parsers disagree')
    assert(G.SHIP_KILLCONFIRM == 2 and G.SHIP_GOINGON == 1
        and G.SHIP_ALLYDMG == 1 and G.SHIP_FACING_CONE == 15,
        'the sweep no longer reads both shipped branches as kill-confirms '
        .. '(kills=' .. tostring(G.SHIP_KILLCONFIRM) .. ' goingon='
        .. tostring(G.SHIP_GOINGON) .. ' allydmg=' .. tostring(G.SHIP_ALLYDMG)
        .. ' cone=' .. tostring(G.SHIP_FACING_CONE) .. ')')
    for _, k in ipairs({ 'J_IsValidHero', 'J_CanCastOnNonMagicImmune',
        'J_IsSuspiciousIllusion', 'nHealth___nHealthCost___2',
        'J_GetEnemiesNearLoc', 'J_GetCenterOfUnits' }) do
        assert(G['COPY_' .. k] == 3, 'the sweep counts ' .. tostring(G['COPY_' .. k])
            .. ' copies of ' .. k .. ', not the 3 section 2 counts')
    end
    -- And the entry this file parsed is the entry the sweep parsed: the gate
    -- must be present in both reads, not merely in one of them.
    assert(b:find("J.IsSoakCandidate('grenharass')", 1, true) ~= nil,
        'this file no longer finds the gate it just cross-checked')
end

-- ==========================================================================
-- 5. Condition (c): the item is bought to be thrown in lane
-- ==========================================================================

tests['[why] the grenade is on 51 hero build lists under bots/BotLib'] = function()
    local G = sweep()
    -- Counted, not flagged: a presence flag reads the same whether the item is
    -- on one build or on fifty, and that is exactly the survivor the 'stayurn'
    -- round's M6 produced.  The number is the condition-(c) argument -- a
    -- consumable this many builds buy, with max stock 2 and a 900-range throw,
    -- is bought to be used in lane, not saved for an execute.
    assert(G.BUYLIST_HERO_FILES >= 51, 'the grenade is now on '
        .. tostring(G.BUYLIST_HERO_FILES) .. ' hero build files, below the 51 '
        .. 'this lever\'s condition-(c) argument was measured on')
end

return tests

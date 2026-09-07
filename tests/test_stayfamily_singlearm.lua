-- [GH #576] Six candidate ids hang off ONE promoted helper. Can a single-arm
-- wave read each of them, or does one of them buy a correct zero?
--
-- WHAT THIS ANSWERS, AND WHY IT IS NOT THE QUESTION THE CENSUS ASKS
-- ----------------------------------------------------------------
-- tests/test_gated_helper_nesting_census.lua asks the IDENTITY question:
-- un-armed, is the inner helper the identity element of the conjunction it just
-- joined? For J.ShouldStayAndRegen the answer is yes and it is cheap -- five of
-- its six gates are the first conjunct of their own condition and the sixth
-- ('stayattr') sits inside a `not ... or ...` that short-circuits to the
-- shipped read. That is asserted below off the source.
--
-- GH #576 (batch desk, 2026-09-06) asks the question that costs MONEY, and it
-- is a different one. If arming one id ALONE cannot move the helper's answer --
-- because a sibling, or a shipped clause the sibling was written to widen,
-- already decided every frame in its domain -- then an isolation wave buys a
-- correct zero, and in a ruling table a correct zero and "tested, no effect"
-- are the same row. check_armed_wiring.py cannot separate them either: it
-- checks that a call site exists, not that the predicate can be true.
--
-- ⭐ THE ANSWER, AND IT IS NOT THE ONE THE ISSUE EXPECTED. Every id is
-- single-arm readable, but the corpus reads them through a distortion big
-- enough to invert which ids look alive:
--
--            gold = 0 (what a .dem carries)   gold >= 90 (what a game carries)
--   shipped TRUE set            13                          125
--   staysrc      +44                          +0
--   staybag      +2                           +0
--   staybottle   +1                           +0
--   stayurn      +2                           +0
--   stayattr     +1                           +5
--   staytower    -0                           -12
--
-- Gold is not networked into a .dem (GH #495) so `bot:GetGold()` is 0 on all
-- 1012 frames, and the shipped function's last line is
-- `if not bHasRegen and bot:GetGold() < 90 then return false end`. At gold 0
-- that line is the ONLY thing the four supply widenings can remove; at gold 90+
-- it is already false, so the four have nothing left to widen and flip NOTHING.
-- The mirror image holds for the one subtractive id: 'staytower' can only act
-- on frames the function already ACCEPTS, and at gold 0 that set is 13 frames
-- none of which has a tower inside 1200 -- so its zero is the gold clause's
-- doing, not a sibling's.
--
-- ⭐⭐ WHAT THAT MEANS FOR A WAVE, stated as the thing the batch desk asked for:
-- all six ids are readable by a single-arm wave IN A REAL GAME, and none of the
-- six zeroes measured on this corpus is caused by another id in the set. The
-- pair that COULD have hidden a lever -- the only two ids that veto rather than
-- widen -- is measured disjoint (`pair_attr_tower_both == 0`), and 'staytower'
-- subtracts exactly as much armed alone as it does armed with all five siblings
-- (12 either way). The four supply widenings are monotone by construction (each
-- sits behind `not bHasRegen`), so arming more of them can only ADD flips.
--
-- ⚠️ WHAT THIS FILE DOES NOT CLAIM. It does not claim the live flip counts are
-- these numbers: forcing gold to 200 moves ONE value the .dem does not carry
-- and leaves every other conjunct as the frame recorded it, so both columns are
-- bounds on the live domain, not the live domain. It does not claim anything
-- about a wave's statistical power. And it does not claim the six are safe to
-- arm TOGETHER -- that is the emergent-aggregate question only a batch answers.

package.path = 'tests/?.lua;' .. package.path
local cs = require('corpus_scale')

local JMZ = 'bots/FunLib/jmz_func.lua'
local IDS = { 'stayattr', 'staytower', 'staysrc', 'staybottle', 'staybag', 'stayurn' }
-- The four that widen `bHasRegen` (monotone, guarded by `not bHasRegen`) and
-- the two that act on the danger clauses above it. Split because the two halves
-- have OPPOSITE legal directions and one counter cannot hold both.
local WIDENERS = { 'staysrc', 'staybottle', 'staybag', 'stayurn' }

local tests = {}

local sweep_cache = nil
local function sweep()
    if sweep_cache ~= nil then return unpack(sweep_cache) end
    local p = assert(io.popen('lua5.1 tests/_stayfamily_singlearm_sweep.lua 2>/dev/null'))
    local s = p:read('*a')
    p:close()
    assert(s:find('\nDONE', 1, true) or s:find('^DONE'),
        'tests/_stayfamily_singlearm_sweep.lua did not reach its DONE line -- '
        .. 'the subprocess failed, and a truncated manifest must never be read '
        .. 'as a small measurement')
    local G, C = {}, {}
    for line in s:gmatch('[^\n]+') do
        local k, v = line:match('^G (%S+) (%S+)$')
        if k then G[k] = tonumber(v) or v end
        local ck, cv = line:match('^C (%S+) (%-?%d+)$')
        if ck then C[ck] = tonumber(cv) end
    end
    sweep_cache = { G, C }
    return G, C
end

-- ==========================================================================
-- 1. The set is the set -- a SEVENTH id must not land unmeasured
-- ==========================================================================

tests['[source] the helper carries exactly the six ids this file measures'] = function()
    local G = sweep()
    assert(G.STAY == 1, 'J.ShouldStayAndRegen is gone from ' .. JMZ)
    -- COUNTED, not flagged. A presence flag cannot go red when a seventh id
    -- lands, and a seventh id landing unmeasured is exactly the failure GH #576
    -- is about.
    assert(G.STAY_SOAK_CALLS == 6, 'J.ShouldStayAndRegen now makes '
        .. tostring(G.STAY_SOAK_CALLS) .. ' J.IsSoakCandidate call(s), not 6. '
        .. 'If an id landed, add it to IDS here and measure its single-arm '
        .. 'column before it goes near a member string -- that is the whole '
        .. 'obligation GH #576 created.')
    assert(G.IDS_IN_SOURCE == G.IDS_DECLARED and G.IDS_DECLARED == #IDS,
        'the declared id list and the source disagree: ' .. tostring(G.IDS_IN_SOURCE)
        .. ' of ' .. tostring(G.IDS_DECLARED) .. ' found')
end

tests['[source] the identity answer the census row rests on'] = function()
    local G = sweep()
    -- Five of six gates are the first thing evaluated in their condition (four
    -- reached only through `not bHasRegen and`, which short-circuits before the
    -- gate too). The sixth is 'stayattr', whose gate sits inside
    -- `not IsSoakCandidate(...) or ...` -- un-armed that disjunct is TRUE and
    -- the shipped veto stands, which is the identity answer in its own shape.
    assert(G.GATED_CONDS == 6, 'gated conditions moved to '
        .. tostring(G.GATED_CONDS))
    assert(G.GATE_FIRST_CONJUNCT == 5, 'gate-first conditions moved to '
        .. tostring(G.GATE_FIRST_CONJUNCT) .. ' of 6; if a gate moved behind an '
        .. 'engine call, the un-armed evaluation is no longer byte-identical '
        .. 'and the census row that calls this (P) is wrong')
end

-- ==========================================================================
-- 2. GH #576's actual question, driven
-- ==========================================================================

tests['[corpus] every id is single-arm readable in a real game'] = function()
    local _, C = sweep()
    -- ⛔ THE DENOMINATOR GOES THROUGH corpus_scale (GH #106 / #127); see the
    -- note in tests/test_waitclar_mana_trip.lua. A frame count is invisible to
    -- the fixture-count detector, so this one was repaired by hand alongside it.
    cs.ratchet(C.live, 1012, 'live hero frames')
    assert(C.raises == 0, tostring(C.raises) .. ' frame(s) raised inside the '
        .. 'driven function; a raise is not a measurement')
    assert(C.gold_nonzero == 0, 'gold is suddenly readable off a .dem ('
        .. tostring(C.gold_nonzero) .. ' non-zero frame(s)); GH #495 has moved '
        .. 'and every bound in this file has to be re-derived')

    -- The claim, per id: SOMEWHERE in the two columns each id moves the answer.
    -- An id that reads zero in BOTH is one an isolation wave cannot buy.
    for _, sId in ipairs(IDS) do
        local n = C[sId .. '_up'] + C[sId .. '_down']
            + C[sId .. '_up_g200'] + C[sId .. '_down_g200']
        assert(n > 0, "'" .. sId .. "' moves J.ShouldStayAndRegen on ZERO of "
            .. 'the 1012 live frames in BOTH the gold-0 and the gold-200 '
            .. 'column. A single-arm wave for it buys a correct zero that will '
            .. 'be filed as "tested, no effect" -- that is GH #576, live.')
    end
end

tests['[corpus] each id moves the answer only in its legal direction'] = function()
    local _, C = sweep()
    for _, sId in ipairs(WIDENERS) do
        -- Each widener sits behind `not bHasRegen` and can only remove a veto.
        assert(C[sId .. '_down'] == 0 and C[sId .. '_down_g200'] == 0,
            "'" .. sId .. "' turned a TRUE into a FALSE; a widening of "
            .. '`bHasRegen` cannot do that')
    end
    -- 'stayattr' relaxes the chase veto: also FALSE -> TRUE only.
    assert(C.stayattr_down == 0 and C.stayattr_down_g200 == 0,
        "'stayattr' turned a TRUE into a FALSE")
    -- 'staytower' APPENDS a veto: TRUE -> FALSE only. The mirror image, and the
    -- reason a single `flips` column would have let the two halves cancel.
    assert(C.staytower_up == 0 and C.staytower_up_g200 == 0,
        "'staytower' turned a FALSE into a TRUE; appending a veto cannot do that")
    -- The tally that must read 0 above is proved to be a counter that counts:
    -- the same function called with its legs exchanged reports the whole domain.
    assert(C.swap_check_up == C.staysrc_up and C.swap_check_down == 0,
        'the swapped tally reads ' .. tostring(C.swap_check_up) .. '/'
        .. tostring(C.swap_check_down) .. ' -- the zeroes above are no longer '
        .. 'proved to come from a counter that can count')
end

tests['[corpus] the zeroes are the gold clause, not a sibling'] = function()
    local _, C = sweep()
    -- The distortion, as the two shipped TRUE sets. At gold 0 the function
    -- accepts 13 frames; at gold >= 90 it accepts 125 -- because its last line
    -- is `if not bHasRegen and bot:GetGold() < 90 then return false end`.
    assert(C.ship_true == 13 and C.ship_true_g200 == 125,
        'the shipped TRUE sets moved to ' .. tostring(C.ship_true) .. '/'
        .. tostring(C.ship_true_g200))

    -- The four supply widenings exist ONLY to remove that gold veto, so once
    -- gold clears 90 they have nothing left to widen. This is the quantified
    -- form of the honest bound all four already publish ("the measured flip set
    -- is the gold-poor SUPERSET"): at gold 200 the superset is empty.
    for _, sId in ipairs(WIDENERS) do
        assert(C[sId .. '_up'] > 0, "'" .. sId .. "' flips nothing even at gold 0")
        assert(C[sId .. '_up_g200'] == 0, "'" .. sId .. "' flips "
            .. tostring(C[sId .. '_up_g200']) .. ' frame(s) at gold 200; its '
            .. 'whole domain was supposed to be inside the gold veto it removes')
    end

    -- 'staytower' is the mirror: it can only act on frames already accepted, so
    -- its gold-0 zero is structural. Driven past the gold gate it flips 12.
    assert(C.staytower_up == 0 and C.staytower_down == 0,
        "'staytower' now moves frames at gold 0")
    assert(C.staytower_down_g200 == 12, "'staytower' flips "
        .. tostring(C.staytower_down_g200) .. ' at gold 200, not 12 -- the '
        .. 'explanation for its gold-0 zero has changed')
end

tests['[corpus] no id in the set hides another'] = function()
    local _, C = sweep()
    -- The only shape that can hide a lever is two independently sufficient
    -- VETOES. This set has exactly two ids that touch a veto, and their domains
    -- are measured disjoint rather than argued.
    assert(C.pair_attr_tower_both == 0,
        tostring(C.pair_attr_tower_both) .. " frame(s) where arming "
        .. "'stayattr' and 'staytower' together differs from arming either "
        .. 'alone; the two vetoes now interact and neither can be read singly')

    -- And the subtractive id subtracts exactly as much alone as it does inside
    -- the full set: its single-arm reading is the same lever the member string
    -- would be measuring.
    assert(C.tower_subtracts_from_all_g200 == C.staytower_down_g200,
        "'staytower' removes " .. tostring(C.tower_subtracts_from_all_g200)
        .. ' frame(s) from the all-armed set but '
        .. tostring(C.staytower_down_g200) .. ' armed alone; a single-arm wave '
        .. 'would be measuring a different lever from the one a member string '
        .. 'ships')

    -- Arithmetic that ties the three all-armed columns together, so a drift in
    -- any one of them cannot pass as a drift in the corpus.
    assert(C.all_minus_tower_true_g200 - C.all_true_g200 == C.staytower_down_g200,
        'the all-armed columns no longer account for the tower veto: '
        .. tostring(C.all_minus_tower_true_g200) .. ' - '
        .. tostring(C.all_true_g200) .. ' ~= ' .. tostring(C.staytower_down_g200))
end

return tests

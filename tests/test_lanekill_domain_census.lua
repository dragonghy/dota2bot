-- [ratchet] [l1trade / l5combo 2026-09-07, 总监] The applicable-frame pricing
-- behind the two 退集 rulings of test_set.md §FW -- and, larger than either id,
-- ONE CLASS OF LEVER THIS REPOSITORY'S CHEAP INSTRUMENT CANNOT WITNESS AT ANY
-- PRICE.
--
-- ⭐ THE FINDING.
-- A FUNNEL THAT DIES ON ITS LAST CONJUNCT LOOKS EXACTLY THE SAME WHETHER THE
-- CLAUSE IS FALSE OR THE INSTRUMENT IS BLIND TO IT. Both lane-kill helpers walk
-- their whole conjunct chain over this corpus and reach the final clause with a
-- healthy population -- 155 (bot, target) pairs for `l1trade`, 11 for `l5combo`
-- -- and then read 0 lethal, 0 fires. Written up as "the domain is empty" that
-- is a clean, quotable, WRONG verdict.
--
-- The last conjunct of both helpers is an OUTGOING burst estimate:
--   J.GetTotalEstimatedDamageToTarget(myAlliesNearIt, enemyTarget)
--       >= target HP + 4s regen
-- and `tests/mock/replay_fixture.lua:714` gives every hero on a frame the
-- damage it actually dealt TO THE SUBJECT in the following window. So
-- ally -> enemy is identically 0 on every frame of every fixture, by
-- construction of the corpus format. `tests/mock/bot_api.lua:134` states the
-- same fact from the other side and names two other helpers it silently
-- disarms; this file adds the lane-kill pair to that list and gives the
-- property a counter instead of a paragraph.
--
-- ⭐⭐ WHY THE ZERO IS NOT SELF-EVIDENTLY SUSPICIOUS, i.e. why this needed
-- measuring rather than reading. The SAME engine call, `GetEstimatedDamageToTarget`,
-- returns REAL ground truth on the SAME frames in the other direction: the two
-- helpers' self-risk clauses ask enemy -> me, and that reads non-zero on 18
-- (l1trade) and 9 (l5combo) frames, and actually vetoes 7 of 138 l1trade frames.
-- An instrument that is live, on the same frames, through the same call, in one
-- direction and dead in the other is not something a reader spots by looking at
-- a `0`. Hence `*_est_blind` / `*_est_live` / `*_incoming_live`: the manifest
-- reports the INSTRUMENT'S STATE next to the clause's RESULT, so the two can
-- never be collapsed by a later reader (the GH #171 shape -- "the bucket was
-- never reached" and "the bucket measured zero" must not print the same).
--
-- ⭐⭐⭐ WHAT THAT BOUGHT, AND WHAT IT DID NOT.
--   IT DID buy the reason 44 days of `verify=0` was never going to end by
--   itself: for these two ids condition (a) is not merely unbought, it is
--   UNBUYABLE FROM THE FIXTURE PATH, and every future session reaching for the
--   cheap tool would have re-derived the same 0 and (if it did not check)
--   written the same wrong verdict.
--   IT DID NOT buy a verdict on the levers. In a real game the engine's own
--   estimator is live, so both helpers can fire; nothing here says they do, or
--   that firing would be good. Buying (a) needs a behavioural detector on wave
--   replays -- registered as an owed execution, not left in prose
--   (`iterations/owed_executions.json:lanekill_condition_a_detector`).
--
-- ⇒ The rulings this file supports are 退集 (out of the armed set, gate and code
-- kept byte-for-byte), NOT reject. See test_set.md §FW.
--
-- WHAT MAKES THIS FILE GO RED, on purpose:
--   * the harness grows an outgoing-damage model  -> `*_est_live` non-zero;
--     the census starts answering the question it looks like it answers, and
--     the "structurally unbuyable" half of §FW is stale.
--   * a shipped gate leaks                        -> `*_shipped_fires` non-zero.
--   * either funnel's shape moves                 -> the ratchets below.

package.path = 'tests/?.lua;' .. package.path
local cs = require('corpus_scale')

local SWEEP = 'lua5.1 tests/_lanekill_domain_sweep.lua'
local JMZ = 'bots/FunLib/jmz_func.lua'

local tests = {}

local function read_file(path)
    local f = assert(io.open(path, 'r'), path .. ' is not readable')
    local s = f:read('*a')
    f:close()
    return s
end

local M = (function()
    local p = assert(io.popen(SWEEP, 'r'))
    local raw = p:read('*a')
    p:close()
    local m = { c = {}, g = {}, done = false }
    for line in raw:gmatch('[^\n]+') do
        local ck, cv = line:match('^C (%S+) (%-?%d+)$')
        if ck ~= nil then m.c[ck] = tonumber(cv) end
        local gk, gv = line:match('^G (%S+) (%S+)$')
        if gk ~= nil then m.g[gk] = gv end
        if line == 'DONE' then m.done = true end
    end
    return m
end)()

local function C(key)
    local n = M.c[key]
    assert(n ~= nil, 'the sweep did not emit counter ' .. key
        .. ' -- an absent counter is not a zero')
    return n
end

tests['[sweep] the subprocess ran to completion'] = function()
    assert(M.done, 'tests/_lanekill_domain_sweep.lua did not print DONE -- every '
        .. 'count below would be a partial sweep read as a finding')
    cs.corpus(C('fixtures'), 'fixture corpus')
    cs.ratchet(C('live'), 1021, 'live hero frames')
    -- Both helpers sit behind IsInLaningPhase, so this is their shared ceiling.
    cs.ratchet(C('lane'), 842, 'laning-phase live hero frames')
    cs.ratchet(C('lane_core'), 712, 'laning-phase core frames (l1trade arm)')
    cs.ratchet(C('lane_sup'), 130, 'laning-phase support frames (l5combo arm)')
    assert(C('lane_core') + C('lane_sup') == C('lane'),
        'the core/support split (' .. C('lane_core') .. '+' .. C('lane_sup')
        .. ') no longer partitions the ' .. C('lane') .. ' laning frames -- '
        .. 'the two arms are meant to be disjoint and exhaustive')
    assert(C('l1_raised') == 0 and C('l5_raised') == 0,
        'the helpers raised (' .. C('l1_raised') .. '/' .. C('l5_raised')
        .. ') -- a raise is not a measured "did not fire" (GH #492), and those '
        .. 'frames would be silently leaving the denominator')
end

-- ------------------------------------------- the funnel, conjunct by conjunct --

tests['[domain] neither funnel is empty before its last clause'] = function()
    -- This is the half that makes the finding non-trivial: if the population
    -- died early there would be nothing to attribute the zero to. It does not.
    cs.ratchet(C('l1_backed'), 295, 'l1trade: frames with a healthy ally within '
        .. tostring(M.g.L1_ALLY_R))
    cs.ratchet(C('l1_enemies'), 138, 'l1trade: frames with an enemy in range')
    cs.ratchet(C('l1_selfrisk_ok'), 131, 'l1trade: frames past the self-risk bar')
    cs.ratchet(C('l1_pairs'), 185, 'l1trade: candidate (bot, target) pairs')
    cs.ratchet(C('l1_shallow'), 155, 'l1trade: pairs that also pass the depth leash')
    cs.ratchet(C('l5_enemies'), 33, 'l5combo: frames with an enemy in range')
    cs.ratchet(C('l5_selfrisk_ok'), 30, 'l5combo: frames past the self-risk bar')
    cs.ratchet(C('l5_notcrowded'), 22, 'l5combo: frames past the second-enemy veto')
    cs.ratchet(C('l5_shallow'), 16, 'l5combo: pairs that also pass the depth gate')
    cs.ratchet(C('l5_coreonit'), 11, 'l5combo: pairs with an allied core on the target')
    -- The self-risk clause really does bite -- so "every clause is a pass-through
    -- and the last one happens to be blind" is excluded by measurement.
    assert(C('l1_selfrisk_ok') < C('l1_enemies'), 'the l1trade self-risk clause '
        .. 'now vetoes nothing (' .. C('l1_selfrisk_ok') .. ' of ' .. C('l1_enemies')
        .. ') -- it was the evidence that the incoming direction is live')
end

tests['[instrument] the last clause reads 0 because it is BLIND, not because it is false'] = function()
    -- The whole point of the file. Every lethality evaluation on the corpus was
    -- made with a dead estimator...
    cs.ratchet(C('l1_est_blind'), 155, 'l1trade: lethality evaluations made blind')
    cs.ratchet(C('l5_est_blind'), 11, 'l5combo: lethality evaluations made blind')
    assert(C('l1_est_blind') == C('l1_shallow'),
        'l1trade: ' .. C('l1_est_blind') .. ' blind evaluations for '
        .. C('l1_shallow') .. ' evaluated pairs -- the two must be equal while '
        .. 'the corpus is blind; a gap means some pairs saw a real number and '
        .. 'the "identically 0" claim is stale')
    assert(C('l5_est_blind') == C('l5_coreonit'),
        'l5combo: ' .. C('l5_est_blind') .. ' blind evaluations for '
        .. C('l5_coreonit') .. ' evaluated pairs -- same re-read')
    assert(C('l1_est_live') == 0 and C('l5_est_live') == 0,
        'THE CORPUS CAN NOW SEE OUTGOING BURST (' .. C('l1_est_live') .. '/'
        .. C('l5_est_live') .. ' live evaluations). This is good news and it '
        .. 'INVALIDATES the "condition (a) is structurally unbuyable here" half '
        .. 'of test_set.md §FW: re-run the census, and buy (a) from fixtures if '
        .. 'it now fires. Do not re-baseline this assertion away.')
    -- ...while the SAME call, on the SAME frames, in the OTHER direction, is live.
    cs.ratchet(C('l1_incoming_live'), 18, 'l1trade: frames where enemy->me read non-zero')
    cs.ratchet(C('l5_incoming_live'), 9, 'l5combo: frames where enemy->me read non-zero')
    assert(C('l1_incoming_live') > 0 and C('l5_incoming_live') > 0,
        'the incoming direction now reads zero everywhere too -- then the '
        .. 'estimator is uniformly dead rather than DIRECTIONAL, and the '
        .. 'reasoning in §FW (which rests on the asymmetry) must be re-derived')
    -- And therefore the two headline zeros are instrument state, not readings.
    assert(C('l1_lethal') == 0 and C('l1_fires') == 0, 'l1trade now fires ('
        .. C('l1_fires') .. ') -- only possible if the estimator woke up; re-read §FW')
    assert(C('l5_lethal') == 0 and C('l5_fires') == 0, 'l5combo now fires ('
        .. C('l5_fires') .. ') -- same re-read')
end

tests['[control] the shipped tree is silent on every frame'] = function()
    -- 退集 removes the ids from the armed string; it does not touch the gates.
    -- This is the assertion that the un-armed arm is still a no-op, i.e. that
    -- the ruling really did leave shipped behaviour alone.
    assert(C('l1_shipped_fires') == 0, 'J.ShouldInitiateLaneKill fired on '
        .. C('l1_shipped_fires') .. ' frames with NO id armed -- the gate leaks '
        .. 'and this is a live-behaviour change, not a soak candidate')
    assert(C('l5_shipped_fires') == 0, 'J.ShouldSupportComboKill fired on '
        .. C('l5_shipped_fires') .. ' frames with NO id armed -- same')
end

-- ------------------------------------------------------ source assertions ----

tests['[source] both gates are still single-id and turbo-only'] = function()
    -- The pullcad trap: a gate written as a conjunction of two ids freezes the
    -- day either one is promoted. Neither of these is, and 退集 must not change
    -- that. Also pins that the ids the ruling names are the ids in the tree.
    local src = read_file(JMZ)
    for _, id in ipairs({ 'l1trade', 'l5combo' }) do
        local n = 0
        for _ in src:gmatch("IsSoakCandidate%(%s*'" .. id .. "'%s*%)") do n = n + 1 end
        assert(n == 1, id .. ' now has ' .. n .. ' gate site(s) in jmz_func (was 1) '
            .. '-- §FW priced a single-site gate; re-derive before promoting')
    end
    local function gate_line(fn)
        local at = assert(src:find('function J.' .. fn .. '( bot )', 1, true),
            'J.' .. fn .. ' is gone from jmz_func -- §FW named it')
        return src:sub(at, at + 400)
    end
    for fn, id in pairs({ ShouldInitiateLaneKill = 'l1trade',
                          ShouldSupportComboKill = 'l5combo' }) do
        local head = gate_line(fn)
        assert(head:find('J.IsModeTurbo()', 1, true), fn
            .. ' no longer opens with the turbo guard -- a soak candidate that '
            .. 'can fire outside turbo is not what §FW ruled on')
        assert(head:find("IsSoakCandidate( '" .. id .. "' )", 1, true), fn
            .. ' no longer reads its own id ' .. id .. ' near the top')
        -- THE PULLCAD TRAP, asserted rather than assumed. Counting this id's
        -- own sites cannot see a SECOND id joining the gate: `A and B` still
        -- contains exactly one `A`. So count every id read in the guard prologue
        -- and require it to be this one, alone.
        -- (This assertion exists because its absence was measured: mutant M4 of
        -- tools/agent/mutstand_lanekill_domain.sh planted exactly that
        -- conjunction and SURVIVED the first version of this file.)
        local ids = {}
        for other in head:gmatch("IsSoakCandidate%(%s*'([%w_]+)'%s*%)") do
            ids[#ids + 1] = other
        end
        assert(#ids == 1 and ids[1] == id, fn .. "'s guard prologue now reads "
            .. #ids .. " soak id(s) (" .. table.concat(ids, ',') .. ') instead of '
            .. 'only ' .. id .. ' -- a gate written as a conjunction of two ids '
            .. 'freezes FALSE the day either one is promoted, and nothing else '
            .. 'in the lab raises a hand for that (the pullcad shape)')
    end
end

tests['[source] the census parsed the live thresholds, not remembered ones'] = function()
    -- The M13 lesson: every number the sweep funnels on is parsed out of the
    -- shipped source, so a threshold edit moves the census instead of silently
    -- invalidating it. This asserts the parse actually resolved.
    for _, k in ipairs({ 'L1_ALLY_R', 'L1_ENEMY_R', 'L1_ALLY_HP', 'L1_SELFRISK',
        'L1_DEPTH', 'L1_TGT_R', 'L5_ENEMY_R', 'L5_SELFRISK', 'L5_CLOSE_R',
        'L5_CLOSE_N', 'L5_DEPTH', 'L5_CORE_R', 'L5_CORE_HP', 'LANE_FLOOR' }) do
        local v = M.g[k]
        assert(v ~= nil and v ~= 'nil', 'the sweep could not parse ' .. k
            .. ' out of jmz_func -- it then falls back to a HARDCODED default '
            .. 'and the census silently stops tracking the tree')
    end
    -- The two that carry the reasoning: the laning floor (both helpers' shared
    -- ceiling) and the self-risk asymmetry the header argues from.
    assert(M.g.LANE_FLOOR == '8', 'the turbo laning floor is now '
        .. tostring(M.g.LANE_FLOOR) .. ' minutes (was 8) -- the 842-frame '
        .. 'laning population and every count under it moved with it')
    assert(tonumber(M.g.L5_SELFRISK) < tonumber(M.g.L1_SELFRISK),
        'the support self-risk bar (' .. tostring(M.g.L5_SELFRISK) .. ') is no '
        .. 'longer stricter than the core one (' .. tostring(M.g.L1_SELFRISK)
        .. ') -- that asymmetry is the documented design of the pair')
end

return tests

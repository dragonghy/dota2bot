-- [strategy 2026-09-08, owner priority P2 / P4.4(ii)] THE SECOND SHADOW CENSUS
-- OF X.ConsiderItemDesire["item_tpscroll"] -- and it comes back with a DIFFERENT
-- SIGN from the first one, which is the whole reason it had to be measured.
--
-- The 14:31Z round found that '撤退:1' returns before '回复状态' and swallows one
-- of 'tpdeep''s two domain frames, and left behind a number rather than a
-- conclusion: `both_triggers 6`.  Six frames with two branch triggers open,
-- against ONE frame the shadow actually cost, says the shape is not a property
-- of that one lever.  So the remaining cells of the same 4x4 table are measured
-- here, on the same corpus walk (tests/_tpquiet_sweep.lua, extended -- NOT a
-- third full-corpus sweep):
--
--     t3_trigger                    9   -- '撤退:3', where 'stayfield' hangs
--     t3_shadowed_by_t1             5   -- ...claimed by '撤退:1' first
--     t3_shadowed_by_t2             3   -- ...or by '撤退:2'
--     t3_shadowed_by_either         6   -- TWO THIRDS of the branch
--     stayfield_true_in_t3          2   -- what a domain reading would credit
--     stayfield_true_in_t3_shadowed 1   -- ...half of it unreachable
--     r4_shadowed_by_t2             4   -- '撤退:2' in front of '回复状态'
--     r4_shadowed_by_t3             6   -- '撤退:3' in front of it too
--
-- ⭐ THE HEADLINE IS THE ONE FOR THE 'stayfield' ADMISSION DECISION, and it is
-- P4.4(ii) rather than a new lever.  'stayfield' sits in
-- `state.json:new_gated_awaiting_ab` and the standing plan is to arm it with
-- 'stayfield2' in one wave.  Its ONLY call site is '撤退:3'.  On this corpus that
-- branch is reachable on at most 3 of its 9 trigger frames; the helper answers
-- TRUE inside the trigger on 2, and 1 of those 2 is shadowed.  ⇒ the wave would
-- read this id as a near-no-op, and "tested, no effect" is exactly what a
-- no-op looks like from the verdict side.  Same shape as GH #622 (a first wave
-- that buys nothing), one branch upstream.
--
-- ⭐⭐ AND THE SHADOW ITSELF IS BENIGN HERE, WHICH IS THE OPPOSITE OF THE FIRST
-- CENSUS -- so "a shadow was found" is not a verdict, the SIGN has to be
-- measured per cell.  Every '撤退:3' frame claimed by '撤退:1' is below 0.19 (the
-- claiming branch's own cap), and on that band '撤退:1' carries a STRICTLY
-- STRONGER guard set than '撤退:3' does: the PROMOTED J.ShouldStayAndRegen over
-- [0.18, 0.19) plus the gated 'tpquiet' over [0.10, 0.18), against 'stayfield'
-- whose floor is 0.18.  The bot is guarded at least as well by losing the race.
-- Asserted from the printed rows, not from the count.
--
-- ⛔⛔ THREE CANDIDATE LEVERS WERE PRICED AND ALL THREE HAVE AN EMPTY DOMAIN ON
-- THIS CORPUS.  This file pins each zero together with the CLAUSE that produced
-- it, because "the domain is small" and "the measurement never ran" must never
-- be the same sentence (the GH #171 shape):
--
--   (1) A veto on '撤退:2''s EMPTY-RING leg.  The family's written reason for
--       exempting that branch is that it "requires enemies AND recent hero
--       damage".  The second half is a conjunct; the first half IS NOT -- the
--       cap is `0.15 + 0.24 * nEnemyCount` and its BASE is nonzero, so at
--       nEnemyCount == 0 the branch still fires on `botHP < 0.15` and the damage
--       clause alone.  The prose is arithmetically wrong.  Measured:
--       `t2_ring_empty 2`, and `t2_empty_below_band 2` -- BOTH of those frames
--       are under 0.10, where this family declines to speak by design.  So the
--       exemption survives on numbers even though its stated reason does not,
--       and the prose is corrected in jmz_func rather than acted on.
--       Second, independent reason the obvious form is a no-op: the branch
--       REQUIRES `WasRecentlyDamagedByAnyHero(6.0)` and 'tpquiet''s helper
--       REFUSES on the same call with the same window ⇒ `t2_empty_damaged_only 0`
--       is a closed form, not a sample.
--   (2) A deep-band veto on '撤退:3', mirroring what 'tpdeep' did for '回复状态'.
--       The hole is real and is the same subtraction: 'stayfield' routes through
--       J.IsFieldRegenSituation, whose band is [0.18, 0.55], while the branch
--       fires down to zero HP ⇒ `t3_below_stayfloor 5` of 9 frames have NO veto
--       of any kind, armed or not.  But `t3_deep_in_band 1` and `t3_deep_src 0`:
--       the single in-band frame carries nothing to drink, so the domain is
--       emptied by the SOURCE clause and no fixture could pin the lever.  This
--       is a CORPUS REQUEST, not a design objection -- filed as such.
--   (3) A second address for 'stayfield''s opinion on '撤退:1'.  Closed form:
--       that branch caps at `botHP < 0.19` and 'stayfield''s band starts at
--       0.18, so the overlap is [0.18, 0.19) -- one percentage point already
--       held by the PROMOTED J.ShouldStayAndRegen.  Nothing to add.
--
-- ⛔ WHAT THIS FILE DOES NOT DO: it does not touch the shared 0.18 floor in
-- J.IsFieldRegenSituation (that edit moves 'stayfield', 'stayfield2' and
-- 'fieldbuy' on one push -- the lanefix bundle mistake), it does not arm or
-- propose admission for anything (owner P4.2 is a freeze), and it does not
-- re-baseline any sibling's published domain reading.

package.path = 'tests/?.lua;' .. package.path
local cs = require('corpus_scale')

local AIUG = 'bots/ability_item_usage_generic.lua'
local JMZ = 'bots/FunLib/jmz_func.lua'

local tests = {}
local sweep

local function read(path)
    local f = assert(io.open(path, 'r'), path .. ' is not readable')
    local s = f:read('*a')
    f:close()
    return s
end

--- Source-order facts, derived HERE and only then required to agree with the
--- manifest.
---
--- ⛔ THE SEPARATION IS A STAND FINDING, INHERITED.  The sibling file's M10
--- proved that an assertion reading a number the checked artefact produced
--- checks nothing: replacing the sweep's order computation with the literal `1`
--- left every counter byte-identical (order is not a count) and the assertion
--- read the mutant's own constant.  Each branch's return is located by starting
--- the search AT that branch's own cast motive -- the M13 finding, because the
--- SAME `return ... tpLoc ...` line ends all three retreat branches, so a
--- whole-file search is satisfied by a sibling's return.
local RET_TP = 'return BOT_ACTION_DESIRE_HIGH, tpLoc, sCastType, sCastMotive'
local function order_facts()
    local src = read(AIUG):gsub('%-%-[^\n]*', '')
    local function at(s) return src:find(s, 1, true) end
    local function ret_of(sMotive, sNextMotive)
        local m = at("sCastMotive = '" .. sMotive .. "'")
        if m == nil then return nil end
        local r = src:find(RET_TP, m, true)
        -- Past the NEXT branch's motive = this branch has no return of its own.
        local nxt = sNextMotive and at("sCastMotive = '" .. sNextMotive .. "'")
        if r and nxt and r > nxt then return nil end
        return r
    end
    return {
        wrap = at('if nMode == BOT_MODE_RETREAT'),
        t1 = at('if botHP < 0.19'),
        t2 = at('if botHP < ( 0.15 + 0.24 * nEnemyCount )'),
        t3 = at('if ( botHP < 0.34 or botHP + botMP < 0.43 )'),
        r4 = at('if ( botHP + botMP < 0.3 or botHP < 0.2 )'),
        ret1 = ret_of('撤退:1', '撤退:2'),
        ret2 = ret_of('撤退:2', '撤退:3'),
        ret3 = ret_of('撤退:3', '回复状态'),
    }
end

-- ==========================================================================
-- 1. The structure the whole census rests on
-- ==========================================================================

tests['[structure] the four home-TP branches are in source order and each returns'] = function()
    local o = order_facts()
    for _, k in ipairs({ 'wrap', 't1', 't2', 't3', 'r4', 'ret1', 'ret2', 'ret3' }) do
        assert(o[k] ~= nil, 'the anchor for `' .. k .. '` is gone from the '
            .. 'comment-stripped source of ' .. AIUG .. ' -- the census cannot '
            .. 'be read against a function it can no longer locate')
    end
    assert(o.t1 < o.t2 and o.t2 < o.t3 and o.t3 < o.r4,
        'the four home-TP triggers are no longer in the order 撤退:1 / 撤退:2 / '
        .. '撤退:3 / 回复状态; every shadow direction in this file is stated '
        .. 'against that order')
    assert(o.ret1 < o.t2 and o.ret2 < o.t3 and o.ret3 < o.r4,
        'a branch stopped RETURNING before the next branch\'s trigger -- '
        .. 'without the returns the branches do not shadow each other at all')
    -- ⛔ Three DISTINCT positions. A single shared return would satisfy every
    -- ordering assertion above at once, which is exactly how M13 got in.
    assert(o.ret1 < o.ret2 and o.ret2 < o.ret3,
        'two retreat branches resolved to the SAME return position; a shared '
        .. 'anchor makes every ordering claim above vacuous')
end

tests['[structure] the three retreat branches share ONE wrapper, 回复状态 does not'] = function()
    -- This asymmetry is what decides how far each cell can be trusted: a
    -- t3-by-t1/t2 hit is inside one `nMode == BOT_MODE_RETREAT`, so the mode
    -- condition is common to both sides and cancels out of the comparison; an
    -- r4-by-t2/t3 hit is not, and is a CEILING only.
    local o = order_facts()
    assert(o.wrap < o.t1,
        'the retreat wrapper no longer precedes 撤退:1')
    assert(o.wrap < o.t2 and o.wrap < o.t3,
        'a retreat branch escaped the wrapper')
    assert(o.ret3 < o.r4,
        '回复状态 is no longer downstream of the whole retreat block')
end

tests['[structure] the branch vetoes are where the census says they are'] = function()
    local src = read(AIUG):gsub('%-%-[^\n]*', '')
    local function branch(sHead, sMotive)
        local a = src:find(sHead, 1, true)
        local b = a and src:find("sCastMotive = '" .. sMotive .. "'", a, true)
        return (a and b) and src:sub(a, b) or nil
    end
    local b2 = branch('if botHP < ( 0.15 + 0.24 * nEnemyCount )', '撤退:2')
    local b3 = branch('if ( botHP < 0.34 or botHP + botMP < 0.43 )', '撤退:3')
    assert(b2 and b3, 'a retreat branch body could not be sliced')
    assert(b3:find('J.ShouldRegenNotTpHome', 1, true) ~= nil,
        '\'stayfield\' is no longer wired into 撤退:3 -- this file\'s whole '
        .. 'reachability reading is about THAT call site')
    for _, sVeto in ipairs({ 'J.ShouldStayAndRegen', 'J.ShouldRegenNotTpHome',
        'J.ShouldSipNotTpQuietHome', 'J.ShouldSipNotTpRecover',
        'J.ShouldDeepSipNotTpRecover' }) do
        assert(b2:find(sVeto, 1, true) == nil,
            '撤退:2 has acquired the veto ' .. sVeto .. '. That branch is the '
            .. 'family\'s standing exemption, and this census is the record of '
            .. 'WHY it survives (its empty-ring leg is 2 frames, both below '
            .. '0.10) -- adding a veto there has to come through this line')
    end
end

tests['[structure] the floor that makes 撤退:3 half-unguarded is 0.18, parsed'] = function()
    -- 'stayfield' is J.ShouldRegenNotGoHome behind a gate, and that routes
    -- through J.IsFieldRegenSituation whose FIRST clause is the band. The
    -- branch's own cap is `botHP < 0.34`. The subtraction between those two is
    -- the hole cell (2) names, so both numbers come off the source.
    local jmz = read(JMZ):gsub('%-%-[^\n]*', '')
    local fn = jmz:match('function J%.IsFieldRegenSituation.-\nend')
    assert(fn ~= nil, 'J.IsFieldRegenSituation could not be located')
    local lo, hi = fn:match('nHP < ([%d%.]+) or nHP > ([%d%.]+)')
    assert(tonumber(lo) == 0.18 and tonumber(hi) == 0.55,
        'the field-regen band moved to [' .. tostring(lo) .. ', '
        .. tostring(hi) .. ']; every "below the only veto\'s floor" count in '
        .. 'this file is stated against [0.18, 0.55]')
    local wrap = jmz:match('function J%.ShouldRegenNotTpHome.-\nend')
    assert(wrap and wrap:find('J.ShouldRegenNotGoHome', 1, true) ~= nil,
        '\'stayfield\' no longer routes through J.ShouldRegenNotGoHome, so the '
        .. 'band above is no longer its band')
end

-- ==========================================================================
-- 2. The corpus census (subprocess sweep, memoised)
-- ==========================================================================

local sweep_cache = nil
function sweep()
    if sweep_cache ~= nil then return unpack(sweep_cache) end
    local p = assert(io.popen('lua5.1 tests/_tpquiet_sweep.lua 2>/dev/null'))
    local s = p:read('*a')
    p:close()
    assert(s:find('\nDONE', 1, true) or s:find('^DONE'),
        'tests/_tpquiet_sweep.lua did not reach its DONE line -- the subprocess '
        .. 'failed, and a truncated manifest must never be read as a small '
        .. 'measurement')
    local G, C, T = {}, {}, {}
    for line in s:gmatch('[^\n]+') do
        local k, v = line:match('^G (%S+) (%S+)$')
        if k then G[k] = tonumber(v) or v end
        local ck, cv = line:match('^C (%S+) (%-?%d+)$')
        if ck then C[ck] = tonumber(cv) end
        local tk, tf, th, thp, tl = line:match('^T (%S+) (%S+) (%S+) (%S+) (%S+)$')
        if tk then
            T[#T + 1] = { kind = tk, fixture = tf, hero = th,
                hp = tonumber(thp), level = tonumber(tl) }
        end
    end
    sweep_cache = { G, C, T }
    return G, C, T
end

--- Keeps a MISSING counter from reading as a satisfied assertion: the sweep
--- zero-initialises every bucket it measures, so `nil` means the KEY is gone,
--- not that the measurement came back empty (the GH #171 shape).
local function must(v, sKey)
    assert(v ~= nil, 'the counter `' .. sKey .. '` is missing from the manifest '
        .. 'entirely -- the sweep no longer measures it, and a nil must never '
        .. 'compare equal to a number')
    return v
end

local function rows(T, sKind)
    local out = {}
    for _, r in ipairs(T) do if r.kind == sKind then out[#out + 1] = r end end
    return out
end

tests['[corpus] the manifest agrees with the source order derived above'] = function()
    local G = sweep()
    local o = order_facts()
    local function want(sKey, bTruth)
        assert(G[sKey] == (bTruth and 1 or 0),
            'the sweep manifest says ' .. sKey .. ' = ' .. tostring(G[sKey])
            .. ' while this file derives ' .. tostring(bTruth) .. ' from the '
            .. 'source; a divergence means the sweep is measuring a different '
            .. 'tree than the one asserted here')
    end
    want('T1_RETURN_BEFORE_T2', o.ret1 < o.t2)
    want('T1_RETURN_BEFORE_T3', o.ret1 < o.t3)
    want('T2_RETURN_BEFORE_T3', o.ret2 < o.t3)
    want('T3_RETURN_BEFORE_R4', o.ret3 < o.r4)
    want('RETREAT_WRAP_BEFORE_T1', o.wrap < o.t1)
    want('RETREAT_RETURNS_DISTINCT', o.ret1 < o.ret2 and o.ret2 < o.ret3)
    assert(G.STAY_FLOOR == 0.18 and G.STAY_CEIL == 0.55,
        'the manifest read a different field-regen band than this file did')
    assert(G.T2_HP_BASE == 0.15 and G.T2_HP_PER_ENEMY == 0.24,
        '撤退:2\'s cap arithmetic moved; the "the base is nonzero, so it does '
        .. 'NOT require enemies" finding has to be re-derived')
    assert(G.T2_NVETOES == 0,
        '撤退:2 carries ' .. G.T2_NVETOES .. ' regen veto(es) now')
    assert(G.T3_STAYVETO == 1 and G.FILE_STAYVETO == 1,
        '\'stayfield\' no longer has exactly one call site, in 撤退:3')
end

tests['[corpus] CELL A: two thirds of stayfield\'s branch is claimed upstream'] = function()
    local _, C = sweep()
    cs.ratchet(C.live, 1021, 'live hero frames')
    assert(C.raises == 0, tostring(C.raises) .. ' frame(s) raised inside a '
        .. 'driven helper; a raise is not a measurement')
    assert(C.arm_leak == 0, 'the sweep armed more than one id')
    -- Anti-vacuum for the whole cell: the veto must be inert unarmed, and
    -- non-trivial armed, or the two columns below say nothing.
    assert(C.stayfield_shipped_true == 0,
        'J.ShouldRegenNotTpHome answers TRUE with no id armed on '
        .. C.stayfield_shipped_true .. ' frame(s) -- it is not gated')
    assert(C.stayfield_armed_true == 24,
        'the \'stayfield\' opinion covers ' .. C.stayfield_armed_true
        .. ' corpus frames, not 24; the "24 wide, 1 reachable" gap is the '
        .. 'evidence this file exists to hand the director')
    assert(C.t3_trigger == 9,
        '撤退:3\'s trigger bound moved to ' .. C.t3_trigger)
    assert(C.t3_shadowed_by_t1 == 5 and C.t3_shadowed_by_t2 == 3,
        'the per-branch shadow split moved (' .. C.t3_shadowed_by_t1 .. ' / '
        .. C.t3_shadowed_by_t2 .. '); the two are counted separately because '
        .. 'they have DIFFERENT consequences -- 撤退:1 is guarded, 撤退:2 is the '
        .. 'standing exemption')
    assert(C.t3_shadowed_by_either == 6,
        'the union moved to ' .. C.t3_shadowed_by_either)
    -- ⛔ The union is a union: not a sum (frames appear in both), never more
    -- than the trigger it is a subset of.
    assert(C.t3_shadowed_by_either <= C.t3_shadowed_by_t1 + C.t3_shadowed_by_t2,
        'the union exceeds the sum of its parts')
    assert(C.t3_shadowed_by_either >= C.t3_shadowed_by_t1
        and C.t3_shadowed_by_either <= C.t3_trigger,
        'the union is not bracketed by its largest part and the trigger set')
    -- ⭐ THE NUMBER FOR THE ADMISSION DECISION.
    assert(C.stayfield_true_in_t3 == 2 and C.stayfield_true_in_t3_shadowed == 1,
        'the reachable domain of \'stayfield\' at its only call site moved to '
        .. C.stayfield_true_in_t3 .. ' with '
        .. C.stayfield_true_in_t3_shadowed .. ' shadowed. This pair IS the '
        .. 'P4.4(ii) evidence: a wave arming this id reads at most '
        .. (C.stayfield_true_in_t3 - C.stayfield_true_in_t3_shadowed)
        .. ' corpus frame(s), and a no-op reads as "tested, no effect"')
end

tests['[corpus] CELL A: the shadow is BENIGN -- the winner guards at least as well'] = function()
    local _, _, T = sweep()
    local byT1 = rows(T, 't3_by_t1')
    assert(#byT1 == 5,
        'the printed 撤退:1 shadow rows (' .. #byT1 .. ') disagree with the '
        .. 'count; a census whose rows and counters disagree is not a census')
    -- ⭐ Every claimed frame is inside the CLAIMING branch's own cap, and on
    -- that band '撤退:1' carries the promoted veto over [0.18, 0.19) plus the
    -- gated 'tpquiet' over [0.10, 0.18) -- against 'stayfield' whose floor is
    -- 0.18. So losing the race cannot cost the bot a guard. This is what makes
    -- the finding a NEGATIVE result rather than a defect, and it is read off
    -- the rows because a count could never say it.
    for _, r in ipairs(byT1) do
        assert(r.hp < 0.19,
            'shadowed frame ' .. r.fixture .. '/' .. r.hero .. ' reads hp '
            .. string.format('%.3f', r.hp) .. ', outside 撤退:1\'s own '
            .. '`botHP < 0.19` cap -- then the bound that produced this row is '
            .. 'wrong, not merely loose')
    end
    -- ...and the same rows must NOT be quietly empty of the deep frames: four
    -- of the five sit below 0.12, i.e. they are claimed by 撤退:1's
    -- `or botHP < 0.12` disjunct with no recent damage at all.
    local nDeep = 0
    for _, r in ipairs(byT1) do if r.hp < 0.12 then nDeep = nDeep + 1 end end
    assert(nDeep == 4,
        nDeep .. ' of the shadowed frames sit below 0.12, not 4 -- that '
        .. 'disjunct is what lets 撤退:1 claim a QUIET deep frame, and the '
        .. 'reading changes if it moves')
end

tests['[corpus] CELL B: 撤退:2 and 撤退:3 stand in front of 回复状态 too'] = function()
    local _, C, T = sweep()
    assert(C.r4_trigger == 12, '回复状态\'s trigger bound moved to ' .. C.r4_trigger)
    assert(C.r4_shadowed_by_t2 == 4 and C.r4_shadowed_by_t3 == 6,
        'the 回复状态 shadow split moved (' .. C.r4_shadowed_by_t2 .. ' / '
        .. C.r4_shadowed_by_t3 .. ')')
    assert(C.r4_shadowed_by_any_retreat == 9,
        'the union moved to ' .. C.r4_shadowed_by_any_retreat)
    assert(#rows(T, 'r4_by_t2') == C.r4_shadowed_by_t2
        and #rows(T, 'r4_by_t3') == C.r4_shadowed_by_t3,
        'the printed 回复状态 shadow rows disagree with their counters')
    -- ⛔ THE CEILING, STATED AS A NUMBER RATHER THAN A CAVEAT. Unlike cell A,
    -- these two branches are separated by the `nMode == BOT_MODE_RETREAT`
    -- wrapper that no fixture can read, so this cell over-counts by exactly the
    -- frames whose mode is not RETREAT. What it can still settle is the
    -- published sibling readings, and it does: NONE of 'tpdeep''s domain frames
    -- is claimed by 撤退:2 or 撤退:3, so that id's number needs no correction
    -- from this cell -- an explicit zero, never a silence.
    assert(C.tpdeep_true_in_r4_shadowed_by_t2 == 0
        and C.tpdeep_true_in_r4_shadowed_by_t3 == 0,
        '\'tpdeep\' now has domain frames claimed by a retreat branch other '
        .. 'than 撤退:1 (' .. C.tpdeep_true_in_r4_shadowed_by_t2 .. ' / '
        .. C.tpdeep_true_in_r4_shadowed_by_t3 .. '); its published domain '
        .. 'reading would need a second correction and this file must not '
        .. 'issue it silently')
    assert(C.tpdeep_true_in_r4_shadowed_by_any == C.tpdeep_true_in_r4_shadowed,
        'the any-retreat shadow of \'tpdeep\' disagrees with the 撤退:1-only '
        .. 'count the previous round published')
end

tests['[corpus] the three priced levers are empty, and each names its clause'] = function()
    local _, C, T = sweep()

    -- (1) '撤退:2''s empty-ring leg. The leg EXISTS (the prose is wrong) and is
    -- still not actionable (both frames are under the family's floor).
    assert(C.t2_trigger == 30, '撤退:2\'s trigger bound moved to ' .. C.t2_trigger)
    assert(C.t2_ring_empty == 2,
        'the empty-ring leg of 撤退:2 moved to ' .. C.t2_ring_empty
        .. ' frame(s). A NON-zero here is the proof that the branch does not '
        .. '"require enemies": its cap base 0.15 is nonzero')
    assert(C.t2_empty_below_band == C.t2_ring_empty and C.t2_empty_in_band == 0,
        'the empty-ring leg is no longer entirely below 0.10 ('
        .. C.t2_empty_below_band .. ' of ' .. C.t2_ring_empty .. '); the '
        .. 'exemption of 撤退:2 was left standing BECAUSE of that, so it has to '
        .. 'be re-decided')
    -- ⛔ Closed form, not a sample: the branch requires damage within 6.0s and
    -- the family's helper refuses on damage within 6.0s.
    assert(C.t2_empty_damaged_only == 0,
        'a frame satisfies both 撤退:2\'s damage requirement and \'tpquiet\'\'s '
        .. 'no-damage refusal, which is a contradiction -- the two windows have '
        .. 'drifted apart')
    assert(must(C.t2_empty_with_any_tower, 't2_empty_with_any_tower') == 2,
        'the anti-vacuum for the tower clause on this leg moved to '
        .. tostring(C.t2_empty_with_any_tower) .. ' -- a zero there would mean '
        .. 'no frame on this leg had an enemy tower anywhere in the world, and '
        .. 'the clause was never exercised')

    -- (2) '撤退:3''s deep leg. The HOLE is real; the DOMAIN is empty, and the
    -- clause that empties it is the SOURCE clause, not the band.
    assert(C.t3_below_stayfloor + C.t3_at_or_above_stayfloor == C.t3_trigger,
        'the below/above-floor partition of 撤退:3 does not sum to its trigger '
        .. 'set; a partition that leaks is not a partition')
    assert(C.t3_below_stayfloor == 5,
        C.t3_below_stayfloor .. ' of 撤退:3\'s trigger frames sit below its '
        .. 'only veto\'s floor, not 5 -- that subtraction is the hole')
    assert(C.t3_deep_in_band == 1,
        'the [0.10, 0.18) slice of 撤退:3 moved to ' .. C.t3_deep_in_band)
    assert(C.t3_deep_src == 0 and C.t3_deep_domain == 0,
        'the deep leg of 撤退:3 is no longer empty (' .. C.t3_deep_src
        .. ' with a sip, domain ' .. C.t3_deep_domain .. '). It was declared '
        .. 'unbuildable for want of ONE frame; if a frame now exists, the '
        .. 'lever is buildable and the corpus request can be closed')
    assert(C.t3_deep_with_any_tower == 7,
        'the anti-vacuum for the tower clause on 撤退:3 moved to '
        .. C.t3_deep_with_any_tower .. ' -- a zero there would mean the tower '
        .. 'clause was never exercised and the domain zero says nothing')
    assert(#rows(T, 't3_deep') == C.t3_deep_domain,
        'the printed deep rows disagree with the domain counter')
end

return tests

-- [strategy 2026-09-08, owner priority P2 / P4.4(ii)] THE THIRD SHADOW CENSUS --
-- and the first one whose cell is an IDENTITY rather than a ceiling.
--
-- The two censuses before this one live in X.ConsiderItemDesire["item_tpscroll"],
-- where every branch trigger is an UPPER BOUND (`X` is file-local, so
-- `X.CanJuke`, `nAttackAllyList` and the enclosing `nMode == BOT_MODE_RETREAT`
-- cannot be driven from a fixture).  The 16:55Z round closed with a specific
-- next question: the same shadow shape exists a second time, in
-- bots/mode_retreat_generic.lua, where
--
--     if J.ShouldStayAndRegen(bot)     then return BOT_MODE_DESIRE_NONE end  -- PROMOTED
--     if J.ShouldRegenNotWalkHome(bot) then return BOT_MODE_DESIRE_NONE end  -- gated 'stayfield2'
--
-- sit adjacent, and that cell decides whether the 'stayfield2' half of the
-- registered promote atom 'field_hold_needs_magnitude' can read anything at all.
--
-- ⭐ WHY THIS CELL NEEDS NO BOUNDS.  Between the promoted veto's return and the
-- gated veto's call there is NOTHING that returns (`MRG_RETURNS_BETWEEN == 0`,
-- derived twice below -- once here, once in the sweep).  So
--
--     the gated line is evaluated  ⟺  the promoted one answered FALSE
--
-- exactly.  `srnwh_armed_true_live` is therefore a DOMAIN, not a ceiling.  Three
-- returns stand UPSTREAM of the pair (a dead/immune bot, a WK reincarnation, a
-- pre-horn human lane); they cap the ABSOLUTE reachability of both lines, but
-- they are common to both and cancel out of the shadow between them -- so they
-- are pinned as a count (`MRG_RETURNS_ABOVE == 3`) rather than described, and a
-- fourth one cannot arrive silently.
--
-- ⭐⭐ THE HEADLINE, AND IT IS THE ASYMMETRY THE ATOM DOES NOT ADMIT.  Measured
-- on the same 1021-frame corpus walk (tests/_tpquiet_sweep.lua, extended -- NOT
-- a fourth full-corpus sweep):
--
--     srnwh_armed_true            24   -- the opinion, identical to 'stayfield''s
--     srnwh_armed_true_shadowed    5   -- claimed by the PROMOTED veto first
--     srnwh_armed_true_live       19   -- ...and this is a DOMAIN, not a bound
--
-- against the previous round's reading of the other half: 'stayfield' reaches at
-- most 1 corpus frame at its only call site.  Both ids wrap the SAME predicate
-- (byte-identical wrappers modulo the id string, asserted below and checked
-- per-frame: `core_disagree == 0`), so the 24 is one opinion asked at two
-- addresses -- and the two addresses buy 19 frames and ~1 frame.  ⇒ the standing
-- plan to arm the pair in ONE wave does not produce two comparable readings: it
-- produces one lever plus a near-no-op, and a joint verdict cannot be split
-- afterwards.  That is the P4.4(ii) evidence this file exists to hand over.
--
-- ⭐⭐⭐ AND THE SIGN, MEASURED PER CELL AS THE PREVIOUS ROUND INSISTED.  Here
-- the shadow is BENIGN FOR PLAY IN THE STRONGEST FORM ANY OF THE THREE CENSUSES
-- HAS PRODUCED: the two lines return the SAME `BOT_MODE_DESIRE_NONE`, so on all
-- 5 shadowed frames the bot's decision is byte-identical either way.  Nothing is
-- lost but the MEASUREMENT -- a wave arming 'stayfield2' reads those 5 as
-- no-ops.  (Census 1: the shadow cost a domain frame.  Census 2: the winner
-- guarded at least as well.  Census 3: the winner makes the same decision.)
--
-- ⭐⭐⭐⭐ THE CORRECTION THIS FILE CARRIES.  'stayfield2''s own comment names
-- two blind spots in the promoted veto and puts the DANGER read first, with the
-- pinned lina frame as its evidence: (1) `WasRecentlyDamagedByAnyHero(3.0)` with
-- no attribution, (2) a flask/tango-only regen read that cannot see a
-- faerie_fire.  On this corpus the split is not close:
--
--     sf2_live_swh_noflask   19  of 19   -- blind spot (2), EVERY live frame
--     sf2_live_swh_damaged    1  of 19   -- blind spot (1)
--     sf2_live_unexplained    0          -- the enumeration is complete here
--
-- The id's live domain is bought by the REGEN half, not the danger half.  The
-- comment is not wrong -- its pinned frame is real -- but it is unrepresentative,
-- and a reader budgeting this id off the comment would budget the wrong clause.
-- Consequence for wave planning, stated as arithmetic: 'stayattr' (the separate
-- id that fixes blind spot (1) INSIDE the promoted veto, making it fire on more
-- frames) can convert at most `sf2_live_swh_damaged` = 1 of these 19 into
-- shadowed ⇒ 'stayattr' and 'stayfield2' interact on at most one corpus frame
-- and do not confound each other in a shared wave.
--
-- ⛔ TWO OF THE FOUR CANDIDATE REASONS ARE RULED OUT IN CLOSED FORM, and both
-- are measured anyway -- a closed form nobody measures is prose:
--   * BAND: the gated helper's [0.18, 0.55] is INSIDE the promoted one's
--     [0.18, 0.75] ⇒ HP can never be why the promoted veto is false here
--     (`sf2_live_swh_above_ceil == 0`);
--   * RING: the gated helper demands an EMPTY 1600 ring where the promoted one
--     only checks 1200 ⇒ a 1200 occupant is impossible on a live frame
--     (`sf2_live_swh_ring_occupied == 0`).
-- Both containments are parsed off the two functions, so the closed form goes
-- red if either radius or either edge moves.
--
-- ⛔ WHAT THIS FILE DOES NOT DO.  It arms nothing and proposes no admission
-- (owner P4.2 is a freeze; both ids stay FROZEN-HOLD).  It does not touch the
-- shared 0.18 floor in J.IsFieldRegenSituation -- that one edit moves
-- 'stayfield', 'stayfield2' and the buy-side ids on a single push, which is the
-- lanefix bundle mistake.  It does not re-baseline 'stayfield''s published
-- reading (the previous round already issued that correction) and it does not
-- rewrite the 'stayfield2' comment's pinned frame -- it prices it.

package.path = 'tests/?.lua;' .. package.path
local cs = require('corpus_scale')

local JMZ = 'bots/FunLib/jmz_func.lua'
local MRG = 'bots/mode_retreat_generic.lua'

local tests = {}

local function read(path)
    local f = assert(io.open(path, 'r'), path .. ' is not readable')
    local s = f:read('*a')
    f:close()
    return s
end

--- The chain's source-order facts, derived HERE and only then required to agree
--- with the sweep's manifest.
---
--- ⛔ THE SEPARATION IS A STAND FINDING, INHERITED FROM THE SIBLING FILE'S M10:
--- an assertion whose input is produced by the artefact under test checks
--- nothing.  Everything below is read off the COMMENT-STRIPPED source, because
--- mode_retreat_generic's own prose block quotes both helper names, both
--- `BOT_MODE_DESIRE_NONE` returns and the entire shadow argument -- an unstripped
--- read would let that comment satisfy every assertion in this file.
local RET_NONE = 'return BOT_MODE_DESIRE_NONE'
local function chain_facts()
    local src = read(MRG):gsub('%-%-[^\n]*', '')
    -- Slice to GetDesireHelper, and to the NEXT top-level `function` rather than
    -- to the first unindented `end`: a non-greedy `.-\nend\n` stops at the first
    -- one and hands back a fragment containing none of the calls, which reads as
    -- "the calls are gone" instead of "the slice is wrong" (measured while
    -- building this file -- every column came back 0 with the slice flag at 1).
    local a = src:find('function GetDesireHelper()', 1, true)
    local b = a and src:find('\nfunction ', a + 1, true)
    local h = (a and b) and src:sub(a, b) or nil
    if h == nil then return { helper = nil } end
    local swh = h:find('if J.ShouldStayAndRegen(bot) then', 1, true)
    local walk = h:find('if J.ShouldRegenNotWalkHome(bot) then', 1, true)
    local function nret(s)
        local n, at = 0, 1
        while true do
            local i = s:find('return', at, true)
            if i == nil then break end
            n, at = n + 1, i + 1
        end
        return n
    end
    -- ⛔ THE FIRST `return`, NOT THE FIRST `return NONE`. Searching for the
    -- CONSTANT skips over a return carrying a different desire and lands on the
    -- next veto's, so a line whose return value was changed keeps reading as
    -- "returns NONE". Locate the return, THEN ask what it returns.
    local function ret_after(at)
        return at and h:find('return', at, true)
    end
    local swh_ret, walk_ret = ret_after(swh), ret_after(walk)
    local function is_none(at)
        return at ~= nil and h:sub(at, at + #RET_NONE - 1) == RET_NONE
    end
    return {
        helper = h,
        swh = swh,
        walk = walk,
        swh_ret = swh_ret,
        walk_ret = walk_ret,
        swh_ret_is_none = is_none(swh_ret),
        walk_ret_is_none = is_none(walk_ret),
        nret = nret,
    }
end

-- ==========================================================================
-- 1. The structure that makes this cell an identity
-- ==========================================================================

tests['[structure] the two vetoes are adjacent, both return NONE, nothing between'] = function()
    local o = chain_facts()
    assert(o.helper ~= nil,
        'GetDesireHelper could not be sliced out of ' .. MRG .. '; the whole '
        .. 'census is a statement about the veto chain inside that function')
    assert(o.swh ~= nil,
        'the PROMOTED veto call `if J.ShouldStayAndRegen(bot) then` is gone from '
        .. 'GetDesireHelper -- with it goes the thing that does the shadowing')
    assert(o.walk ~= nil,
        'the gated veto call `if J.ShouldRegenNotWalkHome(bot) then` is gone '
        .. 'from GetDesireHelper. That is the GH #606 / director-2026-09-07 '
        .. 'failure mode by name: an ARMED id at zero call sites reads as '
        .. '"tested, no effect" in every wave')
    assert(o.swh < o.walk,
        'the gated veto now precedes the PROMOTED one; every "shadowed" count '
        .. 'in this file is stated against the opposite order')
    assert(o.swh_ret ~= nil and o.walk_ret ~= nil,
        'a veto stopped RETURNING; without the return the first line does not '
        .. 'shadow the second at all')
    assert(o.swh_ret_is_none and o.walk_ret_is_none,
        'a veto stopped returning BOT_MODE_DESIRE_NONE (promoted: '
        .. tostring(o.swh_ret_is_none) .. ', gated: '
        .. tostring(o.walk_ret_is_none) .. '). The "benign" verdict rests '
        .. 'entirely on the two returns being the SAME value; if they diverge, '
        .. 'the shadowed frames are a BEHAVIOUR difference and have to be '
        .. 're-read as one')
    assert(o.swh_ret < o.walk,
        'the PROMOTED veto\'s return no longer precedes the gated veto\'s call')
    -- ⛔ Two DISTINCT positions. `return BOT_MODE_DESIRE_NONE` appears many
    -- times in this function, so a shared anchor would satisfy every ordering
    -- claim above at once (the M13 shape).
    assert(o.swh_ret < o.walk_ret,
        'both vetoes resolved to the SAME return position; a shared anchor '
        .. 'makes every ordering claim above vacuous')
    -- ⭐ THE IDENTITY ITSELF.
    local between = o.helper:sub(o.swh_ret + #RET_NONE, o.walk)
    assert(o.nret(between) == 0,
        'something that RETURNS was inserted between the two vetoes ('
        .. o.nret(between) .. ' occurrence(s)). The live-domain reading in this '
        .. 'file is exact ONLY because the gated line is evaluated on precisely '
        .. 'the frames where the promoted one answered false; with a third exit '
        .. 'in between it becomes a ceiling and must be reported as one')
end

tests['[structure] exactly three returns stand upstream of the pair'] = function()
    local o = chain_facts()
    assert(o.helper ~= nil and o.swh ~= nil, 'the chain could not be located')
    -- These cap the ABSOLUTE reachability of both lines (dead/immune bot, WK
    -- reincarnation, pre-horn human lane) but are COMMON to both, so they cancel
    -- out of the shadow between them. Pinned as a number: a fourth upstream exit
    -- would lower both readings without touching a single counter in the sweep.
    assert(o.nret(o.helper:sub(1, o.swh)) == 3,
        'the number of returns upstream of the veto pair moved to '
        .. o.nret(o.helper:sub(1, o.swh)) .. ', not 3. Those exits cancel out of '
        .. 'the SHADOW but not out of absolute reachability, so a change there '
        .. 'changes what `srnwh_armed_true_live` is a domain OF')
end

tests['[structure] the two ids wrap ONE predicate, differing only in the id'] = function()
    local jmz = read(JMZ):gsub('%-%-[^\n]*', '')
    local w1 = jmz:match('function J%.ShouldRegenNotTpHome.-\nend')
    local w2 = jmz:match('function J%.ShouldRegenNotWalkHome.-\nend')
    assert(w1 and w2, 'one of the two field-hold wrappers could not be located')
    local n1 = w1:gsub('ShouldRegenNotTpHome', 'W'):gsub("'stayfield'", "'ID'"):gsub('%s+', ' ')
    local n2 = w2:gsub('ShouldRegenNotWalkHome', 'W'):gsub("'stayfield2'", "'ID'"):gsub('%s+', ' ')
    assert(n1 == n2,
        'the two wrappers have drifted apart:\n  ' .. n1 .. '\n  ' .. n2
        .. '\nThe headline of this file -- "one opinion asked at two addresses, '
        .. 'buying 19 frames and ~1" -- is only meaningful while they are the '
        .. 'same predicate')
    assert(w2:find('J.ShouldRegenNotGoHome', 1, true) ~= nil,
        '\'stayfield2\' no longer routes through J.ShouldRegenNotGoHome')
    assert(w2:find("IsSoakCandidate( 'stayfield2' )", 1, true) ~= nil,
        '\'stayfield2\' is no longer the id on the walk-half wrapper')
end

tests['[structure] the two closed forms are containments, parsed off both functions'] = function()
    local jmz = read(JMZ):gsub('%-%-[^\n]*', '')
    local stay = jmz:match('function J%.ShouldStayAndRegen.-\nend')
    local sit = jmz:match('function J%.IsFieldRegenSituation.-\nend')
    assert(stay and sit, 'a function behind the closed form could not be located')
    local slo, shi = stay:match('nHP < ([%d%.]+) or nHP > ([%d%.]+)')
    local flo, fhi = sit:match('nHP < ([%d%.]+) or nHP > ([%d%.]+)')
    slo, shi, flo, fhi = tonumber(slo), tonumber(shi), tonumber(flo), tonumber(fhi)
    assert(slo and shi and flo and fhi, 'a band edge could not be parsed')
    -- BAND CONTAINMENT: the gated helper's band inside the promoted one's ⇒ HP
    -- can never be why the promoted veto is false on a live frame.
    assert(slo <= flo and fhi <= shi,
        'the field-regen band [' .. flo .. ', ' .. fhi .. '] is no longer '
        .. 'inside the promoted veto\'s [' .. slo .. ', ' .. shi .. ']. The '
        .. '`sf2_live_swh_above_ceil == 0` column stops being a closed form and '
        .. 'becomes a sample the moment that containment breaks')
    -- RING CONTAINMENT: the promoted veto's ring no wider than the gated
    -- helper's ⇒ a 1200 occupant is impossible on a live frame.
    local sring = tonumber(stay:match('J%.GetNearbyHeroes%( bot, (%d+)'))
    local fring = tonumber(sit:match('J%.GetNearbyHeroes%( bot, (%d+)'))
    assert(sring and fring, 'a ring radius could not be parsed')
    assert(sring <= fring,
        'the promoted veto\'s ring (' .. sring .. ') is now WIDER than the '
        .. 'field-regen ring (' .. fring .. '); `sf2_live_swh_ring_occupied == 0` '
        .. 'was a containment, not a measurement, and is now neither')
end

-- ==========================================================================
-- 2. The corpus census (subprocess sweep, memoised)
-- ==========================================================================

local sweep_cache = nil
local function sweep()
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

--- Keeps a MISSING counter from reading as a satisfied assertion (GH #171): the
--- sweep zero-initialises every bucket, so `nil` means the KEY is gone.
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

tests['[corpus] the manifest agrees with the structure derived above'] = function()
    local G = sweep()
    local o = chain_facts()
    assert(G.MRG_HELPER_FN == 1 and G.MRG_SWH_CALLS == 1 and G.MRG_SRNWH_CALLS == 1,
        'the sweep no longer finds exactly one of each veto call inside '
        .. 'GetDesireHelper (' .. tostring(G.MRG_SWH_CALLS) .. ' / '
        .. tostring(G.MRG_SRNWH_CALLS) .. ')')
    assert(G.FILE_SRNWH_CALLS == 1,
        '\'stayfield2\' has ' .. tostring(G.FILE_SRNWH_CALLS) .. ' call sites in '
        .. MRG .. ', not one; with a second address its wave reading is no '
        .. 'longer attributable to this chain')
    local function want(sKey, bTruth)
        assert(G[sKey] == (bTruth and 1 or 0),
            'the sweep manifest says ' .. sKey .. ' = ' .. tostring(G[sKey])
            .. ' while this file derives ' .. tostring(bTruth) .. ' from the '
            .. 'source; a divergence means the sweep read a different tree')
    end
    want('MRG_SWH_BEFORE_SRNWH', o.swh < o.walk)
    want('MRG_SWH_RETURNS_NONE', o.swh_ret < o.walk and o.swh_ret_is_none)
    want('MRG_SRNWH_RETURNS_NONE', o.walk_ret_is_none)
    want('MRG_RETURNS_DISTINCT', o.swh_ret < o.walk_ret)
    assert(G.MRG_RETURNS_BETWEEN == 0,
        'the manifest counts ' .. tostring(G.MRG_RETURNS_BETWEEN) .. ' return(s) '
        .. 'between the two vetoes')
    assert(G.MRG_RETURNS_ABOVE == 3,
        'the manifest counts ' .. tostring(G.MRG_RETURNS_ABOVE) .. ' return(s) '
        .. 'upstream of the pair, not 3')
    assert(G.WRAPPERS_IDENTICAL_MOD_ID == 1 and G.WALK_WRAPPER_ROUTES == 1
        and G.WALK_WRAPPER_NIDS == 1,
        'the sweep no longer reads the two wrappers as one predicate behind two '
        .. 'ids')
    -- The two containments, as the sweep read them.
    assert(G.SWH_LO <= G.STAY_FLOOR and G.STAY_CEIL <= G.SWH_HI,
        'the manifest\'s band containment broke: [' .. tostring(G.STAY_FLOOR)
        .. ', ' .. tostring(G.STAY_CEIL) .. '] is not inside ['
        .. tostring(G.SWH_LO) .. ', ' .. tostring(G.SWH_HI) .. ']')
    assert(G.SWH_RING <= G.FIELDSIT_RING,
        'the manifest\'s ring containment broke: ' .. tostring(G.SWH_RING)
        .. ' > ' .. tostring(G.FIELDSIT_RING))
end

tests['[corpus] CELL C: stayfield2 reaches 19 of its 24 frames, exactly'] = function()
    local _, C = sweep()
    cs.ratchet(C.live, 1021, 'live hero frames')
    assert(C.raises == 0, tostring(C.raises) .. ' frame(s) raised inside a '
        .. 'driven helper; a raise is not a measurement')
    assert(C.arm_leak == 0 and C.stayfield2_arm_leak == 0,
        'the sweep armed more than one id at a time (arm_leak ' .. C.arm_leak
        .. ', stayfield2 leaking into \'stayfield\' '
        .. must(C.stayfield2_arm_leak, 'stayfield2_arm_leak') .. '). The whole '
        .. 'point of two ids for one predicate is that a wave can tell the two '
        .. 'call sites apart')
    -- Gate anti-vacuum: inert unarmed, non-trivial armed.
    assert(must(C.srnwh_shipped_true, 'srnwh_shipped_true') == 0,
        'J.ShouldRegenNotWalkHome answers TRUE with no id armed on '
        .. C.srnwh_shipped_true .. ' frame(s) -- it is not gated, and a gated '
        .. 'fix that is live in shipped play is the one thing this discipline '
        .. 'exists to prevent')
    assert(C.srnwh_armed_true == 24,
        'the \'stayfield2\' opinion covers ' .. C.srnwh_armed_true
        .. ' corpus frames, not 24')
    -- ⭐ ONE PREDICATE, TWO ADDRESSES -- checked per frame, not asserted from
    -- the fact that the wrappers look alike.
    assert(C.core_disagree == 0,
        C.core_disagree .. ' frame(s) had \'stayfield\' and \'stayfield2\' '
        .. 'answering DIFFERENTLY. They wrap the same predicate, so a '
        .. 'disagreement means one of the two reads was taken with the wrong id '
        .. 'armed -- the failure mode that would silently invent or erase a '
        .. 'shadow')
    assert(C.srnwh_armed_true == C.stayfield_armed_true,
        'the two halves\' opinions differ in SIZE (' .. C.srnwh_armed_true
        .. ' vs ' .. C.stayfield_armed_true .. ') while agreeing frame by '
        .. 'frame, which is arithmetically impossible -- one of the two columns '
        .. 'is measuring something else')
    -- ⭐ THE PARTITION. A partition that leaks is not a partition.
    assert(C.srnwh_armed_true_shadowed == 5,
        'the shadowed half moved to ' .. C.srnwh_armed_true_shadowed)
    assert(C.srnwh_armed_true_live == 19,
        'the LIVE domain of \'stayfield2\' moved to ' .. C.srnwh_armed_true_live
        .. '. This number is the P4.4(ii) evidence: it is what a wave arming '
        .. 'this id can read, against at most 1 for \'stayfield\', the other '
        .. 'half of the same promote atom')
    assert(C.srnwh_armed_true_shadowed + C.srnwh_armed_true_live == C.srnwh_armed_true,
        'the shadowed/live split does not sum to the opinion')
    -- Anti-vacuum in the other direction: the two opinions must actually
    -- disagree somewhere, or the shadow column could not be read at all.
    assert(C.swh_shipped_true == 13 and C.swh_true_srnwh_false == 8,
        'the promoted veto\'s own reading moved (' .. C.swh_shipped_true
        .. ' true, ' .. C.swh_true_srnwh_false .. ' of them where the gated one '
        .. 'is false); a zero in the second would mean the two never disagree '
        .. 'and the shadow is not a measurement')
    assert(C.swh_shipped_true == C.srnwh_armed_true_shadowed + C.swh_true_srnwh_false,
        'the promoted veto\'s TRUE set does not split into "also gated-true" '
        .. 'plus "gated-false"')
end

tests['[corpus] CELL C: the shadow is benign -- both lines return the same NONE'] = function()
    local G, C, T = sweep()
    local shadowed = rows(T, 'sf2_shadowed')
    local live = rows(T, 'sf2_live')
    assert(#shadowed == C.srnwh_armed_true_shadowed and #live == C.srnwh_armed_true_live,
        'the printed rows (' .. #shadowed .. ' / ' .. #live .. ') disagree with '
        .. 'their counters; a census whose rows and counters disagree is not a '
        .. 'census')
    -- ⭐ The benign-ness is STRUCTURAL, not statistical: the two lines return
    -- the same constant, so on every shadowed frame the bot's decision is
    -- identical either way. What is lost is the reading, not a guard. Pinned on
    -- the structure fact rather than on the rows, because the rows could never
    -- say it.
    assert(G.MRG_SWH_RETURNS_NONE == 1 and G.MRG_SRNWH_RETURNS_NONE == 1,
        'one of the two vetoes stopped returning BOT_MODE_DESIRE_NONE. The '
        .. '"benign" verdict in this file rests entirely on the two returns '
        .. 'being the SAME value; if they diverge, the 5 shadowed frames are a '
        .. 'behaviour difference and have to be re-read as one')
    -- ...and every shadowed frame sits inside the shared band, which is what
    -- makes them frames of the same disagreement rather than a stray.
    for _, r in ipairs(shadowed) do
        assert(r.hp >= G.STAY_FLOOR and r.hp <= G.STAY_CEIL,
            'shadowed frame ' .. r.fixture .. '/' .. r.hero .. ' reads hp '
            .. string.format('%.3f', r.hp) .. ', outside the field-regen band ['
            .. G.STAY_FLOOR .. ', ' .. G.STAY_CEIL .. '] the gated helper '
            .. 'requires -- then the row is wrong, not merely surprising')
    end
end

tests['[corpus] CELL C: the live domain is bought by the REGEN blind spot, not the danger one'] = function()
    local _, C = sweep()
    -- The two closed forms, measured. A closed form nobody measures is prose.
    assert(must(C.sf2_live_swh_above_ceil, 'sf2_live_swh_above_ceil') == 0,
        C.sf2_live_swh_above_ceil .. ' live frame(s) sit outside the promoted '
        .. 'veto\'s band. The band containment says this is impossible, so a '
        .. 'non-zero means the containment assertion above and this drive '
        .. 'disagree about the same source')
    assert(must(C.sf2_live_swh_ring_occupied, 'sf2_live_swh_ring_occupied') == 0,
        C.sf2_live_swh_ring_occupied .. ' live frame(s) have an enemy inside '
        .. 'the promoted veto\'s ring while the gated helper demands the WIDER '
        .. 'ring empty -- arithmetically impossible')
    -- ⭐ THE CORRECTION. 'stayfield2''s comment puts the DANGER blind spot
    -- first; the corpus says the REGEN one buys the whole domain.
    assert(C.sf2_live_swh_noflask == 19,
        'the flask/tango-blind frames moved to ' .. C.sf2_live_swh_noflask
        .. ' of ' .. C.srnwh_armed_true_live .. '. "Every live frame" is the '
        .. 'claim that makes this id\'s domain a REGEN-read finding rather than '
        .. 'the danger-read finding its own comment leads with')
    assert(C.sf2_live_swh_noflask == C.srnwh_armed_true_live,
        'the flask-blind count is no longer the WHOLE live domain, so the '
        .. '"bought by blind spot (2)" reading needs re-deriving')
    assert(C.sf2_live_swh_damaged == 1,
        'the damaged-but-unattributed frames moved to ' .. C.sf2_live_swh_damaged
        .. '. This number is also the interaction budget: \'stayattr\' makes the '
        .. 'promoted veto fire on MORE frames, so it can convert at most this '
        .. 'many live frames into shadowed ones -- which is why the two ids do '
        .. 'not confound each other in a shared wave')
    assert(C.sf2_live_swh_damaged <= C.srnwh_armed_true_live,
        'a subset column exceeds the set it is a subset of')
    assert(must(C.sf2_live_unexplained, 'sf2_live_unexplained') == 0,
        C.sf2_live_unexplained .. ' live frame(s) are explained by NEITHER named '
        .. 'blind spot, i.e. the promoted veto is false there for some clause '
        .. 'further down its body. That is not a failure -- this file never '
        .. 'claimed its enumeration was complete -- but the "two blind spots" '
        .. 'framing above stops covering the domain and has to be widened')
    -- The overlap with the OTHER half of the same promote atom, so a joint wave
    -- knows how much of its reading is attributable to one id.
    assert(must(C.sf2_live_in_t3, 'sf2_live_in_t3') == 1,
        'the overlap between \'stayfield2\'\'s live domain and \'stayfield\'\'s '
        .. 'branch moved to ' .. C.sf2_live_in_t3 .. '. The two ids sit in '
        .. 'different files and are meant to be armed together; this is how '
        .. 'many frames a joint wave could credit to either')
end

return tests

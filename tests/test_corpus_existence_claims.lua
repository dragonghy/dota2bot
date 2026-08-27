-- GH #248: a claim about what tests/fixtures/ does NOT contain must be
-- executable, because the corpus only ever grows.
--
-- THE DEFECT THIS FILE EXISTS FOR
-- ------------------------------------------------------------------
-- tests/test_campgrade_tier_ladder.lua carried, as the stated reason for
-- arguing GH #137's bearing-weight case from a stand-in hero:
--
--     "The frame GH #137 §3 names, f_260823_002103_wk_ancient_camp_634, is
--      not in the tree on any ref ... level 11 for a Wraith King is therefore
--      not purchasable"
--
-- Both halves were false at HEAD. The frame is in the corpus; its
-- skeleton_king is level 11; it carries the ancient-camp debuff. So the file's
-- strongest available assertion -- "on the very frame where an 11-level Wraith
-- King ground an ancient camp from 100% to 13.5% HP, the armed ladder refuses
-- that camp" -- was sitting one directory away and was never taken, while a
-- level-10 stand-in wore the words "the bearing-weight case".
--
-- WHY A COMMENT IS THE WRONG CONTAINER FOR IT
-- ------------------------------------------------------------------
-- tests/fixtures/ is append-only in practice: fixtures land, they are not
-- pruned. A sentence of the form "the corpus does not have X" is therefore
-- TRUE WHEN WRITTEN and goes FALSE WITHOUT ANYBODY TOUCHING THE FILE THAT
-- CONTAINS IT. Nothing turns red -- the failure direction is a false GREEN,
-- and the shape it takes is the one above: a stand-in keeps the bearing case's
-- name long after the bearing case became purchasable.
--
-- This is the MIRROR of tests/corpus_scale.lua, not a duplicate of it. That
-- module handles growth turning a COUNT EQUALITY falsely RED (`== 100` going
-- red because a 101st fixture landed) and is deliberately silent about
-- existence claims. Growth breaks counts loudly and breaks negative existence
-- claims silently; only the loud half had a handle before this file.
--
-- THE RULE, in two halves, both executable:
--   (A) every tests/fixtures/*.lua path NAMED anywhere under tests/ must
--       exist -- catches the other direction (a fixture is deleted and a
--       comment goes on describing it);
--   (B) no line that names an EXISTING fixture may also assert that it is
--       absent. If a test wants to say a frame is unavailable, it must ask
--       the corpus at run time, as test_campgrade_tier_ladder.lua now does.
--
-- HOW THE TWO ZEROS ARE KEPT FROM BEING VACUOUS -- read before trusting them.
-- Both (A) and (B) report ZERO on a healthy tree, and a zero from a sweep
-- nobody has seen fire is not a measurement. So the sweeps take their file
-- list as an ARGUMENT, and the control below drives the very same functions
-- over a planted source file (written to a temp path, outside tests/) that
-- carries one of each violation. Neutering either check turns the control red,
-- not just the sweep it guards.
--
-- Two self-inflicted defects were found writing this file, both in the
-- "report a miss as a pass" direction, and both fixed by changing the
-- INSTRUMENT rather than adding an assertion:
--   (i)  ABSENCE_TOKENS started with overlapping entries ('is not in the tree'
--        and 'not in the tree on any ref'). Deleting the inner one is masked
--        by the outer, so the list could not be mutation-tested entry by
--        entry. The list is minimal now, and non-overlap is asserted.
--   (ii) The first per-token control BUILT ITS SAMPLE OUT OF THE TOKEN, so it
--        passed for any token whatsoever -- a tautology wearing a control's
--        name. Six of seven token-deletion mutations survived it. The samples
--        below are authored independently of the list, and coverage is
--        asserted in BOTH directions: every sample is flagged, and every token
--        is the reason some sample is flagged.

package.path = 'tests/?.lua;' .. package.path

local tests = {}

-- Anything that reads as "this fixture is not available". Lower-cased before
-- matching. Kept small and literal on purpose: a fuzzy list would start
-- flagging prose that merely mentions absence of something else.
-- ⚠ NO ENTRY MAY CONTAIN ANOTHER -- see (i) above; it is asserted, not hoped.
local ABSENCE_TOKENS = {
    'not in the tree',
    'not in the corpus',
    'does not exist',
    'not purchasable',
    'no such fixture',
    'absent from the corpus',
    'corpus does not carry',
}

local FIXTURE_PAT = 'tests/fixtures/[%w_%./%-]+%.lua'

--- Which absence token, if any, does this line carry?
local function absence_token(sLine)
    local sLower = sLine:lower()
    for _, tok in ipairs(ABSENCE_TOKENS) do
        if sLower:find(tok, 1, true) then return tok end
    end
    return nil
end

--- Does this line both name an EXISTING fixture and claim a fixture is
--  missing? Returns the offending path and the token, or nil.
local function offending_path(sLine)
    local tok = absence_token(sLine)
    if not tok then return nil end
    for sPath in sLine:gmatch(FIXTURE_PAT) do
        local f = io.open(sPath, 'r')
        if f then f:close() return sPath, tok end
    end
    return nil
end

local function read(path)
    local f = assert(io.open(path, 'r'))
    local s = f:read('*a')
    f:close()
    return s
end

local function test_sources()
    local out = {}
    local p = assert(io.popen("find tests -maxdepth 2 -type f \\( -name '*.lua' -o -name '*.py' \\) " ..
                              "-not -path 'tests/fixtures/*' | sort"))
    for path in p:lines() do out[#out + 1] = path end
    p:close()
    return out
end

--- The two ratchets' verdict step, shared with the control below. It is a
--  named instrument rather than an inline `assert(#t == 0)` for a measured
--  reason: on a healthy tree #t is 0, so `== 0` and `>= 0` are
--  indistinguishable and a mutation swapping them SURVIVES every test in this
--  file. Routing both zeros through one function that the control watches
--  raise moves that mutation into something a test can see.
local function require_clean(tFindings, sMsg)
    if #tFindings ~= 0 then
        error(sMsg .. ':\n  ' .. table.concat(tFindings, '\n  '), 2)
    end
end

--- (A) as a function of its input, so the control can drive it too.
--  Returns { findings }, nRefs.
local function sweep_missing(tPaths)
    local tMissing, nRefs = {}, 0
    for _, path in ipairs(tPaths) do
        local seen = {}
        for sPath in read(path):gmatch(FIXTURE_PAT) do
            if not seen[sPath] then
                seen[sPath] = true
                nRefs = nRefs + 1
                local f = io.open(sPath, 'r')
                if f then f:close() else
                    tMissing[#tMissing + 1] = path .. ' -> ' .. sPath
                end
            end
        end
    end
    return tMissing, nRefs
end

--- (B) as a function of its input. Returns { findings }, { token -> true }.
local function sweep_claims(tPaths)
    local tBad, tHitTokens = {}, {}
    for _, path in ipairs(tPaths) do
        local n = 0
        for sLine in (read(path) .. '\n'):gmatch('([^\n]*)\n') do
            n = n + 1
            local sPath, tok = offending_path(sLine)
            if sPath then
                tHitTokens[tok] = true
                tBad[#tBad + 1] = string.format('%s:%d claims %s is missing, but it exists',
                    path, n, sPath)
            end
        end
    end
    return tBad, tHitTokens
end

--============================================================================
-- Controls first: the instrument must be shown to work before any zero it
-- produces is believed. GH #237's lesson applied to this file's own judging
-- code, and GH #242's ("the reading code is under test too").
--============================================================================

-- Independently authored sentences -- NOT derived from ABSENCE_TOKENS. Each is
-- the kind of line a test author actually writes. The pairing to a token is
-- asserted, not assumed, in both directions.
local BAD_SENTENCES = {
    'the frame it names is not in the tree on any ref, so we use a stand-in',
    'that hero at level 11 is not in the corpus, so the boundary is pinned elsewhere',
    'the frame does not exist yet -- the replay desk has not cut it',
    'level 11 for a Wraith King is therefore not purchasable',
    'there is no such fixture, so the assertion below uses the nearest one',
    'that instant is absent from the corpus and cannot be driven here',
    'the corpus does not carry a frame for this, so the numbers are declared',
}

tests['[control] the predicate flags each authored sentence, and every token earns its place'] = function()
    -- Assembled at run time: rule (B) sweeps this file too, and rule (A)
    -- requires every literal fixture path in it to exist, so a hand-written
    -- sample would either flag itself or forbid the missing-path case from
    -- being sampled at all. The judging code is not exempt from its own rules.
    local DIR = 'tests/' .. 'fixtures/'
    local LIVE = DIR .. 'f_260823_002103_wk_ancient_camp_634.lua'
    local GONE = DIR .. 'f_no_such_frame_deliberately_absent.lua'
    assert(io.open(LIVE, 'r'), 'the sample live path is not live; pick another')
    assert(io.open(GONE, 'r') == nil, 'the sample missing path exists; pick another')

    -- No entry may contain another, or the per-entry check below is masked.
    for i, a in ipairs(ABSENCE_TOKENS) do
        for j, b in ipairs(ABSENCE_TOKENS) do
            if i ~= j then
                assert(not a:find(b, 1, true), string.format(
                    'token %q contains token %q -- an overlapping list cannot be ' ..
                    'mutation-tested entry by entry', a, b))
            end
        end
    end

    -- Direction 1: every authored sentence is caught when it names a live frame.
    local tUsed = {}
    for _, s in ipairs(BAD_SENTENCES) do
        local sPath, tok = offending_path('-- ' .. LIVE .. ' ' .. s)
        assert(sPath == LIVE, 'the predicate misses an authored sentence: ' .. s)
        tUsed[tok] = true
    end
    -- Direction 2: every token is the reason some sentence was caught. A token
    -- nothing reaches is dead weight that a mutation could delete for free.
    for _, tok in ipairs(ABSENCE_TOKENS) do
        assert(tUsed[tok], 'absence token is unreachable from any authored ' ..
            'sentence -- deleting it would be a free mutation: ' .. tok)
    end
    assert(#BAD_SENTENCES == #ABSENCE_TOKENS, string.format(
        '%d sentences against %d tokens -- keep them one-to-one so the mapping ' ..
        'above stays a bijection', #BAD_SENTENCES, #ABSENCE_TOKENS))

    -- Negative cases. A TRUE absence claim is honest prose and must survive
    -- (a genuinely deleted fixture is (A)'s job, not (B)'s).
    assert(offending_path('-- ' .. GONE .. ' does not exist') == nil,
        'the predicate fires on a TRUE absence claim -- it would forbid honest prose')
    assert(offending_path('local F = { "' .. LIVE .. '" }') == nil,
        'the predicate fires on an ordinary fixture reference')
    assert(offending_path('-- GetAttackPoint() does not exist in the mock') == nil,
        'the predicate fires on prose about something other than the corpus')
end

tests['[control] both sweeps fire on a planted source file'] = function()
    -- The reachability control for the two zeros below. Same functions, same
    -- arguments, a file that carries one of each violation.
    local DIR = 'tests/' .. 'fixtures/'
    local LIVE = DIR .. 'f_260823_002103_wk_ancient_camp_634.lua'
    local GONE = DIR .. 'f_no_such_frame_deliberately_absent.lua'
    local sTmp = os.tmpname()
    local f = assert(io.open(sTmp, 'w'))
    f:write('-- a planted source file\n')
    f:write('-- ' .. LIVE .. ' is not in the tree on any ref\n')   -- (B) violation
    f:write("local X = { '" .. GONE .. "' }\n")                    -- (A) violation
    f:write('-- an innocent line naming ' .. LIVE .. '\n')
    f:close()

    local tMissing, nRefs = sweep_missing({ sTmp })
    assert(nRefs == 2, 'the planted file names two distinct fixture paths, saw ' .. nRefs)
    assert(#tMissing == 1 and tMissing[1]:find(GONE, 1, true),
        '(A) did not flag the planted missing path')

    local tBad = sweep_claims({ sTmp })
    assert(#tBad == 1 and tBad[1]:find(LIVE, 1, true),
        '(B) did not flag the planted absence claim')

    -- And the verdict step the two ratchets share must actually raise on those
    -- findings. Without this, `== 0` -> `>= 0` is a free mutation on a clean
    -- tree: both zeros would be unguarded and nothing in this file would say so.
    assert(not pcall(require_clean, tMissing, 'x'),
        'require_clean did not raise on a non-empty (A) finding list')
    assert(not pcall(require_clean, tBad, 'x'),
        'require_clean did not raise on a non-empty (B) finding list')
    assert(pcall(require_clean, {}, 'x'),
        'require_clean raises on a clean list -- the ratchets could never pass')

    os.remove(sTmp)
end

--============================================================================
-- (A) every named fixture exists.
--============================================================================

tests['[ratchet][A] every fixture path named under tests/ is a file that exists'] = function()
    local tSources = test_sources()
    local tMissing, nRefs = sweep_missing(tSources)
    -- Anti-vacuum floors, not equalities (GH #106): measured 2026-08-27 at
    -- 267 distinct (file, path) references across 208 test sources. Both may
    -- grow freely; a sweep that suddenly sees three references is measuring
    -- nothing and must not pass quietly.
    assert(#tSources >= 100, 'test-source sweep collapsed: ' .. #tSources .. ' files')
    assert(nRefs >= 250, 'fixture-reference sweep collapsed: ' .. nRefs .. ' references')
    require_clean(tMissing, 'test sources name fixtures that do not exist')
end

--============================================================================
-- (B) no prose claims an existing fixture is missing.
--============================================================================

tests['[ratchet][B] no line claims an existing fixture is absent'] = function()
    local tSources = test_sources()
    assert(#tSources >= 100, 'test-source sweep collapsed: ' .. #tSources .. ' files')
    local tBad = sweep_claims(tSources)
    require_clean(tBad, 'a comment is standing in for a corpus lookup (ask the ' ..
        'corpus at run time instead -- see the [bearing case] tests in ' ..
        'tests/test_campgrade_tier_ladder.lua for the shape)')
end

return tests

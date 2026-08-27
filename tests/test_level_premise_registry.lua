-- [hero] The level-ceiling premise: who still argues from a zero the harness put
-- there, and who has stopped.
--
-- THE PREMISE.  GH #84's turbo level census read `level >= 20` on 0 of 210
-- hero-slots, high-water 19.  That reading was correct about the corpus and
-- wrong about turbo: every batch game self-terminated at a 10-minute economy
-- cap, so no hero-slot COULD reach 20.  Owner priority P3 (GH #108) raised the
-- cap to 25 minutes; the first frame taken past it (GH #235,
-- iterations/pending/tpgap_159_fixture/, t=1382.2 = 23:02 of a 24.9-minute
-- naturally-ended game) reads ten heroes at level 22-27, three of them focus
-- heroes -- crystal_maiden 22, zuus 23, skeleton_king 26.  Real turbo games
-- average ~20 minutes, so the premise was never true of the shipped product
-- either: it was true of a measurement rig.
--
-- WHY A REGISTRY AND NOT NINE COMMENT EDITS.  The premise is not one sentence
-- in one place.  It is quoted at 9 sites in 4 shipped hero files and at 20 sites
-- across 9 test files, and behind several of those it is not prose at all but
-- the ARGUMENT of a verdict -- "this branch is unreachable in turbo", "this
-- domain is empty", "this read is dead weight".  Re-reading a verdict is work;
-- rewriting a sentence is not.  Mixing the two would let the cheap edits stand
-- in for the expensive re-reads, which is exactly how a premise rots quietly the
-- second time.  So this file splits them:
--
--   * bots/ is held at ZERO uncorrected sites, as an equality.  That is the
--     shipped Workshop deliverable and the only place a future reader meets the
--     claim without a test alongside it; the hero desk corrected all 9 on
--     2026-08-27 and owes no more.
--   * tests/ is a CEILING over a closed registry.  The count may fall as each
--     verdict is genuinely re-read; it may not rise, and no file may join the
--     list.  A number that can only go down is the honest shape for a debt
--     somebody else has to work off -- several of these rows belong to the
--     harness and director seats (GH #236 owns the ordering), not to this one.
--
-- WHAT COUNTS AS CORRECTED.  Not deleting the quote -- the premise SHOULD stay
-- quoted, because the verdicts written on top of it are unreadable without it
-- (the same shape as section 4 of tests/test_focus_talent_anchor.lua: the stale
-- ladder may be quoted, never used).  A site is corrected when the surrounding
-- comment block says so, i.e. carries GH #235 or the 2026-08-27 date within 14
-- lines.  So this ratchet cannot be satisfied by censorship, only by writing
-- down what replaced the claim.
--
-- HONEST BOUNDS
--   * This is a PROSE ratchet.  It proves that a premise-bearing comment
--     acknowledges the correction; it proves nothing about whether the verdict
--     built on that premise was actually re-read.  A file can pass here and
--     still hold a stale INERT.
--   * The fingerprints below are the literal forms the claim has taken in this
--     repo, collected by sweep on 2026-08-27.  A tenth phrasing would not be
--     caught.  That is why bots/ is an equality and not merely a ceiling: the
--     one place a new phrasing is cheap to notice is the place with nine known
--     ones already.
--   * THIS FILE EXCLUDES ITSELF, and has to.  It is the file whose subject is
--     those strings, so it contains every one of them; a sweep that included it
--     would report its own prose as a defect.  Same lesson GH #228 paid for --
--     an assertion about a string cannot run over the file that discusses the
--     string.

local tests = {}

local SELF = 'tests/test_level_premise_registry.lua'

-- The literal shapes the GH #84 zero takes in this repo.  Lua patterns.
local FINGERPRINTS = {
    '0 of 210',
    'level >= 20',
    'level 20 does not happen',
    'high%-water 19',
    '0 of 940',
    'ge20',
}

-- A site is corrected when its own comment block names the correction.
local MARKERS = { 'GH #235', '2026%-08%-27' }
local WINDOW = 14

-- tests/ files that still argue from the uncorrected premise, and who owes the
-- re-read.  Recorded 2026-08-27.  Removing a row means the verdict in it was
-- re-read, not that the sentence was deleted.
local PENDING = {
    ['tests/corpus_scale.lua']                     = 'harness -- states the ge20==0 policy itself (GH #236)',
    ['tests/test_level_gate_census.lua']           = 'harness/director -- the 22 GH #84 verdicts (GH #235)',
    ['tests/test_focus_build_level_legality.lua']  = 'hero -- scope claim argued from the zero',
    ['tests/test_lion_hex_talent_slot.lua']        = 'hero -- carries the lionhexaoe empty-domain reading (GH #166)',
    ['tests/test_wk_fact_anchor.lua']              = 'hero -- section 4 STRUCTURAL t20/t25 read census',
    ['tests/test_wk_roshan_mana_ceiling.lua']      = 'hero -- crossing-level tail argument (wkrosh)',
    ['tests/test_wk_bone_guard_thresholds.lua']    = 'hero -- untrained-stub-is-turbo-reality claim',
    ['tests/test_wk_bone_guard_talent_bypass.lua'] = 'hero -- talent6 bypass reachability',
    ['tests/test_wk_q_aim_preflight.lua']          = 'hero -- level distribution note',
}

local function read_lines(path)
    local fh = io.open(path, 'r')
    if not fh then return nil end
    local lines = {}
    for line in fh:lines() do lines[#lines + 1] = line end
    fh:close()
    return lines
end

local function ls(pattern)
    local out = {}
    local p = io.popen('ls ' .. pattern .. ' 2>/dev/null')
    if not p then return out end
    for path in p:lines() do out[#out + 1] = path end
    p:close()
    return out
end

--- { hits = n, uncorrected = n } for one file.
local function scan(path)
    local lines = read_lines(path)
    if not lines then return { hits = 0, uncorrected = 0 } end
    local hits, uncorrected = 0, 0
    for i, line in ipairs(lines) do
        local hit = false
        for _, fp in ipairs(FINGERPRINTS) do
            if line:find(fp) then hit = true; break end
        end
        if hit then
            hits = hits + 1
            local marked = false
            for j = math.max(1, i - WINDOW), math.min(#lines, i + WINDOW) do
                for _, m in ipairs(MARKERS) do
                    if lines[j]:find(m) then marked = true; break end
                end
                if marked then break end
            end
            if not marked then uncorrected = uncorrected + 1 end
        end
    end
    return { hits = hits, uncorrected = uncorrected }
end

local function sweep(paths)
    local out = {}
    for _, path in ipairs(paths) do
        if path ~= SELF then
            local r = scan(path)
            if r.hits > 0 then out[path] = r end
        end
    end
    return out
end

local function bots_paths()
    local out = {}
    for _, pat in ipairs({ 'bots/*.lua', 'bots/BotLib/*.lua', 'bots/FunLib/*.lua' }) do
        for _, p in ipairs(ls(pat)) do out[#out + 1] = p end
    end
    return out
end

-- ---------------------------------------------------------------------------
-- 1. The shipped deliverable carries no uncorrected copy of the premise.

tests['[hero] no file under bots/ still asserts the GH #84 level ceiling'] = function()
    local found = sweep(bots_paths())
    local bad, total = {}, 0
    for path, r in pairs(found) do
        total = total + r.hits
        if r.uncorrected > 0 then
            bad[#bad + 1] = path .. ' (' .. r.uncorrected .. ' of ' .. r.hits .. ')'
        end
    end
    table.sort(bad)
    assert(#bad == 0,
        'these shipped files quote the GH #84 level ceiling without saying it was '
        .. 'corrected: ' .. table.concat(bad, ', ') .. '. The claim may stay quoted '
        .. '-- the verdicts written on it are unreadable otherwise -- but the block '
        .. 'has to say what replaced it (name GH #235 or the 2026-08-27 correction '
        .. 'within ' .. WINDOW .. ' lines). bots/ is the Workshop deliverable: it is '
        .. 'the one place a reader meets this claim with no test beside it.')

    -- Anti-vacuum. If the sweep stops finding the premise at all, this test has
    -- become a test that a `ls` succeeded.  9 sites were corrected by hand on
    -- 2026-08-27 and a correction keeps the quote, so they must still be here.
    assert(total >= 9,
        'the premise sweep found only ' .. total .. ' quoted site(s) under bots/, '
        .. 'and 9 were corrected in place on 2026-08-27. Corrections KEEP the '
        .. 'quote, so this reads as a broken sweep or as somebody deleting the '
        .. 'premise instead of answering it -- which loses the reason the verdicts '
        .. 'above it are phrased the way they are.')
end

-- ---------------------------------------------------------------------------
-- 2. The tests/ debt is closed and can only shrink.

tests['[hero] no new test file joins the stale-premise registry'] = function()
    local found = sweep(ls('tests/*.lua'))
    local joined = {}
    for path, r in pairs(found) do
        if r.uncorrected > 0 and not PENDING[path] then
            joined[#joined + 1] = path .. ' (' .. r.uncorrected .. ')'
        end
    end
    table.sort(joined)
    assert(#joined == 0,
        table.concat(joined, ', ') .. ' argues from the GH #84 level ceiling and is '
        .. 'not on the registry in this file. That premise was retired on '
        .. '2026-08-27 (GH #235): a NEW argument built on it is being written '
        .. 'against a zero the batch harness produced, not against turbo. Either '
        .. 'stop leaning on it or add the row here with who owes the re-read.')
end

tests['[hero] the stale-premise registry shrinks or holds, never grows'] = function()
    local found = sweep(ls('tests/*.lua'))
    local still = 0
    local gone = {}
    for path in pairs(PENDING) do
        local r = found[path]
        if r and r.uncorrected > 0 then
            still = still + 1
        else
            gone[#gone + 1] = path
        end
    end
    table.sort(gone)
    assert(still <= 9,
        still .. ' registry files still argue from the retired premise; the '
        .. 'registered ceiling is 9. This number is a debt, so it may only fall.')

    -- When a row is genuinely re-read, delete it from PENDING in the same change.
    -- Leaving a settled row on the list makes the ceiling read as more debt than
    -- there is, which is the failure mode that makes a registry stop being read.
    if #gone > 0 then
        assert(false,
            'these registry rows no longer carry an uncorrected premise: '
            .. table.concat(gone, ', ') .. '. Good -- now delete them from PENDING '
            .. 'in this file and lower the ceiling, so the number keeps meaning '
            .. 'what it says.')
    end
end

return tests

-- [GH #365 / GH #229] The three "true reds" of GH #365 §3 are FALSE reds of the
-- same family as its §2 -- and the control that would have separated the two
-- classes was never run.
--
-- WHAT #365 PUBLISHED. 开工自检 reported 6 of 54 fast Lua detector files red on
-- the working tree. The issue split them: 3 "假红" (§2, `cannot open
-- bots/Customize/soak_side.lua`, green when run alone) and 3 "真红" (§3):
--
--   test_salvepool_missing_floor.lua:398  armed floor for the anchor pool: got 500, expected 445
--   test_salveyield_arbitration.lua:354   armed, the guard did not yield to an ally worse off on BOTH readings
--   test_tpreach_retreat_exclusion.lua:381 ARMED, d=705 <= reach 750 must veto the TP ...
--
-- The reason given for calling those three real was: "我特地把 gate 文件删干净
-- 后再复跑 -- 删了仍然红,因此排除了那条解释."
--
-- ⭐ THE CONTROL DOES NOT COVER THE HAZARD. `rm -f` BEFORE a run controls for a
-- STALE file left on the tree. It says nothing about a file deleted DURING the
-- run by another process. Those are two different failure modes of one shared
-- physical switch, and only the first one is closed by a pre-run delete. #365
-- §2 itself records that the round's mutation stand had M1/M2 spawning real
-- `routine_selfcheck.sh` processes (killed at 45s by PG_TIMEOUT) -- i.e. the
-- concurrency was still there when §3 was measured.
--
-- ⭐⭐ THE SIGNATURE IS THE UNARMED READING, BIT FOR BIT. Every one of the three
-- failures is an ARMED-leg assertion observing exactly the value its OWN file
-- asserts as the UNARMED value -- and those sibling unarmed cases are green in
-- the same run:
--
--   salvepool  got 500  == FLOOR, and the unarmed case asserts
--                          SalveSelfMissingFloor(890) == 500 for the anchor pool
--   salveyield "did not yield"  == the unarmed case's ShouldYieldSalveToAlly(...) == false
--   tpreach    armed gave false == the assertion THREE LINES ABOVE IT in the same
--                          case body: unarmed CanEnemyInterruptTpChannel == false
--
-- For "the assertion is wrong" to explain that, three independently written
-- files would each have to be wrong in a way that lands precisely on their own
-- file's unarmed value -- a value each file separately asserts and passes on.
-- One shared cause explains all three at once: the armed leg read no switch.
--
-- ⭐⭐⭐ POSITIVE CONTROL (strategy 2026-08-31, recorded in [recorded] below).
-- Running each file with a concurrent `rm -f bots/Customize/soak_side.lua` loop
-- reproduces all three reds BYTE FOR BYTE -- same file, same line, same message,
-- same `N tests, M failures` counts as #365 §3's table. Running each file alone,
-- sequentially, after one pre-run `rm -f`, all three are green (BARE_EXIT=0).
-- So the two classes of #365 are one class.
--
-- INDEPENDENT CORROBORATION, from the same leg that produced the reds. This
-- round's 开工自检 (banner read, not a piped exit code) printed
-- `54 tagged detector file(s), 0 failures` on the working tree -- i.e. the
-- fast Lua leg that reported "6 of 54 failing" 15 hours earlier reports all 54
-- green here. Its `selfcheck worst exit: 3` this round is `cadence
-- trunk-red(python)` -- `tests/test_rc_wrapper.py`, already filed flaky as
-- GH #364 -- and no Lua file at all.
--
-- WHY THIS FILE EXISTS RATHER THAN A CODE CHANGE. #365 §6.2 warns, correctly,
-- against "把红改成绿" by editing an expected value to the observed one. That is
-- exactly what a reader who believes §3 would do here: move salvepool's armed
-- floor 445 -> 500 and delete a real behaviour. This file pins the reason that
-- must not happen, so the ruling does not have to survive as prose.
--
-- SCOPE. Source-level census + recorded readings only. Zero `bots/` diff, zero
-- new gate id, zero AWS. The remediation (serialising or uniquifying the shared
-- switch) is GH #229's, not this file's -- [source S3] measures how far that
-- work has NOT got, so the day someone lands it this file goes red and gets
-- updated on purpose.

package.path = 'tests/?.lua;' .. package.path

local SIDE_PATH = 'bots/Customize/soak_side.lua'

local tests = {}

local function read_file(path)
    local f = assert(io.open(path, 'r'))
    local s = f:read('*a')
    f:close()
    return s
end

--- The body of ONE named test case, not the whole file.
--
-- [why] The first cut of S4 asserted only that a string occurred SOMEWHERE in
-- the subject file. A mutation (M5: flip the unarmed `== false` to something
-- else) SURVIVED, because `test_salveyield_arbitration.lua` asserts
-- `ShouldYieldSalveToAlly(bot, ally, true) == false` at FOUR sites and three of
-- them belong to unrelated cases. "Some case asserts false" is not the claim --
-- the claim is that the case whose value #365 published asserts it. Anchoring
-- to the case body is what makes the mutant die.
local function case_body(sBody, sNamePrefix)
    local nStart = sBody:find("tests['" .. sNamePrefix, 1, true)
    if nStart == nil then return nil end
    local nStop = sBody:find('\nend\n', nStart, true)
    if nStop == nil then return nil end
    return sBody:sub(nStart, nStop)
end

-- This census file names the switch path (and the words `flock` / `LOCK_EX`) in
-- its own prose and assertion messages, so it must exclude itself or S3 matches
-- the searcher instead of the searched.
local SELF = 'tests/test_soakside_shared_switch.lua'

--- Every tests/test_*.lua that names the shared switch path.
local function switch_files()
    local out = {}
    local p = assert(io.popen('ls tests/test_*.lua 2>/dev/null'))
    for path in p:lines() do
        local body = read_file(path)
        if path ~= SELF and body:find(SIDE_PATH, 1, true) then
            out[#out + 1] = { path = path, body = body }
        end
    end
    p:close()
    table.sort(out, function(a, b) return a.path < b.path end)
    return out
end

-- ---------------------------------------------------------------------------
-- [source S1] one literal path, shared by every gate test in the tree
-- ---------------------------------------------------------------------------

tests['[ratchet] [source S1] the switch is ONE global path, declared identically by every gate test'] = function()
    local files = switch_files()
    assert(#files >= 20, 'only ' .. #files .. ' files name ' .. SIDE_PATH ..
        ' -- the census lost its population, re-derive before trusting S2/S3')

    -- Every one of them spells the SAME literal. No file derives a
    -- process-unique path, so two concurrent lua5.1 processes running any two
    -- of these files contend for one inode.
    local nDeclared = 0
    for _, f in ipairs(files) do
        if f.body:find("local SIDE_PATH = '" .. SIDE_PATH .. "'", 1, true) then
            nDeclared = nDeclared + 1
        end
    end
    assert(nDeclared >= 20, 'only ' .. nDeclared .. ' of ' .. #files ..
        ' declare the shared literal; the rest reach it some other way')
end

-- ---------------------------------------------------------------------------
-- [source S2] every such process is BOTH a writer and a deleter
-- ---------------------------------------------------------------------------

tests['[ratchet] [source S2] the unarmed leg is itself a deleter -- the hazard is the suite, not a rogue process'] = function()
    local files = switch_files()
    local nBoth, missing = 0, {}
    for _, f in ipairs(files) do
        local bWrites  = f.body:find('io%.open%(%s*SIDE_PATH%s*,%s*[\'"]w[\'"]%s*%)') ~= nil
        local bDeletes = f.body:find('os%.remove%(%s*SIDE_PATH%s*%)') ~= nil
        if bWrites and bDeletes then
            nBoth = nBoth + 1
        elseif bWrites or bDeletes then
            missing[#missing + 1] = f.path
        end
    end
    assert(nBoth >= 20, 'only ' .. nBoth .. ' files both write and delete the shared switch')

    -- The load-bearing half: the DELETE is not confined to a cleanup that runs
    -- after the armed leg. Arming with `nil` (the unarmed leg) removes the file
    -- outright, so a file's own unarmed case is a deleter that can strip the
    -- armed leg of a DIFFERENT file running in a DIFFERENT process at the same
    -- instant. Pinned on the three #365 §3 subjects by name.
    for _, path in ipairs({
        'tests/test_salvepool_missing_floor.lua',
        'tests/test_salveyield_arbitration.lua',
    }) do
        local body = read_file(path)
        assert(body:find('if sCand == nil then\n%s*os%.remove%(SIDE_PATH%)') ~= nil,
            path .. ': the unarmed leg no longer deletes the shared switch -- ' ..
            'the #365 mechanism moved, re-measure it')
    end
end

-- ---------------------------------------------------------------------------
-- [source S3] nothing serialises the contention (this is the open work)
-- ---------------------------------------------------------------------------

tests['[ratchet] [source S3] no lock and no process-unique path exists anywhere in the suite'] = function()
    local files = switch_files()
    for _, f in ipairs(files) do
        assert(f.body:find('LOCK_EX', 1, true) == nil and f.body:find('flock', 1, true) == nil,
            f.path .. ' now takes a lock -- GH #229 landed; update this census on purpose')
        -- A process-unique switch would have to interpolate something into the
        -- path. The literal is a plain constant in every file today.
        assert(f.body:find("SIDE_PATH = '" .. SIDE_PATH .. "' %.%.") == nil,
            f.path .. ' now derives a per-process switch path -- GH #229 landed')
    end
end

-- ---------------------------------------------------------------------------
-- [source S4] each published "got" is that file's own unarmed assertion
-- ---------------------------------------------------------------------------

tests['[ratchet] [source S4] salvepool: the published `got 500` is the unarmed floor at the SAME pool'] = function()
    local body = read_file('tests/test_salvepool_missing_floor.lua')

    local nFloor = tonumber(body:match('local FLOOR%s*=%s*(%d+)'))
    assert(nFloor == 500, 'the shipped floor constant moved to ' .. tostring(nFloor))

    local nRatio = tonumber(body:match('local RATIO%s*=%s*([%d%.]+)'))
    local nMax   = tonumber(body:match('SUBJ_HP,%s*SUBJ_MAXHP,%s*SUBJ_LEVEL%s*=%s*%d+,%s*(%d+)'))
    assert(nRatio == 0.5 and nMax == 890,
        'the anchor pool/ratio moved: ratio=' .. tostring(nRatio) .. ' pool=' .. tostring(nMax))

    -- The number #365 published as "expected".
    assert(nMax * nRatio == 445, 'the armed expectation is no longer 445')

    -- The number #365 published as "got" -- and the UNARMED CASE asserts it, at
    -- this very pool, in the same file, and passes.
    local sUnarmed = case_body(body, '[gate] unarmed the floor is exactly the shipped amount')
    assert(sUnarmed ~= nil, 'the unarmed floor case is no longer findable by name')
    local sPools = sUnarmed:match('for _, nMax in ipairs%(({[^}]*})%)')
    assert(sPools ~= nil, 'the unarmed pool sweep is no longer inside that case')
    assert(sPools:find('%f[%d]' .. nMax .. '%f[%D]') ~= nil,
        'the unarmed sweep no longer covers the anchor pool ' .. nMax ..
        ' -- the "got 500 is the unarmed reading" identity is no longer pinned')
    assert(sUnarmed:find('J%.SalveSelfMissingFloor%(nMax%) == FLOOR') ~= nil,
        'the unarmed case no longer asserts the shipped floor over that sweep')

    -- ...and the ARMED case is the one #365 quoted, by line and by message.
    local sArmed = case_body(body, '[gate] armed and turbo the floor is the pool-relative one')
    assert(sArmed ~= nil, 'the armed floor case is no longer findable by name')
    assert(sArmed:find('armed floor for the anchor pool: got %s, expected %g', 1, true) ~= nil,
        'the armed message #365 published is gone -- re-derive the identity')
end

tests['[ratchet] [source S4] salveyield: the published "did not yield" is the unarmed value'] = function()
    local body = read_file('tests/test_salveyield_arbitration.lua')

    -- Anchored to the two case bodies by name. The file asserts `== false` on
    -- this call at four separate sites; only ONE of them is the gate's unarmed
    -- leg, and a whole-file search cannot tell them apart (see case_body).
    local sUnarmed = case_body(body, '[gate] unarmed, the guard is false on the anchor frame')
    assert(sUnarmed ~= nil, 'the unarmed gate case is no longer findable by name')
    assert(sUnarmed:find('J%.ShouldYieldSalveToAlly%(bot, ally, true%) == false') ~= nil,
        'the unarmed gate case no longer asserts false on the anchor frame')

    local sArmed = case_body(body, '[gate] armed on the anchor frame, the guard yields')
    assert(sArmed ~= nil, 'the armed gate case is no longer findable by name')
    -- Same frame, same arguments, same helper: the armed failure reports the
    -- unarmed case's asserted value.
    assert(sArmed:find('J%.ShouldYieldSalveToAlly%(bot, ally, true%) == true') ~= nil,
        'the armed case no longer asserts true on that same call')
    assert(sArmed:find('armed, the guard did not yield to an ally worse off on BOTH readings', 1, true) ~= nil,
        'the armed message #365 published is gone -- re-derive the identity')
end

tests['[ratchet] [source S4] tpreach: unarmed-false is asserted INSIDE the failing case body'] = function()
    local body = read_file('tests/test_tpreach_retreat_exclusion.lua')
    local sCase = body:match("tests%['%[drive D1%].-\nend\n")
    assert(sCase ~= nil, 'the [drive D1] case is no longer findable')

    local nUnarmed = sCase:find('J%.CanEnemyInterruptTpChannel%(bot%) == false')
    local nArmed   = sCase:find('J2%.CanEnemyInterruptTpChannel%(bot2%) == true')
    assert(nUnarmed and nArmed, 'the D1 case lost one of its two legs')
    assert(nUnarmed < nArmed,
        'the unarmed leg no longer precedes the armed one inside the same case')

    -- So the published red ("ARMED ... must veto") is the case asserting, a few
    -- lines below itself, that the same call on the same frame gives false when
    -- the switch is absent.
    assert(sCase:find('ARMED, d=705 <= reach 750 must veto the TP', 1, true) ~= nil,
        'the armed message #365 published is gone -- re-derive the identity')
end

-- ---------------------------------------------------------------------------
-- [recorded] the positive control, and the clean control beside it
-- ---------------------------------------------------------------------------
--
-- Both legs were run on 46317e40 (== origin/main at the time), lua5.1, one file
-- per process, `rm -f bots/Customize/soak_side.lua` before each.
--
--   clean leg: `lua5.1 tests/run_tests.lua <filter>`, nothing else running
--   race  leg: same, with `( for i in $(seq 1 60000); do rm -f <SIDE_PATH>; done ) &`
--
-- The exit codes were read BARE (no pipe) -- evidence-discipline rule 3, whose
-- last two sites were this stream's own rounds 0SGN and 0SIB.

local RECORDED = {
    { file = 'test_salvepool_missing_floor.lua',
      clean_exit = 0, clean_tests = 19, clean_fails = 0,
      race_exit  = 1, race_tests  = 19, race_fails  = 1,
      published_tests = 19, published_fails = 1 },
    { file = 'test_salveyield_arbitration.lua',
      clean_exit = 0, clean_tests = 29, clean_fails = 0,
      race_exit  = 1, race_tests  = 29, race_fails  = 2,
      published_tests = 29, published_fails = 2 },
    { file = 'test_tpreach_retreat_exclusion.lua',
      clean_exit = 0, clean_tests = 8, clean_fails = 0,
      race_exit  = 1, race_tests  = 8, race_fails  = 1,
      published_tests = 8, published_fails = 1 },
}

tests['[ratchet] [recorded] the race leg reproduces #365 §3 exactly; the clean leg is green'] = function()
    for _, r in ipairs(RECORDED) do
        assert(r.clean_exit == 0 and r.clean_fails == 0,
            r.file .. ': the clean control is not green -- the ruling does not hold')
        assert(r.race_exit == 1 and r.race_fails > 0,
            r.file .. ': the race control did not go red -- the mechanism is not shown')
        -- The reproduction is not "also red", it is the SAME red: same case
        -- count and same failure count as the table #365 §3 published.
        assert(r.race_tests == r.published_tests and r.race_fails == r.published_fails,
            r.file .. ': reproduction ' .. r.race_tests .. '/' .. r.race_fails ..
            ' does not match #365 §3 ' .. r.published_tests .. '/' .. r.published_fails)
        assert(r.clean_tests == r.race_tests,
            r.file .. ': the two legs did not run the same case set')
    end
    assert(#RECORDED == 3, 'the #365 §3 table has three rows')
end

-- ---------------------------------------------------------------------------
-- [limit] what this file does NOT establish
-- ---------------------------------------------------------------------------

tests['[limit] the honest bounds of the ruling'] = function()
    -- (1) A reproduction under FORCED contention shows the mechanism is
    --     sufficient. It does not prove the director's specific 13:xxZ run was
    --     contended -- that is an inference from #365 §2's own account of the
    --     PG_TIMEOUT-killed selfchecks, plus the fact that three sequential
    --     clean runs on the same tree are green.
    -- (2) The clean leg is three runs, not a soak. A defect that reds at, say,
    --     1-in-50 would not be excluded by it. What IS excluded is a
    --     deterministic assertion error, because a deterministic one cannot be
    --     green three times.
    -- (3) This file says nothing about whether `salvepool` / `salveyield` /
    --     `tpreach` are GOOD levers. It rules only on why their tests were red.
    -- (4) The remediation is not here. S3 measures that no lock and no
    --     per-process path exists; landing either is GH #229's work and will
    --     turn S3 red on purpose.
    -- (5) The full single-process suite was not run (~100 min, GH #124), so the
    --     "only these three" bound is the 54-file fast leg's, not the tree's.
    assert(true)
end

return tests

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

--- The owner module that ALL of these files delegate to as of 2026-09-03
--- (hero backlog `-77` + `-78`).  A migrated file no longer contains the
--- literal path, so a census that only greps the literal would silently LOSE it
--- from its own population -- which is how S1 first went red on this change:
--- 22 -> 18, read as "the census lost its population" when nothing had been
--- lost at all.  That trap is now total rather than partial: grepping the
--- literal alone would find ZERO of the twenty-two.
local OWNER = 'tests/mock/soak_side.lua'

--- Every tests/test_*.lua that reaches the shared switch -- by naming the
--- literal path (a RAW copy) or by requiring the owner module (MIGRATED).
local function switch_files()
    local out = {}
    local p = assert(io.popen('ls tests/test_*.lua 2>/dev/null'))
    for path in p:lines() do
        local body = read_file(path)
        local bMigrated = body:find("require('mock.soak_side')", 1, true) ~= nil
        if path ~= SELF and (body:find(SIDE_PATH, 1, true) or bMigrated) then
            out[#out + 1] = { path = path, body = body, migrated = bMigrated }
        end
    end
    p:close()
    table.sort(out, function(a, b) return a.path < b.path end)
    return out
end

--- Split the population.  A migrated file is one that requires the owner AND
--- has stopped opening the path itself; a file that does both is still raw
--- (it kept a copy), and saying so is the point of the count.
local function partition()
    local raw, migrated = {}, {}
    for _, f in ipairs(switch_files()) do
        local bWrites = f.body:find('io%.open%(%s*SIDE_PATH%s*,%s*[\'"]w[\'"]%s*%)') ~= nil
        if f.migrated and not bWrites then
            migrated[#migrated + 1] = f
        else
            raw[#raw + 1] = f
        end
    end
    return raw, migrated
end

--- The hazard the census measures, as a number that must never grow.  It is
--- ZERO as of 2026-09-03 (hero backlog `-78` closed): every test file that
--- reaches the shared switch now goes through the owner.  The migration ran in
--- four batches -- the four with an observed red (test_cm_pos5_boots, GH #417's
--- subject, and the three GH #365 §3 subjects), the six uniform-shape gate
--- tests (axe_blink_build, corefarm, deathzone, nopush, tpsafe, slardar_tp),
--- the five that carried a direct read of the switch as well (abil1st,
--- abilanc, aimguard, replay_212636, soak_cand_ref -- the last of these is why
--- the owner grew `arm_body`), the two of 2026-09-02T22:54Z (aegis_grouping,
--- tpreach_band), and finally the five that were held back ON PURPOSE because
--- they were the live carriers of S2's own reading (bbfight, bbrespawn,
--- bbshort, pollyhp, salveally).
---
--- Zero is a real ceiling, not a placeholder: a twenty-third gate test that
--- copies the three unchecked lines instead of requiring the owner reds here,
--- and there is no longer a "but some files still do it that way" to point at.
local RAW_CEILING = 0

--- ...and the same number from the other side.  A file may leave the RAW set
--- only by joining this one, so a "migration" that merely deletes the copy
--- without delegating cannot pass both.
local MIGRATED_FLOOR = 22

--- [archive] The reading S2 used to take off the live tree, taken one last time
--- on `cd56e50` (== origin/main when the last five were migrated) and frozen
--- here because migrating the carriers is what makes it unrepeatable.  This is
--- the mechanism of GH #365 §3 stated as a measurement: five test files whose
--- UNARMED leg was itself an unconditional `os.remove` of the one global path,
--- i.e. five processes that delete other processes' switches while claiming
--- only to be measuring the shipped tree.
---
--- Kept as data rather than prose so the identity below (`raw + migrated` is
--- conserved across the change) is checkable rather than assertable.
local ARCHIVED_DELETERS = {
    at_commit = 'cd56e50',
    raw = 5, migrated = 17, deleters = 5,
    files = { 'tests/test_bbfight_turbo_respawn_ceiling.lua',
              'tests/test_bbrespawn_double_subtract.lua',
              'tests/test_bbshort_turbo_respawn_floor.lua',
              'tests/test_pollyhp_getter_axis.lua',
              'tests/test_salveally_missing_floor.lua' },
}

-- ---------------------------------------------------------------------------
-- [source S1] one literal path, shared by every gate test in the tree
-- ---------------------------------------------------------------------------

tests['[ratchet] [source S1] the switch is ONE global path, declared identically by every gate test'] = function()
    local files = switch_files()
    assert(#files >= 20, 'only ' .. #files .. ' files name ' .. SIDE_PATH ..
        ' -- the census lost its population, re-derive before trusting S2/S3')

    -- Every one of them ends up on the SAME inode. No file derives a
    -- process-unique path, so two concurrent lua5.1 processes running any two
    -- of these files contend for one path -- which is still true after the
    -- 2026-09-02 migration, because the owner module holds that same literal
    -- and the migrated files take it from there (`SIDE_PATH = ss.PATH`).
    assert(read_file(OWNER):find("local PATH = '" .. SIDE_PATH .. "'", 1, true) ~= nil,
        OWNER .. ' no longer declares the shared literal -- if it now derives a '
        .. 'per-process path, GH #229 landed and this whole census is stale')

    local nReaches = 0
    for _, f in ipairs(files) do
        if f.body:find("local SIDE_PATH = '" .. SIDE_PATH .. "'", 1, true)
            or f.body:find('SIDE_PATH = ss%.PATH')
            or f.migrated then
            nReaches = nReaches + 1
        end
    end
    assert(nReaches >= 20, 'only ' .. nReaches .. ' of ' .. #files ..
        ' reach the shared literal; the rest reach it some other way')
end

-- ---------------------------------------------------------------------------
-- [source S2] every such process WAS both a writer and a deleter -- archived
-- ---------------------------------------------------------------------------
--
-- The hazard was the suite, not a rogue process: each of these files wrote the
-- one global path and, on its unarmed leg, deleted it unconditionally. As of
-- 2026-09-03 none of them does, so this section holds the archived reading and
-- ratchets the shape at zero in both directions.

tests['[ratchet] [source S2] the unarmed leg was itself a deleter -- archived at zero, and the shape may not come back'] = function()
    local raw, migrated = partition()

    local nBoth = 0
    for _, f in ipairs(raw) do
        local bWrites  = f.body:find('io%.open%(%s*SIDE_PATH%s*,%s*[\'"]w[\'"]%s*%)') ~= nil
        local bDeletes = f.body:find('os%.remove%(%s*SIDE_PATH%s*%)') ~= nil
        if bWrites and bDeletes then nBoth = nBoth + 1 end
    end

    -- MONOTONIC, and this is the whole point of keeping the number: a new gate
    -- test must delegate to the owner rather than copy the three unchecked
    -- lines a twenty-third time. Going DOWN is the work landing; going UP is a
    -- regression that no other test in the tree would notice.
    assert(nBoth <= RAW_CEILING, nBoth .. ' files carry their own unchecked '
        .. 'write+delete of the shared switch, up from ' .. RAW_CEILING
        .. '. A new one copied the shape instead of requiring ' .. OWNER
        .. ' -- migrate it, do not raise this ceiling.')
    assert(#migrated >= MIGRATED_FLOOR, 'only ' .. #migrated
        .. ' files delegate to ' .. OWNER .. ', down from ' .. MIGRATED_FLOOR
        .. '; all twenty-two were migrated for hero backlog `-77`/`-78` and '
        .. 'must stay migrated')

    -- The load-bearing half, and the ONE place its wording changed on
    -- 2026-09-03. Until then this asserted `nDeleters >= 1` off the live tree:
    -- the DELETE is not confined to a cleanup after the armed leg -- arming
    -- with `nil` (the unarmed leg) removed the file outright, so a file's own
    -- unarmed case was a deleter that could strip the armed leg of a DIFFERENT
    -- file in a DIFFERENT process at the same instant.
    --
    -- ⭐ That assertion was a hostage. It could only stay green while at least
    -- one carrier of the defect survived, so the last migration would have made
    -- this census red BY FIXING THE THING IT DESCRIBES -- and the cheap way out
    -- of that red is to delete the assertion, i.e. to lose the reading. So the
    -- reading is archived above (measured, not recalled) and the live half is
    -- flipped to the other direction: the shape must now be GONE, everywhere.
    local nDeleters = 0
    for _, f in ipairs(raw) do
        if f.body:find('if sCand == nil then\n%s*os%.remove%(SIDE_PATH%)') ~= nil then
            nDeleters = nDeleters + 1
        end
    end
    assert(#ARCHIVED_DELETERS.files == ARCHIVED_DELETERS.deleters,
        'the archived deleter list and its count disagree')
    -- The carriers did not vanish, they crossed from one side of the partition
    -- to the other, so the population may GROW but never SHRINK below what the
    -- archive counted.
    --
    -- ⚠️ This was written as an equality first, and the equality was WRONG in
    -- the one direction that matters: a new gate test that delegates to the
    -- owner -- the exact behaviour this whole census exists to push people
    -- towards -- moved the population 22 -> 23 and reded it (measured, M5). The
    -- cheap way out of THAT red is to bump the archived number, which corrupts
    -- an archive whose only job is to be unbumpable. A floor is what was meant.
    local nArchived = ARCHIVED_DELETERS.raw + ARCHIVED_DELETERS.migrated
    assert(#raw + #migrated >= nArchived,
        'the population shrank from ' .. nArchived .. ' to ' .. (#raw + #migrated)
        .. ' files -- subjects were deleted rather than migrated, so neither '
        .. 'ratchet above means what it says')
    for _, sPath in ipairs(ARCHIVED_DELETERS.files) do
        local bStillThere = false
        for _, f in ipairs(migrated) do
            if f.path == sPath then bStillThere = true end
        end
        assert(bStillThere, sPath .. ' was one of the five archived deleters '
            .. 'and is no longer in the migrated set -- it was deleted or '
            .. 'renamed rather than migrated, and the archive above now cites a '
            .. 'file nobody can check')
    end

    -- ...and NO file, on either side, still carries the shape. The migrated
    -- ones must not delete the switch themselves at all: a migration that kept
    -- the delete would leave the hazard in place while reading as progress.
    assert(nDeleters == 0, nDeleters .. ' file(s) still delete the shared '
        .. 'switch on their unarmed leg. That shape is the GH #365 §3 mechanism '
        .. 'and it was measured to zero on ' .. ARCHIVED_DELETERS.at_commit
        .. '; route the unarmed leg through ' .. OWNER .. "'s assert_clean "
        .. 'instead of re-introducing it')
    for _, f in ipairs(migrated) do
        assert(f.body:find('os%.remove%(%s*SIDE_PATH%s*%)') == nil,
            f.path .. ' delegates to ' .. OWNER .. ' but still deletes the '
            .. 'shared switch itself, so it is still a deleter for every other '
            .. 'process')
    end

    -- Where the property lives now. It used to be distributed across twenty-two
    -- copies and countable; it is implemented once, so it has to be PINNED once
    -- -- otherwise "no test file deletes the switch" stays true while the owner
    -- every one of them calls does it on their behalf.
    local sOwner = read_file(OWNER)
    local sUnarmed = sOwner:match('function M%.with_candidate.-\nend\n')
    assert(sUnarmed ~= nil, OWNER .. ' no longer defines with_candidate')
    assert(sUnarmed:find('M%.assert_clean') ~= nil,
        OWNER .. "'s unarmed leg no longer asserts the switch is absent")
    assert(sUnarmed:find('os%.remove') == nil,
        OWNER .. "'s unarmed leg deletes the switch again -- the hazard moved "
        .. 'from twenty-two copies into the one place they all call, which is '
        .. 'strictly worse than where it started')
end

-- ---------------------------------------------------------------------------
-- [source S3] nothing serialises the contention (this is the open work)
-- ---------------------------------------------------------------------------

tests['[ratchet] [source S3] no lock and no process-unique path exists anywhere in the suite'] = function()
    local files = switch_files()
    files[#files + 1] = { path = OWNER, body = read_file(OWNER) }
    for _, f in ipairs(files) do
        assert(f.body:find('LOCK_EX', 1, true) == nil and f.body:find('flock', 1, true) == nil,
            f.path .. ' now takes a lock -- GH #229 landed; update this census on purpose')
        -- A process-unique switch would have to interpolate something into the
        -- path. The literal is a plain constant in every file today.
        assert(f.body:find("PATH = '" .. SIDE_PATH .. "' %.%.") == nil,
            f.path .. ' now derives a per-process switch path -- GH #229 landed')
    end
end

-- ---------------------------------------------------------------------------
-- [source S5] the owner turns the race into a NAMED failure -- run, not read
-- ---------------------------------------------------------------------------
--
-- S1-S3 are a source census: they say the contention is still there. S5 is the
-- part that has to be executed, because the claim is about which of two errors
-- comes out when both are true at once. Under a concurrent `rm`, the armed leg
-- produces the unarmed value AND the switch is gone; #365 §3 spent a round
-- arguing about the first because nothing reported the second.

tests['[owner] a switch removed under the case body outranks the assertion it caused'] = function()
    local ss = require('mock.soak_side')
    ss.assert_clean('S5 precondition')

    local ok, err = pcall(ss.with_candidate, 'censuscand', function()
        os.remove(ss.PATH)                       -- the concurrent process, inlined
        error('THE UNARMED VALUE WOULD BE REPORTED HERE', 0)
    end)
    assert(not ok, 'the owner swallowed a failing case body')
    assert(tostring(err):find('was REMOVED under this case', 1, true) ~= nil,
        'the owner reported the assertion instead of the removed switch, so the '
        .. '#365 §3 reading is back: ' .. tostring(err))
    assert(ss.read() == nil, 'the owner left a switch behind after the race')
end

tests['[owner] it refuses to clobber a switch it did not write'] = function()
    local ss = require('mock.soak_side')
    ss.assert_clean('S5 precondition')

    local f = assert(io.open(ss.PATH, 'w'))
    f:write("return { side = 'radiant', cand = 'stranger' }\n")
    f:close()

    local okArm, errArm = pcall(ss.arm, 'censuscand')
    local sStill = ss.read()
    os.remove(ss.PATH)

    assert(not okArm, 'the owner overwrote a switch another process was holding')
    assert(tostring(errArm):find('did not write it', 1, true) ~= nil,
        'the refusal does not say whose switch it is: ' .. tostring(errArm))
    assert(sStill ~= nil and sStill:find('stranger', 1, true) ~= nil,
        "the stranger's switch was clobbered anyway")
end

--- [why this is a separate case] The clobber case above cannot cover disarm at
--- all: its `arm` FAILS, so nothing is owned, and `disarm` returns at its first
--- line without reaching the ownership check. A mutation that made disarm
--- delete unconditionally survived that case 10/10 green. The subject has to be
--- a span this process really did arm.
tests['[owner] disarm stands down on bytes that changed under it'] = function()
    local ss = require('mock.soak_side')
    ss.assert_clean('S5 precondition')

    ss.arm('censuscand')
    local f = assert(io.open(ss.PATH, 'w'))     -- another process, between our
    f:write("return { side = 'dire', cand = 'stranger' }\n")  -- write and our
    f:close()                                                 -- cleanup
    local okDis, errDis = pcall(ss.disarm)
    local sLeft = ss.read()
    os.remove(ss.PATH)

    assert(okDis, 'disarm raised instead of standing down: ' .. tostring(errDis))
    assert(sLeft ~= nil and sLeft:find('stranger', 1, true) ~= nil,
        "disarm deleted a switch this process did not write -- that is exactly "
        .. "how the other process's failure becomes unattributable, and it is "
        .. 'the defect this whole census exists to describe')
end

--- [why this is a separate case] Nothing else in the suite makes the WRITE
--- fail, and a write that silently does not land is the third member of the
--- family (short write, full disk, read-only tree). A mutation that dropped the
--- read-back survived every other case here.
tests['[owner] a write that does not land is a named failure, not an unarmed reading'] = function()
    local ss = require('mock.soak_side')
    ss.assert_clean('S5 precondition')

    local fnRealOpen = io.open
    io.open = function(sPath, sMode)
        if sPath == ss.PATH and sMode == 'w' then
            -- succeeds at every step and writes nothing: exactly what a short
            -- write looks like to code that drops the return values.
            return { write = function() return true end,
                     close = function() return true end }
        end
        return fnRealOpen(sPath, sMode)
    end
    local ok, err = pcall(ss.arm, 'censuscand')
    io.open = fnRealOpen
    os.remove(ss.PATH)

    assert(not ok, 'the owner called the candidate armed without checking the '
        .. 'bytes, so every gate below it would read "did not fire"')
    assert(tostring(err):find('does not hold what we just wrote', 1, true) ~= nil,
        'the failure does not name the unlanded write: ' .. tostring(err))
end

--- [why these exist] `arm_body` is a SECOND way into the write (hero backlog
--- `-78`, for test_soak_cand_ref_gate.lua, whose subject is the gate resolver
--- itself and which must write shapes `M.body` cannot express).  A second
--- entry point is exactly how a checked helper grows an unchecked copy back:
--- the four cases above all drive `arm`, so a mutation that gave `arm_body`
--- its own three unchecked lines would leave every one of them green.  These
--- are separate cases on purpose -- a single case asserting "refuses AND reads
--- back AND orders the removal first" would fail at its first assertion and
--- cover one of the three, which is the M4 lesson from 2026-09-02.

tests['[owner] arm_body writes the bytes VERBATIM -- that is the whole reason it exists'] = function()
    local ss = require('mock.soak_side')
    ss.assert_clean('S5 precondition')

    -- The shape `M.body` cannot express: a closed gate. If arm_body quietly
    -- routed through `body()` the file would say `cand = 'return {...}'`.
    local sBody = 'return { side = false, cand = false }'
    ss.arm_body(sBody)
    local sGot = ss.read()
    ss.disarm()

    assert(sGot == sBody .. '\n', 'arm_body did not put its own bytes on disk; '
        .. 'got ' .. string.format('%q', tostring(sGot)))
end

tests['[owner] arm_body proves its bytes landed, exactly as arm does'] = function()
    local ss = require('mock.soak_side')
    ss.assert_clean('S5 precondition')

    local fnRealOpen = io.open
    io.open = function(sPath, sMode)
        if sPath == ss.PATH and sMode == 'w' then
            -- Succeeds at every step and writes nothing: a short write, as it
            -- looks to code that drops the return values.
            return { write = function() return true end,
                     close = function() return true end }
        end
        return fnRealOpen(sPath, sMode)
    end
    local ok, err = pcall(ss.arm_body, "return { side = 'radiant', cand = 'x' }")
    io.open = fnRealOpen
    os.remove(ss.PATH)

    assert(not ok, 'arm_body called the gate armed without checking the bytes, '
        .. 'so every "the gate is shut" case in test_soak_cand_ref_gate.lua '
        .. 'would pass on an unarmed tree -- which is what they all assert')
    assert(tostring(err):find('does not hold what we just wrote', 1, true) ~= nil,
        'the failure does not name the unlanded write: ' .. tostring(err))
end

tests['[owner] arm_body refuses to clobber a switch it did not write'] = function()
    local ss = require('mock.soak_side')
    ss.assert_clean('S5 precondition')

    local f = assert(io.open(ss.PATH, 'w'))
    f:write("return { side = 'radiant', cand = 'stranger' }\n")
    f:close()

    local okArm, errArm = pcall(ss.arm_body, 'return { side = false, cand = false }')
    local sStill = ss.read()
    os.remove(ss.PATH)

    assert(not okArm, 'arm_body overwrote a switch another process was holding')
    assert(tostring(errArm):find('did not write it', 1, true) ~= nil,
        'the refusal does not say whose switch it is: ' .. tostring(errArm))
    assert(sStill ~= nil and sStill:find('stranger', 1, true) ~= nil,
        "the stranger's switch was clobbered anyway")
end

tests['[owner] with_body puts the removed switch ahead of the assertion it caused'] = function()
    local ss = require('mock.soak_side')
    ss.assert_clean('S5 precondition')

    local ok, err = pcall(ss.with_body, "return { side = 'radiant', cand = 'x' }",
        function()
            os.remove(ss.PATH)                   -- the concurrent process, inlined
            error('THE UNARMED VALUE WOULD BE REPORTED HERE', 0)
        end)
    assert(not ok, 'with_body swallowed a failing case body')
    assert(tostring(err):find('was REMOVED under this case', 1, true) ~= nil,
        'with_body reported the assertion instead of the removed switch, so a '
        .. 'second entry point re-opened the #365 §3 reading: ' .. tostring(err))
    assert(ss.read() == nil, 'with_body left a switch behind after the race')
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

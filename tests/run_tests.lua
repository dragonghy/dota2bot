-- Minimal test runner. Usage (from repo root):
--   lua5.1 tests/run_tests.lua            # run all tests/test_*.lua
--   lua5.1 tests/run_tests.lua smoke      # run tests whose filename matches
--
-- A test file returns a table of { ['test name'] = function() ... end }.
-- Assertions: error() / assert() with messages; helpers in tests/assertions.lua.
--
-- The filter matches a FILENAME SUBSTRING, not a path.  `run_tests.lua smoke`
-- works; `run_tests.lua tests/test_smoke_load.lua` matches nothing.
--
-- [director 20260826, GH #200] A RUN THAT EXECUTED ZERO TEST BODIES EXITS
-- NON-ZERO.  Until this guard, `run_tests.lua tests/test_smoke_load.lua` (path
-- used as filter) printed `0 tests, 0 failures, 190 files skipped by filter`
-- and exited 0 -- indistinguishable at the exit code from a real pass, which
-- is how the batch desk's pre-launch "every hero file loads" gate came to buy
-- an assumption instead of a fact before a ~$2.1 wave.  The failure direction
-- is the dangerous one: a gate that proves nothing is silent about it, and no
-- counter raises its hand.  Same family as the selfcheck's `SKIP (no lua5.1)`
-- (GH #171): a line that does not lift the exit code.
--   Note the sibling defect this does NOT fix: `lua5.1 tests/test_x.lua` run
-- directly returns the test TABLE without calling anything (exit 0, zero
-- output).  Fixing that per-file would be 190 copies of a rule this runner
-- enforces once, so the runner is the only supported entry point.

-- [director 20260826, GH #216] A FAILURE PRINTS ITS NAME AND TEXT AT THE MOMENT
-- IT HAPPENS, not only in the end-of-run block.  Until this, the only way to
-- learn WHICH case is red was to wait out the whole run -- ~100min (GH #124),
-- dominated by a handful of slow files -- because `failures[]` was printed
-- after the loop.  That tied the diagnosis cost of "the suite is red" to the
-- slowest file in the suite, and the two reds standing on trunk when this was
-- written (#216) were reported WITHOUT their names for exactly that reason:
-- two independent full runs were still going when the finder had to hand off.
-- Two details are load-bearing, not decoration:
--   * the write is FLUSHED.  stdout to a pipe or a file is block-buffered, and
--     a ~100min run is always redirected somewhere -- an unflushed "immediate"
--     print is not immediate at all, it just joins the same end-of-run blob by
--     another route.  Flushing on failure (not on every dot) keeps the cost off
--     the passing path.
--   * the end-of-run block STAYS.  It is the one place the failures appear
--     together, and a reader who scrolls to the bottom must still find them
--     all.  The immediate line is tagged `FAIL[n]` so a duplicate is legible
--     as the same failure seen twice, not as two failures.
local filter = arg[1]

local root = arg[0]:match('^(.*)/[^/]+$') or 'tests'

local failures = {}

-- Record a failure and announce it immediately; see the header note (GH #216).
-- `marker` keeps the progress stream's own distinction intact: `E` is a file
-- that never got as far as running a test body, `F` is a test body that ran and
-- failed.  Collapsing the two would lose the difference at a glance.
local function record_failure(marker, name, err)
    failures[#failures + 1] = { name = name, err = err }
    io.write(marker, '\n')
    io.stdout:write(string.format('FAIL[%d]: %s\n', #failures, name))
    io.stdout:write('      ', (err:gsub('\n', '\n      ')), '\n')
    io.stdout:flush()
end

-- enumerate tests/test_*.lua without LuaFileSystem
local function list_test_files()
    local files = {}
    local p = io.popen('ls "' .. root .. '"')
    for line in p:lines() do
        if line:match('^test_.*%.lua$') then files[#files + 1] = line end
    end
    p:close()
    table.sort(files)
    return files
end

local total, failed, skipped, matched = 0, 0, 0, 0

for _, file in ipairs(list_test_files()) do
    if not filter or file:find(filter, 1, true) then
        matched = matched + 1
        local chunk, load_err = loadfile(root .. '/' .. file)
        if not chunk then
            failed = failed + 1
            total = total + 1
            record_failure('E', file, 'load error: ' .. tostring(load_err))
        else
            local ok, tests = pcall(chunk)
            if not ok then
                failed = failed + 1
                total = total + 1
                record_failure('E', file, 'setup error: ' .. tostring(tests))
            elseif type(tests) ~= 'table' then
                -- [director 2026-09-01, GH #387] A FILE THAT BREAKS THE CONTRACT
                -- FAILS AS ONE FILE.  `pairs(tests)` below sits OUTSIDE the
                -- pcall above, so a chunk returning nil did not fail the file --
                -- it killed the RUNNER, mid-suite, with a traceback and no
                -- summary line.  Measured: tests/test_cm_ult_reach_meter_domain
                -- .lua (a self-running script that printed its own `8 run, 0
                -- failed` and returned nothing) landed on origin/main in
                -- afd8fbf8 and sorts 48th of 277, so from that commit iron rule
                -- 6's dynamic half stopped after 48 files and ~229 files (83%)
                -- went unrun on every stream, every trigger.
                --
                -- The blast radius is the defect, not the bad file: one file's
                -- mistake must never be able to delete the other 229 files'
                -- results.  Same family as GH #200 (a run that proved nothing
                -- exiting 0) one turn further -- there the gate was silent about
                -- proving nothing; here it is loud about the wrong object.
                failed = failed + 1
                total = total + 1
                record_failure('E', file, 'contract error: the file returned '
                    .. type(tests) .. ', not a table of tests. A test file ends '
                    .. 'with `return tests`; it does not run itself (the runner '
                    .. 'prints, counts and reports for every file).')
            else
                local names = {}
                for name in pairs(tests) do names[#names + 1] = name end
                table.sort(names)
                for _, name in ipairs(names) do
                    total = total + 1
                    local ok2, err = pcall(tests[name])
                    if ok2 then
                        io.write('.')
                    else
                        failed = failed + 1
                        record_failure('F', file .. ' :: ' .. name, tostring(err))
                    end
                end
            end
        end
    else
        skipped = skipped + 1
    end
end
io.write('\n\n')

for _, f in ipairs(failures) do
    io.stdout:write('FAIL: ', f.name, '\n')
    io.stdout:write('      ', (f.err:gsub('\n', '\n      ')), '\n')
end

io.stdout:write(string.format('%d tests, %d failures%s\n', total, failed,
    skipped > 0 and (', ' .. skipped .. ' files skipped by filter') or ''))

-- Zero test bodies executed is never a pass -- see the header note (GH #200).
-- Named separately because the two causes need different fixes: a filter that
-- selected no file is a typo at the call site; a file that ran but defined no
-- test is a defect in that file.
if matched == 0 then
    io.stdout:write(string.format(
        'NO TESTS RAN -- filter %q matched 0 of %d files. The filter is a '
        .. 'FILENAME SUBSTRING, not a path.\n', tostring(filter), skipped))
    os.exit(2)
elseif total == 0 then
    io.stdout:write(string.format(
        'NO TESTS RAN -- %d file(s) matched but defined 0 tests between them.\n',
        matched))
    os.exit(2)
end

os.exit(failed == 0 and 0 or 1)

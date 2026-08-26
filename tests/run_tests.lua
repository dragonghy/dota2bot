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

local filter = arg[1]

local root = arg[0]:match('^(.*)/[^/]+$') or 'tests'

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
local failures = {}

for _, file in ipairs(list_test_files()) do
    if not filter or file:find(filter, 1, true) then
        matched = matched + 1
        local chunk, load_err = loadfile(root .. '/' .. file)
        if not chunk then
            failed = failed + 1
            total = total + 1
            failures[#failures + 1] = { name = file, err = 'load error: ' .. tostring(load_err) }
            io.write('E')
        else
            local ok, tests = pcall(chunk)
            if not ok then
                failed = failed + 1
                total = total + 1
                failures[#failures + 1] = { name = file, err = 'setup error: ' .. tostring(tests) }
                io.write('E')
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
                        failures[#failures + 1] = { name = file .. ' :: ' .. name, err = tostring(err) }
                        io.write('F')
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

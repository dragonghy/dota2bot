-- Minimal test runner. Usage (from repo root):
--   lua5.1 tests/run_tests.lua            # run all tests/test_*.lua
--   lua5.1 tests/run_tests.lua smoke      # run tests whose filename matches
--
-- A test file returns a table of { ['test name'] = function() ... end }.
-- Assertions: error() / assert() with messages; helpers in tests/assertions.lua.

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

local total, failed, skipped = 0, 0, 0
local failures = {}

for _, file in ipairs(list_test_files()) do
    if not filter or file:find(filter, 1, true) then
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
os.exit(failed == 0 and 0 or 1)

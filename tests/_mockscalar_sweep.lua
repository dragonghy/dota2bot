-- Heavy corpus sweep for tests/test_mockscalar_return_shape.lua, run as a
-- SUBPROCESS (the backlog 0q rule: a full-corpus drive that rebuilds jmz_func
-- once per hero-frame must not run on run_tests.lua's long-lived heap). The
-- leading underscore keeps run_tests.lua from globbing it.
--
-- WHAT IS MEASURED.  tests/mock/bot_api.lua answers an unknown CamelCase method
-- by PREFIX: `^Is/Has/Can/Was` -> false, `^GetNearby` -> {}, then a catch-all
-- `^Get` -> 0.  That last line is not a default, it is a TYPE CLAIM: it says
-- "every engine getter this mock has not been told about returns a scalar".
-- Where the engine returns a Vector, a table or a handle, the claim is false in
-- one of two ways, and only one of them is loud:
--   * LOUD   -- the caller indexes/iterates/method-calls the 0 and the frame
--              RAISES.  A sweep that scores a raise the same as a measured "no"
--              then deletes those frames from its own denominator silently
--              (measured on this corpus at 75/1012 for one such name; see
--              tests/_midsupfar_sweep.lua's header and GH #492).
--   * QUIET  -- the caller only compares the 0 against a number, and the frame
--              answers with a world nobody declared.
-- This sweep measures the FIRST HALF of the pricing: which `Get*` names that
-- shipped code under bots/ actually calls are answered by that catch-all on
-- REAL fixture units, and which of them are the special-cased exceptions the
-- mock already carries (GetLocation, GetIncomingTrackingProjectiles,
-- ^GetNearby, the handle_getters nil list).
--
-- WHY IT PROBES INSTEAD OF READING THE MOCK.  Whether a name reaches the
-- catch-all is not a property of bot_api.lua alone: replay_fixture.lua installs
-- per-unit `__spec` overrides from the frame, so the same name can be answered
-- from the .dem on one unit and by the prefix rule on the next.  The only
-- honest reading is to ask real units on real frames, which is what this does.
--
-- THE CANDIDATE LIST IS PARSED OUT OF bots/, never hardcoded: a name that
-- shipped code stops calling must drop out of this census by itself, and a name
-- somebody adds must appear.  The count is pinned double-sided by the test.
--
-- ⚠️ HONEST BOUNDARY (this is a CEILING on the loud half, not a bug list).
-- Answering 0 is only wrong where the engine does not return a scalar, and this
-- sweep does NOT decide that -- deciding it needs the shipped consumption, which
-- is the static half in the test file.  A name here is "answered by the
-- catch-all", nothing more.  Rows are probed WITHOUT arguments, which is the
-- arity the catch-all itself ignores; a spec override that is a function of its
-- arguments may therefore raise, and that is recorded as its own bucket rather
-- than folded into either answer (the three-valued lesson of GH #492: a raise
-- is not a measured no).
--
-- Manifest grammar (one record per line, space-separated):
--   C <key> <n>            a counter bucket
--   N <name> <n_scalar0> <n_other> <n_raise> <exempt|plain>
--       one candidate getter: on how many probed (frame, unit) pairs the mock
--       answered the literal number 0, how many it answered anything else
--       (including nil), and how many raised.  `exempt` marks the names the
--       mock already special-cases away from the catch-all, so the roster
--       cannot quietly re-absorb them.
--   R <carrier> <out_s> <raise_s> <ans_s> <out_l> <raise_l> <ans_l>
--       PHASE 2, the pricing that actually decides anything: a shipped helper
--       whose body consumes one of those zeroes, driven on every live frame
--       twice.  `shipped` is the corpus as it stands.  `lifted` re-drives the
--       same frame with the ONE `^Is -> false` default that gates the site
--       overridden true on the nearby enemies -- i.e. the world the mock would
--       have the day somebody repairs that default, which this mock's own
--       history says is a thing that happens (HasModifier and the
--       WasRecentlyDamagedBy* family were both repaired exactly that way).
--       A carrier whose `n_raise_shipped` is 0 and whose `n_raise_lifted` is
--       not is MASKED: two defaults in the same file are cancelling, and the
--       repair order between them is load-bearing.  Carriers with no gate in
--       front of the consumption are driven once and report the same pair
--       twice, so the column stays readable without a second grammar.
--   DONE
-- The test treats absence of the final DONE line as a failed subprocess.

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')

local out = io.stdout

local function read_file(path)
    local f = assert(io.open(path, 'r'), path .. ' is not readable')
    local s = f:read('*a')
    f:close()
    return s
end

-- Every `:Get*(` name shipped code under bots/ actually calls. Parsed, so the
-- candidate list tracks the tree instead of a snapshot of it.
local function shipped_getters()
    local names, order = {}, {}
    local p = assert(io.popen("find bots -name '*.lua' | sort"))
    for path in p:lines() do
        for name in read_file(path):gmatch(':(Get[A-Za-z0-9_]*)%s*%(') do
            if names[name] == nil then
                names[name] = true
                order[#order + 1] = name
            end
        end
    end
    p:close()
    table.sort(order)
    return order
end

-- The names bot_api.lua steers AWAY from the `^Get -> 0` catch-all. Parsed out
-- of the mock for the same reason the candidate list is parsed out of bots/:
-- if somebody adds an exception, this census must notice by itself.
local function exempt_names()
    local src = read_file('tests/mock/bot_api.lua')
    local ex = {}
    -- `if key == 'X' then return ... end` special cases inside default_for
    for name in src:gmatch("key%s*==%s*'(Get[A-Za-z0-9_]*)'") do ex[name] = true end
    -- the handle_getters table (answers nil, not 0)
    local at = src:find('local handle_getters', 1, true)
    if at ~= nil then
        local stop = src:find('\n}', at) or #src
        for name in src:sub(at, stop):gmatch('(Get[A-Za-z0-9_]*)%s*=%s*true') do
            ex[name] = true
        end
    end
    return ex
end

local function fixture_files()
    local p = assert(io.popen('ls tests/fixtures'))
    local files = {}
    for f in p:lines() do
        if f:match('^f_.*%.lua$') then files[#files + 1] = 'tests/fixtures/' .. f end
    end
    p:close()
    table.sort(files)
    return files
end

local c = setmetatable({}, { __index = function() return 0 end })
local function bump(k, n) rawset(c, k, c[k] + (n or 1)) end
for _, k in ipairs({ 'fixtures', 'live', 'probes', 'candidates', 'exempt',
    'names_scalar0_any', 'names_scalar0_always', 'names_never_scalar0',
    'carriers', 'carriers_masked', 'carriers_raising_today',
    'carriers_never_answer' }) do
    rawset(c, k, 0)
end

local candidates = shipped_getters()
local exempt = exempt_names()
rawset(c, 'candidates', #candidates)
local nex = 0
for _, n in ipairs(candidates) do if exempt[n] then nex = nex + 1 end end
rawset(c, 'exempt', nex)

local scalar0, other, raised = {}, {}, {}
for _, n in ipairs(candidates) do scalar0[n], other[n], raised[n] = 0, 0, 0 end

-- PHASE 2 carriers: the shipped helpers whose bodies consume one of the
-- catch-all zeroes. `gate` names the `^Is -> false` mock default that stands
-- between the frame and the consumption, or nil when nothing stands there.
-- `dom` is the helper's own decision domain, re-asked here so an early
-- `#enemies == 0` return is scored as an ABSTENTION and never as an answer --
-- the three-valued rule GH #492 was opened on (755 `false` that were all the
-- same early return read as 755 measured noes).
local function near(J, bot, r)
    local e = J.GetNearbyHeroes(bot, r, true, BOT_MODE_NONE) or {}
    return e
end
-- `lift` says WHOSE `^Is -> false` answers stand between the frame and the
-- consumption: the scanned enemies, or the subject itself. Both appear, and
-- that is not a detail -- a repair to the prefix rule reaches both at once.
local CARRIERS = {
    { name = 'IsWillBeCastUnitTargetSpell', lift = 'enemies',
      gates = { 'IsCastingAbility', 'IsUsingAbility', 'IsFacingLocation' },
      dom = function(J, bot) return #near(J, bot, 1600) > 0 end,
      call = function(J, bot) return J.IsWillBeCastUnitTargetSpell(bot, 1600) end },
    { name = 'IsWillBeCastPointSpell', lift = 'enemies',
      gates = { 'IsCastingAbility', 'IsUsingAbility', 'IsFacingLocation' },
      dom = function(J, bot) return #near(J, bot, 1600) > 0 end,
      call = function(J, bot) return J.IsWillBeCastPointSpell(bot, 1600) end },
    { name = 'DidEnemyCastAbility', lift = 'enemies',
      gates = { 'IsCastingAbility', 'IsUsingAbility', 'IsFacingLocation' },
      dom = function(J, bot) return #near(J, bot, 1200) > 0 end,
      call = function(J) return J.DidEnemyCastAbility() end },
    { name = 'IsCastingUltimateAbility', lift = 'self',
      gates = { 'IsCastingAbility', 'IsUsingAbility' },
      dom = function(_, bot) return bot:CanBeSeen() end,
      call = function(J, bot) return J.IsCastingUltimateAbility(bot) end },
    { name = 'CanEnemyInterruptTpChannel', lift = nil, gates = {},
      dom = function(J, bot) return #near(J, bot, 700) > 0 end,
      call = function(J, bot) return J.CanEnemyInterruptTpChannel(bot) end },
    { name = 'GetUltLoc', lift = nil, gates = {},
      dom = function(J, bot) return #near(J, bot, 1600) > 0 end,
      call = function(J, bot)
          return J.GetUltLoc(bot, near(J, bot, 1600)[1], 0, 2000, 1000)
      end },
}
local car = {}
for _, k in ipairs(CARRIERS) do
    car[k.name] = { out_s = 0, raise_s = 0, ans_s = 0,
                    out_l = 0, raise_l = 0, ans_l = 0 }
end

for _, path in ipairs(fixture_files()) do
    local fx = dofile(path)
    if type(fx) == 'table' and fx.units and fx.time then
        bump('fixtures')
        for _, u in ipairs(fx.units) do
            if u.alive then
                local ok, J, bot = pcall(rf.load, path, u.name)
                if ok and bot ~= nil then
                    bump('live')
                    for _, name in ipairs(candidates) do
                        local okp, v = pcall(function() return bot[name](bot) end)
                        bump('probes')
                        if not okp then
                            raised[name] = raised[name] + 1
                        elseif v == 0 then
                            scalar0[name] = scalar0[name] + 1
                        else
                            other[name] = other[name] + 1
                        end
                    end

                    -- Phase 2, leg A: the corpus exactly as it stands.
                    for _, k in ipairs(CARRIERS) do
                        local r = car[k.name]
                        local okd, ind = pcall(k.dom, J, bot)
                        if not okd or not ind then r.out_s = r.out_s + 1
                        elseif pcall(k.call, J, bot) then r.ans_s = r.ans_s + 1
                        else r.raise_s = r.raise_s + 1 end
                    end
                    -- Phase 2, leg B: lift the `^Is -> false` defaults that
                    -- stand between the frame and the consumption, on the very
                    -- enemies the carrier scans, and re-drive -- i.e. the world
                    -- this mock would have the day that prefix rule is repaired
                    -- for these names, which its own history says happens.
                    -- Carriers with no such gate are not re-driven; leg A
                    -- stands for both, so the columns stay comparable.
                    for _, k in ipairs(CARRIERS) do
                        local r = car[k.name]
                        if #k.gates == 0 then
                            r.out_l, r.raise_l, r.ans_l = r.out_s, r.raise_s, r.ans_s
                        else
                            local targets = { bot }
                            if k.lift == 'enemies' then
                                targets = near(J, bot, 1600)
                            end
                            for _, h in pairs(targets) do
                                if type(h) == 'table' then
                                    for _, g in ipairs(k.gates) do
                                        rawset(h, g, function() return true end)
                                    end
                                end
                            end
                            local okd, ind = pcall(k.dom, J, bot)
                            if not okd or not ind then r.out_l = r.out_l + 1
                            elseif pcall(k.call, J, bot) then r.ans_l = r.ans_l + 1
                            else r.raise_l = r.raise_l + 1 end
                        end
                    end
                end
            end
        end
    end
end

for _, k in ipairs(CARRIERS) do
    local r = car[k.name]
    out:write(string.format('R %s %d %d %d %d %d %d\n', k.name,
        r.out_s, r.raise_s, r.ans_s, r.out_l, r.raise_l, r.ans_l))
    if r.raise_s == 0 and r.raise_l > 0 then bump('carriers_masked') end
    if r.raise_s > 0 then bump('carriers_raising_today') end
    if r.raise_s > 0 and r.ans_s == 0 then bump('carriers_never_answer') end
end
rawset(c, 'carriers', #CARRIERS)

for _, name in ipairs(candidates) do
    if scalar0[name] > 0 then
        bump('names_scalar0_any')
        if other[name] == 0 and raised[name] == 0 then bump('names_scalar0_always') end
    else
        bump('names_never_scalar0')
    end
    out:write(string.format('N %s %d %d %d %s\n', name, scalar0[name],
        other[name], raised[name], exempt[name] and 'exempt' or 'plain'))
end

local keys = {}
for k in pairs(c) do keys[#keys + 1] = k end
table.sort(keys)
for _, k in ipairs(keys) do out:write(string.format('C %s %d\n', k, c[k])) end
out:write('DONE\n')

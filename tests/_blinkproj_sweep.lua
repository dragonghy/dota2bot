-- Heavy corpus sweep for tests/test_blinkflee_scope_ruling.lua, run as a
-- SUBPROCESS (backlog 0q: a full-corpus drive that rebuilds jmz_func once per
-- hero-frame must not run on run_tests.lua's long-lived heap). The leading
-- underscore keeps run_tests.lua from globbing it.
--
-- What it measures: the size of the population on which the GH #304 option (A)
-- transplant -- putting `and not J.ShouldHoldBlinkFlee(bot)` on the
-- IsProjectileIncoming branch of X.ConsiderItemDesire['item_blink'] -- would
-- SUPPRESS a dodge. The hold policy is
--     hp/max >= 0.70  AND  not WasRecentlyDamagedByAnyHero(2.0)
-- so the transplanted guard permits the dodge only when the bot is ALREADY
-- under 70% HP or has ALREADY been hit by a hero in the last 2s. Both readings
-- look BACKWARD; the branch they would gate is triggered by a projectile still
-- in flight, i.e. by damage that has not landed. This sweep puts a number on
-- how much of the corpus sits in the backward-quiet half.
--
-- Manifest grammar (one record per line, space-separated):
--   C <key> <n>                a counter bucket
--   GRID <hp_x1000> <n>        live v2 hero frames with hp/max >= t AND not
--                              WasRecentlyDamagedByAnyHero(2.0) -- the frames
--                              option (A) would hold the dagger on, as a
--                              function of the HP constant. Present so the
--                              reading is not an artifact of 0.70.
--   DONE
-- Absence of the final DONE line is treated by the test as a failed subprocess.
--
-- print() is not usable here -- the loaded bots/ world replaces it -- so every
-- line goes through io.write.

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')

local out = io.stdout

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

-- Zero-initialised so they are ALWAYS emitted: without this an absent key and
-- a measured zero look identical to the parser, and "the assertion never ran"
-- would read as "the assertion passed" (the GH #171 shape).
for _, k in ipairs({
    'fixtures', 'fixtures_v2', 'live', 'v2_live', 'v2_ambiguous',
    'v2_hold', 'v2_dmg2', 'v2_hp_ge70', 'v2_quiet',
    -- The same two readings with the damage window widened to 5.0. They exist
    -- because a 2.0 -> 5.0 mutation of the shipped window SURVIVED the first
    -- battery: on this corpus hero damage on a healthy frame is either inside
    -- 2s or older than 5s, so every number above is byte-identical either way.
    -- That is a property of the corpus, not of the guard, and it is asserted
    -- rather than left as a silent mutation survivor.
    'v2_dmg5', 'v2_quiet5', 'v2_dmg_between_2_and_5',
    'proj_incoming', 'unarmed_hold',
    'IMPOSSIBLE_hold_without_hp', 'IMPOSSIBLE_hold_with_damage',
    'IMPOSSIBLE_hold_not_quiet', 'IMPOSSIBLE_unarmed_hold',
}) do
    rawset(c, k, 0)
end

-- One row per v2, non-ambiguous, live hero frame: { hp fraction, was hit by a
-- hero in the last 2.0s }. The grid below is rebuilt from these, so it is
-- defined over the WHOLE population and not only over the frames that already
-- cleared the shipped 0.70.
local rows = {}

for _, path in ipairs(fixture_files()) do
    local fx = dofile(path)
    if type(fx) == 'table' and fx.units and fx.time then
        bump('fixtures')
        -- v2 = the fixture carries a backward damage window, so
        -- WasRecentlyDamagedByAnyHero(2.0) is answered from data rather than
        -- from the mock's blanket false. Everything keyed v2_* below is
        -- reported on this subset only; the rest of the corpus cannot speak.
        local v2 = fx.recent_window ~= nil and fx.recent_window >= 2.0
        if v2 then bump('fixtures_v2') end

        for _, u in ipairs(fx.units) do
            if u.alive then
                bump('live')
                local J, bot = rf.load(path, u.name)

                -- The dodge branch's own trigger. The dump carries no
                -- projectile stream and the mock answers {} at every call
                -- site, so this is 0 by construction -- asserted, not assumed,
                -- because it is exactly why the joint frame (quiet + inbound
                -- projectile) cannot be pinned offline today (GH #305).
                J.IsSoakCandidate = function() return false end
                if J.IsProjectileIncoming(bot, 1200) then bump('proj_incoming') end

                -- Unarmed the helper is a literal false: the shipped tree is
                -- unchanged by this ruling and by the id.
                if J.ShouldHoldBlinkFlee(bot) then bump('unarmed_hold') end

                if v2 then
                    if u.recent_damage_ambiguous then
                        -- The generator refused to reconstruct this hero's
                        -- history (an illusion of it or of an attacker was on
                        -- the field). The mock default then stands and reads
                        -- calm for the wrong reason, so the frame is excluded
                        -- from every v2_* reading below.
                        bump('v2_ambiguous')
                    else
                        bump('v2_live')
                        local mx = bot:GetMaxHealth() or 0
                        local hp01 = mx > 0 and (bot:GetHealth() / mx) or 0
                        local dmg2 = bot:WasRecentlyDamagedByAnyHero(2.0) and true or false
                        if dmg2 then bump('v2_dmg2') end
                        if hp01 >= 0.70 then bump('v2_hp_ge70') end
                        local quiet = (hp01 >= 0.70) and not dmg2
                        if quiet then bump('v2_quiet') end
                        rows[#rows + 1] = { hp01, dmg2 }

                        -- Sensitivity of the whole reading to the shipped 2.0.
                        local dmg5 = bot:WasRecentlyDamagedByAnyHero(5.0) and true or false
                        if dmg5 then bump('v2_dmg5') end
                        if (hp01 >= 0.70) and not dmg5 then bump('v2_quiet5') end
                        if dmg5 and not dmg2 then bump('v2_dmg_between_2_and_5') end

                        J.IsSoakCandidate = function(id) return id == 'blinkflee' end
                        local hold = J.ShouldHoldBlinkFlee(bot) and true or false
                        if hold then bump('v2_hold') end

                        -- The hold policy IS the conjunction, on the real
                        -- frame: any of these firing means the helper drifted
                        -- away from the two clauses this ruling reasons about.
                        if hold and hp01 < 0.70 then bump('IMPOSSIBLE_hold_without_hp') end
                        if hold and dmg2 then bump('IMPOSSIBLE_hold_with_damage') end
                        if hold ~= quiet then bump('IMPOSSIBLE_hold_not_quiet') end

                        J.IsSoakCandidate = function() return false end
                        if J.ShouldHoldBlinkFlee(bot) then bump('IMPOSSIBLE_unarmed_hold') end
                    end
                end
            end
        end
    end
end

local keys = {}
for k in pairs(c) do keys[#keys + 1] = k end
table.sort(keys)
for _, k in ipairs(keys) do out:write(string.format('C %s %d\n', k, c[k])) end

-- Sweep the HP constant across its whole plausible range. The point of the
-- grid is that the suppression domain is not a property of 0.70: the damage
-- clause alone already accounts for most of it.
for i = 100, 1000, 25 do
    local t = i / 1000
    local n = 0
    for _, r in ipairs(rows) do
        if r[1] >= t and not r[2] then n = n + 1 end
    end
    out:write(string.format('GRID %d %d\n', i, n))
end

out:write('DONE\n')

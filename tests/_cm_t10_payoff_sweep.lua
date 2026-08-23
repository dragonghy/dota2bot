-- Heavy corpus sweep for tests/test_cm_t10_payoff.lua, run as a SUBPROCESS
-- (the backlog 0q rule: a drive that rebuilds jmz_func AND a hero file once per
-- frame-world must not run on run_tests.lua's long-lived heap). The leading
-- underscore keeps run_tests.lua from globbing it (`^test_.*%.lua$`).
--
-- WHAT IT MEASURES
-- ----------------
-- Crystal Maiden's t10 pair, on this repo's corpus, by the SAME procedure for
-- both sides -- [1] special_bonus_hp_200 vs [2] special_bonus_intelligence_12:
--
--   world 0  the frame as dumped
--   world H  +200 hp   (hp += 200, max_hp += 200)
--   world I  +12 INT   (mp += 144, max_mp += 144)
--
-- Four channels, each reported with its own health so a zero can be read as
-- EMPTY or as UNDERPOWERED (the GH #115 rule) rather than guessed at:
--
--   (1) DECISION   drive the real X.SkillsComplement() in each world and record
--                  which ability it queues. Strongest channel; also the weakest
--                  instrument here -- see CHANNEL counters.
--   (2) CASTABLE   ready ability slots (trained, off cooldown) whose mana cost
--                  the frame cannot pay, and which +144 mana would pay for.
--   (3) GATE       the hero file's OWN thresholds -- parsed out of the source,
--                  never restated here (the M13 lesson: a census that copies
--                  the constant it measures reports the old world unmoved after
--                  the constant moves) -- counting frames each world crosses.
--   (4) DEATH      CM-subject frames only: observed.burst vs hp and hp+200,
--                  i.e. whether the HP talent would have survived the damage
--                  the replay actually delivered.
--
-- EXTERNAL ANCHORS (not in the dump -- make_fixture.py extracts no ability
-- specs, same caveat as wkreincarnmp's GetManaCost):
--   * mana costs by rank, datafeed hero_id=5 read 2026-08-23:
--       Crystal Nova 115/135/155/175, Frostbite 125/135/145/155,
--       Freezing Field 200/400/600.
--     Without them every ability reads cost 0 (world assertion #13: the mock
--     answers 0 for un-stubbed Get*), IsFullyCastable() is mana-blind, and the
--     +12 INT world would be invisible BY CONSTRUCTION.
--   * 12 max mana per point of Intelligence (Dota 2 wiki, read 2026-08-23)
--     => +12 INT = +144 mana. DELTA rows report 120/144/168 so no conclusion
--     rests on that one constant.
--   * mana regen per INT (0.05, possibly 0.04 -- the changelog and the article
--     disagree) is deliberately NOT modelled: a frame is instantaneous.
--   * +12 attack damage (INT is CM's primary attribute) is not modelled either.
--     Both omissions cut the same way: they UNDERSTATE the INT side.
--
-- Manifest grammar (one record per line, space-separated):
--   C <key> <n>                        counter bucket
--   WORLD <fixture> <world> <hp> <maxhp> <mp> <maxmp>
--       what the hero file actually saw in that world, so a shift that stops
--       happening cannot hide behind a silent decision channel.
--   ROW <fixture> <lv> <hp> <maxhp> <mp> <maxmp> <d0> <dH> <dI>
--       one live CM frame at hero level >= 10 (below 10 NEITHER talent exists;
--       those frames are out of domain and counted apart). d* = the decision
--       string of each world, '-' = the file queued nothing.
--   SLOT <fixture> <ability> <rank> <cost> <mp> <blocked01> <flip01>
--   XMANA <fixture> <threshold-text>   a mana gate world I crosses on this frame
--   XHP <fixture> <threshold-text>     an hp gate world H crosses on this frame
--   DEATH <fixture> <hp> <burst> <died_after> <saved01>
--   DELTA <mana_delta> <flips>         castability sensitivity
--   THRESH <kind> <value>              a threshold parsed out of the hero file
--   ERR <fixture> <world> <msg>        a world that raised instead of deciding
--   DONE
-- Absence of the final DONE line is treated by the test as a failed subprocess.

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')

local out = io.stdout

local HERO_SRC_PATH = 'bots/BotLib/hero_crystal_maiden.lua'
local HP_BONUS      = 200
local MANA_BONUS    = 144
local TALENT_LEVEL  = 10

-- datafeed hero_id=5, 2026-08-23; index = ability rank.
local COSTS = {
    crystal_maiden_crystal_nova   = { 115, 135, 155, 175 },
    crystal_maiden_frostbite      = { 125, 135, 145, 155 },
    crystal_maiden_freezing_field = { 200, 400, 600 },
}

local c = setmetatable({}, { __index = function() return 0 end })
local function bump(k, n) rawset(c, k, c[k] + (n or 1)) end

local function read_file(path)
    local fh = assert(io.open(path, 'r'), 'cannot open ' .. path)
    local s = fh:read('*a'); fh:close()
    return s
end

--- Lines with comments stripped: a threshold quoted in prose is not a gate.
local function live_lines(src)
    local o = {}
    for line in src:gsub('%-%-%[%[.-%]%]', ''):gmatch('[^\n]+') do
        if not line:match('^%s*%-%-') then o[#o + 1] = line end
    end
    return o
end

-- The hero file's own thresholds, READ OUT of the source. Each entry is
-- { text = <as written>, f = function(hp01, hp, mp01, mp) -> boolean }.
local function parse_thresholds()
    local src = read_file(HERO_SRC_PATH)
    local nKeepMana = tonumber(src:match('nKeepMana%s*=%s*(%d+)'))
    assert(nKeepMana, 'hero_crystal_maiden.lua no longer assigns a literal nKeepMana')
    local mana, hp, seen = {}, {}, {}
    local function add(t, text, f)
        if not seen[text] then seen[text] = true; t[#t + 1] = { text = text, f = f } end
    end
    for _, line in ipairs(live_lines(src)) do
        for op, v in line:gmatch('nMP%s*([><=]+)%s*([%d%.]+)') do
            local n = tonumber(v)
            add(mana, 'nMP' .. op .. v, function(_, _, mp01) return op == '>=' and mp01 >= n or mp01 > n end)
        end
        for op, mul in line:gmatch('GetMana%(%)%s*([><=]+)%s*nKeepMana%s*%*?%s*(%d*)') do
            local n = nKeepMana * (tonumber(mul) or 1)
            add(mana, 'GetMana()' .. op .. n, function(_, _, _, mp) return op == '>=' and mp >= n or mp > n end)
        end
        for op, v in line:gmatch('GetMana%(%)%s*([><=]+)%s*(%d+)') do
            local n = tonumber(v)
            add(mana, 'GetMana()' .. op .. v, function(_, _, _, mp) return op == '>=' and mp >= n or mp > n end)
        end
        for op, v in line:gmatch('nHP%s*([><=]+)%s*([%d%.]+)') do
            local n = tonumber(v)
            add(hp, 'nHP' .. op .. v, function(hp01) return op == '>=' and hp01 >= n or hp01 > n end)
        end
    end
    assert(#mana > 0 and #hp > 0, 'no nMP/nHP thresholds left in ' .. HERO_SRC_PATH)
    return mana, hp
end

local MANA_GATES, HP_GATES = parse_thresholds()

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

local function cm_unit(fx)
    for _, u in ipairs(fx.units or {}) do
        if u.name == 'npc_dota_hero_crystal_maiden' and u.alive then return u end
    end
end

local function shift(bot, dHp, dMana)
    local spec = rawget(bot, '__spec')
    local hp, maxhp = bot:GetHealth(), bot:GetMaxHealth()
    local mp, maxmp = bot:GetMana(), bot:GetMaxMana()
    spec.GetHealth, spec.GetMaxHealth = hp + dHp, maxhp + dHp
    spec.OriginalGetHealth, spec.OriginalGetMaxHealth = hp + dHp, maxhp + dHp
    spec.GetMana, spec.GetMaxMana = mp + dMana, maxmp + dMana
end

--- The decision the shipped file makes on this frame, as a flat string, plus
--- two channel-health readings taken in the same loaded world.
---
--- It also reports what the hero file ACTUALLY saw (hp/mp after the shift).
--- Without that, a mutation removing the shift is invisible: the decision
--- channel is silent on every frame anyway, so "no world changed anything"
--- reads the same whether the worlds differ or not (mutation M4, escaped once).
local function decide(path, dHp, dMana, sKey)
    local J, bot = rf.load(path, 'npc_dota_hero_crystal_maiden')
    -- Stable version: nothing armed. CM's ConsiderQ consults two gated helpers
    -- (lanefix's J.ShouldConserveManaInLane, and nopush); an armed one would be
    -- measuring a tree that does not ship.
    J.IsSoakCandidate = function() return false end

    for sName, tCosts in pairs(COSTS) do
        local h = bot:GetAbilityByName(sName)
        if h ~= nil then
            local rank = h:GetLevel()
            if rank > 0 then rawget(h, '__spec').GetManaCost = tCosts[math.min(rank, #tCosts)] end
        end
    end

    shift(bot, dHp, dMana)

    local nEnemies = #J.GetNearbyHeroes(bot, 1600, true, BOT_MODE_NONE)
    local nMode = bot:GetActiveMode()
    out:write(string.format('WORLD %s %s %d %d %d %d\n', path, sKey,
        bot:GetHealth(), bot:GetMaxHealth(), bot:GetMana(), bot:GetMaxMana()))

    local log = rf.record_actions(bot)
    local X = rf.load_hero('crystal_maiden')
    local ok, err = pcall(function() X.SkillsComplement() end)
    if not ok then return nil, tostring(err) end

    local parts = {}
    for _, entry in ipairs(log) do
        local sAbility, a = '?', entry.args[1]
        if type(a) == 'table' and a.GetName then sAbility = a:GetName() or '?' end
        parts[#parts + 1] = entry.fn .. ':' .. sAbility
    end
    return (#parts == 0) and '-' or table.concat(parts, '|'), nil, nEnemies, nMode
end

local DELTAS = { 120, MANA_BONUS, 168 }
local flips = {}
for _, d in ipairs(DELTAS) do flips[d] = 0 end

for _, path in ipairs(fixture_files()) do
    local fx = dofile(path)
    if type(fx) == 'table' and fx.units and fx.time then
        bump('fixtures')
        local u = cm_unit(fx)
        if u ~= nil then
            bump('cm_frames')
            if (u.level or 0) < TALENT_LEVEL then
                bump('cm_below_t10')
            else
                bump('cm_at_or_above_t10')

                -- (2) CASTABLE
                for _, a in ipairs(u.abilities or {}) do
                    local tCosts = COSTS[a.name]
                    if tCosts ~= nil and (a.level or 0) > 0 and (a.cd or 0) <= 0 then
                        bump('ready_slots')
                        bump('ready_' .. a.name)
                        local nCost = tCosts[math.min(a.level, #tCosts)]
                        local bBlocked = u.mp < nCost
                        local bFlip = bBlocked and (u.mp + MANA_BONUS >= nCost)
                        if bBlocked then
                            bump('unaffordable_slots'); bump('unaffordable_' .. a.name)
                        end
                        if bFlip then bump('castable_flips'); bump('flip_' .. a.name) end
                        for _, d in ipairs(DELTAS) do
                            if bBlocked and u.mp + d >= nCost then flips[d] = flips[d] + 1 end
                        end
                        out:write(string.format('SLOT %s %s %d %d %d %d %d\n',
                            path, a.name, a.level, nCost, u.mp,
                            bBlocked and 1 or 0, bFlip and 1 or 0))
                    end
                end

                -- (3) GATE, both sides through the same procedure
                local mp01, mp01I = u.mp / u.max_mp, (u.mp + MANA_BONUS) / (u.max_mp + MANA_BONUS)
                local hp01, hp01H = u.hp / u.max_hp, (u.hp + HP_BONUS) / (u.max_hp + HP_BONUS)
                local bAnyMana, bAnyHp = false, false
                for _, g in ipairs(MANA_GATES) do
                    if not g.f(hp01, u.hp, mp01, u.mp) and g.f(hp01, u.hp, mp01I, u.mp + MANA_BONUS) then
                        bAnyMana = true
                        bump('managate_crossings')
                        out:write(string.format('XMANA %s %s\n', path, g.text))
                    end
                end
                for _, g in ipairs(HP_GATES) do
                    if not g.f(hp01, u.hp, mp01, u.mp) and g.f(hp01H, u.hp + HP_BONUS, mp01, u.mp) then
                        bAnyHp = true
                        bump('hpgate_crossings')
                        out:write(string.format('XHP %s %s\n', path, g.text))
                    end
                end
                if bAnyMana then bump('managate_frames') end
                if bAnyHp then bump('hpgate_frames') end

                -- (1) DECISION
                local d0, e0, nEnemies, nMode = decide(path, 0, 0, '0')
                local dH = decide(path, HP_BONUS, 0, 'H')
                local dI = decide(path, 0, MANA_BONUS, 'I')
                if d0 == nil then
                    bump('errors'); out:write(string.format('ERR %s 0 %s\n', path, (e0:gsub('%s+', '_'))))
                    d0 = 'ERROR'
                end
                dH, dI = dH or 'ERROR', dI or 'ERROR'
                out:write(string.format('ROW %s %d %d %d %d %d %s %s %s\n',
                    path, u.level, u.hp, u.max_hp, u.mp, u.max_mp, d0, dH, dI))
                if d0 ~= '-' and d0 ~= 'ERROR' then bump('baseline_acted') end
                if dH ~= d0 then bump('hp_world_changed') end
                if dI ~= d0 then bump('int_world_changed') end
                -- CHANNEL health: a decision channel that never sees an enemy
                -- and never reports a mode cannot report a zero as EMPTY.
                if nEnemies == 0 then bump('channel_no_enemy_1600') end
                if nMode == BOT_MODE_NONE then bump('channel_mode_none') end

                -- (4) DEATH, subject frames only (observed.* exists only there)
                if fx.self == 'npc_dota_hero_crystal_maiden' then
                    bump('cm_subject_frames')
                    local nBurst = 0
                    for _, v in pairs((fx.observed or {}).burst or {}) do nBurst = nBurst + (tonumber(v) or 0) end
                    local nDied = (fx.observed or {}).died_after
                    if nDied ~= nil then
                        bump('cm_subject_died')
                        local bSaved = (nBurst < u.hp + HP_BONUS)
                        if bSaved then bump('death_saved_by_200') end
                        out:write(string.format('DEATH %s %d %d %.1f %d\n',
                            path, u.hp, nBurst, nDied, bSaved and 1 or 0))
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
for _, d in ipairs(DELTAS) do out:write(string.format('DELTA %d %d\n', d, flips[d])) end
for _, g in ipairs(MANA_GATES) do out:write(string.format('THRESH mana %s\n', g.text)) end
for _, g in ipairs(HP_GATES) do out:write(string.format('THRESH hp %s\n', g.text)) end
out:write('DONE\n')

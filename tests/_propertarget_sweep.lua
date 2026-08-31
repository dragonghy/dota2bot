-- Corpus sweep helper for tests/test_propertarget_conjunct_guard.lua.
--
-- Deliberately NOT named test_*.lua: run_tests.lua globs '^test_.*%.lua$' and
-- this file walks every fixture x every live hero; it is run in its own
-- process by the calling test via io.popen (same reason as
-- tests/_towerstale_sweep.lua and tests/_stayfield2_margin_sweep.lua).
--
-- WHAT IT COUNTS. mode_roam_generic.lua writes the same three-line decision
-- ("target far -> walk to it, target near -> attack it") FOUR times as
--
--     if J.IsValidTarget(botTarget) and <distance test> then
--         bot:Action_MoveToLocation(botTarget:GetLocation()) return
--     else
--         bot:Action_AttackUnit(botTarget, false) return        -- or ActionQueue_
--     end
--
-- and THREE more times as the nested form
--
--     if J.IsValid(botTarget) then
--         if <distance test> then ... move ... else ... attack ... end
--     end
--
-- The two forms are NOT equivalent, for two independent reasons:
--
--   (1) the PREDICATES differ. J.IsValidTarget delegates to
--       J.Utils.IsValidHero (jmz_func.lua carries a FUSE RECORD saying so in
--       as many words: "same delegate, same answer ... only the name differs,
--       and the name lies"), while J.IsValid is the wide one (not nil, not
--       null, visible, alive, NOT A BUILDING) and therefore admits creeps.
--       J.GetProperTarget -- the source of botTarget at all seven sites --
--       returns bot:GetTarget() or bot:GetAttackTarget() and only nils out
--       SAME-TEAM heroes/buildings, so a creep is a completely ordinary
--       return value.
--
--   (2) the STRUCTURE differs. In the conjunct form the guard is a conjunct
--       of the distance test, so the guard's own failure falls into the
--       `else` -- the branch that exists only for "valid AND near". A creep
--       target at any distance therefore skips the distance test entirely and
--       is handed a CONTINUOUS attack order (bOnce=false), which is the exact
--       shape 'roamreach' was written to remove from mode_team_roam_generic;
--       and a nil target is handed to Action_AttackUnit followed by `return`,
--       so the frame ends with no usable order at all.
--
-- This sweep prices the guard's own failure on the corpus. Per live hero of
-- per fixture, with NOTHING armed, it evaluates J.GetProperTarget(bot) and
-- classifies the value the four `else` branches would receive:
--
--   nil            -- Action_AttackUnit(nil, false) + return
--   hero           -- IsValidTarget true: the conjunct form behaves as written
--   nonhero        -- IsValidTarget FALSE but J.IsValid TRUE: the distance
--                     test is skipped and a continuous order is issued
--   other          -- neither (dead / invisible / building / null)
--
-- and, for the nonhero bucket, whether the SKIPPED distance test would have
-- been true (dist > attack range + 200), i.e. whether the conjunct form
-- actually diverges from the nested form on that frame.
--
-- Usage: lua5.1 tests/_propertarget_sweep.lua
-- Machine-readable stdout:
--   COUNT frames=<n> nil=<n> hero=<n> nonhero=<n> other=<n>
--   SKIP nonhero_far=<n> nonhero_near=<n> hero_far=<n>
--   SRC tgt=<n> atk=<n> both=<n>
--   FRAME <fixture> <hero> class=<c> far=<0|1>

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')

-- The fixture loader replaces the global `print` (the bot API mock owns it), so
-- every line this sweep emits goes through io.stdout directly. Measured: with
-- plain print() the whole run emits nothing and still exits 0.
local function emit(s) io.stdout:write(s, '\n') end

local function fixture_files()
    local p = assert(io.popen('ls tests/fixtures'))
    local out = {}
    for f in p:lines() do if f:match('^f_.*%.lua$') then out[#out + 1] = f end end
    p:close()
    table.sort(out)
    return out
end

local function hero_names(path)
    local fx = dofile('tests/fixtures/' .. path)
    local out = {}
    for _, u in ipairs(fx.units or {}) do
        if u.name and u.name:match('^npc_dota_hero_') and u.alive ~= false then
            out[#out + 1] = u.name
        end
    end
    return out
end

local function safe(fn, dflt)
    local ok, v = pcall(fn)
    if not ok then return dflt end
    return v
end

local n = { frames = 0, nilv = 0, hero = 0, nonhero = 0, other = 0 }
local s = { nonhero_far = 0, nonhero_near = 0, hero_far = 0 }
local src = { tgt = 0, atk = 0, both = 0 }
local out = {}

for _, f in ipairs(fixture_files()) do
    local okh, hs = pcall(hero_names, f)
    if okh then
        for _, h in ipairs(hs) do
            pcall(function()
                local J, bot = rf.load('tests/fixtures/' .. f, h)

                local t = safe(function() return J.GetProperTarget(bot) end, nil)
                n.frames = n.frames + 1

                -- Which of the two sources inside J.GetProperTarget could have
                -- produced it? Recorded so an empty nonhero bucket can be
                -- attributed instead of left as a bare zero.
                local gt = safe(function() return bot:GetTarget() end, nil)
                local ga = safe(function() return bot:GetAttackTarget() end, nil)
                if gt ~= nil then src.tgt = src.tgt + 1 end
                if ga ~= nil then src.atk = src.atk + 1 end
                if gt ~= nil and ga ~= nil then src.both = src.both + 1 end

                local class, far
                if t == nil then
                    class = 'nil'
                    n.nilv = n.nilv + 1
                else
                    local is_hero = safe(function() return J.IsValidTarget(t) end, false)
                    local is_wide = safe(function() return J.IsValid(t) end, false)
                    local d = safe(function() return GetUnitToUnitDistance(bot, t) end, nil)
                    local reach = safe(function() return bot:GetAttackRange() end, nil)
                    if d ~= nil and reach ~= nil then far = (d > reach + 200) end
                    if is_hero then
                        class = 'hero'
                        n.hero = n.hero + 1
                        if far then s.hero_far = s.hero_far + 1 end
                    elseif is_wide then
                        class = 'nonhero'
                        n.nonhero = n.nonhero + 1
                        if far then s.nonhero_far = s.nonhero_far + 1
                        elseif far == false then s.nonhero_near = s.nonhero_near + 1 end
                    else
                        class = 'other'
                        n.other = n.other + 1
                    end
                end
                out[#out + 1] = string.format('FRAME %s %s class=%s far=%s',
                    f, h, class, (far == true) and '1' or ((far == false) and '0' or '?'))
            end)
        end
    end
end

emit(string.format('COUNT frames=%d nil=%d hero=%d nonhero=%d other=%d',
    n.frames, n.nilv, n.hero, n.nonhero, n.other))
emit(string.format('SKIP nonhero_far=%d nonhero_near=%d hero_far=%d',
    s.nonhero_far, s.nonhero_near, s.hero_far))
emit(string.format('SRC tgt=%d atk=%d both=%d', src.tgt, src.atk, src.both))
for _, l in ipairs(out) do emit(l) end

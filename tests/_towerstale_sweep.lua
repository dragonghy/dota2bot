-- Corpus sweep helper for tests/test_towercreep_stale_flag.lua.
--
-- Deliberately NOT named test_*.lua: run_tests.lua globs '^test_.*%.lua$' and
-- this file drives the whole corpus through a shipped mode file; it is run in
-- its own process by the calling test via io.popen (same reason as
-- tests/_stayfield2_margin_sweep.lua and tests/_pullcamp_sweep.lua).
--
-- WHAT IT COUNTS. mode_team_roam_generic keeps TWO stale-handle pairs:
--
--   hTargetCreep                  -- reset every turbo frame by the PROMOTED
--                                    'roamstale' line at the top of
--                                    GetDesireHelper
--   towerCreepMode / towerCreep   -- reset ONLY by the `else` inside
--                                    `if bot:IsAlive() and
--                                     bot:DistanceFromFountain() > 4600`,
--                                    which sits BELOW every early return of
--                                    GetDesireHelper, and by OnEnd()
--
-- and Think() consumes them in the order
--   :587 hTargetCreep   -> Action_AttackUnit(h, true),  return
--   :612 towerCreepMode -> Action_AttackUnit(towerCreep, false), return
--   :621 ShouldHelpAlly -> Action_AttackUnit(targetUnit, false), return
--   :628 core/support   -> Action_AttackUnit(targetUnit, false), return
--
-- so a stale towerCreepMode shadows :621 and :628 -- the two sites that serve
-- every early-return branch of GetDesireHelper.
--
-- This sweep drives every LIVE hero of every fixture as its own subject with
-- NOTHING armed (shipped turbo defaults) and measures, per frame:
--   * the team_roam bid,
--   * which Think() site fired, classified by the recorded action
--     (:587 = AttackUnit(_, true); :612 = AttackUnit(non-hero, false);
--      :621/:628 = AttackUnit(hero, false)),
--   * the six head clauses of X.ShouldAttackTowerCreep, re-evaluated from the
--     outside on the same frame, so an empty domain can be attributed to a
--     clause instead of left as a bare zero.
--
-- Usage: lua5.1 tests/_towerstale_sweep.lua
-- Machine-readable stdout:
--   COUNT frames=<n> bidpos=<n> fire587=<n> fire612=<n> fire621or628=<n>
--   CLAUSE lvl=<n> anim=<n> notgt=<n> noatk=<n> hp38=<n> nodmg=<n> all6=<n>
--   ANIM <value>=<n> ...
--   FRAME <fixture> <hero> bid=<f> site=<n> hp=<f>

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')

-- The fixture loader replaces the global `print` (the bot API mock owns it), so
-- every line this sweep emits goes through io.stdout directly. Measured: with
-- plain print() the whole run emits nothing and still exits 0.
local function emit(s) io.stdout:write(s, '\n') end

-- The mock resolves unknown ALL_CAPS globals to sentinel integers, which ruins
-- the RemapValClamped arithmetic these branches run (same reason as
-- tests/test_roamreach_bounded_chase.lua).
local DESIRE = {
    BOT_MODE_DESIRE_NONE     = 0.0,
    BOT_MODE_DESIRE_VERYLOW  = 0.1,
    BOT_MODE_DESIRE_LOW      = 0.25,
    BOT_MODE_DESIRE_MODERATE = 0.5,
    BOT_MODE_DESIRE_HIGH     = 0.75,
    BOT_MODE_DESIRE_VERYHIGH = 0.9,
    BOT_MODE_DESIRE_ABSOLUTE = 1.0,
}

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

local n = { frames = 0, bidpos = 0, f587 = 0, f612 = 0, f621 = 0 }
local c = { lvl = 0, anim = 0, notgt = 0, noatk = 0, hp38 = 0, nodmg = 0, all6 = 0 }
local d = { reach = 0, tow1600 = 0, towtgt = 0, lvl12 = 0 }
local r = { zero = 0, gate = 0, count = 0, alive = 0, far = 0 }
local anim_hist = {}
local out = {}

local function safe(fn, dflt)
    local ok, v = pcall(fn)
    if not ok then return dflt end
    return v
end

for _, f in ipairs(fixture_files()) do
    local okh, hs = pcall(hero_names, f)
    if okh then
        for _, h in ipairs(hs) do
            local ok, err = pcall(function()
                local J, bot = rf.load('tests/fixtures/' .. f, h)
                for k, v in pairs(DESIRE) do _G[k] = v end
                J.IsSoakCandidate = function() return false end
                GetPushLaneDesire = function() return 0 end   -- luacheck: ignore
                GetDefendLaneDesire = function() return 0 end -- luacheck: ignore
                rawset(bot, 'PushLaneDesire', { [LANE_TOP] = 0, [LANE_MID] = 0, [LANE_BOT] = 0 })
                rawset(bot, 'DefendLaneDesire', { [LANE_TOP] = 0, [LANE_MID] = 0, [LANE_BOT] = 0 })
                dofile('bots/mode_team_roam_generic.lua')
                if GetDesire == nil then return end

                local bid = GetDesire()
                local log = rf.record_actions(bot)
                Think()
                n.frames = n.frames + 1
                if bid > 0 then n.bidpos = n.bidpos + 1 end

                local site = 0
                for _, a in ipairs(log) do
                    if a.fn == 'Action_AttackUnit' then
                        local u = a.args[1]
                        local once = a.args[2]
                        if once == true then
                            site = 587
                        elseif u ~= nil and safe(function() return u:IsHero() end, false) then
                            site = 621
                        else
                            site = 612
                        end
                        break
                    end
                end
                if site == 587 then n.f587 = n.f587 + 1
                elseif site == 612 then n.f612 = n.f612 + 1
                elseif site == 621 then n.f621 = n.f621 + 1 end

                -- X.ShouldAttackTowerCreep's head guard, re-evaluated outside.
                local lvl   = safe(function() return bot:GetLevel() end, 0) > 2
                local av    = safe(function() return bot:GetAnimActivity() end, nil)
                local anim  = (av == 1502)
                local notgt = safe(function() return bot:GetTarget() end, nil) == nil
                local noatk = safe(function() return bot:GetAttackTarget() end, nil) == nil
                local hp38  = J.GetHP(bot) > 0.38
                local nodmg = not safe(function() return bot:WasRecentlyDamagedByAnyHero(2.0) end, true)
                if lvl then c.lvl = c.lvl + 1 end
                if anim then c.anim = c.anim + 1 end
                if notgt then c.notgt = c.notgt + 1 end
                if noatk then c.noatk = c.noatk + 1 end
                if hp38 then c.hp38 = c.hp38 + 1 end
                if nodmg then c.nodmg = c.nodmg + 1 end
                if lvl and anim and notgt and noatk and hp38 and nodmg then c.all6 = c.all6 + 1 end
                -- The FOURTH return of X.ShouldAttackTowerCreep (deny the creep
                -- our own tower is about to last-hit) sits BELOW the 1502 block,
                -- so it is reachable without the anim clause. Its own gate:
                -- a friendly tower within 1600, that tower currently attacking
                -- something, and level <= 12. (X.IsMostAttackDamage is a file
                -- local and is NOT evaluated here -- see the [limit] in the
                -- calling test.)
                local tw = safe(function() return bot:GetNearbyTowers(1600, false) end, {}) or {}
                if tw[1] ~= nil then
                    d.tow1600 = d.tow1600 + 1
                    if safe(function() return tw[1]:GetAttackTarget() end, nil) ~= nil then
                        d.towtgt = d.towtgt + 1
                    end
                end
                if safe(function() return bot:GetLevel() end, 99) <= 12 then d.lvl12 = d.lvl12 + 1 end

                -- Does GetDesireHelper even REACH the tower block? It does iff
                -- the mode gate falls through to its elseif, the ally/enemy
                -- count is not adverse, the bot is alive and it is >4600 from
                -- the fountain -- and no earlier branch returned first, which
                -- on a bid of exactly 0 is the case by construction.
                local am = safe(function() return bot:GetActiveMode() end, nil)
                local gate_open = J.IsFarming(bot) or J.IsPushing(bot) or J.IsDefending(bot)
                    or J.IsDoingRoshan(bot) or J.IsDoingTormentor(bot)
                    or am == BOT_MODE_RUNE or am == BOT_MODE_SECRET_SHOP or am == BOT_MODE_OUTPOST
                    or am == BOT_MODE_WARD or am == BOT_MODE_ATTACK or am == BOT_MODE_DEFEND_ALLY
                    or am == BOT_MODE_ROAM
                local na = #J.GetAlliesNearLoc(bot:GetLocation(), 2200)
                local ne = #J.GetEnemiesNearLoc(bot:GetLocation(), 2000)
                if bid == 0 then
                    r.zero = r.zero + 1
                    if gate_open then r.gate = r.gate + 1 end
                    if na >= ne then r.count = r.count + 1 end
                    if safe(function() return bot:IsAlive() end, false) then r.alive = r.alive + 1 end
                    if safe(function() return bot:DistanceFromFountain() end, 0) > 4600 then
                        r.far = r.far + 1
                    end
                end
                if bid == 0 and gate_open and na >= ne
                    and safe(function() return bot:IsAlive() end, false)
                    and safe(function() return bot:DistanceFromFountain() end, 0) > 4600 then
                    d.reach = d.reach + 1
                end

                local key = tostring(av)
                anim_hist[key] = (anim_hist[key] or 0) + 1

                out[#out + 1] = string.format('FRAME %s %s bid=%.4f site=%d hp=%.4f',
                    f, h, bid, site, J.GetHP(bot))
            end)
            if not ok then out[#out + 1] = 'ERR ' .. f .. ' ' .. h .. ' ' .. tostring(err) end
        end
    else
        out[#out + 1] = 'ERRLOAD ' .. f
    end
end

emit(string.format('COUNT frames=%d bidpos=%d fire587=%d fire612=%d fire621or628=%d',
    n.frames, n.bidpos, n.f587, n.f612, n.f621))
emit(string.format('CLAUSE lvl=%d anim=%d notgt=%d noatk=%d hp38=%d nodmg=%d all6=%d',
    c.lvl, c.anim, c.notgt, c.noatk, c.hp38, c.nodmg, c.all6))
local keys = {}
for k in pairs(anim_hist) do keys[#keys + 1] = k end
table.sort(keys)
local parts = {}
for _, k in ipairs(keys) do parts[#parts + 1] = k .. '=' .. anim_hist[k] end
emit('ANIM ' .. table.concat(parts, ' '))
emit(string.format('REACH zerobid=%d gate=%d count=%d alive=%d far=%d', r.zero, r.gate, r.count, r.alive, r.far))
emit(string.format('FOURTH reach=%d tow1600=%d towtgt=%d lvl12=%d', d.reach, d.tow1600, d.towtgt, d.lvl12))
for _, line in ipairs(out) do emit(line) end

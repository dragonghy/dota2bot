-- Corpus sweep behind the director's 2026-09-09 blind-A ruling on 'pulllane'
-- and 'pullthink' (test_set.md §GF).  Not a test: it prints the readings the
-- ruling quotes, over every fixture in tests/fixtures/.
--
-- The question is condition (a) -- does the pivotal input ever reach the
-- decision from a REAL frame -- asked separately of each id's pivot:
--
--   'pulllane'  : GetNeutralSpawners()   (the loop the lever's clause sits in)
--                 GetLocationAlongLane() (the path the clause measures against)
--   'pullthink' : bot:GetAnimActivity()  (the throttle the lever skips)
--                 bot.roamCampPull       (the frame the lever is scoped to)
--
-- Run: lua5.1 tests/_blind_a_pulllane_pullthink_sweep.lua

-- The mock's api.install replaces _G.print with a no-op (the engine has no
-- console -- AGENTS.md 'no bot-side debugging'), so a print-based sweep exits
-- 0 with ZERO output and looks exactly like a clean run.  Write to stderr.
local function say(s) io.stderr:write(s .. '\n') end

package.path = './tests/?.lua;./tests/mock/?.lua;' .. package.path

local rf = require('mock.replay_fixture')

local p = assert(io.popen('ls tests/fixtures/*.lua'))
local files = {}
for l in p:lines() do files[#files +1] = l end
p:close()

local C = {
    fixtures = 0, unloadable = 0,
    heroes = 0,
    -- pulllane
    spawners_frames = 0, spawners_empty = 0, spawners_nonempty = 0,
    spawner_handles = 0,
    lane_samples = 0, lane_origin = 0, lane_distinct = 0,
    -- pullthink
    anim_calls = 0, anim_zero = 0, anim_nonzero = 0,
    throttle_true = 0, throttle_false = 0, throttle_err = 0,
    camppull_nonnil = 0, camppull_nil = 0, camppull_err = 0,
    beside_calls = 0, beside_path_supplied = 0,
    control_nonnil = 0, control_err = 0,
}
local anim_values = {}
local lane_seen = {}

for _, f in ipairs(files) do
    local ok, J, _, heroes = pcall(rf.load, f)
    if not (ok and J ~= nil) then
        C.unloadable = C.unloadable + 1
    else
        C.fixtures = C.fixtures + 1

        -- ---- 'pulllane' pivot 1: the camp roster the clause iterates --------
        if GetNeutralSpawners ~= nil then
            local tCamps = GetNeutralSpawners()
            C.spawners_frames = C.spawners_frames + 1
            local n = 0
            if type(tCamps) == 'table' then
                for _ in pairs(tCamps) do n = n + 1 end
            end
            C.spawner_handles = C.spawner_handles + n
            if n == 0 then C.spawners_empty = C.spawners_empty + 1
            else C.spawners_nonempty = C.spawners_nonempty + 1 end
        end

        -- ---- 'pulllane' pivot 2: the lane path the clause measures against --
        if GetLocationAlongLane ~= nil then
            for _, nLane in ipairs({ LANE_TOP, LANE_MID, LANE_BOT }) do
                for k = 0, 20 do
                    local v = GetLocationAlongLane(nLane, k / 20)
                    if v ~= nil then
                        C.lane_samples = C.lane_samples + 1
                        local key = string.format('%s,%s,%s',
                            tostring(v.x), tostring(v.y), tostring(v.z))
                        if not lane_seen[key] then
                            lane_seen[key] = true
                            C.lane_distinct = C.lane_distinct + 1
                        end
                        if v.x == 0 and v.y == 0 then
                            C.lane_origin = C.lane_origin + 1
                        end
                    end
                end
            end
        end

        -- ---- 'pullthink' pivots, per hero ----------------------------------
        if heroes ~= nil then
            for _, h in pairs(heroes) do
                C.heroes = C.heroes + 1

                if h.GetAnimActivity ~= nil then
                    local okA, act = pcall(function() return h:GetAnimActivity() end)
                    if okA then
                        C.anim_calls = C.anim_calls + 1
                        anim_values[tostring(act)] = (anim_values[tostring(act)] or 0) + 1
                        if act == 0 then C.anim_zero = C.anim_zero + 1
                        else C.anim_nonzero = C.anim_nonzero + 1 end
                    end
                end

                -- the throttle the armed leg skips and the baseline leg obeys
                local okT, res = pcall(function()
                    return J.Utils.IsBotThinkingMeaningfulAction(h, 0, 'roam')
                end)
                if not okT then C.throttle_err = C.throttle_err + 1
                elseif res then C.throttle_true = C.throttle_true + 1
                else C.throttle_false = C.throttle_false + 1 end

                -- The plan 'pullthink' is scoped to (and 'pulllane' produces).
                -- ⚠️ ARMED, and in turbo.  Read unarmed this count is CONFOUNDED:
                -- the helper's first two lines are IsModeTurbo + the 'pullcamp'
                -- gate, so a nil would only prove the gate is shut -- not that
                -- the camp roster is the wall.  Arming makes the reading say
                -- what the ruling needs it to say.
                local okP, plan = pcall(function()
                    local realSoak, realTurbo = J.IsSoakCandidate, J.IsModeTurbo
                    J.IsSoakCandidate = function(sId)
                        return sId == 'pullcamp' or sId == 'pulllane'
                            or sId == 'pullthink'
                    end
                    J.IsModeTurbo = function() return true end
                    local ok2, r = pcall(J.ShouldPullNeutralCamp, h)
                    J.IsSoakCandidate, J.IsModeTurbo = realSoak, realTurbo
                    if not ok2 then error(r) end
                    return r
                end)
                if not okP then C.camppull_err = C.camppull_err + 1
                elseif plan ~= nil then C.camppull_nonnil = C.camppull_nonnil + 1
                else C.camppull_nil = C.camppull_nil + 1 end

                -- POSITIVE CONTROL.  "Armed and still nil" only means "the camp
                -- roster is the wall" if supplying a roster moves the reading.
                -- Same frame, same arming, one synthetic own-team camp 600u off
                -- the bot -- and a counter on the 'pulllane' clause itself, so
                -- the sweep reports whether the lever's pivot was ever REACHED
                -- rather than inferring it from the roster being empty.
                local okC = pcall(function()
                    local realSoak, realTurbo = J.IsSoakCandidate, J.IsModeTurbo
                    local realSpawn, realBeside = _G.GetNeutralSpawners, J.IsCampBesideLane
                    local vBot = h:GetLocation()
                    J.IsSoakCandidate = function(sId)
                        return sId == 'pullcamp' or sId == 'pulllane'
                            or sId == 'pullthink'
                    end
                    J.IsModeTurbo = function() return true end
                    _G.GetNeutralSpawners = function()
                        return { { team = h:GetTeam(),
                                   location = rf.Vector and rf.Vector(vBot.x + 600, vBot.y, 0)
                                              or { x = vBot.x + 600, y = vBot.y, z = 0 } } }
                    end
                    J.IsCampBesideLane = function(vCamp, tLanePath)
                        C.beside_calls = C.beside_calls + 1
                        if tLanePath ~= nil then C.beside_path_supplied = C.beside_path_supplied + 1 end
                        return realBeside(vCamp, tLanePath)
                    end
                    local ok2, r = pcall(J.ShouldPullNeutralCamp, h)
                    J.IsSoakCandidate, J.IsModeTurbo = realSoak, realTurbo
                    _G.GetNeutralSpawners, J.IsCampBesideLane = realSpawn, realBeside
                    if ok2 and r ~= nil then C.control_nonnil = C.control_nonnil + 1 end
                end)
                if not okC then C.control_err = C.control_err + 1 end
            end
        end
    end
end

-- meaningfulActivities is a file-local in utils.lua; read the globals it is
-- BUILT from, so the ruling quotes what the mock actually serves rather than
-- what a 2026-08-25 comment said it served.
local acts = { 'ACTIVITY_RUN', 'ACTIVITY_ATTACK', 'ACTIVITY_ATTACK2',
               'ACTIVITY_CAST_ABILITY_1', 'ACTIVITY_CHANNEL_ABILITY_1' }

say('=== corpus ===')
say(string.format('fixtures loaded          %d   (unloadable %d)', C.fixtures, C.unloadable))
say(string.format('hero handles             %d', C.heroes))
say('')
say("=== 'pulllane' ===")
say(string.format('GetNeutralSpawners frames %d   empty %d   non-empty %d   camp handles %d',
    C.spawners_frames, C.spawners_empty, C.spawners_nonempty, C.spawner_handles))
say(string.format('GetLocationAlongLane samples %d   at map origin %d   DISTINCT points %d',
    C.lane_samples, C.lane_origin, C.lane_distinct))
say('')
say("=== 'pullthink' ===")
say(string.format('GetAnimActivity calls    %d   zero %d   non-zero %d',
    C.anim_calls, C.anim_zero, C.anim_nonzero))
local vals = {}
for k in pairs(anim_values) do vals[#vals + 1] = k end
table.sort(vals)
for _, k in ipairs(vals) do
    say(string.format('   value %-8s x%d', k, anim_values[k]))
end
say(string.format('IsBotThinkingMeaningfulAction  true %d   false %d   error %d',
    C.throttle_true, C.throttle_false, C.throttle_err))
say(string.format('ShouldPullNeutralCamp (ARMED)  non-nil %d   nil %d   error %d',
    C.camppull_nonnil, C.camppull_nil, C.camppull_err))
say(string.format('  positive control (+1 synthetic camp)  non-nil %d   error %d',
    C.control_nonnil, C.control_err))
say(string.format('  J.IsCampBesideLane reached            %d call(s)  (path supplied %d)',
    C.beside_calls, C.beside_path_supplied))
say('')
say('=== ACTIVITY_* globals as the mock serves them ===')
for _, k in ipairs(acts) do
    say(string.format('   %-28s %s', k, tostring(_G[k])))
end

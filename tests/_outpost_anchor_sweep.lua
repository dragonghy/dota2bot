-- Corpus census for the OUTPOST-AS-ALLIED-BUILDING anchor, run as a SUBPROCESS
-- (backlog 0q: a full-corpus drive that rebuilds jmz_func once per hero-frame
-- must not run on run_tests.lua's long-lived heap). The leading underscore
-- keeps run_tests.lua from globbing it.
--
-- WHAT IS MEASURED, AND WHY IT IS A DIFFERENT FAMILY FROM GH #782.
--
-- GH #782 was filed as a NAME TEST defect: `string.find( b:GetUnitName(),
-- 'tower' )` matches `npc_dota_watch_tower`, so a captured outpost reads as a
-- defensible tower. Three sites were counted there, and every one of them has
-- a name test to narrow.
--
-- ⭐ The family is LARGER than the name test, and this file measures the half
-- GH #782's narrowing cannot reach. A captured outpost is a member of
-- `GetUnitList( UNIT_LIST_ALLIED_BUILDINGS )` and it passes
-- `J.IsValidBuilding` (= `IsValidUnit and unit:IsBuilding()`), so every reader
-- that uses the list as a PROXIMITY ANCHOR and carries NO name test at all is
-- contaminated too -- and there is nothing there for a name-test fix to
-- narrow. Measured membership, not argued: see `wt_*` below.
--
-- The two no-name-test anchor sites in bots/:
--   * J.ShouldRefuseUnsupportedPunish ('ohnum'): a live allied building within
--     1200 of the target RELEASES the refusal, and the release's own stated
--     reason is "the tower is the ally the count does not name, so parity
--     there is really parity plus a tower". An outpost has no attack: it is
--     not an ally any count would want to name. Direction: a spurious RELEASE,
--     i.e. the bot keeps a parity/1v1 punish the lever exists to refuse.
--   * J.ShouldPunishOverchase leg (b) ('overchase'): an allied building within
--     1200 of the chaser sets DEEP, and its own prose calls that "a hard fact
--     about whose ground this is". A river outpost is the one structure that
--     is NOT a fact about whose ground this is. Direction: a spurious DEEP,
--     i.e. a collapse authorised at the midline -- the shape AGENTS.md records
--     as costing a batch run.
--
-- Readings, so a zero can be attributed to the leg that produced it:
--   * wt_fixtures / wt_allied / wt_valid -- the membership fact itself: how
--     many fixtures carry an allied outpost, how many appear in the allied
--     list, and how many of those pass J.IsValidBuilding. wt_valid == wt_allied
--     is the finding; wt_valid == 0 would retire this whole file.
--   * oa_pairs            -- (subject, visible enemy hero within 1600) pairs.
--   * oa_anchor           -- an allied building within 1200 of the target.
--   * oa_anchor_wt_only   -- ...and EVERY one of them is an outpost. This is
--                            the narrowing's domain at the ohnum site.
--   * oa_wt_only_would_refuse -- of those, how many would refuse once the
--                            outposts are discounted (not lethal AND
--                            #allies < #enemies + 1). This is the FLIP set:
--                            the frames where the narrowing changes an answer.
--   * ov_deep_building / ov_deep_building_wt_only -- the same two readings at
--                            the overchase DEEP site, on its own disc.
--
-- ⚠ CORPUS LIMITS, registered rather than worked around:
--   (i) the mock's GetEstimatedDamageToTarget answers 0 on every frame, so the
--       LETHAL release of the ohnum body can never fire here. Every reading
--       below is therefore a numbers-branch reading, and
--       `oa_wt_only_would_refuse` is an UPPER BOUND on the live flip set.
--   (ii) an outpost's TEAM in a fixture is the team the dump recorded holding
--       it at that instant. An UNCAPTURED outpost belongs to neither side and
--       would not appear in either list; nothing here asserts how often that
--       is the case in a real game.
--
-- Every threshold is PARSED OUT OF THE SHIPPED SOURCE, never hardcoded (the
-- M13 lesson): move a number in jmz_func and this census moves with it. A
-- failed parse prints as `nil`, never as a zero (the GH #171 shape).
--
-- Manifest grammar (one record per line, space-separated):
--   G <name> <value>            a constant / structural fact parsed out of the tree
--   C <key> <n>                 a counter bucket
--   F <fixture> <hero> <what>   one live frame in a named domain
--   DONE
-- Absence of the final DONE line is a failed subprocess.

package.path = 'tests/?.lua;' .. package.path

-- ⛔ tests/mock/bot_api.lua replaces the global `print` with an empty function
-- when a fixture loads, so every write after the first rf.load would vanish
-- while the exit code stayed 0 (the lesson this group paid for in
-- tests/test_overchase_pursuit_tense.lua). Bind the real writer FIRST.
local out = io.stdout

local rf = require('mock.replay_fixture')

local JMZ = 'bots/FunLib/jmz_func.lua'

local function read_file(path)
    local f = assert(io.open(path, 'r'), path .. ' is not readable')
    local s = f:read('*a')
    f:close()
    return s
end

local function block(src, header)
    local at = src:find(header, 1, true)
    if at == nil then return nil end
    local stop = src:find('\nfunction J.', at + 10) or #src
    return src:sub(at, stop)
end

local G = {}
local src = read_file(JMZ)
local refuse = block(src, 'function J.ShouldRefuseUnsupportedPunish( bot, target )')
local chase = block(src, 'function J.ShouldPunishOverchase( bot )')
G.REFUSE = refuse and 1 or 0
G.CHASE = chase and 1 or 0
G.REFUSE_BUILDING_R = refuse and tonumber(refuse:match('target, building %) <= (%d+)'))
G.REFUSE_ALLY_R = refuse and tonumber(refuse:match('GetAlliesNearLoc%( vLoc, (%d+) %)'))
G.REFUSE_ENEMY_R = refuse and tonumber(refuse:match('GetEnemiesNearLoc%( vLoc, (%d+) %)'))
G.CHASE_COLLAPSE_R = chase and tonumber(chase:match('GetNearbyHeroes%( bot, (%d+), true'))
G.CHASE_BUILDING_R = chase and tonumber(chase:match('building %) <= (%d+)'))
-- The outpost unit name, parsed out of J.IsOutpostBuilding -- the canonical
-- predicate the narrowing calls -- rather than typed here, so the census and
-- the shipped narrowing can never disagree about what an outpost is.
local outpost = block(src, 'function J.IsOutpostBuilding( nTarget )')
G.OUTPOST_NAME = outpost and outpost:match("GetUnitName%(%)%s*,%s*'([%w_]+)'%s*%)")

-- ⛔ `pairs` SKIPS A NIL, so a failed parse would vanish from the manifest
-- entirely rather than print as `nil` -- which is the very GH #171 shape the
-- header promises not to commit. The key list is therefore explicit.
local gk = { 'CHASE', 'CHASE_BUILDING_R', 'CHASE_COLLAPSE_R', 'OUTPOST_NAME',
    'REFUSE', 'REFUSE_ALLY_R', 'REFUSE_BUILDING_R', 'REFUSE_ENEMY_R' }
for _, k in ipairs(gk) do out:write(string.format('G %s %s\n', k, tostring(G[k]))) end

local OUTPOST = G.OUTPOST_NAME or 'watch_tower'

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
-- Zero-initialised so "the bucket was never reached" and "the bucket measured
-- zero" are never the same thing to the parser (the GH #171 shape).
for _, k in ipairs({ 'fixtures', 'live', 'wt_fixtures', 'wt_allied', 'wt_valid',
    'oa_pairs', 'oa_anchor', 'oa_anchor_has_wt', 'oa_anchor_wt_only',
    'oa_wt_only_would_refuse', 'ov_deep_building', 'ov_deep_building_wt_only',
    'oa_wt_within_2400', 'oa_wt_within_4800', 'raised' }) do
    rawset(c, k, 0)
end
-- ⭐ THE POSITIVE CONTROL FOR A NEGATIVE READING (this group's own rule: a
-- negative reading's control must be a number that MUST come out smaller, never
-- the no-op assertions themselves). `oa_anchor_wt_only` is expected to be a
-- zero, and a broken distance instrument -- an outpost handle whose
-- GetUnitToUnitDistance answers a fabricated constant, say -- would produce that
-- zero for free and look exactly like a real one. So the same instrument is
-- also read at two WIDER radii and the closest outpost distance ever seen is
-- reported: those MUST be non-zero / finite, and they attribute the zero to
-- GEOMETRY (no outpost is ever that close to a visible enemy) rather than to a
-- dead measurement.
local nMinWtDist = nil

local function is_outpost(h)
    local ok, n = pcall(h.GetUnitName, h)
    return ok and n ~= nil and string.find(n, OUTPOST) ~= nil
end

for _, path in ipairs(fixture_files()) do
    local fx = dofile(path)
    if type(fx) == 'table' and fx.units and fx.time then
        bump('fixtures')
        local short = path:match('([^/]+)%.lua$')
        local bWt = false
        for _, b in ipairs(fx.buildings or {}) do
            if string.find(tostring(b.name), OUTPOST) ~= nil then bWt = true end
        end
        if bWt then bump('wt_fixtures') end

        local bCountedMembership = false
        for _, u in ipairs(fx.units) do
            if u.alive then
                local ok, J, bot = pcall(rf.load, path, u.name)
                if ok and bot ~= nil then
                    bump('live')

                    -- (1) THE MEMBERSHIP FACT, counted once per fixture so it
                    -- reads as "this many fixtures put an outpost in the
                    -- allied list", not as a per-subject multiple.
                    if not bCountedMembership then
                        bCountedMembership = true
                        for _, b in pairs(GetUnitList(UNIT_LIST_ALLIED_BUILDINGS) or {}) do
                            if is_outpost(b) then
                                bump('wt_allied')
                                if J.IsValidBuilding(b) then bump('wt_valid') end
                            end
                        end
                    end

                    -- (2) The two anchor sites, re-derived on the real frame.
                    local okP, tE = pcall(J.GetNearbyHeroes, bot,
                        G.CHASE_COLLAPSE_R or 1600, true, BOT_MODE_NONE)
                    if not okP then
                        bump('raised')
                    else
                        for _, e in pairs(tE or {}) do
                            if J.IsValidHero(e) and not J.IsSuspiciousIllusion(e) then
                                bump('oa_pairs')
                                local vE = e:GetLocation()

                                -- ohnum's release loop, verbatim in shape.
                                local nAnchor, nAnchorWt = 0, 0
                                for _, b in pairs(GetUnitList(UNIT_LIST_ALLIED_BUILDINGS) or {}) do
                                    if J.IsValidBuilding(b)
                                        and GetUnitToUnitDistance(e, b) <= (G.REFUSE_BUILDING_R or 1200) then
                                        nAnchor = nAnchor + 1
                                        if is_outpost(b) then nAnchorWt = nAnchorWt + 1 end
                                    end
                                end
                                -- The positive control, on the SAME handles and
                                -- the SAME distance call the anchor loop used.
                                for _, b in pairs(GetUnitList(UNIT_LIST_ALLIED_BUILDINGS) or {}) do
                                    if J.IsValidBuilding(b) and is_outpost(b) then
                                        local d = GetUnitToUnitDistance(e, b)
                                        if nMinWtDist == nil or d < nMinWtDist then nMinWtDist = d end
                                        if d <= 2400 then bump('oa_wt_within_2400') end
                                        if d <= 4800 then bump('oa_wt_within_4800') end
                                    end
                                end

                                if nAnchor > 0 then
                                    bump('oa_anchor')
                                    if nAnchorWt > 0 then bump('oa_anchor_has_wt') end
                                    if nAnchorWt == nAnchor then
                                        bump('oa_anchor_wt_only')
                                        out:write(string.format('F %s %s oa_anchor_wt_only %s\n',
                                            short, u.name, (e:GetUnitName():gsub('npc_dota_hero_', ''))))
                                        -- Would the rest of the refusal fire?
                                        local tA = J.GetAlliesNearLoc(vE, G.REFUSE_ALLY_R or 1200) or {}
                                        local tEn = J.GetEnemiesNearLoc(vE, G.REFUSE_ENEMY_R or 1200) or {}
                                        local bLethal = J.GetTotalEstimatedDamageToTarget(tA, e)
                                            >= e:GetHealth() + e:GetHealthRegen() * 5.0
                                        if not bLethal and #tA < #tEn + 1 then
                                            bump('oa_wt_only_would_refuse')
                                            out:write(string.format('F %s %s oa_flip %s a%d_e%d\n',
                                                short, u.name,
                                                (e:GetUnitName():gsub('npc_dota_hero_', '')),
                                                #tA, #tEn))
                                        end
                                    end
                                end

                                -- overchase leg (b), the DEEP building branch.
                                local nDeep, nDeepWt = 0, 0
                                for _, b in pairs(GetUnitList(UNIT_LIST_ALLIED_BUILDINGS) or {}) do
                                    if J.IsValidBuilding(b)
                                        and GetUnitToUnitDistance(e, b) <= (G.CHASE_BUILDING_R or 1200) then
                                        nDeep = nDeep + 1
                                        if is_outpost(b) then nDeepWt = nDeepWt + 1 end
                                    end
                                end
                                if nDeep > 0 then
                                    bump('ov_deep_building')
                                    if nDeepWt == nDeep then bump('ov_deep_building_wt_only') end
                                end
                            end
                        end
                    end
                end
            end
        end
    end
end

local ck = {}
for k in pairs(c) do ck[#ck + 1] = k end
table.sort(ck)
for _, k in ipairs(ck) do out:write(string.format('C %s %d\n', k, c[k])) end
-- Printed as a G record, not a C record: it is a distance, not a count, and it
-- is the reading that says the instrument was alive when it answered zero.
out:write(string.format('G MIN_WT_TO_ENEMY_DIST %s\n',
    nMinWtDist and string.format('%.1f', nMinWtDist) or 'nil'))
out:write('DONE\n')

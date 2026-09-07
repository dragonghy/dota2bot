-- Corpus census for the 'overchase' (d) leg, run as a SUBPROCESS (backlog 0q:
-- a full-corpus drive that rebuilds jmz_func once per hero-frame must not run
-- on run_tests.lua's long-lived heap). The leading underscore keeps
-- run_tests.lua from globbing it.
--
-- WHAT IS MEASURED, AND WHY IT IS A CENSUS AND NOT AN ARGUMENT.
--
-- J.ShouldPunishOverchase's four conjuncts are not independent. Leg (a)
-- REQUIRES a sub-0.5-HP ally that is not this bot within CHASE_ALLY_R of the
-- chaser; leg (d) then asks J.SafeToCommitFight( bot, enemy ), whose numbers
-- branch counts J.GetAlliesNearLoc( enemyLoc, 1200 ). CHASE_ALLY_R is 900, so
-- the (a) disc is a STRICT SUBSET of the (d) disc: on every frame that reaches
-- (d), the dying ally whose imminent death is the whole reason to collapse is
-- also one of the bodies that authorises the collapse. That is a structural
-- double count, not an occasional one -- it is entailed by the guard's own
-- trigger.
--
-- AGENTS.md records this shape as the case that cost a batch run ("visible 2v2
-- parity counted the dying bot as a full fighter"), and the fix there was
-- narrowed at the fixture level. This census prices the same shape here BEFORE
-- a lever is written, because 0GRENHARASS/0PINEVADE both ended in "priced, then
-- refused" when the domain measured 0.
--
-- Readings, so a zero can be attributed to the leg that produced it:
--   * oc_iso_deep       -- pairs clearing (b)+(c), the cheap legs
--   * oc_a_pass         -- of those, how many clear (a)
--   * oc_ad_pass        -- of those, how many ALSO clear (d)  == the fires set
--   * oc_d_lethal       -- (d) answers true on the LETHAL branch
--   * oc_d_numbers      -- (d) answers true on the NUMBERS branch
--   * oc_d_numbers_thin -- numbers branch true, and it FLIPS to false once the
--                          sub-0.5-HP allies in the 1200 disc are discounted.
--                          This is the priced domain of the lever.
--   * oc_d_numbers_tie  -- of the thin ones, how many were a literal tie
--                          (#allies == #enemies) rather than an advantage.
--
-- ⚠ TWO CORPUS LIMITS THIS FILE CANNOT CLOSE, both registered rather than
-- worked around (GH #611):
--   (i) the mock's GetEstimatedDamageToTarget answers 0 on every frame, so the
--       LETHAL branch of J.SafeToCommitFight can never fire here.
--       `oc_d_lethal` is therefore expected to be 0 BY CONSTRUCTION, and every
--       (d) pass in this corpus is a numbers-branch pass. A real frame may
--       release on lethality where this corpus cannot, so oc_d_numbers_thin is
--       an UPPER BOUND on how often the lever would change the answer.
--   (ii) bot:GetAttackRange() answers 150 for every hero, so nothing here reads
--       "can we actually reach it". That is 'roamreach's question, not this
--       one.
--
-- Every threshold is PARSED OUT OF THE SHIPPED SOURCE, never hardcoded (the M13
-- lesson): move a number in jmz_func and this census moves with it. A failed
-- parse prints as `nil`, never as a zero (the GH #171 shape).
--
-- Manifest grammar (one record per line, space-separated):
--   G <name> <value>            a constant / structural fact parsed out of the tree
--   C <key> <n>                 a counter bucket
--   F <fixture> <hero> <what>   one live frame in a named domain
--   DONE
-- Absence of the final DONE line is a failed subprocess.

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')

local out = io.stdout
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
local chase = block(src, 'function J.ShouldPunishOverchase( bot )')
local safe = block(src, 'function J.SafeToCommitFight( bot, target )')
G.CHASE = chase and 1 or 0
G.SAFE = safe and 1 or 0
G.CHASE_COLLAPSE_R = chase and tonumber(chase:match('GetNearbyHeroes%( bot, (%d+), true'))
G.CHASE_ISOLATED_R = chase and tonumber(chase:match('GetEnemiesNearLoc%( vEnemyLoc, (%d+) %)'))
G.CHASE_ALLY_R = chase and tonumber(chase:match('GetAlliesNearLoc%( vEnemyLoc, (%d+) %)'))
G.CHASE_LOW_HP = chase and tonumber(chase:match('GetHP%( ally %) < (0%.%d+)'))
G.CHASE_OWNHALF = chase and tonumber(chase:match('hEnemyAncient:GetLocation%(%) %) %- (%d+)'))
G.CHASE_BUILDING_R = chase and tonumber(chase:match('building %) <= (%d+)'))
-- The (d) disc. This is the number that makes the double count structural: it
-- is read off SafeToCommitFight, not off the caller, and the finding is the
-- comparison CHASE_ALLY_R <= SAFE_ALLY_R.
G.SAFE_ALLY_R = safe and tonumber(safe:match('GetAlliesNearLoc%( vLoc, (%d+) %)'))
G.SAFE_ENEMY_R = safe and tonumber(safe:match('GetEnemiesNearLoc%( vLoc, (%d+) %)'))
-- The tree's OTHER fog margin, parsed rather than typed: SafeToCommitFight's
-- 'depthnum' branch. It is the number this census compares leg (b)'s midline
-- branch against, and it must move when that branch moves.
G.DEPTHNUM_MARGIN = safe and tonumber(safe:match('hOwnAncient:GetLocation%(%) %) %- (%d+)'))
G.A_DISC_INSIDE_D_DISC =
    (G.CHASE_ALLY_R and G.SAFE_ALLY_R and G.CHASE_ALLY_R <= G.SAFE_ALLY_R) and 1 or 0

local gk = {}
for k in pairs(G) do gk[#gk + 1] = k end
table.sort(gk)
for _, k in ipairs(gk) do out:write(string.format('G %s %s\n', k, tostring(G[k]))) end

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
for _, k in ipairs({ 'fixtures', 'live', 'oc_pairs', 'oc_iso_deep', 'oc_a_pass',
    'oc_ad_pass', 'oc_d_lethal', 'oc_d_numbers', 'oc_d_numbers_thin',
    'oc_d_numbers_tie', 'oc_fires', 'oc_raised',
    'oc_a_lowally_present', 'oc_a_pursuit_unseen',
    'oc_a_attacktarget', 'oc_a_ischasing', 'oc_a_recentdmg',
    'oc_deep_building', 'oc_deep_midline', 'oc_deep_midline_shallow',
    'oc_iso_deep_building', 'oc_iso_deep_midline',
    'oc_fire_building', 'oc_fire_midline', 'oc_fire_midline_shallow' }) do
    rawset(c, k, 0)
end

for _, path in ipairs(fixture_files()) do
    local fx = dofile(path)
    if type(fx) == 'table' and fx.units and fx.time then
        bump('fixtures')
        local short = path:match('([^/]+)%.lua$')
        for _, u in ipairs(fx.units) do
            if u.alive then
                local ok, J, bot = pcall(rf.load, path, u.name)
                if ok and bot ~= nil then
                    bump('live')
                    local armed = { overchase = true }
                    J.IsSoakCandidate = function(id) return armed[id] == true end

                    local tE = J.GetNearbyHeroes(bot, G.CHASE_COLLAPSE_R or 1600,
                        true, BOT_MODE_NONE) or {}
                    for _, e in pairs(tE) do
                        if J.IsValidHero(e) and not J.IsSuspiciousIllusion(e)
                            and not J.IsMeepoClone(e) then
                            bump('oc_pairs')
                            local vE = e:GetLocation()
                            local bIso =
                                #J.GetEnemiesNearLoc(vE, G.CHASE_ISOLATED_R or 1400) <= 1
                            local bDeep = false
                            local bMidlineShallow = false
                            for _, b in pairs(GetUnitList(UNIT_LIST_ALLIED_BUILDINGS) or {}) do
                                if J.IsValidBuilding(b)
                                    and GetUnitToUnitDistance(e, b) <= (G.CHASE_BUILDING_R or 1200) then
                                    bDeep = true
                                    break
                                end
                            end
                            -- Provenance of (b), so "deep" is never one number.
                            -- The building branch is a HARD fact (a live
                            -- structure of ours is right there); the ancient
                            -- branch is a soft midline read, and 800u past the
                            -- midline is shallow enough that the two deserve
                            -- separate buckets.
                            if bDeep then bump('oc_deep_building') end
                            local bDeepBuilding = bDeep
                            if not bDeep then
                                local hO, hEn = GetAncient(GetTeam()), GetAncient(GetOpposingTeam())
                                if hO ~= nil and hEn ~= nil then
                                    bDeep = J.GetLocationToLocationDistance(vE, hO:GetLocation())
                                        < J.GetLocationToLocationDistance(vE, hEn:GetLocation())
                                            - (G.CHASE_OWNHALF or 800)
                                    if bDeep then bump('oc_deep_midline') end
                                    -- What the tree's OTHER fog-margin (the
                                    -- 'depthnum' branch of SafeToCommitFight,
                                    -- "same ancient-distance convention as
                                    -- J.ShouldRegroupNotSolo") would say here.
                                    -- Counted, not assumed: a narrowing whose
                                    -- domain is 0 is refused, not shipped.
                                    if bDeep
                                        and not (J.GetLocationToLocationDistance(vE, hO:GetLocation())
                                            < J.GetLocationToLocationDistance(vE, hEn:GetLocation())
                                                - (G.DEPTHNUM_MARGIN or 1600)) then
                                        bump('oc_deep_midline_shallow')
                                        bMidlineShallow = true
                                    end
                                end
                            end

                            if bIso and bDeep then
                                bump('oc_iso_deep')
                                if bDeepBuilding then bump('oc_iso_deep_building')
                                else bump('oc_iso_deep_midline') end
                                -- (a), re-derived exactly as the shipped body
                                -- states it: not this bot, sub-threshold, and
                                -- the chaser is on it.
                                local bLowAlly = false
                                local bLowAllyPresent = false
                                for _, a in pairs(J.GetAlliesNearLoc(vE, G.CHASE_ALLY_R or 900) or {}) do
                                    if J.IsValidHero(a) and a ~= bot
                                        and not J.IsSuspiciousIllusion(a)
                                        and J.GetHP(a) < (G.CHASE_LOW_HP or 0.5) then
                                        -- Split so "there is nobody to rescue"
                                        -- and "there is somebody, but the
                                        -- chaser is not visibly on them" are
                                        -- never the same reading. The three
                                        -- pursuit tests are counted apart
                                        -- because a corpus can be blind to some
                                        -- of them (GH #611 shape).
                                        bLowAllyPresent = true
                                        local bTgt = (e:GetAttackTarget() == a)
                                        local bChase = J.IsChasingTarget(e, a)
                                        local bDmg = a:WasRecentlyDamagedByHero(e, 2.0)
                                        if bTgt then bump('oc_a_attacktarget') end
                                        if bChase then bump('oc_a_ischasing') end
                                        if bDmg then bump('oc_a_recentdmg') end
                                        if bTgt or bChase or bDmg then
                                            bLowAlly = true
                                            break
                                        end
                                    end
                                end
                                if bLowAllyPresent then
                                    bump('oc_a_lowally_present')
                                    if not bLowAlly then
                                        bump('oc_a_pursuit_unseen')
                                        out:write(string.format(
                                            'F %s %s oc_a_pursuit_unseen\n', short, u.name))
                                    end
                                end
                                if bLowAlly then
                                    bump('oc_a_pass')
                                    out:write(string.format('F %s %s oc_a_pass\n', short, u.name))

                                    -- (d), attributed branch by branch. The
                                    -- shipped function is driven for the
                                    -- ANSWER; the branches are re-derived here
                                    -- only to say WHICH one produced it.
                                    local bSafe = J.SafeToCommitFight(bot, e)
                                    local tA = J.GetAlliesNearLoc(vE, G.SAFE_ALLY_R or 1200) or {}
                                    local nBurst = J.GetTotalEstimatedDamageToTarget(tA, e)
                                    local bLethal =
                                        nBurst >= e:GetHealth() + e:GetHealthRegen() * 5.0
                                    local nEnemy = #J.GetEnemiesNearLoc(vE, G.SAFE_ENEMY_R or 1200)
                                    -- Discount the bodies that are themselves
                                    -- sub-threshold: the corpse-count reading.
                                    local nFit = 0
                                    for _, a in pairs(tA) do
                                        if J.IsValidHero(a)
                                            and not J.IsSuspiciousIllusion(a)
                                            and J.GetHP(a) >= (G.CHASE_LOW_HP or 0.5) then
                                            nFit = nFit + 1
                                        end
                                    end
                                    if bSafe then
                                        bump('oc_ad_pass')
                                        if bDeepBuilding then bump('oc_fire_building')
                                        else
                                            bump('oc_fire_midline')
                                            -- THE PRICE OF THE LEVER, on the
                                            -- only rows that matter: firings
                                            -- the deeper margin would refuse.
                                            if bMidlineShallow then
                                                bump('oc_fire_midline_shallow')
                                                out:write(string.format(
                                                    'F %s %s oc_fire_midline_shallow\n',
                                                    short, u.name))
                                            end
                                        end
                                        if bLethal then bump('oc_d_lethal')
                                        else
                                            bump('oc_d_numbers')
                                            if nFit < nEnemy then
                                                bump('oc_d_numbers_thin')
                                                out:write(string.format(
                                                    'F %s %s oc_thin a=%d fit=%d e=%d\n',
                                                    short, u.name, #tA, nFit, nEnemy))
                                                if #tA == nEnemy then bump('oc_d_numbers_tie') end
                                            end
                                        end
                                    end
                                end
                            end
                        end
                    end
                    local okc, ctgt = pcall(J.ShouldPunishOverchase, bot)
                    if not okc then bump('oc_raised')
                    elseif ctgt ~= nil then
                        bump('oc_fires')
                        out:write(string.format('F %s %s oc_fires\n', short, u.name))
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
out:write('DONE\n')

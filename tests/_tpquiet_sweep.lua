-- Heavy corpus sweep for tests/test_tpquiet_shadowed_branch.lua, run as a
-- SUBPROCESS (a full-corpus drive that reloads the mock world once per
-- hero-frame must not run on run_tests.lua's long-lived heap).  The leading
-- underscore keeps run_tests.lua from globbing it (it globs `^test_.*%.lua$`).
--
-- WHAT IS MEASURED.  X.ConsiderItemDesire["item_tpscroll"] contains four
-- home-TP branches IN SOURCE ORDER, and every one of them RETURNS.  So a veto
-- bolted onto a LATER branch is unreachable on any frame an EARLIER branch
-- already claims.  Three ids from this family live on the '回复状态' branch
-- ('tprecov', 'tpdeep') or on '撤退:3' ('stayfield'); NOTHING has ever asked
-- whether '撤退:1' -- which is upstream of all of them -- gets there first.
--
-- ⭐ THE COLUMN THIS FILE EXISTS FOR: `tpdeep_true_in_r4_shadowed`.  It counts
-- frames where the sibling helper answers TRUE, the '回复状态' trigger is open
-- (so the sibling's own domain reading counts the frame), AND the upstream
-- '撤退:1' trigger is open too -- i.e. frames the sibling is credited with and
-- can never actually reach.  A non-zero here is a statement about the SIBLING's
-- published reading, so it is measured on the SHIPPED sibling function, never
-- re-implemented.
--
-- ⭐⭐ THE CLAIM "SAME CONSTANTS AS THE SIBLING" IS ARITHMETIC BETWEEN TWO
-- PARSED FUNCTIONS, NOT PROSE.  This lever's entire licence is that it re-asks
-- an opinion the family already formed, so a drift in either function must go
-- red.  Both helpers' five constants are parsed off the stripped source and
-- compared pairwise downstream.  The new helper names its constants (the
-- sibling inlines them) for GH #550: a byte-identical line would make
-- tools/agent/mutstand_tpdeep.sh's anchors AMBIGUOUS and abort the SIBLING's
-- whole stand under the sibling's name.
--
-- ⛔ DIRECTION GOES THROUGH A COUNTER THAT IS PROVED TO COUNT.  This lever
-- appends a veto, so it can only turn the branch's TRUE into FALSE and
-- `flip_false_to_true` must be 0 over the whole corpus.  A counter whose content
-- is all zeros cannot tell "the direction holds" from "the tally never ran", so
-- both directions go through ONE `tally(a, b, sDown, sUp)` called a SECOND time
-- with the legs SWAPPED: the branch that must read 0 on the real call is the
-- branch that must report the WHOLE domain on the swapped call.
--
-- ⛔ THE OVERLAP COLUMN IS DELIBERATELY NOT ASSERTED TO ZERO, and that is the
-- one place this file departs from tests/_tpdeep_sweep.lua.  That sweep asserts
-- `overlap 0` because 'tprecov' and 'tpdeep' SHARE a call site, where disjoint
-- bands are the only thing that makes a single-arm wave attributable.  This
-- lever shares a call site with nobody: it is the same predicate at an EARLIER
-- branch, so an overlapping frame is the POINT, not a defect.  What must hold
-- instead is that on every overlapping frame the source order decides, and that
-- is pinned STRUCTURALLY (`T1_RETURN_BEFORE_R4`), never by a count.
--
-- ⚠️ WHAT THIS FILE DOES NOT DRIVE.  `X` in ability_item_usage_generic is a
-- FILE-LOCAL table, so neither branch's body can be called from here and neither
-- can `X.CanJuke()` / `X.GetNumHeroWithinRange()`.  Both `*_trigger` columns are
-- therefore UPPER BOUNDS on reachability, never claims that a branch fires --
-- same shape and same reason as tests/_tpdeep_sweep.lua and
-- tests/test_stayfield_callsite_domain.lua.  The shadow claim is ROBUST to that
-- looseness in the direction that matters: both bounds are over-permissive, so
-- a frame counted as shadowed could only stop being shadowed if the '撤退:1'
-- bound is loose on it -- which is why the row for every shadowed frame is
-- printed, not just its count.
--
-- Manifest grammar (one record per line, space-separated):
--   G <name> <value>    a constant / structural fact parsed out of the tree
--   C <key> <n>         a counter bucket
--   R <fixture> <hero> <hp> <lvl> <stop>
--       one live frame inside the '撤退:1' trigger, with the clause that stops
--       J.ShouldSipNotTpQuietHome: band_high | band_low | source | damage |
--       ring | tower | domain.  (The gate and the turbo check are NOT walked
--       here -- the walk runs below them by construction, and they are driven
--       instead by the shipped-vs-armed columns above.)  Every trigger frame
--       gets a row, in the domain or not -- the anti-vacuum column.
--   S <fixture> <hero> <hp> <lvl>
--       one SHADOWED frame: the sibling answers TRUE, its own branch trigger is
--       open, and '撤退:1' is open too.
--   DONE
-- Absence of the final DONE line is a failed subprocess.

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')

local out = io.stdout
local AIUG = 'bots/ability_item_usage_generic.lua'
local JMZ = 'bots/FunLib/jmz_func.lua'

local function read_file(path)
    local f = assert(io.open(path, 'r'), path .. ' is not readable')
    local s = f:read('*a')
    f:close()
    return s
end

-- Structural facts are claims about CODE.  This lever ships with a long comment
-- that names its own sibling, both bands and every radius, so reading the raw
-- block would let the COMMENT satisfy the assertions (the §EN mistake).
local function strip_comments(s)
    if s == nil then return nil end
    return (s:gsub('%-%-[^\n]*', ''))
end

--- The text of one home-TP branch, from its trigger to its own cast motive.
--- Anchored on the motive STRING (code, never a comment).
local function branch(src, sHead, sMotive)
    local a = src:find(sHead, 1, true)
    if a == nil then return nil end
    local b = src:find("sCastMotive = '" .. sMotive .. "'", a, true)
    if b == nil then return nil end
    return strip_comments(src:sub(a, b))
end

local function count(s, needle)
    if s == nil then return 0 end
    local n, at = 0, 1
    while true do
        local i = s:find(needle, at, true)
        if i == nil then break end
        n = n + 1
        at = i + 1
    end
    return n
end

local aiug = read_file(AIUG)
local jmz = read_file(JMZ)
local aiug_bare = strip_comments(aiug)

local G = {}

local b1 = branch(aiug, 'if botHP < 0.19', '撤退:1')
local b4 = branch(aiug, 'if ( botHP + botMP < 0.3 or botHP < 0.2 )', '回复状态')
G.BRANCH_T1 = b1 and 1 or 0
G.BRANCH_R4 = b4 and 1 or 0

-- ⭐ THE STRUCTURAL PIN THE WHOLE LEVER RESTS ON.  '撤退:1' must RETURN, and it
-- must do so BEFORE the '回复状态' trigger is reached, or "upstream" is not a
-- fact about this file.  Both positions are read off the COMMENT-STRIPPED
-- source so a comment mentioning either marker cannot satisfy this.
local at_t1_ret = aiug_bare:find("return BOT_ACTION_DESIRE_HIGH, tpLoc, sCastType, sCastMotive", 1, true)
local at_r4_trig = aiug_bare:find("if ( botHP + botMP < 0.3 or botHP < 0.2 )", 1, true)
G.T1_RETURN_BEFORE_R4 = (at_t1_ret and at_r4_trig and at_t1_ret < at_r4_trig) and 1 or 0
-- ...and the branch this lever guards must be the FIRST of the two in the file.
local at_t1_trig = aiug_bare:find("if botHP < 0.19", 1, true)
G.T1_TRIGGER_BEFORE_R4 = (at_t1_trig and at_r4_trig and at_t1_trig < at_r4_trig) and 1 or 0

-- The call site: exactly one, in the branch it claims, and no id in the branch
-- condition itself (the 'pullcad' trap -- the gate lives in the helper).
G.T1_QUIETVETO = count(b1, 'J.ShouldSipNotTpQuietHome')
G.T1_TPHOME_VETO = count(b1, 'J.ShouldStayAndRegen')
G.T1_NIDS = count(b1, 'IsSoakCandidate')
G.R4_QUIETVETO = count(b4, 'J.ShouldSipNotTpQuietHome')
-- The whole file carries exactly one call, so "one id, one call site" is a
-- count rather than a sentence (GH #606's shape: a gate address is not
-- reachability, and a second address would make this id unattributable).
G.FILE_QUIETVETO = count(aiug_bare, 'J.ShouldSipNotTpQuietHome')

-- The branch's own trigger constants, so the rows below are read against
-- numbers that came from the tree rather than from this file.
G.T1_HP_TRIGGER = tonumber(b1 and b1:match('botHP < ([%d%.]+)')) or -1
G.T1_DMG_WINDOW = tonumber(b1 and b1:match('WasRecentlyDamagedByAnyHero%( ([%d%.]+) %)')) or -1
G.T1_DEEP_OR = tonumber(b1 and b1:match('or botHP < ([%d%.]+)')) or -1
-- ⭐ The conjunct that makes '撤退:1' the QUIETEST of the four: an EMPTY ring,
-- where both siblings tolerate one enemy.  Counted, because it is the licence
-- for reaching below the family's floor here.
G.T1_RING_EMPTY = count(b1, 'nEnemyCount == 0')
G.R4_RING_LE1 = count(b4, 'nEnemyCount <= 1')
G.R4_LEVEL = tonumber(b4 and b4:match('bot:GetLevel%(%) >= (%d+)')) or -1

-- The new helper.
local quiet = strip_comments(jmz:match('function J%.ShouldSipNotTpQuietHome.-\nend'))
G.QUIET_FN = quiet and 1 or 0
G.QUIET_NIDS = count(quiet, 'IsSoakCandidate')
G.QUIET_TURBO = count(quiet, 'J.IsModeTurbo()')

local at_gate = quiet and quiet:find("IsSoakCandidate( 'tpquiet' )", 1, true)
local at_turbo = quiet and quiet:find('IsModeTurbo()', 1, true)
local at_hp = quiet and quiet:find('J.GetHP(', 1, true)
local at_src = quiet and quiet:find('HasFieldRegenSource', 1, true)
-- An ABSENT clause must not flip this flag (the sibling's stand proved why):
-- missing positions are +inf, so this answers "is the gate ahead of every read
-- that IS still here", and each clause's presence is pinned separately.
local INF = math.huge
G.QUIET_GATE_FIRST = (at_gate and at_turbo
    and at_gate < at_turbo
    and at_gate < (at_hp or INF)
    and at_gate < (at_src or INF)) and 1 or 0

-- The five constants, parsed off the helper's own code.
G.QUIET_HI = tonumber(quiet and quiet:match('QUIET_BAND_HI, QUIET_BAND_LO = ([%d%.]+)')) or -1
G.QUIET_LO = tonumber(quiet and quiet:match('QUIET_BAND_HI, QUIET_BAND_LO = [%d%.]+, ([%d%.]+)')) or -1
G.QUIET_DMG_WINDOW = tonumber(quiet and quiet:match('QUIET_DMG_WINDOW = ([%d%.]+)')) or -1
G.QUIET_RING = tonumber(quiet and quiet:match('QUIET_RING, QUIET_TOWER = (%d+)')) or -1
G.QUIET_TOWER = tonumber(quiet and quiet:match('QUIET_RING, QUIET_TOWER = %d+, (%d+)')) or -1
-- ...and each named constant must actually be USED, or the parse above is
-- reading a decoration.  A literal in the body would satisfy neither.
G.QUIET_USES_HI = count(quiet, 'nHP >= QUIET_BAND_HI')
G.QUIET_USES_LO = count(quiet, 'nHP < QUIET_BAND_LO')
G.QUIET_USES_DMG = count(quiet, 'WasRecentlyDamagedByAnyHero( QUIET_DMG_WINDOW )')
G.QUIET_USES_RING = count(quiet, 'J.GetNearbyHeroes( bot, QUIET_RING, true, BOT_MODE_NONE )')
G.QUIET_USES_TOWER = count(quiet, 'bot:GetNearbyTowers( QUIET_TOWER, true )')
G.QUIET_SOURCE = count(quiet, 'J.HasFieldRegenSource')

-- ⭐⭐ THE SIBLING'S FIVE, parsed the same way, so "the sibling's constants" is
-- arithmetic between two functions rather than a sentence in a comment.
local deep = strip_comments(jmz:match('function J%.ShouldDeepSipNotTpRecover.-\nend'))
G.DEEP_FN = deep and 1 or 0
G.DEEP_HI = tonumber(deep and deep:match('nHP >= ([%d%.]+)')) or -1
G.DEEP_LO = tonumber(deep and deep:match('nHP < ([%d%.]+)')) or -1
G.DEEP_DMG_WINDOW = tonumber(deep and deep:match('WasRecentlyDamagedByAnyHero%( ([%d%.]+) %)')) or -1
G.DEEP_RING = tonumber(deep and deep:match('J%.GetNearbyHeroes%( bot, (%d+)')) or -1
G.DEEP_TOWER = tonumber(deep and deep:match('bot:GetNearbyTowers%( (%d+)')) or -1
-- ⛔ GH #550, pinned in the file that does the thing rather than in the file
-- that would be blamed for it: no line of the new helper may be byte-identical
-- to a line tools/agent/mutstand_tpdeep.sh anchors on.  Those anchors are the
-- INLINE forms; this counts them across the whole of jmz_func and they must
-- stay at exactly one occurrence each.
G.INLINE_BAND_HI = count(jmz, '\tif nHP >= 0.18 then return false end\n')
G.INLINE_BAND_LO = count(jmz, '\tif nHP < 0.10 then return false end\n')
G.INLINE_DMG = count(jmz, '\tif bot:WasRecentlyDamagedByAnyHero( 6.0 ) then return false end\n')
G.INLINE_RING = count(jmz, '\tif #J.GetNearbyHeroes( bot, 2500, true, BOT_MODE_NONE ) > 0 then return false end\n')

local gk = {}
for k in pairs(G) do gk[#gk + 1] = k end
table.sort(gk)
for _, k in ipairs(gk) do out:write(string.format('G %s %s\n', k, tostring(G[k]))) end

local HP_TRIG = G.T1_HP_TRIGGER
local DMG_TRIG = G.T1_DMG_WINDOW
local DEEP_OR = G.T1_DEEP_OR
local R4_LVL = G.R4_LEVEL
local HI = G.QUIET_HI
local LO = G.QUIET_LO

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
local function bump(k) rawset(c, k, c[k] + 1) end
-- Zero-initialised so "the bucket was never reached" and "the bucket measured
-- zero" are never the same thing to the parser (the GH #171 shape).
for _, k in ipairs({ 'fixtures', 'live', 'raises',
    't1_trigger', 'r4_trigger', 'both_triggers',
    'quiet_shipped_true', 'quiet_armed_true', 'quiet_true_in_t1',
    'flips', 'flip_false_to_true', 'flips_swapped', 'flip_false_to_true_swapped',
    'arm_leak', 'tpdeep_true', 'tpdeep_true_in_r4', 'tpdeep_true_in_r4_shadowed',
    'both_armed_true', 'both_armed_true_and_both_triggers',
    'stop_band_high', 'stop_band_low', 'stop_source', 'stop_damage', 'stop_ring',
    'stop_tower', 'quiet_with_any_tower', 'quiet_ring_margin',
    'band_low_otherwise_domain', 'band_high_otherwise_domain' }) do
    rawset(c, k, 0)
end

--- ONE tally for both directions, called twice with the legs swapped.
local function tally(a, b, sDown, sUp)
    if a and not b then bump(sDown) end
    if b and not a then bump(sUp) end
end

for _, path in ipairs(fixture_files()) do
    local fx = dofile(path)
    if type(fx) == 'table' and fx.units and fx.time then
        bump('fixtures')
        for _, u in ipairs(fx.units) do
            if u.alive and u.name and u.name:match('^npc_dota_hero_') then
                local ok, J, bot = pcall(rf.load, path, u.name)
                if ok and bot ~= nil then
                    bump('live')
                    local sArmed = nil
                    J.IsSoakCandidate = function(sId)
                        return sArmed ~= nil and sId == sArmed
                    end
                    local sFx = path:match('([^/]+)%.lua$')
                    local sHero = u.name:gsub('npc_dota_hero_', '')
                    local nHP, nMP = J.GetHP(bot), J.GetMP(bot)

                    local okShip, shipped = pcall(J.ShouldSipNotTpQuietHome, bot)
                    sArmed = 'tpquiet'
                    -- The arming must be ONE id wide.  A stub arming them all
                    -- would let another live id move this answer while the flip
                    -- is still attributed here.  Asserted 0 downstream.
                    if J.IsSoakCandidate('tpdeep') or J.IsSoakCandidate('tprecov')
                        or J.IsSoakCandidate('stayfield') then
                        bump('arm_leak')
                    end
                    local okArm, arm = pcall(J.ShouldSipNotTpQuietHome, bot)
                    -- ⭐ The SHIPPED sibling, armed on its OWN id, same frame.
                    sArmed = 'tpdeep'
                    local okSib, deep_true = pcall(J.ShouldDeepSipNotTpRecover, bot)
                    sArmed = nil

                    if not (okShip and okArm and okSib) then
                        bump('raises')
                    else
                        shipped = shipped and true or false
                        arm = arm and true or false
                        deep_true = deep_true and true or false

                        if shipped then bump('quiet_shipped_true') end
                        if arm then bump('quiet_armed_true') end
                        if deep_true then bump('tpdeep_true') end
                        if arm and deep_true then bump('both_armed_true') end
                        tally(arm, shipped, 'flips', 'flip_false_to_true')
                        -- Legs EXCHANGED, same `tally`.
                        tally(shipped, arm, 'flips_swapped', 'flip_false_to_true_swapped')

                        -- Both branch triggers, as far as a fixture can answer
                        -- them.  UPPER BOUNDS -- see the limit block above.
                        local nRing1600 = #J.GetNearbyHeroes(bot, 1600, true, BOT_MODE_NONE)
                        local bNoFlask = (J.IsItemAvailable('item_flask') == nil)
                        local bT1 = (nHP < HP_TRIG) and (nRing1600 == 0) and bNoFlask
                            and (bot:WasRecentlyDamagedByAnyHero(DMG_TRIG) or nHP < DEEP_OR)
                        local bR4 = ((nHP + nMP < 0.3) or (nHP < 0.2))
                            and bot:GetLevel() >= R4_LVL and nRing1600 <= 1 and bNoFlask

                        if bR4 then bump('r4_trigger') end
                        if bT1 and bR4 then bump('both_triggers') end
                        if arm and deep_true and bT1 and bR4 then
                            bump('both_armed_true_and_both_triggers')
                        end
                        -- ⭐ THE SHADOW.  Measured on the SHIPPED sibling, and
                        -- every hit gets a printed row -- a count alone could
                        -- not be re-checked against the looseness of the bounds.
                        if bR4 and deep_true then
                            bump('tpdeep_true_in_r4')
                            if bT1 then
                                bump('tpdeep_true_in_r4_shadowed')
                                out:write(string.format('S %s %s %.3f %d\n',
                                    sFx, sHero, nHP, bot:GetLevel()))
                            end
                        end

                        if bT1 then
                            bump('t1_trigger')
                            if nHP < HI then
                                -- Anti-vacuum for the tower clause: does this
                                -- frame's world contain an enemy tower AT ALL?
                                if #bot:GetNearbyTowers(20000, true) > 0 then
                                    bump('quiet_with_any_tower')
                                end
                                -- The margin this helper's ring adds over the
                                -- branch's own 1600: empty at 1600 (the branch
                                -- passes) and NOT empty at the helper's radius.
                                if nRing1600 == 0
                                    and #J.GetNearbyHeroes(bot, G.QUIET_RING, true, BOT_MODE_NONE) > 0
                                then
                                    bump('quiet_ring_margin')
                                end
                            end

                            -- The prefix walk: which clause of the helper stops
                            -- this frame.  Buckets sum to `t1_trigger`.
                            local sStop
                            if nHP >= HI then
                                sStop = 'band_high'; bump('stop_band_high')
                            elseif nHP < LO then
                                sStop = 'band_low'; bump('stop_band_low')
                            elseif not J.HasFieldRegenSource(bot) then
                                sStop = 'source'; bump('stop_source')
                            elseif bot:WasRecentlyDamagedByAnyHero(G.QUIET_DMG_WINDOW) then
                                sStop = 'damage'; bump('stop_damage')
                            elseif #J.GetNearbyHeroes(bot, G.QUIET_RING, true, BOT_MODE_NONE) > 0 then
                                sStop = 'ring'; bump('stop_ring')
                            elseif #bot:GetNearbyTowers(G.QUIET_TOWER, true) > 0 then
                                sStop = 'tower'; bump('stop_tower')
                            else
                                sStop = 'domain'; bump('quiet_true_in_t1')
                            end
                            out:write(string.format('R %s %s %.3f %d %s\n',
                                sFx, sHero, nHP, bot:GetLevel(), sStop))

                            -- ⭐ WHAT EACH BAND EDGE ACTUALLY COSTS.  A prefix
                            -- walk reports the FIRST clause that stops a frame,
                            -- so an edge can read as "stopping N frames" while
                            -- costing zero domain -- the later clauses would
                            -- have stopped all N anyway.  These two count the
                            -- frames an edge stops that EVERY other clause would
                            -- have let through, i.e. the edge's real price.  A
                            -- zero here is exactly why an edge must be pinned
                            -- structurally and never by a domain count (the
                            -- sibling stand's M6/M7 lesson).
                            if sStop == 'band_low' or sStop == 'band_high' then
                                local bRest = J.HasFieldRegenSource(bot)
                                    and not bot:WasRecentlyDamagedByAnyHero(G.QUIET_DMG_WINDOW)
                                    and #J.GetNearbyHeroes(bot, G.QUIET_RING, true, BOT_MODE_NONE) == 0
                                    and #bot:GetNearbyTowers(G.QUIET_TOWER, true) == 0
                                if bRest then
                                    bump(sStop == 'band_low' and 'band_low_otherwise_domain'
                                        or 'band_high_otherwise_domain')
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
out:write('DONE\n')

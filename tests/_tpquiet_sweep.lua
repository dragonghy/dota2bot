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
--   T <kind> <fixture> <hero> <hp> <lvl>
--       one frame of the SECOND shadow census (2026-09-08, charter 0TPQUIET
--       「下一格」(2)): kind is t3_by_t1 | t3_by_t2 | r4_by_t2 | r4_by_t3.
--   DONE
--
-- ⭐⭐⭐ THE SECOND CENSUS AND WHY IT IS THE SAME MEASUREMENT, NOT A NEW ONE.
-- The first census answered one cell of a 4x4 table: does '撤退:1' shadow
-- '回复状态'?  It came back `both_triggers 6` against `tpdeep_true_in_r4_shadowed
-- 1` -- i.e. the OVERLAP is six times larger than the one frame that happened to
-- carry a TRUE sibling answer, so the shape cannot be a property of that one
-- lever.  The other pairs of the same table have never been asked:
--   * 'stayfield' hangs on '撤退:3', with '撤退:1' and '撤退:2' upstream of it;
--   * '撤退:2' is upstream of '回复状态', where 'tprecov'/'tpdeep' hang.
-- Both are measured HERE rather than in a third full-corpus sweep: the frames,
-- the ring reads and the flask read are already computed on this walk, and a
-- second 30s drive of the same 1021 frames would be a copy, not evidence.
-- Every cell is an UPPER BOUND for the same reason the first one was (`X` is
-- file-local; `X.CanJuke`, `nAttackAllyList`, `bot:DistanceFromFountain` and the
-- enclosing `nMode == BOT_MODE_RETREAT` are all unreadable from here), so a
-- shadow count is a ceiling on the shadow and every hit gets a printed row.
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
local b2 = branch(aiug, 'if botHP < ( 0.15 + 0.24 * nEnemyCount )', '撤退:2')
local b3 = branch(aiug, 'if ( botHP < 0.34 or botHP + botMP < 0.43 )', '撤退:3')
local b4 = branch(aiug, 'if ( botHP + botMP < 0.3 or botHP < 0.2 )', '回复状态')
G.BRANCH_T1 = b1 and 1 or 0
G.BRANCH_T2 = b2 and 1 or 0
G.BRANCH_T3 = b3 and 1 or 0
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

-- ⭐⭐⭐ THE SECOND CENSUS'S STRUCTURAL PINS.  "Upstream" is a fact about source
-- order, and the first census learned the hard way (M10/M13) that it must not be
-- read off a count and must not be anchored on a line three branches share.  So
-- each branch's OWN return is located by starting the search AT that branch's
-- own motive assignment -- a string unique to it -- and the four triggers are
-- located by their own unique conditions.  All positions come from the
-- comment-stripped source, so the block of prose above cannot satisfy any of it.
local function at_code(s) return aiug_bare:find(s, 1, true) end
local RET_TP = 'return BOT_ACTION_DESIRE_HIGH, tpLoc, sCastType, sCastMotive'
local function at_branch_return(sMotive)
    local m = at_code("sCastMotive = '" .. sMotive .. "'")
    if m == nil then return nil end
    return aiug_bare:find(RET_TP, m, true)
end
local at_t2_trig = at_code('if botHP < ( 0.15 + 0.24 * nEnemyCount )')
local at_t3_trig = at_code('if ( botHP < 0.34 or botHP + botMP < 0.43 )')
local at_t1_ret_own = at_branch_return('撤退:1')
local at_t2_ret_own = at_branch_return('撤退:2')
local at_t3_ret_own = at_branch_return('撤退:3')
local function before(a, b) return (a and b and a < b) and 1 or 0 end
G.T1_RETURN_BEFORE_T2 = before(at_t1_ret_own, at_t2_trig)
G.T1_RETURN_BEFORE_T3 = before(at_t1_ret_own, at_t3_trig)
G.T2_RETURN_BEFORE_T3 = before(at_t2_ret_own, at_t3_trig)
G.T2_RETURN_BEFORE_R4 = before(at_t2_ret_own, at_r4_trig)
G.T3_RETURN_BEFORE_R4 = before(at_t3_ret_own, at_r4_trig)
-- ...and the three retreat returns are three DISTINCT positions.  Without this,
-- a single shared return would satisfy every ordering pin above at once (the
-- M13 shape: a whole-file `find` answered by the wrong branch's return).
G.RETREAT_RETURNS_DISTINCT = (at_t1_ret_own and at_t2_ret_own and at_t3_ret_own
    and at_t1_ret_own < at_t2_ret_own and at_t2_ret_own < at_t3_ret_own) and 1 or 0

-- ⛔ The three retreat branches share ONE enclosing `nMode == BOT_MODE_RETREAT`
-- wrapper; '回复状态' sits OUTSIDE it.  That asymmetry decides how far each
-- shadow cell can be trusted (a t3-by-t1/t2 hit is inside one wrapper, so the
-- mode condition is common to both sides and cancels; an r4-by-t2 hit is not),
-- and it is a structural fact, so it is pinned rather than described.
local at_retreat_wrap = at_code('if nMode == BOT_MODE_RETREAT')
G.RETREAT_WRAP_BEFORE_T1 = before(at_retreat_wrap, at_t1_trig)
G.R4_TRIGGER_AFTER_T3_RETURN = before(at_t3_ret_own, at_r4_trig)

-- The two downstream branches' own trigger constants and their vetoes, parsed
-- the same way '撤退:1''s were.
G.T2_HP_BASE = tonumber(b2 and b2:match('botHP < %( ([%d%.]+)')) or -1
G.T2_HP_PER_ENEMY = tonumber(b2 and b2:match('%+ ([%d%.]+) %* nEnemyCount')) or -1
G.T2_DMG_WINDOW = tonumber(b2 and b2:match('WasRecentlyDamagedByAnyHero%( ([%d%.]+) %)')) or -1
G.T2_RING_CAP_HP = tonumber(b2 and b2:match('nEnemyCount <= %( botHP < ([%d%.]+)')) or -1
G.T2_RING_CAP_LOW = tonumber(b2 and b2:match('nEnemyCount <= %( botHP < [%d%.]+ and (%d+)')) or -1
G.T2_RING_CAP_HIGH = tonumber(b2 and b2:match('nEnemyCount <= %( botHP < [%d%.]+ and %d+ or (%d+)')) or -1
-- '撤退:2' is the genuine escape: it must keep BOTH of the conjuncts that make
-- it one (enemies present via the cap arithmetic, and recent hero damage), and
-- it must carry NO regen veto -- that is the family's standing decision, so a
-- future round adding one there has to come through this line.
G.T2_NVETOES = count(b2, 'J.ShouldStayAndRegen') + count(b2, 'J.ShouldRegenNotTpHome')
    + count(b2, 'J.ShouldSipNotTpQuietHome') + count(b2, 'J.ShouldSipNotTpRecover')
    + count(b2, 'J.ShouldDeepSipNotTpRecover')
G.T3_HP = tonumber(b3 and b3:match('botHP < ([%d%.]+)')) or -1
G.T3_SUM = tonumber(b3 and b3:match('botHP %+ botMP < ([%d%.]+)')) or -1
G.T3_LEVEL = tonumber(b3 and b3:match('bot:GetLevel%(%) >= (%d+)')) or -1
G.T3_RING_LE1 = count(b3, 'nEnemyCount <= 1')
G.T3_STAYVETO = count(b3, 'J.ShouldRegenNotTpHome')
G.FILE_STAYVETO = count(aiug_bare, 'J.ShouldRegenNotTpHome')
-- ⭐ THE BAND '撤退:3''s ONLY VETO CAN ACT IN, read off the shared situation
-- predicate rather than off the wrapper -- 'stayfield' is
-- J.ShouldRegenNotGoHome, whose first clause is J.IsFieldRegenSituation.  The
-- branch's own cap is `botHP < 0.34`, so the two together decide how much of
-- this branch has NO veto at all, and that subtraction is the whole reason the
-- deep columns below exist.  Parsed, never quoted from a comment.
local fieldsit = strip_comments(jmz:match('function J%.IsFieldRegenSituation.-\nend'))
G.FIELDSIT_FN = fieldsit and 1 or 0
G.STAY_FLOOR = tonumber(fieldsit and fieldsit:match('nHP < ([%d%.]+) or nHP >')) or -1
G.STAY_CEIL = tonumber(fieldsit and fieldsit:match('nHP < [%d%.]+ or nHP > ([%d%.]+)')) or -1
G.STAY_WRAPPER_ROUTES = count(strip_comments(jmz:match('function J%.ShouldRegenNotTpHome.-\nend')) or '',
    'J.ShouldRegenNotGoHome')

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
local T2_BASE, T2_PER = G.T2_HP_BASE, G.T2_HP_PER_ENEMY
local T2_DMG = G.T2_DMG_WINDOW
local T2_CAP_HP, T2_CAP_LOW, T2_CAP_HIGH = G.T2_RING_CAP_HP, G.T2_RING_CAP_LOW, G.T2_RING_CAP_HIGH
local T3_HP, T3_SUM, T3_LVL = G.T3_HP, G.T3_SUM, G.T3_LEVEL

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
    'band_low_otherwise_domain', 'band_high_otherwise_domain',
    -- second census (2026-09-08)
    't2_trigger', 't3_trigger',
    't3_shadowed_by_t1', 't3_shadowed_by_t2', 't3_shadowed_by_either',
    'r4_shadowed_by_t2', 'r4_shadowed_by_t3', 'r4_shadowed_by_any_retreat',
    'stayfield_shipped_true', 'stayfield_armed_true',
    'stayfield_true_in_t3', 'stayfield_true_in_t3_shadowed',
    'tpdeep_true_in_r4_shadowed_by_t2', 'tpdeep_true_in_r4_shadowed_by_t3',
    'tpdeep_true_in_r4_shadowed_by_any',
    -- pricing of '撤退:2''s EMPTY-RING leg (see the walk)
    't2_ring_empty', 't2_empty_in_band', 't2_empty_band_src',
    't2_empty_band_src_ring', 't2_empty_band_src_ring_tower',
    't2_empty_with_any_tower', 't2_empty_below_band', 't2_empty_damaged_only',
    -- pricing of '撤退:3''s DEEP leg (below its only veto's floor)
    't3_below_stayfloor', 't3_deep_in_band', 't3_deep_src', 't3_deep_src_nodmg',
    't3_deep_src_nodmg_ring', 't3_deep_domain', 't3_deep_domain_unshadowed',
    't3_deep_with_any_tower', 't3_at_or_above_stayfloor' }) do
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
                    -- Second census: the '撤退:3' veto, read SHIPPED first (its
                    -- gate must make it false on every frame -- the anti-vacuum
                    -- for the armed column below).
                    local okStayShip, stay_shipped = pcall(J.ShouldRegenNotTpHome, bot)
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
                    -- ...and the '撤退:3' veto armed on ITS own id, same frame.
                    sArmed = 'stayfield'
                    local okStayArm, stay_true = pcall(J.ShouldRegenNotTpHome, bot)
                    sArmed = nil

                    if not (okShip and okArm and okSib and okStayShip and okStayArm) then
                        bump('raises')
                    else
                        shipped = shipped and true or false
                        arm = arm and true or false
                        deep_true = deep_true and true or false
                        stay_shipped = stay_shipped and true or false
                        stay_true = stay_true and true or false

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

                        -- ⭐⭐⭐ THE SECOND CENSUS'S TWO NEW BOUNDS.  Same
                        -- construction and same looseness as bT1/bR4 above: every
                        -- conjunct a fixture cannot read is DROPPED, so each is
                        -- an over-permissive ceiling.  For the t3-by-t1/t2 cells
                        -- that looseness is symmetric (all three branches sit
                        -- under one `nMode == BOT_MODE_RETREAT`, pinned above),
                        -- so the dropped wrapper cancels; for r4-by-t2/t3 it does
                        -- not, and that cell is reported as a CEILING only.
                        local bT2 = (nHP < (T2_BASE + T2_PER * nRing1600))
                            and bot:WasRecentlyDamagedByAnyHero(T2_DMG)
                            and (nRing1600 <= (nHP < T2_CAP_HP and T2_CAP_LOW or T2_CAP_HIGH))
                            and bNoFlask
                        local bT3 = ((nHP < T3_HP) or (nHP + nMP < T3_SUM))
                            and bot:GetLevel() >= T3_LVL and nRing1600 <= 1 and bNoFlask

                        if bR4 then bump('r4_trigger') end
                        if bT1 and bR4 then bump('both_triggers') end
                        if bT2 then bump('t2_trigger') end
                        if bT3 then bump('t3_trigger') end

                        local function note(sKind)
                            out:write(string.format('T %s %s %s %.3f %d\n',
                                sKind, sFx, sHero, nHP, bot:GetLevel()))
                        end

                        -- ⭐⭐⭐⭐ PRICING '撤退:2''s EMPTY-RING LEG.  The family's
                        -- written reason for exempting this branch is that it
                        -- "requires enemies AND recent hero damage".  The second
                        -- half is a conjunct; the FIRST half is not -- the cap is
                        -- `0.15 + 0.24 * nEnemyCount`, whose BASE is nonzero, so
                        -- at nEnemyCount == 0 the branch still fires on
                        -- `botHP < 0.15` and the damage clause alone.  These
                        -- columns price that leg the same way every other lever
                        -- in this family was priced: the trigger, then one
                        -- clause at a time, so a zero anywhere names WHICH
                        -- clause emptied it rather than "the domain is small".
                        if bT2 and nRing1600 == 0 then
                            bump('t2_ring_empty')
                            -- Anti-vacuum for the tower clause below.
                            if #bot:GetNearbyTowers(20000, true) > 0 then
                                bump('t2_empty_with_any_tower')
                            end
                            if nHP < LO then bump('t2_empty_below_band') end
                            if nHP >= LO and nHP < HI then
                                bump('t2_empty_in_band')
                                if J.HasFieldRegenSource(bot) then
                                    bump('t2_empty_band_src')
                                    if #J.GetNearbyHeroes(bot, G.QUIET_RING, true, BOT_MODE_NONE) == 0 then
                                        bump('t2_empty_band_src_ring')
                                        if #bot:GetNearbyTowers(G.QUIET_TOWER, true) == 0 then
                                            bump('t2_empty_band_src_ring_tower')
                                            note('t2_quiet_leg')
                                        end
                                    end
                                end
                            end
                            -- ⛔ THE CLOSED FORM THAT DECIDES THE PREDICATE.  The
                            -- branch REQUIRES `WasRecentlyDamagedByAnyHero(6.0)`
                            -- and 'tpquiet''s helper REFUSES on the same call
                            -- with the same window, so re-using that helper here
                            -- would be a no-op by construction (the GH #622
                            -- shape: the first wave buys nothing).  This counts
                            -- the frames where that contradiction is the ONLY
                            -- thing between the leg and the family's opinion.
                            if nHP >= LO and nHP < HI
                                and J.HasFieldRegenSource(bot)
                                and bot:WasRecentlyDamagedByAnyHero(G.QUIET_DMG_WINDOW)
                            then
                                bump('t2_empty_damaged_only')
                            end
                        end

                        -- ⭐⭐⭐⭐⭐ PRICING '撤退:3''s DEEP LEG -- the cell the
                        -- census actually opens.  This branch's only veto is
                        -- 'stayfield', and that veto routes through
                        -- J.IsFieldRegenSituation, whose FIRST clause is a
                        -- [0.18, 0.55] band.  The branch itself fires down to
                        -- zero HP (`botHP < 0.34 or sum < 0.43`).  So everything
                        -- below the family's floor on this branch has NO veto of
                        -- any kind, armed or not -- digit for digit the same
                        -- subtraction that motivated 'tpdeep' on '回复状态'
                        -- (there: the floor stopped 29 of 31 trigger frames).
                        if bT3 then
                            if nHP < G.STAY_FLOOR then bump('t3_below_stayfloor')
                            else bump('t3_at_or_above_stayfloor') end
                            if #bot:GetNearbyTowers(20000, true) > 0 then
                                bump('t3_deep_with_any_tower')
                            end
                            if nHP >= LO and nHP < HI then
                                bump('t3_deep_in_band')
                                if J.HasFieldRegenSource(bot) then
                                    bump('t3_deep_src')
                                    if not bot:WasRecentlyDamagedByAnyHero(G.QUIET_DMG_WINDOW) then
                                        bump('t3_deep_src_nodmg')
                                        if #J.GetNearbyHeroes(bot, G.QUIET_RING, true, BOT_MODE_NONE) == 0 then
                                            bump('t3_deep_src_nodmg_ring')
                                            if #bot:GetNearbyTowers(G.QUIET_TOWER, true) == 0 then
                                                bump('t3_deep_domain')
                                                note('t3_deep')
                                                if not (bT1 or bT2) then
                                                    bump('t3_deep_domain_unshadowed')
                                                    note('t3_deep_unshadowed')
                                                end
                                            end
                                        end
                                    end
                                end
                            end
                        end

                        -- Cell A: is 'stayfield''s branch reached at all?
                        if bT3 then
                            if bT1 then bump('t3_shadowed_by_t1'); note('t3_by_t1') end
                            if bT2 then bump('t3_shadowed_by_t2'); note('t3_by_t2') end
                            if bT1 or bT2 then bump('t3_shadowed_by_either') end
                        end
                        -- Cell B: does '撤退:2' (or '撤退:3') stand in front of
                        -- the branch 'tprecov'/'tpdeep' hang on?
                        if bR4 then
                            if bT2 then bump('r4_shadowed_by_t2'); note('r4_by_t2') end
                            if bT3 then bump('r4_shadowed_by_t3'); note('r4_by_t3') end
                            if bT1 or bT2 or bT3 then bump('r4_shadowed_by_any_retreat') end
                        end
                        -- ...and the same two cells INTERSECTED with a helper that
                        -- actually answers TRUE, which is what a domain reading
                        -- would have been credited with.
                        if stay_shipped then bump('stayfield_shipped_true') end
                        if stay_true then bump('stayfield_armed_true') end
                        if stay_true and bT3 then
                            bump('stayfield_true_in_t3')
                            if bT1 or bT2 then bump('stayfield_true_in_t3_shadowed') end
                        end
                        if deep_true and bR4 then
                            if bT2 then bump('tpdeep_true_in_r4_shadowed_by_t2') end
                            if bT3 then bump('tpdeep_true_in_r4_shadowed_by_t3') end
                            if bT1 or bT2 or bT3 then
                                bump('tpdeep_true_in_r4_shadowed_by_any')
                            end
                        end
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

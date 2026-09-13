-- [rescpost 20260913] THE RESCUE-TP "HE IS UNDER HIS OWN TOWER" REFUSAL NO
-- LONGER COUNTS A CAPTURED OUTPOST AS THE PEEL.
--
-- ⭐ WHAT LANDED, IN ONE LINE: `and not J.IsOutpostBuilding( b )` in the
-- admission test of J.GetRescueTpTarget's bUnderOwnTower loop. One conjunct,
-- ⛔ NO NEW SOAK ID, no new constant.
--
-- ⭐⭐ WHY NO NEW ID, AND WHY THAT IS THE RULE RATHER THAN THE SHORTCUT. The
-- charter's criterion (甲) of 2026-09-13T05:00Z has two halves and this site is
-- the other half from `divepost`'s: the host of the conjunct decides how it
-- lands. `J.ShouldPunishDive` is PROMOTED, so a conjunct there has no gate to
-- inherit and MUST bring its own id ('divepost'). J.GetRescueTpTarget opens
-- with `if not J.IsLaneFixOn( 'rescue' ) then return nil end` and
-- J.IsLaneFixOn is `IsSoakCandidate('lanefix') or IsSoakCandidate('lf_'..sub)`
-- -- an OR of two UNPROMOTED candidates -- so the whole helper is already
-- inert in shipped play and the narrowing inherits that. Adding an id here
-- would be the pullcad trap's cousin: a second gate nested under an unarmed
-- one, which no wave can isolate and which `check_armed_wiring.py` would still
-- call WIRED. ⭐ It is also the one landing shape that adds NOTHING to the
-- armed string under owner P4.2's admission freeze.
--
-- ⭐⭐ WHY THIS SITE EXISTS AT ALL, which is the finding worth carrying. GH
-- #782 was filed as a NAME-TEST defect -- `string.find( name, 'tower' )`
-- matches `npc_dota_watch_tower` -- and three sites were counted. §1 below
-- counts the shape IN THE TREE instead of trusting that prose (the 09-13
-- lesson: a census that enumerates by who was being priced cannot find the
-- site nobody is pricing), and the tree says the family's live members are:
--   * J.ShouldTpSupportTowerFight -- narrowed 2026-09-13 ('tpdeftower').
--   * J.GetRescueTpTarget         -- THIS ROUND.
--   * J.ShouldAbortRoshanAttempt  -- narrowed 2026-09-13 ('roshpost', no new
--                                    id: that host is gated as a WHOLE by one
--                                    unpromoted candidate). §2's allowed-open
--                                    set is therefore EMPTY as of that round;
--                                    it was `{ J.ShouldAbortRoshanAttempt }`
--                                    when this file landed.
-- (bots/mode_retreat_generic_wip.lua carries a fourth; `_wip` is not a mode
-- name the engine loads, and §1 says so rather than silently skipping it.)
--
-- ⭐ WHY THE DIRECTION IS CLOSED-FORM, and note it is the OPPOSITE SIGN from
-- the two siblings -- which is why it is stated rather than assumed. The
-- conjunct is added to the admission test of the loop that SETS
-- bUnderOwnTower, so the set of buildings that can set it is a strict subset:
-- bUnderOwnTower can only fall true -> false, hence the rescue's own
-- `not bUnderOwnTower` conjunct can only go false -> true, hence the answered
-- rescue set can only GROW. ⛔ So unlike `divepost`/`tpdeftower` this narrowing
-- can AUTHORISE an action that did not happen before, and that is registered as
-- the reason it must not be armed casually (§6). What it cannot do is refuse a
-- rescue the shipped tree answered.
--
-- ⭐ THE DEFECT IN ONE SENTENCE, from the code's own words. The comment above
-- the loop says "no rescuing an ally that is standing under its own tower --
-- the tower is the peel there". An outpost has no attack: it peels nobody. So
-- a dying ally beside a captured river outpost is read as defended and the
-- rescue TP is refused. Standard Dota supports the shipped rule (a tower's
-- DPS plus its aggro really is the peel, which is why "he is at his tower" is
-- a live reason not to spend a TP) and supports the narrowing for the same
-- reason: an outpost provides vision and XP, never damage.
--
-- ⭐⭐ THE ARMS, AND WHY THEY ARE AN EXACT COUNTERFACTUAL RATHER THAN A MODEL
-- (§4-§5). Forcing J.IsOutpostBuilding to answer FALSE for every handle
-- reproduces the PRE-NARROWING tree exactly -- `and not false` is the identity
-- -- so arm A is the old code and arm B is the new one, on the same frame,
-- through the same published function. No world is invented:
--   * arm A -- armed, predicate forced FALSE  = the tree before this round.
--   * arm B -- armed, real predicate          = the tree as landed.
--   * arm C -- armed, predicate forced TRUE   = every building an outpost, so
--              bUnderOwnTower can never be set. Maximal release; must contain B.
--   * arm D -- UNARMED, predicate forced TRUE = the host's own gate. Must be
--              nil on every row.
-- Arm D is the "gate present vs gate load-bearing" arm the charter's criterion
-- (丙) requires. ⭐ Here it is discharged by the HOST's early return rather
-- than by a conjunct of its own, and that is exactly what criterion (甲)
-- predicts for a gated host -- but it is still DRIVEN, not argued: a landing
-- that had accidentally moved the conjunct above the gate would fail §5 while
-- passing every other section in this file.
--
-- ⭐ READINGS AS LANDED (142 frames / 657 live hero-rows / load_fail 0 /
-- raised 0). Census: far_pairs 1794, utb 275, utb_has_wt 8 = utb_wt_only 8 (the
-- narrowing's domain, and unlike both siblings it is NOT zero), pred_true 1166 /
-- pred_false 20752, PRED_DISAGREES 0, lowhp_divers 61, flip_candidates 0.
-- Positive control: nearest outpost-to-ally 360.9u, wt_within_tower_r 14,
-- wt_within_2x 45 -- so the zeroes above are geometry, not a dead gauge.
-- Arms: A 6 = B 6 (flip_ab 0), C 7, D 0; shrink_ba 0; flip_ad 6 == fire_a;
-- fire_a2 657 == live; isolated_rows 7; real_pred_drives 664 == live+isolated.
-- ⭐⭐ fire_c 7 > fire_b 6 is the load-bearing reading: treating the building
-- beside the ally as an outpost really does release ONE more rescue. That is a
-- positive witness, not the "all N suppressed" counterfactual the two siblings
-- had to settle for -- and it is why arm D here is separated from arm A by a
-- measured difference instead of by nil == nil.
--
-- Registered: iterations/state.json:rescpost_20260913. armed string,
-- iterations/queue.json and iterations/streams/test_set.md untouched; no new
-- gate id exists to admit. Zero AWS.

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')

local TRG = 'bots/FunLib/jmz_func.lua'

local tests = {}

-- --------------------------------------------------------------- helpers ---

local function read_file(path)
    local f = assert(io.open(path, 'r'), 'could not open ' .. path)
    local s = f:read('*a')
    f:close()
    return s
end

--- Source with every comment removed: this file's prose QUOTES the shipped
--- conjunct, and so does the comment block above the conjunct in jmz_func.lua.
--- An unstripped read would let either of those satisfy §1.
local function stripped(src)
    src = src:gsub('%-%-%[(=*)%[.-%]%1%]', ' ')
    return (src:gsub('%-%-[^\n]*', ''))
end

local SRC = stripped(read_file(TRG))

local function block(header)
    local s = SRC:find(header, 1, true)
    assert(s ~= nil, header .. ' is gone from ' .. TRG)
    local e = SRC:find('\nend', s, true)
    assert(e ~= nil, 'unterminated ' .. header .. ' in ' .. TRG)
    return SRC:sub(s, e + 3)
end

local HOST = block('function J.GetRescueTpTarget( bot )')

--- The outpost unit name, PARSED OUT OF THE SHIPPED PREDICATE rather than
--- restated here (the 2026-09-13 lesson: a guard that names a spelling guards
--- the spelling, not the event -- so never let the test and the code hold
--- separate copies of the discriminator).
local OUTPOST_NAME = (function()
    local body = block('function J.IsOutpostBuilding( nTarget )')
    local lit = body:match("string%.find%(%s*nTarget:GetUnitName%(%)%s*,%s*'([%w_]+)'%s*%)")
    assert(lit ~= nil,
        'J.IsOutpostBuilding no longer tests a single quoted literal against '
        .. 'the unit name. Every count in this file is taken over units matched '
        .. 'by THAT literal; re-parse it here rather than hard-coding a name.')
    return lit
end)()

--- Every threshold below is READ OUT OF THE HOST, never typed here: move a
--- number in jmz_func and this census moves with it (the M13 lesson). A failed
--- parse asserts immediately rather than printing as a zero (the GH #171 shape).
local FAR_R = tonumber(HOST:match('GetUnitToUnitDistance%( bot, ally %) > (%d+)'))
local TOWER_R = tonumber(HOST:match('GetUnitToLocationDistance%( b, ally:GetLocation%(%) %) <= (%d+)'))
local DIVER_R = tonumber(HOST:match('GetEnemiesNearLoc%( ally:GetLocation%(%), (%d+) %)'))
local ALLY_HP = tonumber(HOST:match('nAllyHP < ([%d%.]+)'))
assert(FAR_R ~= nil and TOWER_R ~= nil and DIVER_R ~= nil and ALLY_HP ~= nil,
    'could not parse the host thresholds out of J.GetRescueTpTarget (far='
    .. tostring(FAR_R) .. ' tower=' .. tostring(TOWER_R) .. ' diver='
    .. tostring(DIVER_R) .. ' allyhp=' .. tostring(ALLY_HP) .. '). Every count '
    .. 'below is taken at the shipped numbers; re-parse before re-reading them.')

--- The host's own gate, parsed the same way. The sub-id is what the arms arm.
local GATE_SUB = HOST:match("J%.IsLaneFixOn%(%s*'([%w_]+)'%s*%)")
assert(GATE_SUB ~= nil,
    'J.GetRescueTpTarget no longer opens on J.IsLaneFixOn. This whole file '
    .. 'assumes the helper is gated by its own early return -- that is why the '
    .. 'narrowing carries no id of its own.')

local function corpus_paths()
    local out = {}
    for _, dir in ipairs({ 'tests/fixtures', 'tests/frames' }) do
        -- Registered in tests/test_bots_walk_farm_only.py:UNRESOLVED_HAND_READ:
        -- a plain non-recursive `ls` over two literal directories.
        local p = assert(io.popen('ls ' .. dir .. ' 2>/dev/null'),
            'could not list ' .. dir)
        for line in p:lines() do
            if line:sub(-4) == '.lua' then out[#out + 1] = dir .. '/' .. line end
        end
        p:close()
    end
    assert(#out > 100, 'expected the frame corpus, got ' .. #out)
    return out
end

-- ------------------------------------------------------------ the sweep ---

--- ONE pass over the corpus: the census plus five drives per hero-row.
---
--- ⚠️ BUDGET IS NOT MEMBERSHIP, and this file is NOT in the fast Lua hook
--- (tools/agent/lua_gate_manifest.json): the only sanctioned way in is a full
--- re-measure of all ~436 files, which rewrites the whole manifest and is not a
--- small work unit's business (GH #783 is the round that shows the cost). So a
--- red here does not block anybody's push -- the GH #624 shape, registered
--- rather than papered over, as it was for the two siblings.
--- Memoised: every section reads the same numbers.
local SWEEP, SWEEP_ERR = nil, nil
local MIN_WT_ALLY = nil

local function run_sweep()
    local c = setmetatable({}, { __index = function() return 0 end })
    local function bump(k) rawset(c, k, c[k] + 1) end
    -- Zero-initialised, so "never reached" and "measured zero" are never the
    -- same thing to a reader (the GH #171 shape).
    for _, k in ipairs({ 'frames', 'live', 'load_fail', 'raised',
        'pred_true', 'pred_false', 'PRED_DISAGREES',
        'far_pairs', 'utb', 'utb_has_wt', 'utb_wt_only',
        'lowhp_divers', 'flip_candidates',
        'wt_within_tower_r', 'wt_within_2x',
        'fire_a', 'fire_b', 'fire_c', 'fire_d', 'fire_a2',
        'flip_ab', 'flip_ad', 'shrink_ba', 'isolated_rows', 'real_pred_drives' }) do
        rawset(c, k, 0)
    end
    local drivable = {}

    for _, path in ipairs(corpus_paths()) do
        local ok, J, subject, heroes = pcall(rf.load, path)
        if not ok or J == nil then
            bump('load_fail')
        else
            bump('frames')
            -- tests/mock/replay_fixture.lua binds the enemy and building lists
            -- to the LOADED subject's team, so only heroes on that team can be
            -- driven as the acting bot (inherited trap, GH #767 §4).
            local subj_team = subject:GetTeam()
            for _, h in pairs(heroes or {}) do
                if h ~= nil and h.IsAlive and h:IsAlive()
                    and h:GetTeam() == subj_team
                then
                    bump('live')

                    -- (1) THE CENSUS: the loop's own geometry re-derived on the
                    -- real frame, at the shipped thresholds, using the shipped
                    -- predicate on real handles.
                    for _, ally in pairs(GetUnitList(UNIT_LIST_ALLIED_HEROES) or {}) do
                        if ally ~= h and J.IsValidHero(ally) and not ally:IsIllusion() then
                            -- ⭐ THE POSITIVE CONTROL FOR A NEGATIVE READING.
                            -- `utb_wt_only` and `flip_candidates` are expected
                            -- to be small/zero, and a broken distance
                            -- instrument would hand back that zero for free and
                            -- look identical to a real one. So the SAME
                            -- instrument is read at the shipped radius and at
                            -- twice it, and the closest outpost-to-ally
                            -- distance ever seen is reported: those must be
                            -- non-zero / finite, which attributes any zero to
                            -- GEOMETRY rather than to a dead measurement.
                            for _, b in pairs(GetUnitList(UNIT_LIST_ALLIED_BUILDINGS) or {}) do
                                if J.IsValidBuilding(b) and J.IsOutpostBuilding(b) then
                                    local db = GetUnitToLocationDistance(b, ally:GetLocation())
                                    if MIN_WT_ALLY == nil or db < MIN_WT_ALLY then
                                        MIN_WT_ALLY = db
                                    end
                                    if db <= TOWER_R then bump('wt_within_tower_r') end
                                    if db <= TOWER_R * 2 then bump('wt_within_2x') end
                                end
                            end

                            if GetUnitToUnitDistance(h, ally) > FAR_R then
                                bump('far_pairs')
                                local nMatch, nWt = 0, 0
                                for _, b in pairs(GetUnitList(UNIT_LIST_ALLIED_BUILDINGS) or {}) do
                                    if J.IsValidBuilding(b) then
                                        local bWt = J.IsOutpostBuilding(b) and true or false
                                        if bWt then bump('pred_true') else bump('pred_false') end
                                        -- ...and the predicate must agree with
                                        -- the literal parsed out of its own
                                        -- source, on these same handles.
                                        if (string.find(b:GetUnitName(), OUTPOST_NAME) ~= nil) ~= bWt then
                                            bump('PRED_DISAGREES')
                                        end
                                        if string.find(b:GetUnitName(), 'tower') ~= nil
                                            and GetUnitToLocationDistance(b, ally:GetLocation()) <= TOWER_R
                                        then
                                            nMatch = nMatch + 1
                                            if bWt then nWt = nWt + 1 end
                                        end
                                    end
                                end
                                if nMatch > 0 then
                                    bump('utb')
                                    if nWt > 0 then bump('utb_has_wt') end
                                    -- THE NARROWING'S DOMAIN: every building
                                    -- that set bUnderOwnTower is an outpost, so
                                    -- the refusal rests on nothing but outposts.
                                    if nWt == nMatch then bump('utb_wt_only') end
                                end
                                -- The two ally-side conjuncts that gate the
                                -- same branch, counted separately so a zero
                                -- flip can be attributed to a LIVE conjunct
                                -- rather than to a dead one.
                                local tDivers = J.GetEnemiesNearLoc(ally:GetLocation(), DIVER_R) or {}
                                if J.GetHP(ally) < ALLY_HP
                                    and #tDivers >= 1 and #tDivers <= 2
                                then
                                    bump('lowhp_divers')
                                    if nMatch > 0 and nWt == nMatch then
                                        bump('flip_candidates')
                                    end
                                end
                            end
                        end
                    end

                    -- (2) THE ARMS, on the published helper. Forcing the
                    -- predicate FALSE is an EXACT reconstruction of the
                    -- pre-narrowing tree (`and not false` is the identity), so
                    -- arm A is the old code rather than a model of it.
                    -- (2) ...and this row's NAME is recorded for the arms,
                    -- which cannot share this load -- see below.
                    drivable[#drivable + 1] = { path = path, name = h:GetUnitName() }
                end
            end
        end
    end

    -- ------------------------------------------------------------ the arms ---
    --
    -- ⛔ EACH ARM TAKES ITS OWN rf.load, and that is not caution -- it is the
    -- reading this file's own §6 control produced the first time it ran. Driven
    -- five times on ONE load, 4 of 657 rows answered differently when arm A was
    -- re-taken at the end: J.GetRescueTpTarget mutates module state on a fire
    -- (J.TryTakeTpResponseSlot burns the team's one-per-window response slot,
    -- J.NoteRescueResponse stamps the 15s chain memory), so arms B/C/D were
    -- reading a world arm A had already spent. Those 4 "flips" were the
    -- harness, not the subject. Same trap the defend-TP family registered in
    -- GH #767 §4 -- and the reason §6 stays in the file even now that it is
    -- green: it is the assertion that this isolation is still real.
    -- ⛔ NOT MEMOISED, and that is the whole point of the paragraph above.
    -- Kept as a named local so the mutation stand can replace exactly this one
    -- line with a caching version and watch §6 go red
    -- (tools/agent/mutstand_rescpost.sh M7).
    local function fresh_load(path) return pcall(rf.load, path) end

    local function drive(path, name, armed_sub, force)
        local ok, J, _, heroes = fresh_load(path)
        if not ok or J == nil then return '<load_fail>' end
        local h = heroes and heroes[name]
        if h == nil then return '<no_hero>' end
        local real_pred = J.IsOutpostBuilding
        J.IsSoakCandidate = function(id)
            return armed_sub ~= nil and id == armed_sub
        end
        -- `force` is 'real' (call the shipped predicate), true or false.
        -- ⛔ NOT nil-as-"real": `function() return nil end` is falsey, so a nil
        -- sentinel would silently make arm B a second copy of arm A and the flip
        -- count would be 0 for a reason that has nothing to do with the corpus.
        if force ~= 'real' then
            J.IsOutpostBuilding = function() return force end
        else
            -- ⭐ COUNT THE BRANCH, NOT THE SPELLING. Mutant M8 (arm B driven
            -- with a nil sentinel instead of 'real') SURVIVED the first run of
            -- tools/agent/mutstand_rescpost.sh: with flip_ab == 0, no count in
            -- this file could tell "arm B reads the shipped predicate" from
            -- "arm B is a second copy of arm A". A textual assertion would guard
            -- only the spelling (the 2026-09-13 lesson); this guards the EVENT --
            -- the real-predicate path either executed or it did not.
            bump('real_pred_drives')
        end
        local okr, r = pcall(J.GetRescueTpTarget, h)
        J.IsOutpostBuilding = real_pred
        if not okr then return '<raised>' end
        return r ~= nil and r:GetUnitName() or '<nil>'
    end

    -- ⭐ WHY MOST ROWS MAY SHARE ONE LOAD, stated as an argument that can be
    -- checked rather than as a convenience. Both pieces of module state this
    -- helper touches are reached ONLY on the fire path:
    -- J.NoteRescueResponse( ally:GetLocation() ) is the statement after the
    -- `then`, and J.TryTakeTpResponseSlot() is the LAST conjunct of the same
    -- `if`, so neither runs unless every earlier conjunct passed. Hence a row on
    -- which NO arm fires cannot have mutated anything, and its five arms are
    -- identical shared or isolated. A row on which ANY arm fires is re-driven
    -- with five fresh loads, where the shared pass is used only to DETECT the
    -- fire -- and detection is sound in one direction, which is the direction
    -- needed: contamination can only mask a later arm's fire, never invent the
    -- first one. §6 is the assertion that this argument still holds (a fired
    -- row whose re-drive disagrees with itself turns it red).
    local armed_id = 'lf_' .. GATE_SUB
    local function drive_shared(J, heroes, name, armed_sub, force)
        local h = heroes and heroes[name]
        if h == nil then return '<no_hero>' end
        local real_pred = J.IsOutpostBuilding
        J.IsSoakCandidate = function(id)
            return armed_sub ~= nil and id == armed_sub
        end
        if force ~= 'real' then
            J.IsOutpostBuilding = function() return force end
        else
            -- ⭐ COUNT THE BRANCH, NOT THE SPELLING. Mutant M8 (arm B driven
            -- with a nil sentinel instead of 'real') SURVIVED the first run of
            -- tools/agent/mutstand_rescpost.sh: with flip_ab == 0, no count in
            -- this file could tell "arm B reads the shipped predicate" from
            -- "arm B is a second copy of arm A". A textual assertion would guard
            -- only the spelling (the 2026-09-13 lesson); this guards the EVENT --
            -- the real-predicate path either executed or it did not.
            bump('real_pred_drives')
        end
        local okr, r = pcall(J.GetRescueTpTarget, h)
        J.IsOutpostBuilding = real_pred
        if not okr then return '<raised>' end
        return r ~= nil and r:GetUnitName() or '<nil>'
    end

    for _, row in ipairs(drivable) do
        local a, b, cc, d, a2
        -- pass 1: five arms on one load, used to answer "did anything fire?"
        local okL, J, _, heroes = fresh_load(row.path)
        if not okL or J == nil then
            a, b, cc, d, a2 = '<load_fail>', '<load_fail>', '<load_fail>',
                '<load_fail>', '<load_fail>'
        else
            a = drive_shared(J, heroes, row.name, armed_id, false)
            b = drive_shared(J, heroes, row.name, armed_id, 'real')
            cc = drive_shared(J, heroes, row.name, armed_id, true)
            d = drive_shared(J, heroes, row.name, nil, true)
            a2 = drive_shared(J, heroes, row.name, armed_id, false)
        end
        if a ~= '<nil>' or b ~= '<nil>' or cc ~= '<nil>'
            or d ~= '<nil>' or a2 ~= '<nil>'
        then
            -- pass 2: something fired, so the shared pass is not admissible for
            -- this row. Re-take every arm on its own load.
            bump('isolated_rows')
            a = drive(row.path, row.name, armed_id, false)  -- pre-narrowing tree
            b = drive(row.path, row.name, armed_id, 'real') -- the tree as landed
            cc = drive(row.path, row.name, armed_id, true)  -- all buildings outposts
            d = drive(row.path, row.name, nil, true)        -- UNARMED, same override
            a2 = drive(row.path, row.name, armed_id, false) -- arm A again
        end

        for _, v in ipairs({ a, b, cc, d, a2 }) do
            if v == '<raised>' or v == '<load_fail>' or v == '<no_hero>' then
                bump('raised')
            end
        end
        if a ~= '<nil>' then bump('fire_a') end
        if b ~= '<nil>' then bump('fire_b') end
        if cc ~= '<nil>' then bump('fire_c') end
        if d ~= '<nil>' then bump('fire_d') end
        if a2 == a then bump('fire_a2') end
        if a ~= b then bump('flip_ab') end
        if a ~= d then bump('flip_ad') end
        -- FORBIDDEN DIRECTION: the narrowing must never take a rescue away
        -- that the pre-narrowing tree answered.
        if a ~= '<nil>' and b == '<nil>' then bump('shrink_ba') end
    end
    return c
end

do
    local ok, res = pcall(run_sweep)
    if ok then SWEEP = res else SWEEP_ERR = tostring(res) end
end

--- ⛔ EVERY COUNTING SECTION CALLS THIS FIRST. Several claims here have the
--- shape `x == 0`, and on a dead census that reads `nil == nil` = TRUE: a dead
--- gauge would free-certify the very readings this file exists to take (GH
--- #171; the M8 lesson of 2026-09-12). Fail loudly instead.
local function census_or_die()
    assert(SWEEP ~= nil,
        'the corpus sweep DIED and every count in this file is nil. A zero read '
        .. 'off a dead census is not a zero. Underlying error: '
        .. tostring(SWEEP_ERR))
end

-- ============================================================== sections ===

tests['[rescpost] 1. the conjunct is in the shipped bytes, in order, id-free'] = function()
    local iValid = HOST:find('J.IsValidBuilding( b )', 1, true)
    local iName = HOST:find("string.find( b:GetUnitName(), 'tower' ) ~= nil", 1, true)
    local iCut = HOST:find('and not J.IsOutpostBuilding( b )', 1, true)
    local iDist = HOST:find('GetUnitToLocationDistance( b, ally:GetLocation() ) <= '
        .. TOWER_R, 1, true)
    assert(iCut ~= nil,
        'the outpost narrowing is GONE from J.GetRescueTpTarget. Every count in '
        .. 'this file is about a tree that has it.')
    assert(iValid ~= nil and iName ~= nil and iDist ~= nil,
        'the bUnderOwnTower admission test no longer has the three terms this '
        .. 'file measured around (valid / name / distance)')
    assert(iValid < iName and iName < iCut and iCut < iDist,
        'the admission terms are out of order (want valid < name < outpost < '
        .. 'distance): the cheap tests must stay ahead of the narrowing')

    -- ⛔ NO NEW ID HERE. The host is gated by its own early return, so a second
    -- gate would be a candidate nested under an unarmed candidate -- the
    -- pullcad trap's cousin (AGENTS.md; GH #606). The only IsSoakCandidate
    -- mention in this host must be the one inside J.IsLaneFixOn's own call.
    assert(HOST:find('IsSoakCandidate', 1, true) == nil,
        'J.GetRescueTpTarget now reads a soak candidate DIRECTLY. This file '
        .. 'asserts the narrowing inherits the host gate and adds no id; if a '
        .. 'new id was genuinely wanted, criterion (甲) says the host had to be '
        .. 'promoted first -- and it is not.')
    local iGate = HOST:find("J.IsLaneFixOn( '" .. GATE_SUB .. "' )", 1, true)
    assert(iGate ~= nil and iGate < iCut,
        'the host gate no longer stands ABOVE the narrowing. Arm D (§5) is '
        .. 'discharged by that early return; move the conjunct above it and the '
        .. 'narrowing reaches shipped play un-gated.')
end

tests['[rescpost] 2. the name-test family, counted in the TREE not in prose'] = function()
    -- ⭐ The 2026-09-13 lesson, applied one round later: the previous census
    -- read "the two/three sites" off a sentence, and the member it omitted was
    -- the only live one. So count the SHAPE -- a `'tower'` name test on a
    -- building handle -- across bots/, pair each with the outpost cut in its
    -- own conjunction, and register the survivors by name.
    local WHOLE = stripped(read_file(TRG))
    local sites, narrowed, open = 0, 0, {}
    local at = 1
    while true do
        local s, e = WHOLE:find("string%.find%([^\n]-GetUnitName%(%)[^\n]-'tower'", at)
        if s == nil then break end
        sites = sites + 1
        -- Look back and forward inside the same conjunction (the admission
        -- test is a handful of lines, never 240 characters away from its own cut).
        local window = WHOLE:sub(math.max(1, s - 240), math.min(#WHOLE, e + 240))
        if window:find('IsOutpostBuilding', 1, true) ~= nil then
            narrowed = narrowed + 1
        else
            -- Name the host so a new open site announces itself BY NAME.
            -- ⛔ NOT `head:match('function (J%.[%w_]+)[^\n]*$')`: `$` anchors to
            -- the end of the whole prefix, and there are thousands of newlines
            -- between the enclosing `function` line and the site, so that
            -- pattern matches nothing and every open site reports as `?` -- a
            -- census whose finding is unreadable. Walk forward instead and keep
            -- the last header seen before the site.
            local host_name = '?'
            local at2 = 1
            while true do
                local fs, fe, nm = WHOLE:find('\nfunction (J%.[%w_]+)', at2)
                if fs == nil or fs > s then break end
                host_name = nm
                at2 = fe + 1
            end
            open[#open + 1] = host_name
        end
        at = e + 1
    end
    assert(sites >= 3, 'expected at least 3 `tower` name tests in ' .. TRG
        .. ', found ' .. sites .. '. This file was written against a tree with '
        .. 'three; re-read the family before trusting any count here.')
    assert(narrowed == sites - #open,
        'the pairing arithmetic does not close (sites=' .. sites .. ' narrowed='
        .. narrowed .. ' open=' .. #open .. ')')
    -- ⛔ Deliberately NOT written as "two totals are equal": today both totals
    -- happen to be small, and two numbers that are both wrong are the easiest
    -- green in the world. The allowed open set is named.
    --
    -- ⭐ 2026-09-13, one round later: THE ALLOWED SET IS NOW EMPTY. The single
    -- entry it carried -- J.ShouldAbortRoshanAttempt, host `roshgate` -- was
    -- narrowed by `roshpost` (tests/test_roshpost_outpost_narrow.lua), which
    -- closes the name-test half of the GH #782 family. ⛔ This is not "making a
    -- red go green": the assertion below said "exactly one open site", the site
    -- was narrowed, and the registered state moved with it. The MECHANISM is
    -- deliberately kept rather than deleted -- an empty allowed set plus
    -- `#open == 0` is what makes a NEW un-narrowed site announce itself by
    -- name, which is the whole reason this section counts the tree instead of
    -- reading a sentence.
    local allowed = {}
    for _, fn in ipairs(open) do
        assert(allowed[fn] == true,
            'a `tower` name test on a building handle is UN-NARROWED in ' .. fn
            .. '. Either it is the next member of the GH #782 family (narrow '
            .. "it, and the host's promote status decides whether it needs an "
            .. 'id of its own), or it is deliberate -- in which case add it to '
            .. 'the allowed set here with the reason.')
    end
    assert(#open == 0,
        'the open-site count moved to ' .. #open .. '. The registered state is '
        .. 'ZERO: every `tower` name test on a building handle in ' .. TRG
        .. ' is paired with the outpost cut (tpdeftower / divepost / rescpost / '
        .. 'roshpost).')
end

tests['[rescpost] 3. the domain is real, and the instrument is alive'] = function()
    census_or_die()
    assert(SWEEP['load_fail'] == 0,
        SWEEP['load_fail'] .. ' fixtures failed to load; the counts below are '
        .. 'over a truncated corpus')
    assert(SWEEP['raised'] == 0,
        SWEEP['raised'] .. ' rows raised inside a driven arm')
    assert(SWEEP['frames'] > 100 and SWEEP['live'] > 300,
        'the corpus shrank (frames=' .. SWEEP['frames'] .. ' live='
        .. SWEEP['live'] .. '); re-read every number in this file')

    -- The predicate answers on real handles, both ways, and never disagrees
    -- with the literal parsed out of its own source.
    assert(SWEEP['pred_true'] > 0 and SWEEP['pred_false'] > 0,
        'the outpost predicate is not discriminating on real handles (true='
        .. SWEEP['pred_true'] .. ' false=' .. SWEEP['pred_false'] .. '). A '
        .. 'predicate that answers one way everywhere prices nothing.')
    assert(SWEEP['PRED_DISAGREES'] == 0,
        SWEEP['PRED_DISAGREES'] .. ' handles where J.IsOutpostBuilding and the '
        .. 'literal parsed out of it disagree')

    -- ⭐ THE DOMAIN, and it is NOT zero here -- unlike both siblings. Some
    -- allied "tower" within TOWER_R of a far-away ally is an outpost and
    -- NOTHING ELSE, so the refusal rests on an outpost alone.
    assert(SWEEP['utb'] > 0,
        'the shipped name test never fires on this corpus (utb=0), so this file '
        .. 'prices nothing. Check FAR_R/TOWER_R against the host.')
    assert(SWEEP['utb_wt_only'] > 0,
        'utb_wt_only is 0: no frame in this corpus rests the bUnderOwnTower '
        .. 'refusal on an outpost alone, so the narrowing has no measured '
        .. 'domain here. It would still be construction-safe, but say so '
        .. 'instead of leaving this assertion claiming a domain.')
    assert(SWEEP['utb_wt_only'] <= SWEEP['utb_has_wt']
        and SWEEP['utb_has_wt'] <= SWEEP['utb'],
        'the domain counts are not nested (wt_only=' .. SWEEP['utb_wt_only']
        .. ' has_wt=' .. SWEEP['utb_has_wt'] .. ' utb=' .. SWEEP['utb'] .. ')')

    -- ⭐ The positive control: the distance instrument is answering, so a zero
    -- anywhere above is geometry and not a dead gauge.
    assert(MIN_WT_ALLY ~= nil and MIN_WT_ALLY > 0,
        'no outpost-to-ally distance was ever measured (min=' .. tostring(MIN_WT_ALLY)
        .. '). Every zero in this file would then be unattributable.')
    assert(SWEEP['wt_within_tower_r'] > 0 and SWEEP['wt_within_2x'] >= SWEEP['wt_within_tower_r'],
        'the outpost-to-ally instrument reads no hit at the shipped radius '
        .. '(within=' .. SWEEP['wt_within_tower_r'] .. ' within2x='
        .. SWEEP['wt_within_2x'] .. ')')
end

tests['[rescpost] 4. the end-to-end flip, and the zero is attributed'] = function()
    census_or_die()
    -- The arms are exact counterfactuals of each other, so the direction is
    -- checkable rather than argued: the narrowing may only ADD rescues.
    assert(SWEEP['shrink_ba'] == 0,
        SWEEP['shrink_ba'] .. ' row(s) lost a rescue the pre-narrowing tree '
        .. 'answered. The conjunct is on the admission test of the loop that '
        .. 'SETS bUnderOwnTower, so this direction is impossible by '
        .. 'construction -- a hit here means the landing is not the change this '
        .. 'file describes.')
    assert(SWEEP['fire_b'] >= SWEEP['fire_a'],
        'armed-with-narrowing fired LESS often (' .. SWEEP['fire_b'] .. ') than '
        .. 'the pre-narrowing tree (' .. SWEEP['fire_a'] .. ')')
    -- ⭐ ARM B REALLY READ THE SHIPPED PREDICATE. Exactly one arm per driven row
    -- takes the real-predicate path -- once in the shared pass for every row,
    -- and once more per re-driven row -- so the identity is exact. Without it,
    -- collapsing arm B onto arm A is invisible on a corpus where flip_ab is 0
    -- (measured: mutant M8 survived until this assertion existed).
    assert(SWEEP['real_pred_drives'] == SWEEP['live'] + SWEEP['isolated_rows'],
        'the real-predicate path ran ' .. SWEEP['real_pred_drives']
        .. ' times, expected live+isolated = '
        .. (SWEEP['live'] + SWEEP['isolated_rows']) .. '. Arm B is not being '
        .. 'driven against the shipped predicate, so every flip count below '
        .. 'compares arm A with itself.')
    assert(SWEEP['fire_c'] >= SWEEP['fire_b'],
        'forcing every building to read as an outpost fired LESS often ('
        .. SWEEP['fire_c'] .. ') than the real predicate (' .. SWEEP['fire_b']
        .. '), which cannot happen: arm C can only release refusals arm B keeps.')

    -- ⛔ THE ZERO IS ATTRIBUTED TO A LIVE CONJUNCT, not left bare. The domain
    -- (§3) is non-empty, but no frame in it also clears the branch's ally-side
    -- bar, and that bar is measurably alive on this corpus.
    if SWEEP['flip_ab'] == 0 then
        assert(SWEEP['lowhp_divers'] > 0,
            'flip_ab is 0 AND the ally-side conjunct it is attributed to '
            .. '(nAllyHP < ' .. ALLY_HP .. ' with 1-2 divers) never fires '
            .. 'either. Both zeroes would then be unattributable -- the shape '
            .. 'this file exists to avoid.')
        assert(SWEEP['flip_candidates'] == 0,
            SWEEP['flip_candidates'] .. ' row(s) are in the domain AND clear '
            .. 'the ally-side bar, yet the end-to-end flip is 0. Something '
            .. 'upstream of the loop (TP scroll, HP floor, DotaTime window, '
            .. 'interrupt test) is swallowing them: name it before reporting '
            .. 'this zero.')
    else
        assert(SWEEP['flip_candidates'] > 0,
            'flip_ab is ' .. SWEEP['flip_ab'] .. ' but flip_candidates is 0: '
            .. 'the end-to-end drive and the population arithmetic disagree '
            .. 'about the same frames, so one of the two is wrong.')
    end
end

tests['[rescpost] 5. arm D -- the host gate is load-bearing, driven'] = function()
    census_or_die()
    -- ⭐ "Gate present" vs "gate load-bearing" (criterion 丙). Arm D forces the
    -- predicate exactly as arm C does but leaves the host UNARMED: every row
    -- must answer nil, and no row may differ from the pre-narrowing tree.
    assert(SWEEP['fire_d'] == 0,
        SWEEP['fire_d'] .. ' row(s) answered a rescue while the host was '
        .. 'UNARMED. J.GetRescueTpTarget is reaching shipped play, so this '
        .. "round's conjunct is changing live behaviour with no wave behind it.")
    -- ⭐ AND THE DIFFERENCE MUST BE EXACTLY THE FIRE SET. Unlike the sibling
    -- files, arm A here is ARMED (the pre-narrowing tree) while arm D is
    -- UNARMED, so `flip_ad == 0` would be the WRONG claim -- it would say the
    -- gate changes nothing, i.e. that the helper is dead. The right claim is
    -- that every row on which the armed helper answers is a row on which the
    -- unarmed one does not, and no other row moves:
    assert(SWEEP['flip_ad'] == SWEEP['fire_a'],
        'the armed/unarmed difference (' .. SWEEP['flip_ad'] .. ' rows) is not '
        .. 'exactly the fire set (' .. SWEEP['fire_a'] .. ' rows). Some row '
        .. 'changed answer between armed and unarmed WITHOUT either arm firing, '
        .. 'which nothing in this helper can do.')
    assert(SWEEP['fire_a'] > 0,
        'the armed helper never fires on this corpus, so arm D is comparing '
        .. 'nil with nil and certifies nothing. (It fired on 6 rows when this '
        .. 'file was written; a zero here means the corpus or an upstream '
        .. 'conjunct moved -- re-read every number in this file.)')
    -- ⚠️ AND THE HONEST SCOPE OF THIS ARM, stated rather than glossed: what
    -- `fire_d == 0` proves is that THE HOST GATE is load-bearing, not that a
    -- conjunct-level gate is -- there is no conjunct-level gate here, by design
    -- (§1, criterion 甲). ⭐ Unlike both sibling files the claim is not vacuous:
    -- the armed helper really does answer on this corpus, so the two arms are
    -- separated by a measured difference and not by nil == nil. A landing that
    -- had hoisted the conjunct above the gate -- or deleted the gate, which is
    -- mutant M5 in tools/agent/mutstand_rescpost.sh -- fails HERE while passing
    -- every other section in this file.
end

tests['[rescpost] 6. the helper keeps no ledger (the re-drive control)'] = function()
    census_or_die()
    -- Every arm above shares one rf.load per fixture. That is only sound if the
    -- helper consumes no module-level state between drives -- and this helper
    -- has TWO candidates for it: J.TryTakeTpResponseSlot (a team quota) and
    -- J.NoteRescueResponse (the 15s chain memory), both reached only AFTER a
    -- fire. Arm A is re-taken after arms B/C/D on every row; it must answer
    -- identically, or the arms are not comparable and this file's design is
    -- wrong rather than its subject.
    -- ...and the isolation path must actually be EXERCISED. If nothing ever
    -- fired, the two-tier scheme above would be untested code and this
    -- section's green would mean only "no row was ever at risk".
    assert(SWEEP['isolated_rows'] > 0,
        'no row was ever re-driven on isolated loads (isolated_rows=0), so the '
        .. 'fire-detection tier is dead code here and §6 certifies nothing. '
        .. 'Either the helper stopped firing on this corpus -- re-read every '
        .. 'number in this file -- or the detection condition is wrong.')
    assert(SWEEP['isolated_rows'] >= SWEEP['fire_a'],
        'more rows fired arm A (' .. SWEEP['fire_a'] .. ') than were isolated ('
        .. SWEEP['isolated_rows'] .. '), which is impossible: every fire must '
        .. 'trigger the re-drive.')
    assert(SWEEP['fire_a2'] == SWEEP['live'],
        (SWEEP['live'] - SWEEP['fire_a2']) .. ' of ' .. SWEEP['live']
        .. ' rows answered DIFFERENTLY when the pre-narrowing arm was re-driven '
        .. 'after the other three. J.GetRescueTpTarget now carries state across '
        .. 'calls (quota or chain memory), so every arm in this file must take a '
        .. 'fresh rf.load.')
end

return tests

-- [roshpost 20260913] THE ROSHAN-ABORT "ONE OF OUR TOWERS IS UNDER PRESSURE"
-- LEG NO LONGER COUNTS A CAPTURED OUTPOST AS A TOWER.
--
-- ⭐ WHAT LANDED, IN ONE LINE: `and not J.IsOutpostBuilding( b )` in the
-- admission test of J.ShouldAbortRoshanAttempt's leg-(b) building loop. One
-- conjunct, ⛔ NO NEW SOAK ID, no new constant.
--
-- ⭐⭐ THIS CLOSES THE NAME-TEST HALF OF THE GH #782 FAMILY, and the closing
-- member is the one the family's own registry had been carrying as "still
-- open" for three rounds:
--   * J.ShouldTpSupportTowerFight -- narrowed 09-13 ('tpdeftower', no new id).
--   * J.ShouldPunishDive          -- narrowed 09-13 ('divepost', NEW id: host
--                                    is PROMOTED, so there was no gate to
--                                    inherit).
--   * J.GetRescueTpTarget         -- narrowed 09-13 ('rescpost', no new id).
--   * J.ShouldAbortRoshanAttempt  -- THIS ROUND.
-- tests/test_rescpost_outpost_narrow.lua §2 owns the TREE-WIDE census (it walks
-- every `'tower'` name test in jmz_func.lua and pairs each with the cut in its
-- own conjunction) and its allowed-open set is now EMPTY. That file, not this
-- prose, is what a future round must read: a new un-narrowed site announces
-- itself there BY NAME. §2 below is this file's own local half of that claim,
-- so neither file can go stale alone.
--
-- ⭐⭐ WHY NO NEW ID -- criterion (甲′)'s THIRD state, and it is the cleanest of
-- the three. The host opens with
--     if not J.IsModeTurbo() then return false end
--     if not J.IsSoakCandidate( 'roshgate' ) then return false end
-- i.e. it is gated AS A WHOLE by a single UNPROMOTED candidate. Adding an id
-- here would nest a candidate under an unarmed candidate: no wave could ever
-- isolate it, while `check_armed_wiring.py` would still call it WIRED (the
-- pullcad trap's cousin). So the narrowing inherits `roshgate` and the armed
-- string, iterations/queue.json and iterations/streams/test_set.md are
-- untouched -- the one landing shape that adds nothing under owner P4.2's
-- admission freeze.
--
-- ⭐ THE DEFECT IN ONE SENTENCE, from the code's own words. Leg (b)'s comment
-- reads "one of our towers is under visible pressure while the attempt is still
-- early -- Roshan waits, towers don't". The whole force of that argument is
-- that a tower can FALL while we are in the pit. `string.find( name, 'tower' )`
-- matches `npc_dota_watch_tower`, so a captured outpost with any enemy within
-- 900 is read as a tower about to be lost and the entire Roshan attempt is
-- called off. An outpost cannot fall: it has no health bar to lose and is
-- re-captured by channel, never destroyed. Nothing is being raced, so there is
-- nothing to walk away from. Standard Dota supports the shipped rule and the
-- narrowing for the same reason -- a tower is a structure you can lose, an
-- outpost is a structure you can only borrow.
--
-- ⭐ WHY THE DIRECTION IS CLOSED-FORM, and its sign. The conjunct is added to
-- the admission test of the loop whose body is `return true`, so the set of
-- buildings that can abort is a strict subset: the abort set can only SHRINK.
-- Same sign as tpdeftower/divepost, opposite to rescpost. What it cannot do is
-- abort an attempt the shipped tree continued -- §4's `grow_ba` is that claim,
-- driven end to end rather than argued.
--
-- ⭐⭐ THE ARMS (§4-§6). Forcing J.IsOutpostBuilding to answer FALSE for every
-- handle reproduces the PRE-NARROWING tree EXACTLY -- `and not false` is the
-- identity -- so arm A is the old code, not a model of it:
--   * arm A -- armed, predicate forced FALSE = the tree before this round.
--   * arm B -- armed, real predicate         = the tree as landed.
--   * arm C -- armed, predicate forced TRUE  = every building an outpost, so
--              leg (b) can never fire. Minimal aborts; must be contained by B.
--   * arm D -- UNARMED, predicate forced FALSE = arm A's own world with the
--              host gate shut. Must be false on every row.
-- Arm D is the "gate present vs gate load-bearing" arm criterion (丙) requires,
-- and here it is NOT vacuous: the armed helper really fires (75 rows), so the
-- two arms are separated by a measured difference rather than by false == false.
--
-- ⭐⭐ READINGS AS LANDED (142 frames / 657 live hero-rows / load_fail 0 /
-- raised 0). Census: pred_true 97 / pred_false 1721, PRED_DISAGREES 0;
-- wt_allied 97, wt_with_enemy 1, tower_with_enemy 17, nearest enemy-to-outpost
-- 450.2u -- so every zero below is geometry, not a dead gauge. Leg-(b) sites:
-- site 17 frames, site_has_wt 1, site_wt_only 1.
-- Arms: A 75, B 71, C 0, D 0; flip_ab 4, grow_ba 0, flip_ad 75 == fire_a,
-- fire_a2 657 == live, real_pred_drives 657 == live.
-- ⭐⭐ flip_ab 4 IS THE LOAD-BEARING READING and it is what the three siblings
-- could not buy: this narrowing is not merely construction-safe, it CHANGES
-- THE ANSWER on real frames. The witness is
-- tests/fixtures/f_260820_102030_wk_tower_out_of_reach.lua, DotaTime 436, the
-- DIRE side: a captured `watch_tower` with jakiro at 609.8u and zuus at 450.2u
-- is the ONLY "tower under pressure" on the map, so all four live dire heroes
-- abort the Roshan attempt over a building that cannot be lost. §4 pins that
-- frame by name so the witness cannot quietly leave the corpus.
--
-- ⚠️ THE SCOPE OF THE DRIVE, registered rather than glossed (§7). Every arm is
-- driven with `hRoshan = nil`. That is not a convenience: the corpus contains
-- NO Roshan handle at all (rosh_seen 0 over 142 frames -- the dumper emits
-- heroes and buildings), so it is the only drivable shape. It is also a SHIPPED
-- one -- the host's own comment says the early window is "Roshan unseen or
-- > 60%" and nil is exactly "unseen". The consequence is that leg (a) (the
-- breaking pit tank) is unreachable on every row here, which is what makes the
-- arm differences attributable to leg (b) alone; §7 asserts both halves instead
-- of leaving them as a reader's inference.

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
--- conjunct, and so does the comment block above it in jmz_func.lua. An
--- unstripped read would let either of those satisfy §1.
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

local HOST = block('function J.ShouldAbortRoshanAttempt( bot, hRoshan )')

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

--- Both radii are READ OUT OF THE HOST, never typed here: move a number in
--- jmz_func and this census moves with it (the M13 lesson). A failed parse
--- asserts immediately rather than printing as a zero (the GH #171 shape).
local PRESS_R = tonumber(HOST:match('GetEnemiesNearLoc%( b:GetLocation%(%), (%d+) %)'))
local ROSH_FRAC = tonumber(HOST:match('GetMaxHealth%(%) > ([%d%.]+)'))
assert(PRESS_R ~= nil and ROSH_FRAC ~= nil,
    'could not parse the host constants out of J.ShouldAbortRoshanAttempt '
    .. '(press=' .. tostring(PRESS_R) .. ' roshfrac=' .. tostring(ROSH_FRAC)
    .. '). Every count below is taken at the shipped numbers; re-parse before '
    .. 'trusting any of them.')

--- The host's own gate id, parsed the same way. The arms arm exactly this.
local GATE_ID = HOST:match("J%.IsSoakCandidate%(%s*'([%w_]+)'%s*%)")
assert(GATE_ID ~= nil,
    'J.ShouldAbortRoshanAttempt no longer opens on a bare J.IsSoakCandidate '
    .. 'early return. This whole file assumes the helper is gated as a WHOLE -- '
    .. 'that is why the narrowing carries no id of its own (criterion 甲′).')

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

--- The witness frame, pinned BY NAME so it cannot quietly leave the corpus and
--- take flip_ab with it (§4 turns red instead of going green on an empty set).
local WITNESS = 'f_260820_102030_wk_tower_out_of_reach.lua'

-- ------------------------------------------------------------ the sweep ---

--- ONE pass over the corpus: the census plus five drives per hero-row.
---
--- ⚠️ BUDGET IS NOT MEMBERSHIP, and this file is NOT in the fast Lua hook
--- (tools/agent/lua_gate_manifest.json): the only sanctioned way in is a full
--- re-measure of all ~436 files, which rewrites the whole manifest and is not a
--- small work unit's business (GH #783 is the round that shows the cost). So a
--- red here does not block anybody's push -- the GH #624 shape, registered
--- rather than papered over, as it was for all three siblings.
--- Memoised: every section reads the same numbers.
local SWEEP, SWEEP_ERR = nil, nil
local MIN_ENEMY_TO_WT = nil
local WITNESS_FLIPS = 0

local function run_sweep()
    local c = setmetatable({}, { __index = function() return 0 end })
    local function bump(k) rawset(c, k, c[k] + 1) end
    -- Zero-initialised, so "never reached" and "measured zero" are never the
    -- same thing to a reader (the GH #171 shape).
    for _, k in ipairs({ 'frames', 'live', 'load_fail', 'raised', 'rosh_seen',
        'pred_true', 'pred_false', 'PRED_DISAGREES',
        'wt_allied', 'wt_with_enemy', 'tower_with_enemy',
        'site', 'site_has_wt', 'site_wt_only',
        'fire_a', 'fire_b', 'fire_c', 'fire_d', 'fire_a2',
        'flip_ab', 'flip_ad', 'grow_ba', 'real_pred_drives', 'lega_reachable' }) do
        rawset(c, k, 0)
    end

    --- ⛔ `force` is 'real' (call the shipped predicate), true or false --
    --- NOT nil-as-"real": `function() return nil end` is falsey, so a nil
    --- sentinel would silently make arm B a second copy of arm A. On this
    --- corpus flip_ab is non-zero so that collapse would show, but the two
    --- siblings measured it the hard way (mutant M8) and the shape is cheap to
    --- keep right.
    local function drive(J, heroes, name, armed, force)
        local h = heroes and heroes[name]
        if h == nil then return '<no_hero>' end
        local real_pred = J.IsOutpostBuilding
        J.IsSoakCandidate = function(id)
            return armed and id == GATE_ID
        end
        if force ~= 'real' then
            J.IsOutpostBuilding = function() return force end
        else
            -- ⭐ COUNT THE BRANCH, NOT THE SPELLING: the real-predicate path
            -- either executed or it did not. A textual assertion would guard
            -- only the spelling (the 2026-09-13 lesson).
            bump('real_pred_drives')
        end
        -- ⚠️ hRoshan = nil: the corpus carries no Roshan handle (§7), and nil
        -- is the shipped "Roshan unseen" case the host's own comment names.
        local okr, r = pcall(J.ShouldAbortRoshanAttempt, h, nil)
        J.IsOutpostBuilding = real_pred
        if not okr then return '<raised>' end
        return r and 'T' or 'F'
    end

    for _, path in ipairs(corpus_paths()) do
        local ok, J, subject, heroes = pcall(rf.load, path)
        if not ok or J == nil then
            bump('load_fail')
        else
            bump('frames')

            -- (0) Is a Roshan handle reachable at all? If one ever is, §7's
            -- claim that leg (a) is out of reach stops being free and this
            -- file must re-price the drive rather than keep passing nil.
            for _, u in pairs(GetUnitList(UNIT_LIST_ALL) or {}) do
                if u ~= nil and u.GetUnitName ~= nil
                    and string.find(u:GetUnitName(), 'roshan') ~= nil
                then
                    bump('rosh_seen')
                    break
                end
            end

            -- (1) THE CENSUS. Leg (b) has no bot term at all -- it reads only
            -- the allied building list -- so it is re-derived ONCE per frame,
            -- at the shipped radius, using the shipped predicate on real
            -- handles.
            local nMatch, nWt = 0, 0
            for _, b in pairs(GetUnitList(UNIT_LIST_ALLIED_BUILDINGS) or {}) do
                if J.IsValidBuilding(b) then
                    local bWt = J.IsOutpostBuilding(b) and true or false
                    if bWt then bump('pred_true') else bump('pred_false') end
                    -- ...and the predicate must agree with the literal parsed
                    -- out of its own source, on these same handles.
                    if (string.find(b:GetUnitName(), OUTPOST_NAME) ~= nil) ~= bWt then
                        bump('PRED_DISAGREES')
                    end
                    local nPress = #(J.GetEnemiesNearLoc(b:GetLocation(), PRESS_R) or {})
                    if bWt then
                        -- ⭐ THE POSITIVE CONTROL FOR A NEGATIVE READING. The
                        -- domain counts below are small, and a broken distance
                        -- instrument would hand back a zero for free and look
                        -- identical to a real one. So the nearest enemy-to-
                        -- outpost distance ever seen is reported: a finite,
                        -- sub-radius value attributes any zero to GEOMETRY
                        -- rather than to a dead measurement.
                        bump('wt_allied')
                        if nPress > 0 then bump('wt_with_enemy') end
                        for _, e in pairs(GetUnitList(UNIT_LIST_ENEMY_HEROES) or {}) do
                            local d = GetUnitToLocationDistance(e, b:GetLocation())
                            if MIN_ENEMY_TO_WT == nil or d < MIN_ENEMY_TO_WT then
                                MIN_ENEMY_TO_WT = d
                            end
                        end
                    elseif string.find(b:GetUnitName(), 'tower') ~= nil and nPress > 0 then
                        -- ⭐ THE OTHER HALF OF THE CONTROL: real towers really
                        -- do come under pressure on this corpus, so the
                        -- narrowing is trimming a contaminated leg, not
                        -- emptying a leg that never fires.
                        bump('tower_with_enemy')
                    end
                    if string.find(b:GetUnitName(), 'tower') ~= nil and nPress > 0 then
                        nMatch = nMatch + 1
                        if bWt then nWt = nWt + 1 end
                    end
                end
            end
            if nMatch > 0 then
                bump('site')
                if nWt > 0 then bump('site_has_wt') end
                -- THE NARROWING'S DOMAIN: every building that would abort is an
                -- outpost, so the abort rests on nothing but outposts.
                if nWt == nMatch then bump('site_wt_only') end
            end

            -- (2) THE ARMS, on the published helper. All five share one load:
            -- §6 is the assertion that this is sound (the helper reads and
            -- returns, it consumes no module state -- unlike the rescue-TP
            -- sibling, whose quota burned on a fire and forced isolated loads).
            for _, h in pairs(heroes or {}) do
                -- tests/mock/replay_fixture.lua binds the enemy and building
                -- lists to the LOADED subject's team, so only heroes on that
                -- team can be driven as the acting bot (inherited trap, GH
                -- #767 §4).
                if h ~= nil and h.IsAlive and h:IsAlive()
                    and h:GetTeam() == subject:GetTeam()
                then
                    bump('live')
                    local name = h:GetUnitName()
                    local a  = drive(J, heroes, name, true,  false)  -- pre-narrowing
                    local b  = drive(J, heroes, name, true,  'real') -- as landed
                    local cc = drive(J, heroes, name, true,  true)   -- all outposts
                    local d  = drive(J, heroes, name, false, false)  -- UNARMED, arm A's world
                    local a2 = drive(J, heroes, name, true,  false)  -- arm A again

                    for _, v in ipairs({ a, b, cc, d, a2 }) do
                        if v == '<raised>' or v == '<no_hero>' then bump('raised') end
                    end
                    if a == 'T' then bump('fire_a') end
                    if b == 'T' then bump('fire_b') end
                    if cc == 'T' then bump('fire_c') end
                    if d == 'T' then bump('fire_d') end
                    if a2 == a then bump('fire_a2') end
                    if a ~= b then
                        bump('flip_ab')
                        if path:sub(-#WITNESS) == WITNESS then
                            WITNESS_FLIPS = WITNESS_FLIPS + 1
                        end
                    end
                    if a ~= d then bump('flip_ad') end
                    -- FORBIDDEN DIRECTION: the narrowing must never abort an
                    -- attempt the pre-narrowing tree let continue.
                    if a ~= 'T' and b == 'T' then bump('grow_ba') end
                end
            end
        end
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

tests['[roshpost] 1. the conjunct is in the shipped bytes, in order, id-free'] = function()
    local iValid = HOST:find('J.IsValidBuilding( b )', 1, true)
    local iName = HOST:find("string.find( b:GetUnitName(), 'tower' ) ~= nil", 1, true)
    local iCut = HOST:find('and not J.IsOutpostBuilding( b )', 1, true)
    local iPress = HOST:find('#J.GetEnemiesNearLoc( b:GetLocation(), ' .. PRESS_R
        .. ' ) > 0', 1, true)
    assert(iCut ~= nil,
        'the outpost narrowing is GONE from J.ShouldAbortRoshanAttempt. Every '
        .. 'count in this file is about a tree that has it.')
    assert(iValid ~= nil and iName ~= nil and iPress ~= nil,
        'the leg-(b) admission test no longer has the three terms this file '
        .. 'measured around (valid / name / pressure)')
    assert(iValid < iName and iName < iCut and iCut < iPress,
        'the admission terms are out of order (want valid < name < outpost < '
        .. 'pressure): the cheap tests must stay ahead of the narrowing, and '
        .. 'the narrowing ahead of the enemy scan it exists to skip')

    -- ⛔ NO NEW ID HERE, and the gate must stay ABOVE the conjunct. The host is
    -- gated as a whole by one UNPROMOTED candidate, so a second gate would be a
    -- candidate nested under an unarmed candidate -- no wave can isolate it
    -- while check_armed_wiring.py still calls it WIRED (the pullcad trap's
    -- cousin; AGENTS.md, GH #606).
    local _, nGates = HOST:gsub('IsSoakCandidate', '')
    assert(nGates == 1,
        'J.ShouldAbortRoshanAttempt now reads ' .. nGates .. ' soak candidates. '
        .. 'This file asserts the narrowing inherits the single host gate and '
        .. 'adds none; if a new id was genuinely wanted, criterion (甲) says the '
        .. 'host had to be PROMOTED first -- and `' .. GATE_ID .. '` is not.')
    local iGate = HOST:find("J.IsSoakCandidate( '" .. GATE_ID .. "' )", 1, true)
    assert(iGate ~= nil and iGate < iCut,
        'the host gate no longer stands ABOVE the narrowing. Arm D (§5) is '
        .. 'discharged by that early return; move the conjunct above it and the '
        .. 'narrowing reaches shipped play un-gated.')
end

tests['[roshpost] 2. this host is narrowed, and the family census still owns the tree'] = function()
    -- ⭐ The local half. The TREE-WIDE walk lives in
    -- tests/test_rescpost_outpost_narrow.lua §2 (it pairs every `'tower'` name
    -- test in this file with the cut in its own conjunction and names any
    -- survivor). Two things must hold for that division of labour to be safe,
    -- and both are asserted here rather than assumed:
    --   (a) this host carries exactly one such name test, and it is paired;
    --   (b) the owning census still EXISTS and still registers an allowed-open
    --       set -- a deleted or gutted §2 must not read as "family closed".
    local _, nNameTests = HOST:gsub("string%.find%([^\n]-GetUnitName%(%)[^\n]-'tower'", '')
    assert(nNameTests == 1,
        'J.ShouldAbortRoshanAttempt now has ' .. nNameTests .. " `'tower'` name "
        .. 'tests; this file narrowed exactly one. A second one is a new family '
        .. 'member inside the same host -- narrow it or register it.')

    local owner = 'tests/test_rescpost_outpost_narrow.lua'
    local f = io.open(owner, 'r')
    assert(f ~= nil,
        owner .. ' is gone. It owns the tree-wide census for the GH #782 '
        .. 'name-test family; without it nothing walks bots/ for a new '
        .. 'un-narrowed site and this file would be certifying only its own '
        .. 'host.')
    local osrc = f:read('*a')
    f:close()
    assert(osrc:find('local allowed = {', 1, true) ~= nil
        and osrc:find('#open ==', 1, true) ~= nil,
        owner .. ' no longer carries the allowed-open set and the open-site '
        .. 'count. That census is the only thing that makes a NEW un-narrowed '
        .. "site announce itself by name; this file's green does not cover it.")
end

tests['[roshpost] 3. the domain is real, and the instrument is alive'] = function()
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

    -- ⭐ THE DOMAIN: some frame's entire "tower under pressure" reading rests on
    -- an outpost and nothing else.
    assert(SWEEP['site'] > 0,
        'leg (b) never finds a pressured `tower` on this corpus (site=0), so '
        .. 'this file prices nothing. Check PRESS_R against the host.')
    assert(SWEEP['site_wt_only'] > 0,
        'site_wt_only is 0: no frame rests the abort on an outpost alone, so '
        .. 'the narrowing has no measured domain here. It would still be '
        .. 'construction-safe, but say so instead of leaving this assertion '
        .. 'claiming a domain.')
    assert(SWEEP['site_wt_only'] <= SWEEP['site_has_wt']
        and SWEEP['site_has_wt'] <= SWEEP['site'],
        'the domain counts are not nested (wt_only=' .. SWEEP['site_wt_only']
        .. ' has_wt=' .. SWEEP['site_has_wt'] .. ' site=' .. SWEEP['site'] .. ')')

    -- ⭐ THE POSITIVE CONTROLS. (a) the distance instrument answers at all, and
    -- (b) REAL towers do come under pressure here -- so this narrowing trims a
    -- contaminated leg rather than emptying a leg that never fired.
    assert(MIN_ENEMY_TO_WT ~= nil and MIN_ENEMY_TO_WT > 0 and MIN_ENEMY_TO_WT < PRESS_R,
        'no enemy was ever measured inside the shipped pressure radius of an '
        .. 'outpost (min=' .. tostring(MIN_ENEMY_TO_WT) .. ', radius=' .. PRESS_R
        .. '). Every zero in this file would then be unattributable.')
    assert(SWEEP['wt_allied'] > 0 and SWEEP['wt_with_enemy'] > 0,
        'outposts are absent from the allied building list (wt_allied='
        .. SWEEP['wt_allied'] .. ') or never pressured (wt_with_enemy='
        .. SWEEP['wt_with_enemy'] .. '); the contamination this file narrows '
        .. 'would then be unobservable here.')
    assert(SWEEP['tower_with_enemy'] > 0,
        'no REAL tower is ever under pressure on this corpus, so leg (b) after '
        .. 'the narrowing has no live domain at all -- that is a different '
        .. 'finding from the one this file reports, and it must not pass '
        .. 'silently.')
end

tests['[roshpost] 4. the end-to-end flip, its direction, and its witness'] = function()
    census_or_die()
    -- ⭐ ARM B REALLY READ THE SHIPPED PREDICATE. Exactly one arm per driven row
    -- takes the real-predicate path, so the identity is exact. Without it,
    -- collapsing arm B onto arm A is invisible to every other count here
    -- (measured on a sibling: mutant M8 survived until this assertion existed).
    assert(SWEEP['real_pred_drives'] == SWEEP['live'],
        'the real-predicate path ran ' .. SWEEP['real_pred_drives']
        .. ' times, expected one per live row (' .. SWEEP['live'] .. '). Arm B '
        .. 'is not being driven against the shipped predicate, so every flip '
        .. 'count here compares arm A with itself.')

    -- Direction, checkable rather than argued: the conjunct is on the admission
    -- test of a loop whose body is `return true`, so the abort set is a strict
    -- subset and this direction is impossible by construction.
    assert(SWEEP['grow_ba'] == 0,
        SWEEP['grow_ba'] .. ' row(s) ABORTED the Roshan attempt that the '
        .. 'pre-narrowing tree let continue. A hit here means the landing is '
        .. 'not the change this file describes.')
    assert(SWEEP['fire_b'] <= SWEEP['fire_a'],
        'armed-with-narrowing aborted MORE often (' .. SWEEP['fire_b']
        .. ') than the pre-narrowing tree (' .. SWEEP['fire_a'] .. ')')
    assert(SWEEP['fire_c'] <= SWEEP['fire_b'],
        'forcing every building to read as an outpost aborted MORE often ('
        .. SWEEP['fire_c'] .. ') than the real predicate (' .. SWEEP['fire_b']
        .. '), which cannot happen: arm C can only suppress aborts arm B keeps.')

    -- ⭐⭐ THE LOAD-BEARING READING, and the one all three siblings had to do
    -- without: the narrowing CHANGES THE ANSWER on real frames.
    assert(SWEEP['flip_ab'] > 0,
        'flip_ab is 0: the narrowing changes no answer anywhere on this corpus. '
        .. 'It would still be construction-safe, but the claim in this file`s '
        .. 'header -- that it is load-bearing rather than merely harmless -- '
        .. 'would be unsupported. Re-read the domain counts in §3.')
    assert(SWEEP['flip_ab'] == SWEEP['fire_a'] - SWEEP['fire_b'],
        'flip_ab (' .. SWEEP['flip_ab'] .. ') is not the drop from arm A ('
        .. SWEEP['fire_a'] .. ') to arm B (' .. SWEEP['fire_b'] .. '). With '
        .. 'grow_ba == 0 every flip must be an abort that was removed; a '
        .. 'mismatch means some row moved in a way neither count explains.')

    -- ⛔ AND THE WITNESS IS PINNED BY NAME. Without this, a corpus that lost the
    -- one contaminated frame would fail the assertion above with no hint of
    -- WHY, and a corpus that gained a different one would pass while this
    -- file's header described a frame that is no longer there.
    assert(WITNESS_FLIPS > 0,
        'the registered witness frame ' .. WITNESS .. ' no longer flips. Either '
        .. 'it left tests/fixtures/ or its geometry moved; this file`s header '
        .. 'quotes it (DotaTime 436, dire side, a captured watch_tower with '
        .. 'jakiro 609.8u and zuus 450.2u) and that quote is now stale.')
    assert(WITNESS_FLIPS <= SWEEP['flip_ab'],
        'the witness contributed ' .. WITNESS_FLIPS .. ' of ' .. SWEEP['flip_ab']
        .. ' flips, which is arithmetically impossible')
end

tests['[roshpost] 5. arm D -- the host gate is load-bearing, driven'] = function()
    census_or_die()
    -- ⭐ "Gate present" vs "gate load-bearing" (criterion 丙). Arm D forces the
    -- predicate exactly as arm A does but leaves the host UNARMED: every row
    -- must answer false.
    assert(SWEEP['fire_d'] == 0,
        SWEEP['fire_d'] .. ' row(s) aborted a Roshan attempt while the host was '
        .. 'UNARMED. J.ShouldAbortRoshanAttempt is reaching shipped play, so '
        .. "this round's conjunct is changing live behaviour with no wave "
        .. 'behind it.')
    -- ⭐ AND THE DIFFERENCE MUST BE EXACTLY THE FIRE SET. Arm A is ARMED and arm
    -- D is UNARMED over the same forced world, so `flip_ad == 0` would be the
    -- WRONG claim -- it would say the gate changes nothing, i.e. that the
    -- helper is dead. The right claim is that every row on which the armed
    -- helper aborts is a row on which the unarmed one does not, and no other
    -- row moves. (Copying a sibling's `== 0` here is exactly the 2026-09-13
    -- lesson: copy the shape AND the reason the shape holds.)
    assert(SWEEP['flip_ad'] == SWEEP['fire_a'],
        'the armed/unarmed difference (' .. SWEEP['flip_ad'] .. ' rows) is not '
        .. 'exactly the fire set (' .. SWEEP['fire_a'] .. ' rows). Some row '
        .. 'changed answer between armed and unarmed WITHOUT either arm firing, '
        .. 'which nothing in this helper can do.')
    assert(SWEEP['fire_a'] > 0,
        'the armed helper never aborts on this corpus, so arm D is comparing '
        .. 'false with false and certifies nothing. (It fired on 75 rows when '
        .. 'this file was written; a zero here means the corpus or an upstream '
        .. 'conjunct moved -- re-read every number in this file.)')
end

tests['[roshpost] 6. the helper keeps no ledger (the shared-load control)'] = function()
    census_or_die()
    -- Every arm above shares ONE rf.load per fixture, and that is only sound if
    -- the helper consumes no state between drives. Here the argument is that it
    -- reads and returns -- no quota, no memory stamp -- unlike the rescue-TP
    -- sibling, where J.TryTakeTpResponseSlot burned a team quota on the fire
    -- path and forced a per-arm reload. ⛔ The argument is not taken on trust:
    -- arm A is re-taken after arms B/C/D on every row and must answer
    -- identically. A helper that grew a latch turns this red, and the fix is
    -- isolated loads, not a weaker assertion.
    assert(SWEEP['fire_a2'] == SWEEP['live'],
        (SWEEP['live'] - SWEEP['fire_a2']) .. ' of ' .. SWEEP['live']
        .. ' rows answered DIFFERENTLY when the pre-narrowing arm was re-driven '
        .. 'after the other three. J.ShouldAbortRoshanAttempt now carries state '
        .. 'across calls, so every arm in this file must take a fresh rf.load '
        .. '(see tests/test_rescpost_outpost_narrow.lua, which had to).')
end

tests['[roshpost] 7. the drive`s scope: leg (a) is out of reach, and that is measured'] = function()
    census_or_die()
    -- ⚠️ Every arm passes hRoshan = nil. Two things make that honest rather
    -- than convenient, and both are readings, not arguments.
    --
    -- (a) It is the ONLY drivable shape: the dumper emits heroes and buildings,
    --     so no Roshan handle exists anywhere in the corpus. If one ever
    --     appears, leg (a) becomes reachable and the arm differences below stop
    --     being attributable to leg (b) alone -- so this must turn RED then,
    --     not keep passing.
    assert(SWEEP['rosh_seen'] == 0,
        SWEEP['rosh_seen'] .. ' frame(s) now carry a Roshan handle. Passing '
        .. 'hRoshan = nil no longer covers the corpus: leg (a) (the breaking '
        .. 'pit tank) is reachable on those frames and every arm difference in '
        .. 'this file must be re-attributed before it is quoted again.')
    -- (b) It is a SHIPPED shape, not an invented one: with hRoshan nil the host
    --     takes bEarly = true, which its own comment calls "Roshan unseen", and
    --     the whole leg-(a) block is skipped. That is asserted against the
    --     source so a refactor that made nil mean something else cannot slip
    --     past.
    assert(HOST:find('local bEarly = true', 1, true) ~= nil,
        'the host no longer defaults bEarly to true, so hRoshan = nil is no '
        .. 'longer the "Roshan unseen" early window every arm in this file is '
        .. 'driven in.')
    local iRoshGuard = HOST:find('if hRoshan ~= nil', 1, true)
    assert(iRoshGuard ~= nil,
        'the leg-(a) block no longer guards on `hRoshan ~= nil`, so passing nil '
        .. 'may now reach it and the arms are no longer leg-(b)-only.')
    -- ...and arm C is the end-to-end confirmation of exactly that: with every
    -- building reading as an outpost, leg (b) cannot fire, and if leg (a) were
    -- reachable on any row arm C would still abort somewhere.
    assert(SWEEP['fire_c'] == 0,
        SWEEP['fire_c'] .. ' row(s) still abort with EVERY building forced to '
        .. 'read as an outpost. Leg (b) cannot fire there, so another leg is '
        .. 'answering -- name it before quoting any count in this file as '
        .. 'leg-(b)-only.')
end

return tests

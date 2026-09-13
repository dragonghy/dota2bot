-- [divepost 20260913] THE PUNISH-THE-DIVE BUILDING LOOP NO LONGER TREATS A
-- CAPTURED OUTPOST AS A BUILDING WE ARE BEING DIVED AT.
--
-- ⭐ WHAT LANDED, IN ONE LINE: `and not ( bDivePost and J.IsOutpostBuilding(
-- building ) )` in the admission test of J.ShouldPunishDive's building loop.
-- One conjunct, one new soak id ('divepost'), no new constant.
--
-- ⭐⭐ WHY THIS SITE IS WORTH A ROUND WHEN THE TWO BEFORE IT WERE THE SAME
-- CONJUNCT: 'punish' IS PROMOTED. J.ShouldPunishDive runs in EVERY turbo game
-- today (AGENTS.md's promoted list; the header on the helper says so too), so
-- this is the first member of the outpost-anchor family whose defect is
-- SHIPPING rather than waiting behind an unarmed id. The two earlier ones --
-- J.ShouldRefuseUnsupportedPunish ('ohnum', 2026-09-12) and
-- J.ShouldPunishOverchase leg (b) ('overchase') -- sit under unpromoted hosts.
--
-- ⛔ AND THE FINDING THAT IS NOT THE KNIFE, which is the part worth carrying
-- forward. tests/_outpost_anchor_sweep.lua says, in its own header:
--
--     "The two no-name-test anchor sites in bots/:"
--
-- There are THREE, and the one it omits is the only one that is live. The
-- census was written while reading the two GATED helpers (both are candidates
-- the desk was pricing at the time), and a promoted helper with the identical
-- loop shape -- `J.IsValidBuilding( b ) and GetUnitToUnitDistance( enemy, b )
-- <= 1200`, same list, same radius -- was never in its field of view. A census
-- that enumerates by WHO WAS BEING PRICED cannot find the site nobody is
-- pricing, and "the two sites" reads like a closed enumeration afterwards. §1
-- below therefore counts the shape in the tree instead of trusting a prose
-- list, so the next member of this family announces itself.
--
-- ⭐ WHY IT LANDS WITHOUT A WITNESS, and why that is not impatience. The
-- conjunct is added to the loop's ADMISSION test, so the admitted set is a
-- strict subset of the shipped one; `bInDomain` can only fall from true to
-- false, so the helper's response set can only shrink and the change cannot
-- create a punish target. That argument is closed-form: no frame can make it
-- truer. What a frame buys is the EFFECT SIZE, and §3 measures that directly
-- (0 answers change on 653 live hero-rows) instead of leaving it unmeasured.
--
-- ⛔ THE ZERO IS GEOMETRY, NOT A DEAD GAUGE, and §2 is what makes that
-- readable: no visible enemy hero in this corpus is ever within the loop's 1200
-- of an allied outpost (nearest ever seen is reported), while the predicate
-- itself answers TRUE on real outpost handles and FALSE on real towers on the
-- same frames.
--
-- ⭐⭐ THE TWO ARMS THAT ACTUALLY DISCRIMINATE (§4). A no-op reading cannot tell
-- "the conjunct is load-bearing and gated" from "the conjunct is dead code".
-- Both are answered on the SAME code path with one term overridden, never on an
-- out-of-tree copy:
--   * arm C -- 'divepost' armed and J.IsOutpostBuilding forced TRUE for every
--     building: all 32 shipped fires must be SUPPRESSED. A cosmetic conjunct
--     cannot do that.
--   * arm D -- the same override with 'divepost' UNARMED: all 32 fires must
--     SURVIVE. A conjunct that had been landed un-gated would fail here while
--     passing every other section in this file, and it would be changing
--     shipped play under a promoted helper.
-- Arm D is the one this desk would previously not have written; it is the
-- difference between "the gate is present" and "the gate is load-bearing" (the
-- M8 lesson from tools/agent/mutstand_overchase_tense.sh, 2026-09-12).
--
-- Registered: iterations/state.json:divepost_20260913. armed string /
-- queue.json / test_set.md untouched (P4.2 freeze): the id ships GATED and
-- UNARMED, so shipped play is byte-identical until it is admitted and wins.
-- Zero AWS.

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')
local cs = require('corpus_scale')

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

local HOST = block('function J.ShouldPunishDive( bot )')

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

--- The host's own collapse radius and building radius, read out of the host.
local COLLAPSE_R = tonumber(HOST:match('GetNearbyHeroes%( bot, (%d+), true'))
local BUILDING_R = tonumber(HOST:match('GetUnitToUnitDistance%( enemy, building %) <= (%d+)'))
assert(COLLAPSE_R ~= nil and BUILDING_R ~= nil,
    'could not parse the host radii out of J.ShouldPunishDive (collapse='
    .. tostring(COLLAPSE_R) .. ' building=' .. tostring(BUILDING_R) .. '). '
    .. 'Every count below is taken at the shipped numbers, not at literals '
    .. 'typed here; re-parse before re-reading any of them.')

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

--- ONE pass over the corpus, four arms per hero-row plus the census, so the
--- whole file stays inside the fast Lua gate's per-test BUDGET (measured 3.9s
--- against the 5.5s per-test cap; GH #616).
---
--- ⚠️ BUDGET IS NOT MEMBERSHIP, and this file is NOT in the hook today: the
--- only sanctioned way into tools/agent/lua_gate_manifest.json is a full
--- re-measure of all ~436 files, which rewrites the whole manifest and is not a
--- small work unit's business (GH #783 is the round that shows what rewriting
--- it costs). So a red here does not block anybody's push -- the GH #624 shape,
--- registered rather than papered over. The sibling landed 2026-09-13
--- (tests/test_tpdeftower_outpost_narrow.lua) is outside it for the same reason.
--- Memoised: every section reads the same numbers.
local SWEEP, SWEEP_ERR, MIN_WT = nil, nil, nil

local function run_sweep()
    local c = setmetatable({}, { __index = function() return 0 end })
    local function bump(k) rawset(c, k, c[k] + 1) end
    -- Zero-initialised, so "never reached" and "measured zero" are never the
    -- same thing to a reader (the GH #171 shape).
    for _, k in ipairs({ 'frames', 'live', 'load_fail', 'raised',
        'pred_true', 'pred_false', 'PRED_DISAGREES',
        'pairs', 'anchor', 'anchor_has_wt', 'anchor_wt_only',
        'fire_a', 'fire_b', 'fire_c', 'fire_d', 'fire_a2',
        'flip_ab', 'flip_ad', 'cf_suppressed' }) do
        rawset(c, k, 0)
    end

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
            local real_pred = J.IsOutpostBuilding
            for _, h in pairs(heroes or {}) do
                if h ~= nil and h.IsAlive and h:IsAlive()
                    and h:GetTeam() == subj_team
                then
                    bump('live')

                    -- (1) the census: the predicate on REAL handles, and the
                    -- loop's own anchor geometry re-derived at the shipped radii.
                    local okP, tE = pcall(J.GetNearbyHeroes, h, COLLAPSE_R, true, BOT_MODE_NONE)
                    if not okP then
                        bump('raised')
                    else
                        for _, e in pairs(tE or {}) do
                            if J.IsValidHero(e) and not J.IsSuspiciousIllusion(e) then
                                bump('pairs')
                                local nAnchor, nAnchorWt = 0, 0
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
                                        local d = GetUnitToUnitDistance(e, b)
                                        if bWt and (MIN_WT == nil or d < MIN_WT) then MIN_WT = d end
                                        if d <= BUILDING_R then
                                            nAnchor = nAnchor + 1
                                            if bWt then nAnchorWt = nAnchorWt + 1 end
                                        end
                                    end
                                end
                                if nAnchor > 0 then
                                    bump('anchor')
                                    if nAnchorWt > 0 then bump('anchor_has_wt') end
                                    if nAnchorWt == nAnchor then bump('anchor_wt_only') end
                                end
                            end
                        end
                    end

                    -- (2) the four arms, on the real helper. No fresh load
                    -- between them: §5 proves the helper keeps no ledger by
                    -- re-taking arm A at the end of the row.
                    local function drive(ids, force_outpost)
                        local armed = {}
                        for _, id in ipairs(ids) do armed[id] = true end
                        J.IsSoakCandidate = function(id) return armed[id] == true end
                        J.IsOutpostBuilding =
                            force_outpost and function() return true end or real_pred
                        local r = J.ShouldPunishDive(h)
                        J.IsOutpostBuilding = real_pred
                        return r ~= nil and r:GetUnitName() or '<nil>'
                    end

                    local a = drive({}, false)                  -- shipped
                    local b = drive({ 'divepost' }, false)      -- narrowed
                    local cc = drive({ 'divepost' }, true)      -- narrowed, all outposts
                    local d = drive({}, true)                   -- shipped, all outposts
                    local a2 = drive({}, false)                 -- shipped again

                    if a ~= '<nil>' then bump('fire_a') end
                    if b ~= '<nil>' then bump('fire_b') end
                    if cc ~= '<nil>' then bump('fire_c') end
                    if d ~= '<nil>' then bump('fire_d') end
                    if a2 == a then bump('fire_a2') end
                    if a ~= b then bump('flip_ab') end
                    if a ~= d then bump('flip_ad') end
                    if a ~= '<nil>' and cc == '<nil>' then bump('cf_suppressed') end
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

tests['[divepost] 1. the conjunct is in the shipped bytes, gated, and in order'] = function()
    local iValid = HOST:find('J.IsValidBuilding( building )', 1, true)
    local iCut = HOST:find('and not ( bDivePost and J.IsOutpostBuilding( building ) )', 1, true)
    local iDist = HOST:find('GetUnitToUnitDistance( enemy, building ) <= ' .. BUILDING_R, 1, true)
    assert(iCut ~= nil,
        'the outpost narrowing is GONE from J.ShouldPunishDive. Every count in '
        .. 'this file is about a tree that has it.')
    assert(iValid ~= nil and iDist ~= nil,
        'the building-loop admission test no longer has the two terms this file '
        .. 'measured around (valid / distance)')
    assert(iValid < iCut and iCut < iDist,
        'the admission terms are out of order (want valid < outpost < distance)')

    -- The gate is READ once, above the loop, and it is a single id -- not a
    -- conjunction with another candidate. The pullcad trap (AGENTS.md, GH
    -- #606): an id written into another gate's conjunction freezes FALSE the
    -- day that other id is promoted, while check_armed_wiring.py still calls it
    -- WIRED.
    local iRead = HOST:find("local bDivePost = J.IsSoakCandidate( 'divepost' )", 1, true)
    assert(iRead ~= nil and iRead < iCut,
        "'divepost' is no longer read into bDivePost above the loop")
    local seen = {}
    for id in HOST:gmatch("J%.IsSoakCandidate%(%s*'([%w_]+)'%s*%)") do seen[id] = true end
    local n = 0
    for id in pairs(seen) do
        n = n + 1
        assert(id == 'ownhalf' or id == 'divepost',
            "an unexpected soak id '" .. id .. "' has appeared inside "
            .. 'J.ShouldPunishDive. Two independent ids live here on purpose; a '
            .. 'third needs its own reading of the pullcad trap.')
    end
    assert(n == 2, 'expected exactly the ids ownhalf + divepost in the host, saw ' .. n)

    -- ⭐⭐ THE REASON THIS SITE CARRIES AN ID OF ITS OWN. The host is PROMOTED:
    -- it has no candidate gate of its own, so the loop runs in every turbo game
    -- and an ungated narrowing here would change shipped play. If somebody
    -- re-gates the host, this conjunct silently becomes `<host id> AND
    -- divepost` -- the pullcad trap -- and the isolation reading of 'divepost'
    -- stops meaning anything.
    assert(HOST:find('if not J.IsModeTurbo() then return nil end', 1, true) ~= nil,
        'J.ShouldPunishDive is no longer turbo-only on its first line. '
        .. "'divepost' inherits turbo-only from that line and nowhere else.")
    assert(HOST:find("IsSoakCandidate( 'punish' )", 1, true) == nil,
        'J.ShouldPunishDive has acquired a candidate gate of its own. It was '
        .. "PROMOTED (AGENTS.md), which is why 'divepost' exists as a separate "
        .. 'id; re-read the pullcad trap before leaving this conjunct here.')

    -- The predicate it calls is still the ungated pure one, so this caller is
    -- not silently inheriting somebody else's gate.
    local pred = block('function J.IsOutpostBuilding( nTarget )')
    assert(pred:find('IsSoakCandidate', 1, true) == nil
        and pred:find('IsModeTurbo', 1, true) == nil,
        'J.IsOutpostBuilding has acquired a gate. It is a pure predicate and '
        .. 'every caller carries its own.')

    -- ⭐ THE FAMILY COUNT, taken off the TREE rather than off the prose list in
    -- tests/_outpost_anchor_sweep.lua (whose header says "the two no-name-test
    -- anchor sites" and misses this one, because it enumerated the helpers that
    -- were being priced). Every site that anchors on the allied-building list
    -- by proximity must now either name the outpost predicate or be a known
    -- exception; a NEW one shows up here as a red.
    -- Each anchor is PAIRED with the cut that narrows it by looking back over
    -- the conjunction it sits in, rather than by comparing two totals: the
    -- totals happen to be equal today for unrelated reasons (one cut, in
    -- J.ShouldTpSupportTowerFight, narrows a `>` distance test that is not an
    -- anchor of this shape at all), and a pair of equal wrong numbers is the
    -- easiest green in the world to produce by accident.
    local anchors, unnarrowed, names = 0, 0, {}
    local at = 1
    while true do
        local s, e = SRC:find('GetUnitToUnitDistance%(%s*[%w_]+%s*,%s*building%s*%)%s*<=', at)
        if s == nil then break end
        anchors = anchors + 1
        local look = SRC:sub(math.max(1, s - 240), s)
        if look:find('IsOutpostBuilding', 1, true) == nil then
            unnarrowed = unnarrowed + 1
            local fn = SRC:sub(1, s):match('.*function (J%.[%w_]+)')
            names[#names + 1] = fn or '?'
        end
        at = e + 1
    end
    assert(anchors >= 3, 'the building-proximity anchor shape has vanished from '
        .. TRG .. ' (found ' .. anchors .. '); re-read this family')
    assert(unnarrowed == 1,
        unnarrowed .. ' building-proximity anchor(s) in ' .. TRG .. ' do not '
        .. 'narrow away outposts: ' .. table.concat(names, ', ') .. '. EXACTLY '
        .. 'ONE is registered on purpose -- J.ShouldPunishOverchase leg (b), '
        .. 'priced at end-to-end zero (oc_fire_building 0) and deliberately not '
        .. 're-bought. A SECOND one means a new member of this family has '
        .. 'landed: price it, do not re-baseline this number. (This is the '
        .. 'count tests/_outpost_anchor_sweep.lua states as prose -- "the two '
        .. 'no-name-test anchor sites" -- and got wrong by one.)')
end

tests['[divepost] 2. the gauge is alive and the zero is geometry (positive control)'] = function()
    census_or_die()
    cs.corpus(SWEEP['frames'], 'frames driven')
    assert(SWEEP['load_fail'] == 0, SWEEP['load_fail'] .. ' fixture(s) failed to load')
    assert(SWEEP['raised'] == 0, SWEEP['raised'] .. ' row(s) raised inside the census')
    cs.ratchet(SWEEP['live'], 653, 'live hero-rows on the subject team')
    -- ⛔ These baselines are THIS file's own, measured on its own iteration
    -- (one rf.load per fixture, every live hero on the subject's team driven as
    -- the acting bot). tests/_outpost_anchor_sweep.lua reads 1031 rows / 804
    -- pairs over the same corpus because it re-loads once PER UNIT; borrowing
    -- its numbers here would have registered a count this file cannot produce.
    cs.ratchet(SWEEP['pairs'], 557, '(bot, visible enemy) pairs at the shipped collapse radius')

    -- ⭐⭐ THE READINGS THAT MUST BE NON-ZERO before any zero below is allowed
    -- to mean anything: the predicate separates real outposts from real towers
    -- on real corpus handles.
    assert(SWEEP['pred_true'] > 0,
        'J.IsOutpostBuilding matched NOTHING across the whole corpus. The '
        .. 'narrowing is then a no-op for a reason that has nothing to do with '
        .. 'the fights, and §3 measures nothing.')
    assert(SWEEP['pred_false'] > 0,
        'J.IsOutpostBuilding matched EVERY valid building -- it would remove '
        .. 'the entire dive domain, not just the outposts.')
    assert(SWEEP['PRED_DISAGREES'] == 0,
        SWEEP['PRED_DISAGREES'] .. ' building(s) where J.IsOutpostBuilding '
        .. "disagrees with the literal '" .. OUTPOST_NAME .. "' parsed out of "
        .. 'its own source')

    -- The shipped anchor itself is live (the loop does admit buildings here),
    -- so "no outpost anchor" is a statement about outposts, not about the loop.
    cs.ratchet(SWEEP['anchor'], 62, 'pairs with a shipped building anchor within '
        .. BUILDING_R)

    -- ⛔ AN EQUALITY, not a ratchet: its whole content is a zero, and a
    -- counter-example is the WITNESS this change would like to have. Read a red
    -- here as "the corpus grew the frame that prices this knife", not as a
    -- regression: pin that row as a fixture and turn §3 into a positive
    -- assertion.
    assert(SWEEP['anchor_has_wt'] == 0,
        SWEEP['anchor_has_wt'] .. ' pair(s) now anchor on an OUTPOST. That is '
        .. 'the witness this landing did not have; re-price the effect size.')

    -- ...and the zero is attributable to GEOMETRY rather than to a dead
    -- distance call: the same instrument, on the same handles, reports a finite
    -- nearest outpost, and it is outside the loop's radius.
    assert(MIN_WT ~= nil,
        'no distance from a visible enemy to an allied outpost was ever '
        .. 'measured, so the zero above is free. The membership fact says an '
        .. 'outpost IS in the allied list (tests/_outpost_anchor_sweep.lua: '
        .. 'wt_allied 68 / wt_valid 68); if that has changed, this whole file '
        .. 'is about a corpus that no longer carries outposts.')
    assert(MIN_WT > BUILDING_R,
        string.format('the nearest outpost-to-enemy distance is %.1f, inside '
            .. 'the loop radius %d, yet anchor_has_wt read 0 -- the two '
            .. 'readings contradict each other', MIN_WT, BUILDING_R))
end

tests['[divepost] 3. effect size on this corpus: ZERO, and measured'] = function()
    census_or_die()
    -- The shipped helper fires here: the end-to-end driver is not dead.
    cs.ratchet(SWEEP['fire_a'], 32,
        'rows where the SHIPPED J.ShouldPunishDive returns a punish target '
        .. '(registered 28 on 2026-09-09, 32 on the grown corpus)')

    -- ⛔ EQUALITIES on purpose (see §2): the content is a zero.
    assert(SWEEP['flip_ab'] == 0,
        SWEEP['flip_ab'] .. ' row(s) where arming divepost changes the answer. '
        .. 'The effect size on this corpus was 0 when the change landed; it is '
        .. 'now non-zero, which is good news and must be re-priced.')
    assert(SWEEP['fire_b'] == SWEEP['fire_a'],
        'arming divepost changed the number of fires (' .. SWEEP['fire_b']
        .. ' vs ' .. SWEEP['fire_a'] .. ')')

    -- THE DIRECTION, measured as well as argued. An inequality, not an
    -- equality: the day the corpus grows a witness, armed must fire STRICTLY
    -- less often -- never more.
    assert(SWEEP['fire_b'] <= SWEEP['fire_a'],
        'armed fired MORE often than shipped. The conjunct is on an admission '
        .. 'test, so that is structurally impossible -- something else moved.')
end

tests['[divepost] 4. load-bearing AND gated: the two counterfactual arms'] = function()
    census_or_die()
    -- ⭐⭐ ARM C: with every building answering the outpost predicate and
    -- 'divepost' ARMED, the building branch must admit nothing, so every
    -- shipped fire is suppressed. This is the only reading that separates a
    -- load-bearing conjunct from dead code, and it is taken on the SAME code
    -- path with one term overridden -- no out-of-tree copy of the 40-line host.
    assert(SWEEP['fire_c'] == 0,
        SWEEP['fire_c'] .. ' row(s) still fire with every building forced to '
        .. 'read as an outpost and divepost armed. The conjunct is not '
        .. 'load-bearing on that path, or the domain is reaching the helper by '
        .. "another branch ('ownhalf' is UNARMED in every arm of this sweep).")
    assert(SWEEP['cf_suppressed'] == SWEEP['fire_a'],
        'expected all ' .. SWEEP['fire_a'] .. ' shipped fires to be suppressed '
        .. 'in arm C, got ' .. SWEEP['cf_suppressed'])

    -- ⭐⭐ ARM D: the same override with 'divepost' UNARMED must change NOTHING.
    -- This is the assertion that would have caught an un-gated landing -- a
    -- conjunct written without `bDivePost and` passes every other section in
    -- this file while silently changing shipped play under a PROMOTED helper.
    assert(SWEEP['flip_ad'] == 0,
        SWEEP['flip_ad'] .. ' row(s) changed answer with the outpost predicate '
        .. 'forced TRUE while divepost is UNARMED. The narrowing is reaching '
        .. 'shipped play: it is either un-gated or gated on something that is '
        .. 'not the candidate id.')
    assert(SWEEP['fire_d'] == SWEEP['fire_a'],
        'unarmed fire count moved under the override (' .. SWEEP['fire_d']
        .. ' vs ' .. SWEEP['fire_a'] .. ')')
end

tests['[divepost] 5. the helper keeps no ledger (the re-drive control)'] = function()
    census_or_die()
    -- Every arm above shares one rf.load per fixture. That is only sound if the
    -- helper consumes no module-level state between drives -- the trap that
    -- forces a fresh load in the defend-TP family (J.TryTakeTpResponseSlot, GH
    -- #767 §4). Arm A is re-taken after arms B/C/D on every row; it must answer
    -- identically, or the four arms are not comparable and this file's design
    -- is wrong rather than its subject.
    assert(SWEEP['fire_a2'] == SWEEP['live'],
        (SWEEP['live'] - SWEEP['fire_a2']) .. ' of ' .. SWEEP['live']
        .. ' rows answered DIFFERENTLY when the shipped arm was re-driven after '
        .. 'the other three. J.ShouldPunishDive now carries state across calls, '
        .. 'so every arm in this file must take a fresh rf.load.')
end

return tests

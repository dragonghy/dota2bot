-- [tpdeftower-outpost 20260913] THE DEFEND-TP TOWER LOOP NO LONGER TREATS A
-- CAPTURED OUTPOST AS A DEFENDABLE TOWER -- GH #782, landed.
--
-- ⭐ WHAT LANDED, IN ONE LINE: `and not J.IsOutpostBuilding( building )` in the
-- admission test of J.ShouldTpSupportTowerFight's building loop. One conjunct.
-- No new soak id (the host is already gated turbo + 'midtp'/'suptp'), no new
-- constant, no change to the shipped default (both ids are unpromoted).
--
-- ⛔ READ THIS FIRST, BECAUSE IT IS THE PART THAT COULD BE MISTAKEN FOR THE
-- DISCIPLINE BEING WAIVED. GH #782 was opened as REGISTERED-NOT-REPAIRED, on
-- the explicit ground that the corpus cannot witness the change end to end, and
-- §4 of that issue asks for a frame. This file lands the change anyway, and the
-- reason is not impatience:
--
--   A CLOSED-FORM DIRECTION NEEDS A PROOF, NOT A WITNESS; THE WITNESS COUNT
--   PRICES THE CHANGE, AND HERE IT PRICES IT AT ZERO.
--
-- The conjunct is added to the loop's ADMISSION test, so the candidate set is a
-- strict subset of the un-narrowed one. The loop returns the FIRST admitted
-- building, so any frame that answers narrowed also answers un-narrowed: the
-- response set can only shrink. The only reachable difference is swapping an
-- outpost for a real tower -- which is the repair. Nothing about that argument
-- is corpus-dependent, so no frame can make it truer. What a frame WOULD buy is
-- the effect size, and §3 measures it directly (0 flips on the 8 rows that
-- carry an outpost site) instead of leaving it unmeasured. That is strictly
-- more than the issue asked for on the half a frame could not have answered.
--
-- Precedent, same predicate, one caller over: J.ShouldRefuseUnsupportedPunish
-- ('ohnum'), 2026-09-12, tests/test_ohnum_outpost_anchor.lua.
--
-- ⭐⭐ AND THE FINDING THIS ROUND ACTUALLY TURNED UP, WHICH IS NOT THE KNIFE.
-- tests/test_tpdeftower_anchor_pricing.lua §7 was written the day before
-- expressly to notice this landing:
--
--     assert(host:find('watch_tower', 1, true) == nil,
--         'the host now names `watch_tower` in CODE, i.e. the outpost
--          narrowing has landed. Section 6 still counts 8 outpost sites
--          because it rebuilds the filter itself -- re-read it as history')
--
-- IT DOES NOT NOTICE. The narrowing that a careful author actually writes calls
-- the shared predicate, `J.IsOutpostBuilding( building )`, and the string
-- `watch_tower` never appears in the host at all. So the guard stays GREEN
-- across exactly the event it was written for, and §6 goes on pricing 8 outpost
-- sites the shipped code has already given up. The guard was present; it was
-- not load-bearing. Both sections are repaired this round (§6 re-read as
-- history + given a construction-zero it cannot free-certify, §7's literal
-- swapped for a source-parsed predicate name).
--
-- ⚠️ Generalisation worth the line, because this desk keeps paying for it: A
-- GUARD THAT NAMES A SPELLING GUARDS THE SPELLING, NOT THE EVENT. The sibling
-- lesson from 2026-09-12 (M8 on the overchase stand) is the same shape from the
-- other side -- there a dead census free-certified a pricing, here a live
-- census free-certifies a filter it rebuilds instead of reads. Both are cured
-- by making the test PARSE the shipped expression rather than restate it, which
-- is what tests/_outpost_anchor_sweep.lua already does for the unit name and
-- what §1 below does for the conjunct.
--
-- ⚠️ INHERITED TRAPS (GH #767 §4, unchanged and they still bite):
-- (1) the host's conjunction ENDS in J.TryTakeTpResponseSlot, a module-level
--     ledger it consumes on success => every end-to-end drive takes a FRESH
--     rf.load. There is no reset.
-- (2) tests/mock/replay_fixture.lua binds the enemy and building lists to the
--     LOADED subject's team, so the sweep only ever drives heroes on the
--     subject's own team.
--
-- Registered: iterations/state.json:tpdeftower_outpost_20260913, GH #782.
-- armed string / queue.json / test_set.md untouched. Zero AWS.

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')
local cs = require('corpus_scale')

local TRG = 'bots/FunLib/jmz_func.lua'

-- The host's own constants, re-pinned against the source in §1 rather than
-- trusted: a census whose ring or floor drifts keeps every count satisfied
-- while measuring a cell the shipped code never reads.
local TOWER_RING = 1200   -- J.GetEnemiesNearLoc( vTower, 1200 )
local FAR_FLOOR  = 3500   -- J.TP_RESPONSE_FAR_FLOOR

local tests = {}

-- --------------------------------------------------------------- helpers ---

local function read_file(path)
    local f = assert(io.open(path, 'r'), 'could not open ' .. path)
    local s = f:read('*a')
    f:close()
    return s
end

--- Source with every comment removed: this file's own prose QUOTES the shipped
--- conjunct, so an unstripped read would let a comment satisfy §1.
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

local HOST = block('function J.ShouldTpSupportTowerFight( bot )')

--- ⭐ THE OUTPOST UNIT NAME, PARSED OUT OF THE SHIPPED PREDICATE rather than
--- restated here. This is the cure for the §7 defect described in the header:
--- a census that spells the discriminator itself can disagree with the code
--- while both are green.
local OUTPOST_NAME = (function()
    local body = block('function J.IsOutpostBuilding( nTarget )')
    local lit = body:match("string%.find%(%s*nTarget:GetUnitName%(%)%s*,%s*'([%w_]+)'%s*%)")
    assert(lit ~= nil,
        'J.IsOutpostBuilding no longer tests a single quoted literal against '
        .. 'the unit name. Every count in this file is taken over units matched '
        .. 'by THAT literal; if the predicate changed shape, re-parse it here '
        .. 'rather than hard-coding a name that can drift away from the code.')
    return lit
end)()

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

local PATHS = corpus_paths()

--- The building-loop ADMISSION test, un-narrowed -- i.e. the shipped bytes of
--- 2026-09-12. §1 pins that this is still term-for-term what the host asks
--- minus the one conjunct under study.
local function admitted_loose(J, h, b)
    return J.IsValidBuilding(b)
        and string.find(b:GetUnitName(), 'tower') ~= nil
        and GetUnitToUnitDistance(h, b) > FAR_FLOOR
end

-- ------------------------------------------------- the predicate sweep ---

local OUTPOST_ROWS = {}

local SWEEP, SWEEP_ERR = (function()
    local ok, res = pcall(function()
        local c = setmetatable({}, { __index = function() return 0 end })
        local function bump(k) c[k] = c[k] + 1 end

        for _, path in ipairs(PATHS) do
            local lok, J, subject, heroes = pcall(rf.load, path)
            if not lok or J == nil then
                bump('load_fail')
            else
                bump('frames')
                local subj_team = subject:GetTeam()   -- trap (2)
                for _, h in pairs(heroes or {}) do
                    if h ~= nil and h.IsAlive and h:IsAlive()
                        and h:GetTeam() == subj_team
                    then
                        bump('live')
                        local row_outpost = false
                        for _, b in pairs(GetUnitList(UNIT_LIST_ALLIED_BUILDINGS) or {}) do
                            -- ⭐ THE GAUGE-IS-ALIVE CONTROL, taken on REAL corpus
                            -- handles and not on a synthetic one: the shipped
                            -- predicate must answer TRUE on something and FALSE
                            -- on something. A predicate that answered false for
                            -- everything would make the knife a no-op and would
                            -- free-certify every zero below.
                            if J.IsValidBuilding(b) then
                                if J.IsOutpostBuilding(b) then
                                    bump('pred_true')
                                else
                                    bump('pred_false')
                                end
                                -- and it must agree with the name it parses out
                                -- of its own source, on these same handles
                                local byname =
                                    string.find(b:GetUnitName(), OUTPOST_NAME) ~= nil
                                if byname ~= (J.IsOutpostBuilding(b) and true or false) then
                                    bump('PRED_DISAGREES')
                                end
                            end

                            if admitted_loose(J, h, b) then
                                local vT = b:GetLocation()
                                local tE = J.GetEnemiesNearLoc(vT, TOWER_RING)
                                if tE[1] ~= nil then
                                    bump('site')
                                    if J.IsOutpostBuilding(b) then
                                        bump('site_outpost')
                                        row_outpost = true
                                    else
                                        bump('site_tower')
                                    end
                                    -- the same site under the NARROWED admission
                                    if admitted_loose(J, h, b)
                                        and not J.IsOutpostBuilding(b)
                                    then
                                        bump('site_narrow')
                                    end
                                end
                            end
                        end
                        if row_outpost then
                            OUTPOST_ROWS[#OUTPOST_ROWS + 1] = { path, h:GetUnitName() }
                        end
                    end
                end
            end
        end
        return c
    end)
    if ok then return res, nil end
    return nil, tostring(res)
end)()

--- ⛔ EVERY COUNTING SECTION CALLS THIS FIRST. If the sweep died, `SWEEP[k]` is
--- an index into nil -- but the shape of several claims here is `x == 0`, and a
--- dead census makes `nil == nil` read TRUE. That is the 2026-09-12 lesson
--- (GH #171 shape): a dead gauge free-certifies the one reading the file
--- exists to take. Fail loudly instead.
local function census_or_die()
    assert(SWEEP ~= nil,
        'the corpus sweep DIED and every count in this file is nil. A zero read '
        .. 'off a dead census is not a zero. Underlying error: '
        .. tostring(SWEEP_ERR))
end

--- One drive of the real shipped host on a real frame. ALWAYS a fresh load
--- (trap (1)). `loose` un-narrows the host exactly, by making the conjunct's
--- predicate answer false -- no out-of-tree copy and no reimplementation of the
--- host's 40-line body, which is the only counterfactual that is provably the
--- same code path with one term removed.
local function host_answer(path, subj, ids, loose)
    local J, bot = rf.load(path, subj)
    local armed = {}
    for _, id in ipairs(ids) do armed[id] = true end
    J.IsSoakCandidate = function(id) return armed[id] == true end
    if loose then J.IsOutpostBuilding = function() return false end end
    return J.ShouldTpSupportTowerFight(bot), J, bot
end

-- ============================================================== sections ===

tests['[tpdeftower-outpost] 1. the conjunct is in the shipped bytes, and gated'] = function()
    -- Read off the STRIPPED host, so this file's prose (which quotes the
    -- conjunct twice) cannot satisfy it.
    local iValid  = HOST:find('J.IsValidBuilding( building )', 1, true)
    local iName   = HOST:find("string.find( building:GetUnitName(), 'tower' ) ~= nil", 1, true)
    local iCut    = HOST:find('and not J.IsOutpostBuilding( building )', 1, true)
    local iDist   = HOST:find('GetUnitToUnitDistance( bot, building ) > J.TP_RESPONSE_FAR_FLOOR', 1, true)
    assert(iCut ~= nil,
        'the outpost narrowing is GONE from J.ShouldTpSupportTowerFight. GH #782 '
        .. 'is the case; every count in this file is about a tree that has it.')
    assert(iValid ~= nil and iName ~= nil and iDist ~= nil,
        'the building-loop admission test no longer has the three terms this '
        .. 'file measured around (valid / name / distance)')
    assert(iValid < iName and iName < iCut and iCut < iDist,
        'the admission terms are out of order (want valid < name < outpost < '
        .. 'distance). Not cosmetic: `admitted_loose` in this file is the same '
        .. 'conjunction MINUS the cut, and §3 subtracts one from the other.')

    -- The host is still gated, and the gate still precedes the loop -- this is
    -- what makes "shipped play is unchanged" true rather than hopeful.
    local iTurbo = HOST:find('if not J.IsModeTurbo() then return nil end', 1, true)
    local iGate  = HOST:find("if not ( J.IsSoakCandidate( 'midtp' ) or bSup ) then return nil end", 1, true)
    assert(iTurbo ~= nil and iGate ~= nil and iTurbo < iGate and iGate < iCut,
        'the turbo / candidate early returns no longer precede the narrowing, '
        .. 'so it would reach shipped play. Both ids are unpromoted; if one has '
        .. 'been promoted, this change needs a promote review of its own.')

    -- ⛔ NO NEW SOAK ID INSIDE THE HOST. The 'pullcad' trap (GH #606/#576): a
    -- nested id under an unpromoted host is the conjunction `midtp AND <new>`,
    -- whose single-arm isolation zero is structurally impossible rather than
    -- informative, and check_armed_wiring.py would still call it WIRED.
    local seen = {}
    for id in HOST:gmatch("J%.IsSoakCandidate%(%s*'([%w_]+)'%s*%)") do seen[id] = true end
    for id in pairs(seen) do
        assert(id == 'midtp' or id == 'suptp' or id == 'tparrive'
            or id == 'midsupyield',
            "a new soak id '" .. id .. "' has appeared inside "
            .. 'J.ShouldTpSupportTowerFight. Under an unpromoted host that is '
            .. 'the pullcad trap, not isolation.')
    end

    -- And the predicate it calls is still the ungated pure one, so this caller
    -- is not silently inheriting somebody else's gate.
    local pred = block('function J.IsOutpostBuilding( nTarget )')
    assert(pred:find('IsSoakCandidate', 1, true) == nil
        and pred:find('IsModeTurbo', 1, true) == nil,
        'J.IsOutpostBuilding has acquired a gate. It is a pure predicate and '
        .. 'both of its callers carry their own; a gate here would silently '
        .. 'conjoin two candidates.')

    -- The two constants the sweep uses are the host's, not this file's.
    assert(HOST:find('J.GetEnemiesNearLoc( vTower, ' .. TOWER_RING .. ' )', 1, true) ~= nil,
        'the host no longer builds tEnemies at radius ' .. TOWER_RING)
    assert(SRC:find('J.TP_RESPONSE_FAR_FLOOR = ' .. FAR_FLOOR, 1, true) ~= nil,
        'J.TP_RESPONSE_FAR_FLOOR is no longer ' .. FAR_FLOOR)
end

tests['[tpdeftower-outpost] 2. the knife is LIVE on this corpus (positive control)'] = function()
    census_or_die()
    -- ⭐⭐ THE READING THAT MUST BE NON-ZERO. §3's headline is a zero, and a
    -- zero is free if the predicate never matches anything, if the corpus has
    -- no outposts, or if no outpost ever reaches the loop. Each of those is
    -- excluded here, on real handles, before any zero is allowed to mean
    -- something. (GH #782's own reading, re-taken on the narrowed tree.)
    assert(SWEEP['pred_true'] > 0,
        'J.IsOutpostBuilding matched NOTHING across the whole corpus (' ..
        SWEEP['pred_false'] .. ' valid buildings, 0 outposts). The narrowing is '
        .. 'then a no-op for a reason that has nothing to do with the fights, '
        .. 'and §3 measures nothing.')
    assert(SWEEP['pred_false'] > 0,
        'J.IsOutpostBuilding matched EVERY valid building. It is supposed to '
        .. 'separate outposts from towers; a predicate that is constantly true '
        .. 'would remove the whole tower loop.')
    assert(SWEEP['PRED_DISAGREES'] == 0,
        SWEEP['PRED_DISAGREES'] .. ' building(s) where J.IsOutpostBuilding '
        .. "disagrees with the literal '" .. OUTPOST_NAME .. "' parsed out of "
        .. 'its own source. The predicate has grown a second term; re-read '
        .. 'every count in this file, which is taken over the parsed name.')

    -- The sites the cut actually removes from the loop, i.e. its domain.
    cs.ratchet(SWEEP['site_outpost'], 8,
        'defend-TP sites whose "tower" is an OUTPOST -- the domain this '
        .. 'conjunct removes (GH #782 measured 8 of 113 on the same corpus)')
    cs.ratchet(SWEEP['site_tower'], 105, 'defend-TP sites at a real tower')
    cs.ratchet(#OUTPOST_ROWS, 8, 'hero-rows carrying at least one outpost site')

    -- ⛔ AND THE CUT REMOVES EXACTLY THAT AND NOTHING ELSE. This is the term
    -- that makes "strict subset" a measurement instead of a reading of the
    -- diff: narrowed admissions + outpost admissions == loose admissions.
    assert(SWEEP['site_narrow'] + SWEEP['site_outpost'] == SWEEP['site'],
        'site_narrow (' .. SWEEP['site_narrow'] .. ') + site_outpost ('
        .. SWEEP['site_outpost'] .. ') /= site (' .. SWEEP['site'] .. '). The '
        .. 'conjunct is removing something other than outposts, or admitting '
        .. 'something the un-narrowed test did not.')
    assert(SWEEP['site_narrow'] < SWEEP['site'],
        'the narrowed admission test admits exactly as many sites as the '
        .. 'un-narrowed one, so the knife touches nothing on this corpus and '
        .. 'the zero in §3 is vacuous')
end

tests['[tpdeftower-outpost] 3. effect size on this corpus: ZERO, and measured'] = function()
    census_or_die()
    -- ⭐ THE DOWNSTREAM COUNT -- the one that actually flips an answer, which is
    -- the criterion this desk adopted on 2026-09-12 after a leg-level geometric
    -- count sent a round back into pricing. Not "how many sites are outposts"
    -- (that is §2, the domain) but "on how many rows does the host's ANSWER
    -- change". Drive the real host twice per row on fresh loads: as shipped,
    -- and un-narrowed.
    local n_rows, ans_narrow, ans_loose, ans_loose_outpost, flip = 0, 0, 0, 0, 0
    for _, row in ipairs(OUTPOST_ROWS) do
        n_rows = n_rows + 1
        local bN = host_answer(row[1], row[2], { 'midtp' }, false)
        local bL = host_answer(row[1], row[2], { 'midtp' }, true)
        if bN ~= nil then ans_narrow = ans_narrow + 1 end
        if bL ~= nil then
            ans_loose = ans_loose + 1
            if string.find(bL:GetUnitName(), OUTPOST_NAME) ~= nil then
                ans_loose_outpost = ans_loose_outpost + 1
            end
        end
        local nN = bN ~= nil and bN:GetUnitName() or '<nil>'
        local nL = bL ~= nil and bL:GetUnitName() or '<nil>'
        if nN ~= nL then flip = flip + 1 end
    end
    cs.ratchet(n_rows, 8, 'rows driven end to end (both arms)')

    -- ⛔ EQUALITIES, not ratchets: their whole content is a zero, and a
    -- counter-example is the FINDING GH #782 asked for -- the corpus grew the
    -- frame that witnesses this change. Read a red here as "the witness has
    -- arrived; go pin it as a fixture", not as a regression.
    assert(ans_loose_outpost == 0,
        ans_loose_outpost .. ' row(s) answer an OUTPOST with the narrowing '
        .. 'removed. That is exactly the witness GH #782 requested: the change '
        .. 'now has a frame that validates it end to end. Pin that row as a '
        .. 'fixture and turn this into a positive assertion.')
    assert(flip == 0,
        flip .. ' row(s) where the shipped answer differs from the un-narrowed '
        .. 'answer. The effect size on this corpus was 0 when the change landed; '
        .. 'it is now non-zero, which is good news and must be re-priced.')

    -- ⛔ THE DIRECTION, MEASURED AS WELL AS ARGUED. The header proves the
    -- response set can only shrink; this is that proof's observable shadow. It
    -- is deliberately an INEQUALITY, not an equality: the day the corpus grows
    -- the witness, `flip` goes non-zero above and this must still hold.
    assert(ans_narrow <= ans_loose,
        'the narrowed host answers on MORE rows (' .. ans_narrow .. ') than the '
        .. 'un-narrowed one (' .. ans_loose .. '). That is impossible for a '
        .. 'conjunct added to an admission test whose loop returns the first '
        .. 'match -- so either the loop no longer returns on first match, or '
        .. 'the two arms are not the same code path.')

    -- ⭐ POSITIVE CONTROL FOR THE DRIVER ITSELF, borrowed term for term from
    -- tests/test_tpdeftower_anchor_pricing.lua §4. Both zeros above are
    -- satisfied by a driver that quietly stopped arming anything: the host's
    -- gate line returns nil with no candidate armed, and then "no row answers"
    -- is true for a reason that has nothing to do with outposts. The `parity`
    -- frame is the corpus's witness that this driver can make the host FIRE.
    local PAR = 'tests/fixtures/f_260819_183613_storm_collapse_parity.lua'
    local STORM = 'npc_dota_hero_storm_spirit'
    assert(host_answer(PAR, STORM, { 'midtp' }, false) ~= nil,
        'the driver no longer makes the host answer on the one frame the corpus '
        .. 'says it must, so the two zeros above prove nothing')
    -- ...and the `loose` arm is not a no-op arm that silently skips the drive.
    assert(host_answer(PAR, STORM, { 'midtp' }, true) ~= nil,
        'the un-narrowed arm does not answer on the parity frame either, so the '
        .. 'counterfactual driver is dead and `ans_loose` is a zero about '
        .. 'nothing')

    -- ⭐⭐ AND THE CONTROL THE OTHER CONTROLS CANNOT GIVE. Every reading above
    -- is ALSO satisfied by a `loose` arm that never applies its override at
    -- all: on this corpus the two arms answer identically (that IS the finding),
    -- so no end-to-end count can tell a live counterfactual from a dead one.
    -- Only a direct read can. Both halves are taken on a REAL outpost handle
    -- from a real frame, off the J that `host_answer` itself returns -- so a
    -- mutant that drops the override inside `host_answer` is red here.
    local function an_outpost(J)
        for _, b in pairs(GetUnitList(UNIT_LIST_ALLIED_BUILDINGS) or {}) do
            if J.IsValidBuilding(b)
                and string.find(b:GetUnitName(), OUTPOST_NAME) ~= nil
            then return b end
        end
        return nil
    end
    local row = OUTPOST_ROWS[1]
    assert(row ~= nil, 'no row carries an outpost site, so there is nothing to '
        .. 'take the override control on')
    -- narrow arm: the predicate the host calls must be LIVE
    local _, Jn = host_answer(row[1], row[2], { 'midtp' }, false)
    local hn = an_outpost(Jn)
    assert(hn ~= nil, 'the outpost handle vanished from a row the sweep '
        .. 'recorded as carrying one')
    assert(Jn.IsOutpostBuilding(hn) == true,
        'in the SHIPPED arm J.IsOutpostBuilding answers false on a real '
        .. 'outpost handle, so the conjunct removes nothing and the whole '
        .. 'narrowing is inert for a reason unrelated to the fights')
    -- loose arm: and it must be NEUTERED, by host_answer's own override
    local _, Jl = host_answer(row[1], row[2], { 'midtp' }, true)
    local hl = an_outpost(Jl)
    assert(hl ~= nil, 'the outpost handle vanished on the loose arm')
    assert(Jl.IsOutpostBuilding(hl) == false,
        'the `loose` arm did NOT neuter J.IsOutpostBuilding on a real outpost '
        .. 'handle. The counterfactual is then the same code path as the '
        .. 'shipped one, and every zero in this section is a comparison of the '
        .. 'tree against itself.')
end

tests['[tpdeftower-outpost] 4. shipped play is untouched'] = function()
    -- Both ids that reach this code are unpromoted. `state.json` is the
    -- authority on that list and moves weekly, so read the property that
    -- matters off the SOURCE instead: the promote note a promoted helper
    -- carries must NOT be here, and the gate line must still be.
    assert(HOST:find("J.IsSoakCandidate( 'midtp' )", 1, true) ~= nil,
        "the 'midtp' gate is gone from J.ShouldTpSupportTowerFight -- if it was "
        .. 'promoted, this narrowing is now LIVE in every turbo game and needs '
        .. 'the promote review it never had')
    local raw = read_file(TRG)
    local hi = raw:find('function J.ShouldTpSupportTowerFight( bot )', 1, true)
    assert(hi ~= nil, 'the host is gone from ' .. TRG)
    local head = raw:sub(math.max(1, hi - 2000), hi)
    assert(head:find('PROMOTED (was soak-candidate', 1, true) == nil,
        'J.ShouldTpSupportTowerFight now carries a PROMOTED note, so the '
        .. '"inert in shipped play" claim in this file and in the source '
        .. 'comment is false')
end

return tests

-- [tpdeftower 20260912] THE TOWER-ANCHORED READING OF THE DEFEND-TP
-- WINNABILITY SITE -- GH #767 §6.1 (a), priced, plus (b) bought BEFORE the
-- change instead of after it. Second pricing round at the same site, and the
-- second one to land no behaviour change. The finding is why.
--
-- ⛔ READ THIS FIRST: THERE IS NO BEHAVIOUR CHANGE BEHIND THIS FILE EITHER.
-- What landed is (i) two comment repairs in bots/FunLib/jmz_func.lua and (ii)
-- this census. Every "tower-anchored" count below is a COUNTERFACTUAL about a
-- reading of the site, written out in this file; the shipped bytes still read
-- `J.SafeToCommitFight( bot, tEnemies[1] )` and section 7 pins that.
--
-- THE SITE. J.ShouldTpSupportTowerFight asks "is this collapse winnable" as
--     J.SafeToCommitFight( bot, tEnemies[1] )
-- and J.SafeToCommitFight anchors BOTH of its branches at the TARGET's
-- location, never reading `bot`. GH #767 measured that asking a different
-- member is asking about a different neighbourhood, and handed the desk two
-- options. (a) is the one with a real question behind it: anchor the read at
-- the TOWER -- the point the responder is actually TP-ing to -- so the
-- neighbourhood is the fight, not one arbitrary member's surroundings. The
-- displacement is not hypothetical: on 98 of 113 sites `tEnemies[1]` stands
-- more than 600 units from the tower it is being scored for.
--
-- ⭐⭐ THE FINDING, AND IT RETIRES A SAFETY ARGUMENT THE SOURCE ITSELF USES.
-- A CROSS-LEVER COLLISION IS NOT A PROPERTY OF THE DIRECTION OF THE CHANGE.
-- Yesterday's attempt at this site was strictly STRICTER (a universal) and it
-- withdrew the response on tparrive's POSITIVE control frame. This one is
-- strictly LOOSER on the responder-shaped sites (+15, -0) and it breaks the
-- same candidate from the other side: with only `midtp` armed it fires on
-- tparrive's `outnumbered` frame (whose whole job is that SHIPPED refuses
-- there, so the candidate has something to add) and on its `lost` frame (whose
-- whole job is that even ARMED refuses, so the candidate is not "always go").
-- Measured end to end, not argued: the host answers nil / nil today and
-- tower@4860,-6379 / tower@4860,-6379 under the counterfactual, out of tree.
-- ⇒ "a strict superset, so armed can only ADD a response" -- the sentence
-- J.SafeToCommitFightOnArrival uses about itself -- is sound about the HOST'S
-- OWN behaviour and worthless as a cross-lever bound: a sibling candidate's
-- evidence rests on the shipped arm answering a particular way, and a
-- NEGATIVE control is as breakable as a positive one. Both of yesterday's
-- lessons and this one point at the same rule: at a site that several
-- unpromoted candidates read, price the siblings' own frames first.
--
-- ⭐ AND THE READING IS NOT MERELY DIFFERENTLY SCOPED -- IT IS WRONG ON A FRAME
-- THE CORPUS HAS ALREADY ADJUDICATED. `lost` is t=310.4, one second after
-- `outnumbered`: no ally is left within 1200 of the engage point (0 v 2), which
-- is why the sibling test carries it as "this is what keeps the candidate from
-- degenerating into always go". At the TOWER the same instant counts 1 v 1,
-- because the heat gate guarantees an ally near the tower -- the hurt one being
-- dived. So tower-anchoring reads the dying defender as half of a parity fight.
-- That is a defect of the anchor, not of this corpus.
--
-- ⭐ A SECOND, SEPARATE FINDING THIS PRICING FELL OVER, AND IT IS THE ONE WITH
-- A REPAIR IN IT: `string.find( building:GetUnitName(), 'tower' )` ADMITS
-- `npc_dota_watch_tower`. A captured OUTPOST is an allied building whose name
-- contains "tower", so the defend-TP treats an outpost fight as a tower fight.
-- 8 of the 113 sites are outposts and 5 of those are DEEP in the enemy half at
-- the caller's own engage point (up to 5,827 units closer to their ancient than
-- to ours), while 0 of the 105 real-tower sites are deep. That pair of numbers
-- falsifies the INFERENCE in the shipped prose on J.SafeToCommitFightOnArrival
-- ("a collapse onto our own tower is never deep, so that branch is inert in the
-- caller's domain") while leaving its PREMISE true -- the caller's domain is
-- simply bigger than the word "tower". Both comments are repaired this round.
-- ⛔ The narrowing itself is NOT landed: over the 100 rows that reach the tower
-- loop with a live site the host answers 5, and all 5 are real towers, so the
-- corpus cannot witness the change end to end (section 6). GH #782 carries the
-- frame request; section 6 is what makes the absence a measured zero rather
-- than an assumption.
--
-- ⚠️ SCOPE OF EVERY NUMBER HERE: THE LETHAL BRANCH IS UNOBSERVABLE ON THIS
-- CORPUS (section 5). All 31 shipped commits come from the NUMBERS branch, the
-- burst estimate is positive on 2 of 113 sites, and both lethal branches -- the
-- shipped one and the counterfactual's -- fire 0 times. So this file prices the
-- numbers branch of both readings and says nothing about their lethal halves;
-- same construction limit as GH #760 (no velocity) and GH #474 (no tower attack
-- target), one predicate over.
--
-- ⚠️ THE TRAPS ARE INHERITED, NOT REDISCOVERED (GH #767 §4, and they still
-- bite): (1) the host's conjunction ENDS in J.TryTakeTpResponseSlot, a
-- module-level ledger it consumes on success, so every end-to-end drive here
-- takes a FRESH rf.load; (2) tests/mock/replay_fixture.lua binds the enemy and
-- building lists to the LOADED subject's team at load time, so the sweep only
-- ever drives heroes on the subject's own team.
--
-- ⭐ AND ONE NEW ONE, WORTH THE LINE: the counterfactual host was driven in an
-- OUT-OF-TREE COPY of bots/ + tests/ (cp to a scratch dir, patch there, run
-- there), not by patching the worktree and reverting. Yesterday's round patched
-- in tree while the start-of-shift self-check was reading the same files and
-- got two pollution reds that looked exactly like real regressions. A copy
-- costs 23 MB and removes the whole class.
--
-- Registered: state.json:tpdeftower_20260912, GH #767 (comment), GH #782.
-- armed string / queue.json / test_set.md untouched. Zero AWS.

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')
local cs = require('corpus_scale')

local TRG = 'bots/FunLib/jmz_func.lua'

-- The host's own constants, not new ones.
local TOWER_RING = 1200   -- J.GetEnemiesNearLoc( vTower, 1200 )
local FAR_FLOOR  = 3500   -- J.TP_RESPONSE_FAR_FLOOR
local DEEP_MARGIN = 1600  -- the 'depthnum' convention in J.SafeToCommitFight

local tests = {}

-- --------------------------------------------------------------- helpers ---

local function read_file(path)
    local f = assert(io.open(path, 'r'), 'could not open ' .. path)
    local s = f:read('*a')
    f:close()
    return s
end

--- Source with every comment removed: this file's own repairs QUOTE the shipped
--- expressions, so an unstripped read would let a comment satisfy section 7.
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

--- The SHIPPED expression, spelled out so the comparison is against the text of
--- what ships rather than against another call of the same helper.
local function shipped_answer(J, bot, t)
    if t == nil or t[1] == nil then return false end
    return J.SafeToCommitFight(bot, t[1]) and true or false
end

--- ⭐ THE COUNTERFACTUAL. Same two branches as J.SafeToCommitFight, both
--- anchored at the TOWER instead of at one member, and deliberately NOT
--- counting the arriving responder -- that is 'tparrive''s lever and mixing it
--- in here would be the bundle this desk keeps paying for. The lethal branch is
--- existential over the tower's enemies, so no member is privileged.
local function tower_answer(J, vTower, tEnemies)
    local tAllies = J.GetAlliesNearLoc(vTower, TOWER_RING)
    for i = 1, #tEnemies do
        local e = tEnemies[i]
        if J.IsValidHero(e) then
            local nBurst = J.GetTotalEstimatedDamageToTarget(tAllies, e)
            if nBurst >= e:GetHealth() + e:GetHealthRegen() * 5.0 then
                return true, true
            end
        end
    end
    return #tAllies >= #tEnemies, false
end

--- `bAllyThere`, lifted term for term from the host, so "responder-shaped"
--- means the sites the host would actually score.
local function ally_there(J, bot, vTower)
    for _, ally in pairs(J.GetAlliesNearLoc(vTower, TOWER_RING)) do
        if ally ~= bot and J.IsValidHero(ally)
            and J.WillAllySurviveTpWindow(ally)
            and (ally:WasRecentlyDamagedByAnyHero(3.0) or J.GetHP(ally) < 0.75)
        then
            return true
        end
    end
    return false
end

local function is_outpost(b) return b:GetUnitName() == 'watch_tower' end

-- ------------------------------------------------- the predicate sweep ---

local OUTPOST_ROWS = {}

local SWEEP = (function()
    local c = setmetatable({}, { __index = function() return 0 end })
    local function bump(k) c[k] = c[k] + 1 end

    for _, path in ipairs(PATHS) do
        local ok, J, subject, heroes = pcall(rf.load, path)
        if not ok or J == nil then
            bump('load_fail')
        else
            bump('frames_loaded')
            -- ⚠️ SUBJECT'S TEAM ONLY -- trap (2) in the header.
            local subj_team = subject:GetTeam()
            for _, h in pairs(heroes or {}) do
                if h ~= nil and h.IsAlive and h:IsAlive()
                    and h:GetTeam() == subj_team
                then
                    bump('live')
                    local row_outpost = false
                    for _, b in pairs(GetUnitList(UNIT_LIST_ALLIED_BUILDINGS) or {}) do
                        if J.IsValidBuilding(b)
                            and string.find(b:GetUnitName(), 'tower') ~= nil
                            and GetUnitToUnitDistance(h, b) > FAR_FLOOR
                        then
                            local vT = b:GetLocation()
                            local tE = J.GetEnemiesNearLoc(vT, TOWER_RING)
                            if tE[1] ~= nil then
                                bump('site')
                                if is_outpost(b) then
                                    bump('site_outpost')
                                    row_outpost = true
                                else
                                    bump('site_tower')
                                end

                                -- Producer sanity, and it is trap (2)'s own
                                -- detector rather than a decoration: with the
                                -- subject-team filter gone the loader hands
                                -- this producer the driven hero's own
                                -- TEAMMATES as enemies, and nothing else in
                                -- this file would notice.
                                for i = 1, #tE do
                                    if tE[i]:GetTeam() == h:GetTeam() then
                                        bump('SAME_TEAM')
                                    end
                                    if tE[i] == h then bump('SELF_IN_LIST') end
                                end

                                local s = shipped_answer(J, h, tE)
                                local w, wl = tower_answer(J, vT, tE)
                                if s then bump('shipped_true') end
                                if w then bump('tower_true') end
                                if w and not s then bump('ADD') end
                                if s and not w then bump('WITHDRAW') end
                                if wl then bump('tower_lethal') end

                                -- 5. is the LETHAL branch observable at all?
                                -- Taken on the shipped anchor, which is the one
                                -- that ships: burst of the allies within 1200 of
                                -- `tEnemies[1]` against `tEnemies[1]`.
                                local vE = tE[1]:GetLocation()
                                local aE = J.GetAlliesNearLoc(vE, TOWER_RING)
                                local burst = J.GetTotalEstimatedDamageToTarget(aE, tE[1])
                                if burst > 0 then bump('burst_positive') end
                                if burst >= tE[1]:GetHealth()
                                    + tE[1]:GetHealthRegen() * 5.0
                                then bump('shipped_lethal') end

                                -- how far the scored neighbourhood is displaced
                                if GetUnitToLocationDistance(tE[1], vT) > 600 then
                                    bump('e1_far_600')
                                end

                                -- 6. depth AT THE CALLER'S OWN ENGAGE POINT,
                                -- which is the quantity the repaired comment is
                                -- about -- not depth at the tower.
                                local ea = GetAncient(GetOpposingTeam())
                                local oa = GetAncient(GetTeam())
                                if ea ~= nil and oa ~= nil
                                    and J.GetLocationToLocationDistance(vE, ea:GetLocation())
                                        < J.GetLocationToLocationDistance(vE, oa:GetLocation())
                                          - DEEP_MARGIN
                                then
                                    bump('deep_vloc')
                                    if is_outpost(b) then
                                        bump('deep_vloc_outpost')
                                    else
                                        bump('deep_vloc_tower')
                                    end
                                end

                                if ally_there(J, h, vT) then
                                    bump('rsite')
                                    if s then bump('r_shipped') end
                                    if w then bump('r_tower') end
                                    if w and not s then bump('r_ADD') end
                                    if s and not w then bump('r_WITHDRAW') end
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
end)()

-- ============================================================== sections ===

tests['[tpdeftower] 1. the corpus this file speaks about'] = function()
    assert(SWEEP['load_fail'] == 0,
        SWEEP['load_fail'] .. ' fixture(s) failed to load -- every count below '
        .. 'is taken over a corpus this file cannot describe.')
    cs.corpus(SWEEP['frames_loaded'], 'frames loaded')
    cs.ratchet(SWEEP['live'], 653, 'live hero rows on the subject\'s team')
    cs.ratchet(SWEEP['site'], 113,
        'sites (row, live allied "tower" beyond ' .. FAR_FLOOR
        .. ', >= 1 enemy hero within ' .. TOWER_RING .. ')')
    cs.ratchet(SWEEP['rsite'], 42, 'responder-shaped sites')
    assert(SWEEP['SAME_TEAM'] == 0,
        SWEEP['SAME_TEAM'] .. ' site(s) list an ALLY of the driven hero as an '
        .. 'enemy at the tower -- trap (2) in the header: the loader binds the '
        .. 'enemy list to the LOADED subject\'s team, so this is what driving '
        .. 'an opposite-team hero looks like. Every count below would be taken '
        .. 'over the wrong world.')
    assert(SWEEP['SELF_IN_LIST'] == 0,
        SWEEP['SELF_IN_LIST'] .. ' site(s) list the driven hero itself as an '
        .. 'enemy')
    assert(SWEEP['site'] == SWEEP['site_tower'] + SWEEP['site_outpost'],
        'site (' .. SWEEP['site'] .. ') /= site_tower (' .. SWEEP['site_tower']
        .. ') + site_outpost (' .. SWEEP['site_outpost'] .. '). The split in '
        .. 'section 6 is a partition of THIS number or it is about other rows.')
end

tests['[tpdeftower] 2. both readings are non-degenerate here'] = function()
    assert(SWEEP['shipped_true'] > 0,
        'the shipped expression commits on 0 sites, so section 3 compares an '
        .. 'empty set against the counterfactual and every bound is vacuous.')
    assert(SWEEP['tower_true'] > 0,
        'the tower-anchored reading commits on 0 sites -- it would be a '
        .. 'constant false and this file would be pricing nothing.')
    cs.ratchet(SWEEP['shipped_true'], 31, 'sites where shipped says commit')
    cs.ratchet(SWEEP['tower_true'], 51, 'sites where the tower anchor says commit')
    cs.ratchet(SWEEP['e1_far_600'], 98,
        'sites where the scored member stands > 600 from the tower it is '
        .. 'scored for (the displacement that makes the anchor a real question)')
end

tests['[tpdeftower] 3. direction: this lever moves BOTH ways'] = function()
    -- ⭐ The point of the section. Yesterday's reading at this site could only
    -- withdraw; this one mostly adds and still withdraws twice. Neither the
    -- "can only add" nor the "can only withdraw" bound is available here, and
    -- section 4 shows why neither would have helped anyway.
    cs.ratchet(SWEEP['ADD'], 22, 'sites the tower anchor ADDS')
    cs.ratchet(SWEEP['WITHDRAW'], 2, 'sites the tower anchor WITHDRAWS')
    assert(SWEEP['WITHDRAW'] > 0,
        'the tower anchor no longer withdraws anywhere, i.e. it has become a '
        .. 'one-sided (superset) lever on this corpus. That is a DIFFERENT '
        .. 'lever from the one priced here -- re-read section 4 before reusing '
        .. 'these numbers, because the collision it records does not depend on '
        .. 'the direction.')
    assert(SWEEP['shipped_true'] + SWEEP['ADD'] - SWEEP['WITHDRAW']
        == SWEEP['tower_true'],
        'shipped_true (' .. SWEEP['shipped_true'] .. ') + ADD (' .. SWEEP['ADD']
        .. ') - WITHDRAW (' .. SWEEP['WITHDRAW'] .. ') /= tower_true ('
        .. SWEEP['tower_true'] .. '). The three counters are not about the same '
        .. 'rows, so an oracle that degenerated to a constant could still keep '
        .. 'every ratchet above satisfied.')
    -- On the sites the host would actually score, the counterfactual is
    -- one-sided -- which is exactly the shape that looks safe and is not.
    cs.ratchet(SWEEP['r_ADD'], 15, 'responder-shaped sites ADDED')
    assert(SWEEP['r_WITHDRAW'] == 0,
        SWEEP['r_WITHDRAW'] .. ' responder-shaped withdrawal(s). This was 0 when '
        .. 'the collision in section 4 was measured, and the header leans on it: '
        .. 'the reading broke a sibling candidate WITHOUT taking a single '
        .. 'response away from the host.')
    assert(SWEEP['r_shipped'] + SWEEP['r_ADD'] == SWEEP['r_tower'],
        'r_shipped (' .. SWEEP['r_shipped'] .. ') + r_ADD (' .. SWEEP['r_ADD']
        .. ') /= r_tower (' .. SWEEP['r_tower'] .. ')')
end

--- One drive of the real shipped host on a real frame. ALWAYS a fresh load:
--- J.TryTakeTpResponseSlot is a module-level ledger the host consumes.
local function host_answer(path, subj, ids)
    local J, bot = rf.load(path, subj)
    local armed = {}
    for _, id in ipairs(ids) do armed[id] = true end
    J.IsSoakCandidate = function(id) return armed[id] == true end
    local b = J.ShouldTpSupportTowerFight(bot)
    return b, J, bot
end

tests['[tpdeftower] 4. the collision, on the sibling candidate\'s own frames'] = function()
    local STORM = 'npc_dota_hero_storm_spirit'
    local FR = {
        { 'outnumbered', 'tests/fixtures/f_260819_183613_storm_collapse_outnumbered.lua' },
        { 'lost',        'tests/fixtures/f_260819_183613_storm_collapse_lost.lua' },
    }
    for _, f in ipairs(FR) do
        -- (i) shipped, with the host's own candidate armed and nothing else:
        -- the host must REFUSE. That refusal is the whole content of both of
        -- tparrive's controls.
        local b = host_answer(f[2], STORM, { 'midtp' })
        assert(b == nil, f[1] .. ': the shipped host now answers '
            .. (b ~= nil and b:GetUnitName() or '?') .. ' with only `midtp` armed. tparrive\'s '
            .. 'control frames assume it refuses here; if that changed, the '
            .. 'collision recorded in this file has already happened to '
            .. 'somebody else.')
        -- (ii) and the counterfactual says COMMIT at the site the host scores.
        -- This is the collision, reproducible without the patched tree: the
        -- only thing standing between "refuse" and "commit" on these two frames
        -- is which point the winnability read is anchored at.
        local _, J, bot = host_answer(f[2], STORM, { 'midtp' })
        local found, cf = false, false
        for _, bd in pairs(GetUnitList(UNIT_LIST_ALLIED_BUILDINGS) or {}) do
            if J.IsValidBuilding(bd)
                and string.find(bd:GetUnitName(), 'tower') ~= nil
                and GetUnitToUnitDistance(bot, bd) > FAR_FLOOR
            then
                local vT = bd:GetLocation()
                local tE = J.GetEnemiesNearLoc(vT, TOWER_RING)
                if tE[1] ~= nil and ally_there(J, bot, vT) then
                    found = true
                    if tower_answer(J, vT, tE) then cf = true end
                end
            end
        end
        assert(found, f[1] .. ': no responder-shaped site on this frame any '
            .. 'more, so the frame no longer carries the comparison')
        assert(cf, f[1] .. ': the tower-anchored reading now REFUSES here too. '
            .. 'The collision this file records is gone -- which is good news '
            .. 'for option (a), and means its price must be re-taken rather '
            .. 'than read off this file.')
    end
    -- ⭐ POSITIVE CONTROL FOR THE DRIVER ITSELF. Both assertions above are
    -- satisfied by a driver that quietly stopped arming anything (the host's
    -- second line returns nil with no candidate armed, and then "shipped
    -- refuses" is true for a reason that has nothing to do with winnability).
    -- The `parity` frame is the corpus's witness that this driver can make the
    -- host fire, so a degenerate driver is red here instead of green above.
    assert(host_answer('tests/fixtures/f_260819_183613_storm_collapse_parity.lua',
        STORM, { 'midtp' }) ~= nil,
        'the driver no longer makes the host answer on the one frame the '
        .. 'corpus says it must, so the two refusals above prove nothing')
    -- And the sibling file still states the expectations that make (ii) a
    -- collision rather than a curiosity. Same job as GH #767 §4e: a pin over
    -- code that is not here can only keep its own premise honest.
    local sib = read_file('tests/test_tparrive_collapse_gate.lua')
    for _, want in ipairs({
        "name = 'outnumbered'", "name = 'lost'",
        'shipped = false, armed = true,', 'shipped = false, armed = false,',
    }) do
        assert(sib:find(want, 1, true) ~= nil,
            'tests/test_tparrive_collapse_gate.lua no longer contains "' .. want
            .. '". The price recorded here was taken against a version of that '
            .. 'file which no longer exists -- re-price before re-landing.')
    end
end

tests['[tpdeftower] 5. the lethal branch is unobservable on this corpus'] = function()
    -- ⛔ Kept as EQUALITIES, not ratchets: their whole content is a zero, and a
    -- counter-example is the finding (this corpus grew a frame where burst
    -- estimation is real), not a number to re-baseline past.
    assert(SWEEP['shipped_lethal'] == 0,
        'the shipped LETHAL branch now fires on ' .. SWEEP['shipped_lethal']
        .. ' site(s). Every count in sections 2-3 was taken while it fired 0 '
        .. 'times, i.e. they priced the NUMBERS branch of both readings; with '
        .. 'lethal alive they are about a different predicate.')
    assert(SWEEP['tower_lethal'] == 0,
        'the counterfactual LETHAL branch now fires on ' .. SWEEP['tower_lethal']
        .. ' site(s) -- same consequence as above for the tower anchor.')
    cs.ratchet(SWEEP['burst_positive'], 2,
        'sites where the estimated burst against the scored enemy is even '
        .. 'positive (2 of 113 -- this is the construction limit itself, not a '
        .. 'fact about the fights)')
    assert(SWEEP['shipped_true'] > SWEEP['shipped_lethal'],
        'every shipped commit came from the lethal branch, so the numbers '
        .. 'branch is the unobservable one and the header has it backwards')
end

tests['[tpdeftower] 6. the outpost half: the domain is real, the witness is not'] = function()
    cs.ratchet(SWEEP['site_outpost'], 8,
        'sites where the "tower" the defend-TP would answer is an OUTPOST '
        .. '(npc_dota_watch_tower matches string.find(name, "tower"))')
    cs.ratchet(SWEEP['site_tower'], 105, 'sites at a real tower')
    cs.ratchet(SWEEP['deep_vloc'], 5,
        'sites DEEP in the enemy half at the caller\'s own engage point')
    assert(SWEEP['deep_vloc_tower'] == 0,
        SWEEP['deep_vloc_tower'] .. ' REAL-TOWER site(s) are deep. The repaired '
        .. 'comment on J.SafeToCommitFightOnArrival keeps the premise "a '
        .. 'collapse onto our own tower is never deep" and only corrects the '
        .. 'inference drawn from it; a non-zero here retires the premise too.')
    assert(SWEEP['deep_vloc_outpost'] == SWEEP['deep_vloc'],
        'the deep sites are no longer all outposts (' .. SWEEP['deep_vloc_outpost']
        .. ' of ' .. SWEEP['deep_vloc'] .. '), so the repaired comment names the '
        .. 'wrong mechanism.')
    -- ⛔ THE HALF THAT KEPT THE NARROWING OUT OF THE TREE. A fresh drive of the
    -- real host per row that carries an outpost site: if it never answers an
    -- outpost, a narrowing has nothing to validate it and must not land.
    local answered, outpost_answered = 0, 0
    for _, row in ipairs(OUTPOST_ROWS) do
        local b = host_answer(row[1], row[2], { 'midtp' })
        if b ~= nil then
            answered = answered + 1
            if is_outpost(b) then outpost_answered = outpost_answered + 1 end
        end
    end
    cs.ratchet(#OUTPOST_ROWS, 8, 'rows that carry at least one outpost site')
    assert(outpost_answered == 0,
        outpost_answered .. ' row(s) now answer an OUTPOST end to end. That is '
        .. 'the witness GH #782 asked for: the narrowing can be landed with a '
        .. 'fixture instead of registered as a comment. Read this as a TODO, '
        .. 'not as a regression.')
    -- ⛔ How they fail matters, and it is stronger than the claim needed: none
    -- of the 8 rows answers ANY tower (answered == 0 when this was taken), so
    -- the outpost sites are not losing a race against a real tower -- they die
    -- earlier in the host's conjunction. A reader hunting the witness should
    -- start there rather than looking for a frame where an outpost wins a tie.
    assert(answered >= outpost_answered,
        'internal: outpost answers (' .. outpost_answered .. ') exceed total '
        .. 'answers (' .. answered .. ')')
end

tests['[tpdeftower] 7. shipped play is untouched'] = function()
    local host = block('function J.ShouldTpSupportTowerFight( bot )')
    assert(host:find('J.SafeToCommitFight( bot, tEnemies[1] )', 1, true) ~= nil,
        'the shipped winnability read is no longer `J.SafeToCommitFight( bot, '
        .. 'tEnemies[1] )`. This file prices a counterfactual AGAINST that '
        .. 'expression; if the site moved, every count here is about code that '
        .. 'is gone.')
    assert(SRC:find('SafeToCommitTowerDefense', 1, true) == nil,
        'a tower-anchored helper has been landed in ' .. TRG .. '. This file '
        .. 'says in its header that no behaviour change is behind it, and the '
        .. 'collision in section 4 is the reason -- either that measurement is '
        .. 'stale or the header is now false.')
    local iTurbo = host:find('if not J.IsModeTurbo() then return nil end', 1, true)
    local iGate  = host:find("if not ( J.IsSoakCandidate( 'midtp' ) or bSup ) then return nil end", 1, true)
    local iSite  = host:find('J.SafeToCommitFight( bot, tEnemies[1] )', 1, true)
    assert(iTurbo ~= nil and iGate ~= nil and iTurbo < iGate and iGate < iSite,
        'the turbo / candidate early returns no longer precede the site, so '
        .. 'anything landed here would reach shipped play')
    -- The building filter this round measured, still spelled the way it was
    -- measured -- the 8 outpost sites are a property of THIS test.
    assert(host:find("string.find( building:GetUnitName(), 'tower' ) ~= nil", 1, true) ~= nil,
        'the tower-name test changed. Section 6 counted outposts because that '
        .. 'test admits `npc_dota_watch_tower`; if it was narrowed, the '
        .. 'narrowing this file declined to land has happened and section 6 '
        .. 'needs to be read as history.')
    -- ⭐ AND THE FILTER IS STILL ONLY THAT TEST. Bought by the mutation stand
    -- (M8): the sweep RECOMPUTES the host's filter rather than reading it, so a
    -- narrowing landed in the host would leave all 8 outpost sites, every count
    -- and every ratchet in this file exactly as they are -- the census would go
    -- on pricing a domain the shipped code had already given up. Read off the
    -- STRIPPED block, so the outpost note in the source comment does not
    -- satisfy it.
    assert(host:find('watch_tower', 1, true) == nil,
        'the host now names `watch_tower` in CODE, i.e. the outpost narrowing '
        .. 'has landed. Section 6 still counts 8 outpost sites because it '
        .. 'rebuilds the filter itself -- re-read it as history and move the '
        .. 'counts onto the new filter.')
    -- ⛔ THE THREE CONSTANTS THIS FILE SWEEPS WITH ARE THE HOST'S, NOT ITS OWN.
    -- A census whose ring or floor drifts keeps every ratchet satisfied while
    -- measuring a cell the shipped code never reads.
    assert(host:find('J.GetEnemiesNearLoc( vTower, ' .. TOWER_RING .. ' )', 1, true) ~= nil,
        'the host no longer builds tEnemies at radius ' .. TOWER_RING)
    assert(SRC:find('J.TP_RESPONSE_FAR_FLOOR = ' .. FAR_FLOOR, 1, true) ~= nil,
        'J.TP_RESPONSE_FAR_FLOOR is no longer ' .. FAR_FLOOR)
    assert(SRC:find('hOwnAncient:GetLocation() ) - ' .. DEEP_MARGIN, 1, true) ~= nil,
        "the 'depthnum' margin is no longer " .. DEEP_MARGIN .. ', so section 6 '
        .. 'counts deep sites by a convention the predicate no longer uses')
    -- And the two comment repairs are in place, read off the UNSTRIPPED file
    -- because comments are exactly what they are.
    local raw = read_file(TRG)
    -- Normalised (comment markers and line breaks collapsed) so the pin
    -- survives re-wrapping, and worded so that this round's own prose -- which
    -- describes the old claim without restating it -- does not satisfy it.
    local flat = raw:gsub('\n%s*%-%-', ' '):gsub('%s+', ' ')
    assert(flat:find('never deep, so that branch is inert', 1, true) == nil,
        'the false inference ("...never deep, so that branch is inert in the '
        .. "caller's domain\") is back in the prose on "
        .. 'J.SafeToCommitFightOnArrival. Section 6 measured its conclusion '
        .. 'false on 5 of the caller\'s own sites.')
    assert(raw:find('npc_dota_watch_tower', 1, true) ~= nil,
        'the outpost note is gone from ' .. TRG .. '; section 6 is the only '
        .. 'thing left carrying a finding the source used to state')
end

return tests

-- [hero] `wkqflee` -- the reach term X.ConsiderQ's 撤退时保护自己 (retreat
-- self-defence) firing point has never had.
--
-- ===========================================================================
-- §0  WHAT THIS FILE CARRIES
-- ===========================================================================
--
-- The retreat branch walks nEnemysHerosInRange -- this function's own
-- `nCastRange + 43` SEARCH ring -- and returns the first legal member with no
-- distance term.  A member in the band (nCastRange, nCastRange + 43] cannot be
-- hit standing still, so X.SkillsComplement's ActionQueue_UseAbilityOnEntity is
-- a MOVE order first: Wraith King walks TOWARD the hero the branch's own
-- precondition (J.IsRetreating) says he is fleeing, and re-issues it every
-- frame for as long as the desire holds.
--
-- ⭐ THIS IS THE SIGN-FLIPPED SIBLING OF `wkqlane`, NOT A SECOND COPY.  There
-- the cost is an approach the bot chose; here the walk UNDOES a retreat that is
-- already running.  43 units is 0.13s of movement -- the magnitude is not the
-- argument, the sign is.  GH #873 §一 states the family rule positively: the
-- ring a branch SEARCHES should be the ring it is willing to ACCEPT, and
-- hero_crystal_maiden.lua:1761 is the in-repo copy that already does it.
--
-- ⭐ AND 43 IS THE FLOOR, NOT THE NUMBER.  The `#nEnemysHerosInView == 1`
-- clause above the ring adds 260 to nCastRange, and J.IsInTeamFight -- the only
-- nearby predicate that could have made the two mutually exclusive -- counts
-- ALLIES in BOT_MODE_ATTACK, never enemies (jmz_func.lua).  §2.3 asserts both
-- halves off the source.  With the extension fired the band is (nCastRange,
-- nCastRange + 303].
--
-- ===========================================================================
-- §0.1  THE DOMAIN, MEASURED -- ⛔ AND IT IS NOT EMPTY
-- ===========================================================================
--
-- Both frame directories, 144 frames, gates all off, nothing injected:
--
--     live-WK frames .................................... 51
--     ... carrying an enemy hero in the band ............  3
--     ... where the band member is the ring's ONLY tenant  1
--
-- That last frame is the real frame of §3.  On the other two an in-range enemy
-- sorts ahead of the band member in the distance-sorted list, so the loop
-- reaches the band member only if the nearer one fails the legality chain.
-- ⛔ Three frames is a small sample; the claim this file makes is "the band is
-- occupied on this corpus", never a frequency.
--
-- ===========================================================================
-- §0.2  ⛔ LIMITS -- QUOTING THIS FILE MEANS QUOTING THESE
-- ===========================================================================
--
-- 1. ⛔ RELOCATION IS POSSIBLE FOR THIS LEVER, unlike `wkqlane`.  While the bot
--    is in RETREAT mode the armed leg is NO CAST only when it is retreating
--    ALONE (allies within 1200 < 2) or below hero level 7; with two allies up
--    and level 7+ the catch-all (firing point 10) may answer instead and the
--    lever moves nothing.  §3.3 and §3.4 DRIVE both halves.  Quote the
--    disjunction, never a bare "no cast".
-- 2. ⚠️ ONE INJECTION ON THE REAL FRAME, named: bot:GetActiveMode() ->
--    BOT_MODE_RETREAT (with its desire).  Mode is bot-VM state and is in no
--    .dem -- the 13th-world assertion this tree already carries.  Geometry,
--    roster, health, mana, level, ranks and cooldowns are REAL.  §3.4 adds a
--    SECOND, separately named injection (a two-ally roster) and says so in its
--    own name.
-- 3. ⚠️ §2 and §4 TRANSCRIBE the retreat loop's legality chain to know which
--    candidates it would consider.  §6.2 asserts the shipped chain still reads
--    that way, which is what makes the transcription allowed to exist here.

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')

local WK   = 'npc_dota_hero_skeleton_king'
local SRC  = 'bots/BotLib/hero_skeleton_king.lua'
local Q    = 'skeleton_king_hellfire_blast'
local CAND = 'wkqflee'
local RING = 43

-- ⭐ BOTH directories (tests/frames/README.md: any scan claiming "the tree"
-- rather than "the corpus" has to enumerate tests/frames/ too).  REQUIRED_DIRS
-- is the CLAIM, CORPUS_DIRS is the IMPLEMENTATION, and §1.1 compares them --
-- a guard that only ranges over what is present cannot see an absence.
local CORPUS_DIRS   = { 'tests/fixtures', 'tests/frames' }
local REQUIRED_DIRS = { 'tests/fixtures', 'tests/frames' }

local PIN = 'tests/frames/f_260909_215040_wk_blast_lion_480.lua'

-- Floors, not equalities: the corpus only grows.
local LIVE_WK_FLOOR = 51
local BAND_FLOOR    = 3

local T = {}

local function read_file(path)
    local fh = assert(io.open(path, 'r'), 'cannot open ' .. path)
    local body = fh:read('*a')
    fh:close()
    return body
end

local function code_only(s)
    return (s:gsub('%-%-[^\n]*', ''))
end

--- Every frame chunk in the corpus, deduplicated BY BASENAME.
local function fixture_files()
    local files, seen, per_dir = {}, {}, {}
    for _, dir in ipairs(CORPUS_DIRS) do
        per_dir[dir] = 0
        -- UNRESOLVED_HAND_READ: io.popen, the habit registered in
        -- tests/test_bots_walk_farm_only.py (GH #596 / GH #803).
        local p = io.popen('ls ' .. dir .. ' 2>/dev/null')
        if p then
            for line in p:lines() do
                if line:match('^f_.+%.lua$') and not seen[line] then
                    seen[line] = true
                    files[#files + 1] = dir .. '/' .. line
                    per_dir[dir] = per_dir[dir] + 1
                end
            end
            p:close()
        end
    end
    table.sort(files)
    return files, per_dir
end

local mALIVE = {}
local function alive(path, unit)
    local set = mALIVE[path]
    if set == nil then
        set = {}
        local ok, chunk = pcall(dofile, path)
        if ok and type(chunk) == 'table' then
            for _, u in ipairs(chunk.units or {}) do
                if u.alive == true then set[u.name] = true end
            end
        end
        mALIVE[path] = set
    end
    return set[unit] == true
end

--- The band census.  ⛔ Nothing injected, nothing driven: this reads the ring
--- the shipped branch reads and measures where its members sit relative to the
--- cast range the same frame reports.
local mBAND = nil
local function band_census()
    if mBAND ~= nil then return mBAND end
    local rows = {}
    for _, path in ipairs((fixture_files())) do
        if alive(path, WK) then
            local row = { path = path, band = 0, inring = 0 }
            local ok, err = pcall(function()
                local J, bot = rf.load(path, WK)
                local hQ = bot:GetAbilityByName(Q)
                local cr = (hQ and hQ:GetCastRange()) or 0
                row.cast_range = cr
                row.q_level = (hQ and hQ:GetLevel()) or -1
                for _, e in pairs(J.GetNearbyHeroes(bot, cr + RING, true, BOT_MODE_NONE)) do
                    local d = GetUnitToUnitDistance(bot, e)
                    if d > cr then
                        row.band = row.band + 1
                        row.band_unit = row.band_unit or e:GetUnitName()
                        row.band_dist = row.band_dist or d
                    else
                        row.inring = row.inring + 1
                    end
                end
            end)
            row.err = (not ok) and tostring(err) or nil
            rows[#rows + 1] = row
        end
    end
    mBAND = rows
    return rows
end

--- The pinned frame, driven end to end through the SHIPPED dispatch and the
--- SHIPPED X.ConsiderQ.  `opts` names every injection it applies.
local function drive_pin(opts)
    opts = opts or {}
    local J, bot = rf.load(PIN, WK)
    J.IsModeTurbo    = function() return true end
    J.IsSoakCandidate = function(id) return opts.armed == true and id == CAND end
    if opts.retreat then
        -- INJECTION 1 (limit 2): mode is bot-VM state, in no .dem.
        bot.GetActiveMode       = function() return BOT_MODE_RETREAT end
        bot.GetActiveModeDesire = function() return BOT_MODE_DESIRE_HIGH end
    end
    if opts.two_allies then
        -- INJECTION 2 (limit 2), applied ONLY by the test that names it: a
        -- second ally inside 1200, so the catch-all's `#allyList >= 2`
        -- disjunct is true.  The roster of this frame really carries one.
        local inner = J.GetNearbyHeroes
        J.GetNearbyHeroes = function(b, r, bEnemy, mode)
            local list = inner(b, r, bEnemy, mode)
            if bEnemy == false and r == 1200 and #list == 1 then
                return { list[1], list[1] }
            end
            return list
        end
    end
    local X = rf.load_hero('skeleton_king')
    X.SkillsComplement()
    local d, t = X.ConsiderQ()
    return {
        desire = d,
        target = (type(t) == 'table' and t.GetUnitName and t:GetUnitName()) or nil,
        bot = bot, J = J, X = X,
    }
end

--- The body of X.ConsiderQ, cut on the function rather than on a prose needle.
local function consider_q_body()
    local src = read_file(SRC)
    local i = assert(src:find('\nfunction%s+X%.ConsiderQ%s*%('), 'X.ConsiderQ not found in ' .. SRC)
    local rest = src:sub(i + 1)
    return rest:sub(1, assert(rest:find('\nend\n'), 'no terminating end for X.ConsiderQ'))
end

--- The 撤退时保护自己 block, anchored on its own comment marker so the sibling
--- loops in this same function cannot satisfy a needle meant for it.
local function retreat_block()
    local body = consider_q_body()
    local i = assert(body:find('--撤退时保护自己', 1, true),
        'the 撤退时保护自己 marker is gone from X.ConsiderQ -- §6.1 says what that means')
    return body:sub(i, i + 1400)
end

-- ------------------------------------------------------------- section 1 --
-- COVERAGE, pointed at THIS file's enumeration rather than at the tree.

T['§1.1 the corpus walk enumerates BOTH frame directories, and neither is empty'] = function()
    local files, per_dir = fixture_files()
    for _, dir in ipairs(REQUIRED_DIRS) do
        assert((per_dir[dir] or 0) > 0, 'REQUIRED corpus directory ' .. dir .. ' contributed no '
            .. 'frames to this file\'s walk.  Either the directory moved or CORPUS_DIRS no '
            .. 'longer covers what §0.1\'s universals range over -- and a guard written against '
            .. 'CORPUS_DIRS alone cannot see the second case, which is why REQUIRED_DIRS exists.')
    end
    assert(#files >= 100, 'corpus shrank to ' .. #files .. ' frames; §0.1 quotes 144')
end

-- ------------------------------------------------------------- section 2 --
-- THE SHIPPED SHAPE, parsed from source.  These are the sentences §0 makes.

T['§2.1 the retreat branch iterates the nCastRange + 43 SEARCH ring'] = function()
    local body = code_only(consider_q_body())
    assert(body:find('local nEnemysHerosInRange = J.GetNearbyHeroes(bot, nCastRange + 43', 1, true) ~= nil,
        'the search ring is no longer `nCastRange + 43`.  Every number in §0.1 is a count of '
        .. 'THAT band; re-measure before quoting this file.')
    local seg = code_only(retreat_block())
    assert(seg:find('J.IsRetreating( bot )', 1, true) ~= nil,
        'the retreat branch no longer guards on J.IsRetreating -- the whole argument for this '
        .. 'lever is that the walk it orders undoes a retreat that is already running')
    assert(seg:find('nEnemysHerosInRange', 1, true) ~= nil,
        'the retreat branch no longer iterates nEnemysHerosInRange')
end

T['§2.2 the gate is wired into the retreat loop, in CODE and not in prose'] = function()
    local seg = code_only(retreat_block())
    assert(seg:find('X.wk_IsFleeBlastTargetInReach( npcEnemy, nCastRange )', 1, true) ~= nil,
        'the `' .. CAND .. '` call site is not in the retreat loop\'s CODE.  ⭐ This assertion '
        .. 'reads code_only output on purpose: the charter\'s `-205` cost a round to the other '
        .. 'spelling, where a raw source read scored a PROSE mention of an id as a gate.')
    -- nCastRange is passed IN, not re-read: that is what makes the lever compose
    -- with the +260 extension instead of silently ignoring it.
    local src = read_file(SRC)
    local i = assert(src:find('function X.wk_IsFleeBlastTargetInReach', 1, true))
    local fn = code_only(src:sub(i, i + 400))
    assert(fn:find('J.IsSoakCandidate( \'' .. CAND .. '\' )', 1, true) ~= nil,
        'the helper no longer gates on ' .. CAND)
    assert(fn:find('J.IsModeTurbo()', 1, true) ~= nil,
        'the helper is no longer turbo-only -- every behaviour lever in this tree is')
    assert(fn:find('J.IsInRange( npcEnemy, bot, nCastRange )', 1, true) ~= nil,
        'the armed predicate is no longer "inside nCastRange".  ⛔ If it grew a `+ 80` it '
        .. 'became a COMMIT allowance, which is the one thing §0 says a retreat is not spending.')
end

T['§2.3 nothing makes the +260 extension and the retreat branch mutually exclusive'] = function()
    local body = code_only(consider_q_body())
    assert(body:find('nCastRange = nCastRange + 260', 1, true) ~= nil,
        'the lone-ranged-enemy extension is gone; §0 quotes it as the reason 43 is a floor '
        .. 'rather than the number.  Re-read the band arithmetic before quoting it.')
    -- The only nearby-crowd predicate that could have excluded it counts ALLIES.
    local jm = read_file('bots/FunLib/jmz_func.lua')
    local i = assert(jm:find('\nfunction J.IsInTeamFight%s*%('), 'J.IsInTeamFight not found')
    local fn = code_only(jm:sub(i, i + 900))
    assert(fn:find('BOT_MODE_ATTACK', 1, true) ~= nil and fn:find('attackModeAllyList', 1, true) ~= nil,
        'J.IsInTeamFight no longer counts allies in BOT_MODE_ATTACK.  §0 uses that fact to say '
        .. 'the extension and this branch can hold together; if the predicate now reads enemies, '
        .. 'the floor-versus-number sentence has to be re-derived.')
end

-- ------------------------------------------------------------- section 3 --
-- THE REAL FRAME, DRIVEN.  ⛔ Not a re-implementation of the branch: every
-- reading below comes out of the shipped X.SkillsComplement + X.ConsiderQ.

T['§3.1 the frame really holds one band enemy, and the band is real (cast range 525)'] = function()
    local J, bot = rf.load(PIN, WK)
    local hQ = assert(bot:GetAbilityByName(Q), 'Q handle missing on the pinned frame')
    local cr = hQ:GetCastRange()
    assert(cr == 525, 'GetCastRange answers ' .. tostring(cr) .. ' on the pinned frame, not the '
        .. 'real 525.  ⛔ At 0 the band is empty by construction and BOTH legs answer "no cast" '
        .. 'for a reason about the harness -- the meter-zero family, and the reason §0.2 insists '
        .. 'this frame needs no cast-range injection.')
    local ring = J.GetNearbyHeroes(bot, cr + RING, true, BOT_MODE_NONE)
    assert(#ring == 1, 'the ring holds ' .. #ring .. ' enemies, not 1; §0.1 calls this the frame '
        .. 'where the band member is the ring\'s ONLY tenant')
    local d = GetUnitToUnitDistance(bot, ring[1])
    assert(ring[1]:GetUnitName() == 'npc_dota_hero_lion', 'the sole ring tenant is now '
        .. ring[1]:GetUnitName())
    assert(d > cr and d <= cr + RING, string.format(
        'lion sits at %.1fu, outside the band (%d, %d]', d, cr, cr + RING))
    -- The branch's own disjunct, read off the frame rather than injected.
    assert(bot:GetMana() / bot:GetMaxMana() > 0.8, 'mana fell below the branch\'s `nMP > 0.8` '
        .. 'disjunct on this frame; §0 claims that disjunct is true WITHOUT touching the frame')
    assert(bot:GetLevel() >= 7, 'hero level dropped below 7 -- §3.4\'s relocation half needs it')
end

T['§3.2 the two firing points ABOVE the retreat branch decline on their own terms'] = function()
    local J, bot = rf.load(PIN, WK)
    local X = rf.load_hero('skeleton_king')
    local hQ = bot:GetAbilityByName(Q)
    local ring = J.GetNearbyHeroes(bot, hQ:GetCastRange() + RING, true, BOT_MODE_NONE)
    local lion = ring[1]
    assert(not lion:IsChanneling(), 'lion is channelling on this frame -- the interrupt point '
        .. 'would answer first and the frame stops separating the legs')
    assert(not J.CanKillTarget(lion, X.wk_GetBlastKillDamage(hQ), DAMAGE_TYPE_MAGICAL),
        'the kill-confirm point can now take lion (it is bounded at +80, which ADMITS 547.5u), '
        .. 'so it answers before the retreat branch and this frame no longer isolates the lever')
    assert(not J.IsGoingOnSomeone(bot), '打架先手 is live on this frame')
    assert(not J.IsInTeamFight(bot, 1200), 'the 团战 branch is live on this frame')
end

T['§3.3 ARMED vs UNARMED on the real frame: the shipped leg casts on a target it cannot reach, the armed leg does not cast'] = function()
    local base = drive_pin({ retreat = true, armed = false })
    assert(base.desire == BOT_ACTION_DESIRE_HIGH and base.target == 'npc_dota_hero_lion',
        'the SHIPPED leg no longer answers HIGH/lion while retreating (got '
        .. tostring(base.desire) .. '/' .. tostring(base.target) .. ').  That reading is the '
        .. 'defect this lever exists for; without it the armed leg below proves nothing.')

    local armed = drive_pin({ retreat = true, armed = true })
    assert(armed.desire == 0 and armed.target == nil,
        'ARMED still bids ' .. tostring(armed.desire) .. ' on ' .. tostring(armed.target)
        .. '.  ⛔ Either the gate is not reaching the loop or a firing point BELOW the retreat '
        .. 'branch picked the band member up -- §0.2 limit 1 says which ones can, and on THIS '
        .. 'frame (one ally within 1200) none of them may.')

    -- ⭐ The UNARMED control, separately: with the id off, arming machinery that
    -- never runs would look identical to a lever that works.
    local off = drive_pin({ retreat = true, armed = false })
    assert(off.target == 'npc_dota_hero_lion', 'the unarmed control moved; the two legs above '
        .. 'are then not a controlled comparison')
end

T['§3.4 RELOCATION, driven not quoted: with two allies up the catch-all answers anyway'] = function()
    -- ⚠️ INJECTION 2, named in this test\'s own title: a two-ally roster inside
    -- 1200.  It is the half of §0.2 limit 1 the real roster cannot show.
    local armed = drive_pin({ retreat = true, armed = true, two_allies = true })
    assert(armed.desire == BOT_ACTION_DESIRE_HIGH and armed.target == 'npc_dota_hero_lion',
        'with `#allyList >= 2` the catch-all (firing point 10) is supposed to answer with the '
        .. 'same band member, so the armed lever moves NOTHING there -- got '
        .. tostring(armed.desire) .. '/' .. tostring(armed.target) .. '.  ⛔ If this flipped, '
        .. 'the lever is stronger than §0.2 limit 1 claims and the LIMIT is what is wrong: '
        .. 'rewrite it before quoting "no cast" anywhere.')
end

-- ------------------------------------------------------------- section 4 --
-- THE BAND CENSUS.  ⛔ Floors, and a named pin, so a growing corpus cannot
-- quietly turn §0.1 into a stale universal.

T['§4.1 the band is occupied on this corpus -- 3 of 51 live-WK frames'] = function()
    local rows = band_census()
    local live, band, sole = 0, 0, {}
    for _, r in ipairs(rows) do
        assert(r.err == nil, 'band census failed on ' .. r.path .. ': ' .. tostring(r.err))
        live = live + 1
        if r.band > 0 then
            band = band + 1
            if r.inring == 0 then sole[#sole + 1] = r.path end
        end
    end
    assert(live >= LIVE_WK_FLOOR, 'live-WK frames fell to ' .. live .. ' (floor ' .. LIVE_WK_FLOOR
        .. '); §0.1 is a reading over that set')
    assert(band >= BAND_FLOOR, 'only ' .. band .. ' frames carry a band enemy now (floor '
        .. BAND_FLOOR .. ').  ⛔ If the corpus really lost them, this lever\'s domain reading '
        .. 'has to be retaken -- "the band is occupied" is the sentence that justifies the gate.')
    local found = false
    for _, p in ipairs(sole) do if p == PIN then found = true end end
    assert(found, 'the pinned frame ' .. PIN .. ' is no longer one where the band member is the '
        .. 'ring\'s only tenant.  §3 depends on that; re-pin before trusting it.')
end

-- ⭐ MEASURED, NOT ASSUMED, AND THE FIRST DRAFT OF THIS TEST WAS WRONG.  It
-- asserted "no live-WK frame reports cast range 0" and went red on three: the
-- meter-zero family is the obvious suspect and it is NOT the answer here.  All
-- three carry Q at RANK 0, where 0 is the correct cast range and the branch is
-- unreachable anyway (X.ConsiderQ returns at its IsFullyCastable line).  So the
-- guard has to separate the two readings rather than forbid the number: a zero
-- with a trained Q is the meter, a zero at rank 0 is the game.
T['§4.2 every cast-range zero in the census is explained by Q at rank 0, not by the meter'] = function()
    local rows = band_census()
    local unexplained, rank0 = {}, 0
    for _, r in ipairs(rows) do
        if (r.cast_range or 0) == 0 then
            if (r.q_level or -1) <= 0 then
                rank0 = rank0 + 1
            else
                unexplained[#unexplained + 1] = r.path .. ' (Q rank ' .. tostring(r.q_level) .. ')'
            end
        end
    end
    assert(#unexplained == 0, #unexplained .. ' live-WK frame(s) report cast range 0 with Q '
        .. 'TRAINED, so their band is empty by construction and §4.1\'s count is a count of the '
        .. 'meter rather than of the game (the meter-zero family, of which this very cast range '
        .. 'was the fifth member until it was repaired).  First offender: '
        .. tostring(unexplained[1]))
    assert(rank0 >= 1, 'no rank-0 frame left in the census; the comment above explains a '
        .. 'reading that no longer exists -- re-derive it rather than deleting the guard')
end

-- ------------------------------------------------------------- section 5 --
-- GATE DISCIPLINE.

T['§5.1 unarmed is byte-for-byte the shipped behaviour'] = function()
    local J, bot = rf.load(PIN, WK)
    J.IsModeTurbo     = function() return true end
    J.IsSoakCandidate = function() return false end
    local X = rf.load_hero('skeleton_king')
    local hQ = bot:GetAbilityByName(Q)
    local ring = J.GetNearbyHeroes(bot, hQ:GetCastRange() + RING, true, BOT_MODE_NONE)
    assert(X.wk_IsFleeBlastTargetInReach(ring[1], hQ:GetCastRange()) == true,
        'the unarmed helper refused a candidate.  A gate that is not a no-op when unarmed is '
        .. 'live in every real game, which is the one thing a soak candidate may never be.')
end

T['§5.2 armed OUTSIDE turbo is still the shipped behaviour'] = function()
    local J, bot = rf.load(PIN, WK)
    J.IsModeTurbo     = function() return false end
    J.IsSoakCandidate = function(id) return id == CAND end
    local X = rf.load_hero('skeleton_king')
    local hQ = bot:GetAbilityByName(Q)
    local ring = J.GetNearbyHeroes(bot, hQ:GetCastRange() + RING, true, BOT_MODE_NONE)
    assert(X.wk_IsFleeBlastTargetInReach(ring[1], hQ:GetCastRange()) == true,
        'the lever acts outside Turbo.  Turbo is the optimisation target and the only mode the '
        .. 'batch farm measures; a lever that fires in normal games ships untested behaviour.')
end

T['§5.3 armed IN turbo refuses the band member and admits an in-range one'] = function()
    local J, bot = rf.load(PIN, WK)
    J.IsModeTurbo     = function() return true end
    J.IsSoakCandidate = function(id) return id == CAND end
    local X = rf.load_hero('skeleton_king')
    local hQ = bot:GetAbilityByName(Q)
    local cr = hQ:GetCastRange()
    local ring = J.GetNearbyHeroes(bot, cr + RING, true, BOT_MODE_NONE)
    assert(X.wk_IsFleeBlastTargetInReach(ring[1], cr) == false,
        'armed, the helper still admits lion at 547.5u against a 525 cast range')
    -- The same candidate against a cast range that DOES reach it: the predicate
    -- has to be about distance, not about the unit.
    assert(X.wk_IsFleeBlastTargetInReach(ring[1], cr + 300) == true,
        'armed, the helper refuses a candidate that IS inside the range it was handed -- the '
        .. 'predicate is not reading its nCastRange argument, so it would NOT compose with the '
        .. '+260 extension (§2.3), which is the whole reason that argument is passed in')
end

-- ------------------------------------------------------------- section 6 --
-- RETIREMENT AND TRANSCRIPTION GUARDS.

T['§6.1 this file retires the day the gate is promoted or removed'] = function()
    local src = code_only(read_file(SRC))
    assert(src:find(CAND, 1, true) ~= nil,
        'no `' .. CAND .. '` gate exists in ' .. SRC .. ' any more.  If it was PROMOTED, this '
        .. 'file is retired: fold §0.1\'s readings into the promotion note and delete it.  If it '
        .. 'was reverted, delete it too -- ⛔ what it must not do is keep asserting a lever that '
        .. 'is not on the tree.')
end

T['§6.2 the transcribed retreat chain still matches the shipped loop'] = function()
    local seg = code_only(retreat_block())
    for _, needle in ipairs({
        'J.IsValid( npcEnemy )',
        'X.wk_IsFleeBlastTargetInReach( npcEnemy, nCastRange )',
        'bot:WasRecentlyDamagedByHero( npcEnemy, 5.0 )',
        'nMP > 0.8',
        'J.CanCastOnNonMagicImmune( npcEnemy )',
        'J.CanCastOnTargetAdvanced( npcEnemy )',
        'not J.IsDisabled( npcEnemy )',
        'not npcEnemy:IsDisarmed()',
    }) do
        assert(seg:find(needle, 1, true) ~= nil, 'the shipped retreat loop no longer contains "'
            .. needle .. '".  §2 and §4 transcribe this chain to know which candidates the loop '
            .. 'would consider; a chain that moved makes every count a count of a different set.')
    end
end

T['§6.3 the three sibling rings are still what GH #873 §二 recorded'] = function()
    -- ⭐ The family table, parsed rather than quoted: the shape travelled across
    -- three heroes and the term that made it safe did not travel with it.
    local cm = code_only(read_file('bots/BotLib/hero_crystal_maiden.lua'))
    assert(cm:find('nMostDangerousDamage', 1, true) ~= nil,
        'the Crystal Maiden copy of the argmax family is gone; §0 cites it as the in-repo '
        .. 'reference for "search ring == cast ring"')
    local lion = code_only(read_file('bots/BotLib/hero_lion.lua'))
    assert(lion:find('lionwfight', 1, true) ~= nil,
        'the Lion sibling lever `lionwfight` is gone from hero_lion.lua -- §0 calls this lever '
        .. 'its sign-flipped sibling, and a family argument with one member left is not one')
end

return T

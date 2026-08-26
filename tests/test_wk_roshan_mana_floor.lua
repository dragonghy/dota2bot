-- [hero] `wkrosh` -- Wraith King's Roshan branch asks for 600 absolute mana
-- before it will spend a 95..140 mana spell, and 600 is above the ENTIRE pool of
-- every Wraith King frame this repo has ever recorded.
--
-- THE DEFECT
-- ----------
-- bots/BotLib/hero_skeleton_king.lua X.ConsiderQ has exactly one branch that can
-- cast on Roshan (every other branch in the function iterates hero lists, and the
-- farming branch excludes him by name: `not J.IsRoshan( targetCreep )`).  Its
-- entry price was
--
--     bot:GetActiveMode() == BOT_MODE_ROSHAN and bot:GetMana() >= 600
--
-- Wraithfire Blast costs 95/110/125/140.  An absolute floor 4.3x the price of the
-- spell it gates is the defect, and the 2026-08-23 round
-- (tests/test_wk_roshan_mana_ceiling.lua) already established the arithmetic half:
-- at every pre-scepter milestone in the shipped buy lists the crossing pool is
-- exactly 603, so 600 asks for 99.5% of the pool and one cast puts him under it
-- for the rest of the fight.  That round registered the candidate SHAPE and did
-- not write it.  This file is where it is written, gated.
--
-- WHAT THIS FILE ADDS THAT THE CEILING FILE DID NOT HAVE
-- -----------------------------------------------------
-- A reading off real frames in the dimension the lever is about.  Section 2 walks
-- every Wraith King hero row in tests/fixtures -- 34 of them -- and asks each one
-- the branch's own mana question with the frame's own mana, level and ability
-- ranks:
--
--     shipped floor (600) admits  0 of 34.
--     the highest MAX pool on any of those frames is 459 -- so on this corpus the
--     branch is mana-dead with a FULL bar, whatever Roshan is doing and whatever
--     mode the bot is in.
--     armed floor admits 22 of the 29 frames that have the Blast learned at all.
--
-- The 0/34 is the load-bearing number and it does NOT depend on the mode
-- predicate, which is what makes it worth having: the domain question (section 4)
-- is unanswerable offline, but the mana question is not, and the mana question
-- alone closes the branch on every frame in the archive.
--
-- HONEST BOUNDS -- READ BEFORE QUOTING ANY NUMBER FROM HERE
--   * 0 of 34 is EMPTY ON THIS CORPUS, never RARE IN THE GAME (the stream's Y.2
--     rule).  Every frame here is level 12 or below because the corpus was cut
--     from turbo games capped at 10 game-minutes; the pool crosses 603 at level
--     18-19 with the shipped wand+bracer.  GH #108 raised the cap to 25 game
--     minutes, so a corpus cut AFTER that change can contain frames this scan
--     structurally could not.  When one exists, re-run section 2 before quoting
--     it.
--   * The two mana costs are FRAME-EXTERNAL ANCHORS.  Fixtures carry ability
--     names, levels and cooldowns; they do not carry mana costs, and the mock
--     answers 0 for GetManaCost on every handle (section 4 pins that).  So the
--     costs below are recorded from the game's own KV with a date, and section 2
--     indexes them by each frame's OWN ability rank.  A run that read them off
--     the handles instead would answer 0 and call every frame affordable.
--   * Section 2 says nothing about whether blasting Roshan is a good idea.  That
--     is the lever's (c) argument and it lives in the doc block above
--     X.GetRoshanManaFloor, where the cost side is stated too.
--   * `armed admits 22 of 29` is not "the gate always says yes": 7 learned-Blast
--     frames still fail the armed floor, all of them frames where Reincarnation
--     is rank 1 and its 220 reserve is doing the refusing.  That asymmetry is
--     asserted, not narrated -- it is the evidence that the armed leg is a
--     RESERVE and not a hole.
--
-- THE KNOWN COLLAPSE MODES, checked at the desk (section 5 ratchets them)
--   * DOWNSTREAM-DOMINATED: no.  Nothing after this branch in X.ConsiderQ casts
--     on Roshan; the last branch requires enemy HEROES in range.
--   * UPSTREAM-SIBLING: no.  Every branch above it needs an enemy hero, except
--     the farming branch, which excludes Roshan explicitly.
--   * A STRONGER GUARD ALREADY DOING IT: no, and this one is subtle -- the file's
--     other mana rule, X.ShouldSaveMana, is consulted on ConsiderQ's first line
--     and refuses any cast that would drop him under Reincarnation's cost, but
--     ONLY while Reincarnation is within 3.0s of ready.  The armed floor is that
--     same reserve made unconditional inside a Roshan fight, so the two agree in
--     direction and the armed leg is never the LOOSER of the two.
--   * CONSUMER-SIDE-UNREACHABLE: no.  X.SkillsComplement turns a positive
--     ConsiderQ bid into ActionQueue_UseAbilityOnEntity on the next line, and
--     ConsiderQ is its first consumer.
--   * CARRIER-UNAVAILABLE: no.  Wraith King is a focus hero and in the soak pool.
--   * DOMAIN (does a bot ever enter BOT_MODE_ROSHAN at all): UNKNOWN, and it
--     cannot be measured offline -- see section 4.  Requested as queue hero-10.

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')

local SRC = 'bots/BotLib/hero_skeleton_king.lua'
local WK = 'npc_dota_hero_skeleton_king'
local BLAST = 'skeleton_king_hellfire_blast'
local REINCARN = 'skeleton_king_reincarnation'
local FIXTURE = 'tests/fixtures/f_260823_002103_wk_ancient_camp_634.lua'

-- Recorded 2026-08-26 from the game's own KV
-- (dotabuff/d2vpkr dota/scripts/npc/heroes/npc_dota_hero_skeleton_king.txt), the
-- same mirror tools/agent/special_value_key_census.py reads.  Reincarnation's
-- costs live in AbilityValues/AbilityManaCost/value, not at the top level, and
-- rank 3 really is free -- that is why the armed floor collapses to the blast's
-- own price once Reincarnation is maxed.
local BLAST_MANA = { 95, 110, 125, 140 }
local REINCARN_MANA = { 220, 110, 0 }

-- The shipped constant, quoted here so section 5 fails if the source stops
-- containing it (a promote that deletes the gate must land in this file too).
local SHIPPED_FLOOR = 600

local tests = {}

local function read_file(path)
    local fh = assert(io.open(path, 'r'), 'cannot open ' .. path)
    local body = fh:read('*a')
    fh:close()
    return body
end

--- Load the real frame and the real hero module, with `wkrosh` armed or not.
--- Optionally force the game out of turbo, and optionally publish mana costs onto
--- the frame's own ability handles (the frame-external anchor -- see HONEST
--- BOUNDS).  Returns the module plus the world.
local function world(bArmed, bNonTurbo, tCosts)
    local J, bot, heroes, fx = rf.load(FIXTURE)
    J.IsSoakCandidate = function(id) return bArmed and id == 'wkrosh' end
    if bNonTurbo then
        -- rf.load's install() forces turbo; undo it AFTER load, exactly as
        -- tests/test_axe_cull_immune_veto.lua does.
        GetGameMode = function() return 1 end
    end
    for sName, nCost in pairs(tCosts or {}) do
        local h = bot:GetAbilityByName(sName)
        rawget(h, '__spec').GetManaCost = nCost
    end
    local X = rf.load_hero('skeleton_king')
    return X, J, bot, heroes, fx
end

--- Every Wraith King hero row in the fixture archive with the fields this file
--- reads.  dofile, not a regex: the fixtures are data (the same rule
--- tests/test_wk_roshan_mana_ceiling.lua states, and for the same reason -- an
--- earlier round under-counted Axe frames 10 to 26 with a regex).
local function wk_frames()
    local p = assert(io.popen('ls tests/fixtures/f_*.lua'))
    local tRows = {}
    for sPath in p:lines() do
        local tFix = dofile(sPath)
        for _, tUnit in ipairs((tFix or {}).units or {}) do
            if tUnit.name == WK then
                local nBlast, nReincarn = 0, 0
                for _, tAb in ipairs(tUnit.abilities or {}) do
                    if tAb.name == BLAST then nBlast = tAb.level end
                    if tAb.name == REINCARN then nReincarn = tAb.level end
                end
                tRows[#tRows + 1] = {
                    file = sPath:match('([^/]+)$'),
                    level = tUnit.level, mp = tUnit.mp, max_mp = tUnit.max_mp,
                    blast = nBlast, reincarn = nReincarn,
                }
            end
        end
    end
    p:close()
    return tRows
end

--- The armed floor for one frame, from the frame's own ranks and the recorded KV.
local function armed_floor(tRow)
    local nCost = BLAST_MANA[tRow.blast] or 0
    local nReserve = REINCARN_MANA[tRow.reincarn] or 0
    return nCost + nReserve
end

-- ---------------------------------------------------------------- section 1 --
-- The gate itself, driven on a real frame.

tests['section 1: unarmed, the floor is the shipped 600'] = function()
    local X = world(false, false, { [BLAST] = 140, [REINCARN] = 220 })
    assert(X.GetRoshanManaFloor(140) == SHIPPED_FLOOR,
        'the shipped leg must answer ' .. SHIPPED_FLOOR .. ', got '
        .. tostring(X.GetRoshanManaFloor(140)))
end

tests['section 1: armed in turbo, the floor is cost + the reincarnation reserve'] = function()
    local X = world(true, false, { [BLAST] = 140, [REINCARN] = 220 })
    assert(X.GetRoshanManaFloor(140) == 360,
        'rank-4 blast (140) plus rank-1 Reincarnation (220) is 360, got '
        .. tostring(X.GetRoshanManaFloor(140)))
    local X2 = world(true, false, { [BLAST] = 125, [REINCARN] = 110 })
    assert(X2.GetRoshanManaFloor(125) == 235, 'rank-2 Reincarnation reserves 110')
    local X3 = world(true, false, { [BLAST] = 140, [REINCARN] = 0 })
    assert(X3.GetRoshanManaFloor(140) == 140,
        'rank-3 Reincarnation is FREE in this patch, so the floor collapses to '
        .. 'the blast price itself')
end

tests['section 1: armed OUTSIDE turbo changes nothing'] = function()
    local X = world(true, true, { [BLAST] = 140, [REINCARN] = 220 })
    assert(X.GetRoshanManaFloor(140) == SHIPPED_FLOOR,
        'the gate is turbo-only; a non-turbo game must keep the shipped floor')
end

tests['section 1: one-directional BY CONSTRUCTION, not by today arithmetic'] = function()
    -- If a future patch made the reserve enormous, the armed leg must not start
    -- demanding MORE than the shipped leg: the lever's claim is "600 is too high",
    -- and a leg that could raise it would be testing something nobody argued for.
    local X = world(true, false, { [BLAST] = 140, [REINCARN] = 900 })
    assert(X.GetRoshanManaFloor(140) == SHIPPED_FLOOR,
        'armed floor rose above the shipped one; got '
        .. tostring(X.GetRoshanManaFloor(140)))
    -- And the boundary itself: exactly equal is not below, so it stays shipped.
    local X2 = world(true, false, { [BLAST] = 140, [REINCARN] = 460 })
    assert(X2.GetRoshanManaFloor(140) == SHIPPED_FLOOR,
        'a relative floor equal to 600 must not be reported as a widening')
end

tests['section 1: a nil Reincarnation handle does not crash the floor'] = function()
    -- The engine's answer for an UNLEARNED ultimate is not settled at this desk;
    -- a MISSING handle is, and it must not take the bot's Think down with it (the
    -- error handler is broken, so it would be silent -- AGENTS.md).
    local X, _, bot = world(true, false, { [BLAST] = 95 })
    assert(bot:GetAbilityByName(REINCARN) ~= nil, 'the frame does carry the handle')
    assert(X.GetRoshanManaFloor(95) == 95,
        'with the mock answering 0 for an unanchored GetManaCost the floor is the '
        .. 'blast price; got ' .. tostring(X.GetRoshanManaFloor(95)))
end

-- ---------------------------------------------------------------- section 2 --
-- The real frames.

tests['section 2: the shipped 600 admits 0 of 34 real Wraith King frames'] = function()
    local tRows = wk_frames()
    assert(#tRows == 34, 'the archive carried 34 Wraith King hero rows when this '
        .. 'was measured, now ' .. #tRows .. '. The counts below are of THAT '
        .. 'population -- re-read them rather than lowering the bar.')

    local nShippedOk, nMaxPool = 0, 0
    for _, tRow in ipairs(tRows) do
        if (tRow.mp or 0) >= SHIPPED_FLOOR then nShippedOk = nShippedOk + 1 end
        if (tRow.max_mp or 0) > nMaxPool then nMaxPool = tRow.max_mp end
    end

    assert(nShippedOk == 0, nShippedOk .. ' frame(s) now clear the shipped floor')
    assert(nMaxPool == 459, 'the largest MAX pool on any Wraith King frame in the '
        .. 'archive was 459; got ' .. nMaxPool)
    assert(nMaxPool < SHIPPED_FLOOR, 'the whole point: 600 is above the entire '
        .. 'pool of every recorded frame, so the branch is mana-dead on this '
        .. 'corpus with a FULL bar -- independent of the mode predicate')
end

tests['section 2: the armed floor admits 22 of the 29 learned-Blast frames'] = function()
    local tRows = wk_frames()
    local nLearned, nArmedOk, nRefused = 0, 0, 0
    for _, tRow in ipairs(tRows) do
        if tRow.blast > 0 then
            nLearned = nLearned + 1
            if (tRow.mp or 0) >= armed_floor(tRow) then
                nArmedOk = nArmedOk + 1
            else
                nRefused = nRefused + 1
            end
        end
    end
    assert(nLearned == 29, '29 of the 34 frames had the Blast learned; got ' .. nLearned)
    assert(nArmedOk == 22, 'the armed floor admitted 22 of them; got ' .. nArmedOk)
    assert(nRefused == 7, 'and refused 7; got ' .. nRefused)
end

tests['section 2: every armed refusal is the reincarnation reserve doing its job'] = function()
    -- The asymmetry that shows the armed leg is a RESERVE, not a hole: on every
    -- frame it refuses, the frame could pay for the blast and could not pay for
    -- the blast PLUS the reincarnation behind it.
    local tRows = wk_frames()
    local nChecked = 0
    for _, tRow in ipairs(tRows) do
        if tRow.blast > 0 and (tRow.mp or 0) < armed_floor(tRow) then
            nChecked = nChecked + 1
            local nCost = BLAST_MANA[tRow.blast]
            local nReserve = REINCARN_MANA[tRow.reincarn] or 0
            assert(nReserve > 0, tRow.file .. ' is refused with a ZERO reserve, '
                .. 'which would mean the frame cannot even pay for the blast -- '
                .. 'that is IsFullyCastable\'s job, not this floor\'s')
            assert((tRow.mp or 0) < nCost + nReserve, tRow.file)
        end
    end
    assert(nChecked == 7, 'expected 7 refusals to inspect, saw ' .. nChecked)
end

-- ---------------------------------------------------------------- section 3 --
-- The recorded KV, against the file that consumes it.

tests['section 3: the anchored costs are the ones the doc block quotes'] = function()
    local src = read_file(SRC)
    assert(src:find('95/110/125/140', 1, true),
        'the blast cost ladder is no longer quoted next to the lever')
    assert(src:find('220/110/0', 1, true),
        'the reincarnation cost ladder is no longer quoted next to the lever')
    -- The three armed floors the doc block states, recomputed here from the
    -- ladders rather than copied, so prose and arithmetic cannot drift.
    assert(BLAST_MANA[1] + REINCARN_MANA[1] == 315, 'rank 1/1')
    assert(BLAST_MANA[2] + REINCARN_MANA[1] == 330, 'rank 2/1')
    assert(BLAST_MANA[3] + REINCARN_MANA[2] == 235, 'rank 3/2')
    assert(BLAST_MANA[4] + REINCARN_MANA[2] == 250, 'rank 4/2')
    assert(BLAST_MANA[4] + REINCARN_MANA[3] == 140, 'rank 4/3 -- reincarnation free')
    for i = 1, 4 do
        assert(BLAST_MANA[i] + REINCARN_MANA[1] < SHIPPED_FLOOR,
            'the WORST armed floor is still below the shipped one at rank ' .. i)
    end
end

-- ---------------------------------------------------------------- section 4 --
-- What this test CANNOT see.  Pinned so nobody reads a fixture-driven zero as
-- evidence of an empty domain (the axeblink trap, which cost this stream a
-- candidate).

tests['section 4: no frame carries an active mode, so the branch cannot be driven'] = function()
    local _, _, bot = world(true, false, { [BLAST] = 140, [REINCARN] = 220 })
    assert(bot:GetActiveMode() == 0,
        'a fixture answered a real active mode; if that is now true the branch '
        .. 'can be driven end to end and this file should do so')
    assert(BOT_MODE_ROSHAN ~= nil and BOT_MODE_ROSHAN >= 1001,
        'every BOT_MODE_* constant resolves >= 1001, so 0 never equals one')
    assert(bot:GetActiveMode() ~= BOT_MODE_ROSHAN,
        'the branch guard is constant FALSE offline -- a HARNESS fact, not a '
        .. 'frequency. Size the domain with queue hero-10, never with a scan here')
end

tests['section 4: the mock answers 0 for GetManaCost on every handle'] = function()
    -- Why the costs in this file are recorded constants: a version that read them
    -- off the handles would silently price every spell at zero and call every
    -- frame affordable -- the same silent-zero shape as GH #162's absent KV key.
    local _, _, bot = world(true, false, nil)
    assert(bot:GetAbilityByName(BLAST):GetManaCost() == 0, BLAST)
    assert(bot:GetAbilityByName(REINCARN):GetManaCost() == 0, REINCARN)
end

-- ---------------------------------------------------------------- section 5 --
-- Ratchets: the shape of the change itself.

tests['section 5: the branch reads the helper, not a constant'] = function()
    local src = read_file(SRC)
    assert(src:find('bot:GetMana%(%) >= X%.GetRoshanManaFloor%( nManaCost %)'),
        'the Roshan branch no longer prices itself off X.GetRoshanManaFloor')
    assert(not src:find('bot:GetMana%(%) >= 600'),
        'a bare 600 mana comparison is back in the file')
    local from = src:find('function X%.GetRoshanManaFloor')
    assert(from, 'X.GetRoshanManaFloor is gone from ' .. SRC)
    local rest = src:sub(from)
    local body = rest:sub(1, rest:find('\nfunction X%.') or #rest)
    assert(body:find("J%.IsModeTurbo%(%) and J%.IsSoakCandidate%( 'wkrosh' %)"),
        'the helper is no longer turbo-only-and-gated. If `wkrosh` was PROMOTED, '
        .. 'this file has to be rewritten around the new default, not relaxed')
    assert(body:find('nRelative < nShipped'),
        'the one-directional guard is gone; the armed leg could now demand MORE '
        .. 'mana than the shipped leg')
end

tests['section 5: nothing else in X.ConsiderQ casts on Roshan'] = function()
    -- The DOWNSTREAM-DOMINATED / UPSTREAM-SIBLING rule-out, machine-checked: the
    -- only other branch that looks at neutral creeps excludes Roshan by name, and
    -- if that exclusion ever goes away this lever needs re-reading before it is
    -- armed.
    local src = read_file(SRC)
    local from = src:find('function X%.ConsiderQ%s*%(%s*%)')
    assert(from, 'X.ConsiderQ not found in ' .. SRC)
    local rest = src:sub(from)
    local body = rest:sub(1, rest:find('\nfunction X%.') or #rest)
    assert(body:find('not J%.IsRoshan%( targetCreep %)'),
        'the farming branch no longer excludes Roshan, so it is now a second '
        .. 'Roshan path and this lever is no longer the only one')
    local _, nRoshanTests = body:gsub('J%.IsRoshan%(', '')
    assert(nRoshanTests == 2, 'X.ConsiderQ names Roshan in exactly two places -- '
        .. 'the farming exclusion and this branch; found ' .. nRoshanTests)
end

tests['section 5: X.ShouldSaveMana still guards ConsiderQ upstream'] = function()
    -- The armed floor is that rule made unconditional inside a Roshan fight. If
    -- the upstream call ever goes away, the armed leg stops being "the same
    -- reserve, always on" and becomes the ONLY reserve -- a different claim.
    local src = read_file(SRC)
    local from = src:find('function X%.ConsiderQ%s*%(%s*%)')
    local rest = src:sub(from)
    local body = rest:sub(1, rest:find('\nfunction X%.') or #rest)
    assert(body:find('X%.ShouldSaveMana%( abilityQ %)'),
        'ConsiderQ no longer consults X.ShouldSaveMana')
    -- NOTE the parentheses: string.find returns (start, end), and src:sub(start,
    -- end) would hand back only the matched name -- a 25-character "file" that
    -- passes nothing.  Caught here by the assertion below firing on a source that
    -- was correct; a laxer test would have called it green.
    local nStart = src:find('function X%.ShouldSaveMana')
    local tail = src:sub(nStart)
    assert(tail:find('abilityR:GetCooldownTimeRemaining%(%) <= 3%.0'),
        'the 3.0s window in X.ShouldSaveMana is gone; the armed floor is written '
        .. 'as the permanent version of exactly that window')
    assert(tail:find('bot:GetMana%(%) %- nAbility:GetManaCost%(%) < abilityR:GetManaCost%(%)'),
        'X.ShouldSaveMana no longer reserves the reincarnation cost, which is the '
        .. 'rule the armed floor generalises')
end

return tests

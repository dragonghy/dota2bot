-- [hero] `lionrreach` -- X.ConsiderR commits Finger of Death to targets up to
-- 400 units OUTSIDE its cast range, and the gated narrowing that stops it.
--
-- ===========================================================================
-- §0  WHAT IS WRONG
-- ===========================================================================
--
-- bots/BotLib/hero_lion.lua X.ConsiderR draws two lists off the same radius
-- family and then uses THREE different reach conventions on them, in one
-- function, for one ability:
--
--     击杀 loop    nInBonusEnemyList (nCastRange + 400), NO distance test
--     打架 branch  J.IsInRange( botTarget, bot, nCastRange + 200 )
--     撤退 loop    nInRangeEnemyList (nCastRange, zero slack)
--
-- The loosest of the three sits on the branch with the LEAST situational
-- precondition.  打架 needs J.IsGoingOnSomeone, 团战/撤退 need J.IsInTeamFight /
-- J.IsRetreating; the 击杀 loop needs nothing at all and runs first, so it can
-- fire while Lion is laning, farming or walking home.  What it hands the engine
-- is `ActionQueue_UseAbilityOnEntity( abilityR, target )` on a unit outside
-- cast range -- and that order is a MOVE order first: Lion walks the gap.  On
-- the frame §2 uses, the gap is 345.8 units at 300 movement speed = ~1.15s of
-- walking toward an enemy hero.  X.SkillsComplement `return`s the moment R is
-- queued, so Q/W/E are not considered for as long as the desire holds.
--
-- The neighbouring lever already wrote this sentence about ITSELF.  The third
-- conjunct of X.lion_ShouldCashUltAtWeakest (`J.IsInRange( hTarget, hBot,
-- nCastRange )`) carries the note "without this term the armed leg could order
-- a cast on a target Lion must WALK 400 units toward, which turns 'cash the ult
-- before dying' into a dive.  This lever does not import that problem."  The
-- shipped 击杀 loop HAS that problem.  `lionrreach` is that same term applied
-- to the branch it was written about.
--
-- ===========================================================================
-- §0.1  THE READINGS (two real frames, lethality enumerated, nothing moved)
-- ===========================================================================
--
-- FRAME A -- tests/fixtures/f_260820_162821_lion_drain_lethal.lua, Lion the
-- subject, nCastRange 900, three castable enemies really there:
--
--     luna   702 hp @  353.1u   in range
--     cm     710 hp @  616.3u   in range
--     lina  1088 hp @ 1245.8u   IN THE BAND (345.8u beyond cast range)
--
--     lethal target | gate off (shipped)   | gate on (armed)
--     --------------+----------------------+-----------------------
--     nobody        | NO CAST              | NO CAST     (identical)
--     luna          | finger -> luna       | finger -> luna (identical)
--     cm            | finger -> cm         | finger -> cm   (identical)
--     lina          | finger -> lina       | NO CAST     <- the lever
--
-- Four of four: gate-off is shipped verbatim, armed differs on exactly the one
-- point where the target is unreachable, and where both fire the TARGET IS THE
-- SAME.  The lever can only remove casts, never move one.
--
-- FRAME B -- tests/fixtures/f_260820_043120_viper_defend_poked.lua (subject
-- viper; Lion loaded as the subject unit, which is what §1 does for every
-- frame).  Here `J.IsInTeamFight( bot, 600 )` is TRUE on the real frame, no
-- injection needed, and the roster is one castable enemy:
--
--     silencer 949 hp @ 1078.7u  IN THE BAND (178.7u beyond cast range)
--
-- So silencer is simultaneously the 击杀 loop's candidate AND the 团战 exit's
-- `npcWeakestEnemy`.  That makes this frame the proof that filtering the 击杀
-- loop ALONE would have moved the dive rather than removed it:
--
--     lethal target | gate off        | armed, both sites | armed, kill loop only
--     --------------+-----------------+-------------------+----------------------
--     silencer      | finger->silencer| NO CAST           | finger->silencer
--
-- The third column is not hypothetical: §3 shows it by calling the 团战 exit's
-- own predicate with the unfiltered shipped lethality answer, which is exactly
-- what that exit would have received.  It answers TRUE.  A one-site version of
-- this id would therefore have RESURRECTED the exit X.lion_ShouldCashUltAtWeakest
-- proves is dead as shipped, and fingered the same out-of-range target.
--
-- ===========================================================================
-- §0.2  REPRODUCE
-- ===========================================================================
--
--     lua5.1 tests/run_tests.lua lion_ult_reach
--     bash tools/agent/mutstand_lionrreach.sh
--     bash tools/agent/luacheck_gate.sh
--
-- ===========================================================================
-- §0.3  LIMITS -- load-bearing, quote these with any number above
-- ===========================================================================
--
-- 1. THE DOMAIN IS THIN AND §1 COUNTS IT.  Re-taken 2026-09-11 over both
--    corpus directories (141 frames): Lion is present and alive on 42; on 10 of
--    those a castable enemy sits in the band (outside nCastRange, inside
--    nCastRange + 400), 11 such enemies in all.  On 4 of those 10 the band
--    member is also the WEAKEST castable member of the bonus list, and those 4
--    are the archive frames that can show the 团战 leak at all:
--        f_260820_043120_viper_defend_poked      (silencer)  <- frame B, §3 drives it
--        f_megabundle_051728_slardar_idle        (zuus)
--        f_260909_215040_wk_blast_lane_67        (lich)      <- new 2026-09-11
--        f_260909_215040_wk_blast_lion_480       (crystal_maiden) <- new 2026-09-11
--    ⚠️ QUOTE THESE AS FLOORS, NOT AS THE CORPUS.  §1 asserts them as floors
--    (`>=`), because corpus growth may only make a domain count larger and an
--    `==` on a corpus-size quantity turns every other group's staged frame into
--    a red in this file.  The previous take (27 / 5 / 5 / 2, 2026-08-30) was
--    written as `==` and did exactly that; §1 carries the full note.
--    ⚠️ A first draft of this limit said 24 live frames and 1 leak frame: that
--    scan read tests/fixtures only, and the assert in §1 -- not a re-read -- is
--    what caught the missing tests/frames directory.
-- 2. WHAT §2/§3 INJECT, named so nobody quotes §0.1 as an archive reading:
--    Finger cooldown 0 + IsFullyCastable true on both frames (the corpus
--    answers false, which is the `X.ConsiderR` first line and would make every
--    drive vacuous), and on frame A the ability LEVEL 1 (the frame records
--    rank 0 -- the same absence family as GH #608).  Frame B's rank 1 is real.
--    Nothing else is injected: no health, no position, no modifier, no mode.
--    §4 asserts each injection was actually read before any reading is taken.
-- 3. GEOMETRY, ROSTER AND HEALTH ARE REAL AND UNTOUCHED on both frames.  §2
--    moves the LETHALITY ORACLE instead of anybody's health, which is what
--    makes it an enumeration of the whole cube rather than one sample of it.
--    The same technique, and the same reason, as tests/test_lion_ult_cash_weakest.lua.
-- 4. WHETHER THE REFUSED WALKS WERE WORTH TAKING IS NOT SETTLED HERE.  This
--    file settles the direction (strict subset, same target, never widens) and
--    that both commit sites are load-bearing.  The value question is a wave
--    reading: queue request hero-44.

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')

local SRC    = 'bots/BotLib/hero_lion.lua'
local CAND   = 'lionrreach'
local HELPER = 'lion_ShouldCommitUltKill'
local UNIT   = 'npc_dota_hero_lion'
local FINGER = 'lion_finger_of_death'

local FRAME_A = 'tests/fixtures/f_260820_162821_lion_drain_lethal.lua'
local FRAME_B = 'tests/fixtures/f_260820_043120_viper_defend_poked.lua'
local LEAK_FRAME_2 = 'tests/fixtures/f_megabundle_051728_slardar_idle.lua'

local FIXTURE_DIR = 'tests/fixtures'
local STAGED_DIR  = 'tests/frames'

-- The rosters this file names, re-asserted in §4 so a frame edit cannot slide
-- underneath these names.
local LUNA     = 'npc_dota_hero_luna'
local CM       = 'npc_dota_hero_crystal_maiden'
local LINA     = 'npc_dota_hero_lina'
local SILENCER = 'npc_dota_hero_silencer'

local CAST_RANGE = 900          -- abilityR:GetCastRange() on both frames
local BAND       = 400          -- the 击杀 loop's extra radius

local tests = {}

local function read_file(path)
    local fh = assert(io.open(path, 'r'), 'cannot open ' .. path)
    local body = fh:read('*a')
    fh:close()
    return body
end

--- Both corpus directories, enumerated -- never a hardcoded list.  An empty
--- enumerator and an empty corpus are the same integer; the assert is the only
--- thing that tells them apart.
local function corpus_paths()
    local out = {}
    for _, dir in ipairs({ FIXTURE_DIR, STAGED_DIR }) do
        local n = 0
        local p = assert(io.popen('ls ' .. dir .. ' 2>/dev/null'))
        for name in p:lines() do
            if name:match('^f_.*%.lua$') then
                out[#out + 1] = dir .. '/' .. name
                n = n + 1
            end
        end
        p:close()
        assert(n > 0, 'corpus directory ' .. dir .. ' yielded no f_*.lua frame')
    end
    table.sort(out)
    return out
end

local function consider_r_body(src)
    local from = src:find('function%s+X%.ConsiderR%s*%(')
    assert(from, 'X.ConsiderR is gone from ' .. SRC)
    local rest = src:sub(from)
    local to = rest:find('\nend\n')
    assert(to, 'X.ConsiderR has no closing end in ' .. SRC)
    return rest:sub(1, to)
end

--- Install `v` as the answer to `h:k()` and drop any lazily-cached method, the
--- same two steps rf.record_actions takes.  Setting only the spec entry leaves
--- an already-materialised method in place and the injection silently does not
--- take -- which reads exactly like a lever that does nothing.
local function inject(h, k, v)
    rawget(h, '__spec')[k] = v
    rawset(h, k, nil)
end

--- Drive the REAL X.SkillsComplement dispatch on a real frame, with the
--- candidate armed or not and with the lethality oracle answering true for at
--- most one named unit.  Returns the action log, J, bot and X.
local function drive(sFrame, bArmed, sLethal, nLevel)
    local J, bot = rf.load(sFrame, UNIT)
    J.IsSoakCandidate = function(id) return bArmed and id == CAND end

    local X = rf.load_hero('lion')
    local hR = bot:GetAbilityByName(FINGER)
    if nLevel ~= nil then inject(hR, 'GetLevel', nLevel) end
    inject(hR, 'GetCooldownTimeRemaining', 0)
    inject(hR, 'IsFullyCastable', true)

    -- THE ORACLE.  Moving this, rather than moving anybody's health, is what
    -- makes §2 an enumeration of the whole cube instead of one sample of it.
    J.WillMagicKillTarget = function(_, hTarget)
        return sLethal ~= nil and hTarget:GetUnitName() == sLethal
    end

    local log = rf.record_actions(bot)
    X.SkillsComplement()
    return log, J, bot, X
end

--- The finger target the dispatch actually ordered, or nil if it ordered none.
local function fingered(log)
    for _, a in ipairs(log) do
        if a.fn:find('UseAbilityOnEntity') then
            local h = a.args[2]
            if h ~= nil and h.GetUnitName ~= nil then return h:GetUnitName() end
        end
    end
    return nil
end

-- ---------------------------------------------------------------- section 1 --
-- The domain, counted over the whole corpus.  §0.3 limit 1's evidence.

--- ⚠️ THE NAME CARRIES NO CORPUS-SIZE NUMBER, DELIBERATELY.  It read "on 5 of
--- 27 Lion frames" until 2026-09-11, so the counts lived in three places (name,
--- §0.3, asserts) and the corpus growing put all three out of date at once
--- while only one of them could go red.  The counts live in the asserts.
tests['§1 the corpus puts a castable enemy in the band, and §3\'s frame is still in it'] = function()
    local nFiles, nLive = 0, 0
    local nWithBand, nBandEnemies, nWeakestOutOfRange = 0, 0, 0
    local tLeakFrames = {}
    for _, path in ipairs(corpus_paths()) do
        nFiles = nFiles + 1
        local ok, chunk = pcall(dofile, path)
        if ok and type(chunk) == 'table' then
            local present = false
            for _, u in ipairs(chunk.units or {}) do
                if u.name == UNIT and u.alive ~= false then present = true end
            end
            if present then
                nLive = nLive + 1
                local _, bot = rf.load(path, UNIT)
                local X = rf.load_hero('lion')
                local nBand, nWeakest, hWeakest, bWeakestFar = 0, nil, nil, false
                for _, e in ipairs(bot:GetNearbyHeroes(CAST_RANGE + BAND, true, BOT_MODE_NONE)) do
                    if X.CanCastAbilityROnTarget(e) then
                        local d = GetUnitToUnitDistance(bot, e)
                        if d > CAST_RANGE then nBand = nBand + 1 end
                        if nWeakest == nil or e:GetHealth() < nWeakest then
                            nWeakest, hWeakest, bWeakestFar = e:GetHealth(), e:GetUnitName(), d > CAST_RANGE
                        end
                    end
                end
                nBandEnemies = nBandEnemies + nBand
                if nBand > 0 then nWithBand = nWithBand + 1 end
                if bWeakestFar then
                    nWeakestOutOfRange = nWeakestOutOfRange + 1
                    tLeakFrames[#tLeakFrames + 1] = path .. ' (' .. tostring(hWeakest) .. ')'
                end
            end
        end
    end
    assert(nFiles >= 110, 'the corpus enumerator returned ' .. nFiles
        .. ' frames, expected >= 110 -- an empty ls and an empty corpus are the '
        .. 'same integer')
    -- ⭐ RE-ANCHORED 2026-09-11 (was `== 27` / `== 5 and == 5` / `== 2`, taken
    -- 2026-08-30).  The corpus grew and all three equalities went red at once
    -- -- which is the point worth writing down rather than the numbers: an `==`
    -- on a CORPUS-SIZE quantity makes every frame anyone else stages into a red
    -- in THIS file, hours later, for a reason that has nothing to do with the
    -- lever.  None of these three counts is this file's conclusion; the
    -- conclusion is "the band domain is not empty and §3's frame is still in
    -- it".  So each becomes a FLOOR at its freshly-measured value, and growth
    -- may only make them larger.  (Same cause and same repair as
    -- tests/test_wk_q_castrange_meter_domain.lua: re-anchor by writing the
    -- CAUSE, not by bumping the integer.)
    --
    -- What the re-take actually found, and it is the opposite of a regression:
    -- the lever's whole locally-checkable domain roughly DOUBLED.
    --     live Lion frames    27 -> 42
    --     band frames / band enemies   5 / 5  ->  10 / 11
    --     团战-leak frames     2 -> 4   (two NEW ones, both staged 2026-09-09:
    --         f_260909_215040_wk_blast_lane_67.lua   (npc_dota_hero_lich)
    --         f_260909_215040_wk_blast_lion_480.lua  (npc_dota_hero_crystal_maiden))
    -- queue.json:hero-44 carries that reading to the wave stage.
    assert(nLive >= 42, 'Lion is alive on only ' .. nLive .. ' corpus frames '
        .. '(floor 42) -- frames were REMOVED; re-take §0.3 limit 1 rather than '
        .. 'quoting it')
    assert(nWithBand >= 10 and nBandEnemies >= 11,
        'the band domain SHRANK: ' .. nWithBand .. ' frames / ' .. nBandEnemies
        .. ' enemies, floor 10 / 11.  Re-take §0.3 limit 1.')
    -- This one IS the conclusion: without a band frame the lever has no local
    -- domain at all, so it gets its own assert and its own sentence.
    assert(nWithBand >= 1, 'no corpus frame puts a castable enemy in the '
        .. '(nCastRange, nCastRange + BAND] band -- the lever has no local '
        .. 'domain left and §2/§3 are reading a shape the archive no longer has')
    assert(nWeakestOutOfRange >= 4, 'the 团战-leak domain SHRANK to '
        .. nWeakestOutOfRange .. ' frames (floor 4): '
        .. table.concat(tLeakFrames, ', ')
        .. '.  Those are the archive frames that can show that leak.')
    -- MEMBERSHIP, not position.  The old form pinned tLeakFrames[1]/[2], and an
    -- index into a corpus-sorted list is a claim about every OTHER frame's
    -- name, which is not a claim this file makes.  §3 drives FRAME_B; the
    -- second named frame is what keeps the count honest about the rest.
    local tLeakSet = {}
    for _, s in ipairs(tLeakFrames) do tLeakSet[s] = true end
    assert(tLeakSet[FRAME_B .. ' (' .. SILENCER .. ')'],
        'the frame §3 drives left the leak set: expected ' .. FRAME_B .. ' ('
        .. SILENCER .. '), set is ' .. table.concat(tLeakFrames, ', '))
    assert(tLeakSet[LEAK_FRAME_2 .. ' (npc_dota_hero_zuus)'],
        'the second named leak frame left the set: expected ' .. LEAK_FRAME_2
        .. ' (npc_dota_hero_zuus), set is ' .. table.concat(tLeakFrames, ', '))
end

-- ---------------------------------------------------------------- section 2 --
-- Frame A: the whole lethality cube, both legs.

tests['§2 frame A: gate off fingers whoever is lethal, band member included'] = function()
    for _, sLethal in ipairs({ LUNA, CM, LINA }) do
        local got = fingered(drive(FRAME_A, false, sLethal, 1))
        assert(got == sLethal, 'gate off did not finger the lethal ' .. sLethal
            .. ' (got ' .. tostring(got) .. ') -- §0.1 frame A is stale')
    end
    local none = fingered(drive(FRAME_A, false, nil, 1))
    assert(none == nil, 'gate off fingered ' .. tostring(none)
        .. ' with nobody lethal; some other exit now fires and §2 proves nothing')
end

tests['§2 frame A: armed is a strict subset and never moves a target'] = function()
    local nDiff = 0
    for _, sLethal in ipairs({ LUNA, CM, LINA, false }) do
        local s = sLethal or nil
        local shipped = fingered(drive(FRAME_A, false, s, 1))
        local armed   = fingered(drive(FRAME_A, true,  s, 1))
        if armed ~= shipped then
            nDiff = nDiff + 1
            assert(shipped == LINA and armed == nil,
                'armed differs on the lethal-' .. tostring(s) .. ' point as '
                .. tostring(shipped) .. ' -> ' .. tostring(armed)
                .. '; the only legal difference is dropping the out-of-range LINA cast')
        end
        assert(armed == nil or armed == shipped, 'arming MOVED the target on the '
            .. 'lethal-' .. tostring(s) .. ' point: ' .. tostring(shipped) .. ' -> '
            .. tostring(armed) .. '.  This lever may only REMOVE casts.')
    end
    assert(nDiff == 1, 'the armed leg differs on ' .. nDiff .. ' of the 4 cube '
        .. 'points, expected exactly 1 (the band member LINA)')
end

-- ---------------------------------------------------------------- section 3 --
-- Frame B: the 团战 leak, and why the second call site is load-bearing.

tests['§3 frame B: the block really opens and the weakest is out of range'] = function()
    local _, J, bot, X = drive(FRAME_B, false, nil, nil)
    assert(J.IsInTeamFight(bot, 600) == true,
        'J.IsInTeamFight(bot,600) is no longer true on frame B -- the 团战 block '
        .. 'no longer opens unaided and §3 would be measuring nothing')
    local tBonus = bot:GetNearbyHeroes(CAST_RANGE + BAND, true, BOT_MODE_NONE)
    local nWeakest, hWeakest = nil, nil
    for _, e in ipairs(tBonus) do
        if X.CanCastAbilityROnTarget(e) and (nWeakest == nil or e:GetHealth() < nWeakest) then
            nWeakest, hWeakest = e:GetHealth(), e
        end
    end
    assert(hWeakest ~= nil and hWeakest:GetUnitName() == SILENCER,
        'the weakest castable member of the bonus list on frame B is '
        .. tostring(hWeakest and hWeakest:GetUnitName()) .. ', was ' .. SILENCER)
    local d = GetUnitToUnitDistance(bot, hWeakest)
    assert(d > CAST_RANGE and d <= CAST_RANGE + BAND, SILENCER .. ' is at '
        .. string.format('%.1f', d) .. 'u, which is no longer inside the band '
        .. '(' .. CAST_RANGE .. ', ' .. (CAST_RANGE + BAND) .. ']')
    -- The one-site counterfactual, called rather than argued: hand the 团战
    -- exit's own predicate the UNFILTERED shipped lethality answer -- exactly
    -- what it would receive if only the 击杀 loop routed through the helper.
    assert(X.lion_ShouldCashUltAtWeakest(bot, hWeakest, CAST_RANGE,
            bot:GetHealth() / bot:GetMaxHealth(), true) == true,
        'the 团战 exit no longer fires on a true shipped lethality answer, so '
        .. 'the leak §0.1 frame B describes cannot be demonstrated here')
end

tests['§3 frame B: armed shuts BOTH doors on the out-of-range weakest'] = function()
    local shipped = fingered(drive(FRAME_B, false, SILENCER, nil))
    assert(shipped == SILENCER, 'gate off did not finger the lethal ' .. SILENCER
        .. ' (got ' .. tostring(shipped) .. ') -- §0.1 frame B is stale')
    local armed = fingered(drive(FRAME_B, true, SILENCER, nil))
    assert(armed == nil, 'armed still fingered ' .. tostring(armed)
        .. ' at ' .. string.format('%.1f', 1078.7) .. 'u.  Either the 击杀 loop '
        .. 'or the 团战 exit is not routed through X.' .. HELPER .. '.')
    local sNobody = fingered(drive(FRAME_B, false, nil, nil))
    local aNobody = fingered(drive(FRAME_B, true, nil, nil))
    assert(sNobody == nil and aNobody == nil,
        'with nobody lethal frame B now casts (' .. tostring(sNobody) .. ' / '
        .. tostring(aNobody) .. '); §3 would then not be about this lever')
end

-- ---------------------------------------------------------------- section 4 --
-- The injections took, and the frames still say what §0.1 says they say.

tests['§4 the injections were really read, and the rosters are the named ones'] = function()
    local _, _, botA, XA = drive(FRAME_A, false, nil, 1)
    local hA = botA:GetAbilityByName(FINGER)
    assert(hA:GetLevel() == 1 and hA:GetCooldownTimeRemaining() == 0
        and hA:IsFullyCastable() == true, 'the frame A Finger injections did not take')
    assert(botA:GetHealth() == 607 and botA:GetMaxHealth() == 736,
        'frame A subject health moved: ' .. botA:GetHealth() .. '/'
        .. botA:GetMaxHealth() .. ', was 607/736 -- nothing in this file injects it')
    local seen = {}
    for _, e in ipairs(botA:GetNearbyHeroes(CAST_RANGE + BAND, true, BOT_MODE_NONE)) do
        seen[e:GetUnitName()] = GetUnitToUnitDistance(botA, e)
    end
    assert(seen[LUNA] ~= nil and seen[LUNA] <= CAST_RANGE, 'frame A: luna moved')
    assert(seen[CM] ~= nil and seen[CM] <= CAST_RANGE, 'frame A: crystal maiden moved')
    assert(seen[LINA] ~= nil and seen[LINA] > CAST_RANGE,
        'frame A: lina is no longer the band member (' .. tostring(seen[LINA]) .. 'u)')
    assert(XA:GetAbilityRSplashRadius() ~= nil, 'hero module did not load')

    local _, _, botB = drive(FRAME_B, false, nil, nil)
    local hB = botB:GetAbilityByName(FINGER)
    assert(hB:GetLevel() == 1, 'frame B Finger rank is ' .. hB:GetLevel()
        .. ', was a REAL 1 -- §0.3 limit 2 says this one is not injected')
    assert(hB:IsFullyCastable() == true, 'the frame B Finger injections did not take')
end

-- ---------------------------------------------------------------- section 5 --
-- The helper itself: gate-off equivalence, direction, and the guards.

tests['§5 gate off returns the shipped answer verbatim'] = function()
    local J, bot = rf.load(FRAME_A, UNIT)
    local X = rf.load_hero('lion')
    local hLina, hLuna = nil, nil
    for _, e in ipairs(bot:GetNearbyHeroes(CAST_RANGE + BAND, true, BOT_MODE_NONE)) do
        if e:GetUnitName() == LINA then hLina = e end
        if e:GetUnitName() == LUNA then hLuna = e end
    end
    assert(hLina ~= nil and hLuna ~= nil, 'frame A no longer carries lina and luna')

    J.IsSoakCandidate = function() return false end
    for _, h in ipairs({ hLina, hLuna }) do
        assert(X[HELPER](bot, h, CAST_RANGE, true) == true,
            'gate off must return the shipped answer (true)')
        assert(X[HELPER](bot, h, CAST_RANGE, false) == false,
            'gate off must return the shipped answer (false)')
    end
end

tests['§5 armed narrows only the out-of-range target, never widens'] = function()
    local J, bot = rf.load(FRAME_A, UNIT)
    local X = rf.load_hero('lion')
    local hLina, hLuna = nil, nil
    for _, e in ipairs(bot:GetNearbyHeroes(CAST_RANGE + BAND, true, BOT_MODE_NONE)) do
        if e:GetUnitName() == LINA then hLina = e end
        if e:GetUnitName() == LUNA then hLuna = e end
    end
    J.IsSoakCandidate = function(id) return id == CAND end

    assert(X[HELPER](bot, hLuna, CAST_RANGE, true) == true,
        'the lever refused a target at 353.1u, inside the 900 cast range')
    assert(X[HELPER](bot, hLina, CAST_RANGE, true) == false,
        'the lever accepted lina at 1245.8u, which is a 345.8-unit WALK order')
    -- NEVER WIDENS: a false shipped answer stays false whatever the geometry.
    assert(X[HELPER](bot, hLuna, CAST_RANGE, false) == false,
        'the lever turned a shipped false into a cast -- this id is a NARROWING')
    assert(X[HELPER](bot, hLina, CAST_RANGE, false) == false,
        'the lever turned a shipped false into a cast -- this id is a NARROWING')
    -- The boundary is nCastRange itself, and it is the caller's number: at a
    -- cast range that really does reach lina, the lever accepts her.
    assert(X[HELPER](bot, hLina, 1300, true) == true,
        'the reach test does not use the nCastRange it is handed')
    assert(X[HELPER](bot, hLuna, 300, true) == false,
        'the reach test does not use the nCastRange it is handed')
end

tests['§5 the guards: nil handles, a non-number range, and non-turbo'] = function()
    local J, bot = rf.load(FRAME_A, UNIT)
    local X = rf.load_hero('lion')
    local hLina = nil
    for _, e in ipairs(bot:GetNearbyHeroes(CAST_RANGE + BAND, true, BOT_MODE_NONE)) do
        if e:GetUnitName() == LINA then hLina = e end
    end
    J.IsSoakCandidate = function(id) return id == CAND end

    assert(X[HELPER](nil, hLina, CAST_RANGE, true) == true, 'nil bot must fall back to shipped')
    assert(X[HELPER](bot, nil, CAST_RANGE, true) == true, 'nil target must fall back to shipped')
    assert(X[HELPER](bot, hLina, nil, true) == true, 'a nil cast range must fall back to shipped')
    assert(X[HELPER](bot, hLina, '900', true) == true, 'a string cast range must fall back to shipped')

    -- Non-turbo, armed, is still shipped.  J.IsModeTurbo is overridden on the
    -- module table rather than via GetGameMode: jmz_func.lua caches the answer
    -- in a module-local the first time anything asks and `require` keeps that
    -- module alive for the whole process, so moving GetGameMode here would
    -- change nothing while LOOKING like it had.
    local fTurbo = J.IsModeTurbo
    J.IsModeTurbo = function() return false end
    assert(J.IsModeTurbo() == false, 'the non-turbo override did not take')
    assert(X[HELPER](bot, hLina, CAST_RANGE, true) == true,
        'the lever fired outside turbo')
    J.IsModeTurbo = fTurbo
end

-- ---------------------------------------------------------------- section 6 --
-- Tripwires: both commit sites stay routed through the helper.

tests['§6 both finger-commit sites in X.ConsiderR route through the helper'] = function()
    local body = consider_r_body(read_file(SRC))
    local n = 0
    for _ in body:gmatch('X%.' .. HELPER .. '%s*%(') do n = n + 1 end
    assert(n == 2, 'X.ConsiderR calls X.' .. HELPER .. ' ' .. n .. ' times, expected 2 '
        .. '(the 击杀 loop and the 团战 exit).  A site that stops routing through '
        .. 'the helper is a door this lever no longer closes -- see §0.1 frame B.')
    -- The kill loop must not carry a bare J.WillMagicKillTarget straight into a
    -- return: that is precisely the shipped shape this id replaces.
    assert(body:find('if%s+X%.' .. HELPER),
        'the 击杀 loop no longer tests X.' .. HELPER .. ' directly')
    local src = read_file(SRC)
    local nId = 0
    for _ in src:gmatch("IsSoakCandidate%(%s*'" .. CAND .. "'%s*%)") do nId = nId + 1 end
    assert(nId == 1, "'" .. CAND .. "' is read at " .. nId .. ' gate sites, expected 1 '
        .. '(inside X.' .. HELPER .. ' only)')
    assert(src:find('function%s+X%.' .. HELPER .. '%s*%('), 'X.' .. HELPER .. ' is gone from ' .. SRC)
end

return tests

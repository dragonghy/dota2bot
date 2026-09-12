-- [hero] `lionwreach` -- X.ConsiderW's 打断 (interrupt) firing point bids Hex on
-- a channelling hero up to 300 units OUTSIDE cast range, and the gated
-- narrowing that stops it.
--
-- ===========================================================================
-- §0  WHAT IS WRONG
-- ===========================================================================
--
-- bots/BotLib/hero_lion.lua X.ConsiderW draws ONE wide search ring
--
--     nInBonusEnemyList = J.GetNearbyHeroes( bot, nCastRange + 300, true, ... )
--
-- and hands it to TWO interrupt sub-branches that sit in the SAME `if` body,
-- eleven lines apart, for the same ability and the same purpose:
--
--     npcEnemy:IsChanneling()      -- NO distance term at all
--     npcEnemy:IsCastingAbility()  -- J.IsInRange( bot, npcEnemy, nCastRange + 50 )
--
-- Neither of the two terms the first one DOES carry is a distance term:
-- J.CanCastOnNonMagicImmune is CanBeSeen + immunity + illusion, and
-- J.CanCastOnTargetAdvanced is a linken / antimage / orb table.  §2 reads both
-- out of bots/FunLib/jmz_func.lua rather than asserting it in prose.
--
-- The third consumer of that ring agrees with the SIBLING, not with this one:
-- the 团战 most-dangerous search also spells `J.IsInRange( bot, ...,
-- nCastRange + 50 )`.  Two of three readers bound at +50.  Every other hero
-- firing point in the function is tighter still (攻击 +150; 保护自己, 撤退 and
-- roshan read nCastRange with zero slack).  §2 counts all of that off the
-- source.
--
-- What the engine is handed is `bot:ActionQueue_UseAbilityOnEntity( abilityW,
-- castWTarget )` (X.SkillsComplement, and `...OnLocation` under the scepter),
-- and on an out-of-range target that order is a MOVE order first.  This is
-- also the FIRST firing point in the function, so an out-of-range channeller
-- DISPLACES the 团战 Hex the same function would otherwise spend on the most
-- dangerous enemy inside cast range.
--
-- ===========================================================================
-- §0.1  THE READING (two real frames, nothing moved but the premise)
-- ===========================================================================
--
-- FRAME A -- tests/frames/f_260910_124853_lion_spike_slardar_1416.lua, Lion
-- the subject, his real Aether Lens on him (aetherRange 250) and Hex at rank 4,
-- so nCastRange is 900 and the ring is 1200:
--
--     slardar  879.8u   IN RANGE (inside 950 = nCastRange + 50)
--     zuus    1182.0u   IN THE BAND (232.0u beyond the sibling's bound)
--
--     channeller | gate off (shipped)   | gate on (armed)
--     -----------+----------------------+--------------------------
--     nobody     | no hex               | no hex          (identical)
--     slardar    | hex -> slardar       | hex -> slardar  (identical)
--     zuus       | hex -> ZUUS          | no hex          <- the lever
--     both       | hex -> (whoever      | hex -> SLARDAR  <- the displacement
--                |  the list yields)    |
--
-- FRAME B -- tests/fixtures/f_260820_182906_lion_drain_survived.lua, Lion the
-- subject, no lens on him, Hex rank 1 => nCastRange 575, ring 875:
--
--     luna           177.8u   IN RANGE
--     crystal_maiden 625.2u   IN THE BAND (50.2u beyond the bound)
--
-- Frame B is the displacement in its starkest form: shipped can walk away from
-- an enemy 177.8 units away to reach one 625.2 units away, and 50.2 units is
-- also the proof that the lever is a BAND filter and not a cast-range one --
-- crystal_maiden is inside `nCastRange + 300` and outside `nCastRange + 50`.
--
-- ===========================================================================
-- §0.2  REPRODUCE
-- ===========================================================================
--
--     lua5.1 tests/run_tests.lua lion_hex_interrupt_reach
--     bash tools/agent/mutstand_lionwreach.sh
--     bash tools/agent/luacheck_gate.sh
--
-- ⚠️ `lua5.1 tests/test_lion_hex_interrupt_reach.lua` exits 0 with NO output
-- and runs nothing (tests/run_tests.lua's own header, GH #200 note).  The
-- runner is the only supported entry point.
--
-- ===========================================================================
-- §0.3  LIMITS -- load-bearing, quote these with any number above
-- ===========================================================================
--
-- 1. ⭐ THE PREMISE IS INJECTED; THE BAND IS NOT.  `IsChanneling()` is not a
--    dumped field -- tools/batch_test/behavioral/axecallbkb_domain.py says so
--    and reconstructs it from MODIFIER_ADD/REMOVE intervals, which the fixture
--    loader does not do.  So the corpus can size the BAND but NOT the branch
--    premise, and the domain here is UNSIZED, not empty.  §1 counts the band on
--    real frames (10 frames / 11 castable band enemies over 42 live-Lion
--    frames, 4 of them with an in-range candidate to displace); §3/§4 inject
--    `IsChanneling` on ONE named enemy and leave geometry, roster, health,
--    ranks, items and modifiers untouched.  Size the premise on a wave:
--    iterations/queue.json `hero-68`.
-- 2. WHAT ELSE §3/§4 INJECT, named so nobody quotes §0.1 as an archive reading:
--    Hex `IsFullyCastable` true + cooldown 0 (the corpus answers false on both
--    frames, which is X.ConsiderW's first line and would make every drive
--    vacuous), and E/R/Q `IsFullyCastable` false so X.SkillsComplement reaches
--    the W dispatch at all (those three are considered first and return early).
--    §5 asserts every injection was actually read before any reading is taken.
-- 3. THE COUNTS IN §1 ARE FLOORS, NOT THE CORPUS.  An `==` on a corpus-size
--    quantity turns every other group's staged frame into a red in this file
--    (the lesson tests/test_lion_ult_reach.lua §1 wrote down after it happened).
--    Growth may only make them larger.
-- 4. WHETHER THE REFUSED WALKS WERE WORTH TAKING IS NOT SETTLED HERE.  A
--    channel interrupt is HIGH value -- which is why the bound is the sibling's
--    +50 rather than nCastRange, and why the cost of arming is registered in
--    the helper header rather than argued away.  This file settles the
--    DIRECTION (strict subset at this firing point; relocation only ever to a
--    strictly closer target) and that the band is not a fiction.

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')

local SRC    = 'bots/BotLib/hero_lion.lua'
local JMZ    = 'bots/FunLib/jmz_func.lua'
local CAND   = 'lionwreach'
local HELPER = 'lion_IsInterruptTargetInReach'
local UNIT   = 'npc_dota_hero_lion'
local HEX    = 'lion_voodoo'
local SPIKE  = 'lion_impale'
local DRAIN  = 'lion_mana_drain'
local FINGER = 'lion_finger_of_death'

local FRAME_A = 'tests/frames/f_260910_124853_lion_spike_slardar_1416.lua'
local FRAME_B = 'tests/fixtures/f_260820_182906_lion_drain_survived.lua'

local FIXTURE_DIR = 'tests/fixtures'
local STAGED_DIR  = 'tests/frames'

-- The rosters this file names, re-asserted in §5 so a frame edit cannot slide
-- underneath these names.
local SLARDAR = 'npc_dota_hero_slardar'
local ZUUS    = 'npc_dota_hero_zuus'
local LUNA    = 'npc_dota_hero_luna'
local CM      = 'npc_dota_hero_crystal_maiden'

local SLACK = 50    -- the sibling sub-branch's own bound, eleven lines below
local BAND  = 300   -- the shared search ring's extra radius

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
--- ⚠️ This is an io.popen directory walk, so this file is on the hand-read list
--- of tests/test_bots_walk_farm_only.py (GH #774: a new walk that is not
--- registered turns that census red for the NEXT group, hours later).
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

--- The cast range X.ConsiderW itself computes: `abilityW:GetCastRange() +
--- aetherRange`, with aetherRange rebuilt the way X.SkillsComplement rebuilds
--- it (J.IsItemAvailable -> J.GetAetherLensRangeBonus, the real helpers, not a
--- constant).  A census that read GetCastRange() alone would OVERSTATE the band
--- on every Lion carrying the lens -- the same 250-unit annulus that had
--- tests/test_lion_q_field_engagement.lua reading 670 for a branch that fires
--- at 920.
local function w_cast_range(J, bot)
    local hW = bot:GetAbilityByName(HEX)
    local nAether = 0
    local hLens = J.IsItemAvailable('item_aether_lens')
    if hLens ~= nil then nAether = J.GetAetherLensRangeBonus(hLens, 250) end
    return (hW and hW:GetCastRange() or 0) + nAether
end

--- Install `v` as the answer to `h:k()` and drop any lazily-cached method, the
--- same two steps rf.record_actions takes.  Setting only the spec entry leaves
--- an already-materialised method in place and the injection silently does not
--- take -- which reads exactly like a lever that does nothing.
local function inject(h, k, v)
    rawget(h, '__spec')[k] = v
    rawset(h, k, nil)
end

local function find_enemy(bot, sName)
    for _, e in ipairs(bot:GetNearbyHeroes(3000, true, BOT_MODE_NONE)) do
        if e:GetUnitName() == sName then return e end
    end
    return nil
end

--- Drive the REAL X.SkillsComplement dispatch on a real frame, with the
--- candidate armed or not and with `IsChanneling` true on the named enemies
--- and nobody else.  Returns the action log plus the handles it touched.
local function drive(sFrame, bArmed, tChannellers, bNonTurbo)
    local J, bot = rf.load(sFrame, UNIT)
    J.IsSoakCandidate = function(id) return bArmed and id == CAND end
    J.IsModeTurbo = function() return not bNonTurbo end

    local X = rf.load_hero('lion')

    -- E / R / Q are considered before W and return early on their own first
    -- line; shut them so the dispatch reaches the W branch at all.
    local tShut = {}
    for _, s in ipairs({ DRAIN, FINGER, SPIKE }) do
        local h = bot:GetAbilityByName(s)
        if h ~= nil then inject(h, 'IsFullyCastable', false) end
        tShut[s] = h
    end

    local hW = bot:GetAbilityByName(HEX)
    inject(hW, 'GetCooldownTimeRemaining', 0)
    inject(hW, 'IsFullyCastable', true)

    local tSeen = {}
    for _, sName in ipairs(tChannellers) do
        local h = assert(find_enemy(bot, sName), sName .. ' is not on ' .. sFrame)
        inject(h, 'IsChanneling', true)
        tSeen[sName] = h
    end

    local log = rf.record_actions(bot)
    X.SkillsComplement()
    return log, J, bot, X, hW, tSeen, tShut
end

--- The hex target the dispatch actually ordered, or nil if it ordered none.
local function hexed(log)
    for _, a in ipairs(log) do
        if a.fn:find('UseAbilityOnEntity') then
            local h = a.args[2]
            if h ~= nil and h.GetUnitName ~= nil then return h:GetUnitName() end
        end
    end
    return nil
end

-- ---------------------------------------------------------------- section 1 --
-- The band, counted over the whole corpus.  §0.3 limit 1's evidence.

--- ⚠️ THE NAME CARRIES NO CORPUS-SIZE NUMBER, deliberately: the counts live in
--- the asserts, so the corpus growing can put exactly one thing out of date.
tests['§1 the corpus really puts castable enemies in the band, and both named frames are in it'] = function()
    local nFiles, nLive, nBandFrames, nBandEnemies, nDisplace = 0, 0, 0, 0, 0
    local tBand = {}
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
                local J, bot = rf.load(path, UNIT)
                local cr = w_cast_range(J, bot)
                local nB, nNear = 0, 0
                for _, e in ipairs(bot:GetNearbyHeroes(cr + BAND, true, BOT_MODE_NONE)) do
                    -- The branch's own three terms, minus the premise §0.3
                    -- limit 1 says the corpus cannot answer.
                    if J.IsValidHero(e) and J.CanCastOnTargetAdvanced(e)
                        and J.CanCastOnNonMagicImmune(e) then
                        if GetUnitToUnitDistance(bot, e) > cr + SLACK then
                            nB = nB + 1
                            tBand[path .. ' (' .. e:GetUnitName() .. ')'] = true
                        else
                            nNear = nNear + 1
                        end
                    end
                end
                nBandEnemies = nBandEnemies + nB
                if nB > 0 then nBandFrames = nBandFrames + 1 end
                if nB > 0 and nNear > 0 then nDisplace = nDisplace + 1 end
            end
        end
    end
    assert(nFiles >= 110, 'the corpus enumerator returned ' .. nFiles
        .. ' frames, expected >= 110 -- an empty ls and an empty corpus are the '
        .. 'same integer')
    assert(nLive >= 42, 'Lion is alive on only ' .. nLive .. ' corpus frames '
        .. '(floor 42) -- frames were REMOVED; re-take §0.3 limit 1 rather than '
        .. 'quoting it')
    -- Measured 2026-09-12: 10 band frames / 11 band enemies / 4 displacement
    -- frames over 42 live-Lion frames.  FLOORS (§0.3 limit 3), not the corpus.
    assert(nBandFrames >= 10 and nBandEnemies >= 11,
        'the band domain SHRANK: ' .. nBandFrames .. ' frames / ' .. nBandEnemies
        .. ' enemies, floor 10 / 11.  Re-take §0.3 limit 1.')
    -- This one IS the conclusion: with no band frame the lever has no local
    -- domain at all and §3/§4 are reading a shape the archive no longer has.
    assert(nBandFrames >= 1, 'no corpus frame puts a castable enemy in the '
        .. '(nCastRange + 50, nCastRange + 300] band')
    -- And this one is the DISPLACEMENT claim, which is the half of §0 that a
    -- bare band count cannot support.
    assert(nDisplace >= 4, 'the displacement domain SHRANK to ' .. nDisplace
        .. ' frames (floor 4) -- those are the frames where a band member can '
        .. 'take the bid away from an in-range candidate')
    assert(tBand[FRAME_A .. ' (' .. ZUUS .. ')'],
        'frame A left the band set: expected ' .. FRAME_A .. ' (' .. ZUUS .. ')')
    assert(tBand[FRAME_B .. ' (' .. CM .. ')'],
        'frame B left the band set: expected ' .. FRAME_B .. ' (' .. CM .. ')')
end

-- ---------------------------------------------------------------- section 2 --
-- The SOURCE shape: the asymmetry, the third consumer, and the fact that
-- neither surviving term is a distance term.  Read, not asserted in prose.

--- X.ConsiderW's body with EVERY comment line removed.  Counting shapes over a
--- body that still has comments in it counts this file's own prose: the
--- `nCastRange + 50` census below read 3 instead of 2 the first time it ran,
--- and the third hit was the note the fix itself left at the call site.  A
--- shape census that a comment can satisfy is not a census.
local function consider_w_body(src)
    local from = src:find('function%s+X%.ConsiderW%s*%(')
    assert(from, 'X.ConsiderW is gone from ' .. SRC)
    local rest = src:sub(from)
    local to = rest:find('\nend\n')
    assert(to, 'X.ConsiderW has no closing end in ' .. SRC)
    local body = rest:sub(1, to)
    local out = {}
    for line in (body .. '\n'):gmatch('([^\n]*)\n') do
        if not line:match('^%s*%-%-') then out[#out + 1] = line end
    end
    return table.concat(out, '\n')
end

tests['§2 the interrupt point is the ONE +300-ring reader with no reach term of its own'] = function()
    local body = consider_w_body(read_file(SRC))
    -- The shared ring, spelled off the source.
    assert(body:find('nInBonusEnemyList%s*=%s*J%.GetNearbyHeroes%(%s*bot%s*,%s*nCastRange%s*%+%s*'
        .. BAND), 'the +' .. BAND .. ' search ring is no longer how nInBonusEnemyList is built')
    -- Its three readers, and what each of them bounds with.
    local nReaders = 0
    for _ in body:gmatch('nInBonusEnemyList') do nReaders = nReaders + 1 end
    assert(nReaders == 4, 'nInBonusEnemyList is mentioned ' .. nReaders
        .. ' times in X.ConsiderW (expected 4: one definition + three readers) '
        .. '-- a new reader needs its own reach decision, so this count is a tripwire')
    local nSlack = 0
    for _ in body:gmatch('J%.IsInRange%(%s*bot%s*,%s*npc%w+%s*,%s*nCastRange%s*%+%s*' .. SLACK) do
        nSlack = nSlack + 1
    end
    assert(nSlack == 2, 'expected exactly 2 firing points bounding at nCastRange + '
        .. SLACK .. ' (the IsCastingAbility sibling and the 团战 most-dangerous '
        .. 'exit), found ' .. nSlack)
    -- The 攻击 exit's looser bound is DELIBERATELY LEFT ALONE; pinned so a
    -- later round cannot read this file as having fixed it.
    assert(body:find('J%.IsInRange%(%s*bot%s*,%s*botTarget%s*,%s*nCastRange%s*%+%s*150'),
        'the 攻击 exit no longer bounds at nCastRange + 150 -- this lever '
        .. 'deliberately does not touch it, so a change there is somebody else\'s id')
    -- And neither surviving term on the interrupt point is a distance term.
    -- Read out of jmz_func rather than claimed.
    local jmz = read_file(JMZ)
    local from = jmz:find('function%s+J%.CanCastOnNonMagicImmune%s*%(')
    assert(from, 'J.CanCastOnNonMagicImmune is gone from ' .. JMZ)
    local nmi = jmz:sub(from, from + 400)
    assert(not nmi:find('GetUnitToUnitDistance') and not nmi:find('IsInRange'),
        'J.CanCastOnNonMagicImmune grew a distance term -- §0 has to be re-argued')
    from = jmz:find('function%s+J%.CanCastOnTargetAdvanced%s*%(')
    assert(from, 'J.CanCastOnTargetAdvanced is gone from ' .. JMZ)
    local adv = jmz:sub(from, from + 3000)
    assert(not adv:find('GetUnitToUnitDistance') and not adv:find('J%.IsInRange'),
        'J.CanCastOnTargetAdvanced grew a distance term -- §0 has to be re-argued')
end

-- ---------------------------------------------------------------- section 3 --
-- Frame A: the whole channeller cube on a real Lion frame, both legs.

tests['§3 frame A: gate off hexes whoever channels, band member included'] = function()
    for _, sWho in ipairs({ SLARDAR, ZUUS }) do
        local log = drive(FRAME_A, false, { sWho })
        assert(hexed(log) == sWho, 'gate off, with ' .. sWho .. ' channelling, '
            .. 'the dispatch ordered hex -> ' .. tostring(hexed(log)))
    end
    local log = drive(FRAME_A, false, {})
    assert(hexed(log) == nil, 'gate off with nobody channelling the dispatch '
        .. 'ordered hex -> ' .. tostring(hexed(log)) .. ' -- some OTHER branch '
        .. 'is firing and §3 is not reading the interrupt point at all')
end

tests['§3 frame A: armed refuses the band member and keeps the in-range one byte for byte'] = function()
    local log = drive(FRAME_A, true, { SLARDAR })
    assert(hexed(log) == SLARDAR, 'armed moved the IN-RANGE interrupt: hex -> '
        .. tostring(hexed(log)) .. ' -- the lever must be a no-op inside the bound')

    log = drive(FRAME_A, true, { ZUUS })
    assert(hexed(log) == nil, 'armed still ordered hex -> ' .. tostring(hexed(log))
        .. ' on a band member 232.0u beyond the sibling\'s own bound')

    -- The displacement, in the one shape that proves it is a SWAP and not just
    -- a withholding: both channel, shipped may take either, armed can only take
    -- the reachable one.
    log = drive(FRAME_A, true, { SLARDAR, ZUUS })
    assert(hexed(log) == SLARDAR, 'with both channelling, armed ordered hex -> '
        .. tostring(hexed(log)) .. ' (expected the in-range ' .. SLARDAR .. ')')
end

tests['§3 frame A: the geometry the readings rest on is real and untouched'] = function()
    local J, bot = rf.load(FRAME_A, UNIT)
    local cr = w_cast_range(J, bot)
    assert(cr == 900, 'frame A nCastRange is ' .. cr .. ', expected 900 '
        .. '(Hex rank 4 at 650 + the real Aether Lens 250)')
    local dS = GetUnitToUnitDistance(bot, assert(find_enemy(bot, SLARDAR)))
    local dZ = GetUnitToUnitDistance(bot, assert(find_enemy(bot, ZUUS)))
    assert(dS <= cr + SLACK, SLARDAR .. ' is at ' .. dS .. 'u, no longer inside '
        .. (cr + SLACK))
    assert(dZ > cr + SLACK and dZ <= cr + BAND, ZUUS .. ' is at ' .. dZ
        .. 'u, no longer in the (' .. (cr + SLACK) .. ', ' .. (cr + BAND) .. '] band')
end

-- ---------------------------------------------------------------- section 4 --
-- Frame B: a second frame, a second Hex rank, no lens -- and the starkest
-- displacement in the corpus (177.8u vs 625.2u).

tests['§4 frame B: same three answers on a different rank, a different roster and no lens'] = function()
    local J, bot = rf.load(FRAME_B, UNIT)
    local cr = w_cast_range(J, bot)
    assert(cr == 575, 'frame B nCastRange is ' .. cr .. ', expected 575 '
        .. '(Hex rank 1, no Aether Lens) -- the frames are supposed to differ here')
    local dL = GetUnitToUnitDistance(bot, assert(find_enemy(bot, LUNA)))
    local dC = GetUnitToUnitDistance(bot, assert(find_enemy(bot, CM)))
    assert(dL <= cr + SLACK and dC > cr + SLACK and dC <= cr + BAND,
        'frame B geometry moved: ' .. LUNA .. ' ' .. dL .. 'u, ' .. CM .. ' ' .. dC .. 'u')

    assert(hexed(drive(FRAME_B, false, { CM })) == CM,
        'gate off no longer hexes the band member on frame B')
    assert(hexed(drive(FRAME_B, true, { CM })) == nil,
        'armed still hexes the band member on frame B')
    assert(hexed(drive(FRAME_B, true, { LUNA })) == LUNA,
        'armed moved the in-range interrupt on frame B')
    assert(hexed(drive(FRAME_B, true, { LUNA, CM })) == LUNA,
        'with both channelling on frame B, armed did not keep the 177.8u candidate')
end

-- ---------------------------------------------------------------- section 5 --
-- The gate identity, the injections, and what is deliberately left alone.

tests['§5 gate off is byte-for-byte shipped, and the gate names no other id'] = function()
    local src = read_file(SRC)
    local from = src:find('function%s+X%.' .. HELPER .. '%s*%(')
    assert(from, HELPER .. ' is gone from ' .. SRC)
    local helper = src:sub(from, from + 400)
    local to = helper:find('\nend')
    helper = helper:sub(1, to)
    assert(helper:find("J%.IsModeTurbo%(%)%s*and%s*J%.IsSoakCandidate%(%s*'" .. CAND .. "'%s*%)"),
        'the gate is no longer `turbo and this candidate`')
    assert(helper:find('then%s+return%s+true%s+end'),
        'gate off no longer returns true -- gate-off equivalence is the whole '
        .. 'shape of this id')
    -- pullcad: a gate that names a SECOND id freezes FALSE the day that id is
    -- promoted, and check_armed_wiring.py still calls the site WIRED.
    local nIds = 0
    for _ in helper:gmatch('IsSoakCandidate') do nIds = nIds + 1 end
    assert(nIds == 1, HELPER .. ' names ' .. nIds .. ' soak candidates; exactly '
        .. 'one is allowed (the pullcad trap)')
    assert(helper:find('X%.nWInterruptReachSlack'),
        'the bound is no longer the named constant copied off the sibling')
    assert(src:find('X%.nWInterruptReachSlack%s*=%s*' .. SLACK),
        'X.nWInterruptReachSlack is no longer ' .. SLACK
        .. ' -- it is the sibling sub-branch\'s own bound, not an invented number')
    -- Exactly one call site.
    local nSites = 0
    for _ in src:gmatch('X%.' .. HELPER .. '%(') do nSites = nSites + 1 end
    assert(nSites == 2, HELPER .. ' appears ' .. nSites .. ' times (expected 2: '
        .. 'the definition and ONE call site)')
end

tests['§5 outside Turbo the armed leg answers the shipped decision, on both frames'] = function()
    -- The id is turbo-only; a Lion in a normal-mode game must see the shipped
    -- branch byte for byte even with the candidate armed.
    for _, t in ipairs({ { FRAME_A, ZUUS }, { FRAME_B, CM } }) do
        local sFrame, sBand = t[1], t[2]
        local got = hexed(drive(sFrame, true, { sBand }, true))
        assert(got == sBand, 'outside Turbo the armed helper must answer the '
            .. 'shipped `true`: ' .. sFrame .. ' ordered hex -> ' .. tostring(got)
            .. ' (expected ' .. sBand .. ')')
    end
end

tests['§5 the injections were actually read, on both frames'] = function()
    for _, sFrame in ipairs({ FRAME_A, FRAME_B }) do
        local _, _, _, _, hW, tSeen, tShut = drive(sFrame, false, {})
        assert(hW:IsFullyCastable() == true,
            sFrame .. ': the Hex IsFullyCastable injection did not take')
        assert(hW:GetCooldownTimeRemaining() == 0,
            sFrame .. ': the Hex cooldown injection did not take')
        for sName, h in pairs(tShut) do
            if h ~= nil then
                assert(h:IsFullyCastable() == false,
                    sFrame .. ': ' .. sName .. ' was not shut, so the dispatch may '
                    .. 'never have reached the W branch')
            end
        end
        assert(next(tSeen) == nil, 'this case injects no channeller on purpose')
    end
    -- And the channeller injection itself takes: same frame, same everything,
    -- only IsChanneling differs, and the action appears.
    assert(hexed(drive(FRAME_A, false, {})) == nil)
    assert(hexed(drive(FRAME_A, false, { ZUUS })) == ZUUS)
end

return tests

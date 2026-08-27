-- GH #137: the camp-tier ladder in J.Site.RefreshCamp is dead code -- gated
-- soak candidate 'campgrade' turns it into a real filter.
--
-- THE DEFECT (bots/FunLib/aba_site.lua, shipped default)
-- ------------------------------------------------------
-- The four-branch if/elseif chain reads like a ladder ("small camps at 1,
-- large at 8, ancient at 12, the enemy jungle at 15") and decides nothing:
--
--   * every branch bounds botLevel from ABOVE (<= 7, <= 11, <= 14), so a camp
--     a low-level bot is too weak for is not stopped by its tier -- it falls
--     THROUGH into the next, MORE permissive tier;
--   * and the chain ends in an unconditional `else` that appends the camp
--     anyway, so anything that survives the fall-through is added regardless.
--
-- Trace a level-5 bot and its own ancient camp: branch 1 refuses (ancient),
-- branch 2 refuses (ancient), branch 3 `botLevel <= 14 and not IsEnemyCamp`
-- ACCEPTS. The four conditions are equivalent to `allCampList = every camp`.
--
-- The cost, measured off 40 real games by the replay desk (GH #137 §2-§3):
-- 12/40 ancient-camp engagements happen at level <= 11 (6 of them at <= 9),
-- median HP loss in that bucket is 2.3x the overall median, and the
-- bearing-weight case is an 11-level Wraith King on starting items standing
-- in an ancient camp for 31.5s -- 100% -> 13.5% HP, 2261 damage dealt against
-- 2110 taken (an even trade is the signature of "he cannot break this camp"),
-- for 166 gold, with the nearest enemy hero 4573u away.
--
-- THE FIX (one lever): re-express each tier as the level it NEEDS, so nothing
-- falls through -- enemy camps >= 15, ancient >= 12, large not-weak, small and
-- medium always. Armed only, turbo only; the gate is at the single call site
-- in bots/mode_farm_generic.lua.
--
-- WHAT THIS FILE CAN AND CANNOT BUY LOCALLY -- read before trusting a number
-- ---------------------------------------------------------------------------
-- The subject half is REAL: every bot driven below is a real hero off a real
-- .dem frame, carrying the level the game gave it, and the level is the only
-- operand the fix's ancient tier reads.
--
-- The camp half is NOT in the corpus and is not pretended to be. Two world
-- facts, both asserted below rather than described:
--
--   (W1) GetNeutralSpawners() is `{}` on every fixture -- the dumper does not
--        carry the neutral spawner table -- so RefreshCamp end-to-end on any
--        fixture returns a list of length 0. Driving the shipped entry point
--        with no camps in the world would measure nothing at all.
--   (W2) GetAttackDamage() is 0 on every fixture hero (the dump carries
--        neither damage nor attack speed, tests/mock/replay_fixture.lua:473),
--        so the ladder's `<= 80` clause is vacuously TRUE for the whole
--        corpus. This is why the fix leaves that clause on the large/small
--        tier where the original put it and does NOT let it into the ancient
--        tier: the load-bearing clause has to be one the frames can drive.
--        (GH #137 suggestion 3 wants it on the ancient tier too. That is a
--        second lever and needs its own evidence -- not bundled here.)
--
-- So the camp table below is a DECLARED STAND-IN: the 4x2 cross product of
-- (type, side), which is exactly the judgment surface RefreshCamp reads off a
-- camp (camp.type, camp.team, camp.idx -- nothing else). It is not corpus
-- data and no count in this file is claimed to be.

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')

local tests = {}

-- Real frames, chosen because they straddle the threshold the fix introduces
-- with the SAME hero: skeleton_king at level 10 and at level 12.
--
-- [CORRECTION 2026-08-27, GH #248] This paragraph used to read "the frame
-- GH #137 §3 names, f_260823_002103_wk_ancient_camp_634, is not in the tree on
-- any ref ... level 11 for a Wraith King is therefore not purchasable". Both
-- halves are false at HEAD: the frame IS in the corpus and its skeleton_king
-- IS level 11, so every claim this file made about "the bearing-weight case"
-- was made on a STAND-IN while the case itself sat one directory away. The
-- correction is not a reworded comment. A prose claim about what the corpus
-- does NOT contain is an assertion about a set that only ever GROWS: it is
-- true when written, and it turns false without anybody touching this file,
-- with nothing going red -- the failure direction is a false GREEN, and the
-- shape it takes is a stand-in wearing the bearing case's name.
-- tests/corpus_scale.lua handles the opposite direction (growth turning a
-- COUNT equality falsely RED) and has no handle on this one. So the claim is
-- executable now: BEARING below is looked up, its level is asserted, and
-- tests/test_corpus_existence_claims.lua forbids the prose form repo-wide.
local WK_L10 = { 'tests/fixtures/f_260820_043124_axe_blink_flee_555.lua', 'npc_dota_hero_skeleton_king' }
local WK_L12 = { 'tests/fixtures/f_260820_162859_es_blink_flee_615.lua', 'npc_dota_hero_skeleton_king' }
local AXE_L11 = { 'tests/fixtures/f_050713_es_defend_1v3.lua', 'npc_dota_hero_axe' }
-- GH #137 §3's own bearing-weight frame: skeleton_king, level 11, standing in
-- an ancient camp (modifier_ancient_rock_golem_weakening, 11.0s elapsed at
-- t=634.1), 817/1307 HP on the way from 100% to 13.5%.
local WK_L11_BEARING = { 'tests/fixtures/f_260823_002103_wk_ancient_camp_634.lua', 'npc_dota_hero_skeleton_king' }

local function subject(spec)
    local J, _, heroes = rf.load(spec[1], spec[2])
    return J, heroes[spec[2]]
end

-- The declared stand-in (W1). Fields: exactly the three RefreshCamp reads.
local function camp_table(nOwnTeam)
    local nEnemyTeam = nOwnTeam == 2 and 3 or 2
    local camps, i = {}, 0
    for _, team in ipairs({ nOwnTeam, nEnemyTeam }) do
        for _, sType in ipairs({ 'small', 'medium', 'large', 'ancient' }) do
            i = i + 1
            camps['c' .. i] = { idx = i, type = sType, team = team,
                                location = Vector(100 * i, 100 * i, 0) }
        end
    end
    return camps, i
end

local function with_camps(nOwnTeam, fn)
    local camps, nTotal = camp_table(nOwnTeam)
    local prev = GetNeutralSpawners
    GetNeutralSpawners = function() return camps end
    local ok, err = pcall(fn, nTotal)
    GetNeutralSpawners = prev
    if not ok then error(err, 0) end
end

-- What came back, as a set of "<type>/<own|enemy>" labels.
local function labels(list, nOwnTeam)
    local out = {}
    for _, entry in ipairs(list) do
        local c = entry.cattr
        out[c.type .. '/' .. (c.team == nOwnTeam and 'own' or 'enemy')] = true
    end
    return out
end

local function refresh(J, bot, bStrict)
    local nOwnTeam = bot:GetTeam()
    local got
    with_camps(nOwnTeam, function()
        local list, n = J.Site.RefreshCamp(bot, bStrict)
        assert(n == #list, 'RefreshCamp second return must be the list length')
        got = labels(list, nOwnTeam)
        got.__n = n
    end)
    return got
end

--============================================================================
-- The two world facts this file rests on.
--============================================================================

tests['[world W1] the corpus carries no neutral spawners at all'] = function()
    local J, bot = subject(WK_L10)
    local camps = GetNeutralSpawners()
    assert(type(camps) == 'table' and next(camps) == nil,
        'GetNeutralSpawners() is no longer empty on a fixture -- if the dumper ' ..
        'started carrying the spawner table, this file should drive the real ' ..
        'one instead of the stand-in and every claim below gets stronger')
    local _, n = J.Site.RefreshCamp(bot)
    assert(n == 0, 'with no camps in the world the shipped entry point returns ' ..
        'an empty list -- that is why the camp table here is declared, not loaded')
end

tests['[world W2] every fixture hero reads attack damage 0'] = function()
    for _, spec in ipairs({ WK_L10, WK_L12, AXE_L11, WK_L11_BEARING }) do
        local _, bot = subject(spec)
        assert(bot:GetAttackDamage() == 0, string.format(
            '%s on %s reads attack damage %s; if the dump started carrying it, ' ..
            'the `<= 80` clause stops being vacuous and GH #137 suggestion 3 ' ..
            '(attack damage on the ancient tier) becomes locally testable',
            spec[2], spec[1], tostring(bot:GetAttackDamage())))
    end
end

--============================================================================
-- Today's defect, on real frames.
--============================================================================

tests["[today's defect] shipped default hands a level-10 Wraith King the ancient camps"] = function()
    local J, bot = subject(WK_L10)
    assert(bot:GetLevel() == 10, 'frame no longer carries level 10')
    local got = refresh(J, bot, false)
    assert(got.__n == 8, 'the shipped default admits every camp; got ' .. tostring(got.__n))
    assert(got['ancient/own'], 'level 10 got its own ancient camp (the defect)')
    assert(got['ancient/enemy'], 'level 10 got the ENEMY ancient camp too')
    assert(got['large/own'], 'level 10 got large camps despite attack damage 0')
end

tests["[today's defect] it is level-independent: level 12 gets exactly the same list"] = function()
    local J10, b10 = subject(WK_L10)
    local J12, b12 = subject(WK_L12)
    assert(b12:GetLevel() == 12, 'frame no longer carries level 12')
    local a, b = refresh(J10, b10, false), refresh(J12, b12, false)
    for k in pairs(a) do assert(b[k], 'level 12 lost ' .. tostring(k)) end
    for k in pairs(b) do assert(a[k], 'level 10 lost ' .. tostring(k)) end
    assert(a.__n == b.__n and a.__n == 8,
        'the four conditions decide nothing: both levels get all 8 camps')
end

--============================================================================
-- The fix.
--============================================================================

tests['[the fix] armed, the level-10 Wraith King loses the ancient camps'] = function()
    local J, bot = subject(WK_L10)
    local got = refresh(J, bot, true)
    assert(not got['ancient/own'], 'level 10 -- inside the issue\'s own <= 11 ' ..
        'bucket, though NOT the bearing-weight case, which is pinned below on ' ..
        'its own frame -- must not be handed an ancient camp')
    assert(not got['ancient/enemy'], 'and certainly not the enemy one')
    assert(not got['small/enemy'] and not got['medium/enemy'] and not got['large/enemy'],
        'the enemy jungle is a level-15 tier')
end

tests['[the fix does not starve the farm] small and medium camps survive at every real level'] = function()
    -- GH #137 §4 acceptance: the count must not collapse to 0. A bot with no
    -- camps at all would fall back to the "no camp found" path in
    -- mode_farm_generic (preferedCamp == nil), which is a behaviour change far
    -- wider than this lever.
    for _, spec in ipairs({ WK_L10, WK_L12, AXE_L11, WK_L11_BEARING }) do
        local J, bot = subject(spec)
        local got = refresh(J, bot, true)
        assert(got.__n >= 2, string.format('%s (level %d) armed got %d camps',
            spec[2], bot:GetLevel(), got.__n))
        assert(got['small/own'] and got['medium/own'],
            'own small/medium camps are the always-tier and must always be there')
    end
end

tests['[the fix does not overshoot] level 12 keeps its own ancient camp'] = function()
    -- The other half of GH #137 §4: the 28 engagements at level >= 12 are the
    -- ones the bots SHOULD be having. A fix that zeroed the whole census would
    -- be a regression dressed as a pass.
    local J, bot = subject(WK_L12)
    local got = refresh(J, bot, true)
    assert(got['ancient/own'], 'level 12 is the ancient tier and must keep it')
    assert(not got['ancient/enemy'], 'the enemy ancient camp is still a level-15 tier')
end

tests['[boundary] 11 refuses and 12 admits, both off real frames'] = function()
    for _, spec in ipairs({ AXE_L11, WK_L11_BEARING }) do
        local J11, b11 = subject(spec)
        assert(b11:GetLevel() == 11, spec[1] .. ' no longer carries level 11')
        assert(not refresh(J11, b11, true)['ancient/own'],
            spec[2] .. ' at level 11 is below the ancient tier')
    end

    local J12, b12 = subject(WK_L12)
    assert(refresh(J12, b12, true)['ancient/own'], 'level 12 is the ancient tier')
end

--============================================================================
-- The bearing-weight case itself, which this file used to argue from a
-- stand-in because a comment said the frame was not purchasable.
--============================================================================

tests["[bearing case] GH #137's own frame is in the corpus, and it is level 11"] = function()
    -- The executable form of the claim the header used to make in prose. A
    -- negative existence claim about a growing corpus cannot be a comment: it
    -- goes false on its own, silently, in the flattering direction.
    local f = io.open(WK_L11_BEARING[1], 'r')
    assert(f, 'the bearing-weight frame is gone from the corpus: ' .. WK_L11_BEARING[1] ..
        ' -- if it was deliberately dropped, say so with a red test, not a comment')
    f:close()
    local _, bot = subject(WK_L11_BEARING)
    assert(bot:GetLevel() == 11,
        'the bearing frame no longer carries level 11; got ' .. tostring(bot:GetLevel()))
    -- ...and it is genuinely an ancient-camp frame, not merely a level-11 WK:
    -- the debuff only the ancient rock golem camp applies is on him.
    local fx = assert(dofile(WK_L11_BEARING[1]))
    local bWeakening = false
    for _, u in ipairs(fx.units) do
        if u.name == WK_L11_BEARING[2] then
            for _, m in ipairs(u.modifiers or {}) do
                if m.name == 'modifier_ancient_rock_golem_weakening' then bWeakening = true end
            end
        end
    end
    assert(bWeakening, 'the subject carries no ancient-camp debuff -- this is not ' ..
        'the frame GH #137 measured, and the tests below would be arguing from a name')
end

tests['[bearing case] the defect and the fix, on the frame the issue measured'] = function()
    local J, bot = subject(WK_L11_BEARING)
    -- Today: the chain decides nothing, so the level-11 Wraith King is handed
    -- the very camp the replay shows him losing 86.5% of his HP inside.
    local shipped = refresh(J, bot, false)
    assert(shipped.__n == 8,
        'the shipped default admits every camp; got ' .. tostring(shipped.__n))
    assert(shipped['ancient/own'] and shipped['ancient/enemy'],
        'the defect, on the bearing frame: level 11 is handed the ancient camps')
    -- Armed: refused, at the exact level of the case, with the same hero, on
    -- the same frame. This is the assertion the stand-ins could only approximate.
    local armed = refresh(J, bot, true)
    assert(not armed['ancient/own'] and not armed['ancient/enemy'],
        'armed must refuse the ancient camp AT level 11 on this frame')
    assert(armed['small/own'] and armed['medium/own'],
        'and it must not starve him: the always-tier survives')
end

tests['[enemy tier] the enemy jungle opens at 15, measured on the real level ladder'] = function()
    -- Real frames on both sides of 15: the corpus carries 8 hero-slots at
    -- level >= 15 (levels 15, 16, 17, 19).
    local J14, b14 = subject({ 'tests/fixtures/f_260819_223607_sniper_rooted.lua', 'npc_dota_hero_nevermore' })
    assert(b14:GetLevel() == 14, 'frame no longer carries level 14')
    assert(not refresh(J14, b14, true)['ancient/enemy'], 'level 14 is below the enemy tier')

    local J19, b19 = subject({ 'tests/fixtures/f_260820_163429_es_blink_init_621.lua', 'npc_dota_hero_viper' })
    assert(b19:GetLevel() >= 15, 'frame no longer carries a level >= 15 hero')
    local got = refresh(J19, b19, true)
    assert(got['ancient/enemy'] and got['small/enemy'] and got['medium/enemy'],
        'level 15+ is the everything tier -- armed must not be stricter than ' ..
        'the shipped chain intends at the top of the ladder')
    -- ...except the LARGE tier, and this is (W2) biting, not a level rule:
    -- the fix keeps the attack-damage clause exactly where the shipped chain
    -- put it, and every fixture hero reads 0 damage, so `weak` is true even at
    -- level 19. In a real turbo game a level-19 hero is never under 80 attack
    -- damage, so this asymmetry (ancient admitted, large refused) cannot occur
    -- there -- but it is the sharpest statement of why the corpus cannot judge
    -- that clause, and of why GH #137 suggestion 3 is a separate lever.
    assert(not got['large/own'] and not got['large/enemy'], 'W2 no longer holds here')
    assert(got.__n == 6, 'level 15+ armed: all 8 camps minus the two large ones, got '
        .. tostring(got.__n))
end

--============================================================================
-- Off-candidate equivalence, and the caller that owns the gate.
--============================================================================

tests['[off-candidate equivalence] unarmed is the pre-fix chain, camp for camp'] = function()
    -- The pre-fix chain, transcribed from the shipped source, run beside the
    -- patched function on every real level in the corpus. If these ever
    -- disagree the candidate is not dark and must not ride a wave.
    local function pre_fix(camps, botLevel, atk, nOwnTeam)
        local out = {}
        for _, camp in pairs(camps) do
            local bEnemy, bAncient, bLarge =
                camp.team ~= nOwnTeam, camp.type == 'ancient', camp.type == 'large'
            if (botLevel <= 7 or atk <= 80) and not bEnemy and not bLarge and not bAncient then
                out[#out + 1] = camp.idx
            elseif botLevel <= 11 and not bEnemy and not bAncient then
                out[#out + 1] = camp.idx
            elseif botLevel <= 14 and not bEnemy then
                out[#out + 1] = camp.idx
            else
                out[#out + 1] = camp.idx
            end
        end
        table.sort(out)
        return out
    end

    for _, spec in ipairs({ WK_L10, WK_L12, AXE_L11, WK_L11_BEARING }) do
        local J, bot = subject(spec)
        local nOwnTeam = bot:GetTeam()
        with_camps(nOwnTeam, function()
            local want = pre_fix(GetNeutralSpawners(), bot:GetLevel(), bot:GetAttackDamage(), nOwnTeam)
            local list = J.Site.RefreshCamp(bot, false)
            local got = {}
            for _, e in ipairs(list) do got[#got + 1] = e.idx end
            table.sort(got)
            assert(#got == #want, string.format('%s: unarmed returned %d camps, pre-fix %d',
                spec[2], #got, #want))
            for i = 1, #want do
                assert(got[i] == want[i], 'unarmed diverged from the pre-fix chain at camp ' .. i)
            end
        end)
        -- and the nil call (no second argument at all) is the same thing
        with_camps(nOwnTeam, function(nTotal)
            local _, n = J.Site.RefreshCamp(bot)
            assert(n == nTotal, 'RefreshCamp(bot) with no flag must stay the all-camps default')
        end)
    end
end

local function read(path)
    local f = assert(io.open(path, 'r'))
    local s = f:read('*a')
    f:close()
    return s
end

-- Comment text is not code. This stream has now read its own header back as
-- source three times; the header above quotes every identifier below.
local function strip_comments(src)
    src = src:gsub('%-%-%[%[.-%]%]', ' ')
    return (src:gsub('%-%-[^\n]*', ' '))
end

tests['[the caller owns the gate] RefreshCamp is called turbo-only and candidate-only'] = function()
    local code = strip_comments(read('bots/mode_farm_generic.lua'))
    -- Up to the statement terminator, not to the first ')' -- the gate itself
    -- contains parentheses, and a lazy match would read only `bot, J.IsModeTurbo(`.
    local call = code:match('J%.Site%.RefreshCamp%s*(%b())')
    assert(call, 'the RefreshCamp call site moved or changed shape')
    assert(call:find('J%.IsModeTurbo%s*%(%s*%)'),
        'the strict ladder must be turbo-only; got: ' .. call)
    assert(call:find("J%.IsSoakCandidate%s*%(%s*'campgrade'%s*%)"),
        "the strict ladder must be gated on 'campgrade'; got: " .. call)
    local _, nCalls = code:gsub('J%.Site%.RefreshCamp%s*%(', '')
    assert(nCalls == 1, 'RefreshCamp gained a second call site (' .. nCalls ..
        ') -- a second one would need its own gate')
end

tests['[the lever is one lever] attack damage stays off the ancient tier'] = function()
    local code = strip_comments(read('bots/FunLib/aba_site.lua'))
    local body = code:match('IsCampAllowedForLevel%s*=%s*function.-\nend')
    assert(body, 'IsCampAllowedForLevel is gone or reshaped')
    local ancient = body:match('IsAncientCamp[^\n]*\n')
    assert(ancient and ancient:find('botLevel%s*<%s*12'), 'the ancient tier is no longer level 12')
    assert(not ancient:find('attackDamage'),
        'attack damage reached the ancient tier -- that is GH #137 suggestion 3, ' ..
        'a SECOND lever, and (W2) says the corpus cannot test it')
end

tests['[ts parity] the TypeScript source carries the same ladder'] = function()
    local ts = read('typescript/bots/FunLib/aba_site.ts')
    ts = ts:gsub('/%*.-%*/', ' '):gsub('//[^\n]*', ' ')
    assert(ts:find('IsCampAllowedForLevel'), 'the TS source was not kept in lockstep')
    assert(ts:find('bStrictLadder'), 'the TS RefreshCamp lost the strict-ladder parameter')
    assert(ts:find('botLevel < 12') and ts:find('botLevel < 15'),
        'the TS tiers drifted from the Lua ones')
end

--============================================================================
-- Domain: how much of the corpus sits under the threshold this fix adds.
--============================================================================

tests['[domain] most real hero-frames are below the ancient tier'] = function()
    -- Floors, not equalities (GH #106): adding a fixture must not turn this red.
    local p = assert(io.popen('ls tests/fixtures/*.lua'))
    local nSlots, nBelow, nAtOrAbove, nFiles = 0, 0, 0, 0
    for path in p:lines() do
        local ok, fx = pcall(dofile, path)
        if ok and type(fx) == 'table' and fx.units then
            nFiles = nFiles + 1
            for _, u in ipairs(fx.units) do
                if u.level then
                    nSlots = nSlots + 1
                    if u.level <= 11 then nBelow = nBelow + 1 else nAtOrAbove = nAtOrAbove + 1 end
                end
            end
        end
    end
    p:close()
    assert(nFiles >= 100 and nSlots >= 1000, string.format(
        'corpus shrank: %d files / %d hero-slots', nFiles, nSlots))
    assert(nBelow + nAtOrAbove == nSlots, 'the two buckets must close on the total')
    -- Measured 2026-08-23 on 103 fixtures / 1030 slots: 953 below (92.5%), 77 at
    -- or above. Both floors matter: the first says the fix has a domain, the
    -- second says there is still a population it must NOT touch.
    assert(nBelow >= 900, 'level <= 11 bucket collapsed: ' .. nBelow)
    assert(nAtOrAbove >= 70, 'level >= 12 bucket collapsed: ' .. nAtOrAbove ..
        ' -- the no-overshoot half of GH #137 §4 needs this population to exist')
end

return tests

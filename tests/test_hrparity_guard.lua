-- [GH: hrparity] The lane harass response decides "am I outnumbered" by
-- comparing two populations measured with two different rulers.
--
-- THE DEFECT. J.GetLaneHarassResponse counts harassers out to 1100u and
-- counts help out to 900u, then asks `#tValid > nOurs`. An enemy standing at
-- 1000u is therefore a member of the mob, while an ally standing at the
-- IDENTICAL distance is not on the field at all. The verdict that comes out of
-- that comparison is 'back' -- a 420u step toward the fountain, returned
-- unconditionally from the combat-response floor of the replacement laning
-- Think, above every last-hit and deny. The bot concedes the lane over a
-- population count that the shorter ruler biased.
--
-- WHY THIS IS A FIX AND NOT A NEW POLICY. Nothing in this helper states a
-- policy about how far away help still counts; there is no comment, no named
-- constant, no second threshold anywhere that says an ally at 1000u is too far
-- to matter while an enemy at 1000u is close enough to fear. There is one
-- comparison with two rulers, and the short one sits on the side that keeps the
-- bot in its lane. Armed, the ally count is read on the disc the enemy count
-- had already committed to. Section 1 asserts the two radii are EQUAL rather
-- than that the new one is 1100: symmetry is the property, 1100 is the value.
--
-- ⭐ THE NUMBERS (110 fixtures, 84 entered frames,
-- tests/_lanekill_domain_sweep.lua; the same walk that priced 'hrreach'):
--   * `hr_asym_enemy_band` 12 and `hr_asym_ally_band` 5 -- frames with an enemy
--     (resp. an ally) standing in the 900-1100 band where the two rulers
--     disagree about who is on the field.
--   * `hp_back_closes` 2, `hp_back_opens` 0, `hp_nil_moved` 0 -- armed, exactly
--     2 frames stop retreating, none starts, and the nil bucket never moves
--     (nil is decided above the parity test entirely).
--   * shipped 12 nil + 18 back + 54 fire = 84; armed 12 + 16 + 56 = 84. Both
--     drives close over the entered population, so no bucket is a silent
--     remainder.
--
-- ⭐⭐ THE 2 IS CROSS-CHECKED, NOT RESTATED. `hp_pred_flips` is arithmetic on
-- the raw populations (count both discs, redo the comparison); `hp_back_closes`
-- is what the shipped function actually did when driven with the id armed.
-- Different drives, different code paths, same 2, and section 4 asserts they
-- are equal. That check is here because the 'hrreach' round found the counting
-- identity alone could not tell "keys on the guard" from "keys on nothing"
-- (its M5 mutant kept `hr_closes == hr_fire - hr2_fire` true at 0 == 54-54).
--
-- ⭐⭐⭐ THIS DOMAIN IS NOT STUBBED, and that is asserted rather than assumed.
-- 'hrreach' next door measures mostly the loader, because no fixture carries
-- an attack_range field and GetAttackRange answers a constant 150 on 84/84
-- frames (GH #656). This guard reads hero POSITIONS, which every fixture
-- carries for real and which tests/mock/replay_fixture.lua filters by true
-- distance and vision. `hp_ally_disc_differs` 5 is the proof: the two ally
-- discs return different sets on 5 frames, so the loader is answering the
-- radius question rather than shrugging. Section 5 pins it.
--
-- ⛔ SAID BEFORE ANY WAVE, NOT AFTER (GH #622). ARMED ALONE, THIS ID HANDS ITS
-- 2 FRAMES STRAIGHT TO THE DEFECT NEXT DOOR. Both frames it un-retreats become
-- 'fire' on a target the subject cannot reach (`hp_opened_d_max_u` 882), and
-- the caller serves an out-of-reach attack order by WALKING -- which is exactly
-- what 'hrreach' exists to stop. With BOTH armed the same 2 frames end as nil
-- (`hpb_flip_ends_nil` 2): no retreat, no chase, the shipped last-hit body
-- runs. So the recommendation carried to the director is CO-ARM, not
-- arm-alone; section 7 measures the pair instead of arguing about it. This is
-- a statement about which legs a wave should carry, not a request to bundle two
-- fixes into one id -- each keeps its own gate and its own isolation reading.

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')

local tests = {}

-- Both witnesses come off the sweep's own `F ... hp_pred_flips` lines, so the
-- corpus picked them; they are not frames anyone went looking for.
local W1 = 'tests/fixtures/f_260820_042009_cm_cask_far.lua'
local W1_HERO = 'npc_dota_hero_witch_doctor'
local W2 = 'tests/fixtures/f_260820_102645_cm_es_reach.lua'
local W2_HERO = 'npc_dota_hero_bristleback'

-- ------------------------------------------------------------ source reads --

local function jmz_source()
    local fh = assert(io.open('bots/FunLib/jmz_func.lua', 'r'))
    local s = fh:read('*a'); fh:close()
    return s
end

local function helper_body()
    local src = jmz_source()
    local at = assert(src:find('function J.GetLaneHarassResponse( bot )', 1, true),
        'J.GetLaneHarassResponse moved')
    local fin = assert(src:find('\nend\n', at, true), 'helper has no end')
    return src:sub(at, fin)
end

-- Comments are stripped before every structural read: this guard's header
-- quotes both radii, the id name and the sibling id in prose, so an unstripped
-- search would anchor on the explanation instead of the code.
local function stripped_body()
    local out = {}
    for line in (helper_body() .. '\n'):gmatch('([^\n]*)\n') do
        if not line:match('^%s*%-%-') then out[#out + 1] = line end
    end
    return table.concat(out, '\n')
end

-- ------------------------------------------------------------- the manifest --

local manifest_cache = nil

local function manifest()
    if manifest_cache then return manifest_cache end
    local p = assert(io.popen('lua5.1 tests/_lanekill_domain_sweep.lua 2>&1'),
        'could not start tests/_lanekill_domain_sweep.lua')
    local raw = p:read('*a')
    p:close()
    local m = { C = {}, G = {}, F = {}, done = false }
    for line in raw:gmatch('[^\n]+') do
        local kind = line:match('^(%S+)')
        if kind == 'C' then
            local k, n = line:match('^C (%S+) (%-?%d+)$')
            if k then m.C[k] = tonumber(n) end
        elseif kind == 'G' then
            local k, v = line:match('^G (%S+) (%S+)$')
            if k then m.G[k] = v end
        elseif kind == 'F' then
            local fx, hero, what = line:match('^F (%S+) (%S+) (%S+)$')
            if fx then table.insert(m.F, { fixture = fx, hero = hero, what = what }) end
        elseif kind == 'DONE' then
            m.done = true
        end
    end
    assert(m.done, 'the corpus sweep did not finish -- run '
        .. '`lua5.1 tests/_lanekill_domain_sweep.lua` by hand to see why:\n'
        .. raw:sub(1, 800))
    manifest_cache = m
    return m
end

local function C(key)
    local n = manifest().C[key]
    assert(n ~= nil, 'the sweep did not report counter ' .. key)
    return n
end

-- ================================ 1. the guard symmetrises, asserted as such --

tests['[hrparity] the armed radius equals the enemy radius, whatever it is']
= function()
    local g = manifest().G
    local nE = tonumber(g.HR_ENEMY_R)
    local nP = tonumber(g.HR_PARITY_R)
    assert(nE ~= nil, 'the sweep could not parse the enemy radius')
    assert(nP ~= nil,
        'the sweep could not parse an ally radius inside the hrparity block ' ..
        '(got ' .. tostring(g.HR_PARITY_R) .. ') -- either the guard stopped ' ..
        'reading a second ally set or it now hides the number behind a ' ..
        'variable, and a census that cannot read the ruler cannot check it')
    -- The property is SYMMETRY, not the literal 1100. Asserting equality means
    -- the day someone re-tunes the detection radius, a guard that kept 1100
    -- goes red here instead of quietly becoming a different lever.
    assert(nP == nE,
        'the guard reads allies at ' .. nP .. ' but enemies at ' .. nE ..
        ' -- it is supposed to put both sides of the outnumbered test on ONE ' ..
        'ruler, and two unequal rulers is the defect it exists to remove')
    -- And the SHIPPED default must still carry the asymmetry: this id is a
    -- soak candidate, so an ungated repair would mean it shipped by accident.
    assert(tonumber(g.HR_ALLY_R) ~= nil and tonumber(g.HR_ALLY_R) ~= nE,
        'the shipped ally radius now equals the enemy radius (' ..
        tostring(g.HR_ALLY_R) .. ') -- the repair has left its gate. If that ' ..
        'was a promote, remove this assertion in the same change and say so; ' ..
        'if it was not, an unpromoted behaviour change is live in real games.')
end

tests['[hrparity] the guard sits above the test it repairs'] = function()
    -- M3 (order blindness), the mutant that survives every existence check:
    -- move the recount BELOW `if #tValid > nOurs` and the assignment still
    -- happens, the id is still named, `check_armed_wiring.py` still says WIRED
    -- -- and the branch has already been taken with the old count. Positions,
    -- not existence.
    local body = stripped_body()
    local atGate = body:find("IsSoakCandidate%(%s*'hrparity'%s*%)")
    local atTest = body:find('#tValid > nOurs', 1, true)
    assert(atGate ~= nil, "the shipped helper no longer names 'hrparity'")
    assert(atTest ~= nil, 'the outnumbered test moved; re-anchor this pin')
    assert(atGate < atTest,
        'the hrparity recount now sits BELOW the outnumbered test, so the ' ..
        'verdict is decided on the 900u count before the guard ever runs -- ' ..
        'a no-op that passes every existence check, which is the point of this')
end

tests['[hrparity] the id appears exactly once in the shipped helper'] = function()
    local body = stripped_body()
    local n = 0
    for _ in body:gmatch("IsSoakCandidate%(%s*'hrparity'%s*%)") do n = n + 1 end
    assert(n == 1, "the helper names 'hrparity' " .. n ..
        ' times in code; it is one lever with one call site')
end

-- ============================== 2. both drives close over the same population

tests['[hrparity] the armed drive closes over every entered frame'] = function()
    local entered = C('hr_dmg2')
    assert(entered > 0, 'no frame reaches the helper at all')
    assert(C('hp2_nil') + C('hp2_back') + C('hp2_fire') == entered,
        'the hrparity drive does not close: nil ' .. C('hp2_nil') ..
        ' + back ' .. C('hp2_back') .. ' + fire ' .. C('hp2_fire') ..
        ' ~= entered ' .. entered)
    assert(C('hp2_raised') == 0,
        C('hp2_raised') .. ' frames raise with hrparity armed')
    assert(C('hp_noparse') == 0,
        'the census fell back on an unparsed parity radius on ' ..
        C('hp_noparse') .. ' frames -- the prediction below would be a ' ..
        'statement about the default, not about the guard')
end

-- ================== 3. direction: armed can only delete a 'back', never add one

tests['[hrparity] the forbidden directions read zero'] = function()
    -- Not thresholds anyone chose: the 1100 ally set is a SUPERSET of the 900
    -- one, so nOurs can only grow and `#tValid > nOurs` can only go true ->
    -- false. If either of these goes non-zero the guard has stopped being that.
    assert(C('hp_back_opens') == 0,
        C('hp_back_opens') .. ' frames STARTED retreating when hrparity was ' ..
        'armed. Counting more allies cannot make the bot more outnumbered.')
    assert(C('hp_nil_moved') == 0,
        C('hp_nil_moved') .. ' frames moved into or out of the nil bucket. ' ..
        'nil is decided above the parity test (no valid harasser, or no ' ..
        'fountain vector); this guard must not be able to reach it.')
    assert(C('hp2_nil') == C('hr_nil'),
        'the nil count moved from ' .. C('hr_nil') .. ' to ' .. C('hp2_nil'))
    -- The permitted direction, accounted for exactly rather than bounded.
    assert(C('hr_back') - C('hp2_back') == C('hp_back_closes'),
        'the drop in backs (' .. C('hr_back') .. ' -> ' .. C('hp2_back') ..
        ') does not equal hp_back_closes ' .. C('hp_back_closes'))
    assert(C('hp_fire_opened') == C('hp_back_closes'),
        'a frame that stops retreating must land on fire (tValid is non-empty ' ..
        'by construction there): ' .. C('hp_fire_opened') .. ' vs ' ..
        C('hp_back_closes'))
end

-- ===================== 4. the domain is cross-checked by two different paths

tests['[hrparity] the flip count is reached twice, independently'] = function()
    -- hp_pred_flips: count both ally discs and redo the comparison by hand.
    -- hp_back_closes: drive the shipped function armed and see what it did.
    -- Equal only if the guard actually keys on the parity test.
    assert(C('hp_pred_flips') == C('hp_back_closes'),
        'the two paths to the domain disagree: population arithmetic says ' ..
        C('hp_pred_flips') .. ', the armed drive says ' .. C('hp_back_closes'))
    assert(C('hp_back_closes') > 0,
        'no frame in this corpus flips any more -- the domain is empty, and a ' ..
        'gated lever with an empty domain must not be waved (charter 0FSATOM)')
    -- The same number the 'hrreach' round recorded as the second defect's
    -- price, computed there against HR_ENEMY_R. It has to agree here, or one
    -- of the two rounds is quoting a number the tree no longer produces.
    assert(C('hr_asym_flips') == C('hp_pred_flips'),
        'the price recorded by the hrreach round (' .. C('hr_asym_flips') ..
        ') no longer matches this round (' .. C('hp_pred_flips') .. ')')
    -- A flip needs a band member on one side or the other; more flips than
    -- band frames would mean the columns are counting different populations.
    assert(C('hr_asym_ally_band') >= C('hp_back_closes'),
        'more verdicts flip (' .. C('hp_back_closes') .. ') than there are ' ..
        'frames with an ally in the band (' .. C('hr_asym_ally_band') .. ')')
end

-- ========================= 5. this domain is real frame data, not a stub

tests['[hrparity] the corpus really can tell the two ally discs apart']
= function()
    -- The trap the sibling id fell into, checked instead of assumed. If the
    -- loader answered every radius with the same set (or with {}), every
    -- column above would read a well-formed zero and this round would be
    -- measuring tests/mock, not Dota. 5 frames say otherwise.
    assert(C('hp_ally_disc_differs') > 0,
        'the 900u and 1100u ally queries return the same set on every frame ' ..
        '-- this corpus cannot see the defect at all and no reading here is ' ..
        'about the tree (GH #656 shape, the reason hrreach quotes 8 not 49)')
    assert(C('hp_ally_disc_differs') == C('hr_asym_ally_band'),
        'the two independent walks over the ally band disagree: ' ..
        C('hp_ally_disc_differs') .. ' vs ' .. C('hr_asym_ally_band'))
    -- Stated as a contrast, so a later reader cannot borrow hrreach's caveat
    -- and apply it here: THAT id is stubbed on 84/84 frames, THIS one is not.
    assert(C('hr_range_stub') == C('hr_dmg2'),
        'GetAttackRange is no longer a constant stub -- good news for hrreach, ' ..
        'and this contrast needs rewriting rather than quietly inheriting')
end

-- ============================ 6. the witness frames, on real fixture bytes

local function drive(path, hero, ids)
    local J, bot = rf.load(path, hero)
    J.IsModeTurbo = function() return true end
    J.IsSoakCandidate = function(sId) return ids[sId] == true end
    local ok, s, x = pcall(J.GetLaneHarassResponse, bot)
    assert(ok, 'the helper raised on ' .. path .. ': ' .. tostring(s))
    return s, x, bot, J
end

tests['[hrparity] witness A: a 2v2 read as outnumbered because the ally is at 998u']
= function()
    -- f_260820_042009_cm_cask_far, subject Witch Doctor: enemies Tidehunter at
    -- 245u and Crystal Maiden at 883u (both inside 1100), ally Slardar at 998u
    -- -- inside 1100, outside 900. Shipped, the ally is invisible to the count
    -- and a 2v2 reads 2 > 1, so the bot walks 420u toward its fountain.
    local s, x, bot = drive(W1, W1_HERO, {})
    assert(s == 'back', 'the shipped answer on witness A is now ' ..
        tostring(s) .. ' -- pick a new witness before trusting section 6')
    local tA9 = bot:GetNearbyHeroes(900, false, BOT_MODE_NONE) or {}
    local tA11 = bot:GetNearbyHeroes(1100, false, BOT_MODE_NONE) or {}
    assert(#tA9 == 0 and #tA11 == 1,
        'witness A no longer has exactly one ally in the 900-1100 band (got ' ..
        #tA9 .. ' inside 900, ' .. #tA11 .. ' inside 1100)')
    assert(x ~= nil and x.x ~= nil,
        'the shipped back branch no longer hands back a location')

    local s2 = drive(W1, W1_HERO, { hrparity = true })
    assert(s2 == 'fire',
        'armed, witness A still answers ' .. tostring(s2) ..
        ' -- with the ally counted this is an even fight, not a retreat')
end

tests['[hrparity] witness B: the same shape with the ally at 1075u'] = function()
    -- f_260820_102645_cm_es_reach, subject Bristleback: enemies Crystal Maiden
    -- at 557u and Wraith King at 593u, ally Earthshaker at 1075u. Two
    -- independent fixtures, same defect, opposite lane.
    local s, _, bot = drive(W2, W2_HERO, {})
    assert(s == 'back', 'the shipped answer on witness B is now ' .. tostring(s))
    local tA9 = bot:GetNearbyHeroes(900, false, BOT_MODE_NONE) or {}
    local tA11 = bot:GetNearbyHeroes(1100, false, BOT_MODE_NONE) or {}
    assert(#tA9 == 0 and #tA11 == 1,
        'witness B no longer has exactly one ally in the band (' .. #tA9 ..
        '/' .. #tA11 .. ')')

    local s2 = drive(W2, W2_HERO, { hrparity = true })
    assert(s2 == 'fire', 'armed, witness B still answers ' .. tostring(s2))
end

tests['[hrparity] disarmed and outside turbo, both witnesses are untouched']
= function()
    -- Gate plumbing is NOT local validation (charter step 4) -- the witnesses
    -- above are. This only pins that the two structural conjuncts are conjuncts.
    for _, w in ipairs({ { W1, W1_HERO }, { W2, W2_HERO } }) do
        local J, bot = rf.load(w[1], w[2])
        J.IsModeTurbo = function() return false end
        J.IsSoakCandidate = function() return true end
        local ok, s = pcall(J.GetLaneHarassResponse, bot)
        assert(ok and s == 'back',
            'a normal-mode game no longer gets the shipped answer on ' .. w[1] ..
            ' (got ' .. tostring(s) .. ') -- the turbo conjunct stopped guarding')

        local s2 = drive(w[1], w[2], { some_other_id = true })
        assert(s2 == 'back',
            'turbo alone now changes the answer on ' .. w[1] ..
            ' with hrparity disarmed (got ' .. tostring(s2) .. ')')
    end
end

-- ================ 7. the pair, measured -- because both ids share one helper

tests['[hrparity] armed alone, every frame it un-retreats becomes a chase']
= function()
    -- The bad news, asserted rather than left in prose. `hp_opened_d_max_u` is
    -- real fixture geometry (positions, not the stubbed GetAttackRange), and
    -- the caller spends a 'fire' handle as Action_AttackUnit, which the engine
    -- serves by walking. On witness A the opened target is Crystal Maiden at
    -- 883u and the subject is a Witch Doctor (500 attack range in this patch);
    -- on witness B it is Crystal Maiden at 557u and the subject is Bristleback
    -- (150, melee). Both are out of reach whatever the loader says, so this is
    -- not the stub talking.
    assert(C('hp_opened_d_max_u') > 500,
        'the furthest fire this guard opens is now only ' ..
        C('hp_opened_d_max_u') .. 'u -- the arm-alone caveat has changed shape ' ..
        'and the wave recommendation in this header needs rewriting')
end

tests['[hrparity] with hrreach co-armed the same frames stand and farm']
= function()
    local entered = C('hr_dmg2')
    assert(C('hpb_nil') + C('hpb_back') + C('hpb_fire') == entered,
        'the co-armed drive does not close over the entered population')
    assert(C('hpb_raised') == 0, 'the co-armed drive raises on ' ..
        C('hpb_raised') .. ' frames')
    -- The recommendation, as a measurement: every frame hrparity un-retreats
    -- ends on the shipped last-hit body once hrreach declines the chase.
    assert(C('hpb_flip_ends_nil') == C('hp_back_closes'),
        'only ' .. C('hpb_flip_ends_nil') .. ' of ' .. C('hp_back_closes') ..
        ' un-retreated frames end as nil with both ids armed -- the co-arm ' ..
        'recommendation carried to the director assumes all of them do')
    assert(C('hpb_back') == C('hp2_back'),
        'hrreach moved the back count (' .. C('hp2_back') .. ' -> ' ..
        C('hpb_back') .. '); it is supposed to sit below that branch entirely')
end

return tests

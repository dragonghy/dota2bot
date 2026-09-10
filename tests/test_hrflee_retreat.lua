-- [GH: hrflee] The lane harass response builds its RETREAT VECTOR without the
-- population it is retreating from.
--
-- THE DEFECT. J.GetLaneHarassResponse's outnumbered branch answers 'back' with
-- `bot + 420 * normalize(fountain - bot)`. `tValid` -- the mob this very branch
-- just counted to decide it was outnumbered -- has no vote in the heading. So
-- when the harassers stand BETWEEN the bot and home, the order labelled 'back'
-- walks the bot INTO them, and it does so from the combat-response floor of the
-- replacement laning Think, above every last hit and deny.
--
-- THE WITNESS IS THE WHOLE STEP, not a rounding error. Real frame
-- f_260820_102645_cm_es_reach, bristleback at t=391.5 with hp 0.45: Crystal
-- Maiden at 557u and Wraith King at 593u, both sitting on the line to the dire
-- fountain 12,186u away. The shipped landing is 173u from their centroid --
-- 402 of the 420 units of that step are spent CLOSING, and the bot ends inside
-- Wraith King's melee reach while retreating from him.
--
-- WHY THIS IS A FIX AND NOT A NEW POLICY. No number is invented: 420 and the
-- fountain heading belong to this branch already, and the mob centroid is built
-- from the list the branch itself assembled. Armed, the heading is projected
-- onto the direction perpendicular to the mob -- the homeward-most heading that
-- does not shorten the gap. Walk around them, not through them. Section 2
-- asserts the PROPERTY (the armed landing is no closer to the mob than standing
-- still) rather than the coordinates, so a later re-tuning of 420 moves this
-- test with it instead of past it.
--
-- ⭐ THE NUMBERS (110 fixtures, tests/_lanekill_domain_sweep.lua, the same walk
-- that priced 'hrparity' and 'hrreach'):
--   * `hf_back` 18 -- frames where the shipped helper answers 'back'.
--   * `hf_into_mob` 1 -- of those, the ones whose landing is CLOSER to the mob
--     than standing still. `hf_into_worst_u` 402, `hf_into_lt400` 1.
--   * `hf_land_moved` 1, `hf_armed_no_closer` 1, `hf_armed_still_closes` 0 --
--     armed, exactly that frame moves, and the moved landing keeps the gap.
--   * `hf_verdict_moved` 0 and `hf_missed_defect` 0 -- the two forbidden
--     directions: the guard sits inside the 'back' branch and returns 'back'
--     either way, so it can neither create nor delete a retreat.
--
-- ⭐⭐ THE 1 IS CROSS-CHECKED, NOT RESTATED (the 'hrreach' M5 lesson).
-- `hf_into_mob` is arithmetic on raw positions -- rebuild the centroid, redo
-- the shipped step, compare two distances. `hf_land_moved` is what the shipped
-- function actually did when driven with the id armed. Different code paths,
-- same 1, and section 4 asserts they are equal.
--
-- ⭐⭐⭐ THIS DOMAIN IS NOT STUBBED. 'hrreach' in the same helper measures
-- mostly the loader: no fixture carries an attack_range field, so
-- GetAttackRange answers a constant 150 on 84/84 frames (GH #656). Every number
-- here is read off hero POSITIONS, which every fixture carries for real and
-- which tests/mock/replay_fixture.lua filters by true distance and vision.
--
-- ⛔ SAID BEFORE ANY WAVE, NOT AFTER (GH #622), AND IT IS THE OPPOSITE OF THE
-- SIBLING'S ADVICE. 'hrparity' exists to DELETE retreats, and this guard only
-- ever runs inside one. On this corpus the single frame it fixes is a frame
-- 'hrparity' un-retreats: `hf_lost_to_parity` 1, `hf_pair_keeps` 0. So a leg
-- carrying both ids hands this one an EMPTY domain and buys condition (a) for
-- nothing. The recommendation to the director is DO NOT CO-ARM with 'hrparity'
-- -- where the 'hrparity' round's own recommendation was co-arm with 'hrreach'.
-- Section 6 pins the reading so a later wave cannot lose it. ('hrreach' is
-- harmless here: it only touches the 'fire' branch.)

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')

local tests = {}

-- The witness comes off the sweep's own `F ... hf_into_mob` line, so the corpus
-- picked it; it is not a frame anyone went looking for. The negative control
-- comes off the `F ... hf_away_ok` lines the same way.
local W = 'tests/fixtures/f_260820_102645_cm_es_reach.lua'
local W_HERO = 'npc_dota_hero_bristleback'
local N = 'tests/fixtures/f_260819_222030_jugg_tp_eaten.lua'
local N_HERO = 'npc_dota_hero_juggernaut'

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
-- quotes the id name, the step length and the sibling ids in prose, so an
-- unstripped search would anchor on the explanation instead of the code.
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

-- ----------------------------------------------------------- frame helpers --

-- Drive the shipped helper on one real frame with a chosen arming.
local function drive(path, hero, ids)
    local J, bot = rf.load(path, hero)
    J.IsSoakCandidate = function(id) return ids[id] == true end
    local s, x = J.GetLaneHarassResponse(bot)
    return J, bot, s, x
end

local function mob_centroid(J, bot)
    local nR = tonumber(manifest().G.HR_ENEMY_R) or 1100
    local mx, my, mn = 0, 0, 0
    for _, e in pairs(J.GetNearbyHeroes(bot, nR, true, BOT_MODE_NONE) or {}) do
        if J.IsValidHero(e) and not J.IsSuspiciousIllusion(e)
            and J.CanBeAttacked(e) then
            local v = e:GetLocation()
            mx, my, mn = mx + v.x, my + v.y, mn + 1
        end
    end
    assert(mn > 0, 'the witness frame has no valid harasser left -- the fixture '
        .. 'or the loader changed under this test')
    return mx / mn, my / mn, mn
end

local function dist(ax, ay, bx, by)
    return math.sqrt((ax - bx) ^ 2 + (ay - by) ^ 2)
end

-- =========================== 1. the guard is where it claims to be, and gated --

tests['[hrflee] the guard is turbo-gated on its own id, inside the back branch']
= function()
    local body = stripped_body()
    local at = body:find("IsSoakCandidate( 'hrflee' )", 1, true)
    assert(at, "no 'hrflee' gate in J.GetLaneHarassResponse")
    -- Turbo-only, on the SAME condition (not a separate statement that could
    -- drift apart from it).
    local line = body:sub(math.max(1, at - 120), at + 40)
    assert(line:find('J.IsModeTurbo()', 1, true),
        "the 'hrflee' gate is not conjoined with J.IsModeTurbo()")
    -- The gate must sit AFTER the outnumbered test and BEFORE the shipped
    -- 'back' return: a guard hoisted above `#tValid > nOurs` could change
    -- whether the branch fires, which is the property section 5 relies on.
    local out = assert(body:find('#tValid > nOurs', 1, true),
        'the outnumbered test moved')
    assert(at > out, "the 'hrflee' gate is no longer inside the 'back' branch")
end

tests['[hrflee] the armed step reuses the branch step length, not a new literal']
= function()
    local body = stripped_body()
    local nStep = tonumber(manifest().G.HR_STEP)
    assert(nStep, 'the sweep could not parse the step length')
    -- Every step magnitude in this helper is the same number. The property is
    -- "the guard did not invent a distance"; the value is whatever the branch
    -- chose. Counting them keeps a future re-tune from silently applying to one
    -- landing and not the other.
    local n = 0
    for _ in body:gmatch('%* ' .. nStep .. '[,%s]') do n = n + 1 end
    assert(n >= 2, 'expected the armed landing to reuse the shipped step '
        .. tostring(nStep) .. ', found ' .. n .. ' uses')
    -- And no OTHER magnitude crept in alongside it.
    for lit in body:gmatch('%* (%d%d%d+)') do
        assert(tonumber(lit) == nStep,
            'a second step magnitude appeared in the helper: ' .. lit)
    end
end

tests['[hrflee] the heading is built from the branch\'s own harasser list']
= function()
    local body = stripped_body()
    local at = assert(body:find("IsSoakCandidate( 'hrflee' )", 1, true))
    local guard = body:sub(at)
    assert(guard:find('tValid', 1, true),
        'the armed block does not read tValid -- the retreat heading would '
        .. 'still be built without the population that caused the retreat')
    -- It must not re-query the engine for a second, differently-sized mob: the
    -- whole family defect is one comparison measured with two rulers.
    assert(not guard:find('GetNearbyHeroes', 1, true),
        'the armed block builds its own enemy census instead of reusing '
        .. 'tValid -- that is the two-rulers defect this family exists to fix')
end

-- ================================== 2. the real frame: the property, not coords --

tests['[hrflee] shipped, the witness frame retreats INTO the mob']
= function()
    local J, bot, s, x = drive(W, W_HERO, {})
    assert(s == 'back', 'the witness no longer answers back (got '
        .. tostring(s) .. ') -- the fixture or the helper changed')
    local mx, my, mn = mob_centroid(J, bot)
    assert(mn >= 2, 'the witness should carry a 2-hero mob, got ' .. mn)
    local vB = bot:GetLocation()
    local dNow = dist(vB.x, vB.y, mx, my)
    local dLand = dist(x.x, x.y, mx, my)
    assert(dLand < dNow, 'the shipped landing no longer closes on the mob ('
        .. math.floor(dNow) .. ' -> ' .. math.floor(dLand) .. ') -- this test '
        .. 'has lost its defect')
    -- The size of it: nearly the entire step is spent closing.
    local nStep = tonumber(manifest().G.HR_STEP)
    assert(dNow - dLand > nStep * 0.9, 'the witness closes only '
        .. math.floor(dNow - dLand) .. ' of ' .. nStep)
end

tests['[hrflee] armed, the landing keeps the gap and still heads home']
= function()
    local Js, bots, _, xs = drive(W, W_HERO, {})
    local mx, my = mob_centroid(Js, bots)
    local vB = bots:GetLocation()
    local vF = Js.GetTeamFountain()
    local dNow = dist(vB.x, vB.y, mx, my)

    local Ja, bota, s, x = drive(W, W_HERO, { hrflee = true })
    assert(s == 'back', 'armed changed the verdict to ' .. tostring(s)
        .. ' -- this guard may only move the landing')
    -- THE PROPERTY: no closer to the mob than standing still. Asserted as an
    -- inequality against the bot's own position, so re-tuning the step length
    -- moves this test instead of breaking it.
    local dArmed = dist(x.x, x.y, mx, my)
    assert(dArmed >= dNow, 'the armed landing still closes on the mob ('
        .. math.floor(dNow) .. ' -> ' .. math.floor(dArmed) .. ')')
    -- And it is a real move, not a rounding difference from the shipped one.
    assert(dist(x.x, x.y, xs.x, xs.y) > 1,
        'armed produced the shipped landing')
    -- SECOND PROPERTY, the reason this is a projection and not "run away":
    -- the step still buys ground toward home. A bot that flees straight from
    -- the mob would score worse here than the shipped step does.
    local vBa = bota:GetLocation()
    local dHomeNow = dist(vBa.x, vBa.y, vF.x, vF.y)
    local dHomeArmed = dist(x.x, x.y, vF.x, vF.y)
    assert(dHomeArmed < dHomeNow, 'the armed landing gives up ground toward '
        .. 'home (' .. math.floor(dHomeNow) .. ' -> '
        .. math.floor(dHomeArmed) .. ') -- it should be the homeward-most '
        .. 'heading that does not close on the mob')
    assert(Ja ~= nil)
end

-- ================================ 3. unarmed is byte-for-byte, on two frames --

tests['[hrflee] unarmed, the witness landing is unchanged']
= function()
    local _, _, s1, x1 = drive(W, W_HERO, {})
    -- Arming the two SIBLING ids must not reach this branch's landing either,
    -- except through their own documented effect on the verdict.
    local _, _, s2, x2 = drive(W, W_HERO, { hrreach = true })
    assert(s1 == s2, "'hrreach' moved the 'back' verdict")
    assert(x1.x == x2.x and x1.y == x2.y,
        "'hrreach' moved the retreat landing -- it should only touch 'fire'")
end

tests['[hrflee] a back frame that already moves away is left byte-identical']
= function()
    local Jn, botn, s0, x0 = drive(N, N_HERO, {})
    assert(s0 == 'back', 'the negative control no longer answers back (got '
        .. tostring(s0) .. ')')
    local mx, my = mob_centroid(Jn, botn)
    local vB = botn:GetLocation()
    assert(dist(x0.x, x0.y, mx, my) >= dist(vB.x, vB.y, mx, my),
        'the negative control is in the defect bucket -- pick another frame')
    local _, _, s1, x1 = drive(N, N_HERO, { hrflee = true })
    assert(s1 == 'back' and x1.x == x0.x and x1.y == x0.y,
        'the guard moved a landing that was already heading away from the mob')
end

-- ============================ 4. the corpus, by two independent routes --

tests['[hrflee] the arithmetic route and the drive route report the same domain']
= function()
    assert(C('hf_into_mob') == C('hf_land_moved'),
        'the two routes disagree: hf_into_mob ' .. C('hf_into_mob')
        .. ' vs hf_land_moved ' .. C('hf_land_moved')
        .. ' -- either the guard keys on something other than the closing '
        .. 'test, or the census stopped measuring what the guard does')
    assert(C('hf_into_mob') > 0,
        'the defect bucket is empty on this corpus -- with nothing to fix, '
        .. 'this id must be priced again before it is armed')
end

tests['[hrflee] the corpus census closes over the back population']
= function()
    -- No frame is a silent remainder: every 'back' is either in the defect
    -- bucket or in the away bucket, and the structural outs are counted.
    assert(C('hf_back') == C('hf_into_mob') + C('hf_away_ok'),
        'hf_back ' .. C('hf_back') .. ' != into ' .. C('hf_into_mob')
        .. ' + away ' .. C('hf_away_ok'))
    assert(C('hf_no_fountain') == 0 and C('hf_no_mob') == 0
        and C('hf_on_fountain') == 0,
        'a structural out fired -- the census rows are no longer comparable')
    assert(C('hf5_raised') == 0, 'the armed drive raised an error')
end

-- ================================== 5. the forbidden directions, all three --

tests['[hrflee] armed can neither create nor delete a retreat']
= function()
    assert(C('hf_verdict_moved') == 0,
        'armed moved a frame out of the back verdict on ' ..
        C('hf_verdict_moved') .. ' frames -- this guard sits INSIDE the back '
        .. 'branch and must return back either way')
end

tests['[hrflee] armed never leaves a defect frame untouched, nor still closing']
= function()
    assert(C('hf_missed_defect') == 0,
        C('hf_missed_defect') .. ' frames were in the defect bucket and armed '
        .. 'did not move them')
    assert(C('hf_armed_still_closes') == 0,
        C('hf_armed_still_closes') .. ' armed landings still close on the mob')
    assert(C('hf_armed_no_closer') == C('hf_land_moved'),
        'not every moved landing keeps the gap')
end

-- ========================= 6. the co-arm reading, pinned before any wave --

tests['[hrflee] a leg carrying hrparity leaves this id no domain']
= function()
    -- This is the reading a wave request has to carry (GH #622), and it is the
    -- OPPOSITE of what the 'hrparity' round recommended for its own pairing.
    -- Pinned as a test so it cannot be lost between the report and the slate.
    assert(C('hf_pair_raised') == 0, 'the co-arm drive raised an error')
    assert(C('hf_pair_keeps') + C('hf_lost_to_parity') == C('hf_into_mob'),
        'the co-arm drive did not cover the defect bucket')
    assert(C('hf_lost_to_parity') == C('hf_into_mob')
        and C('hf_pair_keeps') == 0,
        'the co-arm reading CHANGED: hrparity now leaves '
        .. C('hf_pair_keeps') .. ' of ' .. C('hf_into_mob') .. ' defect frames '
        .. 'standing. The do-not-co-arm recommendation in this file\'s header '
        .. 'and in the wave request was measured at 0 -- re-read it before '
        .. 'launching, do not just update the number')
end

return tests

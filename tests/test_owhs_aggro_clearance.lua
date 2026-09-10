-- [l5trees cut 2 / CLEARANCE 20260910] J.GetOffWaveHarassSpot exists for one
-- reason: the bot is standing on the enemy wave, so harassing from here would
-- aggro those creeps, and the branch steps off the wave so the NEXT think can
-- harass aggro-free. The set that makes that true -- `tCreeps`, the enemy lane
-- creeps inside nAggroR -- fed the lane axis and then had no vote at all in the
-- one free variable, the SIGN of the perpendicular. That sign was decided by
-- the hero census alone (the 20260909 ruler round), so the step could be aimed
-- at whichever side the wave leans to and land back inside nAggroR of a creep:
-- position given up, aggro kept, branch purpose defeated.
--
-- The repair is a TIE-BREAK: the hero vote still owns the choice and is
-- overruled only when the side it picked FAILS the aggro test and the mirror
-- PASSES it. No new radius, no new number, no new soak id (the single call site
-- is a pure conjunction with 'l5trees' -- section 2 of the sister file
-- test_owhs_side_ruler.lua asserts that, and it is not restated here).
--
-- ⛔ WHAT THIS CORPUS CANNOT DO, stated before any number below is read.
-- tests/fixtures carries NO CREEPS ON ANY FRAME (section 3 measures that rather
-- than citing it), so this round CANNOT price how often a real wave stands in
-- the region that defeats the step. Two different things stand in for that, and
-- neither is a frequency:
--   * section 2 is pure geometry and needs no corpus at all -- how BIG the
--     region is, computed two independent ways;
--   * sections 4-6 move the corpus's one injected creep to a second declared
--     position inside the same ball and read what the shipped rule then does.
-- The frequency question is the open corpus request (creeps in fixtures), and
-- the honest reading of section 5's 166 is "the geometry admits it on every
-- frame that reaches the branch", NOT "it happens 166 times".
--
-- ⚠️ AND THE COST IS IN HERE, not in the report only: on 161 of those 166 the
-- clearance flip steps NEARER an enemy hero than the hero vote wanted, because
-- flipping is exactly reversing that vote. Section 6 pins it.

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')

local tests = {}

local function read_file(path)
    local fh = assert(io.open(path, 'r'), path .. ' is not readable')
    local s = fh:read('*a'); fh:close()
    return s
end

-- ------------------------------------------------------------- the manifest --

local manifest_cache = nil

local function manifest()
    if manifest_cache then return manifest_cache end
    local p = assert(io.popen('lua5.1 tests/_lanekill_domain_sweep.lua 2>&1'),
        'could not start tests/_lanekill_domain_sweep.lua')
    local raw = p:read('*a')
    p:close()
    local m = { C = {}, G = {}, done = false }
    for line in raw:gmatch('[^\n]+') do
        local kind = line:match('^(%S+)')
        if kind == 'C' then
            local k, n = line:match('^C (%S+) (%-?%d+)$')
            if k then m.C[k] = tonumber(n) end
        elseif kind == 'G' then
            local k, v = line:match('^G (%S+) (%S+)$')
            if k then m.G[k] = v end
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

local function G(key)
    local v = manifest().G[key]
    assert(v ~= nil and v ~= 'nil',
        'the sweep could not parse ' .. key .. ' out of the shipped source -- '
        .. 'a census that cannot read the constant cannot check it')
    return tonumber(v)
end

local function helper_body()
    local src = read_file('bots/FunLib/jmz_func.lua')
    local at = assert(src:find('function J.GetOffWaveHarassSpot( bot )', 1, true),
        'J.GetOffWaveHarassSpot moved')
    local fin = assert(src:find('\nend\n', at, true), 'helper has no end')
    return src:sub(at, fin)
end

-- Count occurrences of a literal needle.
-- Comments out, before any literal is counted: this helper explains its own two
-- numbers in prose (the arithmetic and the lens both name them), and counting
-- those would make the single-binding assertion below unsatisfiable for the one
-- reason that is not a defect. Same reasoning as
-- tests/test_detector_source_constants.py's `_strip_comments`.
local function strip_comments(s)
    local out = {}
    for line in (s .. '\n'):gmatch('([^\n]*)\n') do
        local code = line:match('^(.-)%s*%-%-')
        out[#out + 1] = code or line
    end
    return table.concat(out, '\n')
end

local function count(hay, needle)
    local n, at = 0, 1
    while true do
        local hit = hay:find(needle, at, true)
        if hit == nil then return n end
        n, at = n + 1, hit + 1
    end
end

-- ============================================ 1. one binding per number --

tests['[owhsclear] each number is bound once and read from the binding'] = function()
    local body = strip_comments(helper_body())
    -- The deepnum reading of 2026-09-10 (charter 0DUPGUARD, item 甲): two
    -- literals that agree today are not the same number, and nothing makes them
    -- stay equal. This cut needs nAggroR at two sites (the creep list and the
    -- clearance test) and nStep at two more (the clearance test and the
    -- returned spot), so the bindings are the fix, not a tidy-up -- and this
    -- line is what stops the next reader from inlining one of them back.
    assert(count(body, 'local nAggroR = ') == 1,
        'nAggroR must be bound exactly once in the helper')
    assert(count(body, 'local nStep = ') == 1,
        'nStep must be bound exactly once in the helper')
    assert(count(body, tostring(G('OW_AGGRO_R'))) == 1, string.format(
        'the literal %d appears more than once in the helper: one of the two '
        .. 'aggro-radius sites stopped reading the binding, and they can now '
        .. 'drift apart silently', G('OW_AGGRO_R')))
    assert(count(body, tostring(G('OW_STEP'))) == 1, string.format(
        'the literal %d appears more than once in the helper: one of the step '
        .. 'sites stopped reading the binding', G('OW_STEP')))
    -- And the clearance test really is expressed in those bindings.
    assert(body:find('qx * nStep', 1, true) ~= nil
        and body:find('< nAggroR', 1, true) ~= nil,
        'the clearance test no longer reads the helper\'s own two bindings')
end

-- ================= 2. the defect's SIZE, computed two independent ways --

tests['[owhsclear] the step cannot clear the ball it is measured against']
= function()
    local r, s = G('OW_AGGRO_R'), G('OW_STEP')
    -- The whole defect is reachable iff the two discs overlap at all. This is
    -- the checked relation between the two constants: push the step past 2r and
    -- the header's promise becomes true unconditionally and this cut is dead
    -- code; pull it under r and the spot is inside the ball no matter what.
    assert(s < 2 * r, string.format(
        'nStep %d >= 2*nAggroR %d: the step now clears the aggro ball from any '
        .. 'creep position, so the clearance tie-break is unreachable and must '
        .. 'be deleted rather than left in as decoration', s, 2 * r))
    assert(s > r * 0.5, string.format('nStep %d collapsed relative to nAggroR '
        .. '%d; a step this short never clears anything', s, r))
    -- The perpendicular component beyond which a creep at distance d survives
    -- the step: q > (d^2 + s^2 - r^2) / (2s). At d = r that is 275 for
    -- (500, 550) -- comfortably inside the ball, which is the whole point.
    local qCrit = (r * r + s * s - r * r) / (2 * s)
    assert(qCrit < r, string.format(
        'the critical offset %.1f is outside the aggro ball (r = %d): no creep '
        .. 'that satisfies the helper\'s own precondition could defeat the '
        .. 'step, and the finding would be empty', qCrit, r))
end

tests['[owhsclear] a third of the aggro ball defeats the step -- two routes']
= function()
    local r, s = G('OW_AGGRO_R'), G('OW_STEP')
    -- Route A: closed form for the lens of two equal discs of radius r whose
    -- centres are s apart.
    local area = 2 * r * r * math.acos(s / (2 * r))
        - (s / 2) * math.sqrt(4 * r * r - s * s)
    local fA = area / (math.pi * r * r)
    -- Route B: grid integration over the ball, asking the shipped question
    -- directly ("is this point still within r of the spot?") rather than
    -- trusting the formula. The M5 lesson: a number reached one way is a
    -- number nobody checked.
    local hit, tot, step = 0, 0, 5
    local x = -r
    while x <= r do
        local y = -r
        while y <= r do
            if x * x + y * y <= r * r then
                tot = tot + 1
                -- the spot sits at (0, s) from the bot; a creep at (x, y)
                if x * x + (y - s) * (y - s) < r * r then hit = hit + 1 end
            end
            y = y + step
        end
        x = x + step
    end
    local fB = hit / tot
    assert(math.abs(fA - fB) < 0.01, string.format(
        'the two routes disagree (closed form %.4f, grid %.4f): one of them is '
        .. 'not measuring the region the helper walks into', fA, fB))
    assert(fA > 0.25 and fA < 0.40, string.format(
        'the defect region is %.1f%% of the aggro ball; the prose in '
        .. 'jmz_func.lua and in this file says "a third", so a number outside '
        .. 'this band means the constants moved and the prose is stale',
        fA * 100))
end

-- ==================== 3. the instrument, before any driven reading --

tests['[owhsclear] this corpus carries no lane creeps at all -- measured'] = function()
    assert(C('ow_creeps_zero') == C('ow_live'), string.format(
        'ow_creeps_zero %d != ow_live %d: the corpus grew creeps, so the two '
        .. 'declared injections are no longer the only way the driven rows can '
        .. 'exist -- and a real frequency may now be buyable, which is the '
        .. 'thing this round had to say it could not measure',
        C('ow_creeps_zero'), C('ow_live')))
    assert(C('ow_creeps_live') == 0, 'ow_creeps_live went non-zero')
end

-- ============ 4. on the corpus's own injection the cut is a NO-OP --

tests['[owhsclear] with the creep at my feet the spot is unchanged, everywhere']
= function()
    -- The pre-existing injection puts the single creep AT the bot, where both
    -- candidate spots clear by construction (nStep > nAggroR). So on every
    -- frame this corpus can drive, the clearance cut changes nothing -- which
    -- is the one risk bound a corpus with no creeps CAN give.
    assert(C('ow_drive_nonnil') > 0, 'the drive population went empty')
    assert(C('ow_drive_matches_wide') == C('ow_drive_nonnil'), string.format(
        'ow_drive_matches_wide %d != ow_drive_nonnil %d: the clearance cut '
        .. 'moved a spot on the foot injection, where nothing should be able '
        .. 'to move -- either nStep fell under nAggroR or the tie-break stopped '
        .. 'being a tie-break', C('ow_drive_matches_wide'), C('ow_drive_nonnil')))
end

-- ===================== 5. the probe domain, and it closes on itself --

tests['[owhsclear] the probe domain closes: cause, flip and clearance agree']
= function()
    local n = C('ow_clear_probe')
    assert(n > 0, 'the clearance probe never ran')
    assert(C('ow_clear_probe') == C('ow_drive_nonnil'), string.format(
        'the probe ran on %d frames but the foot drive on %d: the two '
        .. 'injections must see the same population or the no-op claim in '
        .. 'section 4 is about different frames',
        C('ow_clear_probe'), C('ow_drive_nonnil')))
    -- Three columns computed by three different routes -- the arithmetic
    -- restatement (old_hits), the driven comparison (flips), and the shipped
    -- answer measured against the creep (spot_clean) -- must land on one
    -- number. A split means one of them stopped measuring.
    assert(C('ow_clear_old_hits') == n, string.format(
        'ow_clear_old_hits %d != probe %d: the declared offset stopped placing '
        .. 'the creep in the region that defeats the step, so the rows below '
        .. 'are measuring a configuration the finding is not about',
        C('ow_clear_old_hits'), n))
    assert(C('ow_clear_mirror_clean') == n, 'ow_clear_mirror_clean ' ..
        C('ow_clear_mirror_clean') .. ' != probe ' .. n ..
        ': the mirror stopped being an escape, so the tie-break has no answer '
        .. 'to give and the flip count below is not attributable')
    assert(C('ow_clear_flips') == C('ow_clear_old_hits'), string.format(
        'ow_clear_flips %d != ow_clear_old_hits %d -- the flip must happen on '
        .. 'exactly the frames where the shipped side fails and the mirror '
        .. 'clears, no more and no fewer',
        C('ow_clear_flips'), C('ow_clear_old_hits')))
    assert(C('ow_clear_spot_clean') == n, string.format(
        'ow_clear_spot_clean %d != probe %d: the helper returned a spot that '
        .. 'still aggros the creep on some frame where the mirror was clean -- '
        .. 'that is the promise this cut exists to keep',
        C('ow_clear_spot_clean'), n))
end

tests['[owhsclear] the three forbidden directions are zero'] = function()
    assert(C('ow_clear_raised') == 0, 'the helper raised under the probe')
    -- Same forbidden direction the ruler round pinned: whether the sidestep
    -- fires is the TARGET list's job, and a clearance test that could veto the
    -- step would be the M8 shape (removing the bad step by removing the branch).
    assert(C('ow_clear_nil_on_reach') == 0, string.format(
        'ow_clear_nil_on_reach %d: the clearance test leaked into the firing '
        .. 'condition', C('ow_clear_nil_on_reach')))
    -- A flip with no cause is the other failure: overruling the hero vote on a
    -- frame where the side it picked was already clean.
    assert(C('ow_clear_flip_no_cause') == 0, string.format(
        'ow_clear_flip_no_cause %d: the side flipped where the shipped side '
        .. 'already cleared the wave -- that is a new policy, not a tie-break',
        C('ow_clear_flip_no_cause')))
end

-- ============================ 6. the cost, registered rather than argued --

tests['[owhsclear] clearing the wave usually steps nearer a hero -- measured']
= function()
    -- ⚠️ This is the column that argues AGAINST the change, and it is large:
    -- flipping the side is by construction the reverse of "away from the enemy
    -- heroes", so the new spot is nearer somebody on nearly every flip frame.
    -- It is registered, not argued away. What makes the trade defensible rather
    -- than obviously bad is that the alternative on those frames is not "stand
    -- somewhere safer" -- it is "walk nStep, keep the creep aggro anyway", i.e.
    -- pay the position and get nothing. Refusing to step at all is the OTHER
    -- alternative, and it is the forbidden direction pinned above (and by M8 of
    -- the sister stand): it deletes the branch on exactly its own domain.
    assert(C('ow_clear_flip_nearer_hero') > 0, 'the cost column reads zero, '
        .. 'which would mean flipping never approaches anybody -- that '
        .. 'contradicts the flip being a reversal of the hero vote, so the '
        .. 'column has probably stopped counting')
    assert(C('ow_clear_flip_nearer_hero') <= C('ow_clear_flips'), string.format(
        'ow_clear_flip_nearer_hero %d exceeds ow_clear_flips %d',
        C('ow_clear_flip_nearer_hero'), C('ow_clear_flips')))
    -- Not EVERY flip pays it: the frames where it does not are the ones where
    -- the hero vote had nothing to say (an empty or symmetric census). If this
    -- ever becomes an equality the cost has grown to the whole domain and the
    -- prose above is stale.
    assert(C('ow_clear_flip_nearer_hero') < C('ow_clear_flips'), string.format(
        'the cost is now every flip frame (%d of %d); re-read the trade before '
        .. 'quoting this round\'s reading',
        C('ow_clear_flip_nearer_hero'), C('ow_clear_flips')))
end

-- ================================= 7. driven on real frames (witnesses) --

-- Drive the helper on one real frame under a DECLARED two-step injection:
--   pass 1 -- creep at the bot's foot, to learn the side the hero vote picks;
--   pass 2 -- the same single creep moved nOff along that side, still inside
--             nAggroR of the bot (so still a creep list the helper's own third
--             conjunct would accept).
-- Everything except the creep -- hero positions, the fountain, the census, the
-- vote -- is the real frame.
local function drive(path, hero, nOffFrac)
    local J, bot = rf.load(path, hero)
    J.IsSoakCandidate = function() return false end
    local nStep, nAggro = G('OW_STEP'), G('OW_AGGRO_R')
    local vMe = bot:GetLocation()

    local function inject(vx, vy)
        local creep = {
            IsNull = function() return false end,
            CanBeSeen = function() return true end,
            IsAlive = function() return true end,
            IsBuilding = function() return false end,
            GetLocation = function() return Vector(vx, vy, vMe.z or 0) end,
        }
        bot.GetNearbyLaneCreeps = function(_, _r, bEnemy)
            if bEnemy then return { creep } end
            return {}
        end
    end

    inject(vMe.x, vMe.y)
    local v0 = J.GetOffWaveHarassSpot(bot)
    assert(v0 ~= nil, path .. ': the witness frame no longer produces a spot')
    local qx, qy = (v0.x - vMe.x) / nStep, (v0.y - vMe.y) / nStep

    local nOff = math.floor(nAggro * nOffFrac)
    local cx, cy = vMe.x + qx * nOff, vMe.y + qy * nOff
    inject(cx, cy)

    -- The SHIPPED rule restated for this geometry (hero vote only), so the
    -- witness never leans on the helper's own answer to describe the defect.
    local vF = J.GetTeamFountain()
    assert(vF ~= nil, path .. ': this frame has no team fountain')
    local ax, ay = vF.x - cx, vF.y - cy
    local mag = math.max(math.sqrt(ax * ax + ay * ay), 1)
    local px, py = -(ay / mag), ax / mag
    local ex, ey, en = 0, 0, 0
    for _, e in pairs(J.GetNearbyHeroes(bot, G('OW_SIDE_R'), true, BOT_MODE_NONE) or {}) do
        if J.IsValidHero(e) then
            local v = e:GetLocation()
            ex, ey, en = ex + v.x, ey + v.y, en + 1
        end
    end
    if en > 0 then
        ex, ey = ex / en - vMe.x, ey / en - vMe.y
        if (px * ex + py * ey) > 0 then px, py = -px, -py end
    end
    local old = { x = vMe.x + px * nStep, y = vMe.y + py * nStep }

    local vSpot = J.GetOffWaveHarassSpot(bot)
    local function dCreep(p)
        return math.sqrt((p.x - cx) ^ 2 + (p.y - cy) ^ 2)
    end
    return {
        me = vMe, spot = vSpot, old = old, creep = { x = cx, y = cy },
        d_old = dCreep(old), d_new = vSpot ~= nil and dCreep(vSpot) or nil,
        step = vSpot ~= nil and math.sqrt((vSpot.x - vMe.x) ^ 2
            + (vSpot.y - vMe.y) ^ 2) or nil,
        n_enemies = en,
    }
end

tests['[owhsclear] witness 1: the step lands 150u from the creep it stepped off']
= function()
    -- f_231411_ck_zoned, tidehunter -- the ruler round's own witness frame, so
    -- the two cuts are read on the same ground. With the wave one 400u stride
    -- off the axis on the side the hero vote picks, the shipped step lands
    -- INSIDE the aggro radius: the bot walked the whole nStep and is still
    -- standing in the creeps' aggro ball, which is the exact condition the
    -- branch exists to leave.
    local r = drive('tests/fixtures/f_231411_ck_zoned.lua',
        'npc_dota_hero_tidehunter', 0.8)
    assert(r.spot ~= nil, 'the witness frame stopped producing a spot')
    assert(r.d_old < G('OW_AGGRO_R'), string.format(
        'the shipped side lands %.0f from the creep, which is already outside '
        .. 'the %d aggro radius -- this frame no longer witnesses the defect',
        r.d_old, G('OW_AGGRO_R')))
    assert(r.d_new >= G('OW_AGGRO_R'), string.format(
        'the fixed side lands %.0f from the creep and must be at least %d: the '
        .. 'tie-break did not fire on its own witness', r.d_new, G('OW_AGGRO_R')))
    assert(r.d_new > r.d_old + 500, string.format(
        'the repair must be a visible mirror, not a nudge (old %.0f, new %.0f)',
        r.d_old, r.d_new))
    -- FORBIDDEN DIRECTION, on the witness itself: the sidestep is still a
    -- sidestep of exactly nStep. A "fix" that shortened or lengthened the step
    -- to clear the wave would be a different lever entirely.
    assert(math.abs(r.step - G('OW_STEP')) < 1, string.format(
        'the step is now %.1f, not %d', r.step, G('OW_STEP')))
end

tests['[owhsclear] witness 2: the same shape on the game that produced the helper']
= function()
    -- f_175703_sven_tp47, shadow_shaman -- batch game 175703, whose 2:44
    -- sidestep produced this helper's fight-awareness guard and (per the ruler
    -- round) its side-census defect too. A second frame matters here because
    -- witness 1 alone cannot separate "the tie-break works" from "the tie-break
    -- happens to work on one geometry".
    local r = drive('tests/fixtures/f_175703_sven_tp47.lua',
        'npc_dota_hero_shadow_shaman', 0.8)
    assert(r.spot ~= nil, 'the witness frame stopped producing a spot')
    assert(r.n_enemies > 0, 'this frame has no side census, so the flip below '
        .. 'is not overruling anything and the witness proves less than it says')
    assert(r.d_old < G('OW_AGGRO_R') and r.d_new >= G('OW_AGGRO_R'),
        string.format('old %.0f / new %.0f against a %d aggro radius',
            r.d_old, r.d_new, G('OW_AGGRO_R')))
end

tests['[owhsclear] negative control: a creep at my feet leaves the answer alone']
= function()
    -- Without this frame a reader cannot tell "the clearance test refines the
    -- side" from "the clearance test decides the side". At nOffFrac 0 both
    -- candidate spots clear, the tie-break has no cause, and the returned spot
    -- must be bit-identical to the hero vote's.
    local r = drive('tests/fixtures/f_231411_ck_zoned.lua',
        'npc_dota_hero_tidehunter', 0)
    assert(r.spot ~= nil, 'the control frame stopped producing a spot')
    assert(r.d_old >= G('OW_AGGRO_R'), 'the control needs a creep position '
        .. 'where the shipped side already clears')
    assert(math.abs(r.spot.x - r.old.x) < 1 and math.abs(r.spot.y - r.old.y) < 1,
        string.format('the control flipped anyway (old %.0f,%.0f new %.0f,%.0f)',
            r.old.x, r.old.y, r.spot.x, r.spot.y))
end

tests['[owhsclear] a creep BEHIND the step never flips the side'] = function()
    -- The second control, and it is the one that does not depend on any
    -- threshold: put the same creep on the side the step is walking AWAY from.
    -- Whatever nStep and nAggroR are, a spot nStep ahead cannot be nearer to it
    -- than the bot was, so the tie-break must stay silent. If this ever flips,
    -- the clearance test has stopped being a test of the spot and become a
    -- second opinion about the side.
    local r = drive('tests/fixtures/f_231411_ck_zoned.lua',
        'npc_dota_hero_tidehunter', -0.8)
    assert(r.spot ~= nil, 'the frame stopped producing a spot')
    assert(r.d_old >= G('OW_AGGRO_R'), string.format(
        'a creep on the side AWAY from the step cannot be inside the aggro '
        .. 'radius of the spot (%.0f); the geometry is not what this file '
        .. 'thinks it is', r.d_old))
    assert(math.abs(r.spot.x - r.old.x) < 1 and math.abs(r.spot.y - r.old.y) < 1,
        'the side flipped with the creep behind the step')
end

return tests

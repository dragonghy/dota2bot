-- [GH: hrreach] The lane harass response searches 1100u and spends the answer
-- as an attack order, so the bot is sent walking at harassers it cannot hit.
--
-- THE DEFECT. J.GetLaneHarassResponse collects every valid enemy inside an
-- 1100u DETECTION radius into `tValid`, then returns the weakest of them as
-- ('fire', hTarget). Its only caller (mode_laning_generic.lua, the replacement
-- Think's combat-response floor) spends that handle immediately as
-- `bot:SetTarget(x)` + `bot:Action_AttackUnit(x, true)`. The engine serves an
-- attack order on an out-of-reach target by WALKING to it. So the radius that
-- decides "am I being harassed" is also, silently, the radius that decides
-- "how far will I chase" -- and it is the FIRST thing the replacement Think
-- does, returning unconditionally, before any last-hit or deny.
--
-- THE CONVENTION IT SHOULD HAVE USED ALREADY SHIPS, in this helper's own
-- caller. mode_laning_generic.lua's support harass block does the same thing
-- correctly: `bot:GetNearbyHeroes(botAttackRange, ...)` and then attack. Two
-- conventions for one action in one file pair, and the loose one is the one
-- with priority. 'hrreach' is not a new policy; it is that convention applied
-- where it was missing. Same coin as campbind (GH #475) and midsupfar: a
-- selector whose scope is wider than what the consumer can actually do.
--
-- ⭐ THE NUMBERS, AND WHICH WAY EACH ONE CUTS (110 fixtures, 84 entered
-- frames, tests/_lanekill_domain_sweep.lua):
--   * `hr_dmg2` 84 -- frames that pass the helper's only entry gate. The
--     damage channel is real ground truth here: replay_fixture gives each
--     hero the damage it actually dealt TO the subject.
--   * 12 `hr_nil` + 18 `hr_back` + 54 `hr_fire` = 84 -- the shipped drive
--     closes over the entered population, so no bucket is a silent remainder.
--   * `hr_fire_d_gt900` 8 and `hr_fire_d_max_u` 1078 -- on 8 of the 54 the
--     returned target is beyond ANY hero's reach in this patch, the furthest
--     at 1078u. Witnesses include a 175-reach melee Axe
--     (f_260820_043120_viper_defend_paired).
--   * `hr_closes` 49, `hr_opens` 0, `hr_back_moved` 0 -- armed, the answer
--     only ever moves one way, and the 'back' branch never moves at all.
--
-- ⛔ WHAT THIS CORPUS CANNOT SAY, said here rather than left for the wave.
-- NO fixture carries an attack_range field, so tests/mock/bot_api.lua's
-- default answers a CONSTANT 150 for every hero on every frame
-- (`hr_range_stub` 84/84, `hr_range_live` 0). That is GH #656's shape, and it
-- means the headline `hr_closes` 49 is mostly a statement about the LOADER:
-- 41 of those 49 (`hr_closes_stubonly`) are frames where a 600-range Lion or
-- CM would in fact have been in reach and the stub said otherwise. Only
-- `hr_closes_universal` 8 survives a real GetAttackRange, and it is 8 because
-- 900u is beyond every hero's reach whatever the stub says. QUOTE THE 8, NOT
-- THE 49. A wave arming 'hrreach' therefore buys a domain of ~8/84 frames,
-- not ~49/84, and section 4 is the assertion that keeps those apart.
--
-- ⭐⭐ THE 8 IS CROSS-CHECKED, not restated. `hr_fire_d_gt900` is bumped on
-- the SHIPPED drive from the returned target's distance; `hr_closes_universal`
-- is bumped on the DIFFERENTIAL from which frames actually flipped. They are
-- computed by different paths from different drives and section 3 asserts they
-- are equal -- if the guard ever stops keying on reach, the identity breaks
-- before any count changes.
--
-- ⛔⛔ ALSO MEASURED, DELIBERATELY NOT FIXED (one lever at a time; the lanefix
-- bundle lesson). The same helper counts enemies to 1100 but allies to 900, so
-- its outnumbered test compares two populations read at different radii --
-- an enemy at 1000u is a harasser while an ally at 1000u is not. Priced on the
-- same walk: `hr_asym_enemy_band` 12, `hr_asym_ally_band` 5, and
-- `hr_asym_flips` 2 frames where the back/fire verdict genuinely differs if
-- both are read at one radius. That is a real second defect with a real
-- domain; it gets its own round and its own id, and section 5 pins the reading
-- so it cannot be quietly repaired inside this one (the M12 ratchet lesson).

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')

local tests = {}

local WITNESS = 'tests/fixtures/f_260820_043120_viper_defend_paired.lua'
local WITNESS_HERO = 'npc_dota_hero_axe'

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

-- Comments are stripped before every structural read: this helper's header
-- quotes `Action_AttackUnit`, `GetAttackRange` and the id name in prose, so an
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

-- ============================================ 1. the constants come from source

tests['[hrreach] the two radii are parsed out of the shipped helper'] = function()
    local g = manifest().G
    assert(g.HR == '1', 'the sweep could not find J.GetLaneHarassResponse at all')
    -- Asserted as a RELATION, not as two literals: the defect is that the
    -- detection radius and the ally radius differ, so the day someone
    -- equalises them this test should say so rather than pass on new numbers.
    local nE = tonumber(g.HR_ENEMY_R)
    local nA = tonumber(g.HR_ALLY_R)
    assert(nE ~= nil and nA ~= nil,
        'the sweep failed to parse the helper radii (got enemy=' ..
        tostring(g.HR_ENEMY_R) .. ' ally=' .. tostring(g.HR_ALLY_R) .. ')')
    assert(nE == 1100 and nA == 900,
        'the helper radii moved (enemy=' .. nE .. ' ally=' .. nA .. '). ' ..
        'That is allowed, but it re-prices both this guard and the asymmetry ' ..
        'in section 5 -- re-run the sweep and update the recorded readings.')
end

tests['[hrreach] the universal-reach bound is declared, never parsed'] = function()
    -- 900 is an ARGUMENT about Dota (the longest hero attack range in this
    -- patch), not a number in bots/. It is labelled that way in the sweep so
    -- no later reader can cite it as a measurement; this pins the label.
    local g = manifest().G
    assert(g.HR_UNIVERSAL_REACH_DECLARED == '900',
        'the declared universal-reach bound changed to ' ..
        tostring(g.HR_UNIVERSAL_REACH_DECLARED) ..
        ' -- if a hero can now attack past 900, hr_fire_d_gt900 stops being ' ..
        'loader-independent and the headline 8 has to be re-derived')
    local src = jmz_source()
    assert(not src:find('HR_UNIVERSAL_REACH', 1, true),
        'the declared bound leaked into bots/ -- it is a reading aid, not a ' ..
        'threshold the shipped tree may depend on')
end

-- ====================================== 2. the population closes, both drives

tests['[hrreach] the shipped drive closes over every entered frame'] = function()
    local entered = C('hr_dmg2')
    assert(entered > 0, 'no frame reaches the helper at all -- the reading ' ..
        'below would be about the corpus, not about the tree')
    assert(C('hr_nil') + C('hr_back') + C('hr_fire') == entered,
        'the shipped drive does not close: nil ' .. C('hr_nil') ..
        ' + back ' .. C('hr_back') .. ' + fire ' .. C('hr_fire') ..
        ' ~= entered ' .. entered .. '. An unnamed remainder means some ' ..
        'frames took a path this census does not know about.')
    assert(C('hr_raised') == 0,
        C('hr_raised') .. ' frames raise inside the shipped helper')
    -- The two halves of the entry funnel also have to add up, or "no valid
    -- harasser" and "the helper declined for some other reason" would be the
    -- same number (the GH #171 shape).
    assert(C('hr_valid_zero') + C('hr_valid_nonzero') == entered,
        'the valid-enemy split does not close over the entered population')
    assert(C('hr_nil') == C('hr_valid_zero'),
        'the shipped helper returns nil on ' .. C('hr_nil') .. ' frames but ' ..
        C('hr_valid_zero') .. ' have no valid harasser -- the shipped nil is ' ..
        'supposed to have exactly one cause')
end

tests['[hrreach] the armed drive closes over the same population'] = function()
    local entered = C('hr_dmg2')
    assert(C('hr2_nil') + C('hr2_back') + C('hr2_fire') == entered,
        'the armed drive does not close over the entered population')
    assert(C('hr2_raised') == 0,
        C('hr2_raised') .. ' frames raise with hrreach armed')
end

-- ============================== 3. direction: armed can only delete a 'fire'

tests['[hrreach] the forbidden directions read zero'] = function()
    -- The armed candidate set is a strict subset of the shipped one, so these
    -- are not thresholds anyone chose -- they are consequences of the shape.
    -- If either ever goes non-zero the guard has stopped being a narrowing.
    assert(C('hr_opens') == 0,
        C('hr_opens') .. ' frames gained a "fire" when hrreach was armed. ' ..
        'The guard is supposed to be a strict narrowing of the candidate set.')
    assert(C('hr_back_moved') == 0,
        C('hr_back_moved') .. ' frames changed their "back" verdict. ' ..
        'hrreach sits below the outnumbered branch and must not touch it.')
    assert(C('hr_back') == C('hr2_back'),
        'the back count moved from ' .. C('hr_back') .. ' to ' .. C('hr2_back'))
end

tests['[hrreach] the permitted direction is accounted for exactly'] = function()
    assert(C('hr_closes') == C('hr_fire') - C('hr2_fire'),
        'hr_closes ' .. C('hr_closes') .. ' does not equal the drop in fires (' ..
        C('hr_fire') .. ' -> ' .. C('hr2_fire') .. ')')
    assert(C('hr_closes_universal') + C('hr_closes_stubonly') == C('hr_closes'),
        'the closes split does not add back up to hr_closes')
end

tests['[hrreach] the loader-independent 8 is cross-checked, not restated']
= function()
    -- Two independent paths: hr_fire_d_gt900 comes off the SHIPPED drive's
    -- returned-target distance, hr_closes_universal off the DIFFERENTIAL. They
    -- agree only if the armed guard actually keys on reach. This is the
    -- assertion that survives the GetAttackRange stub.
    assert(C('hr_fire_d_gt900') == C('hr_closes_universal'),
        'the two independent counts of out-of-reach fires disagree: ' ..
        'shipped-drive distance says ' .. C('hr_fire_d_gt900') ..
        ', differential says ' .. C('hr_closes_universal'))
    assert(C('hr_fire_d_gt900') > 0,
        'no frame returns a target beyond 900u any more -- the defect this ' ..
        'id exists for is gone, and the id should be retired rather than shipped')
    assert(C('hr_fire_d_max_u') > 900,
        'the furthest ordered target is now ' .. C('hr_fire_d_max_u') .. 'u')
end

-- ================================ 4. the stub is named, so it cannot be quoted

tests['[hrreach] the corpus cannot see any real attack range, and says so']
= function()
    -- If this ever flips, the headline stops being 8 and has to be re-derived
    -- from a corpus that can actually answer GetAttackRange. Asserting it in
    -- BOTH directions means a loader that grows the field goes red, not quiet.
    assert(C('hr_range_live') == 0,
        C('hr_range_live') .. ' frames now report a non-stub attack range. ' ..
        'Good news -- but hr_closes 49 was only ever a loader statement ' ..
        'because of this; re-price the domain before quoting it.')
    assert(C('hr_range_stub') == C('hr_dmg2'),
        'the stub count no longer covers every entered frame')
    -- The trap this whole section exists to spring: the big number is the
    -- loader's, the small one is Dota's.
    assert(C('hr_closes_stubonly') > C('hr_closes_universal'),
        'most of hr_closes used to be the 150 stub talking; if that is no ' ..
        'longer true the reading has changed shape and needs re-writing')
end

tests['[hrreach] the stub column is a real comparison, not a bump'] = function()
    -- M11's lesson, applied before the mutant instead of after: on this corpus
    -- EVERY frame is a stub, so rewriting the hr_range_stub column as an
    -- unconditional bump leaves the manifest byte-identical (84 either way)
    -- and no assertion over the counts can see it. Only a source pin can. The
    -- same reasoning covers hr_range_live, which reads 0 for the same reason.
    local fh = assert(io.open('tests/_lanekill_domain_sweep.lua', 'r'))
    local sweep = fh:read('*a'); fh:close()
    assert(sweep:find("if nMyReach == 150 then bump('hr_range_stub')", 1, true),
        'the hr_range_stub column no longer tests the stub value -- if it is ' ..
        'an unconditional bump the count is meaningless and reads the same')
    assert(sweep:find("else bump('hr_range_live') end", 1, true),
        'hr_range_live is no longer the other arm of that same comparison')
end

-- ============ 5. the asymmetry: priced here, repaired under its own gate next
--
-- ⛔ REWRITTEN 2026-09-09 BY THE ROUND THAT LANDED 'hrparity', which is the
-- outcome this section was built to force -- and it recorded one thing about
-- itself on the way through. THE OLD PIN WOULD NOT HAVE GONE RED. It read
-- `GetNearbyHeroes%( bot, (%d+), false` and asserted the answer was 900; the
-- repair lands as a SECOND ally read inside a gate, leaving the shipped 900
-- first in the body, so the match kept finding 900 and the section kept
-- passing while describing a helper that had changed. A ratchet aimed at an
-- ungated edit does not see a gated one -- which is the only kind this group
-- is allowed to write. The rule that survives: pin what the SHIPPED default
-- still does AND require the repair to be named where it lives.

tests['[hrreach] the second defect is priced here and gated next door'] = function()
    local body = stripped_body()
    local nE = body:match('GetNearbyHeroes%( bot, (%d+), true')
    local nA = body:match('GetNearbyHeroes%( bot, (%d+), false')
    assert(nE == '1100' and nA == '900',
        'the SHIPPED default no longer reads enemies at 1100 and allies at 900 ' ..
        '(got ' .. tostring(nE) .. '/' .. tostring(nA) .. '). The asymmetry ' ..
        'repair is a soak candidate; if it has become the default that is a ' ..
        'promote and both this section and tests/test_hrparity_guard.lua ' ..
        'section 1 have to be rewritten in the same change.')
    -- The repair exists, is gated, and is NOT this id. Two levers in one helper
    -- is the thing the lanefix bundle lesson is about, so it is pinned as a
    -- fact rather than left to whoever reads the diff.
    assert(body:find("IsSoakCandidate%(%s*'hrparity'%s*%)"),
        'the two-radius parity test is unrepaired and no gated repair is ' ..
        'named in this helper -- if the fix was reverted, re-open the reading')
    assert(not body:find("IsSoakCandidate%(%s*'hrreach'%s*%)%s*and"),
        "'hrreach' has gained a conjunct; it is supposed to be one id that " ..
        'can be armed and read in isolation from the parity guard')
    assert(C('hr_asym_flips') > 0,
        'the asymmetry no longer flips any verdict; re-check before citing it')
    assert(C('hr_asym_enemy_band') >= C('hr_asym_flips'),
        'more verdicts flip than there are frames with an enemy in the band')
    -- The 'hrreach' readings this file exists for must be UNDISTURBED by the
    -- sibling landing next to them: same helper, same corpus, same numbers.
    assert(C('hr_closes') == C('hr_fire') - C('hr2_fire')
        and C('hr_closes_universal') == C('hr_fire_d_gt900'),
        'the hrparity guard perturbed the hrreach differential -- the two ' ..
        'levers are supposed to be measurable one at a time')
end

-- ======================================= 6. the witness frame, on real bytes

tests['[hrreach] the witness frame: a melee Axe is sent at a target past 900u']
= function()
    local J, bot = rf.load(WITNESS, WITNESS_HERO)
    J.IsModeTurbo = function() return true end
    J.IsSoakCandidate = function() return false end
    local ok, s, x = pcall(J.GetLaneHarassResponse, bot)
    assert(ok, 'the shipped helper raised on the witness frame: ' .. tostring(s))
    assert(s == 'fire', 'the witness frame no longer returns fire (got ' ..
        tostring(s) .. ') -- pick a new witness before trusting section 6')
    local d = GetUnitToUnitDistance(bot, x)
    assert(d > 900, 'the witness target is only ' .. math.floor(d) ..
        'u away; this frame no longer witnesses the defect')
end

tests['[hrreach] armed, the witness frame stops ordering the unreachable attack']
= function()
    local J, bot = rf.load(WITNESS, WITNESS_HERO)
    J.IsModeTurbo = function() return true end
    J.IsSoakCandidate = function(sId) return sId == 'hrreach' end
    local ok, s = pcall(J.GetLaneHarassResponse, bot)
    assert(ok, 'armed, the helper raised: ' .. tostring(s))
    assert(s == nil, 'armed, the helper still answers ' .. tostring(s) ..
        ' on a frame whose only candidate is out of reach')
end

-- ================================================= 7. gate plumbing (not proof)

tests['[hrreach] outside turbo, and with the id disarmed, nothing moves']
= function()
    -- Gate plumbing is NOT local validation (charter step 4) -- section 6 is.
    -- This only pins that the two structural conjuncts are still conjuncts.
    local J, bot = rf.load(WITNESS, WITNESS_HERO)
    J.IsModeTurbo = function() return false end
    J.IsSoakCandidate = function() return true end
    local ok, s = pcall(J.GetLaneHarassResponse, bot)
    assert(ok and s == 'fire',
        'a normal-mode game no longer gets the shipped answer (got ' ..
        tostring(s) .. ') -- the turbo conjunct has stopped guarding')

    local J2, bot2 = rf.load(WITNESS, WITNESS_HERO)
    J2.IsModeTurbo = function() return true end
    J2.IsSoakCandidate = function(sId) return sId == 'some_other_id' end
    local ok2, s2 = pcall(J2.GetLaneHarassResponse, bot2)
    assert(ok2 and s2 == 'fire',
        'turbo alone now changes the answer with hrreach disarmed')
end

tests['[hrreach] the id appears exactly once in the shipped helper'] = function()
    local body = stripped_body()
    local n = 0
    for _ in body:gmatch("IsSoakCandidate%(%s*'hrreach'%s*%)") do n = n + 1 end
    assert(n == 1, "the helper names 'hrreach' " .. n ..
        ' times in code; it is one lever with one call site')
    -- M3 (order blindness): the guard has to sit ABOVE the shipped weakest
    -- loop, or it becomes a no-op that passes every existence check. Compare
    -- positions rather than merely asserting both exist.
    local atGate = body:find("IsSoakCandidate%(%s*'hrreach'%s*%)")
    local atShipped = body:find('hWeakest, nWeakest = nil, math.huge', 1, true)
    assert(atGate ~= nil and atShipped ~= nil,
        'could not locate both the gate and the shipped weakest loop')
    assert(atGate < atShipped,
        'the hrreach block now sits BELOW the shipped weakest-harasser loop, ' ..
        'so the shipped return runs first and the guard can never fire -- ' ..
        'every existence check still passes, which is the point of this one')
end

return tests

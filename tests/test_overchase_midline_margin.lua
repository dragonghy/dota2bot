-- [overchase] THE BRANCH THAT CARRIES THE GUARD IS THE ONE WITH NO ANCHOR --
-- real-frame validation of leg (b)'s midline margin.
--
-- THE FINDING. J.ShouldPunishOverchase's leg (b) ("the chaser has crossed into
-- OUR territory") is a disjunction of two very different reads:
--
--   HARD:  a LIVE allied building is within 1200 of the chaser.
--   SOFT:  the chaser is closer to our ancient than to theirs by some margin.
--
-- The corpus census (tests/_overchase_sweep.lua, 110 fixtures / 1021 live hero
-- frames) says which one is actually load bearing:
--
--   oc_pairs 794 | oc_deep_building 53 | oc_deep_midline 97
--   oc_iso_deep 50  (of which building 8, midline 42)
--   oc_fire_building 0 | oc_fire_midline 3
--
-- EVERY firing this corpus can witness comes from the SOFT read. Not one comes
-- from the hard one. So the guard is, in practice, entirely a midline guard,
-- and the margin on that line is the guard's real trigger.
--
-- It was 800. That is the shallowest margin in the family -- J.SafeToCommitFight
-- uses 1600 for the SAME ancient-distance convention, and says why in its own
-- header: near the midline, "visible-only parity systematically overestimates
-- safety because fog reinforcements are close". Leg (c) of this guard reads
-- "isolated" off VISIBLE enemies only (J.GetEnemiesNearLoc walks
-- UNIT_LIST_ENEMY_HEROES), so it inherits that failure exactly, and AGENTS.md
-- records the 2v2-that-became-2v4 as a mistake that cost a batch run. The fix
-- adopts the tree's existing number rather than inventing a third one; the HARD
-- branch is untouched, because a live structure of ours is a fact about whose
-- ground this is and is also an ally the numbers branch never counts.
--
-- ⭐ WHY THERE IS NO NEW SOAK ID, and why that is the finding and not a
-- shortcut. This helper is gated on 'overchase', which is NOT promoted. A
-- nested `J.IsSoakCandidate('<new>')` inside it would be the conjunction
-- `overchase AND <new>`; an isolation wave arming <new> alone would read 0, and
-- that 0 is STRUCTURALLY IMPOSSIBLE rather than informative --
-- check_armed_wiring.py answers WIRED anyway (it checks that a call site
-- exists, not that the predicate can be true, GH #606) and the verdict reads
-- back "tested, no effect" with nothing raising a hand. That is the
-- GH #576/#600/#607 family. The previous round established where to PUT a
-- narrowing so its zero stays readable; this is the other half of the same
-- rule: when the host helper is itself an unpromoted candidate, NO placement
-- inside it yields a readable single-arm zero, so the narrowing must edit the
-- host's own body and inherit its id. Shipped play is unchanged either way
-- ('overchase' is un-armed in every real game, so this function returns nil),
-- and a wave arming 'overchase' measures the narrowed guard as ONE arm.
--
-- These are NOT gate-plumbing tests (charter rule 2). Every behavioural reading
-- below comes from driving the SHIPPED J.ShouldPunishOverchase on a real dumped
-- frame and comparing the hero it returns.
--
-- ⚠ LIMITS this corpus cannot close, stated rather than worked around.
--   (1) The mock overrides WasRecentlyDamagedByHero on the real frame, but NOT
--       GetAttackTarget (every unit answers nil) and not the IsRunning /
--       IsFacingLocation pair that J.IsChasingTarget needs. Census:
--       oc_a_attacktarget 0, oc_a_ischasing 0, oc_a_recentdmg 3 -- so ALL of
--       leg (a)'s releases here come from one of its three disjuncts, and the
--       other two are declared-absent, not measured-zero. Filed as GH #613.
--   (2) GetEstimatedDamageToTarget answers 0 on every frame (GH #611), so
--       J.SafeToCommitFight's lethal branch never fires: oc_d_lethal 0 and all
--       three (d) passes are numbers-branch passes.
--   Neither limit touches leg (b), which reads only positions and ancients --
--   ground truth a fixture frame carries exactly.

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')

local JMZ = 'bots/FunLib/jmz_func.lua'

-- POSITIVE CONTROL -- the one firing the narrowing refuses. A 0.72-HP Zeus, a
-- squishy int caster with no escape, turns on a FULL-HP isolated Lion 500u
-- away, counting a 0.44-HP Tidehunter as his second body. The chaser is 1436u
-- past the midline -- inside the old 800 margin, outside the tree's own 1600 --
-- with NO live building of ours within 1200.
local POS = { 'tests/fixtures/f_260820_042607_zuus_reserve_cross.lua',
    'npc_dota_hero_zuus' }
-- NEGATIVE CONTROLS -- the other two firings in the whole corpus. Both are
-- deeper than the new margin, so the narrowing must leave them alone. Two
-- different subjects on one frame, because a guard that stopped firing
-- everywhere would pass a one-frame positive control on its own.
local NEG = {
    { 'tests/fixtures/f_20260827_091703_slot12_zuus_473_1.lua',
        'npc_dota_hero_lina' },
    { 'tests/fixtures/f_20260827_091703_slot12_zuus_473_1.lua',
        'npc_dota_hero_tidehunter' },
}

local function read_file(path)
    local f = assert(io.open(path, 'r'), path .. ' is not readable')
    local s = f:read('*a')
    f:close()
    return s
end

local function block(src, header)
    local at = src:find(header, 1, true)
    if at == nil then return nil end
    local stop = src:find('\nfunction J.', at + 10) or #src
    return src:sub(at, stop)
end

-- Drive the real trigger on a real frame with 'overchase' armed, which is the
-- only arm this lever has.
local function drive(path, hero)
    local J, bot = rf.load(path, hero)
    J.IsSoakCandidate = function(id) return id == 'overchase' end
    return J.ShouldPunishOverchase(bot), J, bot
end

local function hero_name(h)
    if h == nil then return 'nil' end
    return (h:GetUnitName():gsub('npc_dota_hero_', ''))
end

-- The chaser's signed depth in OUR half, in the guard's own convention:
-- positive = closer to our ancient than to theirs by this much.
local function midline_depth(J, u)
    local hOwn, hEnemy = GetAncient(GetTeam()), GetAncient(GetOpposingTeam())
    if hOwn == nil or hEnemy == nil then return nil end
    local v = u:GetLocation()
    return J.GetLocationToLocationDistance(v, hEnemy:GetLocation())
        - J.GetLocationToLocationDistance(v, hOwn:GetLocation())
end

local function nearest_allied_building(J, u)
    local best = nil
    for _, b in pairs(GetUnitList(UNIT_LIST_ALLIED_BUILDINGS) or {}) do
        if J.IsValidBuilding(b) then
            local d = GetUnitToUnitDistance(u, b)
            if best == nil or d < best then best = d end
        end
    end
    return best
end

local tests = {}

-- ---------------------------------------------------------------------------
-- 1. The source says what the finding says: two branches, one tightened.
-- ---------------------------------------------------------------------------

tests['[source] the midline margin is the depthnum convention, not a third number'] = function()
    local chase = block(read_file(JMZ), 'function J.ShouldPunishOverchase( bot )')
    assert(chase ~= nil, 'J.ShouldPunishOverchase is gone from ' .. JMZ)
    local margin = tonumber(chase:match('hEnemyAncient:GetLocation%(%) %) %- (%d+)'))
    assert(margin ~= nil, 'leg (b) no longer has a parseable midline margin; '
        .. 'the census and this file both read that number off the source')

    local safe = block(read_file(JMZ), 'function J.SafeToCommitFight( bot, target )')
    local depthnum = tonumber(safe and safe:match('hOwnAncient:GetLocation%(%) %) %- (%d+)'))
    assert(depthnum ~= nil, "J.SafeToCommitFight's 'depthnum' margin is no "
        .. 'longer parseable; it is the number this lever borrows')

    assert(margin == depthnum, 'the overchase midline margin is ' .. margin
        .. ' but the fog margin the tree already writes for this exact '
        .. 'reasoning is ' .. depthnum .. '. The whole claim of this lever is '
        .. 'that it adopts the existing convention instead of inventing a '
        .. 'third number -- if they have deliberately diverged, move this '
        .. 'assertion and say why in the header.')
end

tests['[source] the HARD building branch is untouched at 1200'] = function()
    local chase = block(read_file(JMZ), 'function J.ShouldPunishOverchase( bot )')
    local r = tonumber(chase:match('building %) <= (%d+)'))
    assert(r == 1200, 'leg (b)\'s building radius is now ' .. tostring(r)
        .. ', not 1200. The narrowing was scoped to the SOFT read on purpose: '
        .. 'a live structure of ours is a hard fact about whose ground this is '
        .. 'and is an uncounted ally. Tightening both is a different lever and '
        .. 'needs its own price.')
end

-- ---------------------------------------------------------------------------
-- 2. [DEFECT] The positive-control frame, driven. The margin is the ONLY thing
--    refusing it -- every other leg of the guard passes on that frame.
-- ---------------------------------------------------------------------------

tests['[DEFECT] the margin is load bearing: every other leg passes on the frame'] = function()
    local got, J, bot = drive(POS[1], POS[2])
    assert(got == nil, 'the narrowed guard now FIRES on the positive-control '
        .. 'frame (returns ' .. hero_name(got) .. '); this lever has no '
        .. 'subject left')

    -- Find the chaser the old margin would have handed back, and show the
    -- refusal is the margin's and nobody else's.
    local chaser = nil
    for _, e in pairs(J.GetNearbyHeroes(bot, 1600, true, BOT_MODE_NONE) or {}) do
        if J.IsValidHero(e) and not J.IsSuspiciousIllusion(e)
            and not J.IsMeepoClone(e) then
            chaser = e
            break
        end
    end
    assert(chaser ~= nil, 'no enemy hero within collapse range on the '
        .. 'positive-control frame any more')
    assert(hero_name(chaser) == 'lion', 'the chaser on this frame is now '
        .. hero_name(chaser) .. ', not the Lion this case was cut around')

    -- (c) ISOLATED still true.
    local n = #J.GetEnemiesNearLoc(chaser:GetLocation(), 1400)
    assert(n <= 1, 'the chaser is no longer isolated (' .. n
        .. ' enemies within 1400); leg (c) is now doing the refusing, not the '
        .. 'margin, and this frame no longer isolates leg (b)')

    -- (d) WINNABLE still true.
    assert(J.SafeToCommitFight(bot, chaser), 'J.SafeToCommitFight now refuses '
        .. 'this engage, so leg (d) is doing the refusing and this frame no '
        .. 'longer isolates leg (b)')

    -- The world facts the claim rests on, asserted rather than restated.
    local depth = midline_depth(J, chaser)
    assert(depth ~= nil, 'no ancients on this frame')
    assert(depth > 800 and depth < 1600, 'the chaser is ' .. string.format('%.0f', depth)
        .. 'u past the midline. This frame exists because that number sits '
        .. 'BETWEEN the old margin (800) and the new one (1600) -- outside '
        .. 'that band it stops being a test of the margin at all.')

    local near = nearest_allied_building(J, chaser)
    assert(near == nil or near > 1200, 'there is now a live allied building '
        .. string.format('%.0f', near or -1) .. 'u from the chaser, so the '
        .. 'HARD branch would carry this frame and the midline margin would be '
        .. 'irrelevant to it')

    -- And the shape that makes the collapse a bad idea: the chaser is healthy,
    -- the subject is not, and the second body is the hero being rescued.
    assert(J.GetHP(chaser) > 0.9, 'the chaser is no longer near-full HP ('
        .. string.format('%.2f', J.GetHP(chaser)) .. '); the case for refusing '
        .. 'was a hurt caster turning on a healthy isolated hero')
    assert(J.GetHP(bot) < 0.8, 'the subject is no longer hurt ('
        .. string.format('%.2f', J.GetHP(bot)) .. ')')
    local nLow, nFit = 0, 0
    for _, a in pairs(J.GetAlliesNearLoc(chaser:GetLocation(), 1200) or {}) do
        if J.IsValidHero(a) then
            if J.GetHP(a) < 0.5 then nLow = nLow + 1 else nFit = nFit + 1 end
        end
    end
    assert(nLow >= 1, 'the numbers branch that admits this engage no longer '
        .. 'counts any sub-50%-HP body; the double count this frame '
        .. 'illustrates is gone')
end

-- ---------------------------------------------------------------------------
-- 3. NEGATIVE CONTROL. The narrowing is a SUBSET, not an off switch.
-- ---------------------------------------------------------------------------

for i, case in ipairs(NEG) do
    local label = '[negative ' .. i .. '] ' .. case[2]:gsub('npc_dota_hero_', '')
        .. ' still collapses -- the narrowing is a subset, not an off switch'
    tests[label] = function()
        local got, J = drive(case[1], case[2])
        assert(got ~= nil, 'the narrowed guard no longer fires on ' .. case[2]
            .. ' in ' .. case[1] .. '. Both remaining corpus firings are '
            .. 'DEEPER than the new margin; if this one stopped, the change '
            .. 'is an off switch and not the narrowing it claims to be.')
        local depth = midline_depth(J, got)
        assert(depth ~= nil and depth >= 1600, 'this control fires with the '
            .. 'chaser only ' .. string.format('%.0f', depth or -1) .. 'u past '
            .. 'the midline, i.e. inside the band the lever refuses; it is no '
            .. 'longer a control for "deeper frames survive".')
    end
end

-- ---------------------------------------------------------------------------
-- 4. The census reading this lever was priced on, pinned so it cannot rot
--    silently. Content-anchored (the 0ADDR lesson): no line numbers.
-- ---------------------------------------------------------------------------

tests['[census] the guard is carried entirely by the soft branch'] = function()
    -- Re-derived here on the two frames the corpus fires on, rather than
    -- re-parsing the sweep's manifest: a pin that reads another tool's output
    -- pins the tool, not the tree.
    for _, case in ipairs({ POS, NEG[1], NEG[2] }) do
        local J, bot = rf.load(case[1], case[2])
        J.IsSoakCandidate = function(id) return id == 'overchase' end
        for _, e in pairs(J.GetNearbyHeroes(bot, 1600, true, BOT_MODE_NONE) or {}) do
            if J.IsValidHero(e) and not J.IsSuspiciousIllusion(e)
                and not J.IsMeepoClone(e) then
                local near = nearest_allied_building(J, e)
                assert(near == nil or near > 1200, case[2] .. ' in ' .. case[1]
                    .. ': a chaser now sits ' .. string.format('%.0f', near)
                    .. 'u from a live building of ours. The census reading this '
                    .. 'lever rests on is oc_fire_building 0 / oc_fire_midline '
                    .. '3 -- if the HARD branch now reaches these frames, the '
                    .. 'claim "the soft read carries the whole guard" needs '
                    .. 're-measuring with tests/_overchase_sweep.lua.')
            end
        end
    end
end

return tests

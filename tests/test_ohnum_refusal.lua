-- [ohnum] A PUNISH WITH NO BUILDING BEHIND IT NEEDS THE NUMBERS -- real-frame
-- validation.
--
-- The defect: J.SafeToCommitFight's numbers branch admits a commit on
-- `#allies >= #enemies`. That floor was written for the SHIPPED punish domain,
-- where the target is by construction within 1200 of one of our live buildings
-- -- the tower is the ally the count never names, so "parity" there is parity
-- plus a tower. The 'ownhalf' extension keeps the same floor while removing the
-- building (its whole point is the dead zone between the river and T1-1200),
-- and the floor then carries most of the widened domain.
--
-- These are NOT gate-plumbing tests (charter rule 2). Every behavioural reading
-- below comes from driving the SHIPPED J.ShouldPunishDive on a real dumped
-- frame, in named arms, and comparing the hero it returns.
--
-- CORPUS (tests/_ohnum_sweep.lua, 110 fixtures / 1021 live hero frames):
--   pd_shipped 28 | pd_ownhalf 79 | pd_ownhalf_only 51
--   domain_parity 31 / domain_advantage 20   (of the 51)
--   both_changed 31, and all 31 are both_to_nil -- both_switched is 0
--   ohnum_alone_changed 0 over the 28 shipped fires
--
-- ⭐ WHY `ohnum_alone_changed 0` IS A MEASUREMENT AND NOT A STRUCTURAL ZERO,
-- which is the whole reason the call site sits where it does. The conjunct
-- joins the SHIPPED path (`bInDomain and SafeToCommitFight and not <this>`),
-- not the 'ownhalf' branch, and the helper decides from the WORLD -- is there a
-- live allied building within 1200 of the target -- rather than from the other
-- gate. So a wave arming 'ohnum' alone really does reach it, and reads zero
-- because the shipped domain is building-proximate by construction. Had the
-- call site been placed inside the 'ownhalf' branch, that same zero would have
-- been unreadable: `check_armed_wiring.py` would still answer WIRED (it checks
-- that a call site exists, not that the predicate can be true) and the verdict
-- would read back "tested, no effect" with nothing raising a hand. That is the
-- gate-inside-gate shape GH #576 / #600 / #607 keep filing.
--
-- ⚠ TWO LIMITS, stated because the corpus cannot close them.
--   (1) The mock's GetEstimatedDamageToTarget answers 0 on EVERY fixture frame,
--       so this helper's LETHAL release can never fire in any reading quoted
--       here (`lethal_release 0`) and all 51 domain frames are numbers-branch
--       frames. The 31 refusals are therefore an UPPER BOUND on what a live
--       game refuses -- in a real frame a burst-lethal target is released and
--       kept. The clearest instance is in the corpus itself:
--       f_260820_043124_axe_blink_kill refuses a 16%-HP Wraith King, which is a
--       kill a live burst read would very likely have kept. The release is
--       asserted here by source and by tools/agent/mutstand_ohnum.sh, not
--       witnessed on a frame.
--   (2) `bot:GetAttackRange()` answers 150 for every hero in the mock, so
--       nothing here reads whether the punisher can actually reach its target.
--       That question belongs to 'roamreach' and is not this lever's.

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')

-- POSITIVE CONTROL. Skywrath Mage at 24% HP turns on an 89%-HP Axe 188u away,
-- 3,092u from the nearest live building of ours, on a visible 2v2. Axe is the
-- counter-initiator in that fight; "parity" is the only thing admitting it.
local POS = { 'tests/fixtures/f_260820_043637_axe_ring_close.lua',
    'npc_dota_hero_skywrath_mage' }
-- NEGATIVE CONTROL A -- advantage, in the SAME extended domain: three of ours
-- around a lone Slardar. The lever must not touch this one.
local NEG_ADV = { 'tests/fixtures/f_20260827_091703_slot12_zuus_473_1.lua',
    'npc_dota_hero_tidehunter' }
-- NEGATIVE CONTROL B -- the shipped domain, on a frame the corpus itself named
-- `parity`: same numbers, but a live building of ours is right there, so the
-- helper releases and the PROMOTED punish is untouched.
local NEG_SHIPPED = { 'tests/fixtures/f_260819_183613_storm_collapse_parity.lua',
    'npc_dota_hero_axe' }

local ARMS = {
    shipped = {},
    ohnum = { ohnum = true },
    ownhalf = { ownhalf = true },
    both = { ownhalf = true, ohnum = true },
}

-- Drive the real trigger on a real frame in every arm. Returns the four target
-- heroes plus the loaded (J, bot) so a test can ask the frame further questions.
local function drive(path, hero)
    local J, bot = rf.load(path, hero)
    local armed = {}
    J.IsSoakCandidate = function(id) return armed[id] == true end
    local got = {}
    for name, set in pairs(ARMS) do
        armed = set
        got[name] = J.ShouldPunishDive(bot)
    end
    return got, J, bot
end

local function hero_name(h)
    if h == nil then return 'nil' end
    return (h:GetUnitName():gsub('npc_dota_hero_', ''))
end

local function read_file(path)
    local f = assert(io.open(path, 'r'), path .. ' is not readable')
    local s = f:read('*a')
    f:close()
    return s
end

-- Long-comment form first, then line comments -- the other order leaves the
-- `--[[` opener's own line stripped and its body behind. (The lesson
-- test_pgchannel_veto.lua paid for: a call site is CODE, and a count that does
-- not strip comments reddens over prose while still missing a real call site
-- hidden in a `--[[ ]]` block.)
local function strip_lua_comments(src)
    src = src:gsub('%-%-%[%[.-%]%]', ' ')
    return (src:gsub('%-%-[^\n]*', ' '))
end

-- Nearest live allied building to a unit, so a test can state the world fact
-- its claim rests on instead of asserting the claim twice.
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

tests['[frame] the positive-control frame really is the case it claims'] = function()
    local got, J, bot = drive(POS[1], POS[2])
    local tgt = got.ownhalf
    assert(tgt ~= nil, 'the ownhalf arm no longer returns a punish target on '
        .. 'the positive-control frame; this lever has no subject there')
    assert(hero_name(tgt) == 'axe', 'the ownhalf arm now punishes '
        .. hero_name(tgt) .. ', not the Axe this case was cut around')
    assert(got.shipped == nil, 'the SHIPPED domain now fires on the '
        .. 'positive-control frame, so it is no longer an ownhalf-only frame '
        .. 'and this case is measuring something else')

    local near = nearest_allied_building(J, tgt)
    assert(near ~= nil and near > 1200, 'the nearest live allied building to '
        .. 'the target is now ' .. tostring(near) .. 'u; above 1200 is the '
        .. 'world fact that makes this an unsupported punish')

    local vLoc = tgt:GetLocation()
    local nA = #J.GetAlliesNearLoc(vLoc, 1200)
    local nE = #J.GetEnemiesNearLoc(vLoc, 1200)
    assert(nA == 2 and nE == 2, 'the engage point now reads ' .. nA .. ' allies '
        .. 'v ' .. nE .. ' enemies, not the 2-v-2 parity this case pins')
    assert(J.GetHP(bot) < 0.30, 'the punisher is no longer the low-HP Skywrath '
        .. 'this case was cut around (HP ' .. tostring(J.GetHP(bot)) .. ')')
end

tests['[frame] armed, the unsupported parity punish is refused'] = function()
    local got = drive(POS[1], POS[2])
    assert(got.both == nil, 'both arms armed, the punish target is still '
        .. hero_name(got.both) .. '; the refusal did not fire')
end

tests['[frame] direction: armed can only REMOVE a target, never add one'] = function()
    -- The conjunct joins as `and not <this>`, so this is true by construction --
    -- pinned anyway, because "by construction" is what the lanefix bundle also
    -- said. Checked on every named frame in this file, in every arm pair.
    for _, cse in ipairs({ POS, NEG_ADV, NEG_SHIPPED }) do
        local got = drive(cse[1], cse[2])
        assert(not (got.shipped == nil and got.ohnum ~= nil), cse[1]
            .. ': arming ohnum ADDED a punish target (' .. hero_name(got.ohnum)
            .. ') where the shipped tree had none')
        assert(not (got.ownhalf == nil and got.both ~= nil), cse[1]
            .. ': arming ohnum on top of ownhalf ADDED a punish target ('
            .. hero_name(got.both) .. ') where ownhalf alone had none')
    end
end

tests['[frame] negative control: numbers advantage keeps the punish'] = function()
    local got, J = drive(NEG_ADV[1], NEG_ADV[2])
    assert(got.ownhalf ~= nil, NEG_ADV[1] .. ' no longer fires under ownhalf')
    local vLoc = got.ownhalf:GetLocation()
    local nA = #J.GetAlliesNearLoc(vLoc, 1200)
    local nE = #J.GetEnemiesNearLoc(vLoc, 1200)
    assert(nA >= nE + 1, 'this control is supposed to hold the ADVANTAGE case; '
        .. 'it now reads ' .. nA .. ' v ' .. nE)
    assert(nearest_allied_building(J, got.ownhalf) > 1200,
        'this control is supposed to be an UNSUPPORTED punish that survives on '
        .. 'numbers alone; a building has come within 1200 of the target, so it '
        .. 'is now released for the other reason and proves nothing')
    assert(got.both == got.ownhalf, 'the refusal fired on a numbers ADVANTAGE ('
        .. nA .. ' v ' .. nE .. '); it is supposed to refuse parity only')
end

tests['[frame] negative control: the shipped domain is untouched'] = function()
    local got, J = drive(NEG_SHIPPED[1], NEG_SHIPPED[2])
    assert(got.shipped ~= nil, NEG_SHIPPED[1] .. ' no longer fires on the '
        .. 'shipped (PROMOTED) path; this control has lost its subject')
    assert(nearest_allied_building(J, got.shipped) <= 1200,
        'the shipped-domain target is no longer within 1200 of a live allied '
        .. 'building -- the release this control exercises is not the one '
        .. 'being exercised any more')
    assert(got.ohnum == got.shipped, "arming 'ohnum' ALONE changed the shipped "
        .. 'punish target to ' .. hero_name(got.ohnum) .. '; the building '
        .. 'release is the only thing standing between this lever and the '
        .. 'PROMOTED trigger')
    -- ...and it is a parity frame, so the release doing the work here really is
    -- the building and not the numbers.
    local vLoc = got.shipped:GetLocation()
    assert(#J.GetAlliesNearLoc(vLoc, 1200) <= #J.GetEnemiesNearLoc(vLoc, 1200),
        'this control is chosen for being a PARITY frame inside the shipped '
        .. 'domain; it now has the numbers, so the building release is no '
        .. 'longer the thing being tested')
end

tests['[gate] the helper is turbo-only and gated, with one call site'] = function()
    local jmz = read_file('bots/FunLib/jmz_func.lua')
    local at = jmz:find('function J.ShouldRefuseUnsupportedPunish( bot, target )', 1, true)
    assert(at, 'J.ShouldRefuseUnsupportedPunish is gone from jmz_func.lua')
    local body = jmz:sub(at, (jmz:find('\nfunction J.', at + 10) or #jmz))
    assert(body:find("J.IsSoakCandidate( 'ohnum' )", 1, true),
        'the helper no longer carries its own ohnum gate')
    assert(body:find('J.IsModeTurbo()', 1, true),
        'the helper is no longer turbo-only')
    assert(body:find('UNIT_LIST_ALLIED_BUILDINGS', 1, true),
        'the building release is gone from the helper; without it this lever '
        .. 'narrows the PROMOTED shipped punish as well')
    assert(body:find('J.GetTotalEstimatedDamageToTarget', 1, true),
        'the LETHAL release is gone from the helper; without it a confirmed '
        .. 'burst kill is refused for want of a head count')

    -- Comment-stripped, because a call site is CODE and this count is the whole
    -- assertion.
    local stripped = strip_lua_comments(jmz)
    local _, n = stripped:gsub('J%.ShouldRefuseUnsupportedPunish%( bot, enemy %)', '')
    assert(n == 1, 'expected exactly one call site in jmz_func.lua, found '
        .. tostring(n) .. ' -- one lever, one call site')
    local _, nAll = stripped:gsub('ShouldRefuseUnsupportedPunish', '')
    assert(nAll == 2, 'ShouldRefuseUnsupportedPunish appears ' .. tostring(nAll)
        .. ' times in stripped source; exactly the definition plus the one '
        .. 'call site was expected')
    for _, f in ipairs({ 'bots/mode_team_roam_generic.lua',
        'bots/mode_retreat_generic.lua' }) do
        local _, k = strip_lua_comments(read_file(f)):gsub(
            'ShouldRefuseUnsupportedPunish', '')
        assert(k == 0, f .. ' has grown a consumer of this helper; the "one '
            .. 'lever, one call site" claim above is scoped to jmz_func.lua '
            .. 'and a second consumer must bring its own reading')
    end
end

tests['[source] the call site joins the SHIPPED path, not the ownhalf branch'] = function()
    -- The placement IS the readability argument (see this file's header). If a
    -- later edit moves the call inside `if ... bOwnHalf ...`, the lever becomes
    -- a conjunction of two ids and its single-arm zero stops being a
    -- measurement -- so the placement is pinned, not just commented.
    local dive = strip_lua_comments(read_file('bots/FunLib/jmz_func.lua'))
    local at = dive:find('function J.ShouldPunishDive( bot )', 1, true)
    assert(at, 'J.ShouldPunishDive is gone')
    local body = dive:sub(at, (dive:find('\nfunction J.', at + 10) or #dive))
    local call = body:find('ShouldRefuseUnsupportedPunish', 1, true)
    local ownhalf_branch = body:find('nInvadeDepth >= 800', 1, true)
    local safe = body:find('J.SafeToCommitFight( bot, enemy )', 1, true)
    assert(call and ownhalf_branch and safe,
        'the call, the ownhalf depth test or the commit gate is missing')
    assert(call > safe, 'the refusal is now evaluated BEFORE '
        .. 'J.SafeToCommitFight, i.e. it has been moved off the shared commit '
        .. 'line and into the ownhalf branch above it -- that makes the lever '
        .. '`ownhalf AND ohnum`, and its single-arm zero stops being a '
        .. 'measurement (call at ' .. call .. ', depth test at '
        .. ownhalf_branch .. ', commit gate at ' .. safe .. ')')
    assert(call - safe < 200, 'the refusal has drifted away from the '
        .. '`bInDomain and SafeToCommitFight` commit line it is supposed to be '
        .. 'conjoined with')
end

tests['[source] the two 1200 radii are the same number'] = function()
    -- The helper repeats the shipped punish radius rather than sharing it (so
    -- it can answer for a future caller that did not come through
    -- ShouldPunishDive). Repeated numbers drift; this is the pin that says so.
    local jmz = read_file('bots/FunLib/jmz_func.lua')
    local function block(header)
        local at = jmz:find(header, 1, true)
        assert(at, header .. ' is gone')
        return jmz:sub(at, (jmz:find('\nfunction J.', at + 10) or #jmz))
    end
    local dive = tonumber(block('function J.ShouldPunishDive( bot )')
        :match('building %) <= (%d+)'))
    local refuse = tonumber(block(
        'function J.ShouldRefuseUnsupportedPunish( bot, target )')
        :match('building %) <= (%d+)'))
    assert(dive ~= nil and refuse ~= nil, 'one of the two building radii no '
        .. 'longer parses (' .. tostring(dive) .. ' / ' .. tostring(refuse)
        .. '); a failed parse is not a zero')
    assert(dive == refuse, 'the shipped punish radius is ' .. dive .. ' but '
        .. 'the refusal releases at ' .. refuse .. '; a target between the two '
        .. 'is in the shipped domain AND treated as unsupported')
end

return tests

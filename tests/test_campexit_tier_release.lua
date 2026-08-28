-- GH #265 follow-up (replay desk 2026-08-28T03:52Z). The pre-registered
-- falsification on #265 fired: the ancient-camp waste is NOT an armed-leg leak,
-- it reproduces on the FACTORY leg -- 25 episodes in the 10..11 band, mean 10.4pp
-- of the bot's own health burned, 36% of them burning more than 10pp, most with
-- no enemy hero anywhere near. Gated soak candidate 'campexit' (turbo-only) is
-- the first id that reaches that population.
--
-- THE ARITHMETIC THE BAND IS MADE OF
-- ----------------------------------
-- bots/mode_farm_generic.lua states the ancient tier twice, as the literal 10:
--
--     ( bot:GetLevel() >= 10 or not nNeutrals[1]:IsAncientCreep() )
--
-- while this repo's declared tier is J.Site.ANCIENT_MIN_LEVEL = 12 -- the value
-- 'campfarm', 'campgrade', 'abilanc' and 'abil1st' all read. The measured band is
-- exactly {10, 11}: the levels between the file's own literal and the ladder's
-- number. That is a relation between two constants, so it is asserted below as
-- arithmetic rather than sampled on a frame.
--
-- ⭐ THE REUSABLE CRITERION, and why the lever is NOT "raise the two literals".
-- A guard is only worth raising if the branch it guards is the branch that acts.
-- Here it is not. Think()'s THIRD neutral read -- the 1000u `neutralCreeps`
-- branch -- carries no tier clause at all, and it is the branch a level 10-11 bot
-- lands in: the `#nNeutrals >= 3` latch passes its own `>= 10` test, sets
-- FARM_STATE_FARM, and every later frame falls straight through the two guarded
-- branches into the unguarded one. So the two `>= 10` clauses are DECORATIVE
-- whenever an ancient is inside the sweep, and a fix that only corrects their
-- constant would arm, measure nothing, and read back as "tested, no effect" --
-- with nothing raising a hand. Failure direction: a NO-OP that looks like a
-- verdict. (aba_site.lua's own FilterFarmNeutrals header has said "the third
-- read carries no ancient clause at all" since GH #137; nobody had acted on it.)
--
-- WHY IT RELEASES INSTEAD OF REFUSING. One round old: 'campfarm' armed emptied
-- the attack list and gave the bot no reason to leave, and GH #265 photographed
-- the deadlock. So armed, the call site retires the camp and walks to the next
-- one -- the shipped UpdateAvailableCamp + re-pick path, not a new one.
--
-- WHAT THIS FILE CAN AND CANNOT BUY LOCALLY -- read before trusting a number
-- --------------------------------------------------------------------------
-- The SUBJECT half is real: four heroes off real .dem frames at the four levels
-- that matter -- L4 (deep under the tier), L10 and L11 (the measured band, i.e.
-- the two levels the shipped literal admits and the ladder refuses) and L12 (one
-- above the tier, where armed must be inert). Level is the only bot operand the
-- predicate reads besides the sweep.
--
-- The CREEP half is NOT in the corpus and is not pretended to be: [world W1]
-- asserts both neutral sweep APIs answer `{}` on every fixture. The creeps below
-- are a DECLARED STAND-IN carrying exactly the fields the shipped code reads. No
-- count here is corpus data except the ones marked [domain].
--
-- NOT END TO END, and the reason is an assertion rather than a footnote: see
-- [limit reach].

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')
local api = require('mock.bot_api')

local tests = {}

local FARM_SRC = 'bots/mode_farm_generic.lua'
local FUNC_SRC = 'bots/FunLib/jmz_func.lua'

-- The four levels the arithmetic above names. L10/L11 are the band the replay
-- desk actually measured on the factory leg; L4 is GH #265's fatal frame; L12 is
-- the control the lever must never touch.
local ES_L4  = { 'tests/fixtures/f_232228_wk_ownhalf_standoff.lua', 'npc_dota_hero_earthshaker', 4 }
local BB_L10 = { 'tests/fixtures/f_080225_wk_revive.lua',           'npc_dota_hero_bristleback', 10 }
local BB_L11 = { 'tests/fixtures/f_181441_zuus_lowhp_limbo.lua',    'npc_dota_hero_bristleback', 11 }
local BB_L12 = { 'tests/fixtures/f_181544_storm_escape_tp.lua',     'npc_dota_hero_bristleback', 12 }

local BAND         = { BB_L10, BB_L11 }
local UNDER_TIER   = { ES_L4, BB_L10, BB_L11 }
local ALL_SUBJECTS = { ES_L4, BB_L10, BB_L11, BB_L12 }

local function subject(spec)
    local J, _, heroes = rf.load(spec[1], spec[2])
    -- GH #91 ratchet: mode_farm_generic carries a defence-ping guard in its own
    -- source, so a file that reads this mode has to say which world it assumed.
    -- 'stale' is the ordinary case and the right one here: this lever is about
    -- what a bot ALREADY farming a camp does with it, not about a lane under
    -- attack -- a 'fresh' world kills the farm bid outright and the frames below
    -- would be describing a mode the bot is not in.
    rf.declare_defend_ping(J, 'stale')
    local bot = heroes[spec[2]]
    assert(bot ~= nil, 'fixture no longer carries ' .. spec[2] .. ' -- ' .. spec[1])
    assert(bot:GetLevel() == spec[3], string.format(
        'the frame moved: %s used to carry %s at level %d, now %d',
        spec[1], spec[2], spec[3], bot:GetLevel()))
    return J, bot
end

local function label(spec)
    return spec[2]:gsub('npc_dota_hero_', '') .. ' L' .. spec[3]
end

-- A declared neutral, carrying exactly the fields FilterFarmNeutrals and
-- J.IsRoshan read.
local function creep(bot, sName, nHealth, bAncient, dist)
    local loc = bot:GetLocation()
    local d = (dist or 300) / math.sqrt(2)
    return api.MakeUnit({
        GetUnitName = sName,
        GetHealth = nHealth,
        GetMaxHealth = nHealth,
        IsAncientCreep = bAncient,
        IsNull = false,
        CanBeSeen = true,
        IsAlive = true,
        IsInvulnerable = false,
        IsHero = false,
        GetLocation = api.Vector(loc.x + d, loc.y + d, 0),
    })
end

-- The Prowler camp of the venomancer frame (L10, t=786.3, 15.0s stationary,
-- 1007 damage out / 898 in): ancients only, nothing else in range.
local function prowler_camp(bot)
    return {
        creep(bot, 'npc_dota_neutral_prowler_shaman',  1100, true, 250),
        creep(bot, 'npc_dota_neutral_prowler_acolyte',  850, true, 300),
        creep(bot, 'npc_dota_neutral_prowler_acolyte',  850, true, 330),
    }
end

-- ⭐ THE DISCRIMINATING INPUT, written before the fix and not after it. An
-- ancient camp and a normal camp inside one sweep. Here "the ladder refuses
-- everything here" and "the ladder refuses something here" give DIFFERENT
-- answers, so a mutation that fires on the mere PRESENCE of an ancient -- the
-- natural way to write this predicate wrong, and strictly worse behaviour, since
-- it walks a bot away from a camp it is allowed to take -- dies here and nowhere
-- else. (The lesson of the 2026-08-27T19:29Z round, applied up front.)
local function mixed_sweep(bot)
    return {
        creep(bot, 'npc_dota_neutral_prowler_shaman', 1100, true,  250),
        creep(bot, 'npc_dota_neutral_ogre_mauler',     550, false, 300),
        creep(bot, 'npc_dota_neutral_prowler_acolyte', 850, true,  330),
    }
end

local function normals_only(bot)
    return {
        creep(bot, 'npc_dota_neutral_ogre_mauler', 550, false, 260),
        creep(bot, 'npc_dota_neutral_ogre_magi',   450, false, 300),
    }
end

local function empty_sweep() return {} end

-- Roshan is an ancient-class unit that is nobody's farm camp. If the predicate
-- ever fires on him it would end a branch it has no business ending.
local function roshan_sweep(bot)
    return {
        creep(bot, 'npc_dota_roshan', 6000, true, 260),
    }
end

local ALL_SWEEPS = { prowler_camp, mixed_sweep, normals_only, empty_sweep, roshan_sweep }

local function names(list)
    local out = {}
    for i, u in ipairs(list) do out[i] = u:GetUnitName() end
    return '[' .. table.concat(out, ',') .. ']'
end

local function read(path)
    local f = assert(io.open(path, 'r'))
    local s = f:read('*a')
    f:close()
    return s
end

local function strip_comments(src)
    src = src:gsub('%-%-%[%[.-%]%]', ' ')
    return (src:gsub('%-%-[^\n]*', ' '))
end

-- The third neutral branch of Think(), from the sweep this lever sits on down to
-- the end of the farm block. Everything asserted about "the branch" is read out
-- of this slice, so a reshape shows up as a missing match rather than as a
-- silently vacuous test.
local function third_branch(code)
    return code:match('local tNearbyCreeps.-\n%s*end%s*\n%s*end%s*\n')
        or code:match('local tNearbyCreeps.*')
end

--============================================================================
-- The arithmetic the band is made of. Two constants, so: asserted, not sampled.
--============================================================================

tests['[ratchet][source] the farm file says 10 twice while the ladder says 12'] = function()
    local code = strip_comments(read(FARM_SRC))
    local _, nLiteral = code:gsub('bot:GetLevel%(%)%s*>=%s*10%s*or%s*not%s*nNeutrals%[1%]:IsAncientCreep%(%)', '')
    assert(nLiteral == 2, 'the shipped ancient guards moved: found ' .. nLiteral ..
        ' of them, not 2 -- re-read which levels the band is made of before ' ..
        'trusting anything below')

    local site = strip_comments(read('bots/FunLib/aba_site.lua'))
    local nTier = tonumber(site:match('ANCIENT_MIN_LEVEL%s*=%s*(%d+)'))
    assert(nTier == 12, 'ANCIENT_MIN_LEVEL is now ' .. tostring(nTier) ..
        ' -- the band this lever owns changed size')

    -- and the measured band is EXACTLY the gap between the two numbers
    local band = {}
    for lvl = 10, nTier - 1 do band[#band + 1] = lvl end
    assert(#band == 2 and band[1] == 10 and band[2] == 11,
        'the gap between the shipped literal and the ladder is no longer {10,11}')
end

tests['[ratchet][source] the third neutral branch carries no tier clause of its own'] = function()
    -- This is why raising the two literals would be a no-op. Read off the slice,
    -- not argued: the branch that acts asks no level question except through the
    -- lever itself.
    local code = strip_comments(read(FARM_SRC))
    local blk = third_branch(code)
    assert(blk, 'the third neutral branch was reshaped -- re-read it before ' ..
        'trusting the no-op argument above')
    assert(blk:find('J%.Site%.FindFarmNeutralTarget'),
        'the third branch no longer selects a farm target -- wrong slice')
    assert(not blk:find('IsAncientCreep'),
        'the third branch grew an ancient clause of its own -- if that is the ' ..
        'real fix, this lever is redundant and should be retired, not kept')
    -- the only level read in the whole branch is the one this lever passes in
    local _, nLevel = blk:gsub('GetLevel%s*%(%s*%)', '')
    assert(nLevel == 0, 'the third branch now reads GetLevel ' .. nLevel ..
        ' times directly -- the tier question moved and this file has not')
end

tests["[today's defect] the latch admits exactly the measured band"] = function()
    -- The shipped latch clause, transcribed: `bot:GetLevel() >= 10 or not
    -- nNeutrals[1]:IsAncientCreep()`. On an ancients-only sweep the second
    -- disjunct is false, so the latch is the level test alone. Driven against
    -- REAL levels off real frames, not against a restated constant.
    local function shipped_latch_passes(bot, sweep)
        return bot:GetLevel() >= 10 or not sweep[1]:IsAncientCreep()
    end
    for _, spec in ipairs(BAND) do
        local _, bot = subject(spec)
        assert(shipped_latch_passes(bot, prowler_camp(bot)), label(spec) ..
            ': the shipped latch no longer admits this level -- the band moved')
    end
    local _, es = subject(ES_L4)
    assert(not shipped_latch_passes(es, prowler_camp(es)),
        'level 4 now passes the shipped latch -- the band moved')
    -- and the ladder refuses all three, which is the disagreement
    for _, spec in ipairs(UNDER_TIER) do
        local J, bot = subject(spec)
        assert(#J.Site.FilterFarmNeutrals(prowler_camp(bot), bot:GetLevel(), true) == 0,
            label(spec) .. ': the ladder no longer refuses this camp')
    end
end

--============================================================================
-- The fix.
--============================================================================

tests['[fix] armed under the tier, an ancients-only camp is released'] = function()
    for _, spec in ipairs(UNDER_TIER) do
        local J, bot = subject(spec)
        assert(J.IsOverTierCampOnly(bot, prowler_camp(bot), true), label(spec) ..
            ': armed, the over-tier camp was not released')
    end
end

tests['[fix] ⭐ discriminating: one farmable normal creep and the bot STAYS'] = function()
    -- The whole point of "every unit" rather than "any unit". A mutation that
    -- fires on the presence of an ancient passes every ancients-only case above
    -- and dies here: with an ogre still in range there IS something this bot may
    -- take, and walking away would be strictly worse than the defect.
    for _, spec in ipairs(UNDER_TIER) do
        local J, bot = subject(spec)
        local sweep = mixed_sweep(bot)
        assert(not J.IsOverTierCampOnly(bot, sweep, true), label(spec) ..
            ': armed walked away from a sweep that still held ' .. names(sweep))
        -- and the thing it would have stayed for really is farmable
        local kept = J.Site.FilterFarmNeutrals(sweep, bot:GetLevel(), true)
        assert(#kept == 1 and kept[1]:GetUnitName() == 'npc_dota_neutral_ogre_mauler',
            label(spec) .. ': the survivor is not the ogre -- ' .. names(kept))
    end
end

tests['[fix] at the tier armed is inert -- the camp is his to take'] = function()
    local J, bot = subject(BB_L12)
    for _, mk in ipairs(ALL_SWEEPS) do
        assert(not J.IsOverTierCampOnly(bot, mk(bot), true),
            'level 12 armed released ' .. names(mk(bot)))
    end
end

tests['[fix] unarmed is false everywhere, and nil behaves like false'] = function()
    for _, spec in ipairs(ALL_SUBJECTS) do
        local J, bot = subject(spec)
        for _, mk in ipairs(ALL_SWEEPS) do
            local sweep = mk(bot)
            assert(J.IsOverTierCampOnly(bot, sweep, false) == false,
                label(spec) .. ': unarmed fired on ' .. names(sweep))
            assert(J.IsOverTierCampOnly(bot, sweep, nil) == false,
                label(spec) .. ': a nil gate must behave exactly like false')
        end
    end
end

tests['[fix] an empty sweep is not a camp to leave'] = function()
    -- Standing nowhere near anything is not this lever's business: firing here
    -- would retire a camp on every frame a bot is walking to one.
    for _, spec in ipairs(ALL_SUBJECTS) do
        local J, bot = subject(spec)
        assert(not J.IsOverTierCampOnly(bot, {}, true), label(spec) ..
            ': armed fired on an empty sweep')
        assert(not J.IsOverTierCampOnly(bot, nil, true), label(spec) ..
            ': armed fired on a nil sweep')
    end
end

tests['[fix] Roshan is not an over-tier camp'] = function()
    for _, spec in ipairs(UNDER_TIER) do
        local J, bot = subject(spec)
        assert(not J.IsOverTierCampOnly(bot, roshan_sweep(bot), true), label(spec) ..
            ': armed treated Roshan as a camp to walk away from')
        -- and the exclusion is Roshan-specific, not "one unit is never a camp"
        local one = { creep(bot, 'npc_dota_neutral_prowler_shaman', 1100, true, 260) }
        assert(J.IsOverTierCampOnly(bot, one, true), label(spec) ..
            ': a single ancient stopped counting -- the Roshan test is passing ' ..
            'for the wrong reason')
    end
end

tests['[fix] ⭐ grid: armed is exactly "non-empty, no Roshan, ladder keeps nothing"'] = function()
    -- The predicate stated as a grid over every subject x every sweep, so it
    -- cannot drift into something narrower or wider without a count changing.
    local nFired, nCells = 0, 0
    for _, spec in ipairs(ALL_SUBJECTS) do
        local J, bot = subject(spec)
        for _, mk in ipairs(ALL_SWEEPS) do
            local sweep = mk(bot)
            nCells = nCells + 1
            local fired = J.IsOverTierCampOnly(bot, sweep, true)
            local kept = J.Site.FilterFarmNeutrals(sweep, bot:GetLevel(), true)
            local bRoshan = false
            for _, u in ipairs(sweep) do
                if u:GetUnitName():find('roshan', 1, true) then bRoshan = true end
            end
            local expect = (#sweep > 0) and (not bRoshan) and (#kept == 0)
            assert(fired == expect, label(spec) .. ' / ' .. names(sweep) ..
                ': predicate said ' .. tostring(fired) .. ', the three conditions say ' ..
                tostring(expect))
            if fired then nFired = nFired + 1 end
        end
    end
    assert(nCells == 20, 'grid changed size: ' .. nCells)
    -- and the grid really does separate the legs: the three under-tier subjects
    -- x the one ancients-only sweep, and nothing else.
    assert(nFired == 3, 'expected exactly 3 cells to fire, got ' .. nFired ..
        ' -- if this is 0 the grid stopped exercising the lever at all')
end

--============================================================================
-- Structure: one gate, turbo-only, not chained, and it always issues an action.
--============================================================================

tests['[source] the gate is turbo-only, on campexit, resolved once'] = function()
    local code = strip_comments(read(FARM_SRC))
    local blk = third_branch(code)
    assert(blk, 'the third neutral branch was reshaped')
    assert(blk:find('J%.IsModeTurbo%s*%(%s*%)'), 'the lever must be turbo-only')
    assert(blk:find("J%.IsSoakCandidate%s*%(%s*'campexit'%s*%)"),
        "the lever must be gated on 'campexit'")
    local _, nGates = code:gsub("J%.IsSoakCandidate%s*%(%s*'campexit'%s*%)", '')
    assert(nGates == 1, "'campexit' is resolved in " .. nGates .. ' places -- a ' ..
        'second resolution point is a second gate to keep in step')
    local _, nCalls = code:gsub('J%.IsOverTierCampOnly%s*%(', '')
    assert(nCalls == 1, 'J.IsOverTierCampOnly has ' .. nCalls .. ' call sites here, not 1')
    -- and the raw sweep really is the raw one: campexit reads the world, not
    -- campfarm's filtered view of it
    assert(blk:find('J%.IsOverTierCampOnly%s*%(%s*bot%s*,%s*tNearbyCreeps'),
        'campexit is no longer fed the raw sweep -- armed campfarm would then ' ..
        'silently switch it off')
    assert(blk:find('NeutralFarmList%s*%(%s*bot%s*,%s*tNearbyCreeps%s*%)'),
        'the campfarm wrapper no longer consumes the same sweep')
end

tests['[source] campexit is NOT conjoined with campfarm or campvoid (the pullcad trap)'] = function()
    -- AGENTS.md: promoting an id freezes FALSE any gate that names it. All three
    -- sit on the same file and the same tier, so they must arm and promote
    -- independently.
    local code = strip_comments(read(FARM_SRC))
    local blk = third_branch(code)
    local gate = blk:match('if%s+J%.IsOverTierCampOnly.-then')
    assert(gate, 'the campexit gate expression was reshaped')
    assert(not gate:find('campfarm') and not gate:find('campvoid'),
        "campexit's gate names another candidate -- promoting that one would " ..
        'freeze campexit FALSE in every wave')
    for _, w in ipairs({ 'NeutralFarmList', 'NeutralPresenceList' }) do
        local body = code:match('local function ' .. w .. '.-\nend')
        assert(body, w .. ' is gone or reshaped')
        assert(not body:find('campexit'), w .. "'s gate now names 'campexit'")
    end
    local fn = strip_comments(read(FUNC_SRC))
    local body = fn:match('function J%.IsOverTierCampOnly.-\nend\n')
    assert(body, 'J.IsOverTierCampOnly is gone or reshaped')
    assert(not body:find('IsSoakCandidate'),
        'the helper resolves a gate of its own -- the gate lives at the call site')
end

tests['[ratchet][source] armed ALWAYS issues an action -- this is a release, not a refusal'] = function()
    -- GH #265's whole lesson. A branch that stops attacking without commanding
    -- anything leaves the previous order running and manufactures the deadlock
    -- again. Both arms of the armed block must command, and the block must end
    -- in a return so nothing downstream re-enters the camp on the same frame.
    local code = strip_comments(read(FARM_SRC))
    local blk = third_branch(code)
    local armed = blk:match('if%s+J%.IsOverTierCampOnly.-\n%s*return;?%s*\n%s*end')
    assert(armed, 'the armed block no longer ends in a return -- re-read for deadlock')
    local _, nMoves = armed:gsub('bot:Action_MoveToLocation%s*%(', '')
    assert(nMoves == 2, 'the armed block issues ' .. nMoves ..
        ' move commands, not 2 -- every path out of it must command something')
    assert(not armed:find('Action_AttackUnit'),
        'the armed block attacks -- that is the branch it exists to leave')
    -- and it retires the camp through the shipped path, not a new one
    assert(armed:find('J%.Site%.UpdateAvailableCamp'),
        'the armed block no longer retires the camp through UpdateAvailableCamp')
    assert(armed:find('ClosestCamp%s*%('),
        'the armed block no longer re-picks through the one camp selector')
    assert(armed:find('farmState%s*=%s*FARM_STATE_NONE'),
        'the armed block leaves FARM_STATE_FARM latched -- it would re-enter next frame')
    -- the same three steps the shipped "done with this camp" branch already takes
    local shipped = code:match('farmState%s*=%s*FARM_STATE_NONE;.-ClosestCamp%(bot,%s*availableCamp%);')
    assert(shipped, 'the shipped retire path was reshaped -- the armed block is ' ..
        'no longer quoting an existing path')
end

tests['[source] the tier test is FilterFarmNeutrals itself, not a second copy'] = function()
    local fn = strip_comments(read(FUNC_SRC))
    local body = fn:match('function J%.IsOverTierCampOnly.-\nend\n')
    assert(body, 'J.IsOverTierCampOnly is gone or reshaped')
    assert(body:find('J%.Site%.FilterFarmNeutrals'),
        'the helper stopped delegating the membership test -- "a creep this bot ' ..
        'may not take" would then have two definitions')
    assert(not body:find('ANCIENT_MIN_LEVEL') and not body:find('IsAncientCreep'),
        'the helper restates the tier itself -- it must read it off the one filter')
    assert(body:find('J%.IsRoshan'), 'the Roshan exclusion is gone')
end

--============================================================================
-- Honest limits and domain.
--============================================================================

tests['[limit reach] this file cannot drive the branch end to end, and here is why'] = function()
    -- Not a footnote. The branch is reached only with neutrals in a 1000u sweep,
    -- and the corpus carries none at all -- so an end-to-end drive would be
    -- measuring an empty world. If the dumper ever starts carrying creeps this
    -- assertion turns red, and the honest response is to delete it and drive
    -- Think() for real rather than to relax it.
    for _, spec in ipairs(ALL_SUBJECTS) do
        local _, bot = subject(spec)
        for _, r in ipairs({ 900, 1000, 1600 }) do
            local a = bot:GetNearbyCreeps(r, true)
            local b = bot:GetNearbyNeutralCreeps(r)
            assert(type(a) == 'table' and #a == 0, label(spec) ..
                ': GetNearbyCreeps is no longer empty on a fixture -- drive Think() for real')
            assert(type(b) == 'table' and #b == 0, label(spec) ..
                ': GetNearbyNeutralCreeps is no longer empty on a fixture -- same')
        end
    end
end

tests['[limit gate] the fixtures cannot tell turbo from normal -- the loader forces it'] = function()
    -- Stated so it cannot be mistaken for a measurement: the turbo conjunct of
    -- the gate is not something these frames witness.
    for _, spec in ipairs(ALL_SUBJECTS) do
        local J = subject(spec)
        assert(J.IsModeTurbo() == true, label(spec) ..
            ': the fixture loader no longer forces turbo, so the turbo conjunct ' ..
            'of this gate is now an untested assumption here')
    end
end

tests['[domain] the band this lever owns is real in the corpus'] = function()
    -- Floors, not equalities (GH #106): adding a fixture must not turn this red.
    local p = assert(io.popen('ls tests/fixtures/*.lua'))
    local nSlots, nBand, nAtOrAbove = 0, 0, 0
    for path in p:lines() do
        local ok, fx = pcall(dofile, path)
        if ok and type(fx) == 'table' and fx.units then
            for _, u in ipairs(fx.units) do
                if u.level then
                    nSlots = nSlots + 1
                    if u.level >= 10 and u.level < 12 then nBand = nBand + 1 end
                    if u.level >= 12 then nAtOrAbove = nAtOrAbove + 1 end
                end
            end
        end
    end
    p:close()
    -- Measured 2026-08-28 on the fixture corpus. The 10..11 band is the two
    -- levels the shipped literal admits and the ladder refuses; it is a small
    -- slice of the corpus precisely because turbo levels fast, which is also why
    -- the replay desk's 25 factory-leg episodes in it are worth removing rather
    -- than a rounding error.
    assert(nSlots >= 1000, 'corpus shrank: ' .. nSlots .. ' hero-slots')
    assert(nBand >= 20, 'the 10..11 band collapsed in the corpus: ' .. nBand)
    assert(nAtOrAbove >= 70, 'the >= 12 population collapsed: ' .. nAtOrAbove)
end

return tests

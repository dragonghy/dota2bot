-- GH #265: `campfarm` armed emptied the ATTACK list for an under-tier bot at an
-- ancient camp, but the same creeps it dropped were still counted by a SECOND,
-- unfiltered neutral sweep whose job is to decide "are there neutrals here" --
-- and counting them holds the lane-creep escape SHUT. Gated soak candidate
-- 'campvoid' (turbo-only) routes that presence check through the same filter.
--
-- THE DEFECT (bots/mode_farm_generic.lua, with 'campfarm' armed)
-- --------------------------------------------------------------
-- The file reads neutrals through TWO engine calls, not one:
--
--     bot:GetNearbyCreeps(900, true)          3 sites, all wrapped by campfarm
--     bot:GetNearbyNeutralCreeps(range)       3 sites, none wrapped
--
-- and the census in tests/test_campfarm_ancient_target.lua that calls itself
-- "every neutral sweep in the farm mode goes through the one gate" counts only
-- the first API. It cannot see the second. That is not a missing assertion; it
-- is an assertion whose NAME claims a universe its own pattern cannot reach --
-- the same shape as GH #257 / #261 / #266, one level up.
--
-- Of the three unwrapped sites, exactly one is on the ACTION path: Think()'s
-- lane-creep escape,
--
--     local nNeutrals = bot:GetNearbyNeutralCreeps(nSearchRange)
--     if J.IsValid(farmTarget) and #nNeutrals == 0 then   -- go hit a lane creep
--
-- and its polarity runs AGAINST the filter. With 'campfarm' armed and the bot
-- below the ancient tier, the attack list is EMPTY (that is campfarm's declared
-- consequence) while this presence list is NOT -- so the bot may not attack the
-- camp it is standing in, and may not leave for a lane creep either. The shipped
-- code has no branch for that state.
--
-- ⭐ THE REUSABLE CRITERION. When a fix REMOVES entries from a list, every other
-- predicate that asks "is this list non-empty" must be filtered by the same
-- rule. Otherwise the fix manufactures a state no branch covers -- nothing to
-- act on, and no reason to move -- and the failure direction is a DEADLOCK, not
-- a wrong choice. Nothing turns red for it, because every site is individually
-- unchanged and each one is defensible on its own.
--
-- GH #265 photographed the deadlock on the armed leg: `1a45f5/20260828_002224_slot10`,
-- a level-4 Earthshaker crossed the Black Dragon camp's aggro radius six times
-- in 19 seconds with ZERO damage events of its own, 3000u clear of any enemy
-- hero (nearest 4097u), and died to `npc_dota_neutral_black_drake` at t=238.1.
--
-- THE FIX (one lever, monotone): route that ONE presence sweep through
-- J.Site.FilterFarmNeutrals as well. FilterFarmNeutrals can only REMOVE entries,
-- so `#nNeutrals == 0` can only flip false -> true: armed can only OPEN the
-- lane-creep escape and can never close one the shipped path took. That
-- one-directionality is read off the shipped source below, not asserted in prose.
--
-- WHAT THIS FILE CAN AND CANNOT BUY LOCALLY -- read before trusting a number
-- --------------------------------------------------------------------------
-- The SUBJECT half is real, and it is the two heroes GH #265 actually named, at
-- the two levels it actually measured: earthshaker at level 4 (§1's fatal frame)
-- and bristleback at level 11 (§2's two leaks), off real .dem frames. Level is
-- the only bot operand the fix reads.
--
-- The CREEP half is NOT in the corpus and is not pretended to be: world fact W1
-- asserts that BOTH sweep APIs answer `{}` on every fixture, so an end-to-end
-- drive of the Think() block would be measuring an empty sweep. The creeps below
-- are a DECLARED STAND-IN carrying exactly the fields the shipped filter reads
-- (IsNull / IsAncientCreep / GetUnitName / GetHealth / GetLocation). No count
-- here is claimed to be corpus data except the ones marked [domain].
--
-- NOT END TO END, and the reason is an assertion, not a footnote: [limit reach]
-- below reads the shipped guard that stands in front of this branch
-- (`#hLaneCreepList > 0`) and pins that the corpus carries no lane creeps either.

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')
local api = require('mock.bot_api')

local tests = {}

local FARM_SRC = 'bots/mode_farm_generic.lua'

-- The two heroes GH #265 named, at the two levels it measured, plus the two
-- controls the lever must NOT touch. ES L4 is the deepest point inside the gate;
-- BB L10 sits in the band where the SHIPPED clause (`>= 10`) passes but the
-- ladder (12) refuses -- the sharpest disagreement; BB L11 is §2's own level;
-- BB L12 is the same hero one level above the tier, where armed must be inert.
local ES_L4   = { 'tests/fixtures/f_232228_wk_ownhalf_standoff.lua', 'npc_dota_hero_earthshaker', 4 }
local BB_L10  = { 'tests/fixtures/f_080225_wk_revive.lua',           'npc_dota_hero_bristleback', 10 }
local BB_L11  = { 'tests/fixtures/f_181441_zuus_lowhp_limbo.lua',    'npc_dota_hero_bristleback', 11 }
local BB_L12  = { 'tests/fixtures/f_181544_storm_escape_tp.lua',     'npc_dota_hero_bristleback', 12 }

local UNDER_TIER = { ES_L4, BB_L10, BB_L11 }
local ALL_SUBJECTS = { ES_L4, BB_L10, BB_L11, BB_L12 }

local function subject(spec)
    local J, _, heroes = rf.load(spec[1], spec[2])
    -- GH #91 ratchet: mode_farm_generic carries a defence-ping guard in its own
    -- source, so any file that reads this mode has to say which world it assumed.
    -- 'stale' is the ordinary case and the right one here: this lever is about
    -- the farm path's neutral bookkeeping, not about a lane under attack. A
    -- 'fresh' world would kill the farm bid outright and the frames below would
    -- be describing a mode the bot is not in.
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

-- A declared neutral creep, carrying exactly the fields FilterFarmNeutrals reads.
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

-- The Black Dragon camp of GH #265 §1/§2: one dragon and two drakes, all ancient,
-- nothing else in range. This is the shape that produces the deadlock.
local function black_dragon_camp(bot)
    return {
        creep(bot, 'npc_dota_neutral_black_dragon', 1400, true, 260),
        creep(bot, 'npc_dota_neutral_black_drake',   700, true, 300),
        creep(bot, 'npc_dota_neutral_black_drake',   700, true, 320),
    }
end

-- ⭐ THE DISCRIMINATING INPUT. An ancient camp and a normal camp inside one
-- sweep. Here "filter the ancients" and "empty the list" give DIFFERENT answers
-- to `#nNeutrals == 0`: the first leaves the escape shut, the second opens it.
-- Without this table a mutation that just returns `{}` passes everything below,
-- because on an ancients-only sweep the two rules agree. (The lesson of the
-- 2026-08-27T19:29Z round, applied up front rather than after a live mutation.)
local function mixed_sweep(bot)
    return {
        creep(bot, 'npc_dota_neutral_black_dragon',  1400, true,  260),
        creep(bot, 'npc_dota_neutral_ogre_mauler',    550, false, 300),
        creep(bot, 'npc_dota_neutral_black_drake',    700, true,  320),
    }
end

local function normals_only(bot)
    return {
        creep(bot, 'npc_dota_neutral_ogre_mauler', 550, false, 260),
        creep(bot, 'npc_dota_neutral_ogre_magi',   450, false, 300),
    }
end

local function empty_sweep() return {} end

local ALL_SWEEPS = { black_dragon_camp, mixed_sweep, normals_only, empty_sweep }

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

-- The shipped presence test, transcribed VERBATIM from the Think() block. W4
-- asserts the source still reads this way, so this stays a transcription and
-- cannot quietly drift into a model of its own.
local function shipped_escape_open(list)
    return #list == 0
end

--============================================================================
-- World facts this file rests on. Asserted, not described.
--============================================================================

tests['[world W1] BOTH sweep APIs answer empty on a fixture, so creeps are declared'] = function()
    -- The existing campfarm file asserts this for GetNearbyCreeps only. The API
    -- this lever is about was never checked, which is exactly the gap.
    for _, spec in ipairs(ALL_SUBJECTS) do
        local _, bot = subject(spec)
        for _, r in ipairs({ 330, 900, 1600 }) do
            local a = bot:GetNearbyCreeps(r, true)
            local b = bot:GetNearbyNeutralCreeps(r)
            assert(type(a) == 'table' and #a == 0, label(spec) ..
                ': GetNearbyCreeps is no longer empty on a fixture -- if the ' ..
                'dumper started carrying creeps, drive the real Think() block here')
            assert(type(b) == 'table' and #b == 0, label(spec) ..
                ': GetNearbyNeutralCreeps is no longer empty on a fixture -- same')
        end
    end
end

tests['[world W2] the farm file reads neutrals through TWO APIs, not one'] = function()
    -- This is the finding, stated as arithmetic. The campfarm census asserts
    -- `bot:GetNearbyCreeps(` == 3 under the title "every neutral sweep"; the
    -- other API is three more sweeps it cannot see.
    local code = strip_comments(read(FARM_SRC))
    local _, nCreeps = code:gsub('bot:GetNearbyCreeps%s*%(', '')
    local _, nNeutral = code:gsub('bot:GetNearbyNeutralCreeps%s*%(', '')
    assert(nCreeps == 3, 'GetNearbyCreeps sweeps moved: ' .. nCreeps)
    assert(nNeutral == 3, 'GetNearbyNeutralCreeps sweeps moved: ' .. nNeutral ..
        ' -- a new one needs a ruling on which side of this lever it sits')
    -- and the older census really is blind to the second API, by construction
    local census = read('tests/test_campfarm_ancient_target.lua')
    assert(census:find('bot:GetNearbyCreeps', 1, true), 'the campfarm census changed shape')
    assert(census:find('GetNearbyNeutralCreeps', 1, true) == nil,
        'the campfarm census now mentions the second API -- if it grew a real ' ..
        'census of both, this assertion should become that one instead')
end

tests['[world W3] exactly one of the three is on the action path, and it is the wrapped one'] = function()
    -- The split is what keeps this to one lever: two sites only stamp `teamTime`
    -- inside GetDesireHelper; the third decides an action inside Think().
    local code = strip_comments(read(FARM_SRC))
    local desire = code:match('function GetDesireHelper%(%).-\nfunction ')
    assert(desire, 'GetDesireHelper is gone or reshaped')
    local think = code:match('function Think%(%).*')
    assert(think, 'Think is gone or reshaped')

    local _, nDesire = desire:gsub('bot:GetNearbyNeutralCreeps%s*%(', '')
    local _, nThink  = think:gsub('bot:GetNearbyNeutralCreeps%s*%(', '')
    assert(nDesire == 2, 'GetDesireHelper now has ' .. nDesire ..
        ' neutral presence sweeps, not 2')
    assert(nThink == 1, 'Think() now has ' .. nThink ..
        ' neutral presence sweeps, not 1 -- a second one needs its own ruling')

    -- the Think() one goes through the wrapper; the desire ones deliberately do not
    assert(think:find('NeutralPresenceList%s*%(%s*bot%s*,%s*bot:GetNearbyNeutralCreeps%s*%('),
        "Think()'s presence sweep is no longer wrapped -- the lever is off")
    assert(not desire:find('NeutralPresenceList'),
        'a desire-side sweep was wrapped too -- that widens the lever past what ' ..
        'GH #265 measured; it needs its own id and its own frames')
end

tests['[world W4] the shipped escape really is `#nNeutrals == 0`, and it is guarded by lane creeps'] = function()
    local code = strip_comments(read(FARM_SRC))
    local blk = code:match('hLaneCreepList%s*=%s*bot:GetNearbyLaneCreeps.-GetFarmLaneTarget.-\n[^\n]*NeutralPresenceList[^\n]*\n[^\n]*')
    assert(blk, 'the lane-creep escape block was reshaped -- re-read it before ' ..
        'trusting shipped_escape_open() above')
    assert(blk:find('#nNeutrals%s*==%s*0'),
        'the escape no longer turns on an empty neutral list')
end

tests['[limit reach] this file cannot drive the block end to end, and here is why'] = function()
    -- Not a footnote: the shipped guard in front of the branch is
    -- `#hLaneCreepList > 0`, and the corpus carries no lane creeps at all, so
    -- the branch is unreachable on every fixture. If the dumper ever starts
    -- carrying creeps this assertion turns red and the honest thing to do is
    -- delete it and drive the block for real.
    local code = strip_comments(read(FARM_SRC))
    assert(code:find('#hLaneCreepList%s*>%s*0'),
        'the lane-creep guard moved -- reachability needs re-reading')
    for _, spec in ipairs(ALL_SUBJECTS) do
        local _, bot = subject(spec)
        local lane = bot:GetNearbyLaneCreeps(900, true)
        assert(type(lane) == 'table' and #lane == 0, label(spec) ..
            ': the corpus now carries lane creeps -- drive Think() for real')
    end
end

--============================================================================
-- Today's defect: the two questions answer off different lists.
--============================================================================

tests["[today's defect] campfarm armed, the bot may not attack and may not leave"] = function()
    -- Both readings driven through the real J.Site.FilterFarmNeutrals: the
    -- attack list as campfarm filters it, the presence list as Think() reads it
    -- today (bare). This is the deadlock, as arithmetic.
    for _, spec in ipairs(UNDER_TIER) do
        local J, bot = subject(spec)
        local sweep = black_dragon_camp(bot)
        local attack = J.Site.FilterFarmNeutrals(sweep, bot:GetLevel(), true)
        assert(#attack == 0, label(spec) ..
            ': campfarm armed no longer empties the attack list at an ancient camp -- got ' ..
            names(attack))
        -- and the presence check, unfiltered, still counts every one of them
        assert(not shipped_escape_open(sweep), label(spec) ..
            ': the bare presence list is empty, so there is no deadlock to fix here')
        assert(#sweep == 3, label(spec) .. ': the camp stand-in changed shape')
    end
end

tests["[today's defect] above the tier there is no deadlock -- the two lists agree"] = function()
    local J, bot = subject(BB_L12)
    local sweep = black_dragon_camp(bot)
    local attack = J.Site.FilterFarmNeutrals(sweep, bot:GetLevel(), true)
    assert(#attack == 3, 'level 12 armed must still see the whole ancient camp, got ' ..
        names(attack))
    assert(not shipped_escape_open(sweep), 'presence read changed at level 12')
end

--============================================================================
-- The fix.
--============================================================================

tests['[fix] armed under the tier, the lane-creep escape opens'] = function()
    for _, spec in ipairs(UNDER_TIER) do
        local J, bot = subject(spec)
        local sweep = black_dragon_camp(bot)
        local presence = J.Site.FilterFarmNeutrals(sweep, bot:GetLevel(), true)
        assert(shipped_escape_open(presence), label(spec) ..
            ': armed, the presence list is still non-empty -- ' .. names(presence))
        -- the two questions now answer off the same list
        local attack = J.Site.FilterFarmNeutrals(sweep, bot:GetLevel(), true)
        assert(#attack == #presence, label(spec) ..
            ': the attack list and the presence list disagree even armed')
    end
end

tests['[fix] ⭐ discriminating: a MIXED sweep must keep the escape SHUT'] = function()
    -- The whole point of filtering rather than emptying. A mutation that returns
    -- `{}` whenever the gate fires passes every ancients-only case above and
    -- fails here: with one ogre still in range there IS something to farm, and
    -- walking off to a lane creep would be strictly worse.
    for _, spec in ipairs(UNDER_TIER) do
        local J, bot = subject(spec)
        local sweep = mixed_sweep(bot)
        local presence = J.Site.FilterFarmNeutrals(sweep, bot:GetLevel(), true)
        assert(#presence == 1, label(spec) ..
            ': expected the one ogre to survive the filter, got ' .. names(presence))
        assert(presence[1]:GetUnitName() == 'npc_dota_neutral_ogre_mauler',
            label(spec) .. ': the survivor is not the ogre -- ' .. names(presence))
        assert(not shipped_escape_open(presence), label(spec) ..
            ': armed opened the escape while a farmable normal creep was in range')
    end
end

tests['[fix] ⭐ monotone: armed can only OPEN the escape, never close one'] = function()
    -- The one-directionality, read as a grid rather than argued in prose:
    -- over every subject x every sweep, the armed list is a subset of the bare
    -- one, and `#==0` never goes true -> false. This is what makes the lever
    -- safe to arm alone.
    local nOpened, nCells = 0, 0
    for _, spec in ipairs(ALL_SUBJECTS) do
        local J, bot = subject(spec)
        for _, mk in ipairs(ALL_SWEEPS) do
            local sweep = mk(bot)
            local armed = J.Site.FilterFarmNeutrals(sweep, bot:GetLevel(), true)
            nCells = nCells + 1
            assert(#armed <= #sweep, label(spec) .. ': armed list grew')
            local was, now = shipped_escape_open(sweep), shipped_escape_open(armed)
            assert(not (was and not now), label(spec) ..
                ': armed CLOSED an escape the shipped path had open -- ' ..
                'the lever is no longer one-directional')
            if now and not was then nOpened = nOpened + 1 end
        end
    end
    assert(nCells == 16, 'grid changed size: ' .. nCells)
    -- and the grid really does separate the two legs: exactly the three
    -- under-tier subjects x the one ancients-only sweep flip.
    assert(nOpened == 3, 'expected exactly 3 cells to flip open, got ' .. nOpened ..
        ' -- if this is 0 the grid stopped exercising the lever at all')
end

tests['[fix] at and above the tier armed is identity -- same table, not a copy'] = function()
    local J, bot = subject(BB_L12)
    for _, mk in ipairs(ALL_SWEEPS) do
        local sweep = mk(bot)
        assert(rawequal(J.Site.FilterFarmNeutrals(sweep, bot:GetLevel(), true), sweep),
            'level 12 armed returned a different table for ' .. names(sweep))
    end
end

tests['[fix] unarmed is identity at every subject, and nil behaves like false'] = function()
    for _, spec in ipairs(ALL_SUBJECTS) do
        local J, bot = subject(spec)
        for _, mk in ipairs(ALL_SWEEPS) do
            local sweep = mk(bot)
            assert(rawequal(J.Site.FilterFarmNeutrals(sweep, bot:GetLevel(), false), sweep),
                label(spec) .. ': unarmed returned a copy instead of the table')
            assert(rawequal(J.Site.FilterFarmNeutrals(sweep, bot:GetLevel(), nil), sweep),
                label(spec) .. ': a nil gate must behave exactly like false')
        end
    end
end

tests['[fix] armed with nothing to drop is also identity'] = function()
    local J, bot = subject(BB_L11)
    local sweep = normals_only(bot)
    assert(rawequal(J.Site.FilterFarmNeutrals(sweep, bot:GetLevel(), true), sweep),
        'a sweep with no ancient in it must come back as the same table')
end

--============================================================================
-- Structure: the gate is one conjunct, turbo-only, and not chained to campfarm.
--============================================================================

tests['[source] the wrapper is turbo-only, gated on campvoid, resolved once'] = function()
    local code = strip_comments(read(FARM_SRC))
    local body = code:match('local function NeutralPresenceList.-\nend')
    assert(body, 'NeutralPresenceList is gone or reshaped')
    assert(body:find('J%.IsModeTurbo%s*%(%s*%)'), 'the filter must be turbo-only')
    assert(body:find("J%.IsSoakCandidate%s*%(%s*'campvoid'%s*%)"),
        "the filter must be gated on 'campvoid'")
    local _, nGates = code:gsub("J%.IsSoakCandidate%s*%(%s*'campvoid'%s*%)", '')
    assert(nGates == 1, "'campvoid' is resolved in " .. nGates .. ' places -- a ' ..
        'second resolution point is a second gate to keep in step')
    local _, nCalls = code:gsub('NeutralPresenceList%s*%(', '')
    assert(nCalls == 2, 'NeutralPresenceList has ' .. nCalls ..
        ' mentions (1 definition + 1 call expected)')
end

tests['[source] campvoid is NOT conjoined with campfarm (the pullcad trap)'] = function()
    -- AGENTS.md: promoting an id silently freezes FALSE any gate that names it.
    -- The two levers sit on the same defect but different lists, so they must be
    -- armable and promotable independently.
    local code = strip_comments(read(FARM_SRC))
    local body = code:match('local function NeutralPresenceList.-\nend')
    assert(not body:find('campfarm'), "campvoid's gate names 'campfarm' -- promoting " ..
        'campfarm would freeze campvoid FALSE in every wave')
    local other = code:match('local function NeutralFarmList.-\nend')
    assert(not other:find('campvoid'), "campfarm's gate names 'campvoid'")
    -- exactly one conjunct beyond turbo, on each side
    for name, b in pairs({ NeutralPresenceList = body, NeutralFarmList = other }) do
        local _, n = b:gsub('J%.IsSoakCandidate%s*%(', '')
        assert(n == 1, name .. ' resolves ' .. n .. ' soak candidates, not 1')
    end
end

tests['[source restraint] the two desire-side sweeps are deliberately left bare'] = function()
    -- Pinned so that widening the lever cannot happen quietly. Both sites only
    -- stamp `teamTime`; neither issues an action.
    local code = strip_comments(read(FARM_SRC))
    local desire = code:match('function GetDesireHelper%(%).-\nfunction ')
    assert(desire, 'GetDesireHelper is gone or reshaped')
    for line in desire:gmatch('[^\n]*bot:GetNearbyNeutralCreeps[^\n]*') do
        assert(not line:find('NeutralPresenceList'),
            'a desire-side sweep got wrapped: ' .. line)
    end
    -- and what those two guard is a timestamp, not a command
    local _, nTeamTime = desire:gsub('teamTime%s*=%s*DotaTime%(%)', '')
    assert(nTeamTime >= 2, 'the desire-side sweeps no longer only stamp teamTime -- ' ..
        'found ' .. nTeamTime .. ' stamps; re-read before leaving them bare')
end

tests['[source] the filter itself is still the only shrinking step'] = function()
    -- The monotone grid above is only meaningful if FilterFarmNeutrals can never
    -- ADD an entry. Read that off the shipped body rather than inferring it.
    local site = strip_comments(read('bots/FunLib/aba_site.lua'))
    local body = site:match('FilterFarmNeutrals%s*=%s*function.-\nend\n')
    assert(body, 'FilterFarmNeutrals is gone or reshaped')
    assert(body:find('kept%[#kept%s*%+%s*1%]%s*=%s*creep'),
        'the filter no longer appends the creeps it keeps -- re-read monotonicity')
    assert(not body:find('table%.insert%s*%(%s*creepList'),
        'the filter mutates its input -- callers no longer hold what they passed')
end

--============================================================================
-- Domain: how much of the corpus sits under the tier this lever owns.
--============================================================================

tests['[domain] the under-tier population is real, and so is the one it must not touch'] = function()
    -- Floors, not equalities (GH #106): adding a fixture must not turn this red.
    local p = assert(io.popen('ls tests/fixtures/*.lua'))
    local nSlots, nUnder, nAtOrAbove = 0, 0, 0
    for path in p:lines() do
        local ok, fx = pcall(dofile, path)
        if ok and type(fx) == 'table' and fx.units then
            for _, u in ipairs(fx.units) do
                if u.level then
                    nSlots = nSlots + 1
                    if u.level < 12 then nUnder = nUnder + 1
                    else nAtOrAbove = nAtOrAbove + 1 end
                end
            end
        end
    end
    p:close()
    -- Measured 2026-08-28 on 105 fixtures / 1050 hero-slots: 966 under the tier
    -- (92.0%), 84 at or above it. Turbo levels fast, but the farm path runs from
    -- minute one, so the gated population is nearly the whole corpus -- which is
    -- exactly why the deadlock this lever removes is worth removing.
    assert(nSlots >= 1000, 'corpus shrank: ' .. nSlots .. ' hero-slots')
    assert(nUnder >= 900, 'the under-tier population collapsed: ' .. nUnder)
    assert(nAtOrAbove >= 70, 'the >= 12 population collapsed: ' .. nAtOrAbove)
end

return tests

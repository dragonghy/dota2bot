-- [owner priority P2 / GH #344] The healthy walk home belongs to no id, and
-- the one thing in the tree that recognises it cannot end a trip.
--
-- WHAT THIS ANSWERS
-- -----------------
-- The replay desk's 2026-08-30T21:58Z sweep (GH #344) counts 127 walks home
-- across W29's 10 stamped games: 96% back outside 4,000 units within 60
-- seconds, 32% of them at full health AND full mana AND with the inventory
-- byte-identical at both ends. 464 seconds of hero time per game. Both legs
-- and both strata carry it, so it is stable-version behaviour, not an armed
-- id's product. GH #344 deliberately proposes no fix and names no id.
--
-- This file supplies the source-side half of that question, with no corpus:
-- WHICH branch in bots/ owns that trip, and what would a fix have to attach
-- to. The answer is three facts, and the third is the one that matters.
--
-- 1. THE BAND IS OWNED BY NOBODY -- closed form, from four constants
-- ------------------------------------------------------------------
-- Owner priority P2's walk leg is split across exactly two ids, and they
-- split it on HEALTH with no gap and no overlap:
--
--   * `stayfield2` -> J.ShouldRegenNotWalkHome -> J.IsFieldRegenSituation,
--     which refuses on `nHP > 0.55`;
--   * `itemtrip`   -> J.IsWastefulItemTrip, which refuses on `hp < 0.55`.
--
-- The same 0.55 from both sides, by design (see the head comment of
-- J.IsWastefulItemTrip). So the health axis has no hole. The hole is on the
-- DISTANCE axis, and only one of the two ids has a distance clause at all:
-- J.IsWastefulItemTrip refuses below 10,000 units from the bot's own
-- fountain, while J.IsFieldRegenSituation has no distance clause to refuse
-- with -- and is already out of the picture above 0.55 anyway. Hence
--
--     hp > 0.55  AND  4000 <= d_fountain < 10000
--
-- is refused by BOTH, where 4,000 is FAR_U -- the threshold GH #344's own
-- trip definition starts at. Its bearing frame sits inside that band: the
-- lion of `eb04aa/20260830_184327_slot1` turns around 7,065 units from home
-- at hp 1.000 / mp 1.00. Two ids, two independent refusals, one frame.
--
-- 2. THE ONE RECOGNISER THAT SHIPS IS ON THE WRONG END OF THE TRIP
-- ----------------------------------------------------------------
-- GH #344's profile -- item mode, full health, full mana -- is already a
-- judgement this tree ships UNGATED, in ConsiderHeroMoveOutsideFountain
-- (bots/mode_roam_generic.lua), whose own comment reads "is stuck in item
-- mode". But it is guarded by `DistanceFromFountain() > 1500 -> false` and by
-- the fountain aura, i.e. it only ever runs once the bot is already home, and
-- the action it drives (ThinkGeneralRoaming) walks to MoveOutsideFountainDistance
-- = 1500 from the team fountain -- INSIDE the 2,000-unit ring GH #344 calls
-- "home". So by construction it can shorten the DWELL and can never end the
-- trip. GH #344's dwell numbers (median 12s, p75 14s, against a 38s median
-- round trip) are that hatch's output, not evidence that nothing acts.
--
-- 3. NO FRAME-LEVEL PREDICATE OVER (hp, mp, ring, distance) CAN PRICE IT
-- ----------------------------------------------------------------------
-- Measured on this repo's own corpus (107 fixtures / 993 live hero frames,
-- the stand tests/_itemtrip_sweep.lua uses), at the shipped constants:
--
--     J.IsWastefulItemTrip holds on                       146 / 993 = 14.7%
--     healthy + empty 1600 ring + 4000 <= d < 10000       209 / 993 = 21.1%
--     ... and also mp > 0.95                               83 / 993 =  8.4%
--
-- The unowned band is LARGER than the entire shipped domain of the only lever
-- that could contest it, and GH #344's full-mana clause removes only 60% of
-- it. Tiering the floor down to 4,000 behind `mp > 0.95` would take the frame
-- domain 14.7% -> 23.1%, the same order of magnitude that had `itemtrip`
-- handed back on condition (b) at 33.1% (director 2026-08-23 14:58Z, X = gpm
-- -26.44). The reason is the one this desk has already paid for once: this
-- predicate selects FRAMES ("healthy, safe, far from home" is the description
-- of an ordinary farming frame) and GH #344 counted TRIPS. The feature that
-- distinguishes those 127 trips -- the bot turned around and came back with
-- nothing -- is a TRIP-level quantity, and no frame carries it.
--
-- That is an arithmetic argument for GH #344's own "observe first, do not
-- gate yet" recommendation, in place of caution.
--
-- SCOPE, HONESTLY
-- ---------------
--   * Zero behaviour change, zero new gate ids, zero AWS, no S3 access. Every
--     assertion below reads the shipped tree or drives a real frame.
--   * GH #344's percentages are reproduced as prose and asserted NOWHERE.
--     This file cannot see that corpus; a ratchet that pretended to would be a
--     ratchet on somebody else's instrument.
--   * The three census numbers in section 3 ARE from this repo's fixture
--     corpus, but they are a one-off read, not re-derived here: pinning a
--     corpus census would make this file fail every time a fixture lands.
--     What is pinned instead is the closed-form band, which does not move.
--   * `bot:GetActiveMode()` is a constant 0 on a fixture (the thirteenth world
--     assertion), so the hatch's BOT_MODE_ITEM clause is read from SOURCE
--     only and is never driven. This file therefore does NOT claim which mode
--     emitted GH #344's 127 trips -- only that whichever it was, the two ids
--     above refuse the band those trips live in.
--   * Frame A's operands (7,065u / hp 1.000 / mp 1.00) are quoted from GH
--     #344. What is driven below is this repo's own pinned P2 frame, with one
--     operand at a time substituted, so that every reading names what was
--     modelled.

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')

local tests = {}

local JMZ    = 'bots/FunLib/jmz_func.lua'
local ROAM   = 'bots/mode_roam_generic.lua'
local MARGIN = 'tools/batch_test/behavioral/stayfield2_margin.py'
local DOMAIN = 'tools/batch_test/behavioral/stayfield_domain.py'

-- Owner priority P2's own pinned frame: Lina, 31.8% HP, 57.6% mana, nearest
-- enemy 6,596 units away, 10,009.85 units from her own fountain. The sibling
-- files in this family drive the same subject.
local LINA      = 'tests/fixtures/f_260822_063722_lina_tp_home.lua'
local LINA_HERO = 'npc_dota_hero_lina'

local function read(path)
    local f = assert(io.open(path, 'r'), 'cannot read ' .. path)
    local s = f:read('*a')
    f:close()
    return s
end

--- Line comments only -- this tree has no long-bracket comments.
local function strip_comments(src)
    local out = {}
    for line in (src .. '\n'):gmatch('([^\n]*)\n') do
        out[#out + 1] = line:gsub('%-%-.*$', '')
    end
    return table.concat(out, '\n')
end

--- Body of a top-level `function <name>(` ... `\nend\n`, comments stripped.
local function fn_body(path, sName)
    local src = strip_comments(read(path))
    local i = assert(src:find('function ' .. sName .. '%('),
        'no such top-level function: ' .. sName .. ' in ' .. path)
    local j = assert(src:find('\nend\n', i, true),
        'unterminated function body: ' .. sName)
    return src:sub(i, j + 4)
end

--- A `NAME = <number>` assignment, read out of a Lua or Python source file.
local function const(path, sName)
    local src = strip_comments(read(path))
    local v = src:match('[^%w_]' .. sName .. '%s*=%s*([%d%.]+)')
    if v == nil then
        -- Python sources are not Lua-commented; fall back to the raw text.
        v = read(path):match('\n' .. sName .. '%s*=%s*([%d%.]+)')
    end
    assert(v ~= nil, 'cannot read constant ' .. sName .. ' from ' .. path)
    return tonumber(v)
end

--- Load a real frame with turbo forced and an explicit armed set, so every
--- reading names the string it was taken on rather than inheriting one.
local function world(armed)
    local J, bot = rf.load(LINA, LINA_HERO)
    J.IsModeTurbo = function() return true end
    J.IsSoakCandidate = function(id) return (armed or {})[id] == true end
    return J, bot
end

--- Substitute exactly ONE operand of the loaded world, leaving the rest of
--- the frame real. Returns the restore function so a case cannot leak.
local function substitute(J, bot, sName, value)
    local real = J[sName]
    J[sName] = function(u) if u == bot then return value end return real(u) end
    return function() J[sName] = real end
end

-- ---------------------------------------------------------------- [source]

tests['[ratchet][source] the two P2 walk-leg ids split health at the SAME number'] = function()
    local situation = fn_body(JMZ, 'J.IsFieldRegenSituation')
    local wasteful  = fn_body(JMZ, 'J.IsWastefulItemTrip')

    local ceiling = situation:match('nHP < [%d%.]+ or nHP > ([%d%.]+)')
    assert(ceiling ~= nil,
        'J.IsFieldRegenSituation no longer refuses on an upper HP edge -- '
        .. 'the band this file reasons about has moved')

    local floor = wasteful:match('J%.GetHP%( bot %) < ([%d%.]+)')
    assert(floor ~= nil,
        'J.IsWastefulItemTrip no longer carries a lower HP edge')

    assert(tonumber(ceiling) == tonumber(floor),
        'the two ids no longer meet at one number (' .. ceiling .. ' vs '
        .. floor .. '): the health axis has acquired a hole or an overlap, '
        .. 'and this file reasons on the premise that it has neither')
end

tests['[ratchet][source] only ONE of the two carries a distance clause'] = function()
    local situation = fn_body(JMZ, 'J.IsFieldRegenSituation')
    local wasteful  = fn_body(JMZ, 'J.IsWastefulItemTrip')

    assert(situation:find('Fountain', 1, true) == nil,
        'J.IsFieldRegenSituation grew a fountain-distance clause -- the '
        .. 'asymmetry this file rests on is gone')

    local d = wasteful:match('J%.GetDistanceFromAllyFountain%( bot %) < (%d+)')
    assert(d ~= nil,
        'J.IsWastefulItemTrip no longer refuses on distance from home')
    assert(tonumber(d) > 0, 'the fountain floor is not a positive distance')
end

tests['[ratchet][source] the full-hp/full-mana item-mode recogniser ships ungated'] = function()
    local hatch = fn_body(ROAM, 'ConsiderHeroMoveOutsideFountain')

    assert(hatch:find('BOT_MODE_ITEM', 1, true) ~= nil,
        'ConsiderHeroMoveOutsideFountain no longer reads the item mode')
    assert(hatch:match('J%.GetHP%(bot%) > ([%d%.]+)') ~= nil,
        'the hatch no longer carries a high-health clause')
    assert(hatch:match('J%.GetMP%(bot%) > ([%d%.]+)') ~= nil,
        'the hatch no longer carries a high-mana clause')

    -- The load-bearing half: it is a shipped default, so GH #344's "both legs,
    -- both strata, same sign" reading is consistent with it being live.
    assert(hatch:find('IsSoakCandidate', 1, true) == nil,
        'ConsiderHeroMoveOutsideFountain acquired a candidate gate -- it is no '
        .. 'longer a stable-version behaviour and section 2 must be rewritten')
end

tests['[ratchet][source] that recogniser runs only after the bot is already home'] = function()
    local hatch = fn_body(ROAM, 'ConsiderHeroMoveOutsideFountain')

    assert(hatch:find('bot:DistanceFromFountain() > MoveOutsideFountainDistance', 1, true) ~= nil,
        'the hatch no longer refuses outside MoveOutsideFountainDistance -- it '
        .. 'may now be reachable on the outbound leg, which would break the '
        .. '"dwell only" claim in section 2')
    assert(hatch:find('modifier_fountain_aura_buff', 1, true) ~= nil,
        'the hatch no longer requires the fountain aura')

    -- And the action it drives walks to that same radius, not past it.
    local think = fn_body(ROAM, 'ThinkGeneralRoaming')
    assert(think:find('MoveOutsideFountainDistance', 1, true) ~= nil,
        'the fountain-exit action no longer uses MoveOutsideFountainDistance')
end

-- ----------------------------------------------------------------- [arith]

tests['[ratchet][arith] the exit walks to a point INSIDE the ring GH #344 calls home'] = function()
    local out  = const(ROAM, 'MoveOutsideFountainDistance')
    local ring = const(DOMAIN, 'FOUNTAIN_NEAR_U')

    assert(out < ring, string.format(
        'the fountain exit now leaves the arrival ring (%g >= %g): it could '
        .. 'end a trip by GH #344\'s definition, and section 2 no longer holds',
        out, ring))
end

tests['[ratchet][arith] a whole qualifying trip can sit below the only distance floor'] = function()
    local wasteful = fn_body(JMZ, 'J.IsWastefulItemTrip')
    local floor = tonumber(wasteful:match('J%.GetDistanceFromAllyFountain%( bot %) < (%d+)'))
    local far   = const(MARGIN, 'FAR_U')

    assert(far < floor, string.format(
        'GH #344\'s trip threshold (%g) is no longer below the fountain floor '
        .. '(%g) -- the band in section 1 has closed and this file is stale',
        far, floor))
end

tests['[ratchet][arith] the unowned band is non-empty, from four parsed constants'] = function()
    local situation = fn_body(JMZ, 'J.IsFieldRegenSituation')
    local wasteful  = fn_body(JMZ, 'J.IsWastefulItemTrip')

    local ceiling = tonumber(situation:match('nHP < [%d%.]+ or nHP > ([%d%.]+)'))
    local floor   = tonumber(wasteful:match('J%.GetDistanceFromAllyFountain%( bot %) < (%d+)'))
    local far     = const(MARGIN, 'FAR_U')

    -- Witness: frame A's own operands, as quoted by GH #344.
    local hpA, dA = 1.000, 7065

    assert(hpA > ceiling, string.format(
        'hp %.3f no longer clears the situation ceiling %.2f', hpA, ceiling))
    assert(dA >= far, string.format(
        'distance %g no longer qualifies as a trip (FAR_U %g)', dA, far))
    assert(dA < floor, string.format(
        'distance %g is no longer below the fountain floor %g', dA, floor))
end

-- ----------------------------------------------------------------- [drive]

tests['[ratchet][drive] both edges of the situation band really decide, on a real frame'] = function()
    local J, bot = world({ stayfield2 = true })
    local situation = fn_body(JMZ, 'J.IsFieldRegenSituation')
    local lo = tonumber(situation:match('nHP < ([%d%.]+) or nHP >'))
    local hi = tonumber(situation:match('nHP < [%d%.]+ or nHP > ([%d%.]+)'))
    assert(lo ~= nil and hi ~= nil and lo < hi, 'the situation band moved')

    -- The frame as it stands: hurt, safe, supplied -- the predicate holds.
    assert(J.ShouldRegenNotWalkHome(bot) == true,
        'the pinned P2 frame no longer satisfies the walk-leg hold; every '
        .. 'reading below is taken against it and means nothing without it')

    -- Probes straddle the PARSED edges by one hundredth, so they follow the
    -- tree if either edge moves instead of quietly testing the old world.
    for _, case in ipairs({ { hi + 0.01, false }, { hi - 0.01, true },
                            { lo + 0.01, true }, { lo - 0.01, false } }) do
        local restore = substitute(J, bot, 'GetHP', case[1])
        local got = J.ShouldRegenNotWalkHome(bot)
        restore()
        assert(got == case[2], string.format(
            'hp %.2f gave %s, expected %s -- the band is not deciding here, '
            .. 'so section 1 would be resting on a dead predicate rather than '
            .. 'on a live edge', case[1], tostring(got), tostring(case[2])))
    end
end

tests['[ratchet][drive] both edges of the wasteful-trip clauses really decide too'] = function()
    local J, bot = world({})
    local wasteful = fn_body(JMZ, 'J.IsWastefulItemTrip')
    local hpFloor = tonumber(wasteful:match('J%.GetHP%( bot %) < ([%d%.]+)'))
    local dFloor  = tonumber(wasteful:match('J%.GetDistanceFromAllyFountain%( bot %) < (%d+)'))
    assert(hpFloor ~= nil and dFloor ~= nil, 'the wasteful-trip clauses moved')

    -- One operand modelled at a time, and every probe derived from the parsed
    -- edge. Health first, at a distance the frame already clears on its own.
    for _, case in ipairs({ { hpFloor - 0.01, false }, { hpFloor, true },
                            { hpFloor + 0.01, true } }) do
        local restore = substitute(J, bot, 'GetHP', case[1])
        local got = J.IsWastefulItemTrip(bot)
        restore()
        assert(got == case[2], string.format(
            'hp %.2f gave %s, expected %s', case[1], tostring(got),
            tostring(case[2])))
    end

    -- Then distance, at frame A's health -- including frame A's own turnaround
    -- point, which is GH #344's operand and not a constant of this tree.
    local restoreHP = substitute(J, bot, 'GetHP', 1.000)
    for _, case in ipairs({ { 7065, false }, { dFloor - 1, false },
                            { dFloor, true }, { dFloor + 1, true } }) do
        local restore = substitute(J, bot, 'GetDistanceFromAllyFountain', case[1])
        local got = J.IsWastefulItemTrip(bot)
        restore()
        assert(got == case[2], string.format(
            'distance %g gave %s, expected %s -- the fountain floor is not '
            .. 'deciding on this frame', case[1], tostring(got),
            tostring(case[2])))
    end
    restoreHP()
end

tests['[ratchet][drive] one frame, two ids, two independent refusals'] = function()
    local J, bot = world({ stayfield2 = true })
    local restoreHP = substitute(J, bot, 'GetHP', 1.000)
    local restoreD  = substitute(J, bot, 'GetDistanceFromAllyFountain', 7065)

    local hold = J.ShouldRegenNotWalkHome(bot)
    local trip = J.IsWastefulItemTrip(bot)

    restoreD()
    restoreHP()

    assert(hold == false,
        'the walk-leg hold now reaches a full-health bot -- section 1 is stale')
    assert(trip == false,
        'the wasteful-trip lever now reaches 7,065 units from home -- section '
        .. '1 is stale')
end

-- --------------------------------------------------------------- [control]

tests['[control] the substitution is what produced the refusals, not the frame'] = function()
    -- The pinned frame stands 10,009.85 units from its own fountain, i.e.
    -- ABOVE the shipped floor by under ten units. So at frame A's health and
    -- the frame's OWN distance the wasteful-trip lever holds -- which is the
    -- only thing that makes the 7,065 reading above a reading about 7,065
    -- rather than a reading about this fixture.
    local J, bot = world({})
    local restoreHP = substitute(J, bot, 'GetHP', 1.000)
    local got = J.IsWastefulItemTrip(bot)
    local d = J.GetDistanceFromAllyFountain(bot)
    restoreHP()

    assert(got == true, string.format(
        'the pinned frame no longer clears the fountain floor on its own '
        .. '(distance %.2f): the distance cases above can no longer '
        .. 'distinguish a substituted refusal from a frame that refuses '
        .. 'anyway, and this control is the whole reason they can', d))
end

tests['[control] the parsed constants are the shipped ones, not restated here'] = function()
    -- The M13 lesson from the sibling sweep: a census that copies the constant
    -- it measures reports the old world unmoved after the constant moves. The
    -- guard is that nothing outside a comment in this file spells the four
    -- numbers it reasons on -- they must all arrive by parse.
    -- Each needle is split in two so this list is not itself a match -- the
    -- same guard shape the sibling files use, and for the same reason.
    local body = strip_comments(read('tests/test_healthy_walk_home_gap.lua'))
    for _, halves in ipairs({ { '0.', '55' }, { '100', '00' },
                              { '4000', '.0' }, { '2000', '.0' },
                              { '15', '00' } }) do
        local lit = halves[1] .. halves[2]
        assert(body:find(lit, 1, true) == nil, string.format(
            'the literal %s entered the executable part of this file -- read '
            .. 'it from the tree instead', lit))
    end
end

-- ----------------------------------------------------------------- [limit]

tests['[limit] this file rules on nobody and measures nobody\'s corpus'] = function()
    -- Neither `stayfield2` nor `itemtrip` is admitted, handed back, or ruled
    -- on here, and GH #344 is not answered -- it asked for observation and
    -- this is the source-side half of the observation. A reachability argument
    -- is not a verdict, and the distinction is only durable if something fails
    -- when it is blurred. Each needle is split so this list is not itself a
    -- match.
    local body = strip_comments(read('tests/test_healthy_walk_home_gap.lua'))
    for _, halves in ipairs({ { 'prom', 'ote' }, { 'INDETER', 'MINATE' },
                              { 'WOR', 'KING' }, { 'SIL', 'ENT' } }) do
        local word = halves[1] .. halves[2]
        assert(body:find(word, 1, true) == nil,
            'a verdict vocabulary word entered the executable part of this '
            .. 'file: ' .. word)
    end
end

tests['[limit] the item-mode clause is source-read only, never driven'] = function()
    -- bot:GetActiveMode() is a constant 0 on a fixture, so any case that
    -- branched on it would run fast, green and all-zero without ever being
    -- checked. Recorded as an assertion rather than as prose so that the day
    -- the dumper starts carrying the active mode, this line fails and the next
    -- author is told the clause has become drivable.
    local J, bot = world({})
    assert(J ~= nil)
    assert(bot.GetActiveMode == nil or bot:GetActiveMode() == 0,
        'the fixture world now reports a real active mode -- the hatch\'s '
        .. 'item-mode clause has become drivable and section 2 can be '
        .. 'upgraded from a source read to a frame read')
end

return tests

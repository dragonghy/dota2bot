-- [ratchet] [hero] The objective-clock band behind `alchrage`, re-taken on the
-- first frame that sits inside it.
--
-- Pays row 2 -- the LAST of the three real re-decisions -- of GH #357's reopen
-- list (tests/frames/README.md).  Row 6 (Axe t15 in-domain) was paid
-- 2026-08-31T13:59Z in tests/test_axe_t15_in_domain.lua; row 3 (the Black King
-- Bar zero) 2026-08-31T16:51Z in tests/test_axe_bkb_supply_staged_frame.lua.
-- Both came back VERDICT UNCHANGED.  So does this one, and for a reason that is
-- one level worse than row 3's.
--
--     tests/frames/f_20260831_004433_cm_creepreach.lua
--     69e067 / 20260831_004433_slot1, t = 1190.4 (19:50), 10 heroes to level 22
--
-- WHY BY NAME AND NOT THROUGH THE GLOB.  tests/fixtures/ is also the census
-- corpus (GH #357): admitting this frame turns nine corpus readings red across
-- three levers.  This file loads it BY NAME, so it pays exactly one row and
-- moves none of the nine.  The `[corpus]` ratchet in the sister file
-- (tests/test_alchemist_rage_objective_clock.lua) therefore stays GREEN and
-- stays TRUE -- the corpus tops out at t=790.4, still below the armed bound of
-- 900 -- and its assertion condition is left byte-identical; only the sentence
-- it prints on failure is corrected, by this change, for the reason in (5).
--
-- ===========================================================================
-- THE READING
-- ===========================================================================
--
-- (1) THE CLOCK CONJUNCT IS SATISFIED, AND IT IS THE ONLY ONE THAT IS.
--     t=1190.4 sits inside [900, 1800) and inside [960, 1920) -- both bands the
--     lever moves.  On this instant the shipped clock says FIRE and the armed
--     clock says HOLD.  This is exactly what the sister file's `[corpus]`
--     LIMIT was watching for.
--
-- (2) THE OTHER FOUR CONJUNCTS ARE ZERO, MEASURED THROUGH THE SHIPPED HELPERS
--     ON THIS FRAME -- not argued from the file's era.  Each Roshan call site
--     reads
--
--         J.IsDoingRoshan(bot) and J.IsRoshan(botTarget)
--             and J.IsInRange(bot, botTarget, 500) and J.IsAttacking(bot)
--             and DotaTime() < X.GetRageObjectiveClock(15, 30)
--
--     and over the frame's ten heroes:
--         J.IsDoingRoshan      0/10   (GetActiveMode answers 0; ROSHAN is 1020)
--         J.IsDoingTormentor   0/10   (same reader; SIDE_SHOP is 1007)
--         J.IsAttacking        0/10   (GetAnimActivity, GetAttackPoint and
--                                      GetAnimCycle all answer 0 -- that helper
--                                      reads three fields, and the dump has none)
--         GetAttackTarget      0/10   (nil, so J.IsRoshan gets nil and refuses)
--     Every one of those zeros is a MOCK DEFAULT, not an observation.  That is
--     the finding, not a caveat on it: the dump carries no active mode, no
--     animation activity and no attack target, so these four conjuncts have no
--     channel to be true through.  Section 3 proves the four predicates can
--     still answer TRUE when something feeds them, so these are SUPPLY zeros
--     and not predicate zeros (the trap -62/-63 hit twice: an empty predicate's
--     0 and an empty corpus's 0 are the same integer).
--
-- (3) AND BEFORE ANY OF THAT, THE CARRIER ZERO.  X.ConsiderChemicalRage exists
--     in exactly two files -- bots/BotLib/hero_alchemist.lua and its verbatim
--     twin bots/FunLib/rubick_hero/alchemist.lua -- so the decision needs an
--     Alchemist or a Rubick on the field.  Across all 108 frames (107 corpus +
--     this one) there are 1,080 hero-instants, 41 distinct heroes, and ZERO of
--     either.  The clock is the LAST conjunct in the chain; the FIRST zero is
--     the carrier, and the frame does not move it.
--
-- (4) SO: VERDICT UNCHANGED.  `alchrage` still rests on the arithmetic
--     (the sister file's sections 1-6, which a frame cannot show because the
--     two legs agree on every frame) plus the wave-domain argument (its
--     `[domain]` section: SOAK_CAP_MIN=25 > 15, so a wave CAN buy condition
--     (a)).  Nothing offline moved.
--
-- (5) THE PART WORTH KEEPING, AND WHY IT IS ONE LEVEL WORSE THAN ROW 3.
--     Row 3 found that an item-slot zero was a PROXY for the immunity zero that
--     was actually load-bearing -- but both live in the schema the dumper
--     already writes, so a later frame could in principle move either.  Here
--     the blocking zero is in the GENERATOR: make_fixture.py emits `units`
--     (heroes only), `buildings` (tower / barracks / watch_tower / ancient) and
--     `creeps` (team, x, y, dt -- no NAME at all).  There is no record type
--     anywhere in that schema whose GetUnitName() could contain "roshan" or
--     "miniboss", which is what J.IsRoshan / J.IsTormentor match on.  So
--
--         no number of frames from this generator, from any era, can pin this
--         decision.
--
--     That makes the `[corpus]` ratchet's own failure message wrong about what
--     to do next: it says "pin the decision on that frame instead of resting on
--     the arithmetic alone", and that instruction is not executable.  The
--     ratchet is still worth keeping -- it is the thing that got this reading
--     taken -- but its message is retargeted here, in the same change, to say
--     what the reading found.  Section 4 pins the generator claim so that if
--     the dumper ever grows a creep/neutral name field, or a Roshan record,
--     this file goes red and says "row 2 is re-openable now".
--
-- HONEST BOUNDS.
--   * COUNTS COME FROM `dofile` ON THE FRAMES, never from a regex over the
--     file text.  A bare substring probe is how -63 nearly fired on
--     `modifier_black_king_bar_immune` while measuring `black_king_bar`.
--   * "ZERO CARRIERS" IS ABOUT THE 108 FRAMES ON DISK, not a claim that the
--     farm never drafts Alchemist.  It is a statement about the offline corpus,
--     which is the only thing this file can see.
--   * THE FOUR PREDICATE ZEROS ARE THIS FRAME'S TEN HEROES at this instant.
--     Section 3's positive controls say the readers work; they do not claim a
--     Roshan attempt is impossible in a real game.
--   * BOT_MODE_ROSHAN=1020 / BOT_MODE_SIDE_SHOP=1007 / ACTIVITY_ATTACK are read
--     out of the mock at runtime, not copied, so a renumbering cannot make the
--     controls silently vacuous.

package.path = 'tests/?.lua;' .. package.path

local rf = require('mock.replay_fixture')

local FRAME = 'tests/frames/f_20260831_004433_cm_creepreach.lua'
local SISTER = 'tests/test_alchemist_rage_objective_clock.lua'
local GENERATOR = 'tools/batch_test/replayscope/make_fixture.py'

-- The two files that carry X.ConsiderChemicalRage, and therefore the only two
-- heroes for which this lever has a decision at all.
local CARRIER_SOURCES = {
    'bots/BotLib/hero_alchemist.lua',
    'bots/FunLib/rubick_hero/alchemist.lua',
}
local CARRIERS = { 'npc_dota_hero_alchemist', 'npc_dota_hero_rubick' }

-- (turbo bound, shipped bound) in minutes -- Roshan, then the Tormentor.
-- Read back off the shipped call sites in section 5 rather than trusted here.
local CALL_SITES = {
    { turbo = 15, shipped = 30 },
    { turbo = 16, shipped = 32 },
}

local tests = {}

local function read_file(path)
    local fh = assert(io.open(path, 'r'), 'cannot open ' .. path)
    local body = fh:read('*a')
    fh:close()
    return body
end

local function strip_comments(src)
    return (src:gsub('%-%-[^\n]*', ''))
end

--- Every frame this file reads: the census corpus plus the staged frame.
local function all_frames()
    local paths = {}
    local p = assert(io.popen('ls tests/fixtures/*.lua 2>/dev/null'))
    for line in p:lines() do paths[#paths + 1] = line end
    p:close()
    assert(#paths > 0, 'no fixtures found -- every count below would be vacuous, '
        .. 'do not read a zero here as a finding')
    paths[#paths + 1] = FRAME
    return paths
end

--- The carrier classifier, as a function of a units list so section 3 can feed
--- it a synthetic world and prove it is not answering zero by construction.
local function count_carriers(units)
    local n = 0
    for _, u in ipairs(units) do
        for _, c in ipairs(CARRIERS) do
            if u.name == c then n = n + 1 end
        end
    end
    return n
end

--- The name test J.IsRoshan / J.IsTormentor actually apply, kept as its own
--- function for the same reason.
local function is_boss_name(name)
    return name:find('roshan', 1, true) ~= nil or name:find('miniboss', 1, true) ~= nil
end

-- ---------------------------------------------------------------------------
-- 1.  The clock conjunct: satisfied, and the frame really is the first.
-- ---------------------------------------------------------------------------

tests['[frame] the staged instant sits inside BOTH bands the lever moves'] = function()
    local fx = dofile(FRAME)
    assert(type(fx) == 'table', FRAME .. ' did not load as a frame table')
    local t = fx.time
    assert(type(t) == 'number', FRAME .. ' has no numeric `time`; the whole reading '
        .. 'below hangs off it')
    for _, csite in ipairs(CALL_SITES) do
        local a, b = csite.turbo * 60, csite.shipped * 60
        assert(t >= a and t < b, ('%s sits at t=%.1f, OUTSIDE [%d, %d) -- the %d/%d '
            .. 'call site cannot tell armed from shipped here and row 2 of GH #357 '
            .. 'is not paid by this frame'):format(FRAME, t, a, b, csite.turbo, csite.shipped))
        -- and the two legs really do disagree here, which is the whole point
        assert((t < b) == true and (t < a) == false,
            ('%d/%d: at t=%.1f shipped and armed agree; the band is not doing '
            .. 'anything'):format(csite.turbo, csite.shipped, t))
    end
end

tests['[corpus] and the corpus alone still cannot -- so the frame IS the first'] = function()
    local ARMED = CALL_SITES[1].turbo * 60
    local tMax, sMax, n = -math.huge, nil, 0
    local p = assert(io.popen('ls tests/fixtures/*.lua 2>/dev/null'))
    for path in p:lines() do
        local t = dofile(path).time
        assert(type(t) == 'number', path .. ' has no numeric `time`')
        n = n + 1
        if t > tMax then tMax, sMax = t, path end
    end
    p:close()
    assert(n > 0, 'no fixtures -- this assertion is vacuous, do not read it as a pass')
    assert(tMax < ARMED, ('%s sits at t=%.1f, inside the armed band. The corpus can '
        .. 'now tell armed from shipped on the CLOCK -- but read section 2 of this '
        .. 'file before concluding anything: the clock is the last of five '
        .. 'conjuncts and the other four have no channel in the dump.')
        :format(tostring(sMax), tMax))
    assert(dofile(FRAME).time > tMax, ('the staged frame (t=%.1f) is no longer later '
        .. 'than the corpus max (%s, t=%.1f) -- "the first frame in the band" is '
        .. 'no longer this file\'s claim to make')
        :format(dofile(FRAME).time, tostring(sMax), tMax))
end

-- ---------------------------------------------------------------------------
-- 2.  The carrier zero -- the FIRST zero in the chain, and the frame does not
--     move it.
-- ---------------------------------------------------------------------------

tests['[carrier] X.ConsiderChemicalRage lives in exactly two files'] = function()
    for _, path in ipairs(CARRIER_SOURCES) do
        local src = strip_comments(read_file(path))
        -- Anchored on the open paren.  Without it `ConsiderChemicalRageXX` --
        -- i.e. the function renamed out from under this file -- satisfies the
        -- match, and mutant M11 of this change's mutation stand did exactly
        -- that and SURVIVED. Same shape as the substring trap in backlog -63.
        assert(src:find('function X%.ConsiderChemicalRage%s*%('), path
            .. ' no longer defines X.ConsiderChemicalRage; the carrier set this '
            .. 'file reasons about has changed')
    end
    -- and nowhere else under bots/, or the carrier set below is too narrow
    local p = assert(io.popen(
        'grep -rlE "function X\\.ConsiderChemicalRage *\\(" bots/ 2>/dev/null'))
    local found = {}
    for line in p:lines() do found[#found + 1] = line end
    p:close()
    table.sort(found)
    assert(#found == #CARRIER_SOURCES, ('X.ConsiderChemicalRage is defined in %d files '
        .. 'under bots/, not %d (%s) -- the carrier list in this file is stale')
        :format(#found, #CARRIER_SOURCES, table.concat(found, ', ')))
end

tests['[carrier] zero Alchemists and zero Rubicks in 108 frames'] = function()
    local nFrames, nUnits, nCarriers, nNonHero = 0, 0, 0, 0
    local seen = {}
    for _, path in ipairs(all_frames()) do
        local fx = dofile(path)
        nFrames = nFrames + 1
        nCarriers = nCarriers + count_carriers(fx.units or {})
        for _, u in ipairs(fx.units or {}) do
            nUnits = nUnits + 1
            seen[u.name] = true
            if not u.name:match('^npc_dota_hero_') then nNonHero = nNonHero + 1 end
        end
    end
    local nDistinct = 0
    for _ in pairs(seen) do nDistinct = nDistinct + 1 end

    -- The reading is only worth anything if the scan actually saw a world.
    assert(nUnits > 500, ('only %d hero-instants across %d frames -- the scan is not '
        .. 'seeing the corpus and its zero means nothing'):format(nUnits, nFrames))
    assert(nDistinct > 20, ('only %d distinct heroes seen; same problem'):format(nDistinct))
    assert(seen['npc_dota_hero_axe'], 'the scan cannot even find Axe; it is broken')
    assert(nNonHero == 0, ('%d units in the corpus are not npc_dota_hero_* -- the '
        .. 'dumper grew a non-hero record type, which is exactly the change that '
        .. 'would re-open section 4'):format(nNonHero))

    assert(nCarriers == 0, ('%d Alchemist/Rubick hero-instants found across %d frames. '
        .. 'The carrier zero has moved: re-take row 2 of GH #357 -- but note that '
        .. 'section 3 still has to pass before the decision is observable')
        :format(nCarriers, nFrames))
end

tests['[carrier] the classifier is not answering zero by construction'] = function()
    -- The control -62/-63 both wish they had run: a synthetic world where the
    -- answer must be non-zero.
    local synthetic = {
        { name = 'npc_dota_hero_alchemist' },
        { name = 'npc_dota_hero_axe' },
        { name = 'npc_dota_hero_rubick' },
    }
    assert(count_carriers(synthetic) == 2, 'count_carriers cannot see a carrier that '
        .. 'IS there -- every zero above is a zero of the reader, not of the corpus')
    assert(count_carriers({ { name = 'npc_dota_hero_axe' } }) == 0,
        'count_carriers counts a non-carrier')
    -- and it must not match on a substring: `modifier_alchemist_*` style names
    assert(count_carriers({ { name = 'modifier_npc_dota_hero_alchemist_acid' } }) == 0,
        'count_carriers matches a substring; -63 nearly shipped that exact bug')
end

-- ---------------------------------------------------------------------------
-- 3.  The four upstream conjuncts, evaluated through the SHIPPED helpers on
--     the real frame -- each with a control proving it can answer TRUE.
-- ---------------------------------------------------------------------------

tests['[domain] all four non-clock conjuncts are zero on the staged frame'] = function()
    local J, _, heroes = rf.load(FRAME)
    local n, nRoshan, nTormentor, nAttacking, nTarget = 0, 0, 0, 0, 0
    for _, h in pairs(heroes) do
        n = n + 1
        if J.IsDoingRoshan(h) then nRoshan = nRoshan + 1 end
        if J.IsDoingTormentor(h) then nTormentor = nTormentor + 1 end
        if J.IsAttacking(h) then nAttacking = nAttacking + 1 end
        if h:GetAttackTarget() ~= nil then nTarget = nTarget + 1 end
    end
    assert(n == 10, ('the frame should carry 10 heroes, the loader handed back %d'):format(n))
    assert(nRoshan == 0, ('%d/%d heroes are in BOT_MODE_ROSHAN on the frame -- the '
        .. 'first non-clock conjunct has a channel now; re-take row 2'):format(nRoshan, n))
    assert(nTormentor == 0, ('%d/%d heroes are in BOT_MODE_SIDE_SHOP -- same'):format(nTormentor, n))
    assert(nAttacking == 0, ('%d/%d heroes report J.IsAttacking -- same'):format(nAttacking, n))
    assert(nTarget == 0, ('%d/%d heroes have a GetAttackTarget -- J.IsRoshan can be fed '
        .. 'now; re-take row 2'):format(nTarget, n))
end

tests['[control] the four readers DO answer true when something feeds them'] = function()
    local J, _, heroes = rf.load(FRAME)
    local axe = heroes['npc_dota_hero_axe']
    assert(axe, 'no Axe on the frame; the controls below would be vacuous')
    local spec = rawget(axe, '__spec')
    assert(type(spec) == 'table', 'the loader stopped exposing __spec; these controls '
        .. 'cannot stamp a value and every zero above becomes unverified')

    -- mode, read out of the mock rather than copied
    assert(type(BOT_MODE_ROSHAN) == 'number' and type(BOT_MODE_SIDE_SHOP) == 'number',
        'the mode constants are not numbers; the controls would be testing nothing')
    spec.GetActiveMode = BOT_MODE_ROSHAN
    assert(J.IsDoingRoshan(axe), 'J.IsDoingRoshan stays false with the mode stamped on '
        .. '-- the 0/10 above is a broken reader, not an empty channel')
    spec.GetActiveMode = BOT_MODE_SIDE_SHOP
    assert(J.IsDoingTormentor(axe), 'J.IsDoingTormentor stays false with the mode stamped on')
    spec.GetActiveMode = nil

    -- Attack animation.  J.IsAttacking reads THREE engine fields, not one:
    -- GetAnimActivity, and then GetAttackPoint() > GetAnimCycle() * 0.99.  All
    -- three default to 0 in the mock (and 0 > 0 is false), so the control has to
    -- stamp all three -- which is itself the point: the dump carries none of
    -- them.  Stamping only the activity is what the first draft of this control
    -- did, and it failed, correctly.
    assert(type(ACTIVITY_ATTACK) == 'number', 'ACTIVITY_ATTACK is not a number')
    spec.GetAnimActivity = ACTIVITY_ATTACK
    spec.GetAttackPoint = 0.3
    spec.GetAnimCycle = 0.1
    assert(J.IsAttacking(axe), 'J.IsAttacking stays false with the attack activity, '
        .. 'attack point and anim cycle all stamped on -- the 0/10 above is a broken '
        .. 'reader, not an empty channel')
    spec.GetAnimActivity, spec.GetAttackPoint, spec.GetAnimCycle = nil, nil, nil

    -- the boss-name test itself
    local fake_roshan = {
        IsNull = function() return false end,
        CanBeSeen = function() return true end,
        IsAlive = function() return true end,
        GetUnitName = function() return 'npc_dota_roshan' end,
    }
    assert(J.IsRoshan(fake_roshan), 'J.IsRoshan refuses a unit literally named '
        .. 'npc_dota_roshan -- the zero above is the reader, not the corpus')
    assert(not J.IsRoshan(heroes['npc_dota_hero_axe']), 'J.IsRoshan accepts a hero')
    assert(not J.IsRoshan(nil), 'J.IsRoshan accepts nil')
end

-- ---------------------------------------------------------------------------
-- 4.  The generator: no frame it can produce carries a Roshan or a Tormentor.
--     This is the claim that makes the verdict "unchanged and unchangeable by
--     frames", so it is pinned against the generator's source, not assumed.
-- ---------------------------------------------------------------------------

tests['[schema] no unit anywhere in 108 frames is named like a boss'] = function()
    local nUnits, nBoss, nCreeps, nNamedCreeps, nBuildings = 0, 0, 0, 0, 0
    for _, path in ipairs(all_frames()) do
        local fx = dofile(path)
        for _, u in ipairs(fx.units or {}) do
            nUnits = nUnits + 1
            if is_boss_name(u.name) then nBoss = nBoss + 1 end
        end
        for _, c in ipairs(fx.creeps or {}) do
            nCreeps = nCreeps + 1
            if c.name ~= nil then nNamedCreeps = nNamedCreeps + 1 end
        end
        for _, b in ipairs(fx.buildings or {}) do
            nBuildings = nBuildings + 1
            if is_boss_name(b.name or '') then nBoss = nBoss + 1 end
        end
    end
    assert(nUnits > 500 and nBuildings > 100, ('the scan saw %d units and %d buildings; '
        .. 'too few for its zero to mean anything'):format(nUnits, nBuildings))
    assert(nCreeps > 0, 'the corpus carries no creep records at all -- the named-creep '
        .. 'reading below is vacuous (GH #354 section 5 wired the creeps block; if it '
        .. 'is gone, say so rather than reading a zero)')
    assert(is_boss_name('npc_dota_roshan') and is_boss_name('npc_dota_miniboss')
        and not is_boss_name('npc_dota_hero_axe'),
        'is_boss_name is broken; every zero in this section is the reader\'s')
    assert(nBoss == 0, ('%d boss-named units in the corpus -- J.IsRoshan / J.IsTormentor '
        .. 'have a channel now, re-take row 2 of GH #357'):format(nBoss))
    assert(nNamedCreeps == 0, ('%d creep records carry a name -- the generator grew the '
        .. 'field this file says it does not have; re-read section 4'):format(nNamedCreeps))
end

tests['[schema] and the generator emits no name field for creeps at all'] = function()
    local src = read_file(GENERATOR)
    local body = src:match('creeps%.append%((%b{})%)')
    assert(body, GENERATOR .. ': cannot find the creeps.append call -- the schema claim '
        .. 'in section 4 is unverifiable, go re-read the generator before quoting it')
    for _, key in ipairs({ 'team', 'x', 'y', 'dt' }) do
        assert(body:find('"' .. key .. '"', 1, true), ('%s: the creep record lost its '
            .. '"%s" key; the schema this file pinned has moved'):format(GENERATOR, key))
    end
    assert(not body:find('"name"', 1, true), GENERATOR .. ': the creep record now carries '
        .. 'a "name" -- a frame CAN name a neutral now, so J.IsRoshan/J.IsTormentor '
        .. 'have a channel and row 2 of GH #357 is re-openable. Re-take the reading.')
    -- and nothing in the generator writes a boss record of its own
    assert(not strip_comments(src):lower():find('roshan', 1, true), GENERATOR
        .. ' mentions roshan outside a comment; it may emit one now')
end

-- ---------------------------------------------------------------------------
-- 5.  The two call sites still consume the helper with the constants this file
--     reasons about.  Without this, section 1's bands are prose.
-- ---------------------------------------------------------------------------

tests['[source] the call sites still pass (15, 30) and (16, 32)'] = function()
    for _, path in ipairs(CARRIER_SOURCES) do
        local src = strip_comments(read_file(path))
        for _, csite in ipairs(CALL_SITES) do
            local pat = 'DotaTime%(%)%s*<%s*X%.GetRageObjectiveClock%('
                .. csite.turbo .. ',%s*' .. csite.shipped .. '%)'
            assert(src:find(pat), ('%s: no `DotaTime() < X.GetRageObjectiveClock(%d, %d)` '
                .. 'call site -- the bands in section 1 are about constants that are no '
                .. 'longer there'):format(path, csite.turbo, csite.shipped))
        end
    end
end

-- ---------------------------------------------------------------------------
-- 6.  The sister file's ratchet is still standing, still true, and still says
--     what its author wired it to say.  Row 2 is paid by taking the reading,
--     not by loosening the thing that asked for it.
-- ---------------------------------------------------------------------------

tests['[sister] the corpus ratchet is intact and its condition is untouched'] = function()
    local src = read_file(SISTER)
    assert(src:find('%[corpus%] no fixture in tests/fixtures can tell armed from factory'),
        SISTER .. ': the `[corpus]` ratchet that asked for this reading is gone. '
        .. 'Row 2 of GH #357 is paid by TAKING the reading, not by deleting the ratchet.')
    assert(src:find('assert(tMax < ARMED,', 1, true), SISTER .. ': the ratchet\'s '
        .. 'condition `tMax < ARMED` has been changed. This file was written against '
        .. 'that exact condition; only its failure MESSAGE was retargeted.')
    assert(src:find('tests/test_alchemist_rage_clock_staged_frame', 1, true), SISTER
        .. ': its failure message no longer points at this file, so the next reader '
        .. 'gets the old instruction ("pin the decision on that frame") which section '
        .. '5 of this header shows is not executable.')
end

return tests

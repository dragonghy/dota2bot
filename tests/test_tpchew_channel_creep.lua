-- [tpchew / GH #739] "Is an enemy positioned to break a TP channel started
-- this frame?" is asked about HEROES and nothing else:
-- J.CanEnemyInterruptTpChannel's first line is a J.GetNearbyHeroes sweep, so a
-- neutral creep is not merely missed, it is structurally outside the
-- predicate's domain. The replay desk proved that from source rather than from
-- corpus (GH #739 comment section 3), which is why this file does not depend
-- on the incident rate the issue was filed with.
--
-- The behaviour it costs, read tick by tick in W64: a support finishes poking a
-- friendly camp and starts the scroll STANDING IN the camp it just aggroed.
-- Channeling requires standing still and neutral aggro does not lapse because
-- you started channeling, so the "retreat" pins the hero next to the damage
-- source for the whole 3-5s: skywrath 0.61 -> 0.41 HP (20pp), lich 0.62 ->
-- 0.45 (17pp).
--
-- ⛔ WHAT THIS FILE DOES NOT CLAIM. Not "the bot should not TP" -- GH #739
-- declines to blame that decision and so does this file (the W64 arm string
-- had four TP ids armed at once; nothing there is attributable to one id).
-- The claim is about ORDER: step out of aggro, THEN channel.
--
-- THE FRAMES, and what each is for:
--   HEAD  wk_ancient_camp_634 / skeleton_king   0.63 HP, 277 neutral damage in
--         the 3s lookback, nearest enemy hero beyond 3000 -- so the shipped
--         guard says "the TP is safe" while an ancient camp eats a fifth of
--         his health bar. A NATURAL instance: this fixture was pinned for
--         another id entirely and already carried the defect shape.
--   N1    wk_ancient_camp_634 / phantom_assassin   the SAME FRAME, the other
--         hero: one neutral hit, at dt=4.7, OUTSIDE the 3.0 lookback. His
--         neutral list is NON-empty, so this control falsifies clause 1 alone
--         and pins the 3.0 -- move it to 5.0 and this case fails.
--   N2    lion_235 / lion   eight LANE creep hits inside the lookback and zero
--         neutrals. Creep damage is TRUE here, so this control falsifies
--         clause 2 alone. The two controls are orthogonal on purpose: each
--         clause has a frame that only it rejects.
--
-- Honest bounds, stated first rather than buried:
--   * 175 of the 187 creep hits inside a 3s lookback in this corpus carry no
--     `src` at all (v1 fixtures). On those frames clause 2 is UNASKABLE, not
--     false-for-a-good-reason, and the loader answers an empty list. The
--     domain measured here is over the 12 attributable frames.
--   * the mock's GetNearbyNeutralCreeps is a MODEL, not a restoration -- no
--     fixture carries neutral units. It does not model distance (every
--     synthesized neutral stands on the subject), so every domain count in
--     this file is an UPPER bound on the guard firing, never a lower one.
--   * this file asserts what the PREDICATE and its one wrapper answer. It does
--     not assert a bid: the item-use layer is dark on a fixture (GH #100).
--   * the IsRooted fall-through is VACUOUS here, not verified: the mock's
--     `^Is -> false` catch-all answers every IsRooted, so no fixture can
--     exercise it. Asserted as such below rather than left to look tested.

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')

local JMZ = 'bots/FunLib/jmz_func.lua'
local GATE = 'tpchew'

local HEAD_FIX = 'tests/fixtures/f_260823_002103_wk_ancient_camp_634.lua'
local HEAD_HERO = 'npc_dota_hero_skeleton_king'
local N1_HERO = 'npc_dota_hero_phantom_assassin'      -- same fixture as HEAD
local N2_FIX = 'tests/fixtures/f_20260909_212625_lion_235.lua'
local N2_HERO = 'npc_dota_hero_lion'

local tests = {}

local function read_file(path)
    local f = assert(io.open(path, 'r'))
    local s = f:read('*a')
    f:close()
    return s
end

--- Install a fixture world with `armed` (a soak id, or nil for none) armed.
--- `{ neutrals = true }` opts in to the loader's SYNTHESIZED neutral reader --
--- see the loader comment: it is a model, not a restoration, so it is asked
--- for rather than installed for everyone. The test at the bottom of this file
--- pins the default (no opt-in => {}) from this side, because four other files
--- assert that default as a declared world assumption.
local function world(fix, hero, armed)
    local J, bot = rf.load(fix, hero, { neutrals = true })
    J.IsSoakCandidate = function(id) return armed ~= nil and id == armed end
    return J, bot
end

--- Every alive hero frame in the fixture corpus, as {path, unit} pairs.
--- Built ONCE: four tests below read it, and rebuilding a 1031-frame world per
--- test is the difference between this file sitting inside the fast Lua gate's
--- per-test cap (GH #616) and sitting outside it.
local CORPUS
local function corpus()
    if CORPUS then return CORPUS end
    CORPUS = {}
    local p = assert(io.popen('ls tests/fixtures/*.lua'))
    for path in p:lines() do
        local ok, fx = pcall(dofile, path)
        if ok and type(fx) == 'table' and fx.units then
            for _, u in ipairs(fx.units) do
                if u.name and u.name:find('^npc_dota_hero_') and u.alive ~= false then
                    CORPUS[#CORPUS + 1] = { path = path, unit = u }
                end
            end
        end
    end
    p:close()
    return CORPUS
end

--- Creep damage rows on `u` inside `window`, split by attribution.
local function creep_rows(u, window)
    local neutral, lane, unattributed, total = 0, 0, 0, 0
    for _, d in ipairs(u.recent_damage or {}) do
        if d.kind == 'creep' and d.dt <= window then
            total = total + (d.value or 0)
            if d.src == nil then unattributed = unattributed + 1
            elseif d.src:find('^npc_dota_neutral') then neutral = neutral + 1
            else lane = lane + 1 end
        end
    end
    return neutral, lane, unattributed, total
end

--- The three readings every corpus test below needs, taken in ONE armed pass
--- over the corpus and cached. Kept separate from the assertions on purpose:
--- the sweep is the measurement, the tests are what is claimed about it.
local SWEEP
local function sweep()
    if SWEEP then return SWEEP end
    SWEEP = { askable = 0, bare = 0, narrowed = 0, blind = 0,
              attributable = 0, neutral_frames = 0, lane_frames = 0, fired = {} }
    for _, row in ipairs(corpus()) do
        local u = row.unit
        if u.recent_damage then SWEEP.askable = SWEEP.askable + 1 end
        local neutral, lane = creep_rows(u, 3.0)
        if neutral > 0 or lane > 0 then
            SWEEP.attributable = SWEEP.attributable + 1
            if neutral > 0 then SWEEP.neutral_frames = SWEEP.neutral_frames + 1 end
            if lane > 0 then SWEEP.lane_frames = SWEEP.lane_frames + 1 end
        end
        local J, bot = world(row.path, row.unit.name, GATE)
        if bot:WasRecentlyDamagedByCreep(3.0) then SWEEP.bare = SWEEP.bare + 1 end
        if J.ShouldStepOutBeforeTpChannel(bot) then
            SWEEP.narrowed = SWEEP.narrowed + 1
            SWEEP.fired[#SWEEP.fired + 1] = row
            if J.CanEnemyInterruptTpChannel(bot) == false then
                SWEEP.blind = SWEEP.blind + 1
            end
        end
    end
    return SWEEP
end

-- ------------------------------------------------------------------ HEAD --

tests['HEAD: the defect -- the shipped guard calls the TP safe while a camp eats him'] = function()
    local J, bot = world(HEAD_FIX, HEAD_HERO, nil)

    -- What the shipped clause actually reads, so the blindness is visible
    -- rather than asserted: there is no enemy hero anywhere near him.
    assert(#J.GetNearbyHeroes(bot, 700, true, BOT_MODE_NONE) == 0,
        'the 700 hero ring the guard scans is empty')
    assert(#J.GetNearbyHeroes(bot, 3000, true, BOT_MODE_NONE) == 0,
        'and so is a ring four times wider -- no hero is involved at all')
    assert(J.CanEnemyInterruptTpChannel(bot) == false,
        'so the hero-only predicate answers "nothing can break this channel"')
    assert(J.ShouldNotStartInterruptibleTp(bot) == false,
        'shipped default: the travel TP is allowed on this frame')

    -- ...and yet an ancient camp is on him right now.
    assert(bot:WasRecentlyDamagedByCreep(3.0) == true,
        'ground truth: a creep damaged him inside the lookback')
    assert(#bot:GetNearbyNeutralCreeps(700) > 0,
        'and the thing hitting him is a neutral camp, not a lane wave')
end

tests['HEAD: armed, the bid is refused so he steps out first'] = function()
    local J, bot = world(HEAD_FIX, HEAD_HERO, GATE)
    assert(J.ShouldStepOutBeforeTpChannel(bot) == true,
        'armed: the creep half of the channel question fires')
    assert(J.ShouldNotStartInterruptibleTp(bot) == true,
        'and the wrapper the item layer calls now refuses this frame')
end

tests['HEAD: what the channel would have cost, measured on the frame'] = function()
    -- Condition (c) measured rather than argued, in the unit GH #739 used:
    -- percentage points of the health bar spent standing still.
    local fx = dofile(HEAD_FIX)
    local subject
    for _, u in ipairs(fx.units) do
        if u.name == HEAD_HERO then subject = u end
    end
    assert(subject, 'head fixture must carry the subject')

    local neutral, lane, _, total = creep_rows(subject, 3.0)
    assert(neutral == 8 and lane == 0,
        'the head frame must be pure camp contact, got ' .. neutral .. ' neutral / '
        .. lane .. ' lane')
    assert(total == 277,
        'expected 277 neutral damage in the 3s lookback, got ' .. total)

    local pp = 100.0 * total / subject.max_hp
    -- GH #739 measured 17pp (lich) and 20pp (skywrath) over a 3-5s channel.
    -- This frame is at least as expensive over a strictly shorter window.
    assert(pp >= 17.0,
        'the 3s lookback alone costs ' .. string.format('%.1f', pp)
        .. 'pp, which must clear the 17pp floor the issue measured')
    assert(subject.hp / subject.max_hp < 0.70,
        'and he is already below 70% health while it happens')
end

-- -------------------------------------------------------------- controls --

tests['N1: neutral damage OUTSIDE the lookback does not fire (pins the 3.0)'] = function()
    local fx = dofile(HEAD_FIX)
    local subject
    for _, u in ipairs(fx.units) do
        if u.name == N1_HERO then subject = u end
    end
    local inside = creep_rows(subject, 3.0)
    local within6 = creep_rows(subject, 6.0)
    assert(inside == 0 and within6 == 1,
        'this control needs exactly one neutral hit, outside 3.0 and inside the '
        .. '6s the fixture recorded -- otherwise it is not a test of the '
        .. 'constant. got ' .. inside .. ' inside / ' .. within6 .. ' within 6s')

    local J, bot = world(HEAD_FIX, N1_HERO, GATE)
    -- The teeth: clause 2 is SATISFIED here, so only clause 1 can reject it.
    assert(#bot:GetNearbyNeutralCreeps(700) > 0,
        'his neutral list is non-empty -- clause 2 cannot be what rejects this')
    assert(bot:WasRecentlyDamagedByCreep(3.0) == false,
        'but nothing hit him inside the 3.0 lookback')
    assert(J.ShouldStepOutBeforeTpChannel(bot) == false, 'so the guard is quiet')
    assert(J.ShouldNotStartInterruptibleTp(bot) == false,
        'and his travel TP is not delayed')
end

tests['N2: LANE creep damage does not fire (pins the neutral clause)'] = function()
    local fx = dofile(N2_FIX)
    local subject
    for _, u in ipairs(fx.units) do
        if u.name == N2_HERO then subject = u end
    end
    local neutral, lane = creep_rows(subject, 3.0)
    assert(neutral == 0 and lane == 8,
        'this control needs lane creep hits and no neutral ones, got '
        .. neutral .. ' neutral / ' .. lane .. ' lane')

    local J, bot = world(N2_FIX, N2_HERO, GATE)
    -- The teeth, mirrored: clause 1 is SATISFIED here, so only clause 2 can
    -- reject it. Together with N1 every clause owns a frame that only it fails.
    assert(bot:WasRecentlyDamagedByCreep(3.0) == true,
        'a creep IS hitting him -- clause 1 cannot be what rejects this')
    assert(#bot:GetNearbyNeutralCreeps(700) == 0,
        'but it is a lane wave, not a camp')
    assert(J.ShouldStepOutBeforeTpChannel(bot) == false, 'so the guard is quiet')
end

-- ------------------------------------------------------------- the gates --

tests['unarmed, the guard is inert on every frame it would fire on'] = function()
    -- The append's safety claim, stated as the equality it actually is:
    -- unarmed, the wrapper answers EXACTLY what the bare hero predicate
    -- answers. Asserting `== false` instead would conflate two different
    -- claims ("the gate is off" and "no hero is near"), and on this corpus
    -- both happen to hold, so the conflation would never show.
    local fired = sweep().fired
    assert(#fired > 0, 'vacuous: the gate never fired anywhere, so nothing was gated')
    for _, row in ipairs(fired) do
        local J0, bot0 = world(row.path, row.unit.name, nil)
        assert(J0.ShouldStepOutBeforeTpChannel(bot0) == false,
            'unarmed must be silent on ' .. row.path .. ' / ' .. row.unit.name)
        assert(J0.ShouldNotStartInterruptibleTp(bot0)
                == J0.CanEnemyInterruptTpChannel(bot0),
            'and unarmed the wrapper must be the old one-liner exactly, on '
            .. row.path .. ' / ' .. row.unit.name)
    end
end

tests['the append is an append: the hero predicate is still asked first'] = function()
    -- The edit's whole safety argument is that unarmed the wrapper is
    -- byte-for-byte the old one-liner. That is a claim about ORDER, so read it
    -- off the source rather than off a return value.
    local src = read_file(JMZ)
    local body = src:match('function J%.ShouldNotStartInterruptibleTp%( bot %)\n(.-)\nend\n')
    assert(body, 'could not find the wrapper body')
    local iHero = body:find('J%.CanEnemyInterruptTpChannel')
    local iChew = body:find('J%.ShouldStepOutBeforeTpChannel')
    assert(iHero and iChew, 'the wrapper must call both halves')
    assert(iHero < iChew,
        'the hero predicate must still be asked FIRST -- this is an append, '
        .. 'not an insert')
    assert(body:find('J%.IsModeTurbo'), 'and turbo must still be the first read')
end

tests['the guard is turbo-only'] = function()
    local J, bot = world(HEAD_FIX, HEAD_HERO, GATE)
    local real = J.IsModeTurbo
    J.IsModeTurbo = function() return false end
    assert(J.ShouldStepOutBeforeTpChannel(bot) == false,
        'normal mode ships unchanged')
    J.IsModeTurbo = real
    assert(J.ShouldStepOutBeforeTpChannel(bot) == true, 'turbo: it fires again')
end

tests['the 3.0 lookback is the SAME constant fieldcreep uses'] = function()
    -- Not a new tuned number: the two clauses ask the same engine probe for
    -- the same reason, and this file is where they are kept together.
    local src = read_file(JMZ)
    local n = 0
    for _ in src:gmatch('WasRecentlyDamagedByCreep%( 3%.0 %)') do n = n + 1 end
    assert(n == 2,
        'expected exactly two WasRecentlyDamagedByCreep( 3.0 ) call sites '
        .. "('fieldcreep' and 'tpchew'), found " .. n
        .. ' -- if one of them moved, the shared-constant argument in both '
        .. 'comments is no longer true')
end

tests['the 700 radius is borrowed from the sibling, not tuned'] = function()
    local src = read_file(JMZ)
    local body = src:match('function J%.ShouldStepOutBeforeTpChannel%( bot %)\n(.-)\nend\n')
    assert(body, 'could not find the predicate body')
    assert(body:find('GetNearbyNeutralCreeps%( 700 %)'),
        'the neutral scan must stay at the 700 J.CanEnemyInterruptTpChannel '
        .. 'scans -- a different number is a tuned constant and needs its own '
        .. 'evidence')
end

tests['IsRooted falls through, and is VACUOUS on this corpus (declared)'] = function()
    -- A bot that cannot walk out has no cheaper option than the channel, so
    -- the scroll stays its last resort. No fixture can exercise this -- the
    -- mock answers every `Is*` false -- so assert exactly that, rather than
    -- letting an untested conjunct read as tested.
    local _, bot = world(HEAD_FIX, HEAD_HERO, GATE)
    assert(bot:IsRooted() == false,
        'the mock answers IsRooted false on every fixture, so the fall-through '
        .. 'is declared here, not measured')

    -- What it WOULD do, on the one world where it can be asked.
    local J2, bot2 = world(HEAD_FIX, HEAD_HERO, GATE)
    rawget(bot2, '__spec').IsRooted = function() return true end
    assert(J2.ShouldStepOutBeforeTpChannel(bot2) == false,
        'rooted: the guard stands down and the scroll stays the last resort')
end

-- ------------------------------------------------------ corpus and model --

tests['the narrowing is why this is not the lanefix shape'] = function()
    -- The measurement that forced clause 2, re-derived here so it cannot go
    -- stale in a comment: the bare "a creep hit me" probe answers TRUE on an
    -- order of magnitude more frames than the narrowed guard, and on the only
    -- subcorpus that can attribute a hit, half of those are lane creeps.
    local sw = sweep()
    assert(sw.askable == 192,
        'askable frames (a recent_damage block exists) moved: ' .. sw.askable)
    assert(sw.bare == 74,
        'the one-clause version of this guard fires on ' .. sw.bare
        .. ' frames, not 74 -- the breadth argument in the comment moved')
    assert(sw.narrowed == 6,
        'the narrowed guard fires on ' .. sw.narrowed .. ' frames, not 6')
    assert(sw.bare > sw.narrowed * 10,
        'clause 2 must still be doing an order of magnitude of work: '
        .. sw.bare .. ' -> ' .. sw.narrowed)

    -- 6 neutral / 6 lane on the attributable frames. This is the number that
    -- says the engine probe's blindness is not a corner case.
    assert(sw.attributable == 12 and sw.neutral_frames == 6 and sw.lane_frames == 6,
        'the attribution split moved: ' .. sw.attributable .. ' attributable, '
        .. sw.neutral_frames .. ' neutral / ' .. sw.lane_frames .. ' lane')
end

tests['every frame the guard fires on is one the shipped guard called safe'] = function()
    -- If the hero predicate already refused these frames, the lever would be
    -- buying nothing. It refuses none of them: this is the blind band, whole.
    local sw = sweep()
    assert(sw.narrowed == 6, 'domain moved: ' .. sw.narrowed)
    assert(sw.blind == sw.narrowed,
        'only ' .. sw.blind .. ' of ' .. sw.narrowed .. ' are new -- the rest '
        .. 'were already refused by the hero predicate, so the lever buys less '
        .. 'than the comment claims')
end

tests['the mock neutral reader: all four declared assumptions'] = function()
    -- The reader is a MODEL. Each assumption written into its comment is
    -- pinned here, so the day a fixture carries real neutral units the
    -- comment goes red instead of quietly becoming false.

    -- (1) LANE CREEPS ARE NOT NEUTRALS.
    local _, lane_bot = world(N2_FIX, N2_HERO, GATE)
    assert(#lane_bot:GetNearbyNeutralCreeps(700) == 0,
        'eight lane creep hits must synthesize no neutrals')

    -- (2) v1 FIXTURES ANSWER EMPTY (unaskable, not false-for-a-good-reason).
    local v1, v1hero
    for _, row in ipairs(corpus()) do
        local neutral, lane, unattributed = creep_rows(row.unit, 3.0)
        if unattributed > 0 and neutral == 0 and lane == 0 then
            v1, v1hero = row.path, row.unit.name
            break
        end
    end
    assert(v1, 'corpus must still contain an unattributed creep-damage frame')
    local _, v1bot = world(v1, v1hero, GATE)
    assert(#v1bot:GetNearbyNeutralCreeps(700) == 0,
        'an unattributed hit must not invent a neutral: ' .. v1)

    -- (3) DISTANCE IS NOT MODELLED -- every radius includes them, so every
    --     count taken through this reader is an upper bound.
    local _, head = world(HEAD_FIX, HEAD_HERO, GATE)
    local wide = #head:GetNearbyNeutralCreeps(700)
    assert(#head:GetNearbyNeutralCreeps(1) == wide,
        'a 1-unit radius returns the same list as 700 -- if that ever stops '
        .. 'being true the upper-bound claim in the loader comment is wrong')
    for _, h in ipairs(head:GetNearbyNeutralCreeps(700)) do
        assert(GetUnitToUnitDistance(head, h) == 0,
            'synthesized neutrals stand on the subject by construction')
        assert(h:GetUnitName():find('^npc_dota_neutral'), 'and are named')
        assert(h:IsAlive() == true, 'and alive')
    end

    -- (5) IT IS OPT-IN. Four other files assert, as a declared world
    --     assumption, that this reader answers {} on every fixture
    --     (test_abil1st_first_unit_reader [W1], test_campvoid_domain_geometry
    --     [world W1], test_replay_004757_veno_ancient, and the bots/ sweep
    --     census in test_abilanc_ancient_selector). A synthesized list is a
    --     different world from a dumped one and must not arrive under their
    --     feet: a restoration may be global, a model has to be asked for.
    local _, plain = rf.load(HEAD_FIX, HEAD_HERO)
    assert(#plain:GetNearbyNeutralCreeps(1600) == 0,
        'without the opt-in the loader must answer {} -- on the very frame '
        .. 'that has the richest neutral attribution in the corpus')

    -- (4) ONE HANDLE PER DISTINCT SOURCE NAME.
    local fx = dofile(HEAD_FIX)
    local subject
    for _, u in ipairs(fx.units) do
        if u.name == HEAD_HERO then subject = u end
    end
    local names, distinct = {}, 0
    for _, d in ipairs(subject.recent_damage or {}) do
        if d.src and d.src:find('^npc_dota_neutral') and not names[d.src] then
            names[d.src] = true
            distinct = distinct + 1
        end
    end
    assert(distinct > 1, 'the head frame must carry more than one camp member')
    assert(wide == distinct,
        'expected one handle per distinct source name (' .. distinct
        .. '), got ' .. wide)
end

return tests

-- [ratchet] Strategy desk 2026-08-30 -- GH #318, the two source-only halves of
-- the `campvoid` SILENT verdict.
--
-- GH #318 (replay desk, W25+W26, 129 games) measured `campvoid` condition (a) at
-- **0 / 160 episodes** on both armed legs and recommended "do not promote, redraw
-- the domain". This file does NOT re-measure that -- it answers the two questions
-- the issue left on the strategy desk, and both of them are answerable from
-- source plus one number the issue already published.
--
-- FINDING 1 -- THE REDESIGN IN #318 §5 IS A NO-OP AS STATED.
-- --------------------------------------------------------
-- §5 proposes: open the lane-creep escape when the **attack** list is empty
-- ("ask `NeutralFarmList`") rather than when the **existence** list is empty.
-- There is no such distinction in this code. Both wrappers in
-- bots/mode_farm_generic.lua are the SAME call:
--
--     J.Site.FilterFarmNeutrals(tCreeps, hBot:GetLevel(),
--         J.IsModeTurbo() and J.IsSoakCandidate('<id>'))
--
-- byte-identical apart from the id string ('campfarm' vs 'campvoid'). "May I
-- attack this" and "is this here" are answered by one predicate with one tier
-- test, so swapping one list for the other moves nothing. [source S1] asserts
-- that identity rather than describing it, so the day somebody really does
-- separate the two, this file goes red and the #318 verdict gets re-read.
--
-- What DOES differ between the two readers is the SWEEP, not the predicate:
-- `NeutralFarmList` is fed `bot:GetNearbyCreeps(900|1000, true)`, while
-- `NeutralPresenceList` is fed `bot:GetNearbyNeutralCreeps(nSearchRange)` with
-- `nSearchRange = min(bot:GetAttackRange() + 180, 1600)`. That radius is the
-- only operand `campvoid`'s domain actually stands on. [source S2].
--
-- FINDING 2 -- THE DOMAIN IS CLOSED BY GEOMETRY, NOT BY CREEP LUCK.
-- ----------------------------------------------------------------
-- #318 §2 measured, from the corpus itself, that each ancient camp has a NORMAL
-- camp beside it: 146 u at the west box (-4812, 9) and 338 u at the east box
-- ( 4005, 115). `FilterFarmNeutrals` only ever drops ANCIENTS, so one live
-- normal creep from that neighbour keeps `#nNeutrals > 0` and the escape shut --
-- armed or not, byte for byte.
--
-- The sweep is centred on the BOT, not on the camp, so the right statement is an
-- inequality, not a comparison of two constants. With `d` = bot-to-ancient-centre
-- and `dnb` = ancient-to-neighbour-centre, the neighbour's centre is inside the
-- sweep for EVERY bearing when `d + dnb <= R`, i.e. whenever
--
--     d <= R - dnb          ("the guaranteed-inside radius")
--
-- and can never be inside when `|d - dnb| > R`. [geometry G1/G2/G3] walk that.
--
-- ⭐ THE ONE THING THIS BUYS THE NEXT ROUND. The guaranteed-inside radius scales
-- with attack range, so #318 §1's escape table -- which pools every hero into one
-- 400/600/800 u in-camp bucket -- is measuring two different populations. For a
-- ranged bot the 400 u bucket is CLOSED BY ARITHMETIC (G2), so `0 / 38` and
-- `0 / 8` there are what geometry predicts and carry no information about the
-- lever. For a melee bot at the east camp geometry does NOT close it (G3). ⇒ the
-- escape table needs a melee/ranged split before it can say anything about
-- `campvoid` at all; that is the baton handed back on GH #318.
--
-- WHAT THIS FILE CAN AND CANNOT BUY -- read before trusting a number.
-- ------------------------------------------------------------------
-- * The SUBJECT half is real: the bot, its level and its position come off the
--   two .dem frames of the episode GH #265/#318 are about (venomancer L10 in the
--   west Prowler camp). [frame B1] computes `d` from the fixture, not from prose.
-- * The CREEP half is NOT in the corpus and is not pretended to be -- [world W1]
--   asserts the sweep APIs answer `{}` on every fixture, so the camp is a
--   DECLARED stand-in carrying exactly the fields the shipped code reads. This is
--   a test of "given the camp, what does the shipped predicate answer", not an
--   end-to-end drive.
-- * `dnb` = 146 / 338 is #318 §2's reading, carried here as DATA with its
--   citation. This file does not re-derive it (the camp centres are inferred
--   from the corpus, which is not in this container). If it moves, edit the
--   constants here and re-read every geometry claim below.
-- * ATTACK RANGE IS DECLARED, not corpus: fixtures carry no attack range and the
--   mock defaults every hero to 150. Each case names the hero whose range it
--   declares. The six ranges below are the five focus heroes plus the subject.
-- * Centre-to-centre is a PROXY for creep-to-bot: real creeps spread around a
--   camp centre. The worst-case bearing (`d + dnb`) is used for every "the exit
--   stays shut" claim, which is the conservative side of that proxy.

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')
local api = require('mock.bot_api')

local tests = {}

local F785 = 'tests/fixtures/f_20260828_004757_venomancer_785.lua'
local F790 = 'tests/fixtures/f_20260828_004757_venomancer_790.lua'
local SUBJ = 'npc_dota_hero_venomancer'
local SRC  = 'bots/mode_farm_generic.lua'

-- [GH #318 §2] camp centres and the distance to the nearest NORMAL camp, as the
-- replay desk's tool printed them. DATA, not re-derived here.
local WEST = { x = -4812, y =    9, dnb = 146 }
local EAST = { x =  4005, y =  115, dnb = 338 }

-- DECLARED attack ranges (see honest bounds). Melee floor first.
local RANGE = {
    axe            = 150,   -- melee, focus hero
    skeleton_king  = 150,   -- melee, focus hero
    zeus           = 380,   -- lowest ranged in the focus pool
    venomancer     = 450,   -- the subject of the motivating frames
    lion           = 600,   -- focus hero
    crystal_maiden = 600,   -- focus hero
}

-- The shipped arithmetic, restated once so every case below reads the same one.
local function sweep_radius(nAttackRange)
    local r = nAttackRange + 180
    if r > 1600 then r = 1600 end
    return r
end

local function read_source()
    local f = assert(io.open(SRC, 'r'), 'cannot read ' .. SRC)
    local s = f:read('*a')
    f:close()
    return s
end

-- ⚠️ SELF-HARM CAUGHT BY THIS FILE'S OWN MUTATION BATTERY (M5), and it is the
-- one GH #300 already paid for once: bots/mode_farm_generic.lua's header block
-- QUOTES the lane-creep escape verbatim --
--
--     --     if J.IsValid(farmTarget) and #nNeutrals == 0 then   -- go hit a lane creep
--
-- -- so a raw `src:find` for that line matches the COMMENT. The first version of
-- [source S2] below did exactly that, and rewriting the real branch to
-- `#nNeutrals <= 1` left all nine cases green. Every source assertion therefore
-- runs on code_only(), and [control C2] asserts the stripper really is what
-- separates them, so this cannot rot back into an unfalsifiable pattern.
--
-- Long-bracket blocks go FIRST: a SINGLE-LINE `--[[ ... ]]` is already destroyed
-- by per-line `--` stripping, which is how a long-comment branch elsewhere in
-- the tree shipped untestable (charter 0CONJ, self-harm B). Order matters.
local function code_only(src)
    local s = src:gsub('%-%-%[%[.-%]%]', '')
    local out = {}
    for line in (s .. '\n'):gmatch('([^\n]*)\n') do
        if not line:match('^%s*%-%-') then out[#out + 1] = line end
    end
    return table.concat(out, '\n')
end

-- The body of `local function <name>(...)` up to its first line-leading `end`.
local function body_of(src, sName)
    local i = src:find('local function ' .. sName .. '%(')
    assert(i ~= nil, SRC .. ' no longer defines ' .. sName ..
        ' -- the two wrappers GH #318 §5 is about have been renamed or removed')
    local j = src:find('\nend', i, true)
    assert(j ~= nil, sName .. ' has no terminating end')
    return src:sub(i, j + 3)
end

local function subject(path)
    local J, _, heroes = rf.load(path, SUBJ)
    rf.declare_defend_ping(J, 'stale')
    local bot = heroes[SUBJ]
    assert(bot ~= nil, 'fixture no longer carries ' .. SUBJ .. ' -- ' .. path)
    return J, bot
end

-- A declared neutral carrying exactly the fields FilterFarmNeutrals reads. Same
-- shape as tests/test_campfarm_ancient_target.lua's and
-- tests/test_replay_004757_veno_ancient.lua's, deliberately: if that stand-in
-- drifts, all three files should be edited together.
local function creep(bot, sName, nHealth, bAncient, nDist)
    local loc = bot:GetLocation()
    local d = (nDist or 300) / math.sqrt(2)
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

-- The camp the subject actually stood in (Prowler ancients -- the names the
-- event stream carried at t=786.3), plus ONE live creep of the normal camp
-- 146 u away. That neighbour is the whole finding.
local function west_sweep(bot, bNeighbourAlive)
    local t = {
        creep(bot, 'npc_dota_neutral_prowler_shaman',  1100, true, 250),
        creep(bot, 'npc_dota_neutral_prowler_acolyte',  850, true, 300),
    }
    if bNeighbourAlive then
        t[#t + 1] = creep(bot, 'npc_dota_neutral_kobold_tunneler', 300, false, 340)
    end
    return t
end

local function dist_to(bot, camp)
    local loc = bot:GetLocation()
    local dx, dy = loc.x - camp.x, loc.y - camp.y
    return math.sqrt(dx * dx + dy * dy)
end

--============================================================================
-- World: what the corpus does and does not carry.
--============================================================================

tests['[world W1] the corpus carries no creeps, so every creep here is declared'] = function()
    local _, bot = subject(F790)
    for _, r in ipairs({ 330, 630, 900, 1000 }) do
        local a = bot:GetNearbyNeutralCreeps(r)
        local b = bot:GetNearbyCreeps(r, true)
        assert(type(a) == 'table' and #a == 0, string.format(
            'GetNearbyNeutralCreeps(%d) is no longer empty on a fixture -- if the ' ..
            'dumper started carrying creeps (GH #318 §6 option (a)), this file ' ..
            'should drive the real sweep and every claim below gets stronger', r))
        assert(type(b) == 'table' and #b == 0,
            'GetNearbyCreeps(' .. r .. ') is no longer empty on a fixture')
    end
end

--============================================================================
-- Source: the two claims GH #318 §5 rests on.
--============================================================================

tests['[source S1] the attack list and the presence list are ONE predicate -- #318 §5 swaps nothing'] = function()
    local src = code_only(read_source())
    local farm     = body_of(src, 'NeutralFarmList')
    local presence = body_of(src, 'NeutralPresenceList')

    -- Both must actually be the gated FilterFarmNeutrals call this claim is about.
    for name, b in pairs({ NeutralFarmList = farm, NeutralPresenceList = presence }) do
        assert(b:find('J%.Site%.FilterFarmNeutrals'),
            name .. ' no longer calls J.Site.FilterFarmNeutrals')
        assert(b:find("J%.IsSoakCandidate%('"),
            name .. ' no longer resolves a soak candidate')
    end

    -- Normalise away the only two things that are allowed to differ: the
    -- wrapper's own name and the id string it arms on.
    local function norm(b)
        return (b:gsub('Neutral%a+List', '<WRAPPER>')
                 :gsub("IsSoakCandidate%('[%w_]+'%)", "IsSoakCandidate('<ID>')"))
    end
    local nf, np = norm(farm), norm(presence)
    assert(nf == np, '#318 §5 has become answerable: the attack list and the ' ..
        'presence list are no longer the same predicate.\n--- attack ---\n' ..
        nf .. '\n--- presence ---\n' .. np)

    -- And the ids really are the two the issue names, in the order it names them.
    assert(farm:find("IsSoakCandidate%('campfarm'%)"),
        'NeutralFarmList no longer arms on campfarm')
    assert(presence:find("IsSoakCandidate%('campvoid'%)"),
        'NeutralPresenceList no longer arms on campvoid')
end

tests['[source S2] the sweep, not the predicate, is what differs -- radius = AttackRange + 180, cap 1600'] = function()
    local src = code_only(read_source())

    -- The presence read: GetNearbyNeutralCreeps at the derived radius.
    assert(src:find('local nSearchRange = bot:GetAttackRange%(%) %+ 180'),
        SRC .. ' no longer derives nSearchRange from GetAttackRange() + 180')
    assert(src:find('if nSearchRange > 1600 then nSearchRange = 1600 end'),
        SRC .. ' no longer caps nSearchRange at 1600')
    assert(src:find('NeutralPresenceList%(bot, bot:GetNearbyNeutralCreeps%(nSearchRange%)%)'),
        'the campvoid call site no longer reads GetNearbyNeutralCreeps(nSearchRange)')

    -- The attack read: GetNearbyCreeps at a FIXED radius, twice.
    local n = 0
    for _ in src:gmatch('NeutralFarmList%(bot, bot:GetNearbyCreeps%(%d+, true%)%)') do
        n = n + 1
    end
    assert(n >= 2, 'expected the campfarm wrapper to be fed a fixed-radius ' ..
        'GetNearbyCreeps sweep at least twice, found ' .. n)

    -- The escape opens on emptiness of the presence list -- the thing #318 §5
    -- proposed to change.
    assert(src:find('if J%.IsValid%(farmTarget%) and #nNeutrals == 0 then'),
        'the lane-creep escape no longer opens on #nNeutrals == 0')
end

tests['[control C2] the comment stripper is load-bearing -- the escape line really is impersonated by a comment'] = function()
    -- Without this case, code_only() could be reduced to `return src` and every
    -- assertion in [source S2] would keep passing while silently matching prose
    -- again. This asserts the two halves separately: the line is present in the
    -- RAW file more than once, and exactly once after stripping.
    -- Anchored on the COMMENT FORM, not on the branch text, so a legitimate
    -- edit to the escape condition does not make this red for the wrong reason
    -- (GH #221/#276: a test that goes red whenever the thing it quotes is
    -- edited is restating that thing).
    local raw  = read_source()
    local pat  = '%-%-%s+if J%.IsValid%(farmTarget%)'
    local nRaw, nCode = 0, 0
    for _ in raw:gmatch(pat) do nRaw = nRaw + 1 end
    for _ in code_only(raw):gmatch(pat) do nCode = nCode + 1 end
    assert(nRaw >= 1, 'the header comment no longer quotes the escape branch -- ' ..
        'if that impersonation is really gone, [source S2] may read the raw file ' ..
        'again, but check the other quoted call sites in this file first')
    assert(nCode == 0, nCode .. ' impersonating comment(s) survived the stripper' ..
        ' -- [source S2] is matching prose again')

    -- ⚠️ HONEST BOUND, registered rather than papered over. code_only() removes
    -- long-bracket blocks BEFORE per-line comments, and that ordering is the
    -- one charter 0CONJ's self-harm B was about -- but it is NOT exercised
    -- here: mode_farm_generic.lua contains ZERO `--[[` blocks today, so that
    -- gsub is defensive, not tested. Asserting the count keeps the claim
    -- truthful: the day someone adds a long comment to this file, this line
    -- goes red and the ordering has to be given a real case.
    local nLong = 0
    for _ in raw:gmatch('%-%-%[%[') do nLong = nLong + 1 end
    assert(nLong == 0, SRC .. ' now has ' .. nLong .. ' long-comment block(s): ' ..
        'the long-bracket branch of code_only() is finally reachable and needs ' ..
        'its own mutation case')
end

--============================================================================
-- Frame: the real bot, on the frames the episode is about.
--============================================================================

tests['[frame B1] on both motivating frames the escape is SHUT with the neighbour alive, at every under-tier level'] = function()
    for _, path in ipairs({ F785, F790 }) do
        local J, bot = subject(path)
        local d = dist_to(bot, WEST)
        -- The subject really is standing in the west ancient camp: this is read
        -- off the fixture, so a regenerated fixture that moved cannot pass quietly.
        assert(d < 400, string.format(
            '%s: subject is %.0f u from the west ancient camp centre -- the ' ..
            'episode this file is about had it inside the camp', path, d))

        local sweep = west_sweep(bot, true)
        for _, lvl in ipairs({ 4, 9, 10, 11 }) do
            local kept = J.Site.FilterFarmNeutrals(sweep, lvl, true)
            assert(#kept == 1, string.format(
                '%s L%d: expected the two ancients dropped and the neighbour ' ..
                'kept, got %d of %d', path, lvl, #kept, #sweep))
            assert(kept[1]:IsAncientCreep() == false,
                'the survivor should be the normal creep')
            -- THE ASSERTION GH #318 §5 point 2 asked for: after the filter,
            -- #nNeutrals is NOT zero, so `#nNeutrals == 0` is false and the
            -- escape stays shut -- campvoid armed or not, byte for byte.
            assert(#kept ~= 0, 'unreachable, kept above')
        end
    end
end

tests['[frame B2] at or above the ancient tier the filter is identity -- the shipped table comes back'] = function()
    local J, bot = subject(F790)
    local sweep = west_sweep(bot, true)
    for _, lvl in ipairs({ 12, 15, 25 }) do
        local kept = J.Site.FilterFarmNeutrals(sweep, lvl, true)
        assert(rawequal(kept, sweep), 'L' .. lvl ..
            ': at or above ANCIENT_MIN_LEVEL the caller must hold the very ' ..
            'table it passed in, not an equivalent copy')
    end
end

tests['[control C1] with the neighbour camp dead the escape OPENS -- the lever is bounded by the neighbour, not by the ancient'] = function()
    -- Without this case every assertion above would also pass against a
    -- predicate that never returns an empty list, and the file would be proving
    -- nothing about campvoid.
    local J, bot = subject(F790)
    local sweep = west_sweep(bot, false)
    for _, lvl in ipairs({ 4, 9, 10, 11 }) do
        local kept = J.Site.FilterFarmNeutrals(sweep, lvl, true)
        assert(#kept == 0, 'L' .. lvl .. ': an all-ancient sweep must filter to ' ..
            'empty, otherwise campvoid has no domain at all and the SILENT ' ..
            'verdict would be trivial rather than geometric')
    end
    -- ⇒ campvoid's real domain is "the neighbouring NORMAL camp is dead or out
    -- of range", not "the bot is standing in an ancient camp".
end

--============================================================================
-- Geometry: the inequality that closes the domain.
--============================================================================

tests['[geometry G1] the guaranteed-inside radius R - dnb covers the subject on both motivating frames'] = function()
    local R = sweep_radius(RANGE.venomancer)          -- 630, DECLARED range
    local guaranteed = R - WEST.dnb                   -- 484
    assert(guaranteed == 484, 'arithmetic moved: ' .. guaranteed)

    for _, path in ipairs({ F785, F790 }) do
        local _, bot = subject(path)
        local d = dist_to(bot, WEST)
        assert(d <= guaranteed, string.format(
            '%s: d=%.0f exceeds the guaranteed-inside radius %d -- the ' ..
            'neighbour camp is no longer certainly inside the sweep and ' ..
            '[frame B1] becomes bearing-dependent', path, d, guaranteed))
        -- Worst-case bearing, stated as the number the claim rests on.
        assert(d + WEST.dnb <= R, string.format(
            '%s: worst-case bot-to-neighbour %.0f > sweep %d', path,
            d + WEST.dnb, R))
    end
end

tests['[geometry G2] #318 §1s 400u bucket is closed by arithmetic for every RANGED range, and open for both melee ones'] = function()
    local BUCKET = 400  -- the tightest in-camp radius in GH #318 §1's table
    local closed, open = {}, {}
    for hero, range in pairs(RANGE) do
        local guaranteed = sweep_radius(range) - WEST.dnb
        if guaranteed >= BUCKET then closed[#closed + 1] = hero
        else open[#open + 1] = hero end
    end
    table.sort(closed); table.sort(open)

    -- Ranged: zeus (380 -> 560 -> 414), venomancer (450 -> 630 -> 484),
    -- lion / crystal_maiden (600 -> 780 -> 634). All >= 400.
    assert(#closed == 4, 'expected the four ranged focus-pool ranges to close ' ..
        'the 400u bucket, got: ' .. table.concat(closed, ','))
    -- Melee: axe / skeleton_king (150 -> 330 -> 184). Far short of 400.
    assert(#open == 2 and open[1] == 'axe' and open[2] == 'skeleton_king',
        'expected exactly the two melee focus heroes to leave the bucket open, ' ..
        'got: ' .. table.concat(open, ','))

    -- ⇒ #318 §1's `0 / 38` and `0 / 8` at 400 u pool a population where the
    -- answer is forced with one where it is not. The escape table needs a
    -- melee/ranged split before it constrains campvoid.
end

tests['[geometry G3] the one configuration geometry does NOT close: a melee bot at the east ancient camp'] = function()
    local Rmelee = sweep_radius(RANGE.axe)   -- 330
    -- West camp: even standing exactly on the centre, 146 < 330, so the
    -- neighbour is inside for a melee bot too.
    assert(WEST.dnb < Rmelee, 'the west neighbour left the melee sweep')
    -- East camp: 338 > 330. A melee bot on that centre does NOT see the
    -- neighbour, so `#nNeutrals` can reach 0 and campvoid can fire.
    assert(EAST.dnb > Rmelee, string.format(
        'the east camp no longer offers campvoid any domain: dnb=%d, melee ' ..
        'sweep=%d', EAST.dnb, Rmelee))
    -- Margin is 8 u. Recorded so nobody reads this as a comfortable domain: a
    -- creep standing 9 u camp-inward of its own centre closes it again, and the
    -- corpus itself reproduced this distance as 1384 u on another subset
    -- (GH #318 §2), i.e. the east number is the unstable one.
    assert(EAST.dnb - Rmelee == 8, 'the east margin moved: ' ..
        (EAST.dnb - Rmelee))

    -- Every ranged range closes the east camp as well.
    for hero, range in pairs(RANGE) do
        if range > 150 then
            assert(EAST.dnb < sweep_radius(range), hero ..
                ' no longer covers the east neighbour camp')
        end
    end
end

return tests

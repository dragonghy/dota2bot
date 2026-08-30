-- [ratchet] [GH #324 / IsFieldRegenSituation / owner priority P2's family]
-- Both levers GH #324 §3 offers are blocked, on TWO DIFFERENT missing facts --
-- and the second one is a standing limit on a whole class of lever, not a note
-- about this issue.
--
-- WHAT #324 REPORTS. `J.IsFieldRegenSituation`'s danger clauses read HEROES and
-- TOWERS; soak candidate `fieldcreep` added the CREEP read. A Shadow Shaman
-- ward, a Wraith King skeleton and Roshan are none of those, so a domain frame
-- where only such a unit is hitting the bot is invisible to every clause. In
-- W25 those frames are 2.1%-3.9% of the domain and their 20-second death rate
-- is 1.6-4.2x the domain reference, high in all four cells (two strata x two
-- legs). §3 asks this group for two things: check whether the engine has a
-- predicate for it, and measure the overlap with `fieldcreep` before deciding
-- whether it wants its own id or a second clause on `fieldcreep`.
--
-- ANSWER 1 -- THE PREDICATE DOES NOT EXIST, AND NEITHER DOES THE FALLBACK'S.
-- The engine's whole damage-attribution surface is five entries, and every one
-- of them is keyed to hero, creep or tower ([source S2]). There is no
-- "was I damaged by a summon", and -- the part §3 did not expect -- there is no
-- "was I damaged by ANYTHING" either, so §3's own retreat position (the
-- negative form: "took damage in 3s while all four clauses say safe") has no
-- operand to be written from. `InstallDamageCallback`, the one entry point that
-- could build a ledger, is called nowhere under `bots/`. That is the same
-- missing sensor GH #323 ran into last round and GH #327 already hands to the
-- harness; this file adds that #324's fallback lands on it too, so #327 covers
-- both and no second sensor issue is owed.
--
-- ANSWER 2 -- THE PACKAGING QUESTION IS DECIDED BY CONTAINMENT, NOT STRENGTH.
-- #324 §1 already carries the overlap it asks to have measured, one subtraction
-- away ([arith A1]): "has 'other' damage" minus "has ONLY 'other' damage" is
-- the cell that also carries creep/neutral damage, i.e. the part `fieldcreep`
-- can already reach. It is 15.5% / 10.8% / 15.9% / 21.0% of the 'other'
-- population -- so the POSITIVE form is 79-89% disjoint from `fieldcreep` and
-- wants its own id, while the NEGATIVE form contains `fieldcreep`'s domain
-- entirely by construction and must be the same id, or the two (a) readings
-- stop being attributable to either -- this group's own GH #319 finding.
--
-- ⭐ THE FINDING THIS FILE EXISTS FOR. #324 §2's frame evidence does not
-- actually point at the ward. Read its own columns: the nearest enemy hero goes
-- 518u -> 4552u across ONE second. 4,034 u/s is 7.3x Dota's 550 u/s movement
-- cap ([arith A2]), so the shaman did not WALK out of the first danger clause's
-- 1600 ring -- she either dropped out of vision or finished a teleport, and the
-- published columns cannot separate those. Under the first reading the missing
-- read is not the ward at all: it is the MEMORY of a hero who was 518 units
-- away one second ago, and this repo already ships that operand
-- (`J.GetLastSeenEnemiesNearLoc`, alive-gated, `time_since_seen < 5.0`, used by
-- `campdanger`, `mode_laning_generic` and all of `aba_defend`).
--
-- And that lever is the one 铁律 4 cannot validate, for two independent
-- reasons, which is why it is written down here instead of landed:
--
--   (甲) THIS CORPUS HAS NO FOG. 0 of the fixture files carry `seen_by`
--        ([world W1]), so `visible_to_subject` is constant-true and every enemy
--        is stamped `time_since_seen = 0`. Driven over the whole corpus at
--        three radii, the vision operand and the memory operand return the same
--        count on every single frame ([drive D1]). A fix whose entire content
--        is "ask memory instead of vision" is therefore a byte-for-byte no-op
--        under fixture validation -- and it does not FAIL there, it passes,
--        green either way. That is the failure family `0GEOM` M5 and `0SENSE`
--        M12 paid for twice: a guard that is green because it is not
--        load-bearing.
--
--   (乙) LANDING `seen_by` WOULD NOT BE ENOUGH. The loader stamps
--        `time_since_seen = visible_to_subject(u) and 0 or 999` ([source S3]),
--        and 999 is past every `time_since_seen < N` window in `bots/` (the
--        largest is 6). So the value is never inside the open interval a fog
--        reader lives in -- an unseen hero has NO memory here, not a STALE one,
--        and the two operands would still coincide. The loader is right to
--        refuse: one snapshot frame carries no history, so a stale sighting
--        cannot be reconstructed by the loader at all. It has to be DUMPED --
--        the engine's own `time_since_seen` (and last-seen location) per enemy
--        hero, which is a real quantity `GetHeroLastSeenInfo` returns in game.
--
-- => Ruling handed back on #324: the direction is agreed and the arithmetic in
--    §1 is accepted, but neither §3 lever can be landed or validated today, and
--    the frame in §2 argues for a THIRD one (fog memory) that is blocked on a
--    different missing fact than the first two. `fieldcreep` stays as it is --
--    gated, unpromoted, unchanged. No placeholder gate id is opened: a
--    placeholder would assert the lever is validatable, which is the exact
--    claim this file refutes (`0SENSE`'s rule, applied to a second issue).
--
-- MUTATION RECORD -- 16 run, 14 CAUGHT, 2 SURVIVED, each patch verified to have
-- landed before the run. The two survivors are not gaps; they ARE the finding,
-- registered rather than papered over (`0CONJ`'s rule):
--   M13  fog window 5.0 -> 60.0    SURVIVED
--   M14  fog window 5.0 -> 900.0   SURVIVED
--   M15  fog window 5.0 -> 1000.0  CAUGHT ([source S3])
-- i.e. the shipped fog window can be retuned ANYWHERE in the open interval
-- (0, 999) and no case in this file -- and no fixture in this repository --
-- can tell. Only crossing the loader's 999 sentinel is detectable, and that is
-- caught by reading source, not by driving a frame. A knob whose entire usable
-- range is corpus-equivalent is (甲) and (乙) stated as one measurement.
--
-- Honest bounds, stated first rather than buried:
--   * ZERO behaviour change. `bots/` and `game/` are byte-identical this round;
--     no gate id is created, so nothing here buys condition (a) anywhere.
--   * The W25 numbers in [arith A1] are GH #324's readings over 121 games of
--     batch corpus this repository does not carry. Nothing here re-derives them
--     and nothing here contradicts them; what is asserted is the SUBTRACTION
--     and the decision rule it implies, which is arithmetic on those readings.
--   * [arith A2] rules walking out. It does NOT rule a teleport out, and says
--     so; the discriminator (a teleport modifier or channel event on the shaman
--     in 644.5-647.5) is in the timeline, not in this repository.
--   * [drive D1] compares COUNTS, not identities: the two APIs return different
--     things (hero handles vs player ids), and the count is the comparable
--     quantity. [control C1] is what stops that from being a weaker claim than
--     it reads -- it separates the counts with one injected sighting.
--   * `WasRecentlyDamagedByCreep`'s two worlds are STILL unresolved
--     (state.json:fieldcreep_engine_semantics_20260822T2300Z). [arith A1] does
--     not depend on the answer: "only 'other'" frames carry no creep AND no
--     neutral row, so they are outside `fieldcreep` under either world.

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')
local cs = require('corpus_scale')

local JMZ = 'bots/FunLib/jmz_func.lua'
local API_DOC = 'docs/BOT_API_REFERENCE.md'
local LOADER = 'tests/mock/replay_fixture.lua'

local function read_file(path)
    local f = assert(io.open(path, 'r'), 'cannot open ' .. path)
    local s = f:read('*a')
    f:close()
    return s
end

-- Source assertions run on CODE, never on file text. GH #300 paid for this
-- once, the `campvoid` round paid for it again inside a file about `campvoid`,
-- and this file is a worse trap still: `jmz_func.lua` quotes `GetHeroLastSeenInfo`
-- in the prose above `J.IsCampSwitchSafe`, so a bare `src:find` for a fog read
-- inside IsFieldRegenSituation's body would be matching neighbouring prose.
-- Blocks first, then line comments (which would otherwise eat a block's `--`).
-- Limit: a `--` inside a string literal is stripped too; nothing below reads one.
local function code_only(src)
    src = src:gsub('%-%-%[%[.-%]%]', ' ')
    src = src:gsub('%-%-[^\n]*', '')
    return src
end

local JMZ_SRC = read_file(JMZ)
local JMZ_CODE = code_only(JMZ_SRC)
local LOADER_CODE = code_only(read_file(LOADER))

-- The function body, taken from its header to the next top-level `function` --
-- the next definition is J.ShouldRegenNotGoHome, so this is the body and
-- nothing else. Cut from CODE, so the long comment block above the fieldcreep
-- clause (which names three of the reads asserted below) is already gone.
local BODY = assert(
    JMZ_CODE:match('function J%.IsFieldRegenSituation%b()(.-)\nfunction '),
    'J.IsFieldRegenSituation is no longer followed by another top-level function'
        .. ' -- the body cut below is unsound')

local function count(hay, needle)
    local n = 0
    for _ in hay:gmatch(needle) do n = n + 1 end
    return n
end

local function fixture_files()
    local p = assert(io.popen('ls tests/fixtures'))
    local files = {}
    for f in p:lines() do
        if f:match('^f_.*%.lua$') then files[#files + 1] = 'tests/fixtures/' .. f end
    end
    p:close()
    table.sort(files)
    return files
end

-- The radii the shipped fog readers actually use: 800 is J.CAMP_DANGER_RADIUS
-- and mode_laning_generic's own ring, 1200 is mode_roshan/mode_side_shop, 1600
-- is aba_defend's and the ring IsFieldRegenSituation's first danger clause
-- measures. Not a swept grid: these are the four call sites' own numbers.
local RADII = { 800, 1200, 1600 }

local SWEEP = (function()
    local files = fixture_files()
    local frames, pairs_seen, agree, seen_by_units = 0, 0, 0, 0
    for _, path in ipairs(files) do
        local fx = dofile(path)
        if type(fx) == 'table' and fx.units then
            for _, u in ipairs(fx.units) do
                if u.seen_by ~= nil then seen_by_units = seen_by_units + 1 end
            end
            -- One subject per fixture. The claim is about the two OPERANDS
            -- coinciding, and both are computed from the same `fx.units` list
            -- through the same `visible_to_team` predicate, so a second subject
            -- on the same frame re-asks a question already answered. Keeping it
            -- to one holds the drive near 4s instead of ~45s.
            for _, u in ipairs(fx.units) do
                if u.alive then
                    local J, bot = rf.load(path, u.name)
                    frames = frames + 1
                    for _, R in ipairs(RADII) do
                        pairs_seen = pairs_seen + 1
                        local vis = #J.GetNearbyHeroes(bot, R, true, BOT_MODE_NONE)
                        local mem = #J.GetLastSeenEnemiesNearLoc(bot:GetLocation(), R)
                        if vis == mem then agree = agree + 1 end
                    end
                    break
                end
            end
        end
    end
    return {
        files = #files,
        frames = frames,
        pairs = pairs_seen,
        agree = agree,
        seen_by_units = seen_by_units,
    }
end)()

local tests = {}

tests['[source S1] every danger clause reads current vision or damage history -- none reads memory, and none enumerates a summon, a ward or Roshan'] = function()
    -- The four shipped clauses plus the gated fifth, named by their reads. The
    -- 1600 ring and the 3000 attribution sweep are both GetNearbyHeroes, hence 2.
    assert(count(BODY, 'GetNearbyHeroes') == 2,
        'the hero clauses no longer read GetNearbyHeroes twice')
    for _, read in ipairs({
        'WasRecentlyDamagedByAnyHero',
        'WasRecentlyDamagedByHero',
        'GetNearbyTowers',
        'WasRecentlyDamagedByCreep',
    }) do
        assert(count(BODY, read) >= 1, 'the ' .. read .. ' clause is gone')
    end

    -- #324's headline, pinned at source: nothing in the body can see a unit
    -- that is not a hero, a tower or a creep. These are the only ways `bots/`
    -- enumerates other unit families, and the body uses none of them.
    for _, blind in ipairs({
        'GetNearbyCreeps', 'GetNearbyNeutralCreeps', 'GetNearbyLaneCreeps',
        'GetUnitList', 'UNIT_LIST',
    }) do
        assert(count(BODY, blind) == 0, BODY:len() .. '-byte body now reads '
            .. blind .. ' -- #324\'s blind spot may have been closed; re-read '
            .. 'the ruling instead of leaving this assertion stale')
    end

    -- ... and the fog operand this repo already ships is not among the reads
    -- either. That is the gap [arith A2] argues #324 §2's frame is really about.
    assert(count(BODY, 'LastSeen') == 0 and count(BODY, 'IsEnemyHeroAroundLocation') == 0,
        'IsFieldRegenSituation now reads fog memory -- the lever this file '
        .. 'argued could not be validated has landed; re-read (甲) and (乙)')
end

tests['[source S2] the engine damage-attribution surface is closed at hero/creep/tower -- #324 §3 wants a predicate outside it, and its fallback wants one too'] = function()
    local doc = read_file(API_DOC)
    local sec = assert(doc:match('### Damage History(.-)\n###'),
        'the Damage History section is gone from ' .. API_DOC)
    local names = {}
    for n in sec:gmatch('|%s*`([%w_]+)%(') do names[#names + 1] = n end
    table.sort(names)
    local got = table.concat(names, ',')
    -- Asserted as the exact SET, not a count: it goes red the day Valve adds an
    -- entry, which is the only event that unblocks §3's first lever.
    assert(got == 'TimeSinceDamagedByAnyHero,WasRecentlyDamagedByAnyHero,'
        .. 'WasRecentlyDamagedByCreep,WasRecentlyDamagedByHero,'
        .. 'WasRecentlyDamagedByTower',
        'the damage-history family moved: ' .. got)

    -- The two things §3 needs, stated as what the set does NOT contain.
    for _, n in ipairs(names) do
        assert(not n:match('Summon') and not n:match('Ward')
            and not n:match('Neutral') and not n:match('Roshan'),
            n .. ' exists -- #324 §3\'s direct lever is unblocked')
        -- The fallback needs an UNATTRIBUTED read. Every name carries its
        -- attributor (Hero / AnyHero / Creep / Tower); a bare
        -- `WasRecentlyDamaged` would be the one §3 could be written from.
        assert(n ~= 'WasRecentlyDamaged' and n ~= 'TimeSinceDamaged',
            n .. ' exists -- #324 §3\'s negative fallback is unblocked')
    end

    -- The ledger entry point: present in the API, called nowhere.
    assert(read_file(API_DOC):find('InstallDamageCallback', 1, true),
        'InstallDamageCallback left the API reference')
    local p = assert(io.popen("grep -rl 'InstallDamageCallback' bots/ 2>/dev/null | wc -l"))
    local n = tonumber(p:read('*a'):match('%d+'))
    p:close()
    assert(n == 0, n .. ' file(s) under bots/ now reference InstallDamageCallback '
        .. '-- a damage ledger may exist; GH #327 and this ruling are stale')
end

tests['[world W1] this corpus has no fog: 0 fixture units carry seen_by'] = function()
    -- An equality zero on purpose (corpus_scale doctrine): (甲) is argued from
    -- it, so it must go red the moment the dumper lands vision, rather than
    -- quietly surviving as a stale limitation.
    assert(SWEEP.seen_by_units == 0, SWEEP.seen_by_units .. ' unit(s) now carry '
        .. 'seen_by -- the corpus grew fog; re-read (甲), it may be obsolete')
    cs.ratchet(SWEEP.files, 100, 'fixture files scanned')
    cs.ratchet(SWEEP.frames, 100, 'fixture frames driven')
end

tests['[drive D1] the vision operand and the memory operand return the same count on every corpus frame, at every shipped radius'] = function()
    -- This is the whole content of (甲). A lever whose text is "ask memory
    -- instead of vision" changes NO answer anywhere in tests/fixtures/, so
    -- 铁律 4's mandatory local validation would report it green without having
    -- exercised it once.
    assert(SWEEP.agree == SWEEP.pairs,
        (SWEEP.pairs - SWEEP.agree) .. ' of ' .. SWEEP.pairs .. ' (frame, radius) '
        .. 'pairs now separate the two operands -- fog reached the corpus and a '
        .. 'fog-memory lever became locally validatable; (甲) is obsolete')
    cs.ratchet(SWEEP.pairs, 300, '(frame, radius) pairs driven')
end

tests['[control C1] D1 is falsifiable: one injected stale-but-usable sighting separates the two operands'] = function()
    -- Without this the equality above is a claim about a predicate that may
    -- simply be incapable of differing -- the `campvoid` round's [control C1]
    -- lesson, and the reason `test_campdanger_switch_safe.lua`'s "genuine fog
    -- memory" line reads stronger than the corpus supports.
    local path = fixture_files()[1]
    local fx = dofile(path)
    local subject
    for _, u in ipairs(fx.units) do
        if u.alive then subject = u.name break end
    end
    assert(subject, 'the first fixture carries no living unit')
    local J, bot = rf.load(path, subject)

    local base_vis = #J.GetNearbyHeroes(bot, 1600, true, BOT_MODE_NONE)
    local base_mem = #J.GetLastSeenEnemiesNearLoc(bot:GetLocation(), 1600)
    assert(base_vis == base_mem, 'the chosen control frame already separates')

    -- The state the corpus never contains: seen recently, not seen NOW. This is
    -- exactly what #324 §2's frame would look like under the fog reading, and
    -- exactly what a fixture cannot carry today -- one frame has no history.
    local real = GetHeroLastSeenInfo
    local ghost = GetTeamPlayers(GetOpposingTeam())[1]
    assert(ghost ~= nil, 'the loader handed out no enemy player ids')
    GetHeroLastSeenInfo = function(id)
        if id == ghost then
            return { { location = bot:GetLocation(), time_since_seen = 1.0 } }
        end
        return real(id)
    end
    local ghost_mem = #J.GetLastSeenEnemiesNearLoc(bot:GetLocation(), 1600)
    GetHeroLastSeenInfo = real

    assert(ghost_mem > base_vis, 'a stale-but-usable sighting did not move the '
        .. 'memory operand (' .. ghost_mem .. ' vs vision ' .. base_vis
        .. ') -- D1 cannot separate the two operands even in principle, and is vacuous')
    assert(#J.GetLastSeenEnemiesNearLoc(bot:GetLocation(), 1600) == base_mem,
        'the injection leaked past this test')
end

tests['[source S3] landing seen_by would not be enough: the loader has no stale memory, only 0 or 999'] = function()
    -- (乙). The stamp is read from the loader's source rather than restated, so
    -- this goes red when the loader learns to carry a real staleness.
    local stamp = LOADER_CODE:match('time_since_seen%s*=%s*([^\n,]+)')
    assert(stamp, 'the loader no longer stamps time_since_seen')
    assert(stamp:find('and 0 or 999', 1, true),
        'the loader\'s time_since_seen stamp changed to `' .. stamp
        .. '` -- if it now carries a real staleness, (乙) is obsolete and a '
        .. 'fog-memory lever may be locally validatable')

    -- 999 is past every window any shipped reader opens, so "invisible" reads
    -- as "no memory", never as "stale memory". Windows read from source, never
    -- restated (backlog 0SRC: a census that copies its own constant reports the
    -- old world unmoved after the constant moves).
    local widest = 0
    local n_windows = 0
    for w in JMZ_CODE:gmatch('time_since_seen%s*<%s*([%d%.]+)') do
        n_windows = n_windows + 1
        widest = math.max(widest, tonumber(w))
    end
    assert(n_windows >= 4, 'only ' .. n_windows .. ' last-seen window(s) left in '
        .. JMZ .. ' -- the fog reader family shrank')
    assert(widest > 0 and widest < 999, 'a shipped last-seen window (' .. widest
        .. ') now reaches the loader\'s 999 sentinel -- an invisible hero would '
        .. 'read as a sighting, which the loader\'s own comment forbids')

    -- And the honest half. Crossing 999 is the ONLY thing about this window
    -- that anything in this repository can detect: M13/M14 above move it to
    -- 60.0 and to 900.0 and every case in this file stays green, because on a
    -- corpus where every sighting is 0 or 999 no value in the open interval
    -- changes an answer. So the assertion just made is a bound, not a test of
    -- the window -- which is exactly why the fog lever cannot be tuned here.
    assert(widest ~= 999, 'the window landed exactly on the sentinel')
end

tests['[arith A1] #324 §3\'s packaging question is decided by containment, not by strength'] = function()
    -- GH #324 §1, verbatim: {stratum, leg, domain, has 'other', ONLY 'other'}.
    -- Not re-derived here (see the honest bounds); the subtraction and the rule
    -- it implies are what this asserts.
    local CELLS = {
        { 'ab', 'armed',    2382, 110, 93 },
        { 'ab', 'baseline', 2811,  65, 58 },
        { 'ba', 'armed',    1494,  44, 37 },
        { 'ba', 'baseline', 1445,  62, 49 },
    }
    for _, c in ipairs(CELLS) do
        local has, only = c[4], c[5]
        local both = has - only               -- also carries creep/neutral damage
        assert(both > 0, c[1] .. '/' .. c[2] .. ': the overlap is empty -- the '
            .. 'two domains would be disjoint outright, a stronger claim than made')
        local overlap = both / has
        -- 铁律 4(i): the direction must hold in BOTH strata AND both legs, or
        -- it is noise. It does, and that is why this is a property of the
        -- DOMAIN rather than an armed-baseline difference.
        assert(overlap > 0.10 and overlap < 0.25, c[1] .. '/' .. c[2]
            .. ': overlap ' .. string.format('%.3f', overlap) .. ' left the '
            .. 'band the ruling was written from')
        assert(only / has >= 0.79, c[1] .. '/' .. c[2] .. ': the disjoint share '
            .. 'fell below 79% -- the "own id" half of the ruling weakens')
    end
    -- The rule, stated so a later round cannot re-derive it differently: a
    -- lever whose domain is mostly DISJOINT from an armed id gets its own id;
    -- a lever whose domain CONTAINS an armed id's must be that id's second
    -- clause, because otherwise neither (a) reading is attributable to either
    -- (this group's GH #319). The negative form of §3 contains `fieldcreep` by
    -- construction: every frame `WasRecentlyDamagedByCreep` vetoes is a frame
    -- that took damage while the four clauses said safe.
    assert(true)
end

tests['[arith A2] the §2 frame rules out walking, and does not rule out a teleport'] = function()
    -- GH #324 §2's own columns for vengefulspirit at t=646.5 and t=647.5.
    local D_BEFORE, D_AFTER, DT = 518, 4552, 1.0
    local speed = (D_AFTER - D_BEFORE) / DT
    -- Dota's hard movement-speed cap. Not a tuning constant and not read from
    -- `bots/` (nothing there caps a speed); it is the game rule the arithmetic
    -- is against, and it is stated so the ratio below is checkable.
    local MOVE_CAP = 550
    assert(speed / MOVE_CAP > 7.0, 'the §2 jump is ' .. string.format('%.1f', speed)
        .. ' u/s, only ' .. string.format('%.1f', speed / MOVE_CAP)
        .. 'x the cap -- the "she did not walk out" step no longer holds')

    -- What that does NOT settle, said out loud rather than left implied. A
    -- completed teleport moves a hero arbitrarily far in one frame and would
    -- make her genuinely gone, in which case the first danger clause was right
    -- and the ward reading is the only gap after all. The discriminator is a
    -- teleport modifier or channel event on the shaman in 644.5-647.5, which
    -- lives in the W25 timeline and not in this repository.
    local RULED_OUT = { walking = true }
    local OPEN = { vision_loss = true, completed_teleport = true }
    assert(RULED_OUT.walking and OPEN.vision_loss and OPEN.completed_teleport,
        'the ruling above was narrowed without re-reading the frame')
end

tests['[control C2] the comment stripper works, and where it is load-bearing'] = function()
    -- Proven on synthetic text rather than assumed. The block-comment control
    -- MUST be multi-line (`0CONJ` self-injury 乙, and `0SENSE` repeated it): on
    -- a single-line block the line-comment pass strips the same text, so a
    -- broken block pass stays green. Only the block pass can remove the SECOND
    -- line, so that is what is asserted.
    local blk = code_only('a --[[ b\nc ]] d')
    assert(blk:find('a') and blk:find('d') and not blk:find('c'),
        'code_only no longer strips a multi-line block comment')
    assert(not code_only('x = 1 -- GetLastSeenEnemiesNearLoc(v, 800)\ny = 2')
        :find('GetLastSeenEnemiesNearLoc', 1, true),
        'code_only no longer strips a line comment')

    -- Where it is load-bearing TODAY, measured rather than assumed. Unlike the
    -- `fieldcreep` round -- where the prose described the read in words and the
    -- stripper changed nothing -- `jmz_func.lua` DOES quote the fog reads in
    -- prose (the block above J.IsCampSwitchSafe names GetLastSeenEnemiesNearLoc
    -- outright), so a mutation swapping JMZ_CODE for JMZ_SRC is caught here.
    local raw = count(JMZ_SRC, 'GetLastSeenEnemiesNearLoc')
    local code = count(JMZ_CODE, 'GetLastSeenEnemiesNearLoc')
    assert(raw > code, 'the prose stopped quoting the fog read (' .. raw
        .. ' raw vs ' .. code .. ' in code) -- code_only is no longer '
        .. 'load-bearing for [source S1], and this control has lost its teeth')
end

tests['[limit] what this file does not buy'] = function()
    -- (1) No behaviour, and deliberately no placeholder gate. A placeholder id
    -- would assert the lever is validatable, which is what this file refutes.
    for _, id in ipairs({ 'fieldward', 'fieldfog', 'fieldsummon' }) do
        assert(not JMZ_CODE:find(id, 1, true), 'gate id \'' .. id .. '\' landed '
            .. '-- this file argued no #324 lever could be validated today; '
            .. 'either a missing fact arrived or the argument was wrong')
    end

    -- (2) It does not measure how often the ward case happens in a GAME. #324's
    -- 2.1%-3.9% is over 121 games of batch corpus this repository does not
    -- carry, and the local corpus is three orders of magnitude smaller.
    assert(SWEEP.frames < 1000, 'the local corpus reached batch scale -- the '
        .. 'limitation above is stale and the domain rate could be re-taken here')

    -- (3) It does not resolve WasRecentlyDamagedByCreep's two worlds. [arith A1]
    -- is world-independent by construction; nothing else here reads the domain.
    assert(count(BODY, 'WasRecentlyDamagedByCreep') == 1,
        'the creep read changed shape -- re-check that A1 is still '
        .. 'world-independent before trusting it')
end

return tests

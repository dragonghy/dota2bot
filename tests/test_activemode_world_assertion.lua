-- The THIRTEENTH world assertion: on a fixture nobody is in a mode.
--
-- `bot:GetActiveMode()` is the bot VM's own state -- which of the mode scripts
-- won this frame's bidding.  It is not an entity property, so it is not in the
-- .dem stream, so no fixture carries it, so the mock answers the generic
-- `default_for('Get*') = 0` (tests/mock/bot_api.lua).  Meanwhile every
-- `BOT_MODE_*` name in bots/ resolves through the auto-constant metatable to a
-- distinct id >= 1001.  The consequence, measured below over the whole archive:
--
--     bot:GetActiveMode() == BOT_MODE_ANYTHING   is FALSE on every hero,
--     on every frame, for every one of the 24 mode names, at all 210 shipped
--     comparison lines.
--
-- WHY THIS IS A WORLD ASSERTION AND NOT A MISSING STUB
-- ---------------------------------------------------
-- Same family as GH #61 (lane front = map origin) and GH #81 (--roles cannot
-- reach the enemy): an undeclared constant sitting under an otherwise real
-- frame, so an assertion that forks on it describes the harness, not the game
-- it came from.  What makes this one worse than its predecessors is that BOTH
-- directions are wrong, and they are wrong the OPPOSITE WAY:
--
--   * script-side comparison (`member:GetActiveMode() == BOT_MODE_ATTACK`)
--     -- constant FALSE.  Ten shipped J predicates degenerate to `false`.
--   * engine-side filter (`bot:GetNearbyHeroes(r, false, BOT_MODE_ATTACK)`)
--     -- the loader's replacement takes the mode argument and IGNORES it
--     (`function(self, radius, enemies, _)`), so the filter is silently
--     dropped and the call answers "every ally within r".  Over-permissive.
--     `J.IsInTeamFight` reads TRUE on 71 of 872 hero-frames because of it.
--
-- So one missing datum makes one family of predicates never fire and another
-- family fire too often, and nothing in the suite said so until now.
--
-- WHAT IT COSTS US TODAY (the reason this file exists now)
-- -------------------------------------------------------
-- GH #84 §5 / charter backlog 0i named `mode_farm_generic:285` the headline
-- TEETH row and made one precondition explicit: before touching a shared
-- consumption path we need a REAL frame where the teamfight location is inside
-- 2500 and the subject is a core.  A corpus request for that frame was routed
-- to the replay group.
--
-- That frame does not exist and cannot be bought.  `J.GetTeamFightLocation`
-- ends in `J.GetCenterOfUnits(J.GetSpecialModeAllies(member, 1400,
-- BOT_MODE_ATTACK))`, `GetSpecialModeAllies` compares GetActiveMode, and
-- `GetCenterOfUnits` answers `Vector(0,0)` for an empty list -- the MAP ORIGIN,
-- not nil.  Measured over the archive: 6 of 188 team-frames answer non-nil, all
-- 6 at the origin, none anywhere else; the 7 hero-frames that then satisfy
-- "distance < 2500 and IsCore" qualify because they are standing near the
-- river, not because a fight is happening.  Every one of those 7 is a phantom.
-- Buying more replays cannot help: the datum is not in a .dem at all (the
-- dumper's field list is asserted below to contain nothing mode-shaped), so
-- supplying it would mean MODELLING which mode a bot was in -- exactly what the
-- fixture discipline exists to forbid.
--
-- A SHIPPED READING THAT IS NOT A HARNESS ARTEFACT
-- -----------------------------------------------
-- `GetTeamFightLocation` uses `Vector(0,0)` as its empty answer while all 35
-- consumers test `~= nil`.  In game the two radii differ (IsInTeamFight looks
-- 1500 and excludes self; GetSpecialModeAllies looks 1400 and includes self),
-- so two attack-mode allies in the 1400-1500 shell with the member itself not
-- attacking yields the same empty list and the same origin -- "the teamfight is
-- at the river" -- to all 35 readers.  That band is narrow and this harness
-- CANNOT decide how often it is entered; it is recorded here as a candidate
-- lever with its precondition (in-game observation or a labelled synthetic),
-- NOT proposed as a change.  Nothing in bots/ is touched by this file.

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')

-- ---------------------------------------------------------------------------
-- Corpus sweep, computed once.
--
-- One load per (fixture, team) rather than one per subject: the mode predicates
-- all take their unit as an argument, and `J.GetTeamFightLocation` reads only
-- `GetTeam()` (its `bot` parameter is unused), so a per-team load reaches every
-- hero-frame.  Verified to reproduce the per-subject sweep exactly -- 872
-- hero-frames, 30 non-nil teamfight readings, 7 qualifying core rows.

--- The mode predicates jmz_func builds directly on GetActiveMode.
local MODE_PREDICATES = {
    'IsRetreating', 'IsGoingOnSomeone', 'IsDefending', 'IsPushing',
    'IsLaning', 'IsDoingRoshan', 'IsShopping', 'IsFarming',
}

local sweep_cache
local function sweep()
    if sweep_cache then return sweep_cache end
    local s = {
        fixtures = 0, team_frames = 0, hero_frames = 0,
        mode_nonzero = 0, proper_target_nonnil = 0,
        pred_true = {}, in_teamfight_1500 = 0,
        mode_filter_ignored = 0, mode_filter_honoured = 0,
        special_allies_nonempty = 0,
        tfl_teams_nonnil = 0, tfl_hero_nonnil = 0,
        tfl_at_origin = 0, tfl_off_origin = 0,
        tfl_within_2500 = 0, qualifying = {},
    }
    for _, k in ipairs(MODE_PREDICATES) do s.pred_true[k] = 0 end

    local p = assert(io.popen('ls tests/fixtures'))
    local files = {}
    for f in p:lines() do
        if f:match('^f_.*%.lua$') then files[#files + 1] = f end
    end
    p:close()
    table.sort(files)

    for _, f in ipairs(files) do
        local path = 'tests/fixtures/' .. f
        local fx = dofile(path)
        s.fixtures = s.fixtures + 1
        local first_of_team, team_order = {}, {}
        for _, u in ipairs(fx.units) do
            if u.name:match('^npc_dota_hero_') and u.alive and not first_of_team[u.team] then
                first_of_team[u.team] = u.name
                team_order[#team_order + 1] = u.team
            end
        end
        for _, team in ipairs(team_order) do
            local J, _, heroes = rf.load(path, first_of_team[team])
            s.team_frames = s.team_frames + 1
            local vFight = J.GetTeamFightLocation(nil)
            if vFight ~= nil then s.tfl_teams_nonnil = s.tfl_teams_nonnil + 1 end
            -- GetSpecialModeAllies over every member of the loaded team.
            for i = 1, #GetTeamPlayers(GetTeam()) do
                local member = GetTeamMember(i)
                if member ~= nil and #J.GetSpecialModeAllies(member, 1400, BOT_MODE_ATTACK) > 0 then
                    s.special_allies_nonempty = s.special_allies_nonempty + 1
                end
            end
            for _, u in ipairs(fx.units) do
                if u.name:match('^npc_dota_hero_') and u.alive and u.team == team then
                    local hero = heroes[u.name]
                    s.hero_frames = s.hero_frames + 1
                    if hero:GetActiveMode() ~= 0 then s.mode_nonzero = s.mode_nonzero + 1 end
                    for _, k in ipairs(MODE_PREDICATES) do
                        if J[k](hero) then s.pred_true[k] = s.pred_true[k] + 1 end
                    end
                    if J.GetProperTarget(hero) ~= nil then
                        s.proper_target_nonnil = s.proper_target_nonnil + 1
                    end
                    if J.IsInTeamFight(hero, 1500) then
                        s.in_teamfight_1500 = s.in_teamfight_1500 + 1
                    end
                    local attack_filtered = hero:GetNearbyHeroes(1500, false, BOT_MODE_ATTACK)
                    local unfiltered = hero:GetNearbyHeroes(1500, false, BOT_MODE_NONE)
                    if #attack_filtered == #unfiltered then
                        s.mode_filter_ignored = s.mode_filter_ignored + 1
                    else
                        s.mode_filter_honoured = s.mode_filter_honoured + 1
                    end
                    if vFight ~= nil then
                        s.tfl_hero_nonnil = s.tfl_hero_nonnil + 1
                        if math.abs(vFight.x) < 0.001 and math.abs(vFight.y) < 0.001 then
                            s.tfl_at_origin = s.tfl_at_origin + 1
                        else
                            s.tfl_off_origin = s.tfl_off_origin + 1
                        end
                        if GetUnitToLocationDistance(hero, vFight) < 2500 then
                            s.tfl_within_2500 = s.tfl_within_2500 + 1
                            if J.IsCore(hero) then
                                s.qualifying[#s.qualifying + 1] = {
                                    fixture = f,
                                    hero = u.name:gsub('npc_dota_hero_', ''),
                                    at_origin = math.abs(vFight.x) < 0.001
                                        and math.abs(vFight.y) < 0.001,
                                }
                            end
                        end
                    end
                end
            end
        end
    end
    sweep_cache = s
    return s
end

local function read_file(path)
    local fh = assert(io.open(path, 'r'))
    local body = fh:read('*a')
    fh:close()
    return body
end

--- Every `BOT_MODE_*` name the shipped code names, minus the DESIRE family
--- (those are thresholds, not modes, and the mock gives them real values).
local function scan_mode_names()
    local names, ordered = {}, {}
    local p = assert(io.popen('find bots -name "*.lua" | sort'))
    for file in p:lines() do
        for line in io.lines(file) do
            for m in line:gmatch('BOT_MODE_[A-Z0-9_]+') do
                if not m:match('^BOT_MODE_DESIRE') and not names[m] then
                    names[m] = true
                    ordered[#ordered + 1] = m
                end
            end
        end
    end
    p:close()
    table.sort(ordered)
    return ordered
end

--- Shipped call-site counts for the three things this file is about.
local function scan_call_sites()
    local out = { get_active_mode = 0, compare_lines = 0, teamfight_consumers = 0 }
    local p = assert(io.popen('find bots -name "*.lua" | sort'))
    for file in p:lines() do
        for line in io.lines(file) do
            for _ in line:gmatch('GetActiveMode%s*%(%s*%)') do
                out.get_active_mode = out.get_active_mode + 1
            end
            if line:match('GetActiveMode%s*%(%s*%)') and line:match('BOT_MODE_') then
                out.compare_lines = out.compare_lines + 1
            end
            for _ in line:gmatch('J%.GetTeamFightLocation%s*%(') do
                if not line:match('^%s*function') then
                    out.teamfight_consumers = out.teamfight_consumers + 1
                end
            end
        end
    end
    p:close()
    return out
end

local tests = {}

-- ---------------------------------------------------------------------------
-- 1. The assertion itself.

tests['[world] every hero on every fixture frame answers GetActiveMode() = 0'] = function()
    local s = sweep()
    assert(s.fixtures == 96, 'expected 96 fixtures, got ' .. s.fixtures)
    assert(s.team_frames == 192, 'expected 192 team-frames, got ' .. s.team_frames)
    assert(s.hero_frames == 892, 'expected 892 hero-frames, got ' .. s.hero_frames)
    assert(s.mode_nonzero == 0,
        s.mode_nonzero .. ' hero-frames answered a non-zero active mode. If the loader '
        .. 'learned to carry modes this is GOOD NEWS -- but every conclusion pinned '
        .. 'against "no bot is in a mode" has to be re-read before this number moves.')
end

tests['[world] no BOT_MODE_* constant equals the 0 the mock answers'] = function()
    local names = scan_mode_names()
    assert(#names == 24, 'expected 24 distinct mode names in bots/, got ' .. #names)
    for _, name in ipairs(names) do
        local value = _G[name]
        assert(type(value) == 'number', name .. ' is not a number in the mock env')
        assert(value ~= 0, name .. ' resolves to 0, which is what GetActiveMode() answers -- '
            .. 'that one comparison would start reading TRUE everywhere')
    end
    -- Including BOT_MODE_NONE: the loader answers the engine's numeric "no mode"
    -- while the mock's BOT_MODE_NONE is an auto-id, so even the honest reading
    -- of 0 misses. Both readings fail the same way -- every comparison is false.
    assert(_G.BOT_MODE_NONE ~= 0, 'BOT_MODE_NONE is 0')
end

tests['[world] the mode predicates are constant-false across the whole archive'] = function()
    local s = sweep()
    for _, k in ipairs(MODE_PREDICATES) do
        assert(s.pred_true[k] == 0, string.format(
            'J.%s read TRUE on %d/%d hero-frames. It was 0/872 when this was pinned; '
            .. 'if the world changed, re-read every conclusion that used it.',
            k, s.pred_true[k], s.hero_frames))
    end
end

tests['[world] J.IsFarming is false for a SECOND, independent reason'] = function()
    -- IsFarming has a live-looking disjunct (`J.GetProperTarget` is a neutral
    -- creep). It is not a survivor of this gap: the archive carries heroes and
    -- structures only, so the proper target is nil on every hero-frame too.
    -- Worth keeping separate -- if the loader ever learns modes, this predicate
    -- still will not fire until the corpus grows neutrals.
    local s = sweep()
    assert(s.proper_target_nonnil == 0,
        'J.GetProperTarget answered non-nil on ' .. s.proper_target_nonnil .. ' hero-frames')
end

-- ---------------------------------------------------------------------------
-- 2. The other direction: the loader drops the filter instead of failing it.

tests['[reverse] the loader ignores the mode argument of GetNearbyHeroes'] = function()
    local src = read_file('tests/mock/replay_fixture.lua')
    assert(src:match('GetNearbyHeroes%s*=%s*function%s*%(self,%s*radius,%s*enemies,%s*_%)'),
        'the loader\'s GetNearbyHeroes no longer discards its mode parameter -- if it now '
        .. 'honours it, this whole file\'s numbers move and must be re-measured')
    assert(not src:match('GetActiveMode'),
        'the loader now mentions GetActiveMode; re-read this file before trusting it')
end

tests['[reverse] dropping it makes the mode-filtered call over-permissive'] = function()
    local s = sweep()
    assert(s.mode_filter_ignored == 892 and s.mode_filter_honoured == 0, string.format(
        'GetNearbyHeroes(1500,false,BOT_MODE_ATTACK) differed from the unfiltered call on '
        .. '%d hero-frames -- the filter is being honoured now', s.mode_filter_honoured))
    -- ... and that is why the one predicate on the engine-filtered path fires
    -- while all eight on the comparison path never do. One missing datum, two
    -- opposite errors.
    -- 71 -> 77 on 2026-08-21T15:xxZ: the hero stream added the two GH #86 Lion
    -- frames (f_260820_162821_lion_drain_lethal / f_260820_182906_lion_drain_
    -- survived), both of them mid-fight, contributing 6 TRUE readings. The
    -- corpus grew; nothing about the world assertion moved (mode_nonzero is
    -- still 0, the filter is still ignored on all 892 hero-frames).
    assert(s.in_teamfight_1500 == 77, string.format(
        'J.IsInTeamFight(bot,1500) read TRUE on %d/%d hero-frames (77 when pinned)',
        s.in_teamfight_1500, s.hero_frames))
end

-- ---------------------------------------------------------------------------
-- 3. The consequence for GH #84 §5 / backlog 0i: the requested frame is a
--    phantom, and no purchase can produce a real one.

tests['[world] GetSpecialModeAllies is empty on every member of every frame'] = function()
    local s = sweep()
    assert(s.special_allies_nonempty == 0,
        'GetSpecialModeAllies answered non-empty ' .. s.special_allies_nonempty .. ' times')
end

tests['[world] so GetTeamFightLocation only ever answers nil or the map origin'] = function()
    local s = sweep()
    assert(s.tfl_teams_nonnil == 8, 'expected 8 non-nil team readings, got ' .. s.tfl_teams_nonnil)
    assert(s.tfl_hero_nonnil == 40, 'expected 40 non-nil hero-frames, got ' .. s.tfl_hero_nonnil)
    assert(s.tfl_at_origin == 40, 'expected all 40 at the origin, got ' .. s.tfl_at_origin)
    assert(s.tfl_off_origin == 0, s.tfl_off_origin .. ' readings landed somewhere real -- '
        .. 'that would be the first true teamfight location in the archive; re-read this file')
end

tests['[blocked] the frame GH #84 §5 asks for does not exist in the archive'] = function()
    -- "teamfight location non-nil AND inside 2500 AND the subject is a core"
    -- selects seven hero-frames. All seven qualify by standing near the river,
    -- because the location IS the river -- the map origin. None of them is
    -- evidence that a core was farming next to a fight.
    local s = sweep()
    local EXPECTED = {
        { fixture = 'f_071859_oracle_screen.lua',                  hero = 'viper' },
        { fixture = 'f_260819_222052_zuus_w2_leak.lua',            hero = 'chaos_knight' },
        { fixture = 'f_260819_222052_zuus_w2_leak.lua',            hero = 'dragon_knight' },
        { fixture = 'f_260819_222052_zuus_w2_leak.lua',            hero = 'skywrath_mage' },
        { fixture = 'f_260819_222052_zuus_w2_leak.lua',            hero = 'slardar' },
        { fixture = 'f_260819_222052_zuus_w2_leak.lua',            hero = 'zuus' },
        { fixture = 'f_megabundle_052241_sniper_l1trade_chase.lua', hero = 'death_prophet' },
    }
    assert(s.tfl_within_2500 == 7,
        'expected 7 hero-frames inside 2500, got ' .. s.tfl_within_2500)
    assert(#s.qualifying == #EXPECTED, string.format(
        'expected %d qualifying core rows, got %d', #EXPECTED, #s.qualifying))
    for i, want in ipairs(EXPECTED) do
        local got = s.qualifying[i]
        assert(got.fixture == want.fixture and got.hero == want.hero, string.format(
            'row %d: expected %s/%s, got %s/%s', i, want.fixture, want.hero,
            got.fixture, got.hero))
        assert(got.at_origin, string.format(
            '%s/%s now qualifies against a location that is NOT the map origin. That would '
            .. 'be the mode_farm_generic:285 evidence frame backlog 0i is blocked on -- '
            .. 'check WHY before using it.', got.fixture, got.hero))
    end
end

tests['[recorded] the datum is not in a .dem, so no corpus purchase supplies it'] = function()
    -- The behavioral pipeline parses the replay's entity + combat-log stream
    -- (tools/batch_test/behavioral/README.md). A bot's active mode is bot-VM
    -- state chosen by our own Lua each frame, not a replicated entity property,
    -- so it is absent from the dumper's field list -- and reconstructing it
    -- would be a MODEL of what the bot was thinking, not a measurement.
    local src = read_file('tools/batch_test/behavioral/dumper/main.go')
    local fields = {}
    for name in src:gmatch('json:"([%w_]+)"') do fields[#fields + 1] = name end
    assert(#fields > 20, 'dumper field scan found only ' .. #fields .. ' fields')
    for _, name in ipairs(fields) do
        assert(not name:find('mode'), 'the dumper now emits a field named "' .. name
            .. '" -- if that is the bot mode, this entire file is obsolete in the best way')
    end
end

-- ---------------------------------------------------------------------------
-- 4. The shipped half: an empty list becomes a location at the river.

tests['[reverse] shipped: GetCenterOfUnits answers the map origin for an empty list'] = function()
    local J = rf.load('tests/fixtures/f_260819_222052_zuus_w2_leak.lua')
    local v = J.GetCenterOfUnits({})
    assert(v ~= nil, 'GetCenterOfUnits({}) returned nil -- the sentinel changed, and with it '
        .. 'every consumer that tests `~= nil`')
    assert(v.x == 0 and v.y == 0, 'GetCenterOfUnits({}) no longer answers (0,0)')
end

tests['[reverse] GetTeamFightLocation hands that origin back as a location'] = function()
    -- The gap is structural, not incidental: there is no emptiness check
    -- between GetSpecialModeAllies and the return, so "no ally is attacking
    -- near the member" is reported to all 35 consumers as "the fight is at the
    -- river". In game the escape is the radius mismatch below; this harness
    -- cannot measure how often it is entered, and this file does not claim to.
    local src = read_file('bots/FunLib/jmz_func.lua')
    local body = src:match('function J%.GetTeamFightLocation.-\nend')
    assert(body, 'J.GetTeamFightLocation not found')
    assert(body:match('J%.GetCenterOfUnits%(%s*allyList%s*%)'),
        'the center-of-units call moved; re-read this pin')
    assert(not body:match('#allyList'),
        'GetTeamFightLocation now inspects the ally list before returning its center -- '
        .. 'if that is the emptiness guard, this pin has been fixed and should be retired')
    assert(body:match('J%.IsInTeamFight%(%s*member,%s*1500%s*%)'),
        'the IsInTeamFight radius moved off 1500')
    assert(body:match('J%.GetSpecialModeAllies%(%s*member,%s*1400,%s*BOT_MODE_ATTACK%s*%)'),
        'the GetSpecialModeAllies radius moved off 1400')
    -- 1500 excluding self vs 1400 including self: the shell between them is the
    -- in-game path to an empty list, and it is the reason this is recorded as a
    -- candidate lever rather than dismissed as a harness artefact.
end

tests['[recorded] call-site census: how much rides on the missing datum'] = function()
    local c = scan_call_sites()
    assert(c.get_active_mode == 255,
        'GetActiveMode() call sites moved from 255 to ' .. c.get_active_mode)
    assert(c.compare_lines == 210,
        'lines comparing GetActiveMode() to a BOT_MODE_* moved from 210 to ' .. c.compare_lines)
    assert(c.teamfight_consumers == 35,
        'J.GetTeamFightLocation consumers moved from 35 to ' .. c.teamfight_consumers)
end

return tests

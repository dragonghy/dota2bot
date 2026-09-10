-- [strategy 20260910, second unit] J.IsValid IS FALSE FOR EVERY BUILDING, BY
-- CONSTRUCTION -- and this file is the reading that says what that costs.
--
-- WHY IT WAS TAKEN. The charter's next slot named one question and told the
-- round to PRICE it before touching anything: J.GetCenterOfUnits has a SECOND
-- sentinel path -- `#nUnits > 0` but no element passes J.IsValid, which also
-- answers Vector(0,0), the map origin -- and the 'tfnull' round left it with
-- the shipped answer on purpose ("covering it would need a second ruler for
-- who counts"). The instruction was: measure whether it is reachable in the
-- corpus; if it is not, take the next candidate and DO NOT force a fix.
--
-- THE ANSWER IS IN TWO HALVES AND THEY DIFFER IN KIND -- that difference is
-- the finding, not the zero:
--   * the HERO half (J.GetEnemiesNearLoc, J.GetNearbyHeroes, J.GetAlliesNearLoc,
--     J.GetSpecialModeAllies -- 88 of the 211 call sites section 3 resolves,
--     plus 2 of the 12 it leaves unresolved by name) is unreachable by
--     IMPLICATION, not merely by this corpus. J.IsValidHero = IsValidUnit and
--     IsHero, and IsHero excludes IsBuilding, so IsValidHero(u) => IsValid(u)
--     for every u on every frame. Section 2 measures the implication anyway
--     (0 disagreements over 1110 hero rows) because an implication read off
--     source and never executed is a claim, not a reading.
--   * the CREEP half (bot:GetNearbyLaneCreeps / GetNearbyNeutralCreeps /
--     GetNearbyCreeps -- 91 resolved sites plus 9 unresolved `nEnemyLaneCreeps`
--     ones) is UNPRICEABLE here, which is not the same
--     as zero: tests/mock/replay_fixture.lua answers `{}` to all three on all
--     111 fixtures, even though 2 fixtures carry a 45-row creep sample the
--     dumper already wrote. A SUPPLY gap of the GH #27 kind. Section 2 asserts
--     it so that a loader which later wires creeps turns this file red and the
--     question comes back.
--
-- ⭐ WHAT THE SWEEP FOUND ANYWAY. There IS a shape in this corpus that reaches
-- the second sentinel, and it is not a creep: a STRUCTURE list. 520 of 520
-- non-empty bot:GetNearbyTowers lists hold no J.IsValid unit at all, because
-- J.IsValid's last conjunct is `not nTarget:IsBuilding()`. Section 1 pins that
-- the rejection has that CAUSE and no other -- on real dump structures every
-- other conjunct (not null, can be seen, alive) is true.
--
-- ⛔ AND THE RULING THE CHARTER ASKED FOR: no J.GetCenterOfUnits call site in
-- bots/ is fed a structure list -- section 3 resolves 199 of the 211 sites to
-- exactly NINE producers and pins that set, and classifies the other 12 by
-- variable name -- so the second sentinel stays unreachable THERE, and this
-- round did not touch it. (The `{}` literal, 20 sites, is the FIRST sentinel:
-- that is 'tfnull' / 'fbnoally' territory, already read.)
--
-- ⭐⭐ THE SAME FACT IS LIVE ONE FILE OVER, AND THAT IS THE HANDOFF. Section 3
-- also scans the mirror question -- who feeds a structure list to a UNIT
-- validator -- and the tree has exactly ONE such site: mode_farm_generic's
-- runMode branch does `J.IsValid(runModeBarracks[1])` on a list that only ever
-- holds barracks, so the condition is false on every frame of every game and
-- the branch under it (attack the enemy barracks while running deep) has never
-- executed. The other 202 structure-list sites do not make this mistake, and
-- the repo ships the right validator -- J.IsValidBuilding, 74 call sites.
--
-- ⛔ WHY NO bots/ CHANGE IS LANDED FOR IT IN THIS ROUND, said before the
-- numbers rather than after: the branch's own domain is EMPTY in this corpus.
-- 0 of 1031 live hero frames have an enemy barracks within 1600, let alone
-- within the branch's `GetAttackRange() + 150` -- and GetAttackRange itself is
-- not dump ground truth (every fixture hero answers the mock's 150). So the
-- consequence cannot be driven on an un-injected frame today, and section 4
-- records the finding as a finding. Frequency is claimed nowhere below.
--
-- Charter: iterations/streams/strategy.md, backlog head. Sibling readings:
-- tests/test_teamfight_location_origin.lua ('tfnull', the first sentinel),
-- tests/test_fbnoally_ally_center_origin.lua ('fbnoally', the empty list).

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')
local cs = require('corpus_scale')

local FARM = 'bots/mode_farm_generic.lua'
local JMZ = 'bots/FunLib/jmz_func.lua'

local tests = {}

-- --------------------------------------------------------------- helpers ---

local function read_file(path)
    local f = assert(io.open(path, 'r'), 'could not open ' .. path)
    local s = f:read('*a')
    f:close()
    return s
end

--- Source with every comment removed. This file's own finding names the call,
--- the variable and both validators, so an unstripped scan would let a COMMENT
--- satisfy the structural assertions (the 'fieldsip' lesson, recorded in
--- tests/test_gated_helper_nesting_census.lua).
local function stripped(src)
    src = src:gsub('%-%-%[(=*)%[.-%]%1%]', ' ')
    return (src:gsub('%-%-[^\n]*', ''))
end

local function lua_files()
    local out = {}
    local p = assert(io.popen('ls bots/*.lua bots/*/*.lua bots/*/*/*.lua 2>/dev/null'),
        'could not list bots/')
    for line in p:lines() do out[#out + 1] = line end
    p:close()
    assert(#out > 100, 'expected the bots/ tree, got ' .. #out .. ' files')
    return out
end

local function all_fixtures()
    local out = {}
    local p = assert(io.popen('ls tests/fixtures/*.lua 2>/dev/null'),
        'could not list tests/fixtures')
    for line in p:lines() do out[#out + 1] = line end
    p:close()
    return out
end

-- ------------------------------------------------------------ the sweep ----

--- One pass over the corpus. Every producer that feeds a J.GetCenterOfUnits
--- call site is asked on the real frame, and every list it returns is scored
--- the way GetCenterOfUnits itself scores it: is it non-empty, and does any
--- element pass J.IsValid?
local SWEEP = (function()
    local c = setmetatable({}, { __index = function() return 0 end })
    local function bump(k) c[k] = c[k] + 1 end

    local function score(prefix, J, list)
        bump(prefix .. '_lists')
        if list == nil or #list == 0 then return end
        bump(prefix .. '_nonempty')
        local nValid = 0
        for _, m in pairs(list) do
            if J.IsValid(m) then nValid = nValid + 1 end
        end
        -- The second sentinel path, stated exactly as GetCenterOfUnits states
        -- it: the list was not empty, and `num` still ended at 0.
        if nValid == 0 then bump(prefix .. '_sentinel2') end
    end

    for _, path in ipairs(all_fixtures()) do
        local ok, J, _, heroes, fx = pcall(rf.load, path)
        if not ok or J == nil then
            bump('load_fail')
        else
            bump('fixtures')
            if J.IsModeTurbo() then bump('turbo_fx') end
            if #(fx.buildings or {}) > 0 then bump('fx_with_buildings') end
            if #(fx.creeps or {}) > 0 then bump('fx_with_creeps') end

            -- Structures, straight from the dump. Every conjunct of J.IsValid is
            -- read separately so the REJECTION has an isolated cause.
            for _, kind in ipairs({ UNIT_LIST_ALLIED_BUILDINGS, UNIT_LIST_ENEMY_BUILDINGS }) do
                for _, b in pairs(GetUnitList(kind)) do
                    bump('bld')
                    if b:IsBuilding() then bump('bld_isbuilding') end
                    if not b:IsNull() then bump('bld_notnull') end
                    if b:CanBeSeen() then bump('bld_canbeseen') end
                    if b:IsAlive() then bump('bld_isalive') end
                    if J.IsValid(b) then bump('bld_isvalid') end
                    if J.IsValidBuilding(b) then bump('bld_isvalidbuilding') end
                end
            end

            for _, u in ipairs(fx.units) do
                local h = heroes[u.name]
                if h ~= nil then
                    bump('rows')
                    -- The implication the hero half rests on, executed rather
                    -- than read off the source.
                    if J.IsValidHero(h) and not J.IsValid(h) then bump('hero_not_valid') end
                    if u.alive then
                        bump('live')
                        for _, r in ipairs({ 600, 900, 1200, 1600 }) do
                            score('hero', J, J.GetNearbyHeroes(h, r, false, BOT_MODE_NONE))
                            score('hero', J, J.GetNearbyHeroes(h, r, true, BOT_MODE_NONE))
                        end
                        score('alloc', J, J.GetAlliesNearLoc(h:GetLocation(), 1200))
                        for _, r in ipairs({ 800, 1600 }) do
                            score('lanecreep', J, h:GetNearbyLaneCreeps(r, true))
                            score('lanecreep', J, h:GetNearbyLaneCreeps(r, false))
                            score('neutral', J, h:GetNearbyNeutralCreeps(r))
                            score('tower', J, h:GetNearbyTowers(r, true))
                            score('tower', J, h:GetNearbyTowers(r, false))
                        end
                        -- The runMode branch's own domain, at its own radius and
                        -- at a generous one.
                        local nRange = h:GetAttackRange()
                        if nRange > 1400 then nRange = 1400 end
                        bump('ar_' .. tostring(nRange))
                        if #h:GetNearbyBarracks(nRange + 150, true) > 0 then bump('rax_branch') end
                        if #h:GetNearbyBarracks(1600, true) > 0 then bump('rax_1600') end
                    end
                end
            end
        end
    end
    return c
end)()

local function C(k) return SWEEP[k] end

tests['[isvalidbld] 0. the sweep covered the corpus'] = function()
    assert(C('load_fail') == 0, C('load_fail') .. ' fixtures failed to load')
    cs.corpus(C('fixtures'), 'isvalidbld sweep')
    cs.ratchet(C('live'), 1031, 'live hero frames')
    cs.ratchet(C('rows'), 1110, 'hero rows')
    cs.universal(C('turbo_fx'), C('fixtures'), 'the corpus is all-Turbo', cs.FLOOR)
    cs.ratchet(C('fx_with_buildings'), 68, 'fixtures carrying structures')
end

-- ------------------------------- 1. the identity, on real dump structures ---

tests['[isvalidbld] 1. MEASURED: J.IsValid rejects every building, and only IsBuilding does it']
= function()
    -- Not "the numbers came out equal" -- the CAUSE is isolated. If a future
    -- loader stopped marking structures alive or visible, the rejection count
    -- would still match and the reason would be wrong; the three conjuncts
    -- below are what forbids reading it that way.
    -- ALIVE structures only: UNIT_LIST_*_BUILDINGS is the loader's alive set,
    -- which is the engine's own semantics (a destroyed structure is absent).
    -- The dump's raw building tables are larger; do not quote this as "rows in
    -- the fixtures".
    cs.ratchet(C('bld'), 2525, 'alive structure rows through UNIT_LIST_*_BUILDINGS')
    cs.universal(C('bld_isbuilding'), C('bld'), 'every structure answers IsBuilding', 100)
    cs.universal(C('bld_notnull'), C('bld'), 'no structure is null', 100)
    cs.universal(C('bld_canbeseen'), C('bld'), 'every structure can be seen', 100)
    cs.universal(C('bld_isalive'), C('bld'), 'every structure is alive', 100)
    assert(C('bld_isvalid') == 0, C('bld_isvalid') .. ' structures now pass '
        .. 'J.IsValid -- its `not IsBuilding()` conjunct is gone or IsBuilding '
        .. 'stopped answering, and every sentence in this file has to be re-read')
    cs.universal(C('bld_isvalidbuilding'), C('bld'),
        'J.IsValidBuilding accepts the same structures J.IsValid rejects', 100)
end

tests['[isvalidbld] 1b. the two validators differ in the source, not only in the reading']
= function()
    local src = stripped(read_file(JMZ))
    local body = src:match('function J%.IsValid%s*%(.-%)(.-)\nend')
    assert(body ~= nil, 'could not locate J.IsValid in ' .. JMZ)
    assert(body:find('IsBuilding', 1, true) ~= nil,
        'J.IsValid no longer mentions IsBuilding -- the identity this file '
        .. 'measures has moved into some other helper')
    assert(src:find('function J.IsValidBuilding', 1, true) ~= nil,
        'J.IsValidBuilding is gone -- the in-repo condition (c) for the finding '
        .. 'in section 3 no longer exists')
end

-- --------------------- 2. the charter's question: the second sentinel path --

tests['[isvalidbld] 2. MEASURED: no hero-list producer can reach the second sentinel']
= function()
    -- The implication, executed. IsValidHero => IsValid, so a non-empty list
    -- from any producer that filters on IsValidHero always has a contributor.
    assert(C('hero_not_valid') == 0, C('hero_not_valid') .. ' hero rows pass '
        .. 'J.IsValidHero and fail J.IsValid -- the implication the hero half '
        .. 'of this ruling rests on is broken')
    cs.ratchet(C('hero_lists'), 8248, 'hero-list productions')
    cs.ratchet(C('hero_nonempty'), 3315, 'non-empty hero lists')
    assert(C('hero_sentinel2') == 0, C('hero_sentinel2') .. ' non-empty hero '
        .. 'lists hold no J.IsValid unit -- the second sentinel is reachable '
        .. 'from a hero producer after all, and the charter\'s refusal is void')
    cs.ratchet(C('alloc_nonempty'), 736, 'non-empty GetAlliesNearLoc lists')
    assert(C('alloc_sentinel2') == 0, C('alloc_sentinel2') .. ' non-empty '
        .. 'GetAlliesNearLoc lists hold no J.IsValid unit -- and that producer '
        .. 'filters on IsAlive alone, so this one is a corpus reading, not an '
        .. 'implication: re-read it rather than quoting the zero')
end

tests['[isvalidbld] 2b. DECLARED: the creep half is unpriceable here, and that is not a zero']
= function()
    -- A supply gap, asserted so it cannot be quoted as "creeps never do this".
    -- The dump already carries the sample; the loader does not wire it into the
    -- three producers, so every creep call site reads an empty world.
    cs.ratchet(C('fx_with_creeps'), 2, 'fixtures carrying a creep sample')
    assert(C('lanecreep_nonempty') == 0, C('lanecreep_nonempty') .. ' lane-creep '
        .. 'lists are now non-empty -- the loader wires creeps, so the creep '
        .. 'half of the second-sentinel question is BUYABLE: re-open it instead '
        .. 'of quoting this file\'s refusal')
    assert(C('neutral_nonempty') == 0, C('neutral_nonempty') .. ' neutral-creep '
        .. 'lists are now non-empty -- same re-opening as the line above')
end

tests['[isvalidbld] 2c. MEASURED: the one shape that DOES reach it is a structure list']
= function()
    -- This is the positive half of the reading and the reason section 3 exists.
    cs.ratchet(C('tower_nonempty'), 520, 'non-empty structure lists')
    cs.universal(C('tower_sentinel2'), C('tower_nonempty'),
        'every non-empty structure list reaches the second sentinel', 100)
end

-- ------------------------------------ 3. who is actually fed such a list ----

--- Resolve the argument of every `J.GetCenterOfUnits(var)` call to the nearest
--- preceding assignment of `var`, and name the producer.
local function centroid_sites()
    local sites, unresolved = {}, {}
    for _, path in ipairs(lua_files()) do
        local lines = {}
        for line in (stripped(read_file(path)) .. '\n'):gmatch('([^\n]*)\n') do
            lines[#lines + 1] = line
        end
        for i, line in ipairs(lines) do
            local var = line:match('J%.GetCenterOfUnits%(%s*([A-Za-z_][A-Za-z0-9_]*)%s*%)')
            if var ~= nil then
                local rhs = nil
                for j = i, math.max(1, i - 60), -1 do
                    if not lines[j]:find('GetCenterOfUnits', 1, true) then
                        -- `[^=]` after the `=` is load-bearing: without it
                        -- `#nCreeps == 1 and ...` reads as an assignment of
                        -- `= 1 and ...` and four sites came back "resolved" to a
                        -- comparison. A mis-resolution is worse than an
                        -- unresolved site here, because the ruling below is a
                        -- statement about what the producer IS.
                        local a = lines[j]:match('%f[%w_]' .. var .. '%s*=%s*([^=].*)')
                        if a ~= nil then rhs = a break end
                    end
                end
                if rhs == nil then
                    unresolved[#unresolved + 1] = var
                else
                    sites[#sites + 1] = { path = path, var = var, rhs = rhs }
                end
            end
        end
    end
    return sites, unresolved
end

-- Variables whose producer is out of the resolver's 60-line reach. Pinned by
-- NAME rather than by position (the 0ADDR lesson): a new name here means a call
-- site nobody has classified, which is the one thing this section must not miss.
local UNRESOLVED_OK = {
    nEnemyLaneCreeps = true,  -- broodmother / brewmaster / rubick_hero: lane creeps
    nEnemyHeroes = true,      -- hero_leshrac: hero list
    hAllyList = true,         -- ability_item_usage_generic: ally hero list
    nUnits = true,            -- the parameter of J.GetCenterOfUnits itself
}

--- The producer set, pinned rather than counted -- the nesting census's rule
--- (tests/test_gated_helper_nesting_census.lua): a count can be re-baselined
--- without anybody reading the new row, a SET cannot. None of the nine returns
--- a structure, which is the whole of the ruling.
local PRODUCERS = {
    ['J.GetEnemiesNearLoc('] = 'enemy heroes, filtered on J.IsValidHero',
    ['J.GetNearbyHeroes('] = 'heroes, filtered on J.IsValidHero',
    ['J.GetAlliesNearLoc('] = 'team roster, filtered on IsAlive',
    ['J.GetSpecialModeAllies('] = 'team roster in one bot mode',
    ['bot:GetNearbyLaneCreeps('] = 'engine lane creeps',
    ['hMinionUnit:GetNearbyLaneCreeps('] = 'engine lane creeps, minion caller',
    ['bot:GetNearbyNeutralCreeps('] = 'engine neutral creeps',
    ['bot:GetNearbyCreeps('] = 'engine creeps',
    ['{}'] = 'the literal empty table -- the FIRST sentinel, not this one',
}

tests['[isvalidbld] 3. RULING: no centroid call site is fed a structure list']
= function()
    local sites, unresolved = centroid_sites()
    assert(#sites >= 150, 'the centroid census found only ' .. #sites
        .. ' resolved call sites -- that reads as a broken scan, not as a tree '
        .. 'that stopped taking centroids')
    local strange = {}
    for _, s in ipairs(sites) do
        local key = s.rhs:gsub('%(.*', '(')
        if PRODUCERS[key] == nil then
            strange[#strange + 1] = s.path .. ': ' .. s.var .. ' = ' .. s.rhs
        end
    end
    assert(#strange == 0, 'a J.GetCenterOfUnits call site now takes a producer '
        .. 'this file has never classified. Answer one question before adding '
        .. 'it: can the list it returns hold a BUILDING? If it can, the second '
        .. 'sentinel (origin returned for a NON-empty list, measured in section '
        .. '2c at 520 of 520) is reachable there and the charter\'s refusal has '
        .. 'to be re-taken:\n      ' .. table.concat(strange, '\n      '))
    local strangers = {}
    for _, v in ipairs(unresolved) do
        if not UNRESOLVED_OK[v] then strangers[#strangers + 1] = v end
    end
    assert(#strangers == 0, 'a centroid call site takes a variable this file '
        .. 'has never classified: ' .. table.concat(strangers, ', ')
        .. ' -- resolve its producer before trusting the ruling above')
end

tests['[isvalidbld] 3b. FINDING: exactly one site feeds a structure list to a UNIT validator']
= function()
    -- The mirror question. `J.IsValid(x)` where x is a structure is false on
    -- every frame -- section 1 measured that on 2584 real structures -- so such
    -- a call is not a check, it is an OFF switch for whatever sits under it.
    local hits, right = {}, 0
    for _, path in ipairs(lua_files()) do
        local lines = {}
        for line in (stripped(read_file(path)) .. '\n'):gmatch('([^\n]*)\n') do
            lines[#lines + 1] = line
        end
        for i, line in ipairs(lines) do
            local var = line:match('([A-Za-z_][A-Za-z0-9_]*)%s*=[^=\n]*GetNearbyTowers%s*%(')
                or line:match('([A-Za-z_][A-Za-z0-9_]*)%s*=[^=\n]*GetNearbyBarracks%s*%(')
            if var ~= nil then
                for j = i, math.min(#lines, i + 40) do
                    -- The building validator FIRST: `J.IsValid[A-Za-z]*` also
                    -- matches J.IsValidBuilding, and counting the 26 correct
                    -- sites as findings would have buried the one real one.
                    if lines[j]:match('J%.IsValidBuilding%s*%(%s*' .. var .. '%s*[%[%)]') then
                        right = right + 1
                    elseif lines[j]:match('J%.IsValid%s*%(%s*' .. var .. '%s*[%[%)]')
                        or lines[j]:match('J%.IsValidHero%s*%(%s*' .. var .. '%s*[%[%)]')
                        or lines[j]:match('J%.IsValidTarget%s*%(%s*' .. var .. '%s*[%[%)]') then
                        hits[#hits + 1] = path .. ': ' .. lines[j]:gsub('^%s+', '')
                    end
                end
            end
        end
    end
    -- ORDER IS LOAD-BEARING, and the mutation stand is why it is written down:
    -- the count assertion below used to run FIRST, and mutant M5 (convert one
    -- of the 26 correct sites to the unit validator -- i.e. a NEW dead branch)
    -- then tripped `right >= 26` instead of the finding, so the stand scored it
    -- "red with the wrong message". The finding is the primary claim; it goes
    -- first, and the reader gets "got 2" rather than "only 25".
    assert(#hits == 1, 'expected exactly the one known site, got ' .. #hits
        .. ':\n      ' .. table.concat(hits, '\n      ')
        .. '\n    A NEW one means another branch just went permanently false; '
        .. 'a ZERO means the known one was repaired -- update the charter and '
        .. 'this file together, do not re-baseline the count alone.')
    assert(hits[1]:find(FARM, 1, true) == 1,
        'the known site moved out of ' .. FARM .. ': ' .. hits[1])
    assert(hits[1]:find('runModeBarracks', 1, true) ~= nil,
        'the known site is no longer the runMode barracks branch: ' .. hits[1])
    -- Condition (c), in this repo rather than on a wiki: the tree already knows
    -- which validator a structure list takes, and uses it 26 times right here
    -- (74 J.IsValidBuilding call sites overall).
    assert(right >= 26, 'only ' .. right .. ' structure lists still go to '
        .. 'J.IsValidBuilding (26 recorded) -- the in-repo argument that the '
        .. 'site above is a MISTAKE and not a convention just got weaker')
end

-- ------------------------------- 4. what the dead branch was trying to do ---

tests['[isvalidbld] 4. the six conjuncts under it are building-specific']
= function()
    -- Intent, argued from the code rather than from a wiki. Everything the
    -- branch checks AFTER the validator is a structure predicate -- glyph,
    -- backdoor protection, invulnerability -- so the author meant a building
    -- check and reached for the unit one. The repo has the building one.
    local src = stripped(read_file(FARM))
    local at = src:find('GetNearbyBarracks', 1, true)
    assert(at ~= nil, 'the runMode barracks branch is gone from ' .. FARM)
    local body = src:sub(at, at + 900)
    assert(body:find('J.IsValid(runModeBarracks[1])', 1, true) ~= nil,
        'the validator on the barracks branch changed -- if it is now a '
        .. 'building validator the finding is FIXED: say so in the charter '
        .. 'instead of leaving this assertion to fail')
    for _, sPred in ipairs({ 'modifier_fountain_glyph', 'modifier_backdoor_protection_active',
                            'IsInvulnerable', 'IsAttackImmune' }) do
        assert(body:find(sPred, 1, true) ~= nil,
            'the branch no longer checks ' .. sPred .. ' -- the intent argument '
            .. '("these are all structure predicates") is weaker by one')
    end
    assert(body:find('Action_AttackUnit(runModeBarracks[1]', 1, true) ~= nil,
        'the action under the dead condition changed -- re-read what is lost')
end

tests['[isvalidbld] 4b. DECLARED: the branch\'s own domain is empty in this corpus']
= function()
    -- Why no fix ships this round. Nothing here is a statement about real
    -- games: it is a statement about what this corpus can witness.
    assert(C('rax_branch') == 0, C('rax_branch') .. ' live hero frames now carry '
        .. 'an enemy barracks inside the branch\'s own radius -- the consequence '
        .. 'is drivable on an un-injected frame, so PRICE it')
    assert(C('rax_1600') == 0, C('rax_1600') .. ' live hero frames now carry an '
        .. 'enemy barracks inside 1600 -- same re-opening as the line above')
    -- The radius itself is a loader default, not dump ground truth, and that is
    -- half of why the domain is empty. Stated so no later round reads
    -- `GetAttackRange() + 150` off a fixture as if the dump had said it.
    cs.universal(C('ar_150'), C('live'),
        'every fixture hero answers the mock GetAttackRange default of 150', 500)
end

return tests

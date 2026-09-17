-- [basecreep] The base-threat top-up that exists FOR creeps cannot see a creep,
-- and on the only frames where it can fire at all it SHORTENS the hold.
--
-- aba_defend.GetDefendDesireHelper keeps a sticky "the base is threatened" flag:
--
--     if heroesNearAncient >= 1 then  baseThreatUntil = now + BASE_THREAT_HOLD
--     elseif isBaseThreatActive then
--         creepWeight = WeightedEnemiesAroundLocation(ancient, BASE_THREAT_RADIUS)
--         if creepWeight >= 2 then  baseThreatUntil = now + 1.5  end
--
-- and the TypeScript source states the policy in its own words one line above:
-- "heroes start, creeps can only extend". Neither half of that is true of the
-- code.
--
-- ⭐ HALF 1 -- IT CANNOT SEE A CREEP. This is WALL 1, the list, and it is the
-- SAME wall [threatcreep] repaired one call site over:
-- WeightedEnemiesAroundLocation prices its units off `unitState.enemyHeroes`,
-- built as GetUnitList(UnitType.Enemies) already filtered by IsValidHero, so the
-- ladder's siege / upgraded / warlock_golem / IsCreep() rungs are unreachable
-- and a creep is never priced at all. §2 drives that: the same injected sample
-- moves the second return value and leaves the first at zero.
--
-- ⛔ AND THIS IS WHY IT WAS INVISIBLE. [threatcreep] measured this call site and
-- called it a provable no-op -- correctly, and ONLY about WALL 2 (the floor):
-- `math.floor(x) >= 2` iff `x >= 2` for any real x, which
-- tests/test_threatcreep_lane_tiebreak.lua still drives. That sentence says
-- nothing about WALL 1. This call site is the SECOND consumer of the same
-- filtered list, and the first consumer getting repaired is exactly what took it
-- out of view (charter 0NEXT35).
--
-- ⭐ HALF 2 -- ON THE ONLY FRAMES IT CAN FIRE, IT SHORTENS. Closed form: the arm
-- is reached only when `heroesNearAncient == 0`, and CountEnemyHeroesNear counts
-- precisely the valid enemy heroes inside BASE_THREAT_RADIUS -- the same set
-- feeding the only reachable rung of the sum. So the shipped weight is 0 on
-- every frame this line runs (§3 drives that over the corpus), EXCEPT through
-- the `now - c.t <= CACHE_ENEMY_AROUND_LOC_HZ` cache, i.e. off a hero reading at
-- most 0.35s stale. A stale-cache hit means the arm above ran under 0.35s ago
-- and left `now + BASE_THREAT_HOLD` (= +4) pending -- and the assignment is `=`,
-- not a max, so replacing it with +1.5 CUTS the hold. The shipped branch can do
-- only two things: nothing, or the opposite of what it is for.
--
-- ⛔ WHY ONE ID AND NOT TWO (0NEXT34 §乙 -- land each half alone, ask whether
-- the number moves):
--   * raw sum alone, keeping `=`: the number moves, in the one direction this
--     branch forbids -- a mega wave at the ancient would cut a live hero hold
--     from +4 to +1.5. Not admissible alone.
--   * math.max alone, keeping the hero-only sum: by the closed form the
--     condition is false except on the stale frames, and there the pending value
--     is the larger one. A no-op.
-- Neither half ships by itself ⇒ one atom, one id. Both mutations are priced in
-- tools/agent/mutstand_basecreep.sh (B2 / B3).
--
-- ⛔ STANDALONE GATE, never a conjunction with 'threatcreep' -- the 'pullcad'
-- trap (a gate naming a second candidate id freezes FALSE the day that id is
-- promoted). §6 pins that the gate expression names exactly one id.
--
-- ⛔ THE THRESHOLD 2 IS UNTOUCHED, and that is the conservative side of the
-- arithmetic: at the minimum bucket 0.2 a basic wave of four is 0.8 and armed
-- STILL refuses. What clears 2 is a siege/mega push (0.5 / 0.6 a body), which is
-- the situation the branch names. §4 drives both.
--
-- ⛔ DIRECTION, one-way and arithmetic. rawCount starts FROM the unfloored hero
-- sum and adds only non-negative creep terms, and `count` is floored after that,
-- so raw >= shipped always ⇒ armed can only turn this condition FALSE -> TRUE;
-- and math.max means it can only push baseThreatUntil LATER. Armed can never
-- disarm base threat and never shorten a hold. §5 drives the inequality.
--
-- ⛔ WHAT THIS FILE CANNOT DRIVE, said plainly rather than implied. The call
-- site is inside ____exports.GetDefendDesireHelper, and on every corpus frame
-- that function returns VeryLow long before reaching it (measured last round for
-- [threatcreep]). So the WIRING is a closed-form proposition about the source
-- text (§6), not a frequency; what is driven on real frames is the SUM the
-- wiring reads (§2-§5). The mutation stand is what makes §6 bite.
--
-- ⛔ THE INSTRUMENT GAP, the same one [defcreep] and [threatcreep] hit (GH #863):
-- tests/mock/replay_fixture.lua answers GetUnitList(UnitType.Enemies) with an
-- empty table, and that list is the sole input to
-- WeightedEnemiesAroundLocation. So on this corpus the creep term is 0 BY
-- CONSTRUCTION and armed reads baseline-identical. §1 asserts the gap out loud
-- AND asserts a non-zero from a DIFFERENT reader on the same frame
-- (UnitType.EnemyHeroes: 5 units) -- per the charter's rule for reading a zero,
-- the loader is gapped, not blind.
--
-- THE STAND-INS, each named with what it costs.
--   (1) A CONSTRUCTED CHOICE OF BUILDING. No corpus frame carries an enemy creep
--       near the ancient -- this corpus is laning to mid-game. So §2/§4/§5 take
--       the REAL five-creep sample f_20260909_212625_lion_235 carries near the
--       radiant top anchor and translate it as a RIGID BODY to the ancient:
--       every offset, distance and bearing is the dump's, and the only
--       constructed thing is which building it stands at. Same stand-in the
--       sibling file declares, and named here rather than inherited.
--   (2) CONSTRUCTED NAMES, and this one stands where it SUPPORTS the claim, so
--       0NEXT34 §丙 requires it spelled out: the dump carries no creep name and
--       the function prices by name. Unnamed creeps therefore take the MINIMUM
--       bucket 0.2 -- conservative, and that is the case §4 uses for "a basic
--       wave still does not clear 2". The mega/siege cases in §4 name the units
--       'npc_dota_creep_badguys_melee_upgraded_mega' / '..._siege' to show the
--       threshold IS reachable. That name is constructed; the positions and the
--       multiplicity under it are the dump's.
--
-- GH #61: GetLaneFrontLocation is unresolved in this corpus and the loader
-- REFUSES the call rather than answering (0,0,0). Nothing below reads a lane
-- front -- the declaration only keeps aba_defend's module state constructible.
--
-- [ratchet]

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')

local tests = {}

-- Five real enemy creeps inside 1200 of the radiant top anchor (nearest 218u).
local FRAME_WAVE = 'tests/fixtures/f_20260909_212625_lion_235.lua'
local SUBJ_WAVE = 'npc_dota_hero_axe'

-- A second, independent frame for the closed-form section.
local FRAME_QUIET = 'tests/fixtures/f_20260912_094042_sniper_546.lua'
local SUBJ_QUIET = 'npc_dota_hero_sniper'

local DEFEND_LUA = 'bots/FunLib/aba_defend.lua'
local DEFEND_TS = 'typescript/bots/FunLib/aba_defend.ts'

-- The shipped constants this file reads; pinned in §6 so a change to either
-- turns this file red instead of quietly re-scoping every number below.
local RADIUS = 2600

local TAIL = 'return ____exports\n'
local PROBE = '____exports.__probe = {'
    .. 'WeightedEnemiesAroundLocation = WeightedEnemiesAroundLocation,'
    .. ' IsBaseThreatActive = IsBaseThreatActive}\n'

local function slurp(path)
    local f = assert(io.open(path, 'r'))
    local s = f:read('*a')
    f:close()
    return s
end

--- The shipped source with one export spliced in ahead of its final return.
--- Every byte under measurement is a shipped byte; the splice adds an export and
--- changes no statement. If the tail stops being `return ____exports` the assert
--- aborts rather than measuring something else.
local function probed_source()
    local src = slurp(DEFEND_LUA)
    assert(src:sub(-#TAIL) == TAIL,
        DEFEND_LUA .. ' no longer ends in `' .. TAIL:gsub('\n', '') .. '`. The '
        .. 'probe splice below would land somewhere else -- fix the splice, do '
        .. 'not loosen this assert.')
    return src:sub(1, #src - #TAIL) .. PROBE .. TAIL
end

--- One enemy creep as WeightedEnemiesAroundLocation's two loops need to see it.
--- Position and team come from the dump; the NAME does not exist there (see the
--- stand-in note in the header).
local function creep_unit(x, y, team, name)
    local u
    u = {
        IsNull = function() return false end,
        CanBeSeen = function() return true end,
        IsAlive = function() return true end,
        IsBuilding = function() return false end,
        -- Deliberate, not a default: jmz.IsValid delegates to
        -- utils.IsValidUnit, whose last conjunct is `not IsInvulnerable()`. A
        -- creep walking at the ancient is not invulnerable. (The loader does not
        -- derive this predicate for anybody -- GH #858 -- which is why the
        -- stand-in answers it rather than inheriting it.)
        IsInvulnerable = function() return false end,
        IsMagicImmune = function() return false end,
        IsHero = function() return false end,
        IsIllusion = function() return false end,
        IsCreep = function() return true end,
        IsAncientCreep = function() return false end,
        IsDominated = function() return false end,
        HasModifier = function() return false end,
        GetUnitName = function() return name or 'npc_dota_creep_badguys_melee' end,
        GetLocation = function() return Vector(x, y, 128) end,
        GetTeam = function() return team end,
    }
    return setmetatable(u, {
        __index = function(_, k)
            error('creep stand-in has no ' .. tostring(k)
                .. ' -- add it deliberately or stop reading it', 2)
        end,
    })
end

--- Load one real frame with the real aba_defend (plus the probe export).
---   opts.armed  -- arm 'basecreep' (nothing else is ever armed)
---   opts.id     -- arm a different id instead, for the gate section
---   opts.turbo  -- false makes J.IsModeTurbo() report a non-turbo game
---   opts.creeps -- {{x=,y=,name=}, ...} injected as the enemy unit list;
---                  omitted means the corpus's own answer, which is none
local function world(frame, subject, opts)
    opts = opts or {}
    for k in pairs(package.loaded) do
        if k:find('FunLib') or k:find('mock') then package.loaded[k] = nil end
    end
    rf = require('mock.replay_fixture')
    local J, bot, heroes, fx = rf.load(frame, subject)
    assert(bot ~= nil, 'fixture ' .. frame .. ' has no subject ' .. subject)
    J.IsSoakCandidate = function(id)
        return id == (opts.id or 'basecreep') and opts.armed == true
    end
    if opts.turbo == false then
        J.IsModeTurbo = function() return false end
    end
    if opts.creeps ~= nil then
        local enemyTeam = bot:GetTeam() == TEAM_RADIANT and TEAM_DIRE or TEAM_RADIANT
        local units = {}
        for _, c in ipairs(opts.creeps) do
            units[#units + 1] = creep_unit(c.x, c.y, enemyTeam, c.name)
        end
        local prev = GetUnitList
        GetUnitList = function(kind) -- luacheck: ignore
            if kind == UNIT_LIST_ENEMIES then return units end
            return prev(kind)
        end
    end
    -- GH #61, declared above. Nothing below reads it.
    _G.GetLaneFrontLocation = function() return Vector(0, 0, 0) end -- luacheck: ignore
    local D = assert(loadstring(probed_source(), '@' .. DEFEND_LUA .. '[probe]'))()
    return J, bot, D, fx, heroes
end

--- The ancient the call site reads, through the engine call it reads it with.
local function ancient_loc(bot)
    local a = GetAncient(bot:GetTeam())
    assert(a ~= nil, 'the loader has no ancient for this frame')
    return a:GetLocation()
end

--- The dump's own enemy creeps within `radius` of `loc`, in world coordinates.
--- Read off the fixture file, never off the function under measurement.
local function dump_creeps_near(fx, bot, loc, radius)
    local out = {}
    for _, c in ipairs(fx.creeps or {}) do
        if c.team ~= bot:GetTeam() and (c.team == TEAM_RADIANT or c.team == TEAM_DIRE) then
            local d = math.sqrt((c.x - loc.x) ^ 2 + (c.y - loc.y) ^ 2)
            if d <= radius then out[#out + 1] = { x = c.x, y = c.y, d = d } end
        end
    end
    table.sort(out, function(a, b) return a.d < b.d end)
    return out
end

--- Translate a real creep sample rigidly from one anchor to another: every
--- offset, distance and bearing is preserved, only the building is constructed.
local function translate(sample, from, to, name)
    local out = {}
    for _, c in ipairs(sample) do
        out[#out + 1] = { x = c.x - from.x + to.x, y = c.y - from.y + to.y, name = name }
    end
    return out
end

--- The real five-creep sample, standing at the ancient. Returned with the
--- anchor so callers never re-derive either.
local function wave_at_ancient(name, k)
    local _, bot0, D0, fx = world(FRAME_WAVE, SUBJ_WAVE)
    local bld, _u, tier = unpack(D0.GetFurthestBuildingOnLane(LANE_TOP))
    assert(bld ~= nil and tier ~= nil, 'the top building is unresolved on this frame')
    local from = bld:GetLocation()
    local sample = dump_creeps_near(fx, bot0, from, 1200)
    assert(#sample >= 5,
        FRAME_WAVE .. ' no longer carries five enemy creeps within 1200 of its '
        .. 'top building -- this file measures a real sample, so re-pick the '
        .. 'frame rather than lowering the count')
    if k ~= nil then
        local cut = {}
        for i = 1, k do cut[i] = sample[i] end
        sample = cut
    end
    return translate(sample, from, ancient_loc(bot0), name)
end

-- ---------------------------------------------------------------------------
-- §1 [instrument] The zero this corpus reports, and the non-zero that proves
-- the reader is gapped rather than blind.
-- ---------------------------------------------------------------------------

tests['[instrument] the enemy list is empty by construction, and a second reader is not'] = function()
    local _, bot = world(FRAME_WAVE, SUBJ_WAVE)
    local nEnemies = #GetUnitList(UNIT_LIST_ENEMIES)
    local nEnemyHeroes = #GetUnitList(UNIT_LIST_ENEMY_HEROES)
    assert(nEnemies == 0,
        'the loader now answers GetUnitList(UnitType.Enemies) with ' .. nEnemies
        .. ' units. That list is the SOLE input to '
        .. 'WeightedEnemiesAroundLocation, so [basecreep]\'s corpus domain is no '
        .. 'longer zero-by-construction -- re-measure it and say so, do not '
        .. 'delete this assert.')
    assert(nEnemyHeroes > 0,
        'the control reader GetUnitList(UnitType.EnemyHeroes) also returns 0 on '
        .. 'this frame, so the zero above cannot be attributed to the list '
        .. 'filter -- the loader may simply be blind here. Re-pick the frame.')
    assert(bot ~= nil)
end

-- ---------------------------------------------------------------------------
-- §2 [wall1] The list: the same real creeps move one return value and not the
-- other. This is the wall, driven rather than cited.
-- ---------------------------------------------------------------------------

tests['[wall1] injected creeps price into the raw sum and not into the shipped sum'] = function()
    local creeps = wave_at_ancient(nil)
    local _, bot, D = world(FRAME_WAVE, SUBJ_WAVE, { creeps = creeps })
    local shipped, raw = D.__probe.WeightedEnemiesAroundLocation(ancient_loc(bot), RADIUS)
    assert(shipped == 0,
        'five enemy creeps at the ancient priced ' .. tostring(shipped)
        .. ' into the SHIPPED sum. That sum walks the IsValidHero-filtered '
        .. 'list, so it must stay 0 -- if it moved, WALL 1 was repaired '
        .. 'somewhere else and this id is no longer the narrow change it claims '
        .. 'to be.')
    assert(math.abs(raw - 1.0) < 1e-9,
        'five creeps at the minimum bucket 0.2 must raise the raw sum to 1.0, '
        .. 'got ' .. tostring(raw))
end

tests['[wall1] with no creeps the two sums agree, so §2 measured the creeps'] = function()
    local _, bot, D = world(FRAME_WAVE, SUBJ_WAVE)
    local shipped, raw = D.__probe.WeightedEnemiesAroundLocation(ancient_loc(bot), RADIUS)
    assert(shipped == raw,
        'on the SAME frame with the injection removed the two sums differ ('
        .. tostring(shipped) .. ' vs ' .. tostring(raw) .. '), so the gap §2 '
        .. 'reports is not the injected creeps')
end

-- ---------------------------------------------------------------------------
-- §3 [closed] The arm is reached only when no enemy hero is inside the radius,
-- and on exactly those frames the shipped sum is 0. Driven on two independent
-- real frames through the same engine call the call site uses.
-- ---------------------------------------------------------------------------

local function closed_form_on(frame, subject)
    local J, bot, D = world(frame, subject)
    local anc = ancient_loc(bot)
    local heroes = J.Utils.CountEnemyHeroesNear(anc, RADIUS)
    local shipped = D.__probe.WeightedEnemiesAroundLocation(anc, RADIUS)
    return heroes, shipped
end

tests['[closed] hero count zero implies the shipped weight is zero'] = function()
    local seen = 0
    for _, fs in ipairs({ { FRAME_WAVE, SUBJ_WAVE }, { FRAME_QUIET, SUBJ_QUIET } }) do
        local heroes, shipped = closed_form_on(fs[1], fs[2])
        if heroes == 0 then
            seen = seen + 1
            assert(shipped == 0,
                fs[1] .. ': no enemy hero within ' .. RADIUS .. ' of the ancient '
                .. '(CountEnemyHeroesNear = 0) yet the shipped weighted sum is '
                .. tostring(shipped) .. '. The closed form in the header says '
                .. 'these two read the same hero set -- if they can disagree, '
                .. 'the shipped top-up is NOT dead and [basecreep]\'s case has '
                .. 'to be rewritten, not this assert.')
        end
    end
    assert(seen == 2,
        'both reference frames must be hero-quiet at the ancient for the closed '
        .. 'form to be driven here; ' .. seen .. ' of 2 were. Re-pick a frame.')
end

-- ---------------------------------------------------------------------------
-- §4 [arith] The threshold 2 against real multiplicity. The conservative case
-- first: a basic wave still does not clear it, ARMED.
-- ---------------------------------------------------------------------------

tests['[arith] a basic wave of four is 0.8 and armed still refuses'] = function()
    local creeps = wave_at_ancient(nil, 4)
    local _, bot, D = world(FRAME_WAVE, SUBJ_WAVE, { creeps = creeps, armed = true })
    local shipped, raw = D.__probe.WeightedEnemiesAroundLocation(ancient_loc(bot), RADIUS)
    assert(math.abs(raw - 0.8) < 1e-9,
        'four creeps at the minimum bucket must read 0.8, got ' .. tostring(raw))
    assert(raw < 2 and shipped < 2,
        'the threshold 2 is deliberately untouched, so a basic wave must NOT '
        .. 'top up base threat under either reading. raw=' .. tostring(raw))
end

tests['[arith] four mega creeps clear the threshold and four basic ones do not'] = function()
    local mega = wave_at_ancient('npc_dota_creep_badguys_melee_upgraded_mega', 4)
    local _, bot, D = world(FRAME_WAVE, SUBJ_WAVE, { creeps = mega, armed = true })
    local shipped, raw = D.__probe.WeightedEnemiesAroundLocation(ancient_loc(bot), RADIUS)
    assert(math.abs(raw - 2.4) < 1e-9,
        'four mega creeps at 0.6 must read 2.4, got ' .. tostring(raw))
    assert(raw >= 2, 'the armed reading must clear the untouched threshold 2')
    assert(shipped == 0 and shipped < 2,
        'and the shipped reading on the SAME frame must still be 0 -- that gap '
        .. 'IS the defect; got ' .. tostring(shipped))
end

tests['[arith] four siege creeps sit exactly on the threshold'] = function()
    local siege = wave_at_ancient('npc_dota_badguys_siege', 4)
    local _, bot, D = world(FRAME_WAVE, SUBJ_WAVE, { creeps = siege, armed = true })
    local _shipped, raw = D.__probe.WeightedEnemiesAroundLocation(ancient_loc(bot), RADIUS)
    assert(math.abs(raw - 2.0) < 1e-9,
        'four siege creeps at 0.5 must read exactly 2.0, got ' .. tostring(raw)
        .. ' -- this is the boundary case of the untouched `>= 2`')
    assert(raw >= 2, 'and `>= 2` must include the boundary')
end

-- ---------------------------------------------------------------------------
-- §5 [dir] The inequality that makes the direction one-way.
-- ---------------------------------------------------------------------------

tests['[dir] the raw sum never falls below the shipped sum'] = function()
    local cases = {
        { name = 'no creeps', creeps = nil },
        { name = 'one basic', creeps = wave_at_ancient(nil, 1) },
        { name = 'five basic', creeps = wave_at_ancient(nil, 5) },
        { name = 'five mega', creeps = wave_at_ancient('npc_dota_creep_badguys_melee_upgraded_mega', 5) },
    }
    for _, c in ipairs(cases) do
        local _, bot, D = world(FRAME_WAVE, SUBJ_WAVE, { creeps = c.creeps })
        local shipped, raw = D.__probe.WeightedEnemiesAroundLocation(ancient_loc(bot), RADIUS)
        assert(raw >= shipped,
            c.name .. ': the raw sum ' .. tostring(raw) .. ' fell below the '
            .. 'shipped sum ' .. tostring(shipped) .. '. The whole direction '
            .. 'argument is that raw only ADDS non-negative creep terms to the '
            .. 'unfloored hero sum -- fix the pricing, not this assert.')
    end
end

tests['[dir] the sum itself is gate-independent -- the gate lives at the call site'] = function()
    local creeps = wave_at_ancient(nil)
    local a, b = {}, {}
    local _, bot1, D1 = world(FRAME_WAVE, SUBJ_WAVE, { creeps = creeps, armed = false })
    a[1], a[2] = D1.__probe.WeightedEnemiesAroundLocation(ancient_loc(bot1), RADIUS)
    local _2, bot2, D2 = world(FRAME_WAVE, SUBJ_WAVE, { creeps = creeps, armed = true })
    b[1], b[2] = D2.__probe.WeightedEnemiesAroundLocation(ancient_loc(bot2), RADIUS)
    assert(a[1] == b[1] and a[2] == b[2],
        'arming moved WeightedEnemiesAroundLocation itself (' .. tostring(a[1])
        .. '/' .. tostring(a[2]) .. ' vs ' .. tostring(b[1]) .. '/'
        .. tostring(b[2]) .. '). [basecreep] gates a CALL SITE; a gate inside '
        .. 'this function would move [threatcreep]\'s consumer too.')
    assert(_2 ~= nil)
end

-- ---------------------------------------------------------------------------
-- §6 [source] The wiring, as a closed-form proposition about the shipped text.
-- Every anchor carries its syntactic position (0NEXT33 §乙: a bare literal is
-- matched by the explanatory comment that has to name the same value).
-- ---------------------------------------------------------------------------

tests['[source] the call site reads the raw sum only under the gate'] = function()
    local s = slurp(DEFEND_LUA)
    assert(s:find('\n            local creepWeight, creepWeightRaw = WeightedEnemiesAroundLocation(', 1, true),
        'the base-threat call site must bind BOTH return values -- the raw one '
        .. 'is the WALL 1 repair')
    assert(s:find('\n            local bBaseCreep = jmz.IsSoakCandidate("basecreep") and jmz.IsModeTurbo()\n', 1, true),
        'the gate must be turbo-only and must name basecreep')
    assert(s:find('if (bBaseCreep and creepWeightRaw or creepWeight) >= 2 then', 1, true),
        'disarmed, the condition must read the SHIPPED first return value, and '
        .. 'the threshold 2 must stay')
end

tests['[source] the top-up can only move the deadline later'] = function()
    local s = slurp(DEFEND_LUA)
    assert(s:find('\n                local nTopUp = DotaTime() + 1.5\n', 1, true),
        'the 1.5 top-up must stay as shipped')
    assert(s:find('baseThreatUntil = bBaseCreep and math.max(baseThreatUntil or -1, nTopUp) or nTopUp', 1, true),
        'armed, the assignment must be a max. A bare `=` here is HALF 2 of the '
        .. 'defect: on a stale-cache frame it replaces a pending '
        .. '+BASE_THREAT_HOLD with +1.5 and SHORTENS the hold.')
end

tests['[source] the gate names exactly one candidate id (the pullcad trap)'] = function()
    local s = slurp(DEFEND_LUA)
    local line = s:match('\n(%s*local bBaseCreep = [^\n]*)\n')
    assert(line ~= nil, 'the basecreep gate line vanished')
    local n = select(2, line:gsub('IsSoakCandidate', ''))
    assert(n == 1,
        'the basecreep gate names ' .. n .. ' candidate ids. A gate written as '
        .. 'IsSoakCandidate(X) and IsSoakCandidate(Y) is frozen FALSE the day Y '
        .. 'is promoted -- the pullcad trap (GH #622).')
end

tests['[source] the shipped hero sum and its floor are untouched'] = function()
    local s = slurp(DEFEND_LUA)
    assert(s:find('\n    count = math.floor(count)\n    _cacheEnemyAroundLoc[key]', 1, true),
        'the floor must stay immediately before the cache write: it still feeds '
        .. 'the ShouldDefend role ladder and the FIRST return value read here')
    assert(s:find('\n    local rawCount = count\n    for ____, unit in ipairs(unitState.enemyCreeps) do', 1, true),
        'the parallel sum must start from the shipped hero sum and then walk '
        .. '`unitState.enemyCreeps` -- that list IS the wall-1 repair')
end

tests['[source] the radius and the arm above it are untouched'] = function()
    local s = slurp(DEFEND_LUA)
    assert(s:find('\nBASE_THREAT_RADIUS = ' .. RADIUS .. '\n', 1, true),
        'BASE_THREAT_RADIUS moved; every number in this file is scoped to '
        .. RADIUS)
    assert(s:find('\n        if heroesNearAncient >= 1 then\n            baseThreatUntil = DotaTime() + BASE_THREAT_HOLD\n', 1, true),
        'the hero arm above the top-up must stay exactly as shipped -- '
        .. '[basecreep] changes the ELSE branch only')
end

tests['[source] the TypeScript source carries the same change'] = function()
    local s = slurp(DEFEND_TS)
    assert(s:find('const bBaseCreep = jmz.IsSoakCandidate("basecreep") && jmz.IsModeTurbo();', 1, true),
        'the .ts source is the one this .lua is generated from; a change landed '
        .. 'in only one of them is a change the next regeneration deletes')
    assert(s:find('baseThreatUntil = bBaseCreep ? math.max(baseThreatUntil || -1, nTopUp) : nTopUp;', 1, true),
        'the .ts top-up must be the same max')
end

return tests

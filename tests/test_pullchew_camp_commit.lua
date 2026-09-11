-- [pullchew / GH #250 §4] The pull trigger's "never pull under threat" clause
-- counts ENEMY HEROES, and a camp is not in its domain at all.
--
-- THE BATON THIS FILE PICKS UP, verbatim from the instrument that held it:
-- tests/test_pullcamp_trigger_census.lua asserted `neut_dmg_support_window == 0`
-- with the message "the lever GH #250 §4 proposes has become
-- fixture-validatable; go land it". That assertion went red when the corpus
-- gained its first non-core frame damaged by a named neutral inside the pull
-- window. There is exactly ONE such frame, and this file is what it bought.
--
-- ⭐ WHAT MAKES THE FRAME A WITNESS RATHER THAN AN ILLUSTRATION. On it the
-- SHIPPED safety predicate J.IsLanePullSafe answers TRUE -- "healthy, nobody
-- hitting me, no enemy hero in 1800" -- on a pos 5 that a camp has just taken
-- 64 HP off (9.2% of max, five hits, two distinct camp members). Every clause
-- that predicate owns is satisfied because every clause it owns asks about
-- heroes. That is GH #250 §4's claim, and it is READ here, not argued.
--
-- ⛔ WHAT THIS FILE DOES NOT CLAIM.
--   * NOT the camp-SIZE lever. GH #250 §4 names "中野的数量或伤害" -- the count
--     OR the damage. The count half remains unlandable and this file does not
--     sneak it in: the loader hands out ONE handle per distinct source name and
--     says in its own comment that no consumer may read it as a census, so the
--     "12-stack" that opened the issue is a lower bound of 2 here.
--   * NOT an effect size. One frame is an existence proof (iron rule 2's (a) is
--     existence + per-frame correctness), and the counting question is not
--     asked anywhere below.
--   * NOT that the radius is right. See the PULL_CHEW_NEUTRAL_RADIUS header:
--     synthesized neutrals stand on the subject, so every radius answers alike.

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')

-- The witness. Bought by the census sweep, not chosen: it is the whole of
-- `neut_dmg_support_window`.
local FIX  = 'tests/fixtures/f_20260909_212625_lion_235.lua'
local HERO = 'npc_dota_hero_silencer'

-- The negative control, on the SAME frame: an enemy core whose creep damage is
-- real and entirely LANE creeps. Naturally occurring, not modelled -- which is
-- what makes it worth more than a constructed one.
local N_LANE = 'npc_dota_hero_viper'

-- The other negative control: a hero with no creep damage at all, so the two
-- conjuncts fail for two different reasons and neither can be carrying the
-- other.
local N_NONE = 'npc_dota_hero_pudge'

local tests = {}

local function read_file(path)
    local f = assert(io.open(path, 'r'))
    local s = f:read('*a')
    f:close()
    return s
end

local function helper_body()
    local src = read_file('bots/FunLib/jmz_func.lua')
    local at = assert(src:find('function J.ShouldPullNeutralCamp', 1, true),
        'J.ShouldPullNeutralCamp is gone')
    local stop = assert(src:find('\nend\n', at, true), 'the helper has no end')
    return src:sub(at, stop)
end

--- Install the fixture world. `{ neutrals = true }` opts in to the loader's
--- SYNTHESIZED neutral reader; it is a model, so it is asked for rather than
--- installed for everyone (four other files declare the empty default as a
--- world assumption). Section 4 pins that default from this side.
local function world(fix, hero, armed)
    local J, bot = rf.load(fix, hero, { neutrals = true })
    J.IsSoakCandidate = function(id) return armed ~= nil and id == armed end
    return J, bot
end

--- The subject's raw damage rows, straight out of the fixture file.
local function rows(fix, hero)
    local fx = assert(dofile(fix))
    for _, u in ipairs(fx.units) do
        if u.name == hero then return u.recent_damage or {}, u end
    end
    error('no unit ' .. hero .. ' in ' .. fix)
end

-- ------------------------------------------------------------------ 1. the
-- ------------------------------------------------- frame, before any lever --

tests['[witness] the frame is a pos 5, in the pull window, above the HP gate'] = function()
    local J, bot = world(FIX, HERO, nil)
    assert(not J.IsCore(bot), 'the witness must be a non-core -- pulling is a pos 4/5 job')
    assert(J.GetPosition(bot) == 5, 'expected pos 5, got ' .. tostring(J.GetPosition(bot)))
    local t = DotaTime()
    assert(t >= 60 and t <= 360,
        'the witness left the 60-360s pull window (t=' .. tostring(t) .. ')')
    -- Above the shipped 0.5 bar, i.e. the existing HP clause is not what would
    -- decline this pull. If this ever drops below 0.5 the frame stops being a
    -- witness for THIS lever, because J.IsLanePullSafe would refuse anyway.
    assert(J.GetHP(bot) > 0.5,
        'the witness fell below the shipped 0.5 HP gate (' .. J.GetHP(bot) .. ')')
end

tests['[witness] a camp took 9.2% of his HP -- five hits, two members'] = function()
    local tRows, u = rows(FIX, HERO)
    local n, dmg, names, distinct = 0, 0, {}, 0
    for _, d in ipairs(tRows) do
        if d.kind == 'creep' and d.src and d.src:find('^npc_dota_neutral') then
            n, dmg = n + 1, dmg + (d.value or 0)
            if not names[d.src] then names[d.src] = true; distinct = distinct + 1 end
        end
    end
    assert(n == 5, 'expected 5 neutral hits, got ' .. n)
    assert(dmg == 64, 'expected 64 neutral damage, got ' .. dmg)
    assert(distinct == 2, 'expected 2 distinct camp members, got ' .. distinct)
    -- The share is the part the issue is about: this is not a graze.
    assert(dmg / u.max_hp > 0.09,
        'the bite is no longer 9%+ of max HP (' .. (dmg / u.max_hp) .. ')')
    -- ...and NOT a hero. The clause that exists asks about heroes; the damage
    -- that landed has no hero in it, which is why the clause cannot see it.
    for _, d in ipairs(tRows) do
        assert(d.kind ~= 'hero',
            'a hero damage row appeared -- the shipped clause could see this frame')
    end
end

tests['⭐[witness][defect] J.IsLanePullSafe says SAFE on that same frame'] = function()
    -- The whole of GH #250 §4 in one assertion. Read with NO candidate armed,
    -- i.e. against the tree as it ships today.
    local J, bot = world(FIX, HERO, nil)
    assert(J.IsLanePullSafe(bot) == true,
        'the shipped safety predicate no longer answers SAFE here -- if a clause '
        .. 'was added that CAN see the camp, this file has been overtaken; '
        .. 're-read GH #250 §4 before repairing the assertion')
    -- Attributed, so a future reader knows WHY it says safe rather than
    -- guessing: each clause it owns is about heroes, and each is satisfied.
    assert(not bot:WasRecentlyDamagedByAnyHero(2.0), 'no hero damage')
    assert(#(J.GetNearbyHeroes(bot, 1800, true, BOT_MODE_NONE) or {}) == 0,
        'no visible enemy hero within 1800')
end

-- ------------------------------------------------------------------ 2. the
-- ------------------------------------------------------- constant, priced --

tests['⭐[constant] the 3.0 every sibling copies is EMPTY on this frame'] = function()
    -- Why PULL_CHEW_LOOKBACK is not 3.0. `fieldcreep` and `tpchew` both read
    -- this probe at 3.0, so 3.0 is the value that would be inherited without
    -- pricing it -- and it cannot fire here. The boundary is pinned on BOTH
    -- sides so that a future widening or narrowing has to come past it.
    local _, bot = world(FIX, HERO, nil)
    assert(bot:WasRecentlyDamagedByCreep(3.0) == false,
        'the probe now fires at 3.0 -- the sibling constant is no longer empty '
        .. 'here, so the lookback derivation needs re-reading')
    assert(bot:WasRecentlyDamagedByCreep(3.5) == true,
        'the probe no longer fires at 3.5')
    -- And the row that puts the edge there, so the numbers above are traceable
    -- to the fixture rather than to this file.
    local tRows = rows(FIX, HERO)
    local nearest = math.huge
    for _, d in ipairs(tRows) do
        if d.kind == 'creep' and d.src and d.src:find('^npc_dota_neutral') then
            if d.dt < nearest then nearest = d.dt end
        end
    end
    assert(nearest > 3.0 and nearest < 3.5,
        'the most recent tooth moved off (3.0, 3.5); it is ' .. nearest)
end

tests['[constant] the shipped lookback is the one the frame can witness'] = function()
    local src = read_file('bots/FunLib/jmz_func.lua')
    local at = assert(src:find('local PULL_CHEW_LOOKBACK = ', 1, true),
        'PULL_CHEW_LOOKBACK is gone')
    local v = tonumber(src:match('local PULL_CHEW_LOOKBACK = ([%d%.]+)'))
    assert(v == 6.0, 'PULL_CHEW_LOOKBACK moved to ' .. tostring(v)
        .. ' -- if that is deliberate, the witness frame must still be in domain')
    local _, bot = world(FIX, HERO, nil)
    assert(bot:WasRecentlyDamagedByCreep(v) == true,
        'the shipped lookback does not reach the witness frame -- this is the '
        .. 'guard-that-cannot-fire shape the header was written against')
    assert(at, 'unreachable')
end

-- ------------------------------------------------------------------ 3. the
-- ------------------------------------------------------------- predicate --

tests['⭐[lever] J.IsPullCampChewing fires on the witness frame'] = function()
    local J, bot = world(FIX, HERO, nil)
    assert(J.IsPullCampChewing(bot) == true,
        'the lever does not fire on the only frame that can witness it')
end

tests['[N1] an enemy core hit only by LANE creeps does not fire it'] = function()
    -- The control that falsifies the UN-NARROWED version, and it is a real
    -- frame rather than a construction: viper's creep damage on this very frame
    -- is two `npc_dota_creep_goodguys_ranged` rows. The raw probe says TRUE and
    -- the lever must still say false -- that difference IS the second conjunct.
    local J, bot = world(FIX, N_LANE, nil)
    assert(bot:WasRecentlyDamagedByCreep(6.0) == true,
        'N1 no longer has creep damage, so it no longer controls anything')
    assert(#bot:GetNearbyNeutralCreeps(1400) == 0, 'N1 must have no neutrals')
    assert(J.IsPullCampChewing(bot) == false,
        'the lever fires on lane-creep damage -- the narrowing conjunct is gone')
    local tRows = rows(FIX, N_LANE)
    local lane = 0
    for _, d in ipairs(tRows) do
        if d.kind == 'creep' and d.src and d.src:find('^npc_dota_creep_') then
            lane = lane + 1
        end
    end
    assert(lane == 2, 'expected 2 lane-creep rows on N1, got ' .. lane)
end

tests['[N2] a hero with no creep damage at all does not fire it'] = function()
    -- Orthogonal to N1 on purpose: here the FIRST conjunct is what refuses, so
    -- neither control can be passing on the other one's account.
    local J, bot = world(FIX, N_NONE, nil)
    assert(bot:WasRecentlyDamagedByCreep(6.0) == false, 'N2 gained creep damage')
    assert(J.IsPullCampChewing(bot) == false, 'the lever fires without any creep damage')
end

tests['[nil] the predicate answers false rather than raising on nil'] = function()
    local J = world(FIX, HERO, nil)
    assert(J.IsPullCampChewing(nil) == false, 'nil must answer false, not raise')
end

-- ------------------------------------------------------------------ 4. the
-- ------------------------------------------------- world assumption, pinned --

tests['[world] without the opt-in the neutral reader is still empty'] = function()
    -- Four other files declare `GetNearbyNeutralCreeps == {}` on every fixture
    -- as a world assumption and build claims on it. This lever must not have
    -- quietly turned the model on for them. Pinned from this side too, exactly
    -- as tpchew's file does.
    local J, bot = rf.load(FIX, HERO)
    assert(#bot:GetNearbyNeutralCreeps(1400) == 0,
        'the synthesized neutral reader is installed WITHOUT the opt-in -- four '
        .. 'other files declare the empty default; see the loader comment')
    assert(bot:WasRecentlyDamagedByCreep(6.0) == true,
        'the damage probe is a RESTORATION and must not need the opt-in')
    assert(J.IsPullCampChewing(bot) == false,
        'without the neutral model the lever must be inert, not guessing')
end

tests['[world] every radius answers alike -- the radius is NOT validated here'] = function()
    -- Stronger than "distance is not modelled", and the stronger form is the
    -- true one: the loader's reader takes NO radius parameter at all
    -- (`GetNearbyNeutralCreeps = function() return synth end`), so the argument
    -- is discarded rather than compared. Asserted so that nobody later reads a
    -- domain count through PULL_CHEW_NEUTRAL_RADIUS as if the geometry had been
    -- measured -- and so that the day the loader starts honouring a radius,
    -- this goes red pointing at the constant that can finally be priced.
    local _, bot = world(FIX, HERO, nil)
    local n400 = #bot:GetNearbyNeutralCreeps(400)
    for _, r in ipairs({ 700, 1000, 1400, 4000 }) do
        assert(#bot:GetNearbyNeutralCreeps(r) == n400,
            'radius ' .. r .. ' now differs from 400 -- distance became modelled, '
            .. 'so PULL_CHEW_NEUTRAL_RADIUS can finally be measured; go do that')
    end
    assert(n400 == 2, 'expected 2 handles (one per distinct member), got ' .. n400)
end

tests['⭐[world] the damage conjunct is UNFALSIFIABLE here, so it is pinned as source'] = function()
    -- Found by the mutation stand, not reasoned out in advance: M6 (delete the
    -- damage conjunct, keep proximity) SURVIVED every behavioural assertion in
    -- this file, and it survived for a structural reason rather than a missing
    -- case. The loader SYNTHESIZES the neutral list FROM the `src`-attributed
    -- damage rows, so on this instrument
    --
    --     neutral list non-empty  =>  WasRecentlyDamagedByCreep true
    --
    -- is an IDENTITY. No corpus frame can hold the second conjunct while the
    -- first is false, so no behavioural test here can ever kill M6 -- and in
    -- the real engine the two are plainly independent (vision is not damage),
    -- which is exactly why the conjunct must stay.
    --
    -- ⛔ THE HONEST LABEL: this is a SOURCE pin standing in for a behavioural
    -- one, and it is weaker. It is written down rather than quietly omitted
    -- because a lever whose guard cannot be falsified locally is the thing this
    -- stream is supposed to declare, not the thing it is supposed to hide.
    local corpus = {}
    for _, hero in ipairs({ HERO, N_LANE, N_NONE }) do
        local _, bot = world(FIX, hero, nil)
        local dmg = bot:WasRecentlyDamagedByCreep(6.0)
        local neut = #bot:GetNearbyNeutralCreeps(1400) > 0
        corpus[#corpus + 1] = hero
        assert(not neut or dmg,
            'a frame now carries neutrals WITHOUT creep damage (' .. hero
            .. ') -- the identity is broken, so the damage conjunct has become '
            .. 'behaviourally testable; replace this source pin with that test')
    end
    assert(#corpus == 3, 'the identity was checked on fewer heroes than claimed')
    -- The pin itself: the conjunct is present, and it REFUSES rather than
    -- merely being evaluated.
    local src = read_file('bots/FunLib/jmz_func.lua')
    local at = assert(src:find('function J.IsPullCampChewing', 1, true))
    local body = src:sub(at, assert(src:find('\nend\n', at, true)))
    assert(body:find('if not bot:WasRecentlyDamagedByCreep( PULL_CHEW_LOOKBACK ) then return false end', 1, true),
        'the damage conjunct is gone from J.IsPullCampChewing -- the lever now '
        .. 'refuses a pull for STANDING NEAR a camp, which is most of the '
        .. 'jungle and the opposite of the mechanic')
end

-- ------------------------------------------------------------------ 5. the
-- ------------------------------------------------------- wiring, as source --
--
-- These are NOT the local validation (the charter is explicit that gate
-- plumbing is not) -- sections 1-4 are. They are here because the reasoning
-- above depends on WHERE the clause sits, and a clause that moves silently
-- turns the argument false without turning anything red.

tests['[wire] the gate is exactly one soak id, standalone'] = function()
    local body = helper_body()
    local line = body:match("[^\n]*IsSoakCandidate%( 'pullchew' %)[^\n]*")
    assert(line, "the 'pullchew' gate is not inside J.ShouldPullNeutralCamp")
    local n = 0
    for _ in line:gmatch('IsSoakCandidate') do n = n + 1 end
    assert(n == 1,
        'two soak ids on one line is the `pullcad` shape: nothing can then arm '
        .. "one without touching the other's code path")
    local src = read_file('bots/FunLib/jmz_func.lua')
    local gates = 0
    for _ in src:gmatch("IsSoakCandidate%( 'pullchew' %)") do gates = gates + 1 end
    assert(gates == 1, "expected exactly one 'pullchew' gate, found " .. gates)
end

tests['⭐[wire] the commitment exemption is present'] = function()
    -- Without `roamCampPull == nil` this lever aborts every pull it has, at the
    -- aggro instant. That is not a style point, it is the difference between
    -- this id and a `lanefix`-shaped mute of a mechanic the owner named twice.
    local body = helper_body()
    local line = assert(body:match("[^\n]*IsSoakCandidate%( 'pullchew' %)[^\n]*"))
    local at = body:find("IsSoakCandidate%( 'pullchew' %)")
    local window = body:sub(at, at + 220)
    assert(window:find('roamCampPull == nil', 1, true) or line:find('roamCampPull == nil', 1, true),
        'the in-progress exemption is gone -- the lever now fires on frames '
        .. 'where a pull is already under way and will abort it')
end

tests['[wire] the clause sits after the hero-threat clause and before the camp loop'] = function()
    -- Section 1's reading is "the same clause, asked about the other units", so
    -- ORDER is what the argument uses. Also: below the threat clause means an
    -- enemy hero still short-circuits first, so no engine call is added to the
    -- frames the shipped guard already refuses.
    local body = helper_body()
    local at_threat = assert(body:find('GetEnemiesNearLoc', 1, true),
        'the enemy-hero threat clause is gone')
    local at_chew = assert(body:find("IsSoakCandidate%( 'pullchew' %)"))
    local at_camps = assert(body:find('GetNeutralSpawners()', 1, true),
        'the camp loop is gone')
    assert(at_threat < at_chew, 'the chew clause moved ABOVE the hero-threat clause')
    assert(at_chew < at_camps, 'the chew clause moved BELOW the camp loop')
end

tests['[wire] the predicate carries no gate of its own'] = function()
    -- The caller owns the gate, so an unarmed game makes neither engine call.
    -- A gate inside the helper as well would be the `pullcad` trap again.
    local src = read_file('bots/FunLib/jmz_func.lua')
    local at = assert(src:find('function J.IsPullCampChewing', 1, true),
        'J.IsPullCampChewing is gone')
    local stop = assert(src:find('\nend\n', at, true))
    local body = src:sub(at, stop)
    assert(not body:find('IsSoakCandidate', 1, true),
        'the predicate gates itself as well as being gated -- pick one')
    assert(not body:find('IsModeTurbo', 1, true),
        'the turbo gate belongs to the caller, which returns nil above it')
end

return tests

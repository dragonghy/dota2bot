-- [hero] `zusjumpany` -- X.ConsiderE's RETREAT firing point asks "is there an
-- enemy I am running away from?" of exactly one member of the ring it built,
-- and the gated widening that asks it of the ring.
--
-- ===========================================================================
-- §0  WHAT IS WRONG
-- ===========================================================================
--
-- bots/BotLib/hero_zuus.lua X.ConsiderE, retreat branch, as shipped:
--
--     local tableNearbyEnemyHeroes = J.GetNearbyHeroes(bot, nCastRange, true, ...)
--     ...
--     local targetHero = tableNearbyEnemyHeroes[1]
--     if J.IsValidHero( targetHero )
--         and J.CanCastOnNonMagicImmune( targetHero )
--         and not bot:IsFacingLocation( targetHero:GetLocation(), 120 )
--     then return BOT_ACTION_DESIRE_HIGH end
--
-- The question the branch is about is EXISTENTIAL -- Heavenly Jump is a
-- no-target hop along the bot's own facing, and the branch buys "hop away from
-- whoever is chasing me".  It is asked of index 1 and of nobody else.
--
-- ⭐ THE LIST IS SORTED, AND THAT IS THE POINT, NOT AN OBJECTION TO IT.
-- docs/BOT_API_REFERENCE.md:1229 makes sorted-by-distance a promise for the
-- whole GetNearby* family, and J.GetNearbyHeroes (jmz_func.lua:2856) only
-- filters -- it never reorders.  So [1] is the NEAREST enemy, reliably.  This
-- is therefore NOT the `anyhero` shape (GH #724), where an existential was
-- handed to an ARBITRARY member and sorting the list would have fixed it.  It
-- is the GH #731 shape: the list is ordered CORRECTLY and the ordering is
-- irrelevant, because the predicate is DIRECTION and the sort key is DISTANCE.
-- The nearest enemy and the enemy at your back are different questions, and
-- the shipped term answers the second one with the first one's handle.
--
-- ===========================================================================
-- §0.1  WHAT THE LEVER DOES
-- ===========================================================================
--
-- X.zuus_IsRetreatJumpThreat is the shipped three-conjunct test, moved verbatim
-- and in the shipped order.  X.zuus_FindRetreatJumpThreat evaluates it on
-- `tEnemies[1]` and nothing else while the gate is off, and on every member
-- until one answers while it is on.  Index 1 is IN that scan, so the armed leg
-- fires on every frame the shipped leg fires on: a WIDENING, by the shape of
-- the loop rather than by today's arithmetic.  §4 drives that both ways and §5
-- drives the unarmed identity.
--
-- ===========================================================================
-- §0.2  THE READING (one real frame, real positions, facing SWEPT)
-- ===========================================================================
--
-- tests/frames/f_260909_215227_zeus_jump_283.lua, t=283.4, Zeus the subject:
--
--     zuus           at (5520.6, -5865.5)  Heavenly Jump rank 1, castable
--     skeleton_king  at (5718.8, -5734.5)  237.58u  bearing  33.46 deg
--     lich           at (5670.3, -5598.3)  306.28u  bearing  60.74 deg
--
-- Both inside the rank-1 ring (700).  The shipped leg can only ever be about
-- Wraith King; the armed leg can be about either.  The branch fires on a target
-- whose bearing is more than 120 deg off the bot's facing, so each enemy
-- authorises a 120-deg arc of facings and the two arcs are offset by the 27.28
-- deg between the bearings.  §3 SWEEPS the circle at 1-deg steps THROUGH THE
-- REAL HELPER -- it does not recompute the arc -- and counts:
--
--     shipped leg fires        120 of 360 facings
--     armed leg fires          147 of 360 facings
--     armed only                27 of 360 facings   (the block 274..300 deg)
--     shipped only               0 of 360 facings   <- the widening, measured
--
-- 27 of 360 is 7.5% of facings on which the shipped tree declines an escape the
-- armed tree takes, and the 0 is the half that makes "widening" a reading
-- rather than a claim about the loop's shape.
--
-- ===========================================================================
-- §0.3  LIMITS -- READ BEFORE QUOTING ANY NUMBER OUT OF THIS FILE
-- ===========================================================================
--
--  1. ⚠️ THE FACING IS INJECTED.  `IsFacingLocation` is on no spec in
--     tests/mock/, so it falls through bot_api.lua's `^Is -> false` catch-all.
--     Unmodified, `not bot:IsFacingLocation(...)` is VACUOUSLY TRUE for every
--     candidate on every frame -- so the two legs are identical everywhere and
--     this lever's DRIVEN domain over the corpus is 0.0 deg.  That zero is the
--     harness's, not the game's; §2 asserts it in that direction so the file
--     cannot be read as "the lever does nothing".  Same family as GH #715 (mock
--     IsMagicImmune never refuses) and the `GetFacing -> 0` note in
--     X.zuus_IsJumpTargetInShockwaveReach's header.  A .dem carries no facing
--     (tests/mock/replay_fixture.lua:613), so no fixture can lift this.
--  2. THE CORPUS SUPPLY IS ONE FRAME.  §1 counts it rather than assuming it:
--     60 live-Zeus instants, 38 reaching the body, 4 with >= 2 enemies in the
--     ring and exactly 1 that is both.  A lever whose question needs two
--     enemies in a 700-1000u ring is rare in this corpus, and that is a
--     statement about the corpus.
--  3. NO FIRING RATE IS CLAIMED.  `GetActiveMode` is in no .dem, so
--     J.IsRetreating and J.IsRunning are false over the whole corpus and the
--     branch never opens on its own; §4 injects the mode to reach it, and says
--     so.  How often a retreating Zeus really has two enemies in the ring with
--     the near one in front is a batch question (queue.json).
--  4. WHAT IT DOES NOT CLAIM: that the added jumps are GOOD ones.  The hop goes
--     along the bot's facing, so on the disagreement arc it may close distance
--     on the nearer enemy.  §3 reports the arc; nothing here reports a payoff.

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')

local SRC    = 'bots/BotLib/hero_zuus.lua'
local CAND   = 'zusjumpany'
local UNIT   = 'npc_dota_hero_zuus'
local JUMP   = 'zuus_heavenly_jump'
local FRAME  = 'tests/frames/f_260909_215227_zeus_jump_283.lua'
local NEAR   = 'npc_dota_hero_skeleton_king'   -- the nearest enemy, i.e. [1]
local FAR    = 'npc_dota_hero_lich'            -- the one only the armed leg sees

local FIXTURE_DIR = 'tests/fixtures'
local STAGED_DIR  = 'tests/frames'

local tests = {}

local function read_file(path)
    local fh = assert(io.open(path, 'r'), 'cannot open ' .. path)
    local body = fh:read('*a')
    fh:close()
    return body
end

--- Both corpus directories, enumerated -- never a hardcoded list.
local function corpus_paths()
    local out = {}
    for _, dir in ipairs({ FIXTURE_DIR, STAGED_DIR }) do
        local n = 0
        -- UNRESOLVED_HAND_READ: io.popen, registered per GH #596's habit.
        local p = assert(io.popen('ls ' .. dir .. ' 2>/dev/null'))
        for name in p:lines() do
            if name:match('^f_.*%.lua$') then
                out[#out + 1] = dir .. '/' .. name
                n = n + 1
            end
        end
        p:close()
        assert(n > 0, 'corpus directory ' .. dir .. ' yielded no f_*.lua frame')
    end
    table.sort(out)
    return out
end

--- Install `v` as the answer to `h:k()` and drop any lazily-cached method.
--- Setting only the spec entry leaves an already-materialised method in place
--- and the injection silently does not take -- which reads exactly like a lever
--- that does nothing.
local function inject(h, k, v)
    rawget(h, '__spec')[k] = v
    rawset(h, k, nil)
end

local function frame(bArmed, path)
    local J, bot = rf.load(path or FRAME, UNIT)
    J.IsSoakCandidate = function(id) return bArmed and id == CAND end
    local X = rf.load_hero('zuus')
    return J, bot, X
end

local function enemy_handle(bot, sName)
    for _, e in ipairs(bot:GetNearbyHeroes(1600, true, BOT_MODE_NONE)) do
        if e:GetUnitName() == sName then return e end
    end
    return nil
end

--- The REAL engine semantics of `IsFacingLocation( vLoc, nTol )`: true when the
--- location lies within nTol degrees of the unit's facing.  Installed on the
--- SUBJECT only, so every other unit keeps the mock's own answer and limit 1
--- stays visible rather than being papered over globally.
local function inject_facing(bot, nFacingDeg)
    inject(bot, 'GetFacing', nFacingDeg)
    inject(bot, 'IsFacingLocation', function(self, vLoc, nTol)
        local v = self:GetLocation()
        local b = math.atan2(vLoc.y - v.y, vLoc.x - v.x) * 180 / math.pi
        local d = math.abs((b - nFacingDeg + 180) % 360 - 180)
        return d <= nTol
    end)
end

local function bearing_to(bot, h)
    local a, b = bot:GetLocation(), h:GetLocation()
    return math.atan2(b.y - a.y, b.x - a.x) * 180 / math.pi % 360
end

--- The two legs of the lever on FRAME at one facing, as (shipped, armed).  The
--- two worlds are loaded ONCE and only the facing is re-injected per degree:
--- reloading the hero per degree cost ~90s for a 360-step sweep, which is the
--- difference between this file being inside `lua_gate.py`'s per-test cap and
--- outside it (GH #616 constraint 1: membership is measured seconds, never a
--- filename).  Nothing else in the world is mutated between steps, so the two
--- handles stay the frame's.
local legs
do
    local _, b0, X0 = frame(false)
    local _, b1, X1 = frame(true)
    local nR = 600 + b0:GetAbilityByName(JUMP):GetLevel() * 100
    legs = function(deg)
        inject_facing(b0, deg)
        inject_facing(b1, deg)
        return X0.zuus_FindRetreatJumpThreat(b0, b0:GetNearbyHeroes(nR, true, BOT_MODE_NONE)),
               X1.zuus_FindRetreatJumpThreat(b1, b1:GetNearbyHeroes(nR, true, BOT_MODE_NONE))
    end
end

-- ---------------------------------------------------------------- section 1 --
-- The SUPPLY, counted over the corpus.  Needs no facing, so limit 1 does not
-- touch it.  Direction-safe bounds only (`>=`), per the discipline the two
-- census rewrites of 2026-09-10/11 were about: a corpus that GROWS must not
-- turn this red, and every number that is not itself the conclusion is a floor.

tests['§1 the corpus supplies exactly one frame that can pose the question'] = function()
    local nLive, nBody, nRing2, nBoth = 0, 0, 0, 0
    local sBoth = nil
    for _, path in ipairs(corpus_paths()) do
        local ok, chunk = pcall(dofile, path)
        if ok and type(chunk) == 'table' then
            local present = false
            for _, u in ipairs(chunk.units or {}) do
                if u.name == UNIT and u.alive ~= false then present = true end
            end
            if present then
                nLive = nLive + 1
                local _, bot = rf.load(path, UNIT)
                local hAb = bot:GetAbilityByName(JUMP)
                local nLv = hAb and hAb:GetLevel() or 0
                local bBody = hAb ~= nil and hAb:IsFullyCastable() and not bot:IsRooted()
                local nRing = 600 + nLv * 100
                local n = #bot:GetNearbyHeroes(nRing, true, BOT_MODE_NONE)
                if bBody then nBody = nBody + 1 end
                if n >= 2 then nRing2 = nRing2 + 1 end
                if bBody and n >= 2 then
                    nBoth = nBoth + 1
                    sBoth = path
                end
            end
        end
    end
    -- Floors, not equalities: a growing corpus may only make these larger.
    assert(nLive >= 60, 'live-Zeus instants fell to ' .. nLive .. ' (floor 60)')
    assert(nBody >= 38, 'frames reaching the body fell to ' .. nBody .. ' (floor 38)')
    assert(nRing2 >= 4, 'frames with >= 2 in the ring fell to ' .. nRing2 .. ' (floor 4)')
    -- This one IS the conclusion: the lever's whole locally-checkable domain.
    assert(nBoth >= 1, 'no corpus frame both reaches the body and holds >= 2 '
        .. 'enemies in the ring -- the lever has no local domain left')
    assert(sBoth == FRAME or nBoth > 1, 'the single qualifying frame moved: '
        .. tostring(sBoth) .. ' (this file reads ' .. FRAME .. ')')
end

-- ---------------------------------------------------------------- section 2 --
-- Limit 1, asserted rather than footnoted.  With the mock's OWN IsFacingLocation
-- the two legs cannot be told apart anywhere, and this file must say that in the
-- direction that stops its own §3 being read as a corpus reading.

tests['§2 with the mock\'s own IsFacingLocation the lever\'s domain is a harness zero'] = function()
    local _, bot = rf.load(FRAME, UNIT)
    assert(bot:IsFacingLocation(Vector(0, 0, 0), 120) == false,
        'IsFacingLocation now answers something -- limit 1 is stale, re-read §0.3')

    -- ⭐ THE POSITIVE CONTROL ON THIS FILE'S OWN INSTRUMENT, and it is the half
    -- §2 shipped without on its first draft.  Every number in §3/§4/§5/§7 rests
    -- on `inject_facing` taking; an injection that silently does not take makes
    -- the whole file read EXACTLY like a lever that does nothing, and the line
    -- above cannot tell the two apart -- it reads a world the injector never
    -- touched.  The stand's M8 blinds the injector, and until this control
    -- existed M8 SURVIVED with the file still green on the sections that are
    -- about the injected facing.  So: inject, then assert the answer MOVED, in
    -- both directions, on a location whose bearing is known by construction.
    local v = bot:GetLocation()
    local vEast = Vector(v.x + 500, v.y, v.z)
    inject_facing(bot, 0)
    assert(bot:IsFacingLocation(vEast, 10) == true,
        'the facing injector did not take -- nothing in §3/§4/§5/§7 is about the '
        .. 'facings it names')
    inject_facing(bot, 180)
    assert(bot:IsFacingLocation(vEast, 10) == false,
        'the facing injector did not take (it answers the same at 0 and 180 deg)')

    local nDiff = 0
    for _, path in ipairs(corpus_paths()) do
        local ok, chunk = pcall(dofile, path)
        if ok and type(chunk) == 'table' then
            local present = false
            for _, u in ipairs(chunk.units or {}) do
                if u.name == UNIT and u.alive ~= false then present = true end
            end
            if present then
                local _, b0, X0 = frame(false, path)
                local _, b1, X1 = frame(true,  path)
                local hAb = b0:GetAbilityByName(JUMP)
                local nRing = 600 + (hAb and hAb:GetLevel() or 0) * 100
                local t0 = b0:GetNearbyHeroes(nRing, true, BOT_MODE_NONE)
                local t1 = b1:GetNearbyHeroes(nRing, true, BOT_MODE_NONE)
                local r0 = X0.zuus_FindRetreatJumpThreat(b0, t0)
                local r1 = X1.zuus_FindRetreatJumpThreat(b1, t1)
                if (r0 == nil) ~= (r1 == nil) then nDiff = nDiff + 1 end
            end
        end
    end
    assert(nDiff == 0, 'the two legs differ on ' .. nDiff .. ' frame(s) with the '
        .. 'facing stub in place -- that cannot happen while the third conjunct '
        .. 'is vacuously true, so either the mock grew a facing or the helper '
        .. 'stopped evaluating it')
end

-- ---------------------------------------------------------------- section 3 --
-- The swept reading.  The facing is INJECTED (limit 1); everything else --
-- positions, ring radius, ability rank, the predicate itself -- is the frame's.

tests['§3 the legs disagree on 27.28 deg of the facing circle, swept through the helper'] = function()
    local _, bot0 = rf.load(FRAME, UNIT)
    local hNear = assert(enemy_handle(bot0, NEAR), NEAR .. ' left ' .. FRAME)
    local hFar  = assert(enemy_handle(bot0, FAR),  FAR  .. ' left ' .. FRAME)
    local dNear = GetUnitToUnitDistance(bot0, hNear)
    local dFar  = GetUnitToUnitDistance(bot0, hFar)
    assert(dNear < dFar, 'the nearest enemy is no longer ' .. NEAR)
    local bNear, bFar = bearing_to(bot0, hNear), bearing_to(bot0, hFar)
    local sep = math.abs((bNear - bFar + 180) % 360 - 180)

    local nOnlyArmed, nOnlyShipped, nBoth = 0, 0, 0
    for deg = 0, 359 do
        local r0, r1 = legs(deg)
        if r0 ~= nil and r1 ~= nil then nBoth = nBoth + 1
        elseif r1 ~= nil then nOnlyArmed = nOnlyArmed + 1
        elseif r0 ~= nil then nOnlyShipped = nOnlyShipped + 1 end
    end

    -- The WIDENING, as a property of the sweep and not of the header prose.
    assert(nOnlyShipped == 0, 'the shipped leg fired on ' .. nOnlyShipped
        .. ' facing(s) the armed leg refused -- this lever is supposed to be a '
        .. 'strict superset')
    -- The disagreement is the bearing separation, degree for degree.  Both are
    -- read off the frame; neither is a constant in this file.
    assert(math.abs(nOnlyArmed - sep) <= 1.5, 'swept disagreement ' .. nOnlyArmed
        .. ' deg does not match the bearing separation ' .. string.format('%.2f', sep)
        .. ' deg')
    assert(nOnlyArmed >= 20, 'the disagreement arc collapsed to ' .. nOnlyArmed .. ' deg')
    -- And the shipped leg really does fire on most of the circle, so the 27 deg
    -- is a strip on a live branch rather than the whole of a dead one.
    assert(nBoth >= 90, 'the shipped leg fires on only ' .. nBoth .. ' facings')
end

-- ---------------------------------------------------------------- section 4 --
-- End to end through the REAL dispatch, on one facing inside the disagreement
-- arc.  Mode injected (limit 3), facing injected (limit 1), nothing else.

tests['§4 on a facing in the arc the shipped tree declines the escape and the armed tree takes it'] = function()
    local function drive(bArmed, deg)
        local J, bot, X = frame(bArmed)
        inject_facing(bot, deg)
        -- Limit 3, itemised: J.IsRetreating reads mode + mode DESIRE +
        -- DistanceFromFountain (the loader wires that one for real), and
        -- J.IsRunning reads the anim activity.  A .dem carries none of the
        -- three, so all three are injected and each is asserted to have taken
        -- -- an injection that silently does not land reads exactly like a
        -- lever that does nothing.
        inject(bot, 'GetActiveMode', BOT_MODE_RETREAT)
        inject(bot, 'GetActiveModeDesire', BOT_MODE_DESIRE_HIGH)
        inject(bot, 'GetAnimActivity', ACTIVITY_RUN)
        assert(J.IsRetreating(bot), 'the retreat mode injection did not take')
        assert(J.IsRunning(bot), 'the anim-activity injection did not take')
        local d = X.ConsiderE()
        return d, J, bot, X
    end

    -- The two facings are DERIVED by sweeping the real helper, not written
    -- down: `deg` is a facing on which only the armed leg elects anybody (the
    -- far enemy is behind the bot, the near one is not), `degBoth` one on which
    -- both legs elect.  Deriving them from the helper rather than from the
    -- bearings keeps this section independent of §3's arithmetic; a hand-written
    -- midpoint got the wrong side of the arc on the first draft and the section
    -- failed with a number that looked like a lever defect.
    local deg, degBoth
    for d = 0, 359 do
        local r0, r1 = legs(d)
        if deg == nil and r0 == nil and r1 ~= nil then deg = d end
        if degBoth == nil and r0 ~= nil and r1 ~= nil then degBoth = d end
    end
    assert(deg ~= nil, 'no facing separates the two legs on ' .. FRAME)
    assert(degBoth ~= nil, 'no facing fires the shipped leg on ' .. FRAME)

    local dOff = drive(false, deg)
    local dOn, _, botOn, XOn = drive(true, deg)
    assert(dOff == BOT_ACTION_DESIRE_NONE or dOff == 0,
        'the shipped tree bid ' .. tostring(dOff) .. ' on a facing where its own '
        .. 'single candidate is in front of it')
    assert(dOn == BOT_ACTION_DESIRE_HIGH,
        'the armed tree bid ' .. tostring(dOn) .. ' where the far enemy is behind it')

    -- ...and it is the FAR enemy that authorised it, not a second reading of the
    -- near one.  Without this the section is satisfied by any widening at all.
    local nRing = 600 + botOn:GetAbilityByName(JUMP):GetLevel() * 100
    local h = XOn.zuus_FindRetreatJumpThreat(botOn, botOn:GetNearbyHeroes(nRing, true, BOT_MODE_NONE))
    assert(h ~= nil and h:GetUnitName() == FAR,
        'the armed leg elected ' .. tostring(h and h:GetUnitName()) .. ', not ' .. FAR)

    -- THE EXEMPTION HALF, and it is not optional: on a facing where the NEAR
    -- enemy is already behind, both legs fire and the armed one changes nothing.
    -- Without it, "armed is a widening" and "armed is an on/off switch for this
    -- branch" are the same reading.
    assert(drive(false, degBoth) == BOT_ACTION_DESIRE_HIGH, 'shipped leg silent at facing ' .. degBoth)
    assert(drive(true,  degBoth) == BOT_ACTION_DESIRE_HIGH, 'armed leg silent at facing ' .. degBoth)
    local _, bE, XE = frame(true)
    inject_facing(bE, degBoth)
    local nRE = 600 + bE:GetAbilityByName(JUMP):GetLevel() * 100
    local hE = XE.zuus_FindRetreatJumpThreat(bE, bE:GetNearbyHeroes(nRE, true, BOT_MODE_NONE))
    assert(hE ~= nil and hE:GetUnitName() == NEAR,
        'at the exemption facing the armed leg elected ' .. tostring(hE and hE:GetUnitName())
        .. ' rather than leaving the shipped election alone')
end

-- ---------------------------------------------------------------- section 5 --
-- Gate OFF is the shipped code, not a near-miss of it.

tests['§5 unarmed the helper is the nearest enemy and nobody else'] = function()
    local _, bot, X = frame(false)
    local nRing = 600 + bot:GetAbilityByName(JUMP):GetLevel() * 100
    for deg = 0, 359 do
        inject_facing(bot, deg)
        local t = bot:GetNearbyHeroes(nRing, true, BOT_MODE_NONE)
        local got = X.zuus_FindRetreatJumpThreat(bot, t)
        local want = X.zuus_IsRetreatJumpThreat(bot, t[1]) and t[1] or nil
        assert(got == want, 'unarmed answer diverges from `tEnemies[1]` at facing ' .. deg)
    end
    -- An empty ring must be nil and must not raise: the shipped line read
    -- `tableNearbyEnemyHeroes[1]` with no length check either.
    assert(X.zuus_FindRetreatJumpThreat(bot, {}) == nil, 'empty ring is not nil')
    assert(X.zuus_FindRetreatJumpThreat(bot, nil) == nil, 'nil ring is not nil')
end

-- ---------------------------------------------------------------- section 7 --
-- Turbo-only, driven.  Without this case the `turbo` half of the gate is
-- untested and a mutant that drops it is invisible -- the whole corpus is a
-- Turbo world, so every other section would stay green while the lever went
-- live in normal games.

tests['§7 outside Turbo the armed leg is the shipped leg'] = function()
    local J, bot, X = frame(true)
    J.IsModeTurbo = function() return false end
    local nRing = 600 + bot:GetAbilityByName(JUMP):GetLevel() * 100
    -- The one facing §3 found the legs disagreeing on; in a non-Turbo world the
    -- armed leg must answer what the shipped leg answers there, i.e. nobody.
    for deg = 274, 300 do
        inject_facing(bot, deg)
        local t = bot:GetNearbyHeroes(nRing, true, BOT_MODE_NONE)
        assert(X.zuus_FindRetreatJumpThreat(bot, t) == nil,
            'the lever fires outside Turbo (facing ' .. deg .. ')')
    end
    -- ...and the same world with Turbo back on does elect, so the case above is
    -- not passing because something unrelated went dark.
    J.IsModeTurbo = function() return true end
    inject_facing(bot, 287)
    assert(X.zuus_FindRetreatJumpThreat(bot, bot:GetNearbyHeroes(nRing, true, BOT_MODE_NONE)) ~= nil,
        'the Turbo control did not elect either -- §7 proves nothing')
end

-- ---------------------------------------------------------------- section 6 --
-- Wiring, and the pullcad trap.

tests['§6 the helper names its own id exactly once, and only in this file'] = function()
    local src = read_file(SRC)
    assert(select(2, src:gsub("IsSoakCandidate%(%s*'" .. CAND .. "'%s*%)", '')) == 1,
        CAND .. ' is named by more than one gate in ' .. SRC)
    -- The gate's condition may name turbo and this id, and nothing else -- a
    -- gate naming a sibling freezes FALSE the day the sibling is promoted.
    local cond = assert(src:match("if not %( (J%.IsModeTurbo%(%) and J%.IsSoakCandidate%(%s*'"
        .. CAND .. "'%s*%)) %)"), 'the ' .. CAND .. ' gate is not the expected shape')
    assert(not cond:find('IsSoakCandidate', 1, true)
        or select(2, cond:gsub('IsSoakCandidate', '')) == 1,
        CAND .. "'s gate names a second candidate id")
    local nOther = 0
    -- UNRESOLVED_HAND_READ: io.popen, registered per GH #596's habit.
    local p = assert(io.popen("grep -rl \"'" .. CAND .. "'\" bots 2>/dev/null"))
    for line in p:lines() do
        if line ~= SRC then nOther = nOther + 1 end
    end
    p:close()
    assert(nOther == 0, CAND .. ' is named in ' .. nOther .. ' other bots/ file(s)')

    -- One call site, and it is the retreat branch.  Comments stripped first:
    -- the call site's own comment quotes the replaced expression verbatim.
    local bare = src:gsub('%-%-[^\n]*', '')
    assert(select(2, bare:gsub('X%.zuus_FindRetreatJumpThreat%s*%(', '')) == 2,
        'X.zuus_FindRetreatJumpThreat is not (definition + exactly one call site)')
    assert(not bare:find('tableNearbyEnemyHeroes%s*%[%s*1%s*%]'),
        'the shipped `tableNearbyEnemyHeroes[1]` read is still in ' .. SRC)
end

return tests

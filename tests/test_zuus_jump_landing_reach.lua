-- [hero] `zusjumpland` -- X.ConsiderE's 进攻 firing point measures Heavenly
-- Jump's target from where the hop TAKES OFF, while the shockwave that is the
-- whole payoff is searched from where the hop LANDS; and the gated narrowing
-- that makes the firing point measure the point the payload is measured from.
--
-- ===========================================================================
-- §0  WHAT IS WRONG
-- ===========================================================================
--
-- bots/BotLib/hero_zuus.lua X.ConsiderE bids on Heavenly Jump from exactly two
-- firing points:
--
--     retreat   J.IsRunning + tableNearbyEnemyHeroes[1]
--               + `not bot:IsFacingLocation( targetHero:GetLocation(), 120 )`
--     进攻      J.IsGoingOnSomeone + J.GetProperTarget
--               + `J.IsInRange( bot, targetHero, nCastRange )`
--
-- Heavenly Jump is a no-target hop.  The bot leaps `hop_distance`
-- (375/450/525/600 by rank) along ITS OWN FACING, and on landing a shockwave
-- seeks up to `targets` enemies within `range` (700/800/900/1000) OF THE
-- LANDING POINT.  The local the file calls `nCastRange` is that `range` ladder
-- spelled out by hand -- the function's own comment says so, and says it is not
-- a cast range.  It is a search radius, and its centre is not where the bot is
-- standing when the bid is made.
--
-- So the 进攻 firing point approves a jump by measuring the target from a point
-- the payload will never be searched from.  The two points differ by up to
-- `hop_distance`: at rank 1 that is 375 of a 700 radius, i.e. the take-off
-- reading can be wrong by more than half the radius it is being compared to.
--
-- The retreat firing point, thirty lines above, is the ONLY place in this file
-- that reasons about which way the hop goes -- and it reasons about it because
-- direction is exactly what that branch is buying (hop AWAY from the hero
-- chasing you).  So the function already knows the hop has a direction.  The
-- 进攻 point is where that knowledge is missing, and it is the point whose
-- payoff -- damage plus a 1.4s / 80% move slow -- is the thing direction
-- decides.  Same family as `lionrreach` (GH #617), `wkqlane` (GH #621) and
-- `cmlaneband` (GH #630): a firing point whose reach term does not measure the
-- thing the branch is about.  It is NOT the same defect -- those three are
-- rings that are too WIDE.  This one is a ring of the right size measured from
-- the wrong CENTRE, and it is wrong in both directions (see §3: half the facing
-- circle connects, half does not, and the shipped term cannot tell them apart).
--
-- ===========================================================================
-- §0.1  THE READING (one real frame, real KV, NOTHING injected)
-- ===========================================================================
--
-- tests/fixtures/f_230510_dp_luna_standoff.lua, Zeus the subject:
--
--     Heavenly Jump rank 1, IsFullyCastable() true, bot not rooted.
--     GetSpecialValueInt('hop_distance') answers a truthful 375 and
--     GetSpecialValueInt('range') a truthful 700, both off the KV snapshot
--     (Zeus is one of the focus five, so the snapshot is real).
--     zeus   at (6240.6, -4675.4)
--     oracle at (5948.3, -5306.2)   =>  695.23u apart
--
-- 695.23 is 4.77u INSIDE the shipped 700 ring -- the shipped term passes, with
-- room to spare.  And it is 370.23u OUTSIDE `range - hop_distance` = 325, which
-- is the largest distance at which the shockwave connects no matter which way
-- the bot faces.  So this frame sits in the band where the shipped term's answer
-- carries no information about whether the cast does anything:
--
--     facing                       landing point       oracle to landing
--     ---------------------------  ------------------  -----------------
--     -114.86 deg (straight AT)    (6082.9, -5015.6)     320.23  connects
--      +65.14 deg (straight AWAY)  (6398.3, -4335.2)    1070.23  MISSES by 370
--
-- ===========================================================================
-- §0.2  WHAT THE LEVER DOES
-- ===========================================================================
--
-- X.zuus_IsJumpTargetInShockwaveReach evaluates the SHIPPED predicate first and
-- returns false unchanged when it is false, so armed it can only ever turn a
-- shipped TRUE into FALSE: a strict narrowing, by construction rather than by
-- today's arithmetic.  §5 drives that.  Two consequences that must ride along
-- with any reading of this id:
--
--   (a) evaluating the shipped call first is also what keeps J.IsInRange's own
--       `CanBeSeen()` conjunct on BOTH legs.  Recomputing the distance inside
--       the helper would have dropped it and made the armed leg not a subset.
--   (b) because the shipped answer is not a constant here (unlike `cmlaneband`,
--       where it was an unconditional true), a WIDENING mutant IS expressible on
--       this id, and the stand has one: M4 measures from the landing point
--       WITHOUT the shipped guard, which admits targets the shipped term
--       refuses.
--
-- ===========================================================================
-- §0.3  LIMITS -- READ BEFORE QUOTING ANY NUMBER OUT OF THIS FILE
-- ===========================================================================
--
--  1. THE QUANTITY THIS LEVER TURNS ON IS NOT IN THE FIXTURE CORPUS, AND THE
--     MOCK ANSWERS IT ANYWAY.  make_fixture.py dumps x/y and no facing on any
--     of the fixtures (tests/mock/replay_fixture.lua:613 declares this for
--     GetExtrapolatedLocation; facing is the same absence).  `GetFacing` is not
--     in any fixture's unit spec, so it falls through bot_api.lua's `^Get -> 0`
--     catch-all and answers a silent, unraised 0: in this corpus every hero in
--     every frame faces due east.  That is a measuring-instrument constant, not
--     a reading -- exactly the shape of GH #611 (out-facing damage constant 0)
--     and GH #613 (two of three chase disjuncts constant false), and the same
--     shape this stream's own previous round found in GetCurrentMovementSpeed.
--     ⇒ NO domain count in this file is a count of "how often armed refuses in
--     a real game".  §1 counts GEOMETRY (which needs no facing); §3 sweeps
--     facing as an INJECTED parameter and says so in its name; §4 injects one
--     facing and asserts the injection took.  Nothing here claims a rate.
--     ⚠️ Neither instrument raises when it is wrong, so nothing in a green run
--     points at either.  The first draft of §4 also read the wrong argument
--     index out of rf.record_actions (the log drops `self`, so the ability is
--     args[1]) and reported "no cast was ordered" on a frame that ordered one.
--     Two instruments, both answering confidently, both wrong toward "nothing
--     happened" -- which is why §4 asserts that each injection TOOK rather than
--     inferring it from the outcome.
--
--  2. §1's band count is over enemy heroes inside the shipped ring, not over
--     the branch's actual candidate.  The branch's candidate is
--     J.GetProperTarget, which reads GetTarget/GetAttackTarget, and
--     GetActiveMode is not in any .dem either -- so on this corpus
--     J.IsGoingOnSomeone is false on every frame and the branch never opens by
--     itself.  §1 is therefore an upper bound on the branch's own domain, and
--     is honest only as what it says it is: how often the geometry that makes
--     the shipped term uninformative is actually present.
--     RE-TAKEN 2026-09-09 (hero, GH #659), 48 -> 49 live-Zeus frames: the staged
--     transit frame f_260908_094909_cm_cmqreach_transit.lua carries a live
--     level-20 Zeus.  ⭐ ONLY THE DENOMINATOR MOVED.  His nearest enemy hero is
--     ~5.4k away, so he contributes neither a band sighting nor a
--     direction-proof one: the geometry stays 5 / 5 over 5 frames, and the
--     upper bound this limit reports got LOOSER as a fraction (5 of 48 -> 5 of
--     49) without any of the three lever-domain numbers being re-derived.
--
--  3. REGISTERED, NOT FIXED -- the retreat firing point.  It is deliberately
--     untouched.  Its payoff is the displacement itself, not the shockwave, and
--     it already carries the only facing term in the file.  §6 pins that this
--     file still has exactly two firing points and that the helper is wired
--     into exactly one of them, so a future round that routes the retreat
--     branch through the same helper finds out here that this file assumed it
--     had not.
--
--  4. REGISTERED, NOT FIXED -- `nCastRange = 600 + nSkillLV * 100` is the KV
--     `range` key written out by hand, and §2 proves the ability answers that
--     key truthfully (700 at rank 1).  Replacing the ladder with the read is a
--     readability change with no behaviour in it, so under P4.4 it cannot be a
--     work unit's body; it also is not free (the ladder is what makes the
--     function work when the handle is misbound).  Whoever takes it retires
--     this limit.  This file reads `hop_distance` rather than laddering it
--     precisely so that it does not add a SECOND hand-copied ladder.
--
-- ===========================================================================
-- WHAT THIS FILE DOES NOT CLAIM
-- ===========================================================================
--   (A) It does not claim armed is better.  It claims the shipped term does not
--       measure what the branch spends mana on, and that armed measures it.
--       Condition (b) is a batch question (queue.json:hero-48).
--   (B) It does not claim a firing rate for the 进攻 branch.  See limit 2.
--   (C) It does not claim the corpus exercises the armed leg's decision.  See
--       limit 1.  The corpus exercises the GEOMETRY; the decision needs facing.

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')

local SRC    = 'bots/BotLib/hero_zuus.lua'
local CAND   = 'zusjumpland'
local HELPER = 'zuus_IsJumpTargetInShockwaveReach'
local UNIT   = 'npc_dota_hero_zuus'
local JUMP   = 'zuus_heavenly_jump'
local ORACLE = 'npc_dota_hero_oracle'

local FRAME = 'tests/fixtures/f_230510_dp_luna_standoff.lua'

local FIXTURE_DIR = 'tests/fixtures'
local STAGED_DIR  = 'tests/frames'

-- The two KV ladders, at the rank this frame is really at.  Both are ASSERTED
-- against the ability in §2 rather than trusted.
local RANK  = 1
local RANGE = 600 + RANK * 100      -- X.ConsiderE's own `600 + nSkillLV * 100`
local HOP   = 375                   -- KV hop_distance base, rank 1

local tests = {}

local function read_file(path)
    local fh = assert(io.open(path, 'r'), 'cannot open ' .. path)
    local body = fh:read('*a')
    fh:close()
    return body
end

--- Both corpus directories, enumerated -- never a hardcoded list.  An empty
--- enumerator and an empty corpus are the same integer; the assert in §1 is the
--- only thing that tells them apart.
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

--- Install `v` as the answer to `h:k()` and drop any lazily-cached method, the
--- same two steps rf.record_actions takes.  Setting only the spec entry leaves
--- an already-materialised method in place and the injection silently does not
--- take -- which reads exactly like a lever that does nothing.
local function inject(h, k, v)
    rawget(h, '__spec')[k] = v
    rawset(h, k, nil)
end

local function enemy_handle(bot, sName)
    for _, e in ipairs(bot:GetNearbyHeroes(1600, true, BOT_MODE_NONE)) do
        if e:GetUnitName() == sName then return e end
    end
    return nil
end

--- Load the frame with Zeus as the subject and arm (or not) the candidate.
--- Nothing else is touched: this is the stand §2 takes its readings on.
local function frame(bArmed)
    local J, bot = rf.load(FRAME, UNIT)
    J.IsSoakCandidate = function(id) return bArmed and id == CAND end
    local X = rf.load_hero('zuus')
    return J, bot, X
end

--- The landing point for a given facing, computed here from the raw geometry --
--- deliberately NOT by calling J.GetFaceTowardDistanceLocation, so that §3 is an
--- independent construction of the quantity the helper computes and not a
--- restatement of it.  (`cmlaneband`'s round learned the other way round: an
--- assertion that recomputes a quantity the same way the code does is blind to
--- how the code constructs it.  Here the helper is driven directly in §2/§4/§5;
--- §3 is the independent arithmetic.)
local function landing(bot, nFacingDeg, nHop)
    local r = nFacingDeg * math.pi / 180
    return bot:GetLocation() + nHop * Vector(math.cos(r), math.sin(r))
end

--- Drive the REAL X.SkillsComplement dispatch on the real frame with the three
--- limit-1/limit-2 injections in place.  Returns the log plus the handles §4
--- needs to prove each injection took.
local function drive(bArmed, nFacingDeg)
    local J, bot, X = frame(bArmed)
    local hOracle = enemy_handle(bot, ORACLE)
    assert(hOracle ~= nil, ORACLE .. ' is not on ' .. FRAME .. ' any more')
    inject(bot, 'GetActiveMode', BOT_MODE_ATTACK)   -- opens J.IsGoingOnSomeone
    inject(bot, 'GetTarget',     hOracle)           -- elects J.GetProperTarget
    inject(bot, 'GetFacing',     nFacingDeg)        -- the quantity limit 1 is about
    local log = rf.record_actions(bot)
    X.SkillsComplement()
    return log, J, bot, X, hOracle
end

--- Did the dispatch queue Heavenly Jump?  X.ConsiderE is the only arm in this
--- file whose executor is the no-target ActionQueue_UseAbility with abilityE.
--- rf.record_actions logs the call's arguments WITHOUT self, so the ability is
--- args[1]; reading args[2] here answers nil on every entry, which reads exactly
--- like "no cast was ordered".
local function jumped(log)
    for _, a in ipairs(log) do
        if a.fn:find('UseAbility$') then
            local h = a.args[1]
            if h ~= nil and h.GetName ~= nil and h:GetName() == JUMP then return true end
        end
    end
    return false
end

-- ---------------------------------------------------------------- section 1 --
-- The geometry domain, counted over the whole corpus.  Needs no facing, so it
-- is a real reading (limit 1) -- but it is an upper bound on the branch's own
-- domain, not the branch's domain (limit 2).

tests['§1 5 of 10 in-ring sightings sit in the band where facing decides'] = function()
    local nFiles, nLive = 0, 0
    local nBand, nSafe, nBandFrames = 0, 0, 0
    local bHasFrame = false
    for _, path in ipairs(corpus_paths()) do
        nFiles = nFiles + 1
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
                if nLv > 0 then
                    local nRange = 600 + nLv * 100
                    local nHop   = hAb:GetSpecialValueInt('hop_distance')
                    local b = 0
                    for _, e in ipairs(bot:GetNearbyHeroes(nRange, true, BOT_MODE_NONE)) do
                        if GetUnitToUnitDistance(bot, e) > nRange - nHop then
                            b = b + 1
                        else
                            nSafe = nSafe + 1
                        end
                    end
                    nBand = nBand + b
                    if b > 0 then
                        nBandFrames = nBandFrames + 1
                        if path == FRAME then bHasFrame = true end
                    end
                end
            end
        end
    end
    assert(nFiles >= 110, 'the corpus enumerator returned ' .. nFiles
        .. ' frames, expected >= 110 -- an empty ls and an empty corpus are the '
        .. 'same integer')
    assert(nLive == 49, 'Zeus is alive on ' .. nLive .. ' corpus frames, was 49 '
        .. '-- re-take §0.3 limit 2 rather than quoting it')
    assert(nBand == 5 and nSafe == 5, 'the geometry moved: ' .. nBand
        .. ' band / ' .. nSafe .. ' direction-proof sightings, was 5 / 5.  '
        .. 'Re-take §1 and §0.3 limit 2.')
    assert(nBandFrames == 5, 'band sightings now share frames (' .. nBandFrames
        .. ' frames for ' .. nBand .. ' sightings, was 5 for 5)')
    assert(bHasFrame, 'the §0.1 frame ' .. FRAME .. ' no longer puts an enemy '
        .. 'in the band, so §2 cannot be read off it')
end

-- ---------------------------------------------------------------- section 2 --
-- THE READING THIS ROUND STANDS BEHIND.  Real frame, real KV, real helper,
-- ZERO injections.  Everything asserted here is a number the corpus carries.

tests['§2 both KV ladders answer truthfully on the real frame'] = function()
    local _, bot = frame(false)
    local hAb = bot:GetAbilityByName(JUMP)
    assert(hAb ~= nil, JUMP .. ' has no handle on ' .. FRAME)
    assert(hAb:GetLevel() == RANK, 'Heavenly Jump is rank '
        .. tostring(hAb:GetLevel()) .. ' on this frame, was ' .. RANK
        .. ' -- both ladders in §0.1 move with it')
    assert(hAb:IsFullyCastable(), 'Heavenly Jump is not castable on this frame, '
        .. 'so X.ConsiderE returns NONE at its first line and §4 proves nothing')
    assert(not bot:IsRooted(), 'the bot is rooted on this frame, same problem')

    -- The lever READS hop_distance.  If the snapshot stopped answering it, the
    -- helper degenerates to the shipped answer and the id silently no-ops.
    assert(hAb:GetSpecialValueInt('hop_distance') == HOP,
        'hop_distance answers ' .. tostring(hAb:GetSpecialValueInt('hop_distance'))
        .. ', was ' .. HOP .. ' -- an armed leg reading 0 here is a no-op that '
        .. 'looks like a lever')
    -- §0.3 limit 4: the hand-written ladder and the KV key agree TODAY.
    assert(hAb:GetSpecialValueInt('range') == RANGE,
        "the KV `range` key answers " .. tostring(hAb:GetSpecialValueInt('range'))
        .. ' while X.ConsiderE ladders ' .. RANGE .. ' -- §0.3 limit 4 assumed '
        .. 'they agree, and a divergence is a behaviour question, not a '
        .. 'readability one')
end

tests['§2 the shipped term passes by 4.8u on a target 370u out of reach'] = function()
    local _, bot = frame(false)
    local hOracle = enemy_handle(bot, ORACLE)
    assert(hOracle ~= nil, ORACLE .. ' is no longer visible on ' .. FRAME)

    local d = GetUnitToUnitDistance(bot, hOracle)
    assert(d > 695 and d < 696, ORACLE .. ' is at ' .. string.format('%.2f', d)
        .. 'u, was 695.23 -- §0.1 is stale')
    assert(d <= RANGE, 'the shipped term no longer passes, so there is nothing '
        .. 'for the lever to narrow on this frame')
    assert(d > RANGE - HOP, ORACLE .. ' is now inside ' .. (RANGE - HOP)
        .. 'u, where the shockwave connects whatever the facing -- this frame '
        .. 'would then be direction-proof and §3 would be about nothing')

    -- The two extremes, arithmetic done here rather than by the helper.
    local vAt   = landing(bot, -114.86, HOP)
    local vAway = landing(bot,   65.14, HOP)
    local dAt   = GetUnitToLocationDistance(hOracle, vAt)
    local dAway = GetUnitToLocationDistance(hOracle, vAway)
    assert(dAt < 325, 'hopping straight at the target lands ' ..
        string.format('%.2f', dAt) .. 'u away, was 320.23')
    assert(dAway > RANGE, 'hopping straight away lands '
        .. string.format('%.2f', dAway) .. 'u away, which the ' .. RANGE
        .. 'u shockwave still reaches -- §0.1 is stale')
    assert(dAway - RANGE > 360, 'the miss is only '
        .. string.format('%.2f', dAway - RANGE) .. 'u, was 370.23')
end

-- ---------------------------------------------------------------- section 3 --
-- The magnitude, swept over the parameter the corpus does not carry.  This is
-- the ONLY section whose input is synthetic, and it is synthetic on purpose:
-- the point is that the shipped term's answer is CONSTANT across a parameter
-- that flips the outcome.  The arithmetic here is independent of the helper's.

tests['§3 [injected facing] the shipped term is constant across a parameter that flips the payload'] = function()
    local _, bot = frame(false)
    local hOracle = enemy_handle(bot, ORACLE)
    local nConnect, nMiss = 0, 0
    for f = 0, 359 do
        local dLand = GetUnitToLocationDistance(hOracle, landing(bot, f, HOP))
        if dLand <= RANGE then nConnect = nConnect + 1 else nMiss = nMiss + 1 end
    end
    assert(nConnect + nMiss == 360, 'the sweep lost a facing')
    assert(nMiss >= 120 and nMiss <= 240, 'only ' .. nMiss .. ' of 360 facings '
        .. 'miss; §0 claims the outcome is genuinely two-sided on this frame, '
        .. 'and a near-zero or near-total miss count would make it one-sided')
    -- ...and the shipped term said the same thing for all 360 of them.
    local _, botOff, XOff = frame(false)
    local hOff = enemy_handle(botOff, ORACLE)
    local hAb  = botOff:GetAbilityByName(JUMP)
    for _, f in ipairs({ 0, 65.14, 180, -114.86, 270 }) do
        inject(botOff, 'GetFacing', f)
        assert(XOff[HELPER](botOff, hOff, hAb, RANGE) == true,
            'gate off changed its answer at facing ' .. f
            .. ' -- the shipped leg must not read facing at all')
    end
end

tests['§3 [injected facing] armed tracks the payload in both directions'] = function()
    local _, bot, X = frame(true)
    local hOracle = enemy_handle(bot, ORACLE)
    local hAb = bot:GetAbilityByName(JUMP)
    for _, case in ipairs({
        { f = -114.86, want = true,  what = 'straight at the target'  },
        { f =  65.14,  want = false, what = 'straight away'           },
        { f = 180,     want = true,  what = 'due west'                },
        { f =   0,     want = false, what = 'due east'                },
    }) do
        inject(bot, 'GetFacing', case.f)
        local got = X[HELPER](bot, hOracle, hAb, RANGE)
        local dLand = GetUnitToLocationDistance(hOracle, landing(bot, case.f, HOP))
        assert(got == case.want, 'armed answered ' .. tostring(got)
            .. ' hopping ' .. case.what .. ' (facing ' .. case.f
            .. '), where the landing point is ' .. string.format('%.2f', dLand)
            .. 'u from the target and the shockwave reaches ' .. RANGE)
        assert((dLand <= RANGE) == case.want,
            'the independent arithmetic in §3 disagrees with the case table at '
            .. 'facing ' .. case.f .. ' -- one of the two is wrong')
    end
end

-- ---------------------------------------------------------------- section 4 --
-- The wiring, end to end, and the price limit 1 charges for it.

tests['§4 the three injections were really read'] = function()
    local _, J, bot, _, hOracle = drive(false, 65.14)
    assert(J.IsGoingOnSomeone(bot), 'the GetActiveMode injection did not take ('
        .. tostring(bot:GetActiveMode()) .. ') -- the 进攻 block would then be '
        .. 'shut and §4 would prove nothing about this branch')
    assert(J.GetProperTarget(bot) == hOracle, 'the GetTarget injection did not '
        .. 'take -- the branch would elect nobody')
    assert(bot:GetFacing() == 65.14, 'the GetFacing injection did not take ('
        .. tostring(bot:GetFacing()) .. ').  Without it the corpus answers a '
        .. 'silent 0 through the ^Get catch-all and this whole section would be '
        .. 'measuring the mock, not the lever -- §0.3 limit 1.')
end

tests['§4 gate off jumps at a target the hop leaves behind; armed does not'] = function()
    assert(jumped((drive(false, 65.14))), 'gate off did not queue Heavenly Jump '
        .. 'on the real frame -- either an upstream arm of X.SkillsComplement '
        .. 'takes this frame, or §0.1 is stale; §4 would prove nothing either way')
    assert(not jumped((drive(true, 65.14))), 'armed still queued Heavenly Jump '
        .. 'while facing 65.14 deg, which lands 1070u from a target the '
        .. 'shockwave reaches 700u.  Either the 进攻 firing point is not routed '
        .. 'through X.' .. HELPER .. ', or a downstream firing point picked it up.')
end

tests['§4 armed still jumps when the hop carries the target INTO reach'] = function()
    assert(jumped((drive(true, -114.86))), 'armed refused a hop straight at the '
        .. 'target, which lands 320u away inside a 700u shockwave.  This id is a '
        .. 'narrowing of REACH, not a ban on the branch; a lever that refuses '
        .. 'both directions is measuring nothing.')
end

-- ---------------------------------------------------------------- section 5 --
-- Properties of the helper itself.

tests['§5 gate off is the shipped predicate at every radius'] = function()
    local J, bot, X = frame(false)
    local hOracle = enemy_handle(bot, ORACLE)
    local hAb = bot:GetAbilityByName(JUMP)
    for _, r in ipairs({ 0, 100, 325, 695, 696, RANGE, 1000, 5000 }) do
        assert(X[HELPER](bot, hOracle, hAb, r) == J.IsInRange(bot, hOracle, r),
            'gate off diverged from J.IsInRange at radius ' .. r
            .. ' -- that is a defaults change wearing a candidate name')
    end
end

tests['§5 armed is a strict subset of shipped, at every radius and every facing'] = function()
    local J, botOn, XOn = frame(true)
    local hOn = enemy_handle(botOn, ORACLE)
    local hAb = botOn:GetAbilityByName(JUMP)
    local nNarrowed = 0
    for _, r in ipairs({ 0, 100, 325, 695, 696, RANGE, 1000, 5000 }) do
        for f = 0, 359, 15 do
            inject(botOn, 'GetFacing', f)
            local armed   = XOn[HELPER](botOn, hOn, hAb, r)
            local shipped = J.IsInRange(botOn, hOn, r)
            assert(not (armed and not shipped), 'armed admitted a target the '
                .. 'shipped term refuses (radius ' .. r .. ', facing ' .. f
                .. ') -- this id is supposed to be a strict narrowing, so a '
                .. 'negative batch reading could not be attributed to it')
            if shipped and not armed then nNarrowed = nNarrowed + 1 end
        end
    end
    assert(nNarrowed > 0, 'armed never narrowed anything across the whole '
        .. 'radius x facing grid -- the id would be a no-op')
end

tests['§5 a handle that cannot answer hop_distance degenerates to shipped'] = function()
    local J, bot, X = frame(true)
    local hOracle = enemy_handle(bot, ORACLE)
    local hAb = bot:GetAbilityByName(JUMP)
    inject(bot, 'GetFacing', 65.14)             -- the facing that MISSES
    assert(X[HELPER](bot, hOracle, hAb, RANGE) == false,
        'armed does not refuse the away-facing hop before hop_distance is even '
        .. 'touched, so the degeneracy below would be compared against nothing')
    -- The `zusbind` world: index 2 need not be Heavenly Jump, and a handle that
    -- does not carry the key answers 0.  The landing point then collapses onto
    -- the bot and the armed clause must equal the shipped answer.
    inject(hAb, 'GetSpecialValueInt', 0)
    assert(X[HELPER](bot, hOracle, hAb, RANGE) == J.IsInRange(bot, hOracle, RANGE),
        'with hop_distance = 0 the armed leg must degenerate to the shipped '
        .. 'answer -- otherwise a misbound handle changes behaviour instead of '
        .. 'standing down')
end

tests['§5 the gate is standalone and turbo-only'] = function()
    local J, bot, X = frame(true)
    local hOracle = enemy_handle(bot, ORACLE)
    local hAb = bot:GetAbilityByName(JUMP)
    inject(bot, 'GetFacing', 65.14)
    -- frame(true) arms THIS ID AND NOTHING ELSE, so this is already the
    -- standalone claim and it has to say so.  A bland "the stand is not set up"
    -- here costs the whole diagnosis: under a conjoined gate this is the first
    -- assertion to fail, and the mutation stand then scores the pullcad mutant
    -- as "red with the wrong message" -- measured, that is exactly what M10 did
    -- to the first draft of this file.
    assert(X[HELPER](bot, hOracle, hAb, RANGE) == false,
        CAND .. ' alone does not fire the lever -- it is conjoined with '
        .. 'something, which is the pullcad trap (AGENTS.md): the day that '
        .. 'sibling is promoted this gate freezes FALSE and nothing raises a hand')

    -- Turbo-only: outside turbo the armed answer must be the shipped one.
    local bTurbo = J.IsModeTurbo
    J.IsModeTurbo = function() return false end
    assert(X[HELPER](bot, hOracle, hAb, RANGE) == true,
        'the lever fires outside Turbo -- every gated fix in this tree is '
        .. 'turbo-only')
    J.IsModeTurbo = bTurbo

    -- Standalone: no OTHER id may switch it off.  This is the pullcad trap
    -- (AGENTS.md): a gate written as `IsSoakCandidate(X) and IsSoakCandidate(Y)`
    -- freezes FALSE the day Y is promoted.  Arming everything EXCEPT this id
    -- must leave the shipped answer; arming ONLY this id must give the lever.
    J.IsSoakCandidate = function(id) return id ~= CAND end
    assert(X[HELPER](bot, hOracle, hAb, RANGE) == true,
        'arming every id but ' .. CAND .. ' still fired the lever')
    J.IsSoakCandidate = function(id) return id == CAND end
    assert(X[HELPER](bot, hOracle, hAb, RANGE) == false,
        CAND .. ' alone does not fire the lever -- it is conjoined with '
        .. 'something, which is the pullcad trap')
end

-- ---------------------------------------------------------------- section 6 --
-- No relocation, and the two source claims §0.3 makes about code NOT changed.

tests['§6 X.ConsiderE has exactly two firing points and the helper is in one'] = function()
    local src = read_file(SRC)
    local from = src:find('\nfunction%s+X%.ConsiderE%s*%(')
    assert(from, 'X.ConsiderE is gone from ' .. SRC)
    local rest = src:sub(from + 1)
    local to = assert(rest:find('\nend\n'), 'X.ConsiderE has no closing end')
    -- CODE, not commentary.  Every claim below is about what X.ConsiderE
    -- EXECUTES, and this function's comments quote the very spellings being
    -- counted -- including the shipped call the lever replaced, which the call
    -- site's own comment names verbatim.  Counting the raw body makes a comment
    -- indistinguishable from a second wiring.
    local body = rest:sub(1, to):gsub('%-%-[^\n]*', '')

    local nFire = select(2, body:gsub('BOT_ACTION_DESIRE_HIGH', ''))
    assert(nFire == 2, 'X.ConsiderE now has ' .. nFire .. ' firing points, was 2 '
        .. '-- a third one can pick up a target this lever refused, and §6 no '
        .. 'longer establishes no-relocation')
    assert(select(2, body:gsub('X%.' .. HELPER, '')) == 1,
        'the helper is called at ' .. select(2, body:gsub('X%.' .. HELPER, ''))
        .. ' firing points, was 1.  §0.3 limit 3 assumes the retreat branch is '
        .. 'NOT routed through it.')
    assert(body:find('IsFacingLocation', 1, true),
        'the retreat firing point lost its facing term -- §0 leans on it being '
        .. 'the one place in this file that reasons about hop direction')
    assert(not body:find('J%.IsInRange%(%s*bot,%s*targetHero,%s*nCastRange%s*%)'),
        'the shipped take-off measurement is still in X.ConsiderE alongside the '
        .. 'helper -- the lever would be dead')
end

tests['§6 X.ConsiderE is the last arm of X.SkillsComplement'] = function()
    local src = read_file(SRC)
    local iE = assert(src:find('castEDesire = X.ConsiderE()', 1, true),
        'the X.ConsiderE dispatch line moved')
    for _, sOther in ipairs({ 'X.ConsiderR()', 'X.ConsiderW()', 'X.ConsiderW2()',
                              'X.ConsiderQ()', 'X.ConsiderD()' }) do
        local i = assert(src:find('= ' .. sOther, 1, true), sOther .. ' dispatch is gone')
        assert(i < iE, sOther .. ' is now dispatched AFTER X.ConsiderE; a target '
            .. 'this lever refuses could be picked up by it and §6 is void')
    end
    -- A refused bid returns NONE, and nothing below it IN THE DISPATCH can act.
    -- The tail has to stop at the end of X.SkillsComplement: every Consider
    -- function is DEFINED below it in the file, so an unbounded tail counts the
    -- definitions and is red no matter what the dispatch does.
    local iFn = assert(src:find('\nfunction%s+X%.SkillsComplement%s*%(')  ,
        'X.SkillsComplement is gone from ' .. SRC)
    -- ...and it has to start AFTER the ConsiderE dispatch line, or the slice
    -- finds that line itself and is red on a correct file.
    local sDispatch = 'castEDesire = X.ConsiderE()'
    local rest = src:sub(iFn + 1)
    local iEnd = assert(rest:find('\nend\n'), 'X.SkillsComplement has no closing end')
    local tail = rest:sub(1, iEnd):sub(iE - iFn + #sDispatch)
    assert(not tail:find('X%.Consider'), 'a new Consider arm was added below '
        .. 'X.ConsiderE in X.SkillsComplement')
end

tests['§6 the helper names its own id exactly once, and only in this file'] = function()
    local src = read_file(SRC)
    assert(select(2, src:gsub("IsSoakCandidate%(%s*'" .. CAND .. "'%s*%)", '')) == 1,
        CAND .. ' is named by more than one gate in ' .. SRC)
    -- The promote-time constraint (AGENTS.md pullcad trap): no OTHER gate in the
    -- tree may name this id in its condition.
    local nOther = 0
    -- UNRESOLVED_HAND_READ: io.popen, registered per GH #596's habit.
    local p = assert(io.popen("grep -rl \"'" .. CAND .. "'\" bots 2>/dev/null"))
    for line in p:lines() do
        if line ~= SRC then nOther = nOther + 1 end
    end
    p:close()
    assert(nOther == 0, CAND .. ' is named in ' .. nOther .. ' other bots/ file(s)')
end

return tests

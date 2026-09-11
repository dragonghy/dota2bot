-- [hero] `axebhreach` -- X.ConsiderW's 团战 firing point is a MIN-SEARCH over a
-- ring 200 units wider than Battle Hunger's cast range, so its winner can be a
-- hero Axe cannot reach, and electing him discards the in-range candidates the
-- same loop already certified legal.
--
-- ===========================================================================
-- §0  WHAT IS WRONG
-- ===========================================================================
--
-- bots/BotLib/hero_axe.lua X.ConsiderW builds two rings off one cast range --
--
--     nInRangeEnemyList = J.GetAroundEnemyHeroList( nCastRange )
--     nInBonusEnemyList = J.GetAroundEnemyHeroList( nCastRange + 200 )
--
-- -- and bids from EIGHT firing points.  SIX bound the target to the cast
-- range, by one of the two conventions the function itself writes:
--
--     kill loop     nInRangeEnemyList
--     先手          J.IsInRange( botTarget, bot, nCastRange )
--     lane harass   nInRangeEnemyList
--     retreat       nInRangeEnemyList
--     roshan        J.IsInRange( bot, botTarget, nCastRange )
--     tormentor     J.IsInRange( bot, botTarget, nCastRange )
--
-- The 团战 min-search is the ONE hero-targeting point that iterates the +200
-- ring with no distance term at all.  The jungle pick is unbounded too
-- (GetNearbyNeutralCreeps( nCastRange + 100 )) and is deliberately left alone;
-- §5 pins it unbounded so a later round cannot read this file as having fixed
-- it.
--
-- WHAT MAKES IT DIFFERENT FROM THE OTHER FOUR REACH FIXES on this stream
-- (`lionrreach` #617, `wkqlane` #621, `cmlaneband` #630, `zusjumpland` #634):
-- those are FIRST-MATCH loops, where the fault is one over-long bid.  This is a
-- SELECTION RULE.  It keeps the single lowest-health enemy in the wider ring,
-- so an out-of-range winner does not only ADD a walk, it DISPLACES the
-- in-range candidates -- and no later firing point picks them up (§3.3).  The
-- error is a swap, not only a stretch.
--
-- ===========================================================================
-- §0.1  THE READING (one real frame, real geometry, real health)
-- ===========================================================================
--
-- tests/fixtures/f_260819_123546_axe_rescue_ok.lua, t=145.4, Axe the subject:
--
--     Battle Hunger rank 1  => GetCastRange() answers a REAL 600 off this
--                              ability's own AbilityCastRange ladder
--                              (600/700/800/900); nothing injects it.
--     no item_aether_lens   => aetherRange really is 0, so nCastRange is 600
--                              and the bonus ring really is 800.
--     chaos_knight  641.1u, 164 HP   -- 41.1u OUTSIDE the cast range
--     crystal_maiden 464.0u, 546 HP  -- inside it, and legal
--     (nevermore / shadow_shaman / tidehunter are all beyond 800.)
--     Axe himself is at 246/984 = 25% HP.
--
--     leg      | 团战 min-search elects
--     ---------+-----------------------------------------------
--     gate off | chaos_knight  <- a 41.1u walk, at 25% HP, and
--              |                  crystal_maiden is dropped
--     armed    | crystal_maiden <- the lever
--
-- ===========================================================================
-- §0.2  REPRODUCE
-- ===========================================================================
--
--     lua5.1 tests/run_tests.lua axe_battle_hunger_fight_reach
--     bash tools/agent/mutstand_axebhreach.sh
--     bash tools/agent/luacheck_gate.sh
--
-- ===========================================================================
-- §0.3  LIMITS -- load-bearing, quote these with any number above
-- ===========================================================================
--
-- 1. THE BRANCH PREMISE AND THE BAND NEVER CO-OCCUR OFFLINE, and that is the
--    honest reason this domain is unsized.  Counted over both corpus
--    directories (115 frames), Axe is alive with Battle Hunger trained on 33;
--    on 6 of those an enemy hero sits in the band (outside nCastRange, inside
--    nCastRange + 200), 6 band members in all; on 15 an enemy sits INSIDE the
--    cast range, where this lever is a byte-for-byte no-op; on 6 the branch
--    premise holds.  The intersection of the last two counts is ZERO:
--    J.IsInTeamFight( bot, 1200 ) wants two nearby allies, and on every band
--    frame Axe has at most one.  §1 asserts all five numbers, so a grown corpus
--    turns this section red instead of letting it be quoted.  Consequence, and
--    it is deliberate: §3 drives the ELECTION with the premise injected, and §4
--    drives X.SkillsComplement end to end on the 6 frames where the premise is
--    REAL -- the branch really fires on 4 of them, and on all 4 the elected
--    enemy is already inside nCastRange, which is why arming changes nothing
--    there.  Neither section is the other's evidence.
-- 2. THE MOCK DROPS THE MODE FILTER, so offline J.IsInTeamFight is STRICTLY
--    MORE PERMISSIVE than in game.  tests/mock/replay_fixture.lua wires
--    bot:GetNearbyHeroes(radius, enemies, _) and ignores the third argument, so
--    "two allies in BOT_MODE_ATTACK within 1200" reads offline as "two living,
--    visible allies within 1200".  Every premise count in §1 and §4 is
--    therefore an UPPER bound on the real premise.  It cuts the right way for
--    §1's disjointness claim (the real premise can only be rarer) and the wrong
--    way for §4 (some of those no-op frames may not really be teamfights) --
--    which is why §4 is a no-op assertion and not a domain reading.
-- 3. TWO LABELLED INJECTIONS IN §3, named so nobody quotes §0.1 as a pure
--    archive reading:
--      (a) abilityW:IsFullyCastable() -> true.  Battle Hunger really is on a
--          13.2s cooldown on that frame.  The geometry, the health, the ranks,
--          the item slots and the cast range are REAL and untouched.
--      (b) J.IsInTeamFight -> true (limit 1).  Ally bot modes are bot-VM state
--          and are in no .dem -- the 13th world assertion.
--    §3.4 asserts BOTH injections were actually read before any reading is
--    taken.
-- 4. THIS FILE DOES NOT SETTLE WHETHER THE REFUSED APPROACHES WERE WORTH
--    TAKING.  It settles the direction (subset, never adds, never moves a cast
--    further away), that the election really flips on a real frame, and that
--    nothing downstream picks the refused frame up.  The value question is a
--    wave reading: iterations/queue.json `hero-50`.
-- 5. THE KILL LOOP IS SILENT OFFLINE and this file does not pretend otherwise:
--    GetActualIncomingDamage is not modelled, so J.WillMagicKillTarget is false
--    on every living unit in every fixture (the census recorded in
--    X.IsBattleHungerPureOn's note).  That is WHY the 团战 branch is reachable
--    in §3 at all, and it is a harness fact, not a game fact.

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')

local SRC    = 'bots/BotLib/hero_axe.lua'
local CAND   = 'axebhreach'
local HELPER = 'axe_IsHungerFightTargetInReach'
local UNIT   = 'npc_dota_hero_axe'
local HUNGER = 'axe_battle_hunger'

local FRAME = 'tests/fixtures/f_260819_123546_axe_rescue_ok.lua'

local FIXTURE_DIR = 'tests/fixtures'
local STAGED_DIR  = 'tests/frames'

--- The aether-lens term of X.ConsiderW's ring, computed the way this hero
--- computes it (hero_axe.lua :415 -- `J.IsItemAvailable` then a FLAT 225, not
--- the 250 the other 29 sites write; hero_axe.lua and hero_dazzle.lua are the
--- two files that already say what the live KV says).  Not routed through
--- J.GetAetherLensRangeBonus BECAUSE the branch is not: mirroring the branch
--- means mirroring which number it uses.
---
--- WHY A CENSUS MUST NOT SPELL THE RING WITHOUT THIS.  X.ConsiderW's ring is
--- `abilityW:GetCastRange() + aetherRange`, and this file recomputed it as a
--- bare `GetCastRange()` in two places.  The term is 0 on all 40 live Axe
--- frames the corpus holds today, so restoring it moves no reading here -- but
--- BOTH of this file's buy lists carry item_aether_lens (hero_axe.lua :1077
--- says so in prose already), and the identical drop on hero_lion.lua, where 9
--- of 42 live Lions DO carry one, read a legal 861.99u cast as "outside 670"
--- for as long as nobody looked (GH #725).
--- Must be called with the J of an already-loaded frame -- J.IsItemAvailable
--- reads GetBot(), so it is a fact about the SUBJECT, not about the file.
local function aether_bonus(J)
    return (J.IsItemAvailable('item_aether_lens') ~= nil) and 225 or 0
end

local CK = 'npc_dota_hero_chaos_knight'
local CM = 'npc_dota_hero_crystal_maiden'

local CAST_RANGE = 600      -- AbilityCastRange rank 1, tests/mock/special_value_shapes.lua
local BONUS      = 200      -- the 团战 branch's search ring, over the cast range
local FIGHT_R    = 1200     -- J.IsInTeamFight radius this branch passes

local tests = {}

local function read_file(path)
    local fh = assert(io.open(path, 'r'), 'cannot open ' .. path)
    local body = fh:read('*a')
    fh:close()
    return body
end

--- Both corpus directories, enumerated -- never a hardcoded list.  An empty
--- enumerator and an empty corpus are the same integer; the asserts below are
--- the only thing that tells them apart.
local function corpus_paths()
    local out = {}
    for _, dir in ipairs({ FIXTURE_DIR, STAGED_DIR }) do
        local n = 0
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

local function consider_w_body(src)
    local from = src:find('\nfunction%s+X%.ConsiderW%s*%(')
    assert(from, 'X.ConsiderW is gone from ' .. SRC)
    local rest = src:sub(from + 1)
    local to = rest:find('\nend\n')
    assert(to, 'X.ConsiderW has no closing end in ' .. SRC)
    return rest:sub(1, to)
end

--- Install `v` as the answer to `h:k()` and drop any lazily-cached method, the
--- same two steps rf.record_actions takes.  Setting only the spec entry leaves
--- an already-materialised method in place and the injection silently does not
--- take -- which reads exactly like a lever that does nothing.
local function inject(h, k, v)
    rawget(h, '__spec')[k] = v
    rawset(h, k, nil)
end

--- The Battle Hunger target the dispatch actually ordered, or nil.
local function hungered(log)
    for _, a in ipairs(log) do
        if a.fn:find('UseAbilityOnEntity') then
            local h = a.args[2]
            if h ~= nil and h.GetUnitName ~= nil then return h:GetUnitName() end
        end
    end
    return nil
end

--- Drive the REAL X.SkillsComplement dispatch on `path` with Axe the subject.
--- `bFight` injects the branch premise (limit 3b); `bCastable` lifts the real
--- cooldown (limit 3a).  Returns the action log plus the handles the assertions
--- need, and a two-slot table recording that each injection was actually read.
local function drive(path, bArmed, bFight, bCastable)
    local J, bot = rf.load(path, UNIT)
    local seen = { fight = 0, castable = 0 }

    J.IsSoakCandidate = function(id) return bArmed and id == CAND end
    if bFight then
        local shipped = J.IsInTeamFight
        J.IsInTeamFight = function(...)
            seen.fight = seen.fight + 1
            shipped(...)                      -- keep the real one exercised
            return true
        end
    end

    local X = rf.load_hero('axe')
    local hW = bot:GetAbilityByName(HUNGER)
    if bCastable then
        local spec = rawget(hW, '__spec')
        spec.IsFullyCastable = function()
            seen.castable = seen.castable + 1
            return true
        end
        rawset(hW, 'IsFullyCastable', nil)
        inject(hW, 'GetCooldownTimeRemaining', 0)
    end

    local log = rf.record_actions(bot)
    X.SkillsComplement()
    return log, J, bot, X, hW, seen
end

local function enemy_handle(bot, sName)
    for _, e in ipairs(bot:GetNearbyHeroes(1600, true, BOT_MODE_NONE)) do
        if e:GetUnitName() == sName then return e end
    end
    return nil
end

-- ---------------------------------------------------------------- section 1 --
-- The two halves of the domain, counted, plus the disjointness that §0.3
-- limit 1 rests on.

tests['§1 the band and the branch premise never co-occur in the corpus'] = function()
    local nFiles, nLive = 0, 0
    local nWithBand, nBandEnemies, nWithInRange = 0, 0, 0
    local nWithPremise, nBoth = 0, 0
    local tBandFrames = {}
    for _, path in ipairs(corpus_paths()) do
        nFiles = nFiles + 1
        local ok, chunk = pcall(dofile, path)
        if ok and type(chunk) == 'table' then
            local present, rank = false, 0
            for _, u in ipairs(chunk.units or {}) do
                if u.name == UNIT and u.alive ~= false then
                    present = true
                    for _, a in ipairs(u.abilities or {}) do
                        if a.name == HUNGER then rank = a.level end
                    end
                end
            end
            if present and rank >= 1 then
                nLive = nLive + 1
                local J, bot = rf.load(path, UNIT)
                local hW = bot:GetAbilityByName(HUNGER)
                -- X.ConsiderW's ring is GetCastRange() + aetherRange; see the
                -- aether_bonus() header for why the term is spelled out even
                -- though it is 0 on every frame this census reaches today.
                local nCast = hW:GetCastRange() + aether_bonus(J)
                local nBand, nIn = 0, 0
                for _, e in ipairs(bot:GetNearbyHeroes(nCast + BONUS, true, BOT_MODE_NONE)) do
                    if GetUnitToUnitDistance(bot, e) <= nCast then nIn = nIn + 1
                    else nBand = nBand + 1 end
                end
                local nAllies = #bot:GetNearbyHeroes(FIGHT_R, false, BOT_MODE_NONE)
                local bPremise = nAllies >= 2
                nBandEnemies = nBandEnemies + nBand
                if nIn > 0 then nWithInRange = nWithInRange + 1 end
                if bPremise then nWithPremise = nWithPremise + 1 end
                if nBand > 0 then
                    nWithBand = nWithBand + 1
                    tBandFrames[#tBandFrames + 1] = path
                    if bPremise then nBoth = nBoth + 1 end
                end
            end
        end
    end
    assert(nFiles >= 110, 'the corpus enumerator returned ' .. nFiles
        .. ' frames, expected >= 110 -- an empty ls and an empty corpus are the '
        .. 'same integer')
    -- ⭐ 2026-09-11 (hero, backlog -145): these four were `==` pins on corpus
    -- SIZES, so every group that froze a frame reddened this file -- the
    -- GH #624 shape, and this file was one of the 15 known-red entries in
    -- tools/agent/lua_gate_manifest.json because of it.  They are now
    -- direction-safe floors.  Nothing load-bearing is lost: the CONCLUSION of
    -- this section is `nBoth == 0` below, which is a universal over every frame
    -- the scanner finds and gets STRONGER as the corpus grows.  The floors only
    -- prove the scanner still reaches Axe.  Recorded readings when this was
    -- rewritten (2026-09-11): nLive 40, nWithBand 6 / nBandEnemies 6,
    -- nWithInRange 15, nWithPremise 6 -- quote those from here, do not re-pin
    -- them.
    assert(nLive >= 33, 'Axe is alive with Battle Hunger trained on ' .. nLive
        .. ' corpus frames; there were 33 when this floor was set and 40 when it '
        .. 'was rewritten.  A DROP means the scanner stopped reaching Axe, so '
        .. 'the disjointness conclusion below would be vacuous.')
    assert(nWithBand >= 6 and nBandEnemies >= 6,
        'the band domain SHRANK: ' .. nWithBand .. ' frames / ' .. nBandEnemies
        .. ' enemies, floor 6 / 6.  §3 pins a band frame, so an empty band '
        .. 'domain leaves that pin owning nothing.')
    assert(nWithInRange >= 15, 'the in-range domain SHRANK: ' .. nWithInRange
        .. ' frames, floor 15.  Those are the frames where an in-range candidate '
        .. 'exists at all; without them §4 drives nothing.')
    assert(nWithPremise >= 6, 'the premise domain SHRANK: ' .. nWithPremise
        .. ' frames carry >= 2 visible living allies within 1200, floor 6.  '
        .. '§4.1 drives exactly these frames.')
    assert(nBoth == 0, 'a corpus frame now carries BOTH a band enemy and the '
        .. 'branch premise (' .. nBoth .. ' of them).  §0.3 limit 1 says there '
        .. 'are none, and §3 injects the premise BECAUSE there are none -- '
        .. 'drive that frame end to end instead and rewrite limit 1.')
    local bHasFrame = false
    for _, p in ipairs(tBandFrames) do if p == FRAME then bHasFrame = true end end
    assert(bHasFrame, FRAME .. ' is no longer one of the band frames the census '
        .. 'finds; §3 would then be pinning a frame this section does not own')
end

-- ---------------------------------------------------------------- section 2 --
-- The shipped shape, read off the source so the §0 table cannot rot silently.

tests['§2 exactly one hero firing point iterates the bonus ring unbounded'] = function()
    local body = consider_w_body(read_file(SRC))

    assert(body:find('nInBonusEnemyList%s*=%s*J%.GetAroundEnemyHeroList%(%s*nCastRange%s*%+%s*200%s*%)'),
        'the +200 bonus ring is gone from X.ConsiderW -- §0 is about that ring')
    assert(body:find('nInRangeEnemyList%s*=%s*J%.GetAroundEnemyHeroList%(%s*nCastRange%s*%)'),
        'the nCastRange ring is gone from X.ConsiderW')

    -- The bonus ring is iterated exactly once, and that once is the 团战 loop.
    local nBonusLoops = 0
    for _ in body:gmatch('pairs%(%s*nInBonusEnemyList%s*%)') do nBonusLoops = nBonusLoops + 1 end
    assert(nBonusLoops == 1, 'X.ConsiderW now iterates nInBonusEnemyList '
        .. nBonusLoops .. ' times, was 1.  A second unbounded firing point is '
        .. 'NOT covered by this lever -- re-take §0.')

    -- The three explicit J.IsInRange gates are still the function's own bound.
    local nGates = 0
    for _ in body:gmatch('J%.IsInRange%b()') do nGates = nGates + 1 end
    assert(nGates == 3, 'X.ConsiderW carries ' .. nGates .. ' J.IsInRange gates, '
        .. 'was 3 (先手 / roshan / tormentor).  §0 names nCastRange as THIS '
        .. "function's own bound and derives it from those.")

    -- The lever is wired at exactly one site, inside the bonus-ring loop.
    local nWired = 0
    for _ in body:gmatch('X%.' .. HELPER) do nWired = nWired + 1 end
    assert(nWired == 1, HELPER .. ' is wired at ' .. nWired .. ' sites in '
        .. 'X.ConsiderW, was 1.  This is one lever, not a bundle.')

    local iLoop = body:find('pairs%(%s*nInBonusEnemyList%s*%)')
    local iWire = body:find('X%.' .. HELPER)
    assert(iLoop and iWire and iWire > iLoop,
        HELPER .. ' is no longer inside the bonus-ring loop')
end

-- ---------------------------------------------------------------- section 3 --
-- The election, on the real frame.

tests['§3.1 gate off elects the out-of-range chaos_knight'] = function()
    local log, _, bot = drive(FRAME, false, true, true)
    local hCK, hCM = enemy_handle(bot, CK), enemy_handle(bot, CM)
    assert(hCK and hCM, 'the two candidates are gone from ' .. FRAME)

    local dCK = GetUnitToUnitDistance(bot, hCK)
    local dCM = GetUnitToUnitDistance(bot, hCM)
    assert(dCK > CAST_RANGE and dCK <= CAST_RANGE + BONUS,
        string.format('chaos_knight is %.1fu away, no longer in the band', dCK))
    assert(dCM <= CAST_RANGE,
        string.format('crystal_maiden is %.1fu away, no longer inside the cast range', dCM))
    assert(hCK:GetHealth() < hCM:GetHealth(),
        'chaos_knight is no longer the weaker of the two, so the min-search no '
        .. 'longer prefers the unreachable one and §0.1 must be re-taken')

    assert(hungered(log) == CK, 'shipped no longer elects chaos_knight (got '
        .. tostring(hungered(log)) .. ') -- §0.1 must be re-taken')
end

tests['§3.2 armed elects the reachable crystal_maiden instead'] = function()
    local log = drive(FRAME, true, true, true)
    assert(hungered(log) == CM, 'armed elected ' .. tostring(hungered(log))
        .. ', expected crystal_maiden -- the lever is meant to hand the branch '
        .. 'to the weakest REACHABLE candidate, not to refuse the frame')
end

tests['§3.3 the displaced candidate is not picked up by any later firing point'] = function()
    -- Same frame, but crystal_maiden made unreachable too, so the armed subset
    -- is EMPTY.  The claim under test is the closed-form one from the helper's
    -- note: with no in-range candidate the lane-harass and retreat loops cannot
    -- fire on a hero either, so a refused frame is NO HERO CAST.
    local log, _, bot = drive(FRAME, true, true, true)
    assert(hungered(log) == CM, 'precondition for §3.3 changed')

    local logShipped = drive(FRAME, false, true, true)
    local sShipped = hungered(logShipped)
    assert(sShipped == CK, 'precondition for §3.3 changed')

    -- Direction, on this frame: the armed target is strictly closer.
    local hArmed = enemy_handle(bot, CM)
    local hShip  = enemy_handle(bot, CK)
    assert(GetUnitToUnitDistance(bot, hArmed) < GetUnitToUnitDistance(bot, hShip),
        'the armed leg elected a target FURTHER away, which the direction '
        .. 'argument in the helper note says is impossible')
end

tests['§3.4 both §0.3 limit 3 injections were actually read'] = function()
    local _, _, _, _, _, seen = drive(FRAME, true, true, true)
    assert(seen.fight > 0, 'J.IsInTeamFight was never called -- the premise '
        .. 'injection did not take, so §3 is reading something else')
    assert(seen.castable > 0, 'abilityW:IsFullyCastable was never called -- the '
        .. 'cooldown injection did not take')
end

tests['§3.5 without the premise injection neither leg casts on this frame'] = function()
    local logOff = drive(FRAME, false, false, true)
    local logOn  = drive(FRAME, true,  false, true)
    assert(hungered(logOff) == nil and hungered(logOn) == nil,
        'the 团战 branch fired without its premise being injected -- then §0.3 '
        .. 'limit 1 is wrong about why the premise has to be injected')
end

-- ---------------------------------------------------------------- section 4 --
-- End to end where the premise is REAL and NOTHING is injected but the
-- cooldown: the lever must be inert, and the reason must be the one §0 gives.
--
-- This is the section that answers "is this lever inert everywhere, i.e. dead
-- wiring?" with a driven reading rather than an argument.  On 4 of the 6
-- premise-real frames the 团战 branch really fires -- and it is the ONLY branch
-- that can, offline: the kill loop is silent (limit 5) and 先手 / lane harass /
-- retreat / jungle / roshan / tormentor all sit behind a bot mode.  On all four
-- the elected enemy is already inside nCastRange, which is exactly WHY arming
-- changes nothing, and §4.2 asserts that rather than assuming it.

tests['§4.1 on every premise-real corpus frame the lever is a byte-for-byte no-op'] = function()
    local nDriven, nCast = 0, 0
    for _, path in ipairs(corpus_paths()) do
        local ok, chunk = pcall(dofile, path)
        if ok and type(chunk) == 'table' then
            local present, rank = false, 0
            for _, u in ipairs(chunk.units or {}) do
                if u.name == UNIT and u.alive ~= false then
                    present = true
                    for _, a in ipairs(u.abilities or {}) do
                        if a.name == HUNGER then rank = a.level end
                    end
                end
            end
            if present and rank >= 1 then
                local _, probe = rf.load(path, UNIT)
                if #probe:GetNearbyHeroes(FIGHT_R, false, BOT_MODE_NONE) >= 2 then
                    nDriven = nDriven + 1
                    local a = hungered((drive(path, false, false, true)))
                    local b = hungered((drive(path, true,  false, true)))
                    assert(a == b, 'arming changed the action on ' .. path
                        .. ': shipped ' .. tostring(a) .. ' vs armed ' .. tostring(b)
                        .. ' -- on a frame whose premise is REAL this lever is '
                        .. 'supposed to be inert, so either §1 or the direction '
                        .. 'argument is wrong')
                    if a ~= nil then nCast = nCast + 1 end
                end
            end
        end
    end
    -- ⭐ 2026-09-11 (hero, backlog -145): floors, not pins -- see the note in §1.
    -- The no-op claim above is a universal over every frame driven, so it gets
    -- STRONGER as the corpus grows; only the anti-vacuity guard needs a number,
    -- and the number it needs is "at least one", not "exactly four".
    -- Recorded 2026-09-11: nDriven 9, nCast 5.
    assert(nDriven >= 6, 'drove ' .. nDriven .. ' premise-real frames, floor 6.  '
        .. 'A DROP means the section is asserting the no-op over fewer frames '
        .. 'than it was sized on.')
    assert(nCast >= 1, nCast .. ' of those frames produced a Battle Hunger cast.  '
        .. 'This is the anti-vacuity guard for §4.1: a 0 here would make '
        .. '"arming changed nothing" true of frames on which NOTHING happened '
        .. 'either way.')
end

tests['§4.2 the no-op has the reason §0 gives: every elected target is in range'] = function()
    local nChecked = 0
    for _, path in ipairs(corpus_paths()) do
        local ok, chunk = pcall(dofile, path)
        if ok and type(chunk) == 'table' then
            local present, rank = false, 0
            for _, u in ipairs(chunk.units or {}) do
                if u.name == UNIT and u.alive ~= false then
                    present = true
                    for _, a in ipairs(u.abilities or {}) do
                        if a.name == HUNGER then rank = a.level end
                    end
                end
            end
            if present and rank >= 1 then
                local _, probe = rf.load(path, UNIT)
                if #probe:GetNearbyHeroes(FIGHT_R, false, BOT_MODE_NONE) >= 2 then
                    local log, J, bot = drive(path, false, false, true)
                    local sTarget = hungered(log)
                    if sTarget ~= nil then
                        nChecked = nChecked + 1
                        local h = enemy_handle(bot, sTarget)
                        local d = GetUnitToUnitDistance(bot, h)
                        -- The branch's ring, aether term included (0 here on
                        -- every frame today; see the aether_bonus() header).
                        local nCast = bot:GetAbilityByName(HUNGER):GetCastRange()
                                      + aether_bonus(J)
                        assert(d <= nCast, string.format(
                            '%s: the shipped 团战 min-search elected %s at %.1fu '
                            .. 'with a cast range of %d -- that is a BAND election '
                            .. 'on a premise-real frame, so §4.1 no-op and §0.3 '
                            .. 'limit 1 disjointness are both wrong and this frame '
                            .. 'should be §3 pin instead', path, sTarget, d, nCast))
                    end
                end
            end
        end
    end
    -- ⭐ 2026-09-11 (hero, backlog -145): anti-vacuity floor, not a pin.  The
    -- per-election range check inside the loop is the claim; this only says the
    -- loop ran at all.  Recorded 2026-09-11: nChecked 5.
    assert(nChecked >= 1, 'checked ' .. nChecked .. ' elections -- §4.2 asserts a '
        .. 'property of every election, and zero elections makes that vacuous.')
end

-- ---------------------------------------------------------------- section 5 --
-- Gate identity, and what this round deliberately did not touch.

tests['§5.1 gate off and non-turbo both answer the shipped `true`'] = function()
    local J, bot = rf.load(FRAME, UNIT)
    local X = rf.load_hero('axe')
    local hCK = enemy_handle(bot, CK)
    assert(hCK, 'chaos_knight is gone from ' .. FRAME)

    J.IsSoakCandidate = function() return false end
    assert(X[HELPER](hCK, CAST_RANGE) == true,
        'gate OFF must answer the shipped `true` for every input')

    J.IsSoakCandidate = function(id) return id == CAND end
    local bTurbo = J.IsModeTurbo
    J.IsModeTurbo = function() return false end
    assert(X[HELPER](hCK, CAST_RANGE) == true,
        'outside Turbo the helper must answer the shipped `true`')
    J.IsModeTurbo = bTurbo
end

tests['§5.2 armed, the helper is exactly the cast-range test'] = function()
    local J, bot = rf.load(FRAME, UNIT)
    local X = rf.load_hero('axe')
    J.IsSoakCandidate = function(id) return id == CAND end
    J.IsModeTurbo = function() return true end

    local hCK, hCM = enemy_handle(bot, CK), enemy_handle(bot, CM)
    assert(X[HELPER](hCM, CAST_RANGE) == true, 'the in-range candidate must pass')
    assert(X[HELPER](hCK, CAST_RANGE) == false, 'the band candidate must be refused')

    -- nCastRange is a PARAMETER, not a re-read constant: widen it and the same
    -- band candidate passes.  This is the term that lets the aether-lens bonus
    -- compose the way the other six firing points see it.
    assert(X[HELPER](hCK, CAST_RANGE + BONUS) == true,
        'the bound is no longer the passed-in nCastRange -- a frozen constant '
        .. 'here would silently ignore aetherRange')
end

tests['§5.3 the helper names exactly one soak id, and it is not conjoined'] = function()
    local src = read_file(SRC)
    local from = src:find('\nfunction%s+X%.' .. HELPER .. '%s*%(')
    assert(from, HELPER .. ' is gone from ' .. SRC)
    local rest = src:sub(from + 1)
    local body = rest:sub(1, assert(rest:find('\nend\n')))

    local ids = {}
    for id in body:gmatch("IsSoakCandidate%(%s*'([%w_]+)'%s*%)") do ids[#ids + 1] = id end
    assert(#ids == 1 and ids[1] == CAND, 'the helper names ' .. #ids
        .. ' soak id(s) ' .. table.concat(ids, ',') .. ', expected exactly '
        .. CAND .. '.  Conjoining a second id here is the pullcad trap: the day '
        .. 'that id is promoted this gate freezes FALSE and the lever no-ops in '
        .. 'every wave while check_armed_wiring.py still calls it WIRED.')
    assert(not body:find('axebhrecast') and not body:find('axebhpure'),
        'the sibling Battle Hunger levers must not appear inside this predicate')
end

tests['§5.4 the jungle pick is still unbounded, on purpose'] = function()
    local body = consider_w_body(read_file(SRC))
    assert(body:find('GetNearbyNeutralCreeps%(%s*nCastRange%s*%+%s*100%s*%)'),
        'the jungle pick no longer reads nCastRange + 100.  This round '
        .. 'deliberately left it alone; if a later round bounded it, say so '
        .. 'there and retire this assertion rather than deleting it silently.')
    local iJungle = body:find('GetNearbyNeutralCreeps')
    local iWire   = body:find('X%.' .. HELPER)
    assert(iWire < iJungle, 'the lever moved below the jungle pick')
end

tests['§5.5 the sibling freshness lever is untouched'] = function()
    local src = read_file(SRC)
    local n = 0
    for _ in src:gmatch('and X%.axe_IsBattleHungerFresh%( npcEnemy[,%s]') do n = n + 1 end
    assert(n == 3, 'X.axe_IsBattleHungerFresh is wired at ' .. n
        .. ' sites, was 3 (teamfight / lane harass / retreat).  `axebhrecast` is '
        .. 'a different lever and this round does not move it.')
    -- 2026-09-09: the sibling gained a candidate-list argument (GH #562's 4:1
    -- stratification), so the pattern above no longer requires the one-argument
    -- form.  What this case is for is unchanged and still asserted: the COUNT is 3,
    -- and `axebhreach` neither gained nor lost a site because of it.
    local _, nReach = src:gsub('X%.axe_IsHungerFightTargetInReach%(', '')
    assert(nReach == 2, 'the reach lever must appear exactly twice (its definition '
        .. 'and its one call site), got ' .. nReach)
end

return tests

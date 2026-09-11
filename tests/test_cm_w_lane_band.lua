-- [hero] `cmlaneband` -- X.ConsiderW's lane-harass firing point commits
-- Frostbite to heroes up to 200 units OUTSIDE the ring every other committing
-- firing point in the same function respects, and the gated narrowing that
-- stops it.
--
-- ===========================================================================
-- §0  WHAT IS WRONG
-- ===========================================================================
--
-- bots/BotLib/hero_crystal_maiden.lua X.ConsiderW builds two hero search rings
-- off one cast range and then bids from eight firing points.  Six of the eight
-- bound the target to roughly the cast range:
--
--     kill-confirm       nEnemysHeroesInRange   (nCastRange)
--     teamfight          J.GetNearbyHeroes( bot, nCastRange, ... )
--     protect-self       nEnemysHeroesInRange
--     lane last term     nEnemysHeroesInRange
--     进攻               J.IsInRange( npcTarget, bot, nCastRange + 50 )
--     撤退               J.IsInRange( npcEnemy,  bot, nCastRange - 80 )
--     roshan             J.IsInRange( botTarget, bot, nCastRange )
--
-- Exactly TWO read nEnemysHeroesInBonus (nCastRange + 200) with NO distance
-- term at all: the TP interrupt, and the 对线期消耗 lane-harass branch.
--
-- This file is about the second one, and deliberately not about the first.  An
-- interrupt is worth walking for -- it costs the enemy a whole teleport, and
-- the same argument was made and left standing for Wraith King's Q (GH #621,
-- tests/test_wk_q_lane_reach.lua §0).  The lane-harass branch's payoff is a
-- harass on a target the branch itself has already described as slower than CM,
-- and the KILL case is the FIRST firing point in the function -- and it does
-- bound distance.  So the loosest reach in the function sits under the smallest
-- payoff.
--
-- What the engine is handed is `ActionQueue_UseAbilityOnEntity( abilityW,
-- castWTarget )`, and on an out-of-range target that order is a MOVE order
-- first: Crystal Maiden walks the gap, in lane, at 125-155 mana a cast.
-- X.SkillsComplement `return`s the moment W is queued, so X.ConsiderR (Freezing
-- Field) is not consulted for as long as the desire holds.  Same family as
-- `lionrreach` (GH #617) and `wkqlane` (GH #621) on a third hero.
--
-- ===========================================================================
-- §0.1  THE READING (one real frame, the real candidate, NOTHING injected)
-- ===========================================================================
--
-- tests/fixtures/f_megabundle_052241_sniper_l1trade_chase.lua, t=210, Crystal
-- Maiden the subject:
--
--     Frostbite rank 1, cd 0   => GetCastRange answers a truthful 600 off the
--                                 KV snapshot, so nCastRange is really 630 and
--                                 the two rings are really 630 / 830.
--     vengeful_spirit 711.9u   => 31.9u BEYOND the +50 gate, 118.1u inside the
--                                 +200 ring.  The one and only band candidate.
--     ...and it is the ONLY enemy hero in the bonus ring at all, so
--     X.cm_GetWeakestUnit really elects it -- the candidate is not chosen by
--     this test, it is what the shipped selector returns on the real frame.
--
--     leg      | lane-harass candidate  | X.cm_IsLaneHarassTargetInReach
--     ---------+------------------------+-------------------------------
--     gate off | vengeful_spirit        | true   (an 81.9u walk order)
--     armed    | vengeful_spirit        | FALSE  <- the lever
--
-- §2 takes that reading with zero injections.  §4 then drives the whole
-- X.SkillsComplement dispatch, and pays for it with the three injections §0.3
-- limit 2 names.
--
-- ===========================================================================
-- §0.2  REPRODUCE
-- ===========================================================================
--
--     lua5.1 tests/run_tests.lua cm_w_lane_band
--     bash tools/agent/mutstand_cmlaneband.sh
--     bash tools/agent/luacheck_gate.sh
--
-- ===========================================================================
-- §0.3  LIMITS -- load-bearing, quote these with any number above
-- ===========================================================================
--
-- 1. THE DOMAIN AND §1 COUNTS IT.  Over both corpus directories (141 frames),
--    Crystal Maiden is present and alive on 70; on 5 of those an enemy hero
--    sits in the band (outside nCastRange + 50, inside nCastRange + 200), 5
--    band members in total; on 20 an enemy sits inside the gate, where this
--    lever is a byte-for-byte no-op.
--    RE-TAKEN 2026-09-11 (hero), 53 -> 70 live / 3 -> 5 band / 13 -> 20 gate.
--    ⛔ AND THE WAY THIS ONE WAS RE-TAKEN IS THE POINT.  The three counts above
--    were pinned with `==`, so for three rounds this file sat RED on trunk --
--    and what it was red ABOUT was its own domain GROWING.  A `== N` on a
--    corpus size makes good news and bad news look identical, and the reader
--    who finds the red has to re-derive which one it is.  They are FLOORS now
--    (growth may only push them up), with the conclusion -- "the band domain is
--    non-empty at all" -- asserted separately so a drifting count cannot
--    satisfy it.  Same cause and same fix as the three re-anchored in
--    tests/test_lion_ult_reach.lua §1; hero backlog -152 第四条.
--    The earlier 52 -> 53 re-take (2026-09-09, GH #659) is kept below because
--    its reasoning is still the model for reading a moved denominator: the
--    staged frame f_260908_094909_cm_cmqreach_transit.lua was a CM-subject
--    frame pinned BECAUSE Crystal Maiden is in transit with her nearest live
--    enemy 2790u away -- far outside both band and gate -- so ONLY THE
--    DENOMINATOR MOVED.  A reader quoting a stale denominator is not quoting a
--    stale finding.
--
-- 2. ⚠️ THE BRANCH AS A WHOLE FIRING IS **NOT** A READING THIS ROUND BOUGHT,
--    and both reasons are about the harness, not the game.  §4 opens three
--    conjuncts by hand and says so here rather than in a comment nobody reads:
--      (a) bot:GetActiveMode() -> BOT_MODE_LANING.  Active mode is bot-VM state
--          and is in no .dem (the 13th-world assertion `wkqlane` recorded).  The
--          whole 对线期消耗 block sits behind it, so NO archive frame can reach
--          the branch either way.
--      (b) the candidate's GetCurrentMovementSpeed -> 285.  The fixture loader
--          hands EVERY unit `GetCurrentMovementSpeed = 300`
--          (tests/mock/replay_fixture.lua), so the branch's own
--          `target speed < bot speed` conjunct is `300 < 300` -- false on every
--          frame in the corpus, for a reason that is about the loader constant
--          and not about the game.  Same family as GH #611 / #613: a loader
--          constant silently disarms a whole branch and it reads like "the
--          domain is empty".  285 is not a claim about this venge's real speed;
--          it is the smallest edit that opens the conjunct.
--      (c) the bot's GetHealth -> 400.  The branch demands nHP > 0.6 and this
--          CM is at 342/604 = 56.6%.  This one IS frame data being overridden,
--          and it is the reason §2 -- which injects NOTHING -- is the reading
--          this round stands behind, and §4 only the wiring.
--    §4 asserts all three took before it reads anything.  Geometry, roster,
--    ability ranks, cooldowns and mana are REAL and untouched in both sections.
--
-- 3. THIS FILE DOES NOT TOUCH THE TP INTERRUPT, the other unbounded firing
--    point.  §0 argues it is defensible; that argument is not machine-checked
--    here and is not claimed to be.  §5 asserts the interrupt is still
--    unbounded so that a future round cannot read this file as having fixed it.
--
-- 4. THE 1600-UNIT FIRING POINT IS REGISTERED, NOT FIXED.  The block below the
--    one this lever guards bids on `nEnemysHeroesInView[1]` -- a 1600 ring, 970
--    units past the cast range, wider than the band this file closes.  It is
--    left alone because its own `>= 5 allies within 350 of the target` conjunct
--    makes its domain a separate question, not because it is defensible.  §5
--    pins that it still reads the view ring, so a later round finds it.
--
-- 5. WHETHER THE REFUSED WALKS WERE WORTH TAKING IS NOT SETTLED HERE.  This
--    file settles the direction (strict subset, never widens, never relocates)
--    and that the shipped selector really elects an out-of-reach candidate on a
--    real frame.  The value question is a wave reading: queue request hero-47.

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')

local SRC    = 'bots/BotLib/hero_crystal_maiden.lua'
local CAND   = 'cmlaneband'
local HELPER = 'cm_IsLaneHarassTargetInReach'
local UNIT   = 'npc_dota_hero_crystal_maiden'
local FROST  = 'crystal_maiden_frostbite'

local FRAME = 'tests/fixtures/f_megabundle_052241_sniper_l1trade_chase.lua'

local FIXTURE_DIR = 'tests/fixtures'
local STAGED_DIR  = 'tests/frames'

local VENGE = 'npc_dota_hero_vengeful_spirit'

local CAST_RANGE = 600          -- AbilityCastRange, tests/mock/special_value_shapes.lua
local SLACK      = 30           -- X.ConsiderW's own `+ 30` on top of the cast range
local NCR        = CAST_RANGE + SLACK   -- what the function calls nCastRange
local GATE       = 50           -- the 进攻 firing point's OWN commit slack (+50)
local BONUS      = 200          -- the lane-harass branch's search ring

local tests = {}

local function read_file(path)
    local fh = assert(io.open(path, 'r'), 'cannot open ' .. path)
    local body = fh:read('*a')
    fh:close()
    return body
end

--- Both corpus directories, enumerated -- never a hardcoded list.  An empty
--- enumerator and an empty corpus are the same integer; the assert below is the
--- only thing that tells them apart.
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

local function enemy_handle(bot, sName)
    for _, e in ipairs(bot:GetNearbyHeroes(1600, true, BOT_MODE_NONE)) do
        if e:GetUnitName() == sName then return e end
    end
    return nil
end

--- Load the frame with CM as the subject and arm (or not) the candidate.
--- Nothing else is touched: this is the stand §2 and §3 take their readings on.
local function frame(bArmed)
    local J, bot = rf.load(FRAME, UNIT)
    J.IsSoakCandidate = function(id) return bArmed and id == CAND end
    local X = rf.load_hero('crystal_maiden')
    return J, bot, X
end

--- The shipped candidate: whatever X.cm_GetWeakestUnit elects out of the REAL
--- bonus ring on the REAL frame.  Not a handle this test picked.
local function shipped_candidate(bot, X)
    local tBonus = bot:GetNearbyHeroes(NCR + BONUS, true, BOT_MODE_NONE)
    return X.cm_GetWeakestUnit(tBonus), tBonus
end

--- Drive the REAL X.SkillsComplement dispatch on the real frame with the three
--- §0.3 limit 2 injections in place.  Returns the action log plus the handles
--- §4 needs to prove the injections took.
local function drive(bArmed)
    local J, bot, X = frame(bArmed)
    local hVenge = enemy_handle(bot, VENGE)
    assert(hVenge ~= nil, VENGE .. ' is not on ' .. FRAME .. ' any more')
    inject(bot,    'GetActiveMode',           BOT_MODE_LANING)
    inject(bot,    'GetHealth',               400)
    inject(hVenge, 'GetCurrentMovementSpeed', 285)
    local log = rf.record_actions(bot)
    X.SkillsComplement()
    return log, J, bot, X, hVenge
end

--- The Frostbite target the dispatch actually ordered, or nil if it ordered
--- none.  X.ConsiderW is the only arm in this file that uses OnEntity.
local function frozen(log)
    for _, a in ipairs(log) do
        if a.fn:find('UseAbilityOnEntity') then
            local h = a.args[2]
            if h ~= nil and h.GetUnitName ~= nil then return h:GetUnitName() end
        end
    end
    return nil
end

-- ---------------------------------------------------------------- section 1 --
-- The domain, counted over the whole corpus.  §0.3 limit 1's evidence.

tests['§1 the corpus still puts an enemy in the band on some Crystal Maiden frame'] = function()
    local nFiles, nLive = 0, 0
    local nWithBand, nBandEnemies, nWithGate = 0, 0, 0
    local tBandFrames = {}
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
                local nBand, nGate = 0, 0
                for _, e in ipairs(bot:GetNearbyHeroes(NCR + BONUS, true, BOT_MODE_NONE)) do
                    local d = GetUnitToUnitDistance(bot, e)
                    if d <= NCR + GATE then
                        nGate = nGate + 1
                    else
                        nBand = nBand + 1
                    end
                end
                nBandEnemies = nBandEnemies + nBand
                if nGate > 0 then nWithGate = nWithGate + 1 end
                if nBand > 0 then
                    nWithBand = nWithBand + 1
                    tBandFrames[#tBandFrames + 1] = path
                end
            end
        end
    end
    assert(nFiles >= 110, 'the corpus enumerator returned ' .. nFiles
        .. ' frames, expected >= 110 -- an empty ls and an empty corpus are the '
        .. 'same integer')
    -- ⭐ FLOORS, not `==` pins (hero backlog -152, same cause as the three
    -- re-anchored in tests/test_lion_ult_reach.lua §1).  A `== N` on a CORPUS
    -- SIZE makes good news and bad news look identical: this file was red for
    -- three rounds because Crystal Maiden went from 53 live instants to 70 --
    -- i.e. because its own domain was GROWING.  Growth may only push these up,
    -- so a floor is the direction-safe bound and a shrinking corpus still
    -- speaks up.
    assert(nLive >= 53, 'Crystal Maiden is alive on only ' .. nLive .. ' corpus '
        .. 'frames (floor 53) -- the corpus SHRANK; re-take §0.3 limit 1 rather '
        .. 'than quoting it')
    assert(nWithBand >= 3 and nBandEnemies >= 3,
        'the band domain shrank: ' .. nWithBand .. ' frames / ' .. nBandEnemies
        .. ' enemies (floor 3 / 3).  Re-take §0.3 limit 1.')
    assert(nWithGate >= 13, 'the in-gate domain shrank: ' .. nWithGate
        .. ' frames (floor 13).  Those are the frames on which this lever is a '
        .. 'byte-for-byte no-op, and the count belongs in §0.3 limit 1.')
    -- The CONCLUSION, stated on its own so it cannot be satisfied by a count
    -- drifting: the lever must still have a local domain at all.
    assert(nWithBand >= 1, 'no corpus frame puts an enemy in the band any more '
        .. '-- this lever has no locally-checkable domain left')
    local bHasFrame = false
    for _, p in ipairs(tBandFrames) do if p == FRAME then bHasFrame = true end end
    assert(bHasFrame, 'the §0.1 frame ' .. FRAME .. ' is no longer one of the '
        .. 'band frames (' .. table.concat(tBandFrames, ', ') .. ')')
end

-- ---------------------------------------------------------------- section 2 --
-- THE READING THIS ROUND STANDS BEHIND.  Real frame, real selector, real
-- helper, ZERO injections.

tests['§2 the shipped selector elects an out-of-reach candidate on the real frame'] = function()
    local _, bot, X = frame(false)
    local hCand, tBonus = shipped_candidate(bot, X)
    assert(hCand ~= nil, 'X.cm_GetWeakestUnit elects nobody out of the bonus '
        .. 'ring on ' .. FRAME .. ' -- §0.1 is stale')
    assert(hCand:GetUnitName() == VENGE, 'the shipped candidate is now '
        .. hCand:GetUnitName() .. ', was ' .. VENGE)
    assert(#tBonus == 1, 'the bonus ring now holds ' .. #tBonus .. ' heroes, '
        .. 'was 1.  With more than one, the candidate is a selector outcome and '
        .. '§0.1 has to say which health picked it.')

    local d = GetUnitToUnitDistance(bot, hCand)
    assert(d > NCR + GATE and d <= NCR + BONUS, VENGE .. ' is at '
        .. string.format('%.1f', d) .. 'u, no longer inside the band ('
        .. (NCR + GATE) .. ', ' .. (NCR + BONUS) .. ']')

    -- The cast range is REAL: no injection, straight off the KV snapshot.
    local hW = bot:GetAbilityByName(FROST)
    assert(hW ~= nil and hW:GetCastRange() == CAST_RANGE,
        'Frostbite answers GetCastRange() = ' .. tostring(hW and hW:GetCastRange())
        .. ', expected ' .. CAST_RANGE .. ' -- every ring in X.ConsiderW would '
        .. 'then be measured off a number this file did not read')
end

tests['§2 gate off admits that candidate; armed refuses it'] = function()
    local _, botOff, XOff = frame(false)
    local hOff = shipped_candidate(botOff, XOff)
    assert(XOff.cm_IsLaneHarassTargetInReach(botOff, hOff, NCR) == true,
        'gate off refused the band candidate -- the shipped behaviour changed, '
        .. 'which is a defaults change wearing a candidate name')

    local _, botOn, XOn = frame(true)
    local hOn = shipped_candidate(botOn, XOn)
    assert(hOn:GetUnitName() == VENGE, 'arming moved the shipped selector')
    assert(XOn.cm_IsLaneHarassTargetInReach(botOn, hOn, NCR) == false,
        'armed still admits ' .. VENGE .. ' at '
        .. string.format('%.1f', GetUnitToUnitDistance(botOn, hOn)) .. 'u')
end

-- ---------------------------------------------------------------- section 3 --
-- No relocation.  The `lionrreach` trap: filtering one site can MOVE a cast
-- instead of removing it.  Here it cannot, and this drives that on the real
-- frame rather than quoting the source.

tests['§3 no firing point in X.ConsiderW can pick the band target up'] = function()
    local _, bot = frame(true)
    local hVenge = enemy_handle(bot, VENGE)
    assert(hVenge ~= nil, VENGE .. ' is no longer visible on ' .. FRAME)
    local d = GetUnitToUnitDistance(bot, hVenge)

    -- Every other firing point reads nEnemysHeroesInRange, or an explicit test
    -- at nCastRange, +50 or -80.  All three rings are asked HERE, on the real
    -- frame, rather than read off the source.
    for _, r in ipairs({ NCR - 80, NCR, NCR + GATE }) do
        for _, e in ipairs(bot:GetNearbyHeroes(r, true, BOT_MODE_NONE)) do
            assert(e:GetUnitName() ~= VENGE, VENGE .. ' is now inside the '
                .. r .. 'u ring; a tighter firing point could re-pick him and '
                .. '§3 is void')
        end
    end
    assert(d > NCR + GATE, VENGE .. ' is at ' .. string.format('%.1f', d)
        .. 'u, inside the widest ring any other committing firing point uses')

    -- The one ring that IS wider is the view ring, and the firing point that
    -- reads it is §0.3 limit 4's -- registered, not fixed.  If a future round
    -- narrows that one, this assert is where it finds out this file assumed it
    -- had not.
    local bInView = false
    for _, e in ipairs(bot:GetNearbyHeroes(1600, true, BOT_MODE_NONE)) do
        if e:GetUnitName() == VENGE then bInView = true end
    end
    assert(bInView, VENGE .. ' left the 1600 view ring, so §0.3 limit 4 can no '
        .. 'longer be read off this frame')
end

-- ---------------------------------------------------------------- section 4 --
-- The wiring, end to end -- and the price §0.3 limit 2 charges for it.

tests['§4 the three injections were really read, and the frame is the named one'] = function()
    local _, _, bot, _, hVenge = drive(false)
    assert(bot:GetActiveMode() == BOT_MODE_LANING,
        'the GetActiveMode injection did not take (' .. tostring(bot:GetActiveMode())
        .. ') -- the whole 对线期消耗 block would then be shut and §4 would prove '
        .. 'nothing about this branch')
    assert(bot:GetHealth() == 400, 'the GetHealth injection did not take ('
        .. tostring(bot:GetHealth()) .. ') -- the branch demands nHP > 0.6 and '
        .. 'the frame is at 56.6%')
    assert(hVenge:GetCurrentMovementSpeed() == 285,
        'the movement-speed injection did not take ('
        .. tostring(hVenge:GetCurrentMovementSpeed()) .. ') -- the loader hands '
        .. 'every unit 300 and the conjunct would be 300 < 300')
    assert(bot:GetCurrentMovementSpeed() == 300,
        'the bot no longer reads the loader constant 300, so §0.3 limit 2 (b) '
        .. 'no longer describes what makes that conjunct undrivable')
end

tests['§4 gate off freezes the out-of-reach venge; armed does not'] = function()
    local shipped = frozen((drive(false)))
    assert(shipped == VENGE, 'gate off did not freeze ' .. VENGE .. ' (got '
        .. tostring(shipped) .. ') -- either §0.1 is stale, or an upstream arm '
        .. 'takes the frame and §4 would prove nothing')

    local armed = frozen((drive(true)))
    assert(armed == nil, 'armed still froze ' .. tostring(armed) .. ' at 711.9u.  '
        .. 'Either the lane-harass branch is not routed through X.' .. HELPER
        .. ', or a downstream firing point picked the target up.')
end

-- ---------------------------------------------------------------- section 5 --
-- Properties of the helper itself, and the two claims §0.3 makes about code
-- this file did NOT change.

tests['§5 gate off returns the shipped answer (true) for every target'] = function()
    local _, bot, X = frame(false)
    local hVenge = enemy_handle(bot, VENGE)
    for _, r in ipairs({ 0, 100, NCR, NCR + GATE, NCR + BONUS, 5000 }) do
        assert(X.cm_IsLaneHarassTargetInReach(bot, hVenge, r) == true,
            'gate off must be the shipped no-filter answer (true) at nCastRange '
            .. '= ' .. r .. ', got false')
    end
end

tests['§5 armed does nothing outside turbo'] = function()
    local J, bot, X = frame(true)
    J.IsModeTurbo = function() return false end
    local hVenge = enemy_handle(bot, VENGE)
    assert(X.cm_IsLaneHarassTargetInReach(bot, hVenge, NCR) == true,
        'the lever fired outside turbo -- every soak candidate in this tree is '
        .. 'turbo-only and this one would ship into normal games')
end

tests['§5 armed is exactly the +50 gate, over the whole cast-range ladder'] = function()
    local _, bot, X = frame(true)
    local hVenge = enemy_handle(bot, VENGE)
    local d = GetUnitToUnitDistance(bot, hVenge)
    -- Walk nCastRange rather than the target: the ladder is what a talent, an
    -- Aether Lens or the lone-enemy attack-range extension above the branch
    -- actually move, and the gate has to keep composing with all three.
    for _, r in ipairs({ 300, 500, NCR, 700, 900 }) do
        local bWant = (d <= r + GATE)
        assert(X.cm_IsLaneHarassTargetInReach(bot, hVenge, r) == bWant,
            'armed is no longer exactly `distance <= nCastRange + ' .. GATE
            .. '`: at nCastRange = ' .. r .. ' with the target at '
            .. string.format('%.1f', d) .. 'u it answered '
            .. tostring(not bWant))
    end
end

tests['§5 the TP interrupt is still unbounded -- this file did not fix it'] = function()
    local body = consider_w_body(read_file(SRC))
    local from = body:find('modifier_teleporting')
    assert(from, 'the TP interrupt is gone from X.ConsiderW')
    local head = body:find('nEnemysHeroesInBonus%s*%)')
    assert(head ~= nil and head < from, 'the interrupt no longer reads the bonus ring')
    local seg = body:sub(head, from)
    assert(not seg:find('IsInRange') and not seg:find('GetUnitToUnitDistance'),
        'the TP interrupt now HAS a distance term.  Good -- but §0.3 limit 3 '
        .. 'claims it does not, so retire that limit instead of this assert.')
end

tests['§5 the 1600-unit firing point is still there -- §0.3 limit 4'] = function()
    local body = consider_w_body(read_file(SRC))
    assert(body:find('nEnemysHeroesInView%[1%]'),
        'the firing point that bids on nEnemysHeroesInView[1] is gone or renamed.  '
        .. 'If a round narrowed it, retire §0.3 limit 4; do not delete this assert.')
end

tests['§5 the lane-harass branch really routes through the helper'] = function()
    local body = consider_w_body(read_file(SRC))
    -- The paren is load-bearing: the helper is also NAMED in prose above the
    -- function, and a bare-name count reads that mention as a second call site.
    local at = body:find('X%.' .. HELPER .. '%s*%(')
    assert(at, 'X.ConsiderW no longer calls X.' .. HELPER
        .. ' -- the lever is wired to nothing and every reading above is vacuous')
    local nCalls = 0
    for _ in body:gmatch('X%.' .. HELPER .. '%s*%(') do nCalls = nCalls + 1 end
    assert(nCalls == 1, 'X.' .. HELPER .. ' now has ' .. nCalls .. ' call sites in '
        .. 'X.ConsiderW, was 1.  A second site is a different lever with a '
        .. 'different domain; give it its own id and its own frame.')
end

return tests

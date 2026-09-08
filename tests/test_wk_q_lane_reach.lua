-- [hero] `wkqlane` -- X.ConsiderQ's lane-harass firing point commits Wraithfire
-- Blast to targets up to 330 units OUTSIDE its cast range, and the gated
-- narrowing that stops it.
--
-- ===========================================================================
-- §0  WHAT IS WRONG
-- ===========================================================================
--
-- bots/BotLib/hero_skeleton_king.lua X.ConsiderQ builds two search rings off one
-- cast range and then bids from TEN firing points.  Eight of the ten bound the
-- target to roughly the cast range:
--
--     kill-confirm       GetUnitToUnitDistance(...) <= nCastRange + 80
--     teamfight          nEnemysHerosInRange   (nCastRange + 43)
--     打架先手           J.IsInRange( npcTarget, bot, nCastRange + 80 )
--     retreat            nEnemysHerosInRange
--     farming            bot:GetNearbyNeutralCreeps( nCastRange + 100 )
--     roshan             J.IsInRange( npcTarget, bot, nCastRange )
--     recently-damaged   nEnemysHerosInRange
--     generic            nEnemysHerosInRange
--
-- Exactly TWO iterate nEnemysHerosInBonus (nCastRange + 330) with NO distance
-- term at all: the channel interrupt, and the 对线期间 lane-harass branch.
--
-- This file is about the second one, and deliberately not about the first.  An
-- interrupt is worth walking for -- it costs the enemy a whole channel.  The
-- lane-harass branch's payoff is a HARASS (a 1.0-1.6s stun and the dot) on a
-- target the bot's own creeps are already beating on, and the KILL case is
-- firing point 2, which does bound distance.  So the loosest reach in the
-- function sits under the smallest payoff, on a MELEE hero, at hero level <= 5.
--
-- What the engine is handed is `ActionQueue_UseAbilityOnEntity( abilityQ,
-- castQTarget )`, and on an out-of-range target that order is a MOVE order
-- first: Wraith King walks the gap.  X.SkillsComplement `return`s the moment Q
-- is queued, so X.ConsiderW (Bone Guard) is not consulted for as long as the
-- desire holds.  Same family as `lionrreach` (GH #617) on a different hero.
--
-- ===========================================================================
-- §0.1  THE READING (one real frame, one candidate, nothing moved)
-- ===========================================================================
--
-- tests/fixtures/f_230545_wk_sven_burst.lua, t=306.0, Wraith King the subject:
--
--     hero level 4        => the branch's own `nLV <= 5` disjunct is TRUE on the
--                            REAL frame.  Nothing injects a mode, and nothing
--                            can: bot:GetActiveMode() is bot-VM state and is in
--                            no .dem (13th world assertion).
--     Reincarnation rank 0, nLV 4 < 6
--                         => X.ShouldSaveMana is really false, so the first line
--                            of X.ConsiderQ really lets the frame through.
--     sven   661.6u       => 56.6u BEYOND the +80 gate, 193.4u inside the +330
--                            ring.  The one and only band candidate.
--     lich   861.3u       => 6.3u OUTSIDE the ring, so the bonus list really
--                            holds exactly one enemy...
--     ...and #nEnemysHerosInView == 2, so the +260 lone-ranged-enemy extension
--     above really stays shut.  Neither of those two facts is arranged.
--
--     leg      | lane-harass firing point
--     ---------+-------------------------------
--     gate off | blast -> sven   (a 56.6u walk)
--     armed    | NO CAST         <- the lever
--
-- ===========================================================================
-- §0.2  REPRODUCE
-- ===========================================================================
--
--     lua5.1 tests/run_tests.lua wk_q_lane_reach
--     bash tools/agent/mutstand_wkqlane.sh
--     bash tools/agent/luacheck_gate.sh
--
-- ===========================================================================
-- §0.3  LIMITS -- load-bearing, quote these with any number above
-- ===========================================================================
--
-- 1. THE DOMAIN IS THIN AND §1 COUNTS IT.  Over both corpus directories (115
--    frames), Wraith King is present and alive on 37; on 6 of those an enemy
--    hero sits in the band (outside nCastRange + 80, inside nCastRange + 330),
--    6 band members in total; on 11 an enemy sits inside the gate, where this
--    lever is a byte-for-byte no-op.  These counts are ASSERTED, not narrated:
--    if the corpus grows, §1 goes red and this section is re-taken rather than
--    quoted.
-- 2. TWO INJECTIONS, named so nobody quotes §0.1 as a pure archive reading:
--      (a) GetCastRange -> 525.  GetCastRange is on no spec in tests/mock, so
--          the generic `^Get` default answers 0 on every archive frame (the
--          meter-zero family recorded in X.ConsiderQ's own kill-confirm note).
--          At 0 the bonus ring is 330 and sven is not even in the list, so BOTH
--          legs would answer "no cast" for a reason that is about the harness
--          and not about the game.  525 is this ability's own AbilityCastRange,
--          already in the tree at tests/mock/special_value_shapes.lua.
--      (b) J.GetAttackEnemysAllyCreepCount -> 4.  The dumper's creeps[] carries
--          only {t,team,x,y} (GH #581): no attack target, so NO archive frame
--          can answer that conjunct either way.
--    §4 asserts both injections were actually read before any reading is taken.
--    Geometry, roster, health, hero level, ability ranks and cooldowns are REAL
--    and untouched.
-- 3. THIS FILE DOES NOT TOUCH THE CHANNEL INTERRUPT, the other unbounded firing
--    point.  §0 argues it is defensible; that argument is not machine-checked
--    here and is not claimed to be.  §5 asserts the interrupt is still
--    unbounded so that a future round cannot read this file as having fixed it.
-- 4. WHETHER THE REFUSED WALKS WERE WORTH TAKING IS NOT SETTLED HERE.  This file
--    settles the direction (strict subset, never widens, never relocates) and
--    that the branch really fires on a real frame.  The value question is a wave
--    reading: queue request hero-45.

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')

local SRC    = 'bots/BotLib/hero_skeleton_king.lua'
local CAND   = 'wkqlane'
local HELPER = 'wk_IsLaneHarassTargetInReach'
local UNIT   = 'npc_dota_hero_skeleton_king'
local BLAST  = 'skeleton_king_hellfire_blast'

local FRAME = 'tests/fixtures/f_230545_wk_sven_burst.lua'

local FIXTURE_DIR = 'tests/fixtures'
local STAGED_DIR  = 'tests/frames'

local SVEN = 'npc_dota_hero_sven'
local LICH = 'npc_dota_hero_lich'

local CAST_RANGE = 525          -- AbilityCastRange, tests/mock/special_value_shapes.lua
local GATE       = 80           -- the function's OWN gate slack (+80)
local BONUS      = 330          -- the lane-harass branch's search ring

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

local function consider_q_body(src)
    local from = src:find('\nfunction%s+X%.ConsiderQ%s*%(')
    assert(from, 'X.ConsiderQ is gone from ' .. SRC)
    local rest = src:sub(from + 1)
    local to = rest:find('\nend\n')
    assert(to, 'X.ConsiderQ has no closing end in ' .. SRC)
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

--- Drive the REAL X.SkillsComplement dispatch on the real frame, with the
--- candidate armed or not, and with the two §0.3 limit 2 injections in place.
--- `nCreeps` is the answer J.GetAttackEnemysAllyCreepCount gives for every
--- target; pass 0 to close the lane-harass branch's own creep conjunct.
local function drive(bArmed, nCreeps)
    local J, bot = rf.load(FRAME, UNIT)
    J.IsSoakCandidate = function(id) return bArmed and id == CAND end
    J.GetAttackEnemysAllyCreepCount = function() return nCreeps end

    local X = rf.load_hero('skeleton_king')
    local hQ = bot:GetAbilityByName(BLAST)
    inject(hQ, 'GetCastRange', CAST_RANGE)
    inject(hQ, 'GetCooldownTimeRemaining', 0)
    inject(hQ, 'IsFullyCastable', true)

    local log = rf.record_actions(bot)
    X.SkillsComplement()
    return log, J, bot, X, hQ
end

--- The blast target the dispatch actually ordered, or nil if it ordered none.
local function blasted(log)
    for _, a in ipairs(log) do
        if a.fn:find('UseAbilityOnEntity') then
            local h = a.args[2]
            if h ~= nil and h.GetUnitName ~= nil then return h:GetUnitName() end
        end
    end
    return nil
end

local function enemy_handle(bot, sName)
    for _, e in ipairs(bot:GetNearbyHeroes(CAST_RANGE + BONUS, true, BOT_MODE_NONE)) do
        if e:GetUnitName() == sName then return e end
    end
    return nil
end

-- ---------------------------------------------------------------- section 1 --
-- The domain, counted over the whole corpus.  §0.3 limit 1's evidence.

tests['§1 the corpus puts an enemy in the band on 6 of 37 Wraith King frames'] = function()
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
                for _, e in ipairs(bot:GetNearbyHeroes(CAST_RANGE + BONUS, true, BOT_MODE_NONE)) do
                    local d = GetUnitToUnitDistance(bot, e)
                    if d <= CAST_RANGE + GATE then
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
    assert(nLive == 37, 'Wraith King is alive on ' .. nLive .. ' corpus frames, '
        .. 'was 37 -- re-take §0.3 limit 1 rather than quoting it')
    assert(nWithBand == 6 and nBandEnemies == 6,
        'the band domain moved: ' .. nWithBand .. ' frames / ' .. nBandEnemies
        .. ' enemies, was 6 / 6.  Re-take §0.3 limit 1.')
    assert(nWithGate == 11, 'the in-gate domain moved: ' .. nWithGate
        .. ' frames, was 11.  Those are the frames on which this lever is a '
        .. 'byte-for-byte no-op, and the count belongs in §0.3 limit 1.')
    local bHasFrame = false
    for _, p in ipairs(tBandFrames) do if p == FRAME then bHasFrame = true end end
    assert(bHasFrame, 'the §0.1 frame ' .. FRAME .. ' is no longer one of the '
        .. 'band frames (' .. table.concat(tBandFrames, ', ') .. ')')
end

-- ---------------------------------------------------------------- section 2 --
-- The lever, driven end to end through the real dispatch.

tests['§2 gate off blasts the out-of-range sven; armed does not'] = function()
    local shipped = blasted((drive(false, 4)))
    assert(shipped == SVEN, 'gate off did not blast ' .. SVEN .. ' (got '
        .. tostring(shipped) .. ') -- §0.1 is stale, or some upstream firing '
        .. 'point now takes the frame and §2 would prove nothing')

    local armed = blasted((drive(true, 4)))
    assert(armed == nil, 'armed still blasted ' .. tostring(armed) .. ' at '
        .. '661.6u.  Either the lane-harass branch is not routed through X.'
        .. HELPER .. ', or a downstream firing point picked the target up.')
end

tests['§2 with the creep conjunct shut, both legs agree -- the branch is the one'] = function()
    local shipped = blasted((drive(false, 0)))
    local armed   = blasted((drive(true, 0)))
    assert(shipped == nil and armed == nil,
        'with J.GetAttackEnemysAllyCreepCount answering 0 the frame still casts ('
        .. tostring(shipped) .. ' / ' .. tostring(armed) .. ').  §2 above would '
        .. 'then not be attributable to the lane-harass branch at all.')
end

-- ---------------------------------------------------------------- section 3 --
-- No relocation.  The `lionrreach` trap: filtering one site can MOVE a dive
-- instead of removing it.  Here it cannot, and this drives that rather than
-- quoting the source.

tests['§3 no firing point below the lane-harass branch can reach the band'] = function()
    local _, _, bot = drive(true, 4)
    local hSven = enemy_handle(bot, SVEN)
    assert(hSven ~= nil, 'sven is no longer inside the bonus ring on ' .. FRAME)
    local d = GetUnitToUnitDistance(bot, hSven)
    assert(d > CAST_RANGE + GATE and d <= CAST_RANGE + BONUS,
        SVEN .. ' is at ' .. string.format('%.1f', d) .. 'u, no longer inside the '
        .. 'band (' .. (CAST_RANGE + GATE) .. ', ' .. (CAST_RANGE + BONUS) .. ']')

    -- Every downstream firing point reads one of these two rings, or an explicit
    -- test no wider than +100.  Both rings are asked HERE, on the real frame,
    -- rather than read off the source.
    local tTight = bot:GetNearbyHeroes(CAST_RANGE + 43, true, BOT_MODE_NONE)
    for _, e in ipairs(tTight) do
        assert(e:GetUnitName() ~= SVEN, 'sven is now inside nEnemysHerosInRange '
            .. '(nCastRange + 43); the retreat / teamfight / recently-damaged / '
            .. 'generic firing points could then re-pick him and §3 is void')
    end
    assert(d > CAST_RANGE + 100, 'sven is now inside nCastRange + 100, which is '
        .. 'the widest explicit test any downstream firing point applies')

    -- And the whole dispatch agrees: armed, nothing is ordered at all.
    local log = drive(true, 4)
    assert(#log == 0 or blasted(log) == nil,
        'the armed leg ordered ' .. tostring(blasted(log)) .. '; the band target '
        .. 'was relocated to another firing point rather than dropped')
end

-- ---------------------------------------------------------------- section 4 --
-- The injections took, and the frame still says what §0.1 says it says.

tests['§4 the injections were really read, and the frame is the named one'] = function()
    local _, J, bot, X, hQ = drive(false, 4)
    assert(hQ:GetCastRange() == CAST_RANGE, 'the GetCastRange injection did not '
        .. 'take (' .. tostring(hQ:GetCastRange()) .. ') -- every ring in '
        .. 'X.ConsiderQ would then be 525 units too small')
    assert(hQ:IsFullyCastable() == true, 'the IsFullyCastable injection did not take')
    assert(J.GetAttackEnemysAllyCreepCount(nil, 1400) == 4,
        'the creep-count injection did not take')
    assert(X[HELPER] ~= nil, 'X.' .. HELPER .. ' is gone from the hero module')

    -- REAL frame data, none of it injected.
    assert(bot:GetLevel() == 4, 'the subject is now level ' .. bot:GetLevel()
        .. ', was a REAL 4 -- the branch entry `nLV <= 5` stops being real')
    assert(bot:GetHealth() == 868 and bot:GetMaxHealth() == 868,
        'subject health moved: ' .. bot:GetHealth() .. '/' .. bot:GetMaxHealth()
        .. ', was 868/868 -- nothing in this file injects it')
    local hR = bot:GetAbilityByName('skeleton_king_reincarnation')
    assert(hR ~= nil and hR:GetLevel() == 0, 'Reincarnation rank moved; '
        .. 'X.ShouldSaveMana was false on this frame BECAUSE nLV < 6 and R is '
        .. 'unlearned, and §0.1 says so')

    local seen = {}
    for _, e in ipairs(bot:GetNearbyHeroes(CAST_RANGE + BONUS, true, BOT_MODE_NONE)) do
        seen[e:GetUnitName()] = GetUnitToUnitDistance(bot, e)
    end
    assert(seen[SVEN] ~= nil and seen[SVEN] > CAST_RANGE + GATE,
        'sven is no longer the band member (' .. tostring(seen[SVEN]) .. 'u)')
    assert(seen[LICH] == nil, 'lich is now INSIDE the bonus ring; §0.1 says he is '
        .. '6.3u outside it, and the ring holding exactly one candidate is what '
        .. 'makes §2 a single-target reading')

    -- The +260 extension really stays shut: it needs EXACTLY one enemy in 1600.
    local nView = #bot:GetNearbyHeroes(1600, true, BOT_MODE_NONE)
    assert(nView == 2, 'the 1600 roster is now ' .. nView .. ', was 2.  At 1 the '
        .. '+260 lone-ranged-enemy extension can open and every ring in §0.1 moves.')
end

-- ---------------------------------------------------------------- section 5 --
-- The helper itself: gate-off equivalence, direction over the whole distance
-- ladder, and the scope this file explicitly does NOT claim.

tests['§5 gate off returns the shipped answer (true) for every target'] = function()
    local J, bot = rf.load(FRAME, UNIT)
    local X = rf.load_hero('skeleton_king')
    J.IsSoakCandidate = function() return false end
    for _, sName in ipairs({ SVEN, LICH }) do
        local h = nil
        for _, e in ipairs(bot:GetNearbyHeroes(3000, true, BOT_MODE_NONE)) do
            if e:GetUnitName() == sName then h = e end
        end
        assert(h ~= nil, FRAME .. ' no longer carries ' .. sName)
        for _, nCR in ipairs({ 0, 100, 525, 900 }) do
            assert(X[HELPER](h, nCR) == true,
                'gate off must be the shipped no-filter answer (true) for '
                .. sName .. ' at nCastRange ' .. nCR)
        end
    end
end

tests['§5 armed does nothing outside turbo'] = function()
    local J, bot = rf.load(FRAME, UNIT)
    local X = rf.load_hero('skeleton_king')
    local h = nil
    for _, e in ipairs(bot:GetNearbyHeroes(3000, true, BOT_MODE_NONE)) do
        if e:GetUnitName() == SVEN then h = e end
    end
    assert(h ~= nil, FRAME .. ' no longer carries ' .. SVEN)
    assert(J.IsModeTurbo() == true, 'the fixture no longer reports turbo, so this '
        .. 'assert could not tell a turbo-only gate from an ungated one')
    J.IsSoakCandidate = function(id) return id == CAND end
    assert(X[HELPER](h, CAST_RANGE) == false, 'armed IN turbo must refuse the '
        .. 'out-of-gate sven, otherwise the negative control below is vacuous')
    J.IsModeTurbo = function() return false end
    assert(X[HELPER](h, CAST_RANGE) == true,
        'the lever fired outside turbo -- every behaviour id in this repo is '
        .. 'turbo-only and this one has no exemption')
end

tests['§5 armed is a strict subset over the whole cast-range ladder'] = function()
    local J, bot = rf.load(FRAME, UNIT)
    local X = rf.load_hero('skeleton_king')
    local h = nil
    for _, e in ipairs(bot:GetNearbyHeroes(3000, true, BOT_MODE_NONE)) do
        if e:GetUnitName() == SVEN then h = e end
    end
    assert(h ~= nil, FRAME .. ' no longer carries ' .. SVEN)
    local d = GetUnitToUnitDistance(bot, h)

    local nDiff = 0
    for nCR = 0, 1200, 25 do
        J.IsSoakCandidate = function() return false end
        local shipped = X[HELPER](h, nCR)
        J.IsSoakCandidate = function(id) return id == CAND end
        local armed = X[HELPER](h, nCR)
        assert(shipped == true, 'the shipped leg answered ' .. tostring(shipped)
            .. ' at nCastRange ' .. nCR .. '; it must be an unconditional true')
        assert(armed == false or armed == true, 'armed answered a non-boolean')
        -- Strict subset: armed may only ever turn true into false.
        assert(not (armed == true and shipped == false),
            'armed WIDENED at nCastRange ' .. nCR)
        if armed ~= shipped then nDiff = nDiff + 1 end
        assert(armed == (d <= nCR + GATE), 'armed is no longer exactly '
            .. '`distance <= nCastRange + ' .. GATE .. '` at nCastRange ' .. nCR)
    end
    assert(nDiff > 0, 'armed never differed anywhere on the ladder; the lever '
        .. 'would be a no-op on this frame')
end

tests['§5 the channel interrupt is still unbounded -- this file did not fix it'] = function()
    local body = consider_q_body(read_file(SRC))
    local from = body:find('IsChanneling%s*%(%s*%)')
    assert(from, 'the channel-interrupt firing point is gone from X.ConsiderQ; '
        .. '§0.3 limit 3 names it as the OTHER unbounded point and must be re-taken')
    -- Between the loop head and the interrupt return there is still no distance
    -- term.  If someone bounds it later, this assert is the reminder to retire
    -- §0.3 limit 3 rather than to leave a stale claim standing.
    local head = body:find('nEnemysHerosInBonus%s*%)')
    assert(head ~= nil and head < from, 'the interrupt no longer reads the bonus ring')
    local seg = body:sub(head, from)
    assert(not seg:find('IsInRange') and not seg:find('GetUnitToUnitDistance'),
        'the channel interrupt now HAS a distance term.  Good -- but §0.3 limit 3 '
        .. 'claims it does not, so retire that limit instead of this assert.')
end

tests['§5 the lane-harass branch really routes through the helper'] = function()
    local body = consider_q_body(read_file(SRC))
    -- The paren is load-bearing: the branch also NAMES the helper in a comment,
    -- and a bare-name count reads that mention as a second call site.
    local at = body:find('X%.' .. HELPER .. '%s*%(')
    assert(at, 'X.ConsiderQ no longer calls X.' .. HELPER
        .. ' -- the lever is wired to nothing and every reading above is vacuous')
    local nCalls = 0
    for _ in body:gmatch('X%.' .. HELPER .. '%s*%(') do nCalls = nCalls + 1 end
    assert(nCalls == 1, 'X.' .. HELPER .. ' now has ' .. nCalls .. ' call sites in '
        .. 'X.ConsiderQ, was 1.  A second site is a different lever with a '
        .. 'different domain; give it its own id and its own frame.')
end

return tests

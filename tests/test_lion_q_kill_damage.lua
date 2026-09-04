-- [hero] [ratchet] `lionqdmg` -- GH #175's Lion direction, filed 2026-08-25 and
-- deliberately left unfixed there, picked up.  Behaviour change, so it ships
-- GATED ('lionqdmg', turbo-only).  Axis `0DMG`.
--
-- WHAT WAS FOUND
--
-- `hAbility:GetAbilityDamage()` is backed by the ability's TOP-LEVEL
-- `AbilityDamage` KV field and nothing else (docs/BOT_API_REFERENCE.md:1526).
-- `lion_impale` declares none in this patch -- its "// Damage." section is
-- literally empty and the numbers live in `AbilityValues`:
--
--     "lion_impale"
--     {
--         "AbilityCastPoint"  "0.3 0.3 0.3 0.3"
--         "AbilityManaCost"   "90 110 130 150"
--         // Damage.
--         //-------------------------------------------------------------------
--         "AbilityValues" { "damage" { "value" "105 170 235 300" } ... }
--     }
--
-- So `bots/BotLib/hero_lion.lua`'s X.ConsiderQ read a hard 0 and handed it to
-- J.WillMagicKillTarget as the damage its KILL branch is allowed to claim.
--
-- WHY THIS IS A CEILING AND NOT A PESSIMISTIC MARGIN
--
-- J.WillMagicKillTarget (jmz_func.lua:1110) builds
--
--     EstDamage = dmg * ( 1 + bot:GetSpellAmp() ) - HealthBack / MagicResistReduce
--
-- and ends in `GetActualIncomingDamage(EstDamage, MAGICAL) >= GetHealth()`.
-- `dmg` enters ONLY through that product, so at dmg = 0 the whole first term is
-- 0 at EVERY spell amp, and EstDamage <= 0 for any non-negative health regen.
-- Against anything alive (health >= 1) the predicate is false.  Every rank,
-- every item, every target, every amplification: the kill branch of Lion's Q has
-- never been able to fire.  §4 drives that on a real frame rather than asserting
-- the algebra, and §4b derives the "dmg enters only as a multiplier" premise out
-- of jmz_func.lua instead of re-typing it.
--
-- WHAT THE DEAD BRANCH ACTUALLY COST -- narrower than it first looks
--
-- Every other branch in X.ConsiderQ also returns BOT_ACTION_DESIRE_HIGH, so the
-- loss is NOT desire, it is coverage.  Read against the branches that follow it
-- (§6 pins the list out of the source), the kill branch is the only one with no
-- mode or context precondition at all: the AoE branch needs 3 heroes, 团战 needs
-- J.IsInTeamFight, 攻击 needs J.IsGoingOnSomeone, 撤退 needs J.IsRetreating, the
-- farm/push branches need creep counts, and the catch-all 常规 branch needs
-- `nLV >= 15`.  So the uncovered set is exactly: a Lion below level 15, in none
-- of those modes, looking at a killable enemy hero.  That is the Turbo laning
-- phase, which is where Earth Spike's 105-300 is largest relative to hero health.
-- It is also the only branch that reaches into `nInBonusEnemyList` (cast range
-- + 200) on its own terms.
--
-- WHAT THIS FILE DOES NOT CLAIM
--
--   * That un-deadening the branch WINS games.  Locally-correct is not
--     emergently-good (AGENTS.md, the lanefix lesson); that is what the gate is
--     for, and condition (a) still has to be bought from the corpus.
--   * That 105/170/235/300 is what the engine hands back at a given level once
--     facets and talents fold in.  §2 proves the change is a one-directional
--     un-deadening for ANY positive reading.
--   * Anything about the `5.0` second regen delay this call site passes.  §6
--     registers it -- it is the only literal delay among the repo's
--     J.WillMagicKillTarget call sites, against a 0.3 cast point -- and
--     deliberately does not touch it.  One lever at a time.
--   * Anything about the two OTHER proven-zero reads in this file (X.ConsiderW
--     and X.ConsiderE assign an `nDamage` local that nothing reads).  §3b pins
--     them as unread so a later reader does not mistake them for live bugs.

package.path = 'tests/?.lua;' .. package.path

local api = require('mock.bot_api')
local rf  = require('mock.replay_fixture')

local LION     = 'bots/BotLib/hero_lion.lua'
local JMZ      = 'bots/FunLib/jmz_func.lua'
local SNAPSHOT = 'tests/mock/ability_damage.lua'
local SHAPES   = 'tests/mock/special_value_shapes.lua'

local CAND_ID  = 'lionqdmg'
local KEY      = 'damage'
local Q_NAME   = 'lion_impale'
local Q_KV     = { 105, 170, 235, 300 }   -- AbilityValues/damage
local Q_DELAY  = 5.0                      -- what the call site passes as nDelay

-- The two Lion frames in the corpus with a live enemy hero inside Q's kill-loop
-- reach (cast range 650 + the branch's own +200).  Chosen by an exhaustive scan
-- of every `f_*_lion_*` fixture, not by taste; §5 records what the scan found.
local FRAME_L4 = 'tests/fixtures/f_260820_182906_lion_drain_survived.lua'  -- Q rank 4
local FRAME_L2 = 'tests/fixtures/f_222428_lion_lich_burst.lua'            -- Q rank 2

local function read_file(sPath)
    local fh = assert(io.open(sPath, 'r'), 'cannot open ' .. sPath)
    local s = fh:read('*a'); fh:close()
    return s
end

--- Strip Lua line comments BEFORE anything is counted.  The block above quotes
--- the call name, the key and the delay while explaining them, and a parser that
--- reads prose reports the prose (GH #136's first census).
local function strip_comments(src)
    return (src:gsub('%-%-[^\n]*', ''))
end

local function body_of(src, sName)
    local sBody = src:match('function X%.' .. sName .. '%(.-%)(.-)\nend\n')
    assert(sBody, 'X.' .. sName .. ' not found in ' .. LION)
    return sBody
end

--- An Earth Spike handle whose engine-side AbilityDamage is `nShipped` and whose
--- KV `damage` is `nKv`.  A declared fabrication: §7 measures why no frame can
--- supply one (the mock carries no KV at all, so both legs read 0 offline).
local function make_impale(nShipped, nKv)
    return api.MakeUnit{
        GetUnitName = Q_NAME,
        GetAbilityDamage = function() return nShipped end,
        GetSpecialValueInt = function(_, sKey)
            if sKey == KEY then return nKv end
            return 0
        end,
    }
end

--- Load Lion on a real frame, set the mode and the gate, return (X, J, bot).
--- GetGameMode is set BEFORE the hero file loads because J.IsModeTurbo memoises
--- its answer on the first call, and the first call is at load time.
local function load_lion(bArmed, bTurbo, sFrame)
    local J, bot = rf.load(sFrame or FRAME_L4)

    if bTurbo == false then
        GetGameMode = function() return GAMEMODE_ALLPICK end
    end
    J.IsSoakCandidate = bArmed
        and function(sId) return sId == CAND_ID end
        or function() return false end

    return rf.load_hero('lion'), J, bot
end

local tests = {}

-- ---------------------------------------------------------------------------
-- 1. The source shape: where the shipped expression is allowed to live.

tests['[hero] ConsiderQ takes its kill damage from the helper and nowhere else'] = function()
    local sBody = body_of(strip_comments(read_file(LION)), 'ConsiderQ')

    assert(sBody:find('X.GetImpaleKillDamage( abilityQ )', 1, true),
        'the one assignment must go through the helper, with the file-local handle')
    assert(not sBody:find('GetAbilityDamage', 1, true),
        'and the raw call must not survive inside ConsiderQ -- that would be an ungated site')

    -- nDamage has exactly one consumer in this function: J.WillMagicKillTarget.
    -- A second one would be a leg nothing here is watching, and (the GH #175
    -- lesson) it could well cut the other way.
    -- Frontier-anchored, or `nDamageType` on the next line counts as a read.
    local nReads = select(2, sBody:gsub('%f[%w]nDamage%f[%W]', ''))
    assert(nReads == 2, 'expected the assignment plus exactly one read of nDamage in '
        .. 'ConsiderQ, got ' .. nReads)
    assert(sBody:find('J.WillMagicKillTarget( bot, npcEnemy, nDamage, 5.0 )', 1, true),
        'and that read must be the kill loop\'s damage argument')
end

tests['[hero] the helper is gated, turbo-only, and ends on the shipped expression'] = function()
    local sBody = body_of(strip_comments(read_file(LION)), 'GetImpaleKillDamage')

    assert(sBody:find("J.IsModeTurbo() and J.IsSoakCandidate( '" .. CAND_ID .. "' )", 1, true),
        'the gate must be turbo-only and carry this id, spelled exactly')

    -- Structural gate-off equivalence: the LAST statement is the shipped read,
    -- and it is the only `return` outside the armed branch.
    local sTail = sBody:match('(return [^\n]*)%s*$')
    assert(sTail == 'return hAbility:GetAbilityDamage()',
        'the shipped expression must be the helper\'s last statement, got ' .. tostring(sTail))
    local nReturns = select(2, sBody:gsub('return ', ''))
    assert(nReturns == 2, 'expected exactly two returns (armed KV, shipped fallthrough), got '
        .. nReturns)
    assert(sBody:find('nKvDamage > 0', 1, true),
        'and a KV key answering <= 0 must fall through to the shipped expression rather '
        .. 'than inventing a default (the GH #162 house rule)')
end

tests['[hero] driven: the gate is off by default, off outside turbo, and one-directional'] = function()
    -- Unarmed: the helper is the shipped read, whatever the KV says.
    local X = load_lion(false, true)
    assert(X.GetImpaleKillDamage(make_impale(0, 300)) == 0,
        'unarmed must answer the shipped 0 even when the KV carries 300')
    assert(X.GetImpaleKillDamage(make_impale(7, 300)) == 7,
        'and must pass a nonzero shipped reading straight through')

    -- Armed but not turbo: same as unarmed.  Both halves of the gate matter.
    X = load_lion(true, false)
    assert(X.GetImpaleKillDamage(make_impale(0, 300)) == 0,
        'armed outside turbo must still answer the shipped read')

    -- Armed in turbo: the KV, and only when it is positive.
    X = load_lion(true, true)
    assert(X.GetImpaleKillDamage(make_impale(0, 300)) == 300, 'armed+turbo must read the KV')
    assert(X.GetImpaleKillDamage(make_impale(0, 0)) == 0,
        'a KV that answers 0 falls through, it does not become a default')
    assert(X.GetImpaleKillDamage(make_impale(11, -5)) == 11,
        'and a negative KV reading falls through too -- armed can never be SMALLER '
        .. 'than shipped, which is what makes this a pure un-deadening')
end

-- ---------------------------------------------------------------------------
-- 2. The census the whole reading rests on -- so a patch breaks this loudly.

tests['[hero] lion declares no nonzero AbilityDamage, and the KV carries the numbers'] = function()
    api.install({})

    local tNonzero = assert(dofile(SNAPSHOT).NONZERO, 'no AbilityDamage snapshot')
    assert(tNonzero['lion'] == nil, 'lion must declare no nonzero AbilityDamage anywhere -- '
        .. 'if a patch gives one to ANY Lion ability, the shipped leg stops being provably '
        .. '0 and this entire reading needs redoing')
    -- Corroboration inside the same snapshot, so the absence above is not a
    -- fetch that half-succeeded and wrote an empty table.
    assert(tNonzero['tidehunter'] and tNonzero['tidehunter']['tidehunter_ravage'],
        'expected tidehunter/ravage in the snapshot as a liveness check')

    local tShapes = assert(dofile(SHAPES), 'no special-value shape snapshot')
    local tImpale = tShapes.SHAPES and tShapes.SHAPES['lion'] and tShapes.SHAPES['lion'][Q_NAME]
    assert(tImpale, Q_NAME .. ' missing from the shape snapshot')
    assert(tImpale[KEY], Q_NAME .. ' declares no `' .. KEY .. '` AbilityValues key -- '
        .. 'the armed leg would read nothing and fall through')
    assert(tImpale[KEY].base == '105 170 235 300',
        'the per-level damage the armed leg reads, got ' .. tostring(tImpale[KEY].base))
end

tests['[hero] the other two proven-zero reads in this file are still unread locals'] = function()
    local src = strip_comments(read_file(LION))

    -- The file still holds exactly three GetAbilityDamage() calls; one of them
    -- is now the helper's shipped fallthrough.  This count is the same ratchet
    -- tests/test_zuus_bolt_kill_cap.lua carries, restated where it now belongs.
    local nCalls = select(2, src:gsub('GetAbilityDamage%(%)', ''))
    assert(nCalls == 3, 'expected 3 GetAbilityDamage() reads in ' .. LION .. ', got ' .. nCalls)

    for _, sName in ipairs{ 'ConsiderW', 'ConsiderE' } do
        local sBody = body_of(src, sName)
        assert(sBody:find('local nDamage = ability', 1, true),
            sName .. ' should still assign nDamage from a handle')
        local nReads = select(2, sBody:gsub('%f[%w]nDamage%f[%W]', ''))
        assert(nReads == 1, sName .. '\'s nDamage must stay an UNREAD local (assignment only). '
            .. 'It is a proven zero; the moment something reads it, the direction has to be '
            .. 'read at that new site before anything is concluded. Got ' .. nReads
            .. ' occurrences')
    end
end

-- ---------------------------------------------------------------------------
-- 3. The ceiling, driven through the REAL J.WillMagicKillTarget on real frames.

tests['[hero] driven ceiling: dmg=0 kills the branch on every live enemy, both frames'] = function()
    for _, sFrame in ipairs{ FRAME_L4, FRAME_L2 } do
        local _, J, bot = load_lion(false, true, sFrame)
        local tEnemies = J.GetNearbyHeroes(bot, 850, true, BOT_MODE_NONE)
        assert(#tEnemies >= 2, sFrame .. ' must carry live enemies in reach, got ' .. #tEnemies)

        for _, npcEnemy in ipairs(tEnemies) do
            assert(npcEnemy:GetHealth() >= 1, 'scan should only reach living heroes')
            assert(J.WillMagicKillTarget(bot, npcEnemy, 0, Q_DELAY) == false,
                'the shipped 0 must never confirm a kill: ' .. npcEnemy:GetUnitName()
                .. ' at ' .. npcEnemy:GetHealth() .. ' hp on ' .. sFrame)
            -- ...and it stays false for every spell amp, because amp enters only
            -- as a multiplier on dmg (premise derived in the next case), so
            -- amp = a is exactly dmg = 0 * (1 + a) = 0.
            for _, nAmp in ipairs{ 0, 0.15, 0.5, 4.0 } do
                assert(J.WillMagicKillTarget(bot, npcEnemy, 0 * (1 + nAmp), Q_DELAY) == false,
                    'still false at spell amp ' .. nAmp)
            end
        end
    end
end

tests['[hero] the premise behind that amp sweep is read out of jmz_func, not re-typed'] = function()
    local src = strip_comments(read_file(JMZ))
    local sBody = src:match('function J%.WillMagicKillTarget%(.-%)(.-)\nend\n')
    assert(sBody, 'J.WillMagicKillTarget not found')

    assert(sBody:find('local EstDamage = dmg * ( 1 + bot:GetSpellAmp() )', 1, true),
        'the sweep above is only valid while `dmg` enters through exactly this product; '
        .. 'if the expression changes, redo the sweep instead of editing this assertion')
    -- `dmg` must not appear anywhere else in the estimate, or scaling it is no
    -- longer the same thing as scaling the amp.
    local nUses = select(2, sBody:gsub('%f[%w]dmg%f[%W]', ''))
    assert(nUses == 1, 'expected `dmg` to be used exactly once in the estimate, got ' .. nUses)
    assert(sBody:find('return nRealDamage >= npcTarget:GetHealth()', 1, true),
        'and the predicate must still end on a health comparison')
end

-- ---------------------------------------------------------------------------
-- 4. The counterfactual, and the corpus limit -- MEASURED, not assumed.

-- RE-DRIVEN 2026-09-04 (hero, backlog -88 (甲)).  Every number below is the
-- same number it was, and that is a reading rather than a reassurance: what
-- changed is WHERE it comes from.  Until `kvgetters` landed, this section fed
-- J.WillMagicKillTarget out of Q_KV -- a four-entry ladder TYPED INTO THIS FILE
-- -- because the mock answered 0 for GetSpecialValue* and no frame could supply
-- the armed leg's reading.  The loader now serves that getter out of the KV
-- snapshot, so the section drives X.GetImpaleKillDamage on the frame's own
-- handle instead: the exact call X.ConsiderQ makes, at the frame's own rank.
--
-- Q_KV stays, demoted from driver to CROSS-CHECK.  A typed ladder that drives
-- the assertions cannot fail when the tree moves under it -- it IS the tree, as
-- far as the test can see.  Compared against the getter it becomes a witness:
-- 8 Lion frames, ranks 2 and 4, helper vs ladder agreed on every one, which is
-- why re-driving changed no number here.  If the KV moves, the cross-check
-- names it rather than this file quietly re-baselining onto the new value.

tests['[hero] armed, the branch stops being dead: the frame decides on Q rank and amp'] = function()
    local X, J, bot = load_lion(true, true, FRAME_L4)
    local tEnemies = J.GetNearbyHeroes(bot, 850, true, BOT_MODE_NONE)

    local hLuna
    for _, e in ipairs(tEnemies) do
        if e:GetUnitName() == 'npc_dota_hero_luna' then hLuna = e end
    end
    assert(hLuna, 'the frame must still carry Luna, the corpus\'s nearest firing candidate')
    assert(hLuna:GetHealth() == 345, 'Luna\'s health on this frame, got ' .. hLuna:GetHealth())

    local hQ = bot:GetAbilityByName(Q_NAME)
    assert(hQ and hQ:GetLevel() == 4, 'and Lion must be at Q rank 4 here, got '
        .. tostring(hQ and hQ:GetLevel()))

    -- The damage the armed leg actually claims on this frame, taken from the
    -- helper rather than from Q_KV, so the driver below is the shipped call
    -- path.  The ladder is the cross-check, not the source.
    local nDmg = X.GetImpaleKillDamage(hQ)
    assert(nDmg == 300, 'the armed helper reads 300 at rank 4 on this frame, got ' .. nDmg)
    assert(nDmg == Q_KV[4], 'and the getter agrees with the ladder this file used to be '
        .. 'driven by; a disagreement means the KV moved and every number in this section '
        .. 'needs re-reading rather than the ladder needing an edit. Got ' .. nDmg
        .. ' vs ' .. Q_KV[4])
    assert(hQ:GetAbilityDamage() == 0, 'while the shipped leg still reads 0 on the same '
        .. 'handle -- the whole point of the gate, now visible on a frame instead of on a '
        .. 'fabrication')

    -- THE CORPUS LIMIT, stated as a number rather than as "no firing frame
    -- exists": at rank 4 the armed leg reads 300, and 300 is 45 hp -- 13.0% of
    -- the nuke -- short of Luna's 345.  So even armed this frame does NOT fire
    -- at zero spell amp.  It is the closest the corpus gets (§5).
    assert(hLuna:GetHealth() - nDmg == 45, 'the miss is 45 hp, computed from the helper '
        .. 'reading rather than restated, got ' .. (hLuna:GetHealth() - nDmg))
    assert(J.WillMagicKillTarget(bot, hLuna, nDmg, Q_DELAY) == false,
        'armed at rank 4 and zero amp, this frame is still 45 hp short')
    assert(J.WillMagicKillTarget(bot, hLuna, nDmg * 1.14, Q_DELAY) == false,
        'and at 14% spell amp')
    -- ...and it clears at exactly 15%, which matters because Lion's own innate
    -- `lion_to_hell_and_back` declares a `spell_amp` of 20 in the KV (its
    -- conditions are the engine's business and are NOT claimed here).  What the
    -- corpus's one near-firing frame turns on is therefore a quantity this
    -- harness models as 0 -- that is the limit, not a verdict.
    assert(J.WillMagicKillTarget(bot, hLuna, nDmg * 1.15, Q_DELAY) == true,
        'at 15% spell amp the un-deadened branch fires on a real frame')

    local tShapes = dofile(SHAPES)
    local tInnate = tShapes.SHAPES['lion']['lion_to_hell_and_back']
    assert(tInnate and tInnate['spell_amp'] and tInnate['spell_amp'].base == '20',
        'the innate\'s declared spell_amp, read from the snapshot rather than remembered')

    -- The other enemy on the same frame is a control: 1261 hp is out of reach of
    -- any Earth Spike rank at any plausible amp, so the branch stays selective.
    for _, e in ipairs(tEnemies) do
        if e:GetUnitName() ~= 'npc_dota_hero_luna' then
            assert(J.WillMagicKillTarget(bot, e, nDmg * 2, Q_DELAY) == false,
                'armed must not confirm a kill on ' .. e:GetUnitName()
                .. ' at ' .. e:GetHealth() .. ' hp')
        end
    end
end

tests['[hero] LIMIT: the whole Lion corpus, scanned, holds no firing frame at amp 0'] = function()
    -- Exhaustive, so the "no firing frame" claim is a measurement.  Every Lion
    -- fixture, every living enemy within the kill loop's reach, at that frame's
    -- own Q rank -- and, since the -88 (甲) re-drive, at the damage the frame's
    -- own handle hands the helper rather than at Q_KV[nRank].
    local nFrames, nPairs, nFiring, nNearest = 0, 0, 0, math.huge
    local nAgree, nDisagree = 0, 0
    local p = assert(io.popen('ls tests/fixtures/f_*.lua 2>/dev/null'))
    local tPaths = {}
    for sLine in p:lines() do tPaths[#tPaths + 1] = sLine end
    p:close()
    assert(#tPaths > 20, 'fixture glob came back short: ' .. #tPaths)

    for _, sPath in ipairs(tPaths) do
        local fx = dofile(sPath)
        if fx and fx.self == 'npc_dota_hero_lion' then
            nFrames = nFrames + 1
            local X, J, bot = load_lion(true, true, sPath)
            local hQ = bot:GetAbilityByName(Q_NAME)
            local nRank = (hQ and hQ:GetLevel()) or 0
            if nRank >= 1 then
                local nDmg = X.GetImpaleKillDamage(hQ)
                -- The cross-check runs per frame, so a KV move shows up as a
                -- named disagreement instead of as a silently shifted ceiling.
                if nDmg == Q_KV[nRank] then nAgree = nAgree + 1 else nDisagree = nDisagree + 1 end
                for _, e in ipairs(J.GetNearbyHeroes(bot, 850, true, BOT_MODE_NONE)) do
                    nPairs = nPairs + 1
                    local nShort = e:GetHealth() - nDmg
                    if nShort < nNearest then nNearest = nShort end
                    if J.WillMagicKillTarget(bot, e, nDmg, Q_DELAY) then
                        nFiring = nFiring + 1
                    end
                end
            end
        end
    end

    assert(nFrames >= 7, 'expected the Lion fixture corpus, got ' .. nFrames .. ' frames')
    assert(nPairs >= 10, 'expected enemy-in-reach pairs to scan, got ' .. nPairs)
    assert(nAgree >= 7, 'the helper must be readable on the frames themselves; only '
        .. nAgree .. ' frames produced a getter reading, which means the loader stopped '
        .. 'serving GetSpecialValue* and this scan is driven by nothing')
    assert(nDisagree == 0, 'getter and ladder disagreed on ' .. nDisagree .. ' frame(s); the '
        .. 'KV moved, so re-read this section rather than editing Q_KV to match')
    assert(nFiring == 0, 'the corpus has no armed-leg firing frame at zero spell amp; if one '
        .. 'appears, this file has become able to assert the fire and should. Got ' .. nFiring)
    assert(nNearest == 45, 'and the nearest miss is 45 hp (Luna, ' .. FRAME_L4 .. '), got '
        .. nNearest)
end

-- ---------------------------------------------------------------------------
-- 5. Registered and NOT changed: the 5.0s delay, and the branch order.

tests['[hero] the 5.0s regen delay is the only literal in the repo, and is left alone'] = function()
    local nLiteral, nTotal = 0, 0
    local p = assert(io.popen('ls bots/BotLib/hero_*.lua bots/FunLib/*.lua bots/*.lua 2>/dev/null'))
    local tPaths = {}
    for sLine in p:lines() do tPaths[#tPaths + 1] = sLine end
    p:close()

    for _, sPath in ipairs(tPaths) do
        for sArgs in strip_comments(read_file(sPath)):gmatch('WillMagicKillTarget%(([^)]*)%)') do
            nTotal = nTotal + 1
            local sLast = sArgs:match(',%s*([^,]+)%s*$') or ''
            if sLast:match('^%s*[%d.]+%s*$') then nLiteral = nLiteral + 1 end
        end
    end

    assert(nTotal >= 30, 'expected the repo\'s WillMagicKillTarget call sites, got ' .. nTotal)
    assert(nLiteral == 1, 'exactly one call site passes a bare numeric delay -- Lion\'s Q kill '
        .. 'loop, 5.0s against a 0.3s cast point, every other site passing nCastPoint or a '
        .. 'travel-time expression. This is REGISTERED, not fixed: it is a second lever and '
        .. 'rides its own id when somebody prices it. Got ' .. nLiteral)
end

tests['[hero] the branch order the coverage argument rests on is still the source order'] = function()
    local sBody = body_of(strip_comments(read_file(LION)), 'ConsiderQ')

    -- The kill loop must stay FIRST; the reading above is about what covers the
    -- states it leaves behind, and that is an ordering claim.
    local nKill = assert(sBody:find('J.WillMagicKillTarget', 1, true), 'kill loop gone')
    for _, sGuard in ipairs{ 'nCanHurtEnemyAoE.count >= 3', 'J.IsInTeamFight( bot, 1200 )',
                             'J.IsGoingOnSomeone( bot )', 'J.IsRetreating( bot )' } do
        local nAt = sBody:find(sGuard, 1, true)
        assert(nAt and nAt > nKill, 'expected `' .. sGuard .. '` to still follow the kill loop')
    end
    -- And the catch-all really does carry a level floor -- the half that makes
    -- the uncovered set "below level 15" rather than "never".
    assert(sBody:find('nLV >= 15', 1, true),
        'the 常规 catch-all\'s level floor is load-bearing for the coverage reading')
end

-- ---------------------------------------------------------------------------
-- 6. LIMITS -- measured here, not asserted in prose.

-- RE-ANCHORED 2026-09-04 (hero, `kvgetters`).  THE LIMIT THIS CASE RECORDED IS
-- HALF GONE, and the half that went is the one that mattered.
--
-- ARCHIVED READING (until 2026-09-03): both legs read 0 offline -- the shipped
-- one because the mock has no AbilityDamage field, the armed one because
-- GetSpecialValue* was on the generic Get* default -- and the mock could not
-- even tell a real key from a fabricated one.  That is why the armed leg in the
-- sections above is driven on DECLARED fabrications rather than on the getter.
--
-- What changed: tests/mock/replay_fixture.lua now serves GetSpecialValue* out of
-- the KV snapshot (tests/test_fixture_kv_getters.lua), so `damage` answers the
-- real lion_impale ladder (105/170/235/300).  GetAbilityDamage was NOT served --
-- it is a different unspecced getter and this round deliberately took one small
-- batch -- so the shipped leg still reads 0.
--
-- ⇒ The two legs are now DIFFERENT offline, which is exactly what "no fixture
-- can separate them" said was impossible.
--
-- THE RE-DRIVE THIS PARAGRAPH ASKED FOR HAS HAPPENED (2026-09-04, backlog
-- -88 (甲)).  It used to end "whoever picks that lever up re-drives it through
-- the getter and re-reads §4 first"; §4 is now driven by X.GetImpaleKillDamage
-- on each frame's own handle, and Q_KV is a cross-check rather than the driver.
-- The re-read changed no number -- 8 frames, 11 pairs, 0 firing, nearest miss
-- 45 -- and that agreement is itself the reading: the fabrications the archived
-- world forced were faithful to the KV, which is a thing nobody could check
-- while the getter answered 0.  What did change is falsifiability: the old
-- section could not fail when the KV moved, because the ladder it asserted
-- against was the same ladder it was driven by.
--
-- WHAT IS STILL FABRICATED, AND CORRECTLY SO: §2 and §3 drive the helper on
-- make_impale handles because they need a NONZERO shipped reading (the
-- fallthrough, the negative-KV guard, the gate-off equality), and no frame in
-- this corpus supplies one -- GetAbilityDamage answers 0 on every Lion handle
-- offline.  That is a declared fabrication for a case a frame structurally
-- cannot make, not a leftover from the archived world.
--
-- This case pins the new asymmetry, and pins the one piece of the old limit
-- that survives -- a key nobody ever wrote still reads 0, so absence and zero
-- remain indistinguishable, which is GH #162 and is not repaired.
tests['LIMIT: the armed leg is readable offline now; the shipped leg is not, and absence still reads 0'] = function()
    local _, _, bot = load_lion(true, true)
    local h = bot:GetAbilityByName(Q_NAME)
    assert(h, 'the frame must resolve an Earth Spike handle')
    assert(h:GetAbilityDamage() == 0,
        'the mock has no AbilityDamage field, so the shipped leg reads 0 offline for a reason '
        .. 'unrelated to the KV -- the agreement with the real engine is a coincidence and '
        .. 'must not be cited as confirmation')

    local shapes = require('mock.special_value_shapes')
    local entry = shapes.SHAPES['lion'][Q_NAME] and shapes.SHAPES['lion'][Q_NAME][KEY]
    assert(entry ~= nil and entry.base ~= nil,
        'the KV snapshot no longer carries lion_impale/' .. KEY .. '; without it '
        .. 'this case is back to the archived world and cannot say so')
    local steps = {}
    for tok in entry.base:gmatch('%S+') do steps[#steps + 1] = tonumber(tok) end
    local rank = h:GetLevel()
    local want = steps[math.min(math.max(rank, 1), #steps)]
    local got = h:GetSpecialValueInt(KEY)
    assert(got == want, KEY .. ' reads ' .. tostring(got) .. ' at rank ' .. rank
        .. ', KV ladder says ' .. tostring(want) .. '. A 0 means the loader '
        .. 'stopped serving GetSpecialValue* and this file is back in the world '
        .. 'its section 4 numbers were taken in.')
    assert(got ~= h:GetAbilityDamage(),
        'the two legs read the same number offline again, so the separation this '
        .. 'case records has been lost')

    assert(h:GetSpecialValueInt('a_key_nobody_ever_wrote') == 0,
        'a key that never existed still reads 0, so ABSENCE and ZERO remain '
        .. 'indistinguishable -- GH #162 is not repaired by the KV getters, and '
        .. 'the armed leg above is still driven on declared fabrications for that '
        .. 'reason. If this ever answers non-zero the loader started inventing '
        .. 'values, which is worse than the zero it replaced.')
end

tests['LIMIT: the frames carry no regen and no resist, so the delay costs nothing here'] = function()
    local _, J, bot = load_lion(false, true)
    for _, e in ipairs(J.GetNearbyHeroes(bot, 850, true, BOT_MODE_NONE)) do
        assert(e:GetHealthRegen() == 0, 'make_fixture.py extracts no health regen')
        assert(e:GetMagicResist() == 0, 'nor magic resistance')
    end
    -- Consequence, stated so nobody reads §4's numbers as end-to-end truths:
    -- HealthBack = regen * nDelay = 0 offline, so `5.0` and `0.3` are the same
    -- number to this harness, and the resistance term is absent. Both make the
    -- readings above an UPPER bound on the real engine -- heroes carry 25% base
    -- magic resistance, so the 15% amp figure in §4 is a floor, not a threshold.
    local _, J2, bot2 = load_lion(false, true)
    local tE = J2.GetNearbyHeroes(bot2, 850, true, BOT_MODE_NONE)
    assert(J2.WillMagicKillTarget(bot2, tE[1], 100, 0.3)
        == J2.WillMagicKillTarget(bot2, tE[1], 100, 5.0),
        'offline the two delays are indistinguishable, by construction')
end

return tests

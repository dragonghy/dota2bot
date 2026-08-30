-- [hero] The firing-side fixture tests/test_zuus_static_field_pct.lua owed.
--
-- THE BATON THIS FILE TAKES
--
-- test_zuus_static_field_pct.lua:337 (hero stream, 2026-08-29) lifted its own
-- LIMIT and wrote the follow-up down rather than taking it:
--
--     "The follow-up this case's own text asked for -- 'a firing-side fixture
--      becomes possible and this file should grow one' -- is NOT taken here:
--      it is its own work unit and needs a frame where the static-field
--      percentage decides the verdict.  Baton: hero.md backlog."
--
-- The LIMIT that had blocked it was `GetActualIncomingDamage` answering 0 on
-- every handle (GH #154's 22nd world assertion), which is the LAST line of
-- J.WillMagicKillTarget:
--
--     local nRealDamage = npcTarget:GetActualIncomingDamage( EstDamage, nDamageType )
--     return nRealDamage >= npcTarget:GetHealth()          -- jmz_func.lua:1151
--
-- A constant 0 there makes that `return` constantly false, so "does the global
-- execute fire on this frame" was not a question any fixture could settle.  The
-- mock now answers the raw damage (tests/test_mock_incoming_damage_default.lua
-- pins it; no reduction modelled, i.e. an UPPER BOUND) -- so the question is
-- decidable, and this file settles it on a real frame.
--
-- THE FRAME, AND WHY IT IS THE ONE
--
-- tl_103216 @ t=473.5 (7:53) -- generated for a Crystal Maiden subject, re-loaded
-- here with Zeus as the subject (the frame carries both).  Everything below is
-- real frame data:
--
--   Zeus  lvl 9, 865/1000 HP, 566/824 mana, Thundergod's Wrath rank 1, cd 0.0
--   CM    lvl 9, 292/1110 HP, alive, 268 units away, modifier_stunned
--   and CM's own recent_damage column shows Zeus already burning her down over
--   the trailing 3.8s (17, 126, 20, 18, 24, 126, 31, 209).
--
-- So the ~130s global is OFF COOLDOWN and AFFORDABLE, and one enemy sits in the
-- range where the kill estimate is decided by nothing but the Static Field
-- percentage.  X.ConsiderR's per-enemy predicate (hero_zuus.lua:1099) is
--
--     local nEstDamage = nDamage + e:GetHealth() * abilityASBonus
--     if J.WillMagicKillTarget( bot, e, nEstDamage, nCastPoint ) and ...
--
-- and on this frame, with the rank-1 ult damage anchored from the repo's own
-- frozen KV snapshot (275):
--
--     shipped 0.09   ->  275 + 292*0.0900 = 301.28  >=  292   FIRES
--     KV 3.85% (lvl9)->  275 + 292*0.0385 = 286.24   <  292   does NOT fire
--     KV ceiling 4.95%-> 275 + 292*0.0495 = 289.45   <  292   does NOT fire
--
-- The break-even percentage this frame demands is (292-275)/292 = 5.82%.  The
-- whole KV band [3.45, 4.95] sits BELOW it and the shipped constant sits 1.55x
-- ABOVE it, so the flip does not depend on how the engine folds `hero_levelup`
-- -- the same reason §3 of the sibling file proves the band rather than a value.
--
-- WHAT IS ANCHORED RATHER THAN READ OFF THE FRAME
--
-- make_fixture.py extracts no ability specs, so three numbers come from
-- tests/mock/special_value_shapes.lua -- the repo's own frozen KV snapshot,
-- PARSED here rather than retyped, so a re-snapshot moves this file's arithmetic
-- with it instead of silently disagreeing:
--
--     zuus_thundergods_wrath / damage          = "275 425 575"   -> rank 1 = 275
--     zuus_thundergods_wrath / AbilityManaCost = "250 375 500"   -> rank 1 = 250
--     zuus_thundergods_wrath / AbilityCastPoint= "0.4 0.4 0.4 0.4"
--     zuus_static_field      / damage_health_pct = 3.45, hero_levelup +0.05
--
-- BOTH LEGS ARM `zusbind`.  hero_zuus.lua says so in its own doc block:
-- "`zusstatic` armed without `zusbind` armed measures the wrong ability's
-- missing key, i.e. 0", and tests/test_zuus_ability_index_binding.lua measured
-- that `sAbilityList[5]` is Static Field in ZERO of the eight worlds.  Offline
-- the slot is nil, so an unbound run gives BOTH legs a bonus of 0 and the
-- comparison under test would not exist.  Arming `zusbind` on both legs is what
-- isolates GH #173's question -- the PERCENTAGE -- from GH #175's question --
-- the HANDLE.  The contrast here is therefore
--
--     leg A  zusbind armed, zusstatic OFF  -> bonus 0.09     (the shipped constant)
--     leg B  zusbind armed, zusstatic ON   -> bonus KV/100   (the game's own number)
--
-- ⚠️ MEASURED LIMIT -- §6, AND IT IS THE HALF A READER MUST NOT SKIP
--
-- The mock models NO damage reduction.  Real heroes carry 25% base magic
-- resistance, and J.WillMagicKillTarget's last line runs the estimate through
-- GetActualIncomingDamage, so in game both thresholds shrink by the resistance
-- factor.  §6 measures what that costs: swept over every fixture in the corpus,
-- the in-band pair count is 1 at multiplier 1.00 (this frame) and 0 at 0.75.
-- So this file pins THE DECISION FUNCTION on a real frame; it does NOT claim
-- that this exact cast happened in game, and it does NOT license reading the
-- corpus 0 at 0.75 as "the band is never reached" -- 51 Zeus-carrying frames is
-- not a frequency estimate.  Condition (a) for `zusstatic` still has to be
-- bought from a wave (queue hero-15).
--
-- What IS model-independent, and is the property condition (a) rests on:
-- `target:GetHealth() * bonus` is >= 0 always and armed only ever LOWERS the
-- bonus, so the armed leg's firing set is a SUBSET of the shipped leg's at every
-- resistance factor.  §4 drives that direction rather than asserting it.

package.path = 'tests/?.lua;' .. package.path

local rf = require('mock.replay_fixture')

local FRAME  = 'tests/fixtures/f_260820_103216_cm_es_aftershock.lua'
local SHAPES = 'tests/mock/special_value_shapes.lua'
local ZUUS   = 'bots/BotLib/hero_zuus.lua'

local ULT     = 'zuus_thundergods_wrath'
local STATIC  = 'zuus_static_field'
local SUBJECT = 'npc_dota_hero_zuus'
local TARGET  = 'npc_dota_hero_crystal_maiden'

local SHIPPED_PCT = 0.09          -- asserted against the Lua in §7, not trusted

-- ---------------------------------------------------------------------------
-- KV anchors, parsed out of the frozen snapshot rather than retyped.

--- The n-th per-level entry of a KV "a b c" base string, clamped to the last.
local function per_level(sBase, nRank)
    local t = {}
    for w in tostring(sBase):gmatch('%S+') do t[#t + 1] = tonumber(w) end
    assert(#t > 0, 'no numeric entries in KV base string ' .. tostring(sBase))
    return t[math.min(nRank, #t)]
end

local function kv(sAbility, sKey)
    local shapes = assert(dofile(SHAPES).SHAPES['zuus'], 'no zuus block in the KV snapshot')
    local ab = assert(shapes[sAbility], 'no KV block for ' .. sAbility)
    return assert(ab[sKey], sAbility .. ' has no key ' .. sKey)
end

local ULT_DAMAGE_R1 = per_level(kv(ULT, 'damage').base, 1)
local ULT_MANA_R1   = per_level(kv(ULT, 'AbilityManaCost').base, 1)
local ULT_CASTPOINT = per_level(kv(ULT, 'AbilityCastPoint').base, 1)
local SF_BASE       = tonumber(kv(STATIC, 'damage_health_pct').base)
local SF_PER_LEVEL  = tonumber((kv(STATIC, 'damage_health_pct').bonus['hero_levelup']:gsub('%+', '')))

-- The band the KV can reach at all: level 1 to the game's cap of 31.
local KV_MIN = SF_BASE
local KV_MAX = SF_BASE + SF_PER_LEVEL * 30

-- ---------------------------------------------------------------------------

--- Load the frame with Zeus as the subject, anchor the ult's three KV specs and
--- give `zuus_static_field` the handle the engine would supply for an innate.
--- bStatic arms 'zusstatic' on top of 'zusbind'; bTurbo == false kills the gate.
local function load_zeus(bStatic, bTurbo)
    local J, bot, heroes, fx = rf.load(FRAME, SUBJECT)

    local abilityR = bot:GetAbilityByName(ULT)
    local sR = rawget(abilityR, '__spec')
    sR.GetSpecialValueInt = function(_, sKey)
        if sKey == 'damage' then return ULT_DAMAGE_R1 end
        return 0
    end
    sR.GetManaCost = ULT_MANA_R1
    sR.GetCastPoint = ULT_CASTPOINT

    -- DECLARED FABRICATION: Static Field is innate + hidden, so no .dem carries
    -- it and the loader creates no handle (measured in the sibling file's §5).
    -- In game it is trained from level 1 and answers `damage_health_pct`; here
    -- that is supplied, and the percentage supplied is the KV value at the
    -- frame's own real Zeus level.
    local nPct = SF_BASE + SF_PER_LEVEL * (bot:GetLevel() - 1)
    local hStatic = bot:GetAbilityByName(STATIC)
    local sS = rawget(hStatic, '__spec')
    sS.GetLevel = 1
    sS.IsTrained = function() return true end
    sS.GetSpecialValueFloat = function(_, sKey)
        if sKey == 'damage_health_pct' then return nPct end
        return 0
    end

    if bTurbo == false then
        GetGameMode = function() return GAMEMODE_ALLPICK end
    end
    J.IsSoakCandidate = function(id)
        if id == 'zusbind' then return true end
        if id == 'zusstatic' then return bStatic == true end
        return false
    end

    local X = rf.load_hero('zuus')
    return X, J, bot, heroes, abilityR, hStatic, fx, nPct
end

local tests = {}

-- ---------------------------------------------------------------------------
-- 1. Ground truth -- every assertion here is real frame data.

tests['[hero] ground truth: the global is ready and one enemy is in the band'] = function()
    local _, _, bot, heroes, abilityR, _, fx = load_zeus(false)

    assert(fx.time == 473.5, 'the frame is t=473.5, got ' .. tostring(fx.time))
    assert(bot:GetUnitName() == SUBJECT, 'subject re-pointed at Zeus')
    assert(bot:GetLevel() == 9, 'Zeus is level 9, got ' .. bot:GetLevel())
    assert(bot:GetMana() == 566, 'real mana on the frame, got ' .. bot:GetMana())

    assert(abilityR:GetLevel() == 1, 'Thundergod\'s Wrath is rank 1')
    assert(abilityR:GetCooldownTimeRemaining() == 0, 'the global is OFF COOLDOWN')
    assert(abilityR:IsFullyCastable(),
        '566 mana pays the ' .. ULT_MANA_R1 .. ' cost -- ConsiderR does NOT bail on line 1')

    local cm = heroes[TARGET]
    assert(cm ~= nil and cm:IsAlive(), 'Crystal Maiden is alive on this frame')
    assert(cm:GetTeam() ~= bot:GetTeam(), 'and she is an enemy')
    assert(cm:GetHealth() == 292, 'CM is at 292 HP, got ' .. cm:GetHealth())
    local d = GetUnitToUnitDistance(bot, cm)
    assert(d > 200 and d < 350, 'CM is ~268 units away, got ' .. math.floor(d))
end

tests['[hero] ground truth: no OTHER enemy is anywhere near the band'] = function()
    -- The ult is global, so ConsiderR's loop walks every enemy hero. If a second
    -- one were near the threshold the flip below could not be attributed to CM.
    local _, _, bot = load_zeus(false)
    local nNear, nTotal = 0, 0
    for _, e in pairs(GetUnitList(UNIT_LIST_ENEMY_HEROES)) do
        if e ~= nil and e:IsAlive() then
            nTotal = nTotal + 1
            if e:GetUnitName() ~= TARGET then
                -- The most generous estimate any leg can produce.
                local nEst = ULT_DAMAGE_R1 + e:GetHealth() * SHIPPED_PCT
                if nEst >= e:GetHealth() * 0.9 then nNear = nNear + 1 end
            end
        end
    end
    assert(nTotal == 5, 'the frame carries five live enemy heroes, got ' .. nTotal)
    assert(nNear == 0,
        'CM must be the only enemy the estimate can reach, got ' .. nNear .. ' others')
end

-- ---------------------------------------------------------------------------
-- 2. The anchors, so a re-snapshot of the KV is loud rather than silent.

tests['[hero] the three anchored ult specs come from the frozen KV snapshot'] = function()
    assert(ULT_DAMAGE_R1 == 275, 'rank-1 Thundergod damage is 275 in the snapshot, got '
        .. tostring(ULT_DAMAGE_R1))
    assert(ULT_MANA_R1 == 250, 'rank-1 mana cost is 250, got ' .. tostring(ULT_MANA_R1))
    assert(ULT_CASTPOINT == 0.4, 'cast point is 0.4, got ' .. tostring(ULT_CASTPOINT))
    assert(SF_BASE == 3.45 and SF_PER_LEVEL == 0.05,
        'Static Field is 3.45 +0.05/level in the snapshot, got '
        .. tostring(SF_BASE) .. ' +' .. tostring(SF_PER_LEVEL))
end

tests['[hero] the frame sits BETWEEN the KV ceiling and the shipped constant'] = function()
    local _, _, _, heroes = load_zeus(false)
    local nHP = heroes[TARGET]:GetHealth()
    -- The percentage this frame demands for the estimate to reach lethal.
    local nBreakEven = (nHP - ULT_DAMAGE_R1) / nHP
    assert(nBreakEven > KV_MAX / 100,
        'the KV ceiling ' .. KV_MAX .. '% must fall SHORT of the break-even '
        .. string.format('%.2f%%', nBreakEven * 100))
    assert(nBreakEven < SHIPPED_PCT,
        'and the shipped constant must clear it -- otherwise there is no flip')
end

-- ---------------------------------------------------------------------------
-- 3. The flip, driven through the REAL helper on ConsiderR's exact expression.

--- ConsiderR's per-enemy estimate (hero_zuus.lua:1099), built from the real
--- X.GetStaticFieldBonus rather than a retyped constant.
local function will_kill(bStatic)
    local X, J, bot, heroes, _, hStatic = load_zeus(bStatic)
    local nBonus = X.GetStaticFieldBonus(X.GetBoundAbility(hStatic, STATIC))
    local cm = heroes[TARGET]
    local nEst = ULT_DAMAGE_R1 + cm:GetHealth() * nBonus
    return J.WillMagicKillTarget(bot, cm, nEst, ULT_CASTPOINT), nBonus, nEst, cm:GetHealth()
end

tests['[hero] the shipped 0.09 declares the kill on the real frame'] = function()
    local bKill, nBonus, nEst, nHP = will_kill(false)
    assert(nBonus == SHIPPED_PCT, 'gate off is the shipped constant, got ' .. tostring(nBonus))
    assert(bKill == true,
        'shipped estimate ' .. string.format('%.2f', nEst) .. ' vs ' .. nHP
        .. ' HP must read LETHAL -- this is the cast the ~130s cooldown pays for')
end

tests['[hero] the KV percentage retracts it -- the constant IS the decision'] = function()
    local bKill, nBonus, nEst, nHP = will_kill(true)
    assert(nBonus > 0 and nBonus < SHIPPED_PCT,
        'armed reads the KV percentage, got ' .. tostring(nBonus))
    assert(bKill == false,
        'KV estimate ' .. string.format('%.2f', nEst) .. ' vs ' .. nHP
        .. ' HP must read SURVIVES')
end

tests['[hero] armed but NOT turbo keeps the shipped verdict'] = function()
    local X, J, bot, heroes, _, hStatic = load_zeus(true, false)
    local nBonus = X.GetStaticFieldBonus(X.GetBoundAbility(hStatic, STATIC))
    assert(nBonus == SHIPPED_PCT, 'the gate is turbo-only, got ' .. tostring(nBonus))
    local cm = heroes[TARGET]
    assert(J.WillMagicKillTarget(bot, cm, ULT_DAMAGE_R1 + cm:GetHealth() * nBonus,
        ULT_CASTPOINT) == true, 'so the non-turbo verdict is the shipped one')
end

-- ---------------------------------------------------------------------------
-- 4. The whole KV band, and the direction that survives any damage model.

tests['[hero] the retraction holds across the ENTIRE KV band [3.45, 4.95]'] = function()
    local _, J, bot, heroes = load_zeus(true)
    local cm = heroes[TARGET]
    for nPct = KV_MIN, KV_MAX + 1e-9, 0.05 do
        local nEst = ULT_DAMAGE_R1 + cm:GetHealth() * (nPct / 100)
        assert(J.WillMagicKillTarget(bot, cm, nEst, ULT_CASTPOINT) == false,
            'a KV percentage of ' .. string.format('%.2f', nPct)
            .. '% must still fall short -- the flip must not depend on how the '
            .. 'engine folds hero_levelup')
    end
end

tests['[hero] armed can only ever retract, never invent -- driven, not asserted'] = function()
    -- The one-sided property condition (a) rests on. Swept over every live enemy
    -- on the frame and over the whole KV band, armed's firing set must be a
    -- SUBSET of shipped's. A percentage above 0.09 anywhere would break it.
    local _, J, bot = load_zeus(true)
    local nChecked = 0
    for _, e in pairs(GetUnitList(UNIT_LIST_ENEMY_HEROES)) do
        if e ~= nil and e:IsAlive() then
            local nShipped = ULT_DAMAGE_R1 + e:GetHealth() * SHIPPED_PCT
            local bShipped = J.WillMagicKillTarget(bot, e, nShipped, ULT_CASTPOINT)
            for nPct = KV_MIN, KV_MAX + 1e-9, 0.05 do
                local nArmed = ULT_DAMAGE_R1 + e:GetHealth() * (nPct / 100)
                local bArmed = J.WillMagicKillTarget(bot, e, nArmed, ULT_CASTPOINT)
                assert(not (bArmed and not bShipped),
                    'armed fired where shipped did not, on ' .. e:GetUnitName()
                    .. ' at ' .. string.format('%.2f', nPct) .. '%')
                nChecked = nChecked + 1
            end
        end
    end
    assert(nChecked == 5 * 31, 'five enemies x 31 band steps, got ' .. nChecked)
end

-- ---------------------------------------------------------------------------
-- 5. End to end -- the ACTION QUEUE, not the helper's return value
--    (test_set.md §0b).  X.ConsiderR is dispatched first in X.SkillsComplement
--    and returns early with ActionQueue_UseAbility( abilityR ), so the global
--    reaching the queue is the whole decision.

local function run_skills(bStatic)
    local X, J, bot, heroes, abilityR, hStatic = load_zeus(bStatic)
    local log = rf.record_actions(bot)
    X.SkillsComplement()
    local t = {}
    for _, e in ipairs(log) do
        if e.fn:find('UseAbility') then
            local a = e.args[1]
            t[#t + 1] = (type(a) == 'table' and a.GetName) and a:GetName() or tostring(a)
        end
    end
    return t, X, J, bot, heroes, abilityR, hStatic
end

local function contains(t, s)
    for _, v in ipairs(t) do if v == s then return true end end
    return false
end

tests['[hero] end to end: shipped cashes the ~130s global on this frame'] = function()
    local names = run_skills(false)
    assert(contains(names, ULT),
        'the shipped estimate must put Thundergod\'s Wrath on the queue, got {'
        .. table.concat(names, ',') .. '}')
end

tests['[hero] end to end: the KV percentage keeps it -- the final decision moves'] = function()
    local names = run_skills(true)
    assert(not contains(names, ULT),
        'armed, the global must NOT reach the action queue, got {'
        .. table.concat(names, ',') .. '}')
end

-- ---------------------------------------------------------------------------
-- 6. The measured LIMIT.  Read the header before quoting any number here.

--- Every (fixture, live enemy hero) pair the corpus offers with a Zeus who owns
--- a trained ultimate, scored under a declared damage multiplier.
local function corpus_band_count(nMult)
    local fh = assert(io.popen('ls tests/fixtures/f_*.lua 2>/dev/null'))
    local nBand, nDomain, sWhere = 0, 0, nil
    for sPath in fh:lines() do
        local ok, fx = pcall(dofile, sPath)
        if ok and type(fx) == 'table' and type(fx.units) == 'table' then
            local z
            for _, u in ipairs(fx.units) do
                if u.name == SUBJECT then z = u end
            end
            local nRank = 0
            for _, a in ipairs((z or {}).abilities or {}) do
                if a.name == ULT then nRank = a.level end
            end
            if z and nRank > 0 then
                local nDmg = per_level(kv(ULT, 'damage').base, nRank)
                local nKV = (SF_BASE + SF_PER_LEVEL * (z.level - 1)) / 100
                for _, u in ipairs(fx.units) do
                    if u.team ~= z.team and u.alive
                        and u.name:find('^npc_dota_hero_') then
                        nDomain = nDomain + 1
                        local bShip = (nDmg + u.hp * SHIPPED_PCT) * nMult >= u.hp
                        local bArm  = (nDmg + u.hp * nKV) * nMult >= u.hp
                        if bShip and not bArm then
                            nBand = nBand + 1
                            sWhere = sPath .. ' / ' .. u.name
                        end
                    end
                end
            end
        end
    end
    fh:close()
    return nBand, nDomain, sWhere
end

tests['[hero] LIMIT: the corpus offers exactly ONE in-band pair, and it is this frame'] = function()
    local nBand, nDomain, sWhere = corpus_band_count(1.0)
    -- A LOWER BOUND, not an equality (GH #273's shape): the corpus grows, and a
    -- new fixture must not turn this into a failure that says nothing. Measured
    -- 2026-08-30: 167 pairs across the 37 fixtures whose Zeus owns a trained
    -- ultimate (51 carry Zeus at all).
    assert(nDomain > 150, 'the domain must be non-trivial, got ' .. nDomain .. ' pairs')
    assert(nBand == 1, 'expected exactly one in-band pair at multiplier 1.00, got ' .. nBand)
    assert(sWhere:find('103216_cm_es_aftershock', 1, true)
        and sWhere:find('crystal_maiden', 1, true),
        'and it must be the frame this file pins, got ' .. tostring(sWhere))
end

tests['[hero] LIMIT: under 25% base magic resist the corpus offers NONE'] = function()
    -- NOT "the band is never reached": the band moves down (~[212, 221] HP at
    -- rank 1) and 51 Zeus-carrying frames is not a frequency estimate. What this
    -- pins is that the flip above lives in the mock's declared no-reduction
    -- model, so nobody may quote it as an in-game count.
    local nBand, nDomain = corpus_band_count(0.75)
    assert(nDomain > 150, 'same domain (167 measured 2026-08-30), got ' .. nDomain)
    assert(nBand == 0, 'expected no in-band pair at multiplier 0.75, got ' .. nBand)
end

-- ---------------------------------------------------------------------------
-- 7. Wiring -- cheap tripwires, so the arithmetic above cannot drift off the
--    code it claims to be about.

tests['[hero] the shipped constant is still 0.09 and still the last statement'] = function()
    local fh = assert(io.open(ZUUS, 'r'))
    local src = fh:read('*a'); fh:close()
    -- NOTE the parentheses: string.find returns TWO values and `s:sub(s:find(..))`
    -- silently becomes sub(start, stop), i.e. the match itself rather than the
    -- tail. That slip made this tripwire fail on a file that was perfectly fine.
    local nAt = (src:find('function X.GetStaticFieldBonus', 1, true))
    assert(nAt, 'X.GetStaticFieldBonus must still exist in ' .. ZUUS)
    local body = src:sub(nAt)
    body = body:sub(1, (body:find('\nend', 1, true)))
    assert(body:find('return 0.09', 1, true),
        'the gate-off constant this file compares against must still be 0.09')
    assert(body:find("J.IsSoakCandidate( 'zusstatic' )", 1, true),
        'and the KV branch must still be gated behind zusstatic')
end

tests['[hero] ConsiderR still consumes the bonus the way §3 models it'] = function()
    local fh = assert(io.open(ZUUS, 'r'))
    local src = fh:read('*a'); fh:close()
    assert(src:find('local nEstDamage = nDamage + e:GetHealth() * abilityASBonus', 1, true),
        'the global-execute loop must still build its estimate this way')
    assert(src:find('J.WillMagicKillTarget( bot, e, nEstDamage, nCastPoint )', 1, true),
        'and must still route it through the helper §3 drives')
    assert(src:find("abilityASBonus = X.GetStaticFieldBonus( X.GetBoundAbility( abilityAS, 'zuus_static_field' ) )", 1, true),
        'and SkillsComplement must still feed it through both gates')
end

return tests

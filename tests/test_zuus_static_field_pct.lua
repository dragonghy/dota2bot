-- [hero] GH #173 -- Zeus's Static Field percentage was a hardcoded 0.09, and the
-- game's own KV says it is 3.45% rising to ~4.9%.  Behaviour change, so it ships
-- GATED ('zusstatic', turbo-only).  Every step of the reasoning is pinned here.
--
-- WHAT WAS FOUND
--
-- hero_zuus.lua carried, in X.SkillsComplement:
--
--     if abilityAS:IsTrained() then abilityASBonus = 0.09 end
--
-- and `abilityASBonus` has exactly two consumers, both of them kill estimates:
--
--   * X.ConsiderW, the ranged-creep snipe:
--       targetRanged:GetHealth() < GetActualIncomingDamage(nDamage +
--           targetRanged:GetHealth() * abilityASBonus, MAGICAL)
--   * X.ConsiderR, the `lowHPCount` loop -- the one that decides whether the
--       ~130s map-wide execute gets cashed in at all.
--
-- The game's KV for `zuus_static_field` (d2vpkr mirror, the same source
-- tools/agent/gen_ability_meta.py and tools/agent/special_value_key_census.py
-- already read; fetched 2026-08-25):
--
--     "zuus_static_field"
--     {
--         "MaxLevel"   "1"
--         "Innate"     "1"
--         "AbilityValues"
--         {
--             "damage_health_pct"
--             {
--                 "value"        "3.45"
--                 "hero_levelup" "+0.05"
--                 "special_bonus_unique_zeus_static_field_dmg" "+2"
--                 "display_type" "kMagicalDamagePercentage"
--             }
--         }
--     }
--
-- So the live percentage is 3.45 at hero level 1 and rises by 0.05 per hero
-- level -- about 4.95 at level 31, the highest it can reach without the t2x
-- talent.  The shipped 0.09 is therefore between 1.8x and 2.6x the truth at
-- EVERY level the ability can be at, and the error is in the OPTIMISTIC
-- direction: the bot credits itself with damage it will not deal, believes a
-- target is finishable, and spends the global ultimate (or a 100+ mana bolt) on
-- someone who lives.  Which is the same failure the hero backlog's Zeus item
-- (§4, "没蓝放大") already blames for missed execute windows, reached through a
-- different door -- mana burned on a kill that was never there.
--
-- WHAT THE FIX IS NOT
--
-- It is NOT "Static Field only hits heroes".  That was this desk's first
-- hypothesis and the localisation killed it before a line was written:
--
--   DOTA_Tooltip_ability_zuus_static_field_Description
--   "Zeus shocks any enemy that he attacks or is hit by his abilities, causing
--    damage equal to a percentage of their current health."
--
-- "any enemy" -- creeps included -- so the ConsiderW creep-snipe call site is
-- applying the term to a legitimate target and only the NUMBER was wrong.  The
-- reading `GetHealth() * pct` (current health, not max) matches the tooltip too.
-- Recorded because a later reader will have the same idea.
--
-- THE SHAPE OF THE CHANGE (why gate-off equivalence is structural)
--
-- X.GetStaticFieldBonus keeps the shipped constant as the function's LAST
-- statement and the armed branch is the only detour; the `IsTrained()` guard
-- runs first, in the same position and with the same operation sequence as the
-- shipped line.  Armed, a key that answers <= 0 drops the term rather than
-- inventing a default (the house rule from GH #162).  §2/§3 make those claims
-- falsifiable.
--
-- ⚠️ LIMIT -- MEASURED IN §5, NOT ASSERTED, AND IT IS WHY THERE IS NO
-- FIRING-SIDE FIXTURE
--
--   * Static Field is `Innate 1` + hidden, so no .dem carries it: on the Zeus
--     fixtures `J.Skill.GetAbilityList(bot)[5]` is nil and the file-local
--     `abilityAS` is a handle for a nil name whose IsTrained() is false.  That
--     is why the helper takes the handle as a PARAMETER -- otherwise neither leg
--     could be driven offline at all.  Same family as GH #151.
--   * tests/mock/bot_api.lua answers 0 for every `Get*` it does not know, so
--     GetSpecialValueFloat is 0 for every key -- offline the armed leg reads 0,
--     not 3.45.  Same class as GH #162/#133/#145.
--   * GetActualIncomingDamage answers 0 on every live handle (the 22nd world
--     assertion, GH #154), so J.WillMagicKillTarget cannot be driven to a
--     truthful answer offline and "does the ult fire on this frame" is not a
--     question a fixture can settle.
--
-- So the frame in §4 is used for what it CAN carry truthfully -- the real
-- current-health of the five enemy heroes and the real level of the Zeus
-- looking at them -- and the phantom damage is computed from those.  Condition
-- (a) has to be bought from the corpus; the request is queue hero-15.
--
-- WHAT THIS FILE DOES NOT CLAIM
--
--   * That the engine hands back 3.85 at level 9.  How `hero_levelup` folds
--     into GetSpecialValueFloat is the engine's business; §3 therefore proves
--     the tightening for the WHOLE band [3.45, 4.95] rather than one value.
--   * That a Zeus on the `zuus_livewire` facet reads this key at all (that
--     facet's damage lives under damage_health_pct_min_close / _max_close,
--     which are not in this hero KV file).  Armed, such a Zeus would read <= 0
--     here and lose the term -- conservative, and recorded rather than hidden.
--   * That tightening the estimate WINS games.  Locally-correct is not
--     emergently-good (AGENTS.md, the lanefix lesson).  That is what the gate
--     is for.

package.path = 'tests/?.lua;' .. package.path

local api = require('mock.bot_api')
local rf  = require('mock.replay_fixture')

local SNAPSHOT = 'tests/mock/special_value_keys.lua'
local ZUUS     = 'bots/BotLib/hero_zuus.lua'
local FRAME    = 'tests/fixtures/f_230952_zuus_ult_hoard.lua'

local CAND_ID = 'zusstatic'
local KEY     = 'damage_health_pct'
local SHIPPED = 0.09

-- The KV band, from the block quoted above: 3.45 at hero level 1, +0.05 per
-- level.  31 is the highest hero level the game allows.
local KV_MIN = 3.45
local KV_MAX = 3.45 + 0.05 * 30

local function read_file(sPath)
    local fh = assert(io.open(sPath, 'r'), 'cannot open ' .. sPath)
    local s = fh:read('*a'); fh:close()
    return s
end

--- Strip Lua line comments BEFORE anything is counted.  The reasoning block
--- above quotes both `0.09` and the key name while explaining them, and a
--- parser that reads prose reports the prose (GH #136's first census).
local function strip_comments(src)
    return (src:gsub('%-%-[^\n]*', ''))
end

--- Build an ability handle that answers like a trained Static Field with a
--- given percentage.  A declared fabrication, not a frame reading (§5 measures
--- why no frame can supply one).
local function make_static_field(nPct, bTrained)
    return api.MakeUnit{
        GetUnitName = 'zuus_static_field',
        IsTrained = bTrained ~= false,
        GetSpecialValueFloat = function(_, sKey)
            if sKey == KEY then return nPct end
            return 0
        end,
    }
end

--- Load Zeus on the real frame, set the mode and the gate, return (X, J, bot).
--- GetGameMode is set BEFORE the hero file loads because J.IsModeTurbo memoises
--- its answer on first call (bModeTurboCache).
local function load_zuus(bArmed, bTurbo)
    local J, bot = rf.load(FRAME)

    if bTurbo == false then
        GetGameMode = function() return GAMEMODE_ALLPICK end
    end
    J.IsSoakCandidate = bArmed
        and function(sId) return sId == CAND_ID end
        or function() return false end

    return rf.load_hero('zuus'), J, bot
end

local tests = {}

-- ---------------------------------------------------------------------------
-- 1. The source shape: a ratchet on where the constant may live.

tests['[hero] the shipped 0.09 survives exactly once, as the helper\'s last word'] = function()
    local src = strip_comments(read_file(ZUUS))

    local n = select(2, src:gsub('0%.09', ''))
    assert(n == 1, 'the shipped constant must appear exactly once (it IS the gate-off '
        .. 'answer, and a second copy would be an ungated call site), got ' .. n)

    local sHelper = src:match('function X%.GetStaticFieldBonus%b()(.-)\nend')
    assert(sHelper, 'X.GetStaticFieldBonus is gone; the call site would be ungated')
    assert(sHelper:find('0.09', 1, true), 'the shipped constant lives inside the helper')
    assert(sHelper:find("IsSoakCandidate( '" .. CAND_ID .. "' )", 1, true),
        'the correction must sit behind IsSoakCandidate(' .. CAND_ID .. ')')
    assert(sHelper:find('IsModeTurbo', 1, true), 'and behind IsModeTurbo (turbo-only, AGENTS.md)')
    assert(sHelper:find(KEY, 1, true), 'and it must read ' .. KEY .. ' off the ability')

    -- The shipped constant is the LAST statement: gate-off is the shipped path
    -- by construction, not by measurement.
    local sTail = sHelper:match('(return[^\n]*)%s*$')
    assert(sTail and sTail:find('0.09', 1, true),
        'the helper must END on the shipped constant, got ' .. tostring(sTail))
end

tests['[hero] SkillsComplement takes the bonus from the helper and nowhere else'] = function()
    local src = strip_comments(read_file(ZUUS))
    local sComplement = src:match('function X%.SkillsComplement%(%)(.-)\nend\n')
    assert(sComplement, 'X.SkillsComplement not found')
    -- RE-POINTED 2026-08-26 (zusbind, GH #203): the handle is no longer taken
    -- raw.  `abilityAS` is sAbilityList[5], and index 5 is Static Field in none
    -- of the eight drop-worlds (tests/test_zuus_ability_index_binding.lua), so
    -- the assignment now routes through X.GetBoundAbility.  The ratchet is
    -- re-aimed rather than relaxed: it still demands ONE assignment, still
    -- demands the helper, and now also demands that the routed name is the
    -- ability this file's percentage is about.
    assert(sComplement:find(
        "X.GetStaticFieldBonus( X.GetBoundAbility( abilityAS, 'zuus_static_field' ) )", 1, true),
        'the one assignment must go through the helper, with the routed file-local handle')

    -- abilityASBonus is written in exactly two places: the per-tick reset and
    -- the helper call.  A third write would be a leg nothing here is watching.
    local nWrites = select(2, src:gsub('abilityASBonus%s*=', ''))
    assert(nWrites == 3, 'expected the declaration, the reset and the helper call = 3 '
        .. 'writes to abilityASBonus, got ' .. nWrites)
end

-- ---------------------------------------------------------------------------
-- 2. The helper's own behaviour, on a fabricated handle.

tests['gate off: the answer is the shipped 0.09, whatever the KV says'] = function()
    local X = load_zuus(false, true)
    assert(X.GetStaticFieldBonus(make_static_field(KV_MIN)) == SHIPPED,
        'gate off must be byte-for-byte the shipped constant')
    assert(X.GetStaticFieldBonus(make_static_field(0)) == SHIPPED,
        'and it must not consult the key at all -- a dead key changes nothing off-gate')
end

tests['gate on: the answer is the KV percentage, as a fraction'] = function()
    local X = load_zuus(true, true)
    local nGot = X.GetStaticFieldBonus(make_static_field(3.45))
    assert(math.abs(nGot - 0.0345) < 1e-12, 'expected 0.0345, got ' .. tostring(nGot))
end

tests['gate on but NOT turbo: unchanged (turbo-only, AGENTS.md)'] = function()
    local X = load_zuus(true, false)
    assert(X.GetStaticFieldBonus(make_static_field(3.45)) == SHIPPED,
        'the correction is turbo-only')
end

tests['untrained Static Field is 0 on both legs -- the shipped guard, unmoved'] = function()
    local Xoff = load_zuus(false, true)
    assert(Xoff.GetStaticFieldBonus(make_static_field(3.45, false)) == 0,
        'gate off: an untrained passive contributes nothing (the shipped IsTrained guard)')
    local Xon = load_zuus(true, true)
    assert(Xon.GetStaticFieldBonus(make_static_field(3.45, false)) == 0,
        'gate on: same guard, same answer, and it must run BEFORE the gate')
end

tests['gate on: a key that answers <= 0 drops the term, it does not invent one'] = function()
    local X = load_zuus(true, true)
    assert(X.GetStaticFieldBonus(make_static_field(0)) == 0,
        'a renamed/absent key must not silently restore 0.09 (GH #162 house rule)')
    assert(X.GetStaticFieldBonus(make_static_field(-1)) == 0, 'nor may a negative read pass through')
end

-- ---------------------------------------------------------------------------
-- 3. The direction of the change, over the whole KV band.
--
-- The claim that matters for a soak candidate is not "0.0345 < 0.09" at one
-- point but that the armed leg can never be MORE optimistic than the shipped
-- leg anywhere the KV can go.

tests['[hero] armed is never more optimistic than shipped, across the KV band'] = function()
    local X = load_zuus(true, true)
    local nPct = KV_MIN
    local nSeen = 0
    while nPct <= KV_MAX + 1e-9 do
        local nArmed = X.GetStaticFieldBonus(make_static_field(nPct))
        assert(nArmed < SHIPPED, 'armed (' .. nArmed .. ') must stay under the shipped '
            .. SHIPPED .. ' at pct ' .. nPct)
        nSeen = nSeen + 1
        nPct = nPct + 0.05
    end
    assert(nSeen == 31, 'the band is one reading per hero level 1..31, got ' .. nSeen)

    -- And the size of the correction, so a KV drift that halves it is visible.
    assert(X.GetStaticFieldBonus(make_static_field(KV_MAX)) / SHIPPED < 0.56,
        'even at the top of the band the shipped constant is >1.8x the truth')
end

-- ---------------------------------------------------------------------------
-- 4. The real frame: what the shipped constant invents, in HP, on live enemies.

tests['[hero] real frame 230952 t=567: the shipped constant invents 162-222 HP'] = function()
    local _, _, bot = load_zuus(true, true)
    assert(bot:GetLevel() == 9, 'the frame is a level-9 Zeus; if that moved, so did the frame')

    local tEnemies = GetUnitList(UNIT_LIST_ENEMY_HEROES)
    local nLive, nPhantomMin, nPhantomMax, nShipped = 0, 0, 0, 0
    for _, e in pairs(tEnemies) do
        if e ~= nil and e:IsAlive() then
            local nHP = e:GetHealth()
            assert(nHP > 0, 'a live enemy with no health is a broken frame read')
            nLive = nLive + 1
            nShipped = nShipped + nHP * SHIPPED
            nPhantomMin = nPhantomMin + nHP * (SHIPPED - KV_MAX / 100)
            nPhantomMax = nPhantomMax + nHP * (SHIPPED - KV_MIN / 100)
            -- Per-enemy, not just in aggregate: every single one is overcredited.
            assert(nHP * SHIPPED > nHP * (KV_MAX / 100),
                'the shipped constant must overcredit EVERY live enemy on the frame')
        end
    end

    assert(nLive == 5, 'the frame carries five live enemy heroes, got ' .. nLive)
    assert(nShipped > 350 and nShipped < 370,
        'shipped credits ~360 HP of Static Field across the frame, got ' .. nShipped)
    assert(nPhantomMin > 160 and nPhantomMin < 165,
        'at the top of the KV band the invented damage is ~162 HP, got ' .. nPhantomMin)
    assert(nPhantomMax > 218 and nPhantomMax < 224,
        'at the bottom of the band it is ~222 HP, got ' .. nPhantomMax)
end

-- ---------------------------------------------------------------------------
-- 5. The LIMIT, measured rather than asserted.

tests['LIMIT: no .dem carries Static Field -- sAbilityList[5] is nil on the frame'] = function()
    local _, J, bot = load_zuus(true, true)
    local tList = J.Skill.GetAbilityList(bot)
    assert(tList[5] == nil, 'if a dump ever carries the innate, this test should be revisited '
        .. '-- it currently reads ' .. tostring(tList[5]))
    assert(tList[1] == 'zuus_arc_lightning' and tList[6] == 'zuus_thundergods_wrath',
        'the rest of the list is real, so the nil above is the innate and not a broken load')

    -- Which is exactly why the helper takes a parameter: the file-local handle
    -- answers false here, so BOTH legs read 0 on any untouched fixture.
    local hNil = bot:GetAbilityByName(tList[5])
    assert(hNil:IsTrained() == false, 'the handle for a nil name is untrained')
end

tests['LIMIT: offline every GetSpecialValue key reads 0, armed included'] = function()
    local _, _, bot = load_zuus(true, true)
    local h = bot:GetAbilityByName('zuus_lightning_bolt')
    assert(h:GetSpecialValueFloat(KEY) == 0, KEY .. ' reads 0 under the mock')
    assert(h:GetSpecialValueFloat('a_key_nobody_ever_wrote') == 0,
        'and so does a key that never existed -- the mock cannot tell them apart')
end

tests['LIMIT: GetActualIncomingDamage is 0, so the firing side cannot be driven'] = function()
    local _, _, bot = load_zuus(true, true)
    for _, e in pairs(GetUnitList(UNIT_LIST_ENEMY_HEROES)) do
        if e ~= nil and e:IsAlive() then
            assert(e:GetActualIncomingDamage(500, DAMAGE_TYPE_MAGICAL) == 0,
                'the 22nd world assertion (GH #154) still holds; if it stops holding, '
                .. 'a firing-side fixture becomes possible and this file should grow one')
        end
    end
end

-- ---------------------------------------------------------------------------
-- 6. The KV shape the reading rests on -- so a patch breaks this file loudly.

tests['[hero] damage_health_pct is a live Zeus key in the frozen KV snapshot'] = function()
    api.install({})
    local tZuus = assert(dofile(SNAPSHOT).KEYS['zuus'], 'no KV snapshot for zuus')
    assert(tZuus[KEY] == true, KEY .. ' must be a zuus ability key -- if Valve renames it the '
        .. 'armed leg silently loses the term, which is the GH #162 failure mode')

    -- Corroboration inside the same snapshot, so the presence above is not a
    -- fetch that half-succeeded.
    for _, sKey in ipairs({ 'damage', 'hop_distance', 'arc_damage' }) do
        assert(tZuus[sKey] == true, 'expected sibling key ' .. sKey .. ' in the snapshot')
    end
end

return tests

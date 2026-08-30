-- [ratchet] [hero] The SECOND consumer of `abilityASBonus` -- X.ConsiderW's
-- ranged-creep snipe -- priced at last.  Baton left by the hero charter's
-- backlog item -50 (2026-08-30T01:54Z) and carried unmeasured through -51, -52
-- and -53: "`abilityASBonus` 的第二个消费方 `X.ConsiderW` 仍未量".
--
-- Tagged `[ratchet]` so routine_selfcheck.sh's fast Lua leg reads it every
-- round: §6 is a coupling ratchet that has to go red the DAY somebody fixes the
-- other defect, not a round later.
--
-- ZERO behaviour change.  `bots/BotLib/hero_zuus.lua` gains corrected comment
-- text and no executable line; no new gate id; `zusstatic` / `zusbind` /
-- `zusboltcap` keep their gates and their armed state exactly as they were.
--
-- ---------------------------------------------------------------------------
-- WHAT WAS ASKED
--
-- `zusstatic` (GH #173) replaces Zeus's hardcoded 0.09 Static Field percentage
-- with the KV's 3.45% + 0.05/level.  The id has TWO consumers of the resulting
-- `abilityASBonus`, and only one of them has ever been measured:
--
--   * X.ConsiderR (hero_zuus.lua:1099) -- the `lowHPCount` loop that decides
--     whether the ~130s global execute is cashed in.  Measured 2026-08-30 in
--     tests/test_replay_260820_zuus_static_band.lua: one frame in the whole
--     fixture corpus where the 0.09 alone decides, band (286, 302] at rank 1.
--   * X.ConsiderW (hero_zuus.lua:795) -- the ranged-creep snipe.  NOT measured.
--
-- Backlog -50 pre-registered an expectation for the second one, in writing:
--
--     "它的带在**创兵血量尺度**上、`nDamage` 是雷击不是大招,**可能宽一个量级**"
--     (its band is on the CREEP-health scale, its nDamage is the bolt and not
--      the ult, so it may be an order of magnitude WIDER)
--
-- ---------------------------------------------------------------------------
-- WHAT WAS FOUND -- the band is EMPTY, and not by a little
--
-- The site is one expression (hero_zuus.lua:793-795):
--
--     local nDamage = abilityW:GetAbilityDamage() * ( 1 + bot:GetSpellAmp() )
--     ...
--     targetRanged:GetHealth() < targetRanged:GetActualIncomingDamage(
--         nDamage + targetRanged:GetHealth() * abilityASBonus, DAMAGE_TYPE_MAGICAL )
--
-- Write `m` for the resistance factor GetActualIncomingDamage applies, `D` for
-- nDamage, `b` for abilityASBonus and `h` for the creep's health.  The branch
-- fires iff
--
--     h < m * (D + h*b)      <=>      h * (1 - m*b) < m*D
--
-- and `abilityW` is `zuus_lightning_bolt`, whose `GetAbilityDamage()` read is
-- PROVEN ZERO (§2: this patch's KV declares no top-level `AbilityDamage` on any
-- Zeus ability at all, so the read is 0 whichever handle it lands on -- GH #175's
-- census, tests/mock/ability_damage.lua).  D = 0 collapses the predicate to
--
--     h < m*b*h      <=>      1 < m*b
--
-- **The target's health cancels.**  That is the finding: this is not a kill
-- estimate that has become pessimistic, it is a health-FREE constant.  It is
-- false for every creep at every health at every rank, and the break-even is
-- `b >= 1/m >= 1.0` -- Static Field would have to take **at least 100% of the
-- target's current health**.  Shipped 0.09 is 11.1x short of that; the armed KV
-- band 3.45%-4.95% is 20.2x-29.0x short.  A CEILING, not a margin: no
-- percentage this id can ever carry revives the branch, so arming `zusstatic`
-- cannot move this consumer, and neither can rejecting it.
--
-- ---------------------------------------------------------------------------
-- THE PRE-REGISTERED EXPECTATION IS FALSIFIED TWICE OVER
--
-- Not only is the band not "an order of magnitude wider" -- it is exactly zero.
-- And the counterfactual (§5) refuses the guess in the other direction too.
-- Both sites have the SAME algebraic form, so solving each for the firing
-- threshold gives `h < m*D/(1 - m*b)` and the width of the band between the two
-- legs is
--
--     W(D) = m*D * [ 1/(1 - m*b_shipped) - 1/(1 - m*b_armed) ]
--
-- i.e. **strictly proportional to D and to nothing else about the site**.  The
-- creep-health scale never enters.  So if GH #175's other direction is ever
-- fixed and D becomes the bolt's KV damage, this band is
-- `D_bolt / D_ult` times the ult's band: 140/575 to 380/275, i.e.
-- **0.24x to 1.38x** -- the same order of magnitude, bracketing 1.  The
-- "creep-health scale" intuition priced the wrong quantity: what sets the band
-- is the flat damage term, and the bolt's is SMALLER than the ult's at three of
-- the four rank pairings.
--
-- ---------------------------------------------------------------------------
-- WHAT THIS BUYS THE ID (and the string attached to it)
--
-- TODAY the ConsiderR measurement IS the whole `zusstatic` id: its second
-- consumer has empty domain, so nothing is being left out of the (a) reading
-- queue hero-15 is buying.  That is a strictly BETTER position than the one
-- backlog -50 recorded ("只看大招的读数不得代表整个 id") -- but it is
-- CONDITIONAL, and the condition lives in a different id's defect:
--
--     the day `zuus` acquires a nonzero top-level `AbilityDamage`, or the day
--     the site at :795 stops reading GetAbilityDamage(), the second consumer
--     re-opens and the (a) reading silently stops covering the id.
--
-- §6 is that tripwire.  It is the whole reason this file is `[ratchet]`.
--
-- ---------------------------------------------------------------------------
-- TWO SENTENCES CORRECTED (comment-only, in the same change)
--
-- hero_zuus.lua:819 and tests/test_zuus_bolt_kill_cap.lua:47-49 both said the
-- zero is "fed to J.WillMagicKillTarget over in X.ConsiderW, where it KILLS the
-- branch".  Two things wrong with that, and §7 pins both:
--
--   1. J.WillMagicKillTarget has exactly one call site in this file and it is in
--      X.ConsiderR (:1100), not X.ConsiderW.  X.ConsiderW's kill test is the
--      inline GetActualIncomingDamage comparison at :795.  The two sites also
--      take their flat damage from DIFFERENT calls -- ConsiderR from
--      GetSpecialValueInt('damage') (nonzero, 275 at rank 1), ConsiderW from
--      GetAbilityDamage() (zero).  The sentence attached the zero to the site
--      that does not have it.
--   2. "a 0-damage nuke finishes nobody" gets the right verdict off the wrong
--      shape.  The estimate at :795 is not 0 -- it still carries `h*b`.  What
--      the zero removes is the SCALE, and that is what makes the deadness
--      total and percentage-proof rather than marginal.  Same family as the
--      corrections this stream landed on GH #328 (WK t25) and GH #330 (OD
--      double-spend): the verdict survived, the shape of the defect did not.
--
-- ---------------------------------------------------------------------------
-- WARNING -- LIMITS, MEASURED OR DECLARED, NOT GLOSSED
--
--   * The `m` ladder is driven, but the mock models no resistance by default
--     (tests/mock/bot_api.lua returns the raw damage, an UPPER bound).  §3
--     therefore drives m over a declared ladder INCLUDING m = 1.0, the most
--     generous world there is.  The conclusion needs no `m` at all: it holds
--     for every m <= 11.1, and creeps do not amplify magic damage by 1010%.
--   * NO fixture in this corpus carries lane creeps -- make_fixture.py extracts
--     heroes.  So "how often is X.ConsiderW's last branch REACHED" is not a
--     question this file can answer, and it does not try.  It answers "when
--     reached, can it fire", which is the question the band was about.  §4's
--     ranged creep is a DECLARED FABRICATION handed to the real X.ConsiderW on
--     a real frame.
--   * The spell-amp factor `( 1 + bot:GetSpellAmp() )` multiplies a zero and is
--     therefore irrelevant TODAY.  It is not irrelevant in §5's counterfactual;
--     §5 states its own assumption (amp = 0) rather than hiding it.
--   * GH #175's proof of the zero is one-directional and stays that way: a hero
--     that HAS a nonzero AbilityDamage proves nothing about a particular site.
--     Zeus has none, which is the direction that proves.

package.path = 'tests/?.lua;' .. package.path

local api = require('mock.bot_api')
local rf  = require('mock.replay_fixture')

local ZUUS    = 'bots/BotLib/hero_zuus.lua'
local BOLTCAP = 'tests/test_zuus_bolt_kill_cap.lua'
local SHAPES  = 'tests/mock/special_value_shapes.lua'
local DAMAGES = 'tests/mock/ability_damage.lua'
local FRAME   = 'tests/fixtures/f_260819_222052_zuus_w2_leak.lua'

local SUBJECT = 'npc_dota_hero_zuus'
local BOLT    = 'zuus_lightning_bolt'
local ULT     = 'zuus_thundergods_wrath'
local STATIC  = 'zuus_static_field'

-- ---------------------------------------------------------------------------
-- KV anchors, parsed out of the frozen snapshot rather than retyped.

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

local SF_BASE      = tonumber(kv(STATIC, 'damage_health_pct').base)
local SF_PER_LEVEL = tonumber((kv(STATIC, 'damage_health_pct').bonus['hero_levelup']:gsub('%+', '')))

-- The percentage band the KV can reach at all: hero level 1 to the cap of 31.
local KV_MIN_PCT = SF_BASE
local KV_MAX_PCT = SF_BASE + SF_PER_LEVEL * 30

local function read_file(sPath)
    local fh = assert(io.open(sPath, 'r'), 'cannot open ' .. sPath)
    local s = fh:read('*a'); fh:close()
    return s
end

--- Strip Lua line comments BEFORE anything is counted: this file's own
--- reasoning block quotes the call names it is about, and a parser that reads
--- prose reports the prose (GH #136's first census).
local function strip_comments(src)
    return (src:gsub('%-%-[^\n]*', ''))
end

local function body_of(src, sFunc)
    local sBody = src:match('function X%.' .. sFunc .. '%(.-%)(.-)\nend\n')
    assert(sBody, 'X.' .. sFunc .. ' not found in ' .. ZUUS)
    return sBody
end

--- The shipped constant, read off the Lua instead of retyped.  §1 pins that it
--- is still the last statement of X.GetStaticFieldBonus.
local SHIPPED_PCT
do
    local sBody = body_of(strip_comments(read_file(ZUUS)), 'GetStaticFieldBonus')
    SHIPPED_PCT = tonumber(sBody:match('return%s+([%d%.]+)%s*\n%s*$'))
    assert(SHIPPED_PCT ~= nil, 'X.GetStaticFieldBonus no longer ends on a numeric return')
end

local tests = {}

-- ---------------------------------------------------------------------------
-- 1. The source shape.  Everything below is arithmetic ON this expression, so
--    the expression is pinned first; the day it moves, this file is wrong and
--    says so rather than quietly measuring something else.

tests['[ratchet] [1] the second consumer is one expression and it has the shape the math assumes'] = function()
    local src   = strip_comments(read_file(ZUUS))
    local sBody = body_of(src, 'ConsiderW')

    assert(sBody:find('local nDamage = abilityW:GetAbilityDamage() * ( 1 + bot:GetSpellAmp() )', 1, true),
        'X.ConsiderW must still take its flat damage from GetAbilityDamage() -- that is '
            .. 'the term §2 proves is zero')
    assert(sBody:find('targetRanged:GetHealth() < targetRanged:GetActualIncomingDamage( nDamage '
            .. '+ targetRanged:GetHealth() * abilityASBonus , DAMAGE_TYPE_MAGICAL )', 1, true),
        'the ranged-creep predicate must still be the two-term estimate this file prices')

    -- abilityASBonus has exactly two readers in the whole file. A third would be
    -- a consumer nothing has priced, which is the situation backlog -50 was
    -- complaining about in the first place.
    local nReads = select(2, src:gsub('abilityASBonus', ''))
    assert(nReads == 5,
        'expected 5 mentions of abilityASBonus -- the declaration, the per-tick '
            .. 'reset, the SkillsComplement assignment, and its TWO reads (ConsiderR '
            .. 'and ConsiderW). Got ' .. nReads .. ': a consumer moved or a third one '
            .. 'appeared, and a third one would be exactly the unpriced consumer '
            .. 'backlog -50 was complaining about. Re-derive this file before trusting it.')

    local sR = body_of(src, 'ConsiderR')
    assert(sR:find('local nEstDamage = nDamage + e:GetHealth() * abilityASBonus', 1, true),
        'the FIRST consumer (the priced one) must still be in X.ConsiderR')
    assert(sR:find('nDamage = abilityR:GetSpecialValueInt( \'damage\' )', 1, true),
        'and it must still take its flat damage from GetSpecialValueInt, NOT '
            .. 'GetAbilityDamage -- the asymmetry is the whole reason one site is dead '
            .. 'and the other is not')
end

tests['[ratchet] [1b] J.WillMagicKillTarget has one call site and it is not ConsiderW'] = function()
    local src = strip_comments(read_file(ZUUS))
    local nTotal = select(2, src:gsub('J%.WillMagicKillTarget', ''))
    assert(nTotal == 1, 'expected exactly 1 J.WillMagicKillTarget call in hero_zuus.lua, got '
        .. nTotal)

    assert(body_of(src, 'ConsiderR'):find('J.WillMagicKillTarget', 1, true),
        'that one call belongs to X.ConsiderR')
    assert(not body_of(src, 'ConsiderW'):find('J.WillMagicKillTarget', 1, true),
        'and X.ConsiderW does NOT call it -- the claim §7 corrects')
end

-- ---------------------------------------------------------------------------
-- 2. The zero is PROVEN, not assumed -- and proven twice, from two frozen
--    snapshots that are generated by two different censuses.

tests['[ratchet] [2] no Zeus ability declares a nonzero top-level AbilityDamage'] = function()
    local nonzero = assert(dofile(DAMAGES).NONZERO, 'ability_damage.lua has no NONZERO table')
    assert(nonzero['zuus'] == nil,
        'zuus now appears in the AbilityDamage census. GetAbilityDamage() inside '
            .. 'hero_zuus.lua is no longer provably zero, so the ENTIRE pricing in this '
            .. 'file is void -- re-derive it, do not adjust this assertion. See §6.')

    -- The census's proof is per-hero and needs no handle resolution: a read
    -- inside hero_<h>.lua can only land on one of <h>'s own abilities.
    local nHeroes = 0
    for _ in pairs(nonzero) do nHeroes = nHeroes + 1 end
    assert(nHeroes >= 1,
        'the census is empty, which would mean it failed to parse rather than that '
            .. 'no hero declares one')
end

tests['[ratchet] [2b] the bolt keeps its damage in AbilityValues, where GetAbilityDamage cannot see it'] = function()
    local shapes = assert(dofile(SHAPES).SHAPES['zuus'], 'no zuus block in the KV snapshot')
    local bolt = assert(shapes[BOLT], 'no KV block for ' .. BOLT)

    assert(bolt['AbilityDamage'] == nil,
        BOLT .. ' now declares a top-level AbilityDamage. Same consequence as [2].')
    assert(bolt['damage'] ~= nil and bolt['damage'].base ~= nil,
        'and its per-level damage must still live in AbilityValues/damage')
    assert(bolt['damage'].base == '140 220 300 380',
        'the bolt ladder moved to ' .. tostring(bolt['damage'].base)
            .. '; §5\'s counterfactual is parsed from it, so re-read §5 rather than '
            .. 'patching this string')
end

-- ---------------------------------------------------------------------------
-- 3. The degeneration, DRIVEN.  The real X.GetStaticFieldBonus supplies both
--    legs' `b`; the real mock GetActualIncomingDamage supplies `m`; the health
--    ladder is swept.  Nothing here is a restatement of the algebra.

--- A handle that answers like Static Field at a given percentage.
local function make_static(nPct)
    return api.MakeUnit{
        GetUnitName = STATIC,
        IsTrained = function() return true end,
        GetSpecialValueFloat = function(_, sKey)
            if sKey == 'damage_health_pct' then return nPct end
            return 0
        end,
    }
end

--- A ranged creep at health h whose magic resistance factor is m.
local function make_creep(h, m)
    return api.MakeUnit{
        GetUnitName = 'npc_dota_creep_badguys_ranged',
        GetHealth = h,
        IsAlive = true,
        GetActualIncomingDamage = function(_, dmg) return dmg * m end,
    }
end

local HEALTH_LADDER = { 1, 5, 25, 50, 100, 150, 200, 250, 300, 400, 550, 700, 1000, 2000 }
local M_LADDER      = { 1.00, 0.90, 0.75, 0.50, 0.25 }

tests['[ratchet] [3] with D = 0 the predicate is health-free and false on every leg'] = function()
    local J = rf.load(FRAME, SUBJECT)
    local X = rf.load_hero('zuus')

    local nChecked, nFired = 0, 0
    for _, m in ipairs(M_LADDER) do
        for _, h in ipairs(HEALTH_LADDER) do
            -- Shipped leg and the whole armed KV band, through the real helper.
            local tLegs = { { false, 0 } }
            for p = KV_MIN_PCT, KV_MAX_PCT + 1e-9, 0.05 do
                tLegs[#tLegs + 1] = { true, p }
            end

            for _, leg in ipairs(tLegs) do
                J.IsSoakCandidate = leg[1]
                    and function(id) return id == 'zusstatic' end
                    or function() return false end
                local b = X.GetStaticFieldBonus(make_static(leg[2]))
                local creep = make_creep(h, m)
                -- The shipped expression, with nDamage = 0 as §2 proves it is.
                if creep:GetHealth() < creep:GetActualIncomingDamage(
                        0 + creep:GetHealth() * b, DAMAGE_TYPE_MAGICAL) then
                    nFired = nFired + 1
                end
                nChecked = nChecked + 1
            end
        end
    end

    assert(nFired == 0,
        'the ranged-creep snipe fired ' .. nFired .. ' time(s) out of ' .. nChecked
            .. '. With nDamage = 0 it cannot: re-read §2 before believing this run.')
    -- 32 legs per (m, h): the shipped 0.09 plus the 31 KV steps from 3.45% to
    -- 4.95% -- the whole percentage range the id can ever reach, levels 1 to 31.
    local nWant = #M_LADDER * #HEALTH_LADDER * 32
    assert(nChecked == nWant, 'expected ' .. nWant .. ' drives, got ' .. nChecked)
end

tests['[ratchet] [3b] the break-even is a ceiling: b would have to reach 100% of current health'] = function()
    local J = rf.load(FRAME, SUBJECT)
    local X = rf.load_hero('zuus')

    J.IsSoakCandidate = function() return false end
    local bShipped = X.GetStaticFieldBonus(make_static(0))
    assert(math.abs(bShipped - SHIPPED_PCT) < 1e-12,
        'gate off must hand back the shipped constant, got ' .. tostring(bShipped))

    J.IsSoakCandidate = function(id) return id == 'zusstatic' end
    local bArmedLo = X.GetStaticFieldBonus(make_static(KV_MIN_PCT))
    local bArmedHi = X.GetStaticFieldBonus(make_static(KV_MAX_PCT))

    -- Firing needs m*b > 1 and m <= 1, so b > 1 is necessary at ANY resistance.
    for _, pair in ipairs{ { 'shipped', bShipped }, { 'armed lo', bArmedLo }, { 'armed hi', bArmedHi } } do
        assert(pair[2] < 1.0,
            pair[1] .. ' bonus is ' .. pair[2] .. ', i.e. >= 100% of the target\'s current '
                .. 'health. That is the ONLY world where this branch can fire, and it is '
                .. 'not this one.')
    end

    -- The shortfall factors quoted in the header, computed not retyped.
    local fShipped = 1.0 / bShipped
    local fArmedHi = 1.0 / bArmedHi
    local fArmedLo = 1.0 / bArmedLo
    assert(math.abs(fShipped - 11.111) < 0.01, 'shipped shortfall ' .. fShipped .. 'x, recorded 11.1x')
    assert(math.abs(fArmedHi - 20.202) < 0.01, 'armed best-case shortfall ' .. fArmedHi .. 'x, recorded 20.2x')
    assert(math.abs(fArmedLo - 28.986) < 0.01, 'armed worst-case shortfall ' .. fArmedLo .. 'x, recorded 29.0x')
end

-- ---------------------------------------------------------------------------
-- 4. End to end on a REAL frame: the real X.ConsiderW, both legs.
--    X.GetRanged is replaced (declared fabrication: no fixture carries creeps),
--    everything downstream of it is the shipped code.

local function consider_w_on(bArmed, h, m)
    local J, bot = rf.load(FRAME, SUBJECT)
    J.IsSoakCandidate = function(id)
        if id == 'zusbind' then return true end
        if id == 'zusstatic' then return bArmed == true end
        return false
    end

    -- The innate is hidden, so no .dem carries a handle for it (GH #151's
    -- family, measured in the sibling file). Supply the one the engine would,
    -- at the KV percentage for this frame's real Zeus level.
    local nPct = SF_BASE + SF_PER_LEVEL * (bot:GetLevel() - 1)
    local sS = rawget(bot:GetAbilityByName(STATIC), '__spec')
    sS.GetLevel = 1
    sS.IsTrained = function() return true end
    sS.GetSpecialValueFloat = function(_, sKey)
        if sKey == 'damage_health_pct' then return nPct end
        return 0
    end

    local X = rf.load_hero('zuus')
    local creep = make_creep(h, m)
    X.GetRanged = function() return creep end

    X.SkillsComplement()          -- the only thing that assigns abilityASBonus
    local nDesire, hTarget = X.ConsiderW()
    return nDesire, hTarget, bot, nPct, creep
end

tests['[ratchet] [4] ground truth: the bolt really is castable on this frame'] = function()
    local _, bot = rf.load(FRAME, SUBJECT)
    assert(bot:GetUnitName() == SUBJECT, 'subject is Zeus')
    assert(bot:GetLevel() == 8, 'Zeus is level 8 on this frame, got ' .. bot:GetLevel())
    assert(bot:GetMana() == 152, 'real mana on the frame, got ' .. bot:GetMana())

    local w = bot:GetAbilityByName(BOLT)
    assert(w ~= nil, 'the frame carries a Lightning Bolt handle')
    assert(w:GetLevel() == 4, 'the bolt is rank 4, got ' .. w:GetLevel())
    assert(w:GetCooldownTimeRemaining() == 0, 'and it is OFF COOLDOWN')
    assert(w:IsFullyCastable(),
        '152 mana pays the rank-4 cost -- X.ConsiderW does not bail on line 1')
end

tests['[ratchet] [4b] end to end: neither leg snipes the creep, at any health'] = function()
    for _, h in ipairs(HEALTH_LADDER) do
        for _, bArmed in ipairs{ false, true } do
            local nDesire, hTarget = consider_w_on(bArmed, h, 1.00)
            assert(nDesire == BOT_ACTION_DESIRE_NONE,
                (bArmed and 'armed' or 'shipped') .. ' leg bid ' .. tostring(nDesire)
                    .. ' on a ' .. h .. ' HP ranged creep. The branch that bids HIGH here '
                    .. 'is the snipe, and §3 says it cannot fire.')
            assert(hTarget == nil, 'and it must hand back no target, got ' .. tostring(hTarget))
        end
    end
end

tests['[ratchet] [4c] and the reason is the zero, not the gate: restoring D fires it'] = function()
    -- The counterfactual, driven rather than argued: hand X.ConsiderW a bolt
    -- whose GetAbilityDamage() answers the KV number, change nothing else, and
    -- the same creep is sniped. Without this, [4b] proves only that SOMETHING
    -- upstream is false.
    local J, bot = rf.load(FRAME, SUBJECT)
    J.IsSoakCandidate = function(id) return id == 'zusbind' end
    local sW = rawget(bot:GetAbilityByName(BOLT), '__spec')
    sW.GetAbilityDamage = function() return per_level(kv(BOLT, 'damage').base, 4) end

    local X = rf.load_hero('zuus')
    local creep = make_creep(100, 1.00)
    X.GetRanged = function() return creep end

    X.SkillsComplement()
    local nDesire, hTarget = X.ConsiderW()
    assert(nDesire == BOT_ACTION_DESIRE_HIGH,
        'with the KV damage restored the 100 HP creep must be sniped, got ' .. tostring(nDesire)
            .. '. If this is NONE, the branch is dead for a second reason this file '
            .. 'has not found, and [4b] does not mean what it says.')
    assert(hTarget == creep, 'and the target must be that creep')
end

-- ---------------------------------------------------------------------------
-- 5. The counterfactual band -- the number backlog -50 asked for, under the
--    assumption that makes it answerable, stated in the open.

--- Width of the band between the two legs at flat damage D and resistance m.
--- Assumes spell amp 0 (declared: the shipped site multiplies D by 1+amp, and
--- amp is 0 on every fixture the corpus carries).
local function band_width(D, m, bShipped, bArmed)
    return m * D * (1.0 / (1.0 - m * bShipped) - 1.0 / (1.0 - m * bArmed))
end

tests['[ratchet] [5] the band is proportional to D alone -- creep health never enters'] = function()
    local bS, bA = SHIPPED_PCT, KV_MIN_PCT / 100

    -- Same D, same m, wildly different health scales: the width does not move,
    -- because it does not depend on health at all. Driven against the shipped
    -- predicate rather than asserted off the formula.
    for _, m in ipairs(M_LADDER) do
        for _, D in ipairs{ 140, 275, 380, 575 } do
            local nLo = m * D / (1 - m * bA)
            local nHi = m * D / (1 - m * bS)
            -- Below the armed threshold both fire; above the shipped one neither
            -- does; strictly between, exactly the shipped leg fires.
            local tProbe = { nLo * 0.5, (nLo + nHi) / 2, nHi * 1.5 }
            local tWant  = { 'both', 'shipped', 'neither' }
            for i, h in ipairs(tProbe) do
                local bFireS = h < m * (D + h * bS)
                local bFireA = h < m * (D + h * bA)
                local sGot = (bFireS and bFireA and 'both')
                    or (bFireS and 'shipped') or (not bFireA and 'neither') or 'armed-only'
                assert(sGot == tWant[i],
                    'at D=' .. D .. ' m=' .. m .. ' h=' .. string.format('%.1f', h)
                        .. ' expected ' .. tWant[i] .. ', got ' .. sGot)
            end
            assert(math.abs(band_width(D, m, bS, bA) - (nHi - nLo)) < 1e-9,
                'the closed form and the thresholds must agree at D=' .. D)
        end
    end
end

tests['[ratchet] [5b] "an order of magnitude wider" is refused: 0.24x to 1.38x'] = function()
    local bS, bA = SHIPPED_PCT, KV_MIN_PCT / 100
    local tBolt = { per_level(kv(BOLT, 'damage').base, 1), per_level(kv(BOLT, 'damage').base, 4) }
    local tUlt  = { per_level(kv(ULT,  'damage').base, 1), per_level(kv(ULT,  'damage').base, 3) }

    assert(tBolt[1] == 140 and tBolt[2] == 380, 'bolt ladder parsed as 140..380')
    assert(tUlt[1] == 275 and tUlt[2] == 575, 'ult ladder parsed as 275..575')

    -- The ratio of the two sites' bands is exactly the ratio of their flat
    -- damages -- everything else in W(D) cancels. Checked at each m rather than
    -- taken on faith.
    for _, m in ipairs(M_LADDER) do
        local rLo = band_width(tBolt[1], m, bS, bA) / band_width(tUlt[2], m, bS, bA)
        local rHi = band_width(tBolt[2], m, bS, bA) / band_width(tUlt[1], m, bS, bA)
        assert(math.abs(rLo - 140 / 575) < 1e-9, 'lo ratio drifted at m=' .. m)
        assert(math.abs(rHi - 380 / 275) < 1e-9, 'hi ratio drifted at m=' .. m)
        assert(rLo > 0.1 and rHi < 10.0,
            'the two bands are within an order of magnitude of each other at m=' .. m
                .. ' (' .. string.format('%.2f', rLo) .. 'x .. '
                .. string.format('%.2f', rHi) .. 'x). Backlog -50 pre-registered '
                .. '"maybe an order of magnitude WIDER"; that is refused here, and the '
                .. 'refusal is recorded rather than the expectation being edited.')
    end

    -- And the absolute widths, for whoever prices the fix to GH #175.
    local nMin, nMax = math.huge, 0
    for _, m in ipairs{ 1.00, 0.75 } do
        for _, D in ipairs(tBolt) do
            local w = band_width(D, m, bS, bA)
            nMin = math.min(nMin, w); nMax = math.max(nMax, w)
        end
    end
    assert(math.abs(nMin - 4.81) < 0.01, 'narrowest counterfactual band ' .. nMin .. ' HP, recorded 4.81')
    assert(math.abs(nMax - 24.00) < 0.01, 'widest counterfactual band ' .. nMax .. ' HP, recorded 24.00')
end

-- ---------------------------------------------------------------------------
-- 6. THE COUPLING RATCHET. The reason this file is read every round.

tests['[ratchet] [6] the day the second consumer re-opens, the (a) reading stops covering the id'] = function()
    local nonzero = assert(dofile(DAMAGES).NONZERO, 'ability_damage.lua has no NONZERO table')
    local src = strip_comments(read_file(ZUUS))
    local sBody = body_of(src, 'ConsiderW')

    local bZeroStillProven = (nonzero['zuus'] == nil)
        and sBody:find('abilityW:GetAbilityDamage()', 1, true) ~= nil

    assert(bZeroStillProven,
        'X.ConsiderW\'s flat damage is no longer a provable zero. The consequence is '
            .. 'NOT in this file: `zusstatic`\'s condition (a) is being bought on the '
            .. 'ConsiderR consumer alone (queue hero-15), and that was only the whole id '
            .. 'because this consumer had empty domain. It no longer does. Re-open the '
            .. 'second consumer in the (a) definition BEFORE reading any verdict, and '
            .. 'price the band with §5 (' .. string.format('%.1f', 4.81) .. '-'
            .. string.format('%.1f', 24.00) .. ' HP at amp 0).')

    -- The sibling gate is untouched by this file and must stay that way: the
    -- OTHER direction of the same zero (widening ConsiderW2) is `zusboltcap`'s,
    -- filed and not fixed here (GH #166: never two directions in one predicate).
    assert(src:find("J.IsSoakCandidate( 'zusboltcap' )", 1, true),
        'zusboltcap must still gate the other direction of the same zero')
    assert(not sBody:find('zusboltcap', 1, true),
        'and it must NOT have reached into X.ConsiderW -- that would be this file '
            .. 'silently un-deadening a kill branch')
end

-- ---------------------------------------------------------------------------
-- 7. The two corrected sentences stay corrected.

tests['[ratchet] [7] neither file still says ConsiderW feeds J.WillMagicKillTarget'] = function()
    -- The correction convention in this repo QUOTES the retired sentence
    -- (backlog -52: the ratchet's first version went red on a file that was
    -- correct, because correcting HERE means citing the original). So the rule
    -- is not "never appears" but "appears only under a correction marker".
    -- A quoted sentence spans lines; the window is the paragraph, not the line.
    local WINDOW = 14
    for _, sPath in ipairs{ ZUUS, BOLTCAP } do
        local tLines = {}
        for sLine in (read_file(sPath) .. '\n'):gmatch('([^\n]*)\n') do
            tLines[#tLines + 1] = sLine
        end
        local nFound, nCovered = 0, 0
        for i, sLine in ipairs(tLines) do
            if sLine:find('J.WillMagicKillTarget over in X.ConsiderW', 1, true)
                or sLine:find('J.WillMagicKillTarget, where it KILLS', 1, true) then
                nFound = nFound + 1
                for j = math.max(1, i - WINDOW), i do
                    if tLines[j]:find('CORRECTED 2026-08-30', 1, true) then
                        nCovered = nCovered + 1
                        break
                    end
                end
            end
        end
        assert(nFound >= 1,
            sPath .. ' no longer quotes the retired sentence at all. This repo corrects '
                .. 'by citing; a correction that deletes its own subject cannot be '
                .. 'audited. Restore the quote inside the correction block.')
        assert(nCovered == nFound,
            sPath .. ' carries the retired claim on ' .. (nFound - nCovered)
                .. ' line(s) with no CORRECTED marker in the preceding ' .. WINDOW
                .. ' lines -- i.e. as a LIVE claim. J.WillMagicKillTarget is '
                .. 'X.ConsiderR\'s; see §1b.')
    end
end

tests['[ratchet] [7b] and both now say what the zero actually does to that site'] = function()
    for _, sPath in ipairs{ ZUUS, BOLTCAP } do
        local src = read_file(sPath)
        assert(src:find('CORRECTED 2026-08-30', 1, true),
            sPath .. ' lost its correction block; the claim in §7 is unattributed again')
        assert(src:find('health%-free') or src:find('health cancels'),
            sPath .. ' must say what the zero removes (the health SCALE), not merely '
                .. 'that the branch dies -- that is the half the retired sentence got right')
    end
end

return tests

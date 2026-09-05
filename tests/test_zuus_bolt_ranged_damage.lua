-- [hero] `zusboltdmg` -- X.ConsiderW's ranged-creep snipe is dead by closed
-- form, and the dead term is the SECOND consumer of the zero `zusboltcap`
-- repaired on the first.  Written 2026-09-05 under OWNER_PRIORITIES P4.4
-- (bots/ 主体配额).
--
-- THE DEFECT
-- ----------
-- bots/BotLib/hero_zuus.lua X.ConsiderW read:
--
--     local nDamage = abilityW:GetAbilityDamage() * ( 1 + bot:GetSpellAmp() )
--     ...
--     if targetRanged ~= nil
--         and targetRanged:GetHealth() < targetRanged:GetActualIncomingDamage(
--                 nDamage + targetRanged:GetHealth() * abilityASBonus, DAMAGE_TYPE_MAGICAL )
--
-- `CAbility:GetAbilityDamage()` reads an ability's TOP-LEVEL `AbilityDamage` KV
-- field and nothing else.  `zuus_lightning_bolt` does not declare one -- its
-- ladder lives in `AbilityValues/damage` (140 220 300 380) -- so the read is 0
-- in the ENGINE, not merely in the mock (§1; GH #175, axis `0DMG`).  With
-- nDamage = 0 the predicate degenerates to `h < m*b*h`, i.e. `1 < m*b`:
-- HEALTH-FREE and false for every creep at every rank, because Static Field's
-- `b` is 0.09 and `m` <= 1.  Break-even needs b >= 1.0, 11.1x the shipped value.
--
-- WHAT IS NEW HERE AND WHAT IS NOT -- READ BEFORE QUOTING THIS FILE
-- -----------------------------------------------------------------
--   * THE ARITHMETIC IS NOT NEW.  It is
--     tests/test_zuus_static_field_second_consumer.lua §3, landed 2026-08-30,
--     and §4c of that same file already DROVE the counterfactual on a real
--     frame: restore the KV damage and the same creep is sniped.  This round's
--     contribution is the LANDED, GATED repair plus the direction proof; it does
--     not re-litigate the deadness, it cites it and re-drives it here so the two
--     files cannot drift apart silently.
--   * THE END-TO-END CREEP IS A DECLARED FABRICATION.  No fixture in
--     tests/fixtures carries lane creeps -- make_fixture.py records hero
--     snapshots -- so X.GetRanged cannot be driven off a frame at all (§5
--     measures that rather than asserting it).  §4 replaces X.GetRanged and
--     nothing else; every term downstream of it is the shipped code running on a
--     real Zeus frame (f_260819_222052_zuus_w2_leak: level 8, rank-4 bolt, off
--     cooldown, 152 mana -- all real frame data).  This is the same declared
--     substitution the sibling file makes, made in the same place.
--   * SIZING IS NOT HERE.  How often a lane creep survives a tower hit inside
--     990 units of a Zeus with no enemy hero within 1400 is a corpus question, and
--     no fixture can answer it.  iterations/queue.json hero-32 asks for it.
--   * DIRECTION IS PROVED BY CONSTRUCTION, NOT BY DATA (§3).  The armed answer is
--     >= the shipped answer for every input, and the predicate is monotone in
--     nDamage, so the armed snipe set is a strict superset of the shipped one.
--     A negative wave reading is attributable to "snipes too often" and NEVER to
--     "the lever deleted a cast" -- the failure mode no counter can report.

package.path = 'tests/?.lua;' .. package.path
local api = require('mock.bot_api')
local rf  = require('mock.replay_fixture')

local ZUUS    = 'bots/BotLib/hero_zuus.lua'
local SHAPES  = 'tests/mock/special_value_shapes.lua'
local DAMAGES = 'tests/mock/ability_damage.lua'
local STATE   = 'iterations/state.json'
local QUEUE   = 'iterations/queue.json'

local FRAME   = 'tests/fixtures/f_260819_222052_zuus_w2_leak.lua'
local SUBJECT = 'npc_dota_hero_zuus'
local BOLT    = 'zuus_lightning_bolt'
local CAND    = 'zusboltdmg'
local KEY     = 'damage'

local tests = {}

local function read_file(sPath)
    local fh = assert(io.open(sPath, 'r'), 'cannot open ' .. sPath)
    local s = fh:read('*a'); fh:close()
    return s
end

-- Strip Lua line comments BEFORE anything is counted: the reasoning block above
-- X.GetBoltRangedKillDamage quotes the call name and the key while explaining
-- them, and a parser that reads prose reports the prose (GH #136).
local function strip_comments(src)
    return (src:gsub('%-%-[^\n]*', ''))
end

local function body_of(src, sFunc)
    local sBody = src:match('function X%.' .. sFunc .. '%(.-%)(.-)\nend\n')
    assert(sBody, 'X.' .. sFunc .. ' not found in ' .. ZUUS)
    return sBody
end

local function per_level(sBase, nRank)
    local t = {}
    for w in sBase:gmatch('%S+') do t[#t + 1] = tonumber(w) end
    return t[math.min(nRank, #t)]
end

local function kv(sAbility, sKey)
    local shapes = assert(dofile(SHAPES).SHAPES['zuus'], 'no zuus block in the KV snapshot')
    local a = assert(shapes[sAbility], 'no KV block for ' .. sAbility)
    return assert(a[sKey], sAbility .. ' has no KV key ' .. sKey)
end

--- An ability handle answering like a Lightning Bolt whose engine-side
--- AbilityDamage is `nShipped` and whose KV `damage` is `nKv`.  Declared
--- fabrication (§5 measures why no frame can supply the pair).
local function make_bolt(nShipped, nKv)
    return api.MakeUnit{
        GetUnitName = BOLT,
        GetAbilityDamage = function() return nShipped end,
        GetSpecialValueInt = function(_, sKey)
            if sKey == KEY then return nKv end
            return 0
        end,
    }
end

--- A ranged creep at health h whose magic-resistance factor is m.  Same shape
--- as the sibling file's, deliberately: the two must not price different creeps.
local function make_creep(h, m)
    return api.MakeUnit{
        GetUnitName = 'npc_dota_creep_badguys_ranged',
        GetHealth = h,
        IsAlive = true,
        GetActualIncomingDamage = function(_, dmg) return dmg * m end,
    }
end

--- Load Zeus on the real frame with the gate armed or not.  GetGameMode is set
--- BEFORE the hero file loads because J.IsModeTurbo memoises on first call.
local function load_zuus(bArmed, bTurbo)
    local J, bot = rf.load(FRAME, SUBJECT)
    if bTurbo == false then
        GetGameMode = function() return GAMEMODE_ALLPICK end
    end
    -- `zusbind` is armed on BOTH legs: it is the handle-resolution candidate the
    -- sibling file arms, and leaving it out would change what handle the helper
    -- is handed rather than what the helper does with it.
    J.IsSoakCandidate = function(sId)
        if sId == 'zusbind' then return true end
        return bArmed == true and sId == CAND
    end
    return rf.load_hero('zuus'), J, bot
end

local SHIPPED_LADDER = { 0, 1, 77, 140, 380, 500 }
local KV_LADDER      = { 0, 1, 140, 220, 300, 380, 999 }
local HEALTH_LADDER  = { 1, 5, 25, 50, 100, 150, 200, 250, 300, 400, 550, 700, 1000, 2000 }

-- ---------------------------------------------------------------- section 1 --
-- The zero is PROVEN, from the repo's own two frozen snapshots.  If a patch ever
-- gives the bolt a top-level AbilityDamage this whole lever is void and says so
-- here rather than quietly becoming a no-op.

tests['section 1: no Zeus ability declares a nonzero top-level AbilityDamage'] = function()
    local nonzero = assert(dofile(DAMAGES).NONZERO, 'ability_damage.lua has no NONZERO table')
    assert(nonzero['zuus'] == nil,
        'zuus now appears in the AbilityDamage census, so GetAbilityDamage() inside '
            .. 'hero_zuus.lua is no longer provably zero. This lever\'s whole premise is '
            .. 'void -- re-derive it, do not adjust this assertion.')
    local nHeroes = 0
    for _ in pairs(nonzero) do nHeroes = nHeroes + 1 end
    assert(nHeroes >= 1,
        'the census is empty, which would mean it failed to parse rather than that no '
            .. 'hero declares one -- a zero that measures the instrument, not the tree')
end

tests['section 1b: the bolt ladder lives in AbilityValues/damage and is 140 220 300 380'] = function()
    local bolt = assert(dofile(SHAPES).SHAPES['zuus'][BOLT], 'no KV block for ' .. BOLT)
    assert(bolt['AbilityDamage'] == nil,
        BOLT .. ' now declares a top-level AbilityDamage. Same consequence as section 1.')
    assert(bolt[KEY] ~= nil and bolt[KEY].base == '140 220 300 380',
        'the bolt ladder moved to ' .. tostring(bolt[KEY] and bolt[KEY].base)
            .. '; sections 3 and 4 parse their numbers from it, so re-read them rather '
            .. 'than patching this string')
end

-- ---------------------------------------------------------------- section 2 --
-- The helper's own behaviour, on fabricated handles.  Gate off must be the
-- shipped expression byte for byte -- by construction (last statement), not by
-- measurement.

tests['section 2: gate off -- the answer is the shipped GetAbilityDamage(), whatever the KV says'] = function()
    local X = load_zuus(false)
    for _, s in ipairs(SHIPPED_LADDER) do
        for _, k in ipairs(KV_LADDER) do
            local got = X.GetBoltRangedKillDamage(make_bolt(s, k))
            assert(got == s,
                'unarmed answer at shipped=' .. s .. ' kv=' .. k .. ' was ' .. tostring(got)
                    .. ', expected the shipped ' .. s .. '. Gate-off must be the shipped '
                    .. 'path byte for byte.')
        end
    end
end

tests['section 2b: non-turbo -- armed id, wrong mode, still the shipped answer'] = function()
    local X = load_zuus(true, false)
    for _, s in ipairs(SHIPPED_LADDER) do
        local got = X.GetBoltRangedKillDamage(make_bolt(s, 380))
        assert(got == s,
            'non-turbo answer at shipped=' .. s .. ' was ' .. tostring(got)
                .. '; the candidate is turbo-only (AGENTS.md)')
    end
end

tests['section 2c: armed -- the KV number is taken only when it is BIGGER'] = function()
    local X = load_zuus(true)
    for _, s in ipairs(SHIPPED_LADDER) do
        for _, k in ipairs(KV_LADDER) do
            local got = X.GetBoltRangedKillDamage(make_bolt(s, k))
            local want = (k > s) and k or s
            assert(got == want,
                'armed clause admits ' .. tostring(got) .. ' at shipped=' .. s
                    .. ' kv=' .. k .. ', expected max(shipped, kv) = ' .. want
                    .. '. A KV read that answers <= the shipped expression must fall '
                    .. 'through to the shipped expression (the GH #162 house rule), '
                    .. 'never invent a default.')
        end
    end
end

tests['section 2d: on the REAL frame the two legs are 0 and the rank-4 KV number'] = function()
    local nKv = per_level(kv(BOLT, KEY).base, 4)
    assert(nKv == 380, 'rank-4 KV damage parsed as ' .. tostring(nKv))

    local Xoff, _, botOff = load_zuus(false)
    local hOff = botOff:GetAbilityByName(BOLT)
    assert(hOff ~= nil, 'the frame carries a Lightning Bolt handle')
    assert(hOff:GetLevel() == 4, 'the bolt is rank 4 on this frame, got ' .. hOff:GetLevel())
    assert(hOff:GetAbilityDamage() == 0,
        'the shipped leg must read 0 on the real handle, got ' .. tostring(hOff:GetAbilityDamage()))
    assert(Xoff.GetBoltRangedKillDamage(hOff) == 0, 'so the unarmed helper answers 0')

    local Xon, _, botOn = load_zuus(true)
    local hOn = botOn:GetAbilityByName(BOLT)
    assert(Xon.GetBoltRangedKillDamage(hOn) == nKv,
        'the armed helper must answer the rank-4 KV number ' .. nKv .. ', got '
            .. tostring(Xon.GetBoltRangedKillDamage(hOn)))
end

-- ---------------------------------------------------------------- section 3 --
-- DIRECTION BY CONSTRUCTION.  Two claims, and neither is a sample:
--   (i) armed >= shipped for every (shipped, kv) pair -- swept, not argued;
--  (ii) the predicate is monotone non-decreasing in nDamage, so (i) makes the
--       armed snipe set a superset of the shipped one.
-- (ii) is what makes a negative wave reading un-attributable to a DELETED cast,
-- which is the failure no counter can see (the `cullthresh` / `wkbonefight`
-- lesson, third cross-hero reuse).

tests['section 3: armed is never SMALLER than shipped -- the forbidden direction'] = function()
    local Xon  = load_zuus(true)
    local Xoff = load_zuus(false)
    for _, s in ipairs(SHIPPED_LADDER) do
        for _, k in ipairs(KV_LADDER) do
            local nOn  = Xon.GetBoltRangedKillDamage(make_bolt(s, k))
            local nOff = Xoff.GetBoltRangedKillDamage(make_bolt(s, k))
            assert(nOn >= nOff,
                'armed answer ' .. nOn .. ' is BELOW the shipped ' .. nOff
                    .. ' at shipped=' .. s .. ' kv=' .. k .. '. That is the one direction '
                    .. 'this lever is forbidden: it would silently DELETE a snipe the '
                    .. 'shipped bot makes, and no counter reports a cast that did not '
                    .. 'happen.')
        end
    end
end

tests['section 3b: the snipe predicate is monotone in the flat damage'] = function()
    -- The predicate re-driven through the real mock GetActualIncomingDamage
    -- rather than restated: h < m*(D + h*b) is non-decreasing in D, so a bigger
    -- D can only turn false into true.
    local B_LADDER = { 0.09, 0.20, 0.29 }
    local M_LADDER = { 1.00, 0.90, 0.75, 0.50, 0.25 }
    for _, b in ipairs(B_LADDER) do
        for _, m in ipairs(M_LADDER) do
            for _, h in ipairs(HEALTH_LADDER) do
                local creep = make_creep(h, m)
                local bPrev = false
                for _, D in ipairs{ 0, 140, 220, 300, 380, 1000 } do
                    local bNow = creep:GetHealth()
                        < creep:GetActualIncomingDamage(D + creep:GetHealth() * b,
                                                        DAMAGE_TYPE_MAGICAL)
                    assert(not (bPrev and not bNow),
                        'the predicate went TRUE -> FALSE as the flat damage rose (b=' .. b
                            .. ' m=' .. m .. ' h=' .. h .. ' D=' .. D .. '). Monotonicity is '
                            .. 'what makes section 3 a superset proof; without it the '
                            .. 'direction argument does not transfer from the helper to '
                            .. 'the branch.')
                    bPrev = bNow
                end
            end
        end
    end
end

tests['section 3c: and with D = 0 it is health-free and false -- the deadness, re-driven'] = function()
    -- Not a citation of the sibling file: the same claim, driven here, so the two
    -- cannot drift apart. b is swept over the shipped 0.09 and the whole armed KV
    -- band; m over the resistance range. Nothing below is algebra.
    for _, b in ipairs{ 0.09, 0.20, 0.29, 0.50, 0.99 } do
        for _, m in ipairs{ 1.00, 0.90, 0.75, 0.50, 0.25 } do
            for _, h in ipairs(HEALTH_LADDER) do
                local creep = make_creep(h, m)
                local bFires = creep:GetHealth()
                    < creep:GetActualIncomingDamage(0 + creep:GetHealth() * b,
                                                    DAMAGE_TYPE_MAGICAL)
                assert(bFires == false,
                    'the shipped predicate FIRED at b=' .. b .. ' m=' .. m .. ' h=' .. h
                        .. '. It must be false for every health: with D = 0 it reduces to '
                        .. '1 < m*b and m*b <= 0.99. If this ever passes, the branch was '
                        .. 'not dead and the whole lever needs re-pricing.')
            end
        end
    end
end

-- ---------------------------------------------------------------- section 4 --
-- END TO END on the real frame, through the real X.ConsiderW and the real
-- helper.  X.GetRanged is replaced and NOTHING ELSE is (declared fabrication --
-- section 5 measures why).

local function consider_w_on(bArmed, h, m)
    local X = load_zuus(bArmed)
    local creep = make_creep(h, m)
    X.GetRanged = function() return creep end
    X.SkillsComplement()          -- the only thing that assigns abilityASBonus
    local nDesire, hTarget = X.ConsiderW()
    return nDesire, hTarget, creep
end

tests['section 4: ground truth -- the bolt really is castable on this frame'] = function()
    local _, _, bot = load_zuus(false)
    assert(bot:GetUnitName() == SUBJECT, 'subject is Zeus')
    assert(bot:GetLevel() == 8, 'Zeus is level 8 on this frame, got ' .. bot:GetLevel())
    assert(bot:GetMana() == 152, 'real mana on the frame, got ' .. bot:GetMana())
    local w = bot:GetAbilityByName(BOLT)
    assert(w:GetCooldownTimeRemaining() == 0, 'and the bolt is OFF COOLDOWN')
    assert(w:IsFullyCastable(),
        '152 mana pays the rank-4 cost -- X.ConsiderW does not bail on line 1')
end

tests['section 4b: shipped leg -- no creep is sniped at any health'] = function()
    for _, h in ipairs(HEALTH_LADDER) do
        local nDesire, hTarget = consider_w_on(false, h, 1.00)
        assert(nDesire == BOT_ACTION_DESIRE_NONE,
            'the shipped leg bid ' .. tostring(nDesire) .. ' on a ' .. h
                .. ' HP ranged creep. Section 3c says it cannot.')
        assert(hTarget == nil, 'and it must hand back no target, got ' .. tostring(hTarget))
    end
end

tests['section 4c: armed leg -- the low-health creep IS sniped, and it is this gate that did it'] = function()
    local nDesire, hTarget, creep = consider_w_on(true, 100, 1.00)
    assert(nDesire == BOT_ACTION_DESIRE_HIGH,
        'with the gate armed the 100 HP creep must be sniped, got ' .. tostring(nDesire)
            .. '. If this is NONE the branch is dead for a SECOND reason this file has '
            .. 'not found, and section 4b does not mean what it says.')
    assert(hTarget == creep, 'and the target must be that creep')

    -- The same frame, the same creep, the gate the only difference.
    local nOff = consider_w_on(false, 100, 1.00)
    assert(nOff == BOT_ACTION_DESIRE_NONE,
        'the unarmed leg answered ' .. tostring(nOff) .. ' on the same creep, so the '
            .. 'gate is not what separates the two legs')
end

tests['section 4d: the armed snipe set is a SUPERSET on the frame, sweep-verified'] = function()
    local nOnly, nBoth = 0, 0
    for _, h in ipairs(HEALTH_LADDER) do
        for _, m in ipairs{ 1.00, 0.75, 0.25 } do
            local bOff = consider_w_on(false, h, m) == BOT_ACTION_DESIRE_HIGH
            local bOn  = consider_w_on(true,  h, m) == BOT_ACTION_DESIRE_HIGH
            assert(not (bOff and not bOn),
                'shipped snipes and armed does not, at h=' .. h .. ' m=' .. m
                    .. ' -- the forbidden direction, on a real frame')
            if bOn and not bOff then nOnly = nOnly + 1 end
            if bOn and bOff then nBoth = nBoth + 1 end
        end
    end
    assert(nOnly > 0,
        'arming changed nothing on any of the ' .. (#HEALTH_LADDER * 3) .. ' swept cases. '
            .. 'That is the DEAD-WIRING shape (GH #531): helper present, id registered, '
            .. 'call site present, armed answer identical -- a wave would read it back '
            .. 'as "tested, no effect" with nothing raising a hand.')
    assert(nBoth == 0,
        'the shipped leg snipes on ' .. nBoth .. ' swept cases; section 3c says zero')
end

-- ---------------------------------------------------------------- section 5 --
-- THE COVERAGE BOUNDARY, measured rather than asserted.  Two sentences that must
-- never be merged into one: the BRANCH has source-level coverage only; the TERM
-- that changed has real-frame coverage (section 2d reads it off the frame's own
-- handle).  The day either blocker is fixed this section goes red and says so.

tests['section 5: no fixture carries a lane creep, so X.GetRanged is not frame-drivable'] = function()
    local nFrames, nWithCreeps = 0, 0
    local ZEUS_FRAMES = {
        'tests/fixtures/f_072738_zuus_mana.lua',
        'tests/fixtures/f_073148_zuus_lina.lua',
        'tests/fixtures/f_163714_zuus_commit_pin.lua',
        'tests/fixtures/f_181441_zuus_lowhp_limbo.lua',
        'tests/fixtures/f_230952_zuus_ult_hoard.lua',
        'tests/fixtures/f_260819_142047_zuus_ult_denied.lua',
        'tests/fixtures/f_260819_142047_zuus_ult_manalock.lua',
        'tests/fixtures/f_260819_222052_zuus_w2_leak.lua',
        'tests/fixtures/f_260820_042607_zuus_reserve_cross.lua',
        'tests/fixtures/f_260820_042607_zuus_reserve_safe.lua',
    }
    for _, sPath in ipairs(ZEUS_FRAMES) do
        local fx = dofile(sPath)
        nFrames = nFrames + 1
        for _, u in ipairs(fx.units or {}) do
            if type(u.name) == 'string' and u.name:find('_creep', 1, true) then
                nWithCreeps = nWithCreeps + 1
                break
            end
        end
    end
    assert(nFrames == #ZEUS_FRAMES, 'listed ' .. #ZEUS_FRAMES .. ' frames, loaded ' .. nFrames)
    assert(nWithCreeps == 0,
        nWithCreeps .. ' of ' .. nFrames .. ' Zeus frames now carry creep units. That is '
            .. 'GOOD NEWS, not a failure: X.GetRanged became frame-drivable, so section 4 '
            .. 'should stop fabricating its creep and drive the real selector instead. '
            .. 'Rewrite section 4; do not relax this assertion.')
end

tests['section 5b: and GetActiveMode is 0 on the frame -- the second, independent blocker'] = function()
    local _, _, bot = load_zuus(false)
    assert(bot:GetActiveMode() == 0,
        'GetActiveMode now answers ' .. tostring(bot:GetActiveMode()) .. ' on this frame '
            .. '(GH #474 territory). X.GetRanged branches on BOT_MODE_LANING and on four '
            .. 'mode suppressors, so a real mode would make the selector partially '
            .. 'drivable -- re-read section 4 before quoting it.')
end

-- ---------------------------------------------------------------- section 6 --
-- Source ratchets: where the expression may live, and that the gate stays a gate.

tests['section 6: X.ConsiderW takes its flat damage through the helper and nowhere else'] = function()
    local src   = strip_comments(read_file(ZUUS))
    local sBody = body_of(src, 'ConsiderW')
    assert(sBody:find('local nDamage = X.GetBoltRangedKillDamage( abilityW ) * ( 1 + bot:GetSpellAmp() )', 1, true),
        'the one assignment must go through the helper, with the file-local handle')
    assert(not sBody:find('GetAbilityDamage', 1, true),
        'and no raw GetAbilityDamage may survive inside ConsiderW -- that would be an '
            .. 'ungated site wearing a gated site\'s name')
    assert(sBody:find('targetRanged:GetHealth() < targetRanged:GetActualIncomingDamage( nDamage '
            .. '+ targetRanged:GetHealth() * abilityASBonus , DAMAGE_TYPE_MAGICAL )', 1, true),
        'the snipe predicate must still be the two-term estimate sections 3 and 4 price')

    -- nDamage has exactly one consumer in this function. A second would be a leg
    -- nothing in this file is watching.
    local nReads = select(2, sBody:gsub('nDamage', ''))
    assert(nReads == 2,
        'expected the assignment plus exactly ONE read of nDamage in ConsiderW, got '
            .. nReads .. ': a second consumer appeared and nothing here prices it')
end

tests['section 6b: the gate is turbo-only, standalone, and ends on the shipped expression'] = function()
    local sHelper = body_of(strip_comments(read_file(ZUUS)), 'GetBoltRangedKillDamage')
    assert(sHelper:find("J.IsSoakCandidate( '" .. CAND .. "' )", 1, true),
        'the correction must sit behind IsSoakCandidate(' .. CAND .. ')')
    assert(sHelper:find('J.IsModeTurbo()', 1, true),
        'and behind IsModeTurbo (turbo-only, AGENTS.md)')
    assert(sHelper:find("GetSpecialValueInt( '" .. KEY .. "' )", 1, true),
        'and it must read the KV key ' .. KEY .. ' rather than re-typing the ladder')

    -- The `pullcad` trap: a gate written as a conjunction of two candidate ids
    -- freezes FALSE the day either is promoted, and check_armed_wiring.py still
    -- calls it WIRED. Keep it standalone.
    local _, nIds = sHelper:gsub('IsSoakCandidate', '')
    assert(nIds == 1,
        'the helper names ' .. nIds .. ' soak ids; keep it standalone so promoting '
            .. 'another id cannot freeze this one false (the pullcad trap)')

    -- Gate-off is the shipped path BY CONSTRUCTION, in two halves rather than one
    -- line.  The shipped read is bound ONCE, ahead of the gate, and the helper's
    -- last statement returns that binding -- so no path that skips the gate can
    -- return anything else, and section 2 needs no measurement to be believed.
    -- (It is bound rather than re-called because the armed clause has to COMPARE
    -- against it; a second raw call would also break the tree-wide count of
    -- surviving GetAbilityDamage() sites that tests/test_zuus_bolt_kill_cap.lua
    -- keeps at 2.)
    assert(sHelper:find('local nShipped = hAbility:GetAbilityDamage()', 1, true),
        'the helper must bind the shipped read to nShipped before the gate, got:\n' .. sHelper)
    local sTail = sHelper:match('(return[^\n]*)%s*$')
    assert(sTail and sTail:find('return nShipped', 1, true),
        'and it must END on `return nShipped`, got ' .. tostring(sTail))
    local _, nRaw = sHelper:gsub('GetAbilityDamage%(%)', '')
    assert(nRaw == 1,
        'the helper calls GetAbilityDamage() ' .. nRaw .. ' times; exactly one binding '
            .. 'keeps the two legs reading the same number within a frame')
end

tests['section 6c: the zusstatic co-arming hand-off is registered, not left in a report'] = function()
    -- Arming this id un-empties `abilityASBonus`'s second consumer, which is the
    -- premise `zusstatic`'s condition (a) rests on (queue hero-15). Rule 9: the
    -- next baton is handed over in the SAME work unit or it drops. Three places
    -- carry it; this asserts the two durable ones.
    local sState = read_file(STATE)
    assert(sState:find(CAND, 1, true),
        CAND .. ' is not registered in ' .. STATE .. '; an unregistered soak id cannot '
            .. 'be armed by a wave and cannot be found by whoever reads the verdict')
    assert(sState:find('zusstatic', 1, true),
        'the state archive must still name zusstatic -- section 6c is about the '
            .. 'RELATION between the two ids')
    local sQueue = read_file(QUEUE)
    assert(sQueue:find(CAND, 1, true),
        CAND .. ' has no request in ' .. QUEUE .. '. This lever is unsized by '
            .. 'construction (section 5), so a fixture scan may not stand in for one.')
end

return tests

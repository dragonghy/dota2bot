-- Axe's Battle Hunger kill branch declares PURE damage into a magical-only kill
-- predicate.  GH #154, soak candidate 'axebhpure' (turbo-only, not armed).
--
-- THE FACT, in two halves that have to be read together:
--
--   (1) `axe_battle_hunger` has `AbilityUnitDamageType` `DAMAGE_TYPE_PURE` and
--       the tooltip property `DPS_Pure` (the game's own hero KV, via the d2vpkr
--       mirror that tools/agent/gen_ability_meta.py already reads; fetched
--       2026-08-24).  12s duration, 12/16/20/24 damage per second, +8 from this
--       file's t15 pick => 144/192/240/288 raw, 240/288/336/384 with the talent.
--
--   (2) `J.WillMagicKillTarget` hardcodes `nDamageType = DAMAGE_TYPE_MAGICAL`
--       and returns `npcTarget:GetActualIncomingDamage( EstDamage, nDamageType )
--       >= npcTarget:GetHealth()`.  Magic resistance is applied to a damage
--       number that the engine will not reduce.  Every hero carries 25% at base,
--       so the branch under-states its own spell by at least a quarter, and by
--       more against any magic-resistance item.
--
-- It is not a house convention.  X.ConsiderR, in the SAME FILE, declares
-- `nDamageType = DAMAGE_TYPE_PURE` for Culling Blade and compares against RAW
-- health with no mitigation term at all.  Section 2 pins both halves of that
-- contrast so the pair cannot drift.
--
-- WHAT THIS FILE CAN AND CANNOT SHOW
--
-- Section 4 drives the SHIPPED X.ConsiderW on synthetic units that model a 25%
-- magic resistance, because a real-frame fixture cannot reach this branch at
-- all: `GetActualIncomingDamage` is not modelled by the mock, so it answers the
-- generic `Get*` default 0 on 1040 / 1040 hero handles across the 104 loadable
-- fixtures.  J.WillMagicKillTarget is therefore FALSE on all 966 living units
-- and TRUE on all 74 corpses (0 >= 0), measured 2026-08-24 and re-measured on
-- one Axe frame in section 5.  That inversion is not specific to Axe: every kill
-- branch in every focus hero -- CM Frostbite, Lion Impale/Finger, Zeus Bolt --
-- routes through the same call, so a GREEN fixture run over any of them is a
-- false green, and the domain of this fix can only be bought from a wave
-- (iterations/queue.json, hero-13).
--
-- MUTATION RECORD (2026-08-24): see the table at the bottom of this file.

package.path = 'tests/?.lua;' .. package.path
local api = require('mock.bot_api')
local rf = require('mock.replay_fixture')

local AXE_SRC = 'bots/BotLib/hero_axe.lua'
local Q_NAME = 'axe_berserkers_call'
local W_NAME = 'axe_battle_hunger'
local R_NAME = 'axe_culling_blade'

local CAND = 'axebhpure'

-- External anchors (game hero KV, d2vpkr mirror, read 2026-08-24).  Recorded
-- here rather than fetched: the test must run with no network.
local BH_DAMAGE_TYPE = 'DAMAGE_TYPE_PURE'
local BH_DPS      = { 12, 16, 20, 24 }
local BH_DURATION = 12
local MAGIC_RESIST = 0.25       -- every hero's base value

-- The focus five, and the KV damage type of every ability of theirs that can
-- reach a kill predicate.  PURE is the interesting column: it is the one the
-- magical-only helper mis-prices, and axe_battle_hunger is its only member with
-- a J.WillMagicKillTarget consumer.  (axe_culling_blade is also PURE and is NOT
-- a defect -- X.ConsiderR compares it against raw health, section 2.)
local FOCUS_DAMAGE_TYPES = {
    ['axe_battle_hunger']            = 'DAMAGE_TYPE_PURE',
    ['axe_culling_blade']            = 'DAMAGE_TYPE_PURE',
    ['axe_counter_helix']            = 'DAMAGE_TYPE_PURE',
    ['crystal_maiden_crystal_nova']  = 'DAMAGE_TYPE_MAGICAL',
    ['crystal_maiden_frostbite']     = 'DAMAGE_TYPE_MAGICAL',
    ['crystal_maiden_freezing_field'] = 'DAMAGE_TYPE_MAGICAL',
    ['lion_impale']                  = 'DAMAGE_TYPE_MAGICAL',
    ['lion_finger_of_death']         = 'DAMAGE_TYPE_MAGICAL',
    ['zuus_arc_lightning']           = 'DAMAGE_TYPE_MAGICAL',
    ['zuus_lightning_bolt']          = 'DAMAGE_TYPE_MAGICAL',
    ['zuus_thundergods_wrath']       = 'DAMAGE_TYPE_MAGICAL',
    ['skeleton_king_hellfire_blast'] = 'DAMAGE_TYPE_MAGICAL',
    ['skeleton_king_bone_guard']     = 'DAMAGE_TYPE_PHYSICAL',
}

-- Measured 2026-08-24 by driving J.WillMagicKillTarget with 99999 damage against
-- every hero handle of every loadable fixture.  Section 5 reproduces one row.
local CORPUS = { files = 104, units = 1040, living = 966, corpses = 74 }

local tests = {}

local function read(path)
    local fh = assert(io.open(path, 'r'))
    local src = fh:read('*a')
    fh:close()
    return src
end

--- Source with every `--` line comment stripped, so that a claim quoted in a
--- rationale block is never counted as code.  (The parser in
--- test_wk_magic_wand_branches.lua learned this the hard way.)
local function strip_comments(src)
    local out = {}
    for line in (src .. '\n'):gmatch('([^\n]*)\n') do
        out[#out + 1] = line:gsub('%-%-.*$', '')
    end
    return table.concat(out, '\n')
end

----------------------------------------------------------------------
-- 1.  The arithmetic, straight from the anchors.  No mock, no source.

tests['the anchored numbers say the shipped predicate under-states by the resistance'] = function()
    for lv, dps in ipairs(BH_DPS) do
        local raw = dps * BH_DURATION
        local seen = raw * (1 - MAGIC_RESIST)
        assert(seen < raw, 'rank ' .. lv .. ': a magical reading must be smaller')
        assert(math.abs(raw - seen - raw * MAGIC_RESIST) < 1e-9,
            'the whole gap is the resistance term, nothing else')
    end
    -- rank 4 with this file's t15 pick (+8 dps): 384 pure, read as 288.
    local talented = (BH_DPS[4] + 8) * BH_DURATION
    assert(talented == 384, 'anchor drift: expected 384 pure at rank 4 with +8 dps')
    assert(talented * (1 - MAGIC_RESIST) == 288,
        'anchor drift: a 25%-resistance hero is read as 288')
end

tests['PURE is the only damage type the magical-only helper misprices'] = function()
    -- Physical would be misread too, but no focus hero routes one here; the
    -- assertion is that the census below has to be re-read if that changes.
    local pure = 0
    for _, t in pairs(FOCUS_DAMAGE_TYPES) do
        if t == BH_DAMAGE_TYPE then pure = pure + 1 end
    end
    assert(pure == 3, 'expected exactly three PURE abilities among the focus five '
        .. '(Axe: Battle Hunger, Culling Blade, Counter Helix); got ' .. pure)
end

----------------------------------------------------------------------
-- 2.  The contrast inside hero_axe.lua itself.  Read out of the shipped source
--     with comments stripped, so a rationale block cannot satisfy any of it.

tests['ConsiderR prices Culling Blade as pure: raw health, no mitigation term'] = function()
    local src = strip_comments(read(AXE_SRC))
    local r = src:match('function X%.ConsiderR%(%)(.-)\nend')
    assert(r, 'X.ConsiderR not found in ' .. AXE_SRC)
    assert(r:find('DAMAGE_TYPE_PURE', 1, true),
        'X.ConsiderR must still declare the pure damage type')
    assert(r:find('GetHealth() + npcEnemy:GetHealthRegen()', 1, true),
        'X.ConsiderR must still compare RAW health against the kill damage; if '
        .. 'this line moved to a mitigation helper, the contrast this whole file '
        .. 'rests on is gone and GH #154 has to be re-argued')
    assert(not r:find('WillMagicKillTarget', 1, true),
        'X.ConsiderR must NOT route its pure damage through the magical helper')
end

tests['ConsiderW still hands the full 12s dot total to the kill test'] = function()
    local src = strip_comments(read(AXE_SRC))
    local w = src:match('function X%.ConsiderW%(%)(.-)\nend')
    assert(w, 'X.ConsiderW not found in ' .. AXE_SRC)
    assert(w:find("GetSpecialValueInt( 'damage_per_second' ) * nDuration", 1, true),
        'the damage claim must still be dps * duration -- the size of the '
        .. 'mispricing in section 1 is computed from exactly that product')
    assert(w:find('X.WillBattleHungerKill( npcEnemy, nDamage, nDuration )', 1, true),
        'the kill branch must call the gated wrapper, not the helper directly')
end

tests['the gate is turbo-only and reads its own id'] = function()
    local src = strip_comments(read(AXE_SRC))
    local g = src:match('function X%.IsBattleHungerPureOn%(%)(.-)\nend')
    assert(g, 'X.IsBattleHungerPureOn not found')
    assert(g:find('J.IsModeTurbo()', 1, true), 'the gate must be turbo-only')
    assert(g:find("J.IsSoakCandidate( '" .. CAND .. "' )", 1, true),
        'the gate must read the ' .. CAND .. ' candidate id')
end

tests['gate off is the shipped predicate, structurally'] = function()
    -- The widening is unreachable until J.WillMagicKillTarget has answered
    -- false, so "gate off == shipped" is a property of the code, not of a run.
    local src = strip_comments(read(AXE_SRC))
    local f = src:match('function X%.WillBattleHungerKill%b()(.-)\nend')
    assert(f, 'X.WillBattleHungerKill not found')
    local shipped = f:find('J.WillMagicKillTarget', 1, true)
    local gate = f:find('X.IsBattleHungerPureOn', 1, true)
    assert(shipped and gate and shipped < gate,
        'the shipped call must come FIRST and return true before the gate is '
        .. 'consulted; otherwise gate-off is no longer byte-for-byte the old '
        .. 'behaviour and the change cannot ride a mirror as a dark candidate')
end

----------------------------------------------------------------------
-- 3.  A synthetic Axe frame.  Every branch of X.ConsiderW except the kill
--     branch is switched off, so the read-out is that branch alone:
--       * GetActiveMode stays at the mock default, so J.IsGoingOnSomeone,
--         J.IsInTeamFight and J.IsLaning are all false (GH #125);
--       * no allies anywhere;
--       * Battle Hunger fully castable, everything else not.
--     The enemies model a real 25% magic resistance, which the fixture world
--     cannot (section 5).

local function make_frame(opts)
    api.reset_modules()
    local wlv = opts.wlv or 4
    local w = api.MakeAbility(W_NAME, {
        IsFullyCastable = true,
        GetLevel = wlv,
        GetCastRange = 900,
        GetCastPoint = 0.3,
        GetManaCost = 50 + 10 * (wlv - 1),
        GetSpecialValueInt = function(_, key)
            if key == 'duration' then return BH_DURATION end
            if key == 'damage_per_second' then return opts.dps or BH_DPS[wlv] end
            return 0
        end,
    })
    local q = api.MakeAbility(Q_NAME, { IsFullyCastable = false, GetLevel = 1 })
    local e = api.MakeAbility('axe_counter_helix', { IsFullyCastable = false, GetLevel = 1 })
    local r = api.MakeAbility(R_NAME, { IsFullyCastable = false, GetLevel = 1, IsUltimate = true })

    -- X.GetAbilityList walks GetAbilityInSlot, and hero_axe.lua binds abilityW by
    -- INDEX (sAbilityList[2]), not by name.  Without this the file binds four
    -- placeholder handles and X.ConsiderW returns at its first line -- a silent
    -- zero that reads exactly like "the branch declined".
    local slots = { [0] = q, [1] = w, [2] = e, [5] = r }

    local enemies = {}
    for i, e in ipairs(opts.enemies) do
        local mods = e.modifiers or {}
        enemies[i] = api.MakeHero(e.name, {
            GetTeam = 3,                    -- bot is TEAM_RADIANT (2)
            CanBeSeen = true,
            IsAlive = true,
            GetHealth = e.hp,
            GetMaxHealth = 1000,
            GetHealthRegen = e.regen or 0,
            GetLocation = api.Vector(e.dist, 0, 0),
            GetAttackRange = 150,
            -- The engine's magical mitigation, which the fixture world does not
            -- model at all.  Pure damage would NOT pass through this.
            GetActualIncomingDamage = function(_, dmg) return dmg * (1 - MAGIC_RESIST) end,
            GetMagicResist = MAGIC_RESIST,
            HasModifier = function(_, name) return mods[name] == true end,
        })
    end

    local bot = api.MakeHero('npc_dota_hero_axe', {
        GetLevel = 15,
        CanBeSeen = true,
        IsAlive = true,
        GetLocation = api.Vector(0, 0, 0),
        GetMana = 900, GetMaxMana = 1000,
        GetHealth = 2000, GetMaxHealth = 2000,
        GetSpellAmp = 0,
        GetNearbyHeroes = function(_, radius, bEnemy)
            if not bEnemy then return {} end
            local t = {}
            for i, e in ipairs(opts.enemies) do
                if e.dist <= radius then t[#t + 1] = enemies[i] end
            end
            return t
        end,
        GetAbilityInSlot = function(_, slot) return slots[slot] end,
        GetAbilityByName = function(_, name)
            if name == W_NAME then return w end
            if name == Q_NAME then return q end
            if name == R_NAME then return r end
            if name == 'axe_counter_helix' then return e end
            return api.MakeAbility(name or 'mock_absent', { IsTrained = false })
        end,
    })
    api.install({ bot = bot })
    _G.GetLaneFrontLocation = function() return api.Vector(90000, 0, 0) end

    local X = dofile(AXE_SRC)
    local J = package.loaded[GetScriptDirectory() .. '/FunLib/jmz_func']
    assert(J, 'jmz_func must already be loaded by the hero file; patching a '
        .. 'second copy would arm a gate nobody reads')
    J.IsModeTurbo = function() return opts.turbo ~= false end
    J.IsSoakCandidate = function(id) return opts.armed == true and id == CAND end
    X.SkillsComplement()
    return X, bot, enemies
end

--- desire, and the unit name the kill branch aimed at (or nil).
local function decide(opts)
    local X = make_frame(opts)
    local d, t = X.ConsiderW()
    local name = (type(t) == 'table' and t.GetUnitName) and t:GetUnitName() or nil
    return d or 0, name
end

local function solo(hp, opts)
    opts = opts or {}
    return decide({
        armed = opts.armed, turbo = opts.turbo, wlv = opts.wlv, dps = opts.dps,
        enemies = { { name = 'npc_dota_hero_lina', dist = 400, hp = hp,
                      regen = opts.regen, modifiers = opts.modifiers } },
    })
end

----------------------------------------------------------------------
-- 4.  The behavioural read-out.  Rank 4, 24 dps, 12s => 288 pure, which the
--     shipped predicate reads as 216 against a 25%-resistance hero.  The band
--     the fix opens is therefore (216, 288].

tests['control: below the mispriced threshold both worlds fire'] = function()
    local off = select(1, solo(200))
    local on  = select(1, solo(200, { armed = true }))
    assert(off > 0, 'a 200-HP target is inside even the under-stated estimate; '
        .. 'if this is silent the frame is dead for an unrelated reason and '
        .. 'every other read-out in this section is meaningless')
    assert(on > 0, 'the widening must never withhold a cast the shipped code makes')
end

tests['control: above the true damage neither world fires'] = function()
    assert(select(1, solo(400)) == 0, 'shipped code must not claim a 400-HP kill')
    assert(select(1, solo(400, { armed = true })) == 0,
        'the widening must not claim a kill the pure arithmetic does not support')
end

tests['THE DEFECT: inside the band the shipped branch is silent'] = function()
    local d, name = solo(250)
    assert(d == 0 and name == nil,
        'a 250-HP hero dies to 288 pure damage, but the magical reading is 216 '
        .. 'and the shipped kill branch refuses; got desire ' .. d)
end

tests['THE FIX: armed, the same frame fires at the same target'] = function()
    local d, name = solo(250, { armed = true })
    assert(d > 0, 'armed, the pure arithmetic kills and the branch must fire')
    assert(name == 'npc_dota_hero_lina', 'it must aim at the enemy in the band')
end

tests['the gate is inert outside turbo'] = function()
    assert(select(1, solo(250, { armed = true, turbo = false })) == 0,
        'the candidate is turbo-only; in any other mode it must be a no-op')
end

tests['the regeneration term survives the fix'] = function()
    -- 12 seconds is a long window: 4 hp/s regenerates 48, which is enough to
    -- push a 250-HP target back out of the 288 band.  If this stops mattering,
    -- the fix has dropped a term it was supposed to keep.
    assert(select(1, solo(250, { armed = true, regen = 4 })) == 0,
        '250 HP + 48 regenerated over the dot exceeds 288; must not fire')
    assert(select(1, solo(250, { armed = true, regen = 0 })) > 0,
        'the same target with no regeneration must fire -- otherwise the read '
        .. 'above is not about regeneration at all')
end

tests['the widening abstains on every target the helper has an opinion about'] = function()
    for _, mod in ipairs({ 'modifier_medusa_mana_shield',
                           'modifier_kunkka_ghost_ship_damage_delay',
                           'modifier_templar_assassin_refraction_absorb' }) do
        assert(select(1, solo(250, { armed = true, modifiers = { [mod] = true } })) == 0,
            'the widening must refuse a target carrying ' .. mod .. ': the shipped '
            .. 'helper scales its estimate for it and this branch does not model that')
    end
end

tests['the widening abstains on Bristleback by name'] = function()
    local d = select(1, decide({
        armed = true,
        enemies = { { name = 'npc_dota_hero_bristleback', dist = 400, hp = 250 } },
    }))
    assert(d == 0, 'the fourth special case in J.WillMagicKillTarget is a unit '
        .. 'name, not a modifier; the widening must refuse it too')
end

tests['a lower rank moves the band, so the read is not pinned to one number'] = function()
    -- Rank 1: 12 dps * 12s = 144 pure, read as 108.  The band is (108, 144].
    assert(select(1, solo(130, { wlv = 1 })) == 0, 'rank 1 shipped: 130 > 108')
    assert(select(1, solo(130, { wlv = 1, armed = true })) > 0, 'rank 1 armed: 130 <= 144')
    assert(select(1, solo(160, { wlv = 1, armed = true })) == 0, 'rank 1 armed: 160 > 144')
end

----------------------------------------------------------------------
-- 5.  Why section 4 had to be synthetic.  One real Axe frame, reproducing the
--     corpus-wide reading recorded at the top of this file.

tests['world assertion: the fixture world cannot reach any kill branch'] = function()
    local J, bot, heroes = rf.load('tests/fixtures/f_011405_jak_rescue_axe.lua')
    local living, verdicts = 0, 0
    for _, h in pairs(heroes) do
        if h:GetHealth() > 0 then
            living = living + 1
            assert(h:GetActualIncomingDamage(100, DAMAGE_TYPE_MAGICAL) == 0,
                'GetActualIncomingDamage is expected to answer the generic Get* '
                .. 'default 0 here.  If it now answers a real number the mock has '
                .. 'grown a damage model, and section 4 should be rewritten on '
                .. 'real frames -- see GH #154 and queue hero-13')
            if J.WillMagicKillTarget(bot, h, 99999, 0.3) then verdicts = verdicts + 1 end
        end
    end
    assert(living > 0, 'the fixture must carry living heroes, or this proves nothing')
    assert(verdicts == 0, 'with 99999 damage declared, J.WillMagicKillTarget still '
        .. 'says "no kill" for every living unit: the branch is structurally dead '
        .. 'offline, in this hero and in every other focus hero')
end

tests['and the same default makes it TRUE for corpses'] = function()
    -- 0 >= 0.  The inversion is the point: an offline scan that counted "frames
    -- where the kill branch would fire" would count exactly the dead ones.
    local J, bot, heroes = rf.load('tests/fixtures/f_011405_jak_rescue_axe.lua')
    local corpses, fired = 0, 0
    for _, h in pairs(heroes) do
        if h:GetHealth() == 0 then
            corpses = corpses + 1
            if J.WillMagicKillTarget(bot, h, 1, 0.3) then fired = fired + 1 end
        end
    end
    if corpses > 0 then
        assert(fired == corpses,
            'every corpse must come back as killable; got ' .. fired .. '/' .. corpses)
    end
    assert(CORPUS.living + CORPUS.corpses == CORPUS.units,
        'the recorded corpus split must add up')
end

----------------------------------------------------------------------
-- MUTATION RECORD (2026-08-24), 11 mutations of hero_axe.lua, 11 caught, plus
-- one no-op control that escaped as intended.  The judgement was read off the
-- runner's own "N tests, M failures" counters, never a substring of the line:
-- "10 failures" contains "0 failures", and that exact confusion mis-scored a
-- mutation in this desk's 2026-08-24T00:00Z round.
--   M1  drop `X.IsBattleHungerPureOn` from X.WillBattleHungerKill (always widen)
--                                                        -> CAUGHT (gate off/turbo)
--   M2  gate reads a different id                        -> CAUGHT
--   M3  gate drops J.IsModeTurbo                         -> CAUGHT
--   M4  widening drops the regeneration term             -> CAUGHT
--   M5  widening keeps the resistance (`* 0.75`)         -> CAUGHT
--   M6  shipped call moved AFTER the gate check          -> CAUGHT (structure)
--   M7  abstain list emptied                             -> CAUGHT
--   M8  Bristleback name check deleted                   -> CAUGHT
--   M9  `>=` in the widening flipped to `>`              -> CAUGHT (band edge)
--   M10 ConsiderR rewritten to use J.WillMagicKillTarget -> CAUGHT (section 2)
--   M11 dps * duration replaced by dps alone             -> CAUGHT
--   M12 a pure comment line added                        -> ESCAPED, as intended
return tests

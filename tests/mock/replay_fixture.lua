-- Rebuild a real replay instant (a make_fixture.py fixture) under the mock Bot
-- API, so the REAL decision helpers in jmz_func run on the REAL game state.
--
-- This is the local-validation keystone: no J.* function is stubbed. The loader
-- only lays down the ENGINE plumbing the helpers read —
--   * every hero as a mock unit at its real position/HP/mana/level/net worth/team,
--   * GetUnitList/GetTeamPlayers/GetTeamMember over the fixture roster,
--   * each enemy's GetEstimatedDamageToTarget = the damage it ACTUALLY dealt to
--     the subject in the following seconds (ground truth from the replay),
-- then loads jmz_func fresh. A test calls the real helper and asserts the
-- decision. Reproduce first, then fix, then this test pins it forever.

package.path = 'tests/?.lua;' .. package.path
local api = require('mock.bot_api')
local ability_meta = require('mock.ability_meta')

local M = {}

--- Real engine ability slot + IsUltimate for one hero's dumped abilities.
---
--- The dump is FLATTENED (filtered entries are skipped), so its array index is
--- NOT the engine slot, and it carries no ultimate marker -- `AbilityType` is
--- KV data that never enters a .dem. Left as-is, `X.GetAbilityList` could not
--- fill `sAbilityList[6]` for ANY hero, so every "drive ConsiderR on a real
--- frame" test passed without reaching one line of ultimate logic (GH #36).
---
--- Resolution order, most authoritative first:
---   1. the dump's own `slot` / `is_ultimate` fields, once the dumper emits
---      them -- a newer dump always outranks this loader's reconstruction;
---   2. `mock/ability_meta.lua`, generated from the game's own hero KV, which
---      says WHICH name is the ultimate (never guessed from position: the dump
---      order genuinely differs per hero -- centaur ends ..stampede[ult],
---      horsepower[innate], while lich ends ..chain_frost[ult]).
---
--- Only the placement is reconstructed: non-ultimates keep dump order from
--- slot 0, and a hero's ultimate goes to slot 5. That mirrors the engine
--- invariant `X.GetAbilityList` itself encodes (`ability:IsUltimate() and
--- slot >= 4`) -- in game the R position is never a basic-ability slot.
local function resolve_slots(unit_name, abilities)
    local ults = ability_meta.ULTIMATES[unit_name] or {}
    local by_slot, next_basic, next_ult = {}, 0, 5
    for i, a in ipairs(abilities) do
        local is_ult = a.is_ultimate
        if is_ult == nil then is_ult = ults[a.name] or false end
        local slot = a.slot
        if slot == nil then
            if is_ult then
                slot, next_ult = next_ult, next_ult + 1
            else
                slot, next_basic = next_basic, next_basic + 1
                -- Never let a basic ability squat the reserved R slot.
                if next_basic == 5 then next_basic = 6 end
            end
        end
        by_slot[i] = { slot = slot, is_ultimate = is_ult }
    end
    return by_slot
end

--- Load a fixture file. Returns J, bot (the subject), heroes (by full name), fx.
---
--- `sSubject` (optional) drives the frame from ANOTHER hero on it instead of
--- fx.self -- every unit in the slice carries its real position/HP/mana/level/
--- items/ability cooldowns, so any hero present is a legitimate subject for a
--- decision that reads only frame state. One thing does NOT transfer: the
--- `observed` block (burst damage, died_after) is ground truth about fx.self
--- only, so under an override every unit's GetEstimatedDamageToTarget is 0
--- rather than a number that would silently mean "damage dealt to someone else".
function M.load(path, sSubject)
    api.reset_modules()
    local fx = dofile(path)

    local subj_name = sSubject or fx.self
    local subj_override = subj_name ~= fx.self
    local subj_team
    for _, u in ipairs(fx.units) do
        if u.name == subj_name then subj_team = u.team end
    end
    assert(subj_team, 'fixture subject not in units: ' .. tostring(subj_name))

    -- Vision, when the dump carries it (v2 "vision+items" timelines write
    -- seen_by = the teams that could see the hero at that instant). The engine's
    -- info model is vision-limited and the shipped helpers gate on it --
    -- J.IsValid and J.CanCastOnNonMagicImmune both require CanBeSeen() -- so a
    -- fog-dependent decision only reproduces if the fixture keeps the fog.
    -- v1 fixtures omit seen_by: those stay fully visible, exactly as before.
    local function visible_to_team(u, team)
        if u.seen_by == nil then return true end
        if u.team == team then return true end -- you always see your own side
        for _, t in ipairs(u.seen_by) do
            if t == team then return true end
        end
        return false
    end
    local function visible_to_subject(u) return visible_to_team(u, subj_team) end

    local heroes = {}
    for _, u in ipairs(fx.units) do
        local loc = api.Vector(u.x, u.y, 0)
        local burst = 0
        if not subj_override then
            burst = (fx.observed and fx.observed.burst and fx.observed.burst[u.name]) or 0
        end
        -- Real inventory: slot-ordered item handles ('' = empty slot). The TP
        -- scroll's real cooldown state rides on tp_cd from the dump.
        local slots = {}
        for i, itname in ipairs(u.items or {}) do
            if itname ~= '' then
                slots[i - 1] = api.MakeAbility('item_' .. itname, {
                    IsFullyCastable = true,
                })
            end
        end
        -- The TP scroll lives in the dedicated slot (15), outside the 9 carried
        -- slots the dump lists; its real cooldown state rides on tp_cd. Every
        -- hero owns one, so synthesize the handle from the captured cooldown.
        if u.tp_cd ~= nil then
            slots[15] = api.MakeAbility('item_tpscroll', {
                IsFullyCastable = u.tp_cd <= 0,
                GetCooldownTimeRemaining = u.tp_cd,
            })
        end
        heroes[u.name] = api.MakeHero(u.name, {
            GetItemInSlot = function(_, i) return slots[i] end,
            GetTeam = u.team,
            GetLocation = loc,
            GetHealth = u.hp, GetMaxHealth = u.max_hp,
            OriginalGetHealth = u.hp, OriginalGetMaxHealth = u.max_hp,
            GetMana = u.mp, GetMaxMana = u.max_mp,
            GetLevel = u.level,
            GetNetWorth = u.net_worth or 0,
            IsAlive = u.alive,
            CanBeSeen = visible_to_subject(u),
            GetCurrentMovementSpeed = 300,
            -- The engine's AoE search. The generic Get* default answers 0, and
            -- every caller indexes `.count` / `.targetloc` on the result, so a
            -- full hero script (SkillsComplement) crashed before reaching the
            -- decision under test. Answer the CONSERVATIVE shape -- "no AoE
            -- cluster found" -- which understates opportunities rather than
            -- inventing them. A test that needs a cluster overrides the spec.
            FindAoELocation = function(self)
                return { count = 0, targetloc = self:GetLocation() }
            end,
            -- Ground truth: what this hero actually did to the subject next.
            GetEstimatedDamageToTarget = function() return burst end,
        })
        -- Real ability state from the slice: pre-populate the (name-cached)
        -- handles a hero script will fetch via GetAbilityByName, so a FULL
        -- script run (SkillsComplement) sees real levels and cooldowns.
        local slotAbilities = {}
        local resolved = resolve_slots(u.name, u.abilities or {})
        for i, a in ipairs(u.abilities or {}) do
            if a.name ~= '' then
                local h = heroes[u.name]:GetAbilityByName(a.name)
                local sp = rawget(h, '__spec')
                sp.GetLevel = a.level
                sp.GetCooldownTimeRemaining = a.cd
                -- Derived, not snapshotted: a test that anchors GetManaCost or
                -- moves GetLevel/GetCooldownTimeRemaining must see the derived
                -- answers move with it. Frozen booleans made the fixture world
                -- disagree with the engine in exactly the dimension under test
                -- (test_set.md §F) -- e.g. a 246-mana ultimate reading
                -- "fully castable" while the hero held 190 mana, which is the
                -- real reason X.ConsiderR bails on its first line in game.
                local owner = heroes[u.name]
                sp.IsTrained = function(self) return self:GetLevel() > 0 end
                sp.IsCooldownReady = function(self)
                    return self:GetCooldownTimeRemaining() <= 0
                end
                sp.IsFullyCastable = function(self)
                    return self:GetLevel() > 0
                        and self:GetCooldownTimeRemaining() <= 0
                        and owner:GetMana() >= (self:GetManaCost() or 0)
                end
                -- Truthful per the game's own KV, so X.GetAbilityList can tell
                -- the ultimate from a basic and fill sAbilityList[6] (GH #36).
                sp.IsUltimate = resolved[i].is_ultimate
                slotAbilities[resolved[i].slot] = h
            end
        end
        -- GetAbilityInSlot: real engine slots (see resolve_slots) -- helpers
        -- like J.GetReadyHardCc scan slots rather than known names, and
        -- X.GetAbilityList requires the ultimate to sit at slot >= 4.
        rawget(heroes[u.name], '__spec').GetAbilityInSlot = function(_, slot)
            return slotAbilities[slot]
        end
        -- Bypass the illusion heuristic via its own cache property: fixture
        -- units are canonical real heroes (illusions dropped at generation).
        heroes[u.name].is_suspicious_illusion = false
    end

    local bot = heroes[subj_name]
    api.install({ bot = bot, team = subj_team })

    -- Engine plumbing over the fixture roster (alive units only, like in game).
    local allies, enemies = {}, {}
    for _, u in ipairs(fx.units) do
        if u.alive then
            local h = heroes[u.name]
            if u.team == subj_team then allies[#allies + 1] = h
            else enemies[#enemies + 1] = h end
        end
    end
    GetTeamPlayers = function()
        local t = {}
        for i = 1, #allies do t[i] = i end
        return t
    end
    GetTeamMember = function(i) return allies[i] end
    GetUnitList = function(kind)
        if kind == UNIT_LIST_ENEMY_HEROES then return enemies end
        if kind == UNIT_LIST_ALLIED_HEROES then return allies end
        return {}
    end
    GetGameMode = function() return GAMEMODE_TURBO end
    DotaTime = function() return fx.time end

    -- Structures, when the fixture carries them. Without this every fixture ran
    -- with the mock's `GetTower = nil` stub, which silently turned
    -- J.GetNearbyLocationToTp -- the TP LANDING POINT for the whole rescue/
    -- defend TP family -- into its no-tower-left fallback: the FOUNTAIN. Any
    -- test that asked where a TP puts the responder was therefore testing a
    -- degenerate path that never occurs in a real game with towers standing
    -- (GH #37). J.GetRescueTpTarget's "ally is under its own tower" veto had
    -- the same problem: it scans UNIT_LIST_ALLIED_BUILDINGS, which returned {}.
    local buildings = {}
    for _, b in ipairs(fx.buildings or {}) do
        buildings[#buildings + 1] = api.MakeUnit({
            GetUnitName = b.name,
            GetTeam = b.team,
            GetLocation = api.Vector(b.x, b.y, 0),
            IsAlive = b.alive,
            GetHealth = b.alive and 1 or 0, GetMaxHealth = 1,
            CanBeSeen = true,
            -- Every shipped reader of UNIT_LIST_*_BUILDINGS filters through
            -- J.IsValidBuilding -> J.Utils.IsValidBuilding -> unit:IsBuilding().
            -- Without this the list was wired but the filter rejected all of
            -- it, so the tower loop in J.ShouldTpSupportTowerFight and the
            -- "ally is under its own tower" veto in J.GetRescueTpTarget stayed
            -- unreachable even after the GH #37 round connected GetTower.
            IsBuilding = true,
        })
    end
    if fx.buildings ~= nil then
        -- Destroyed structures are simply absent, exactly as the engine reports
        -- them (GetTower returns nil for a fallen tower -- that nil is what
        -- makes "nearest ALIVE friendly tower" the real semantics).
        local towers_by_team = {}
        local alive_buildings = {}
        for _, h in ipairs(buildings) do
            if h:IsAlive() then
                local team = h:GetTeam()
                alive_buildings[team] = alive_buildings[team] or {}
                table.insert(alive_buildings[team], h)
                if h:GetUnitName() == 'tower' then
                    towers_by_team[team] = towers_by_team[team] or {}
                    table.insert(towers_by_team[team], h)
                end
            end
        end
        -- The dump records a tower's class, position and team but not which
        -- TOWER_* enum slot it is, so the index here is positional rather than
        -- the engine's. Every shipped reader of GetTower(team, i) loops i=0..10
        -- and reduces over the whole set (nearest / count / "is it still up"),
        -- so the SET is what carries meaning and the ordering does not.
        GetTower = function(team, i)
            local t = towers_by_team[team]
            return t and t[i + 1] or nil
        end
        local prev_unit_list = GetUnitList
        GetUnitList = function(kind)
            if kind == UNIT_LIST_ALLIED_BUILDINGS then
                return alive_buildings[subj_team] or {}
            end
            if kind == UNIT_LIST_ENEMY_BUILDINGS then
                for team, list in pairs(alive_buildings) do
                    if team ~= subj_team then return list end
                end
                return {}
            end
            return prev_unit_list(kind)
        end
    end

    -- Roster-backed unit-local queries, so full hero scripts (which use
    -- bot:GetNearbyHeroes rather than the J wrappers) also see the real world.
    for _, u in ipairs(fx.units) do
        local me = heroes[u.name]
        rawget(me, '__spec').GetNearbyHeroes = function(self, radius, enemies, _)
            local out = {}
            for _, v in ipairs(fx.units) do
                local other = heroes[v.name]
                -- Vision-limited, like the engine: a hero your team cannot see
                -- is not "nearby" as far as bot:GetNearbyHeroes is concerned.
                if other ~= self and v.alive
                    and visible_to_team(v, self:GetTeam())
                    and GetUnitToUnitDistance(self, other) <= (radius or 1600)
                then
                    local isEnemy = other:GetTeam() ~= self:GetTeam()
                    if (enemies and isEnemy) or (not enemies and not isEnemy) then
                        out[#out + 1] = other
                    end
                end
            end
            return out
        end
    end

    local J = require(GetScriptDirectory() .. '/FunLib/jmz_func')

    -- unit:DistanceFromFountain() is a real engine method with no Get prefix,
    -- so the generic mock default leaves it nil and any file that compares it
    -- (mode_retreat_generic X.ShouldRun) dies on load. The fountains are fixed
    -- map constants the shipped code already carries, so wire the REAL distance
    -- per team rather than a placeholder.
    local vOurFountain, vEnemyFountain = J.GetTeamFountain(), J.GetEnemyFountain()
    for _, u in ipairs(fx.units) do
        local vFountain = (u.team == subj_team) and vOurFountain or vEnemyFountain
        rawget(heroes[u.name], '__spec').DistanceFromFountain = function(self)
            return GetUnitToLocationDistance(self, vFountain)
        end
    end

    return J, bot, heroes, fx
end

--- Record every Action_* / ActionQueue_* the subject takes. Returns the log
--- (list of {fn=..., args={...}}); call before running a hero script.
function M.record_actions(bot)
    local log = {}
    local spec = rawget(bot, '__spec')
    for _, fn in ipairs({
        'Action_UseAbility', 'Action_UseAbilityOnEntity',
        'Action_UseAbilityOnLocation', 'Action_UseAbilityOnTree',
        'ActionQueue_UseAbility', 'ActionQueue_UseAbilityOnEntity',
        'ActionQueue_UseAbilityOnLocation',
        'ActionPush_UseAbility', 'ActionPush_UseAbilityOnEntity',
        'ActionPush_UseAbilityOnLocation',
        'Action_AttackUnit', 'Action_MoveToLocation', 'Action_MoveToUnit',
        'Action_ClearActions',
    }) do
        spec[fn] = function(_, ...)
            log[#log + 1] = { fn = fn, args = { ... } }
        end
        rawset(bot, fn, nil) -- drop any lazily-cached method so the spy is used
    end
    return log
end

--- Load a full hero script (bots/BotLib/hero_<part>.lua) into the installed
--- fixture world and return its module table (X). Must be called after load().
function M.load_hero(part)
    return dofile(GetScriptDirectory() .. '/BotLib/hero_' .. part .. '.lua')
end

return M

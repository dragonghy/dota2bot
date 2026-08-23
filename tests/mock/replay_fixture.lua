-- Rebuild a real replay instant (a make_fixture.py fixture) under the mock Bot
-- API, so the REAL decision helpers in jmz_func run on the REAL game state.
--
-- This is the local-validation keystone: no J.* function is stubbed. The loader
-- only lays down the ENGINE plumbing the helpers read —
--   * every hero as a mock unit at its real position/HP/mana/level/net worth/team,
--   * GetUnitList/GetTeamPlayers/GetTeamMember over the fixture roster,
--   * each enemy's GetEstimatedDamageToTarget = the damage it ACTUALLY dealt to
--     the subject in the following seconds (ground truth from the replay), or
--     0 when the fixture declares that ground truth unattributable
--     (observed.ground_truth_ambiguous -- an illusion was on the field),
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
        -- `ground_truth_ambiguous` is the generator refusing to attribute the
        -- damage rows on this frame: the combat log names units, not entities,
        -- so while an illusion/clone of the subject (or of one of its
        -- attackers) is on the field, "damage dealt to the subject" is not a
        -- knowable number. Same rule as the sSubject override above -- 0, not a
        -- number that would silently mean damage dealt to someone else.
        -- Measured case: 20260820_102030 t=639.5, where the name-keyed sum
        -- claimed 849 damage in 3s while the tidehunter's own entity
        -- REGENERATED (1419 -> 1423).
        if not subj_override and not (fx.observed and fx.observed.ground_truth_ambiguous) then
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
        -- Real buffs/debuffs active at the instant, when the fixture carries
        -- them. Without this every fixture ran with the mock's blanket
        -- `HasModifier == false` (the Is/Has/Can default), which states a world
        -- assumption nobody declared: nobody rooted, stunned, silenced, hexed,
        -- channelling a TP, or holding any buff. Two consequences, both silent:
        -- shipped branches that are ENTERED through a modifier were structurally
        -- unreachable in every fixture (all of mode_roam_generic's
        -- continuous-attack branches; the tpscroll consider function's opening
        -- veto list), and a test could assert "it should have walked away here"
        -- on a frame where the hero could not move at all. Same class as the
        -- GetTower / GetIncomingTrackingProjectiles gaps.
        -- v1 fixtures (and any hero carrying none at the instant) omit the
        -- field and keep the old always-false world byte for byte.
        local mods = u.modifiers or {}
        local by_name = {}
        for _, m in ipairs(mods) do
            if by_name[m.name] == nil then by_name[m.name] = m end
        end
        -- What hit this hero in the seconds BEFORE the instant. Without it the
        -- mock's Is/Has/Can/Was default answered `false` at all 670
        -- WasRecentlyDamagedBy* call sites under bots/ -- an undeclared world
        -- assumption ("nobody here has been hit by anything recently") in the
        -- same family as the pre-modifiers HasModifier default and the
        -- GetTower / GetIncomingTrackingProjectiles gaps. It made whole shipped
        -- branches structurally unreachable: J.ShouldAbandonTpChannel bails on
        -- its `WasRecentlyDamagedByAnyHero(1.5)` line, so the gated `tpwatch`
        -- body could never be reached on a real frame, and the "am I under
        -- fire" guards in aba_defend/jmz_func read calm on every fixture.
        --
        -- `observed.damage` cannot substitute: it looks FORWARD from t (ground
        -- truth about what followed) while these readers look BACKWARD (what
        -- the bot already knows at t).
        --
        -- v1 fixtures (and any hero nothing hit inside the lookback) omit the
        -- field, and the four readers below are then NOT installed at all --
        -- the mock default stands, which is the same answer for the right
        -- reason. A hero the generator marked `recent_damage_ambiguous` (an
        -- illusion of it, or of one of its attackers, was on the field during
        -- the lookback) lands here too: those rows are name-keyed and cannot
        -- say which copy was hit, and a declared refusal beats a fabricated
        -- history.
        local rdmg = u.recent_damage
        local rwin = fx.recent_window
        local damage_readers = nil
        if rdmg ~= nil then
            -- The fixture only saw `recent_window` seconds of history, so a
            -- query for a longer interval is answered from what exists and
            -- flagged rather than silently under-reported.
            local function hit(fInterval, pred)
                local n = tonumber(fInterval) or 0
                if rwin ~= nil and n > rwin then n = rwin end
                for _, d in ipairs(rdmg) do
                    if d.dt <= n and pred(d) then return true end
                    if d.dt > n then break end -- generator sorts by dt ascending
                end
                return false
            end
            damage_readers = {
                WasRecentlyDamagedByAnyHero = function(_, f)
                    return hit(f, function(d) return d.kind == 'hero' end)
                end,
                WasRecentlyDamagedByHero = function(_, hUnit, f)
                    local nm = hUnit ~= nil and hUnit:GetUnitName() or nil
                    return hit(f, function(d) return d.kind == 'hero' and d.actor == nm end)
                end,
                WasRecentlyDamagedByTower = function(_, f)
                    return hit(f, function(d) return d.kind == 'tower' end)
                end,
                WasRecentlyDamagedByCreep = function(_, f)
                    return hit(f, function(d) return d.kind == 'creep' end)
                end,
            }
        end
        heroes[u.name] = api.MakeHero(u.name, {
            GetItemInSlot = function(_, i) return slots[i] end,
            HasModifier = function(_, sName) return by_name[sName] ~= nil end,
            NumModifiers = #mods,
            -- Engine indices are 0-based; jmz's own readers scan
            -- `for i = 0, NumModifiers()` (one past the end), so the extra index
            -- must answer harmlessly rather than crash.
            GetModifierName = function(_, i) return (mods[i + 1] or {}).name or '' end,
            GetModifierRemainingDuration = function(_, i)
                return (mods[i + 1] or {}).remaining or 0
            end,
            GetModifierStackCount = function(_, i)
                return (mods[i + 1] or {}).stacks or 0
            end,
            GetTeam = u.team,
            -- The real engine player slot, when the fixture carries it. Every
            -- role question routes through it (aba_role.GetPosition matches it
            -- against GetTeamPlayers and reads RoleAssignment), and so does
            -- every J.Utils per-hero cache key. nil here = the mock's own
            -- default stands, which is the pre-#53 world.
            GetPlayerID = u.player_id,
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
        if damage_readers ~= nil then
            local dsp = rawget(heroes[u.name], '__spec')
            for k, v in pairs(damage_readers) do dsp[k] = v end
        end
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

    -- GH #61: refuse to answer GetLaneFrontLocation from the loader.
    -- The 125 shipped call sites read a per-team, per-lane point that the .dem
    -- does not carry (dumper samples creeps at 3 s intervals, without lane
    -- attribution or per-team side, and the engine's frontOffset argument needs
    -- lane pathnodes -- reconstructing this would be modelling, not restoring
    -- ground truth). The api.install() default answers (0,0,0) for every team
    -- and lane, which silently made `ds.defendLoc` the middle of the river and
    -- `ds.distanceToLane` identical across the three lanes -- a stub the
    -- final-desire assertions in the defend/tpwatch family were unknowingly
    -- pressing against.
    --
    -- The loader now raises. A test that needs a lane front must DECLARE its
    -- assumption by overwriting the global itself:
    --
    --     GetLaneFrontLocation = function(_, lane) return Vector(x, y, 0) end
    --
    -- A test that overwrites it to `function() return Vector(0, 0, 0) end` is
    -- taking the pre-#61 stub as an EXPLICIT choice, and any final-desire
    -- claim it makes now says so on its face.
    _G.GetLaneFrontLocation = function()
        error(
            'LOADER REFUSES: GetLaneFrontLocation is unresolved (GH #61). '
            .. 'The dump does not carry lane fronts; do not compare against '
            .. '(0,0,0). Declare your assumption in the test with '
            .. '`GetLaneFrontLocation = function(_, lane) return Vector(...) end`.',
            2)
    end

    -- Engine plumbing over the fixture roster (alive units only, like in game).
    local allies, enemies = {}, {}
    for _, u in ipairs(fx.units) do
        if u.alive then
            local h = heroes[u.name]
            if u.team == subj_team then allies[#allies + 1] = h
            else enemies[#enemies + 1] = h end
        end
    end
    -- The team ROSTER (dead members included, ordered by player slot), which is
    -- what the engine's GetTeamPlayers/GetTeamMember report -- as opposed to
    -- GetUnitList(UNIT_LIST_ALLIED_HEROES), which is the live units in the
    -- world. Both were the alive-only list before, and with no player ids to
    -- report GetTeamPlayers answered bare indices 1..N; aba_role.GetPosition
    -- matches `heroID[i] == bot:GetPlayerID()`, so nothing ever matched, every
    -- ally fell through to the same fallback and the fixture world claimed all
    -- five allies were pos 1 -- i.e. J.IsCore was true for everyone, in every
    -- fixture. That is a definite wrong answer, not a refusal, so any assertion
    -- that forked on core/support was decided by the harness (issue #53).
    local roster = {}
    for _, u in ipairs(fx.units) do
        if u.team == subj_team and u.player_id ~= nil then
            roster[#roster + 1] = { pid = u.player_id, hero = heroes[u.name] }
        end
    end
    if #roster > 0 then
        table.sort(roster, function(a, b) return a.pid < b.pid end)
        GetTeamPlayers = function()
            local t = {}
            for i, r in ipairs(roster) do t[i] = r.pid end
            return t
        end
        GetTeamMember = function(i)
            return roster[i] and roster[i].hero or nil
        end
    else
        -- Fixtures generated before the dumper emitted player_id keep the world
        -- they were validated in, byte for byte. tests/test_fixture_roles.lua
        -- ratchets the list of those, so the degenerate world can only shrink.
        GetTeamPlayers = function()
            local t = {}
            for i = 1, #allies do t[i] = i end
            return t
        end
        GetTeamMember = function(i) return allies[i] end
    end

    -- The DRAFTED role, when the fixture carries it. Without it aba_role.
    -- GetPosition falls through to RoleAssignment[team][i], i.e. the hero's
    -- draft SLOT -- and GH #57 measured that against the real draft at 47.3%
    -- (23/60 on the six games behind this repo's 2026-08-20 fixtures). The role
    -- is a property of the soak seed and travels glued to the hero;
    -- X.ShufflePickOrder moves only the slot. In game the shuffle swaps
    -- RoleAssignment alongside sSelectList so the engine sees the drafted role;
    -- the loader has no shuffle to replay, so it must be told.
    -- `bot.assignedRole` is the first thing aba_role.GetPosition reads.
    if fx.roles ~= nil then
        for name, pos in pairs(fx.roles) do
            local h = heroes[name]
            if h ~= nil then rawset(h, 'assignedRole', pos) end
        end
    end

    -- Fog memory. GetHeroLastSeenInfo is the engine's "where do I remember this
    -- hero being, and how stale is that" API; the mock answered `{}` for every
    -- id, so J.GetLastSeenEnemiesNearLoc / J.GetLastSeenEnemies / every
    -- last-seen head-count in aba_defend returned an EMPTY LIST on every
    -- fixture, on every frame. That is one more undeclared world assertion of
    -- the same family as GetTower, GetIncomingTrackingProjectiles, HasModifier
    -- and WasRecentlyDamagedBy*: "nobody has ever seen an enemy anywhere".
    --
    -- Two halves are needed, because the readers all look like
    --   for _, id in pairs(GetTeamPlayers(GetOpposingTeam())) do
    --       local info = GetHeroLastSeenInfo(id) ... info[1].location
    -- and GetTeamPlayers above answers for OUR team only. The opposing side
    -- gets the enemies' real player_ids when the fixture carries them, and an
    -- id space of its own otherwise -- disjoint from the ally ids either way.
    -- Only ALIVE enemies get an id, matching the alive-only convention the
    -- unit lists already use (every reader gates on IsHeroAlive, which the mock
    -- cannot answer per id).
    --
    -- time_since_seen: the behavioural dump carries no per-hero vision
    -- (GH #27), so today every fixture is fully visible and every sighting is
    -- current (0). If a fixture ever does carry `seen_by`, a hero the subject's
    -- team cannot see gets a deliberately unusable memory (999) rather than an
    -- invented stale location -- every shipped reader gates on
    -- `time_since_seen < N`, so that reads as "no useful memory", never as a
    -- sighting we made up.
    local ENEMY_ID_BASE = 100
    local lastSeenById, enemyIds = {}, {}
    local function stampLastSeen(u, id)
        lastSeenById[id] = { {
            location = api.Vector(u.x, u.y, 0),
            time_since_seen = visible_to_subject(u) and 0 or 999,
        } }
    end
    local nEnemy = 0
    for _, u in ipairs(fx.units) do
        if u.alive then
            if u.team == subj_team then
                -- Ally ids come from the roster above, so look the id up rather
                -- than inventing one.
                for i, id in ipairs(GetTeamPlayers(subj_team)) do
                    if GetTeamMember(i) == heroes[u.name] then stampLastSeen(u, id) end
                end
            else
                nEnemy = nEnemy + 1
                local id = u.player_id
                if id == nil then id = ENEMY_ID_BASE + nEnemy end
                enemyIds[#enemyIds + 1] = id
                stampLastSeen(u, id)
            end
        end
    end

    local ownTeamPlayers = GetTeamPlayers
    GetTeamPlayers = function(team)
        if team ~= nil and team ~= subj_team then
            local t = {}
            for i, id in ipairs(enemyIds) do t[i] = id end
            return t
        end
        return ownTeamPlayers(team)
    end
    GetHeroLastSeenInfo = function(id) return lastSeenById[id] or {} end
    -- UNIT_LIST_ALL: the world-sweep list. Until this line it fell through to
    -- the `{}` below, so every reader that enumerates the world through it saw
    -- an EMPTY WORLD -- not "no creeps", NO UNITS AT ALL, heroes included.
    -- That is an undeclared world assumption in the same family as the
    -- HasModifier / WasRecentlyDamagedBy* / GetHeroLastSeenInfo / structure
    -- gaps before it, and it decides some heavily-read numbers:
    --   * mode_retreat_generic.buildContext builds BOTH its hero lists from it,
    --     so #nAllyHeroes and #nEnemyHeroes were 0 in every fixture and every
    --     "am I outnumbered here" comparison in the retreat bid compared 0 to 0;
    --   * J.WeAreStronger(bot, r) sums power over it, so it weighed an empty
    --     team against an empty team in every fixture.
    -- The heroes are ground truth in the dump, so they are restored here.
    -- WHAT IS STILL MISSING, DECLARED RATHER THAN FAKED: the engine's
    -- UNIT_LIST_ALL also carries creeps, buildings, couriers, wards and
    -- summons. The fixture generator writes heroes (and, since the structures
    -- round, buildings under their own key) but no creeps or summons -- a
    -- SUPPLY gap of the GH #27 kind, not something to invent. Buildings are
    -- deliberately NOT injected here either: the one shipped reader that would
    -- pick them up (buildContext's tower-danger clause) multiplies
    -- GetAttackDamage() * GetAttackSpeed(), neither of which the dump carries.
    -- So: any assertion that needs a CREEP, a SUMMON or a TOWER to be seen
    -- through UNIT_LIST_ALL is still reading an empty set and must say so.
    -- Self is included, exactly as the engine reports it (the bot is a unit in
    -- the world), which is why `#nAllyHeroes` is never 0 for a live bot.
    local allUnits = {}
    for _, h in ipairs(allies) do allUnits[#allUnits + 1] = h end
    for _, h in ipairs(enemies) do allUnits[#allUnits + 1] = h end
    GetUnitList = function(kind)
        if kind == UNIT_LIST_ENEMY_HEROES then return enemies end
        if kind == UNIT_LIST_ALLIED_HEROES then return allies end
        if kind == UNIT_LIST_ALL then return allUnits end
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
            -- Structures carry a real health fraction when the fixture has one
            -- (`hp`, 0..1 from the dump). Without it every building in every
            -- fixture stood at FULL health, which is not a neutral default:
            -- aba_defend's urgency multiplier is a remap of the building's hp
            -- fraction, and its "this tier-1/2 is already lost, stop
            -- defending" early return is a threshold on the same number.
            IsAlive = b.alive,
            GetHealth = b.alive and math.floor(1000 * (b.hp or 1)) or 0,
            GetMaxHealth = 1000,
            -- J.GetHP reads the UN-hooked engine getters for own-team units;
            -- without these it compared nil to a number and crashed as soon as
            -- a structure of the subject's own team reached it.
            OriginalGetHealth = b.alive and math.floor(1000 * (b.hp or 1)) or 0,
            OriginalGetMaxHealth = 1000,
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
        -- SLOT-ADDRESSABLE STRUCTURES.
        --
        -- The dump records a tower's class, position and team but not which
        -- TOWER_* enum slot it is, so the previous wiring indexed the alive
        -- towers POSITIONALLY. That is enough for the readers that loop
        -- i = 0..10 and reduce over the whole set (nearest / count / "is it
        -- still up"), which is what the GH #37 round needed -- but it is NOT
        -- enough for a reader that asks for ONE named slot, and the mock
        -- resolves unknown ALL_CAPS globals to sentinel integers, so
        -- `GetTower(team, TOWER_MID_1)` asked for slot <sentinel> and got nil.
        --
        -- One such reader gates a large shipped surface:
        -- aba_defend.GetFurthestBuildingOnLaneHelper walks
        -- GetTower(team, Tower.Top1/2/3) -> GetBarracks(team, ...) -> ancient,
        -- and GetDefendDesireHelper does
        --     if not IsValidBuildingTarget(furthestBuilding) then return None end
        -- So in every fixture that helper returned nil, every lane's defend
        -- desire came out of the SEVEN early returns above that line, and the
        -- ENTIRE bottom half of GetDefendDesireHelper -- ShouldDefend, the
        -- capBoost/baseFloor pair, the panic floor, the recentlyHit
        -- attenuator, ConsiderPingedDefend, the tier/HP remaps -- was
        -- structurally unreachable. Same family as the HasModifier,
        -- WasRecentlyDamagedBy* and GetHeroLastSeenInfo gaps before it: an
        -- undeclared world assumption, here "this team has no buildings on
        -- any lane".
        --
        -- Slots are DERIVED from geometry rather than hardcoded, and derived
        -- over the FULL building set (destroyed ones included) so that losing
        -- a tower does not silently renumber the survivors:
        --   * the two structures nearest the team's own ancient are its base
        --     towers (next-nearest is ~3x further away, so the split is not
        --     close);
        --   * s = y - x separates the three lane corridors, which are
        --     symmetric about the mid diagonal: |s| < 1000 is mid, s > 0 is
        --     top, s < 0 is bot. Measured over the real building tables in
        --     this repo's fixtures the mid towers sit at |s| <= 513 and the
        --     nearest lane tower at |s| = 2160, so the margin is 4x;
        --   * within a lane, furthest-from-own-ancient is tier 1.
        -- GetTower still returns nil for a destroyed slot -- that nil is the
        -- engine's own "nearest ALIVE tower" semantics.
        local ENUM = {
            TOWER_TOP_1 = 0, TOWER_TOP_2 = 1, TOWER_TOP_3 = 2,
            TOWER_MID_1 = 3, TOWER_MID_2 = 4, TOWER_MID_3 = 5,
            TOWER_BOT_1 = 6, TOWER_BOT_2 = 7, TOWER_BOT_3 = 8,
            TOWER_BASE_1 = 9, TOWER_BASE_2 = 10,
            BARRACKS_TOP_MELEE = 0, BARRACKS_TOP_RANGED = 1,
            BARRACKS_MID_MELEE = 2, BARRACKS_MID_RANGED = 3,
            BARRACKS_BOT_MELEE = 4, BARRACKS_BOT_RANGED = 5,
        }
        for name, value in pairs(ENUM) do _G[name] = value end

        local ancient_by_team = {}
        for _, h in ipairs(buildings) do
            if h:GetUnitName() == 'ancient' then ancient_by_team[h:GetTeam()] = h end
        end

        local function d2(a, b)
            local dx, dy = a.x - b.x, a.y - b.y
            return dx * dx + dy * dy
        end
        -- team -> { [slot] = handle } over the FULL set (alive or not).
        local tower_slots, barracks_slots = {}, {}
        local by_team = {}
        for _, h in ipairs(buildings) do
            local name = h:GetUnitName()
            if name == 'tower' or name == 'barracks' then
                by_team[h:GetTeam()] = by_team[h:GetTeam()] or { tower = {}, barracks = {} }
                table.insert(by_team[h:GetTeam()][name], h)
            end
        end
        local function lane_of(h)
            local l = h:GetLocation()
            local s = l.y - l.x
            if s > 1000 then return 'top' elseif s < -1000 then return 'bot' end
            return 'mid'
        end
        for team, sets in pairs(by_team) do
            local anc = ancient_by_team[team]
            tower_slots[team], barracks_slots[team] = {}, {}
            if anc ~= nil then
                local ancLoc = anc:GetLocation()
                local towers = {}
                for _, h in ipairs(sets.tower) do towers[#towers + 1] = h end
                table.sort(towers, function(a, b)
                    return d2(a:GetLocation(), ancLoc) < d2(b:GetLocation(), ancLoc)
                end)
                -- Base pair first (nearest two), then the lanes.
                local lanes = { top = {}, mid = {}, bot = {} }
                for i, h in ipairs(towers) do
                    if i == 1 then
                        tower_slots[team][ENUM.TOWER_BASE_1] = h
                    elseif i == 2 then
                        tower_slots[team][ENUM.TOWER_BASE_2] = h
                    else
                        table.insert(lanes[lane_of(h)], h)
                    end
                end
                local base = { top = ENUM.TOWER_TOP_1, mid = ENUM.TOWER_MID_1, bot = ENUM.TOWER_BOT_1 }
                for lane, list in pairs(lanes) do
                    table.sort(list, function(a, b)
                        return d2(a:GetLocation(), ancLoc) > d2(b:GetLocation(), ancLoc)
                    end)
                    for i, h in ipairs(list) do
                        if i <= 3 then tower_slots[team][base[lane] + i - 1] = h end
                    end
                end
                -- Barracks: melee is the one nearer the ancient of each lane pair.
                local rax = { top = {}, mid = {}, bot = {} }
                for _, h in ipairs(sets.barracks) do table.insert(rax[lane_of(h)], h) end
                local rbase = {
                    top = ENUM.BARRACKS_TOP_MELEE,
                    mid = ENUM.BARRACKS_MID_MELEE,
                    bot = ENUM.BARRACKS_BOT_MELEE,
                }
                for lane, list in pairs(rax) do
                    table.sort(list, function(a, b)
                        return d2(a:GetLocation(), ancLoc) < d2(b:GetLocation(), ancLoc)
                    end)
                    for i, h in ipairs(list) do
                        if i <= 2 then barracks_slots[team][rbase[lane] + i - 1] = h end
                    end
                end
            end
        end

        GetTower = function(team, i)
            local slots = tower_slots[team]
            local h = slots and slots[i]
            if h ~= nil and h:IsAlive() then return h end
            -- Pre-slot fixtures and any team the fixture has no ancient for
            -- keep the old positional answer, so nothing already pinned moves.
            if slots ~= nil and next(slots) ~= nil then return nil end
            local t = towers_by_team[team]
            return t and t[i + 1] or nil
        end
        GetBarracks = function(team, i)
            local slots = barracks_slots[team]
            local h = slots and slots[i]
            if h ~= nil and h:IsAlive() then return h end
            return nil
        end
        if next(ancient_by_team) ~= nil then
            -- The bare mock answers every team with one 4500-hp unit at the map
            -- ORIGIN, i.e. "both ancients stand on top of each other in the
            -- river" -- which decides every base-threat and fountain-direction
            -- question in the wrong place.
            GetAncient = function(team) return ancient_by_team[team] end
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

        -- UNIT-LOCAL STRUCTURE QUERIES.
        --
        -- The bare mock answers every method whose name starts with GetNearby
        -- with `{}` (bot_api default_for). The loader had wired GetNearbyHeroes
        -- but nothing else, so in EVERY fixture
        --     bot:GetNearbyTowers(r, bEnemies)   -- 183 call sites in bots/
        --     bot:GetNearbyBarracks(r, bEnemies) --  20 call sites
        -- both answered "there is no tower and no barracks anywhere near
        -- anybody" -- even though the fixture already carries every structure
        -- with its real team, position and alive flag (they were reachable
        -- only through GetTower / GetAncient / UNIT_LIST_*_BUILDINGS). Same
        -- family as the GetTower-slot, GetHeroLastSeenInfo and UNIT_LIST_ALL
        -- gaps before it: an undeclared world assumption sitting under an
        -- otherwise real frame.
        --
        -- This is a RESTORATION, not a model: team, position and alive state
        -- are dump ground truth. Two things are stated rather than invented:
        --   * ALIVE only -- a destroyed tower is absent, which is the semantics
        --     every reader already assumes (`nEnemyTowers[1]` = "the nearest
        --     tower still standing").
        --   * SORTED BY DISTANCE ascending. The engine makes no documented
        --     promise here, but every shipped consumer reads [1] as "the
        --     closest one" (mode_retreat_generic's GetAttackTarget() == bot
        --     check, aba_push's tier walk), so an unsorted list would make
        --     those readers answer about an arbitrary tower.
        -- Outposts (`watch_tower`) are deliberately NOT included: the engine
        -- returns tower-class structures here, and the outpost has its own
        -- reader.
        local function nearby_structures(name)
            return function(self, radius, bEnemies)
                local out = {}
                for _, h in ipairs(buildings) do
                    if h:GetUnitName() == name and h:IsAlive() then
                        local isEnemy = h:GetTeam() ~= self:GetTeam()
                        if (bEnemies and isEnemy) or (not bEnemies and not isEnemy) then
                            if GetUnitToUnitDistance(self, h) <= (radius or 1600) then
                                out[#out + 1] = h
                            end
                        end
                    end
                end
                table.sort(out, function(a, b)
                    return GetUnitToUnitDistance(self, a) < GetUnitToUnitDistance(self, b)
                end)
                return out
            end
        end
        for _, u in ipairs(fx.units) do
            local spec = rawget(heroes[u.name], '__spec')
            spec.GetNearbyTowers = nearby_structures('tower')
            spec.GetNearbyBarracks = nearby_structures('barracks')
        end
    end

    -- Roster-backed unit-local queries, so full hero scripts (which use
    -- bot:GetNearbyHeroes rather than the J wrappers) also see the real world.
    --
    -- SORTED BY DISTANCE ascending, same as nearby_structures above and for a
    -- stronger reason: here the engine DOES make the promise.
    -- docs/BOT_API_REFERENCE.md:1229 -- "All return tables sorted by distance
    -- (closest first)" -- covers the whole GetNearby* family. `fx.units` is
    -- written by make_fixture.py in ALPHABETICAL hero-name order (`for h in
    -- sorted(per)`), so handing it back untouched made every shipped branch
    -- that reads list[1], or that stops at the first hit of a
    -- `for _ in pairs(...)`, answer about the alphabetically-first hero in the
    -- radius instead of the nearest one. 2277 GetNearbyHeroes call sites in
    -- bots/ read this list, and J.GetNearbyHeroes (jmz_func.lua:2517) only
    -- filters -- it never reorders -- so the loader is the only place the
    -- order can be restored.
    --
    -- The ordering is STATED, not dumped: a .dem carries no list order. Ties
    -- (two heroes at the same distance) break on unit name so the list is a
    -- total order and a test that pins a target cannot flap between runs; the
    -- engine makes no such promise, and no reading here may depend on which
    -- of two equidistant heroes comes first.
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
            table.sort(out, function(a, b)
                local da, db = GetUnitToUnitDistance(self, a), GetUnitToUnitDistance(self, b)
                if da == db then return a:GetUnitName() < b:GetUnitName() end
                return da < db
            end)
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

--- How far in the past a "stale" defence ping sits. Any value larger than the
--- widest shipped window (aba_defend's 6.0s) would do; a big round number is
--- chosen so a test that prints the stamp cannot mistake it for a real time.
local DEFEND_PING_STALE_AGE = 1e6

--- Declare, for THIS fixture VM, how long ago somebody pinged for defence.
---
--- GH #91. `J.Utils.GameStates.defendPings` is lazily initialised BY the same
--- clock reading it is later compared against (bots/mode_farm_generic.lua:135,
--- was :124 before the 2026-08-24 'campsel' wrapper shifted the file by +11,
--- and three siblings), so in a one-call VM the first reader is its own
--- initialiser and `GameTime() - pingedTime` is exactly 0. Three shipped bids
--- (farm, side_shop, all three push_tower_* via aba_push) return their floor
--- on every fixture frame as a result.
---
--- The loader deliberately does NOT pick a side for you. Whether anybody
--- pinged in the last five seconds is NOT in the .dem -- the dumper captures
--- no pings -- so a loader default would be modelling a value we have no
--- ground truth for, silently, in every test at once (the same reason path 1
--- of GH #89 was refused). Instead the assumption is one visible line in the
--- test that depends on it.
---
--- There is no default argument on purpose: `state` must be 'stale' (nobody
--- pinged recently -- the common case in a live game) or 'fresh' (somebody
--- pinged just now -- the guard's intended domain). Anything else raises,
--- rather than falling back to a value that could never go red.
--- Returns the pingedTime written, for tests that want to assert on it.
function M.declare_defend_ping(J, state)
    if state ~= 'stale' and state ~= 'fresh' then
        error("declare_defend_ping: state must be 'stale' or 'fresh', got "
            .. tostring(state), 2)
    end
    local now = GameTime()
    local stamped = (state == 'stale') and (now - DEFEND_PING_STALE_AGE) or now
    J.Utils['GameStates'] = J.Utils['GameStates'] or {}
    J.Utils['GameStates']['defendPings'] = { pingedTime = stamped }
    return stamped
end

--- Load a full hero script (bots/BotLib/hero_<part>.lua) into the installed
--- fixture world and return its module table (X). Must be called after load().
function M.load_hero(part)
    return dofile(GetScriptDirectory() .. '/BotLib/hero_' .. part .. '.lua')
end

return M

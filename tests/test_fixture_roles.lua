-- GH #53 contract: a fixture must answer "who is a core" with the REAL roles,
-- or admit it cannot answer at all.
--
-- The bot API's whole role chain hangs off one number: aba_role.GetPosition
-- matches `bot:GetPlayerID()` against `GetTeamPlayers(GetTeam())` and reads
-- RoleAssignment at that slot; `J.IsCore(bot) = J.GetPosition(bot) <= 3`.
-- Before this contract, the mock defaulted every hero's GetPlayerID to 0 and
-- the loader answered GetTeamPlayers with bare indices 1..N, so NOTHING ever
-- matched, every ally fell through to the same fallback, and all five read
-- pos 1 -- i.e. `J.IsCore` was TRUE for every hero in all 61 fixtures. Any
-- assertion that forked on core vs support was decided by the harness, not by
-- the frame (the end-to-end example in test_replay_creeppull_reachable.lua is
-- one: jmz_func's pull bid opens with `if not J.IsCore(bot) then return nil`).
--
-- Same family as GH #27 (no `vis` -> everyone judged visible), GH #36 (no
-- ultimate marker -> every R gate no-opped) and test_set.md §F (GetTower = nil
-- -> every TP landed at the fountain): the fixture world was poorer than the
-- engine in one dimension, and it was poor by giving a DEFINITE WRONG ANSWER
-- rather than by refusing.
--
-- The fix is upstream, not in this file: the dumper now emits `player_id`
-- (m_iPlayerID, un-zigzagged) and make_fixture.py passes it through, so fixtures
-- generated from here on carry the real slots. Fixtures made before that keep
-- the world they were validated in, byte for byte -- and LEGACY_NO_ROLE_DATA
-- below is the debt register for them: it can only ever shrink.
--
-- Ground truth for the anchor fixture is the game's own analysis.json, whose
-- `team_slot` is what the batch harness assigned:
--   radiant slot 0 lina / 1 crystal_maiden / 2 dragon_knight / 3 juggernaut /
--   4 obsidian_destroyer  (dire slots 0-4 = medusa/queen_of_pain/viper/lich/
--   witch_doctor, player ids 5-9). Verified 10/10 against the .dem's raw
--   m_iPlayerID when the dumper field was added.
--
-- READ THAT AS SLOTS, NOT ROLES (GH #57, stated here 2026-08-20T23:30Z). The
-- anchor's EXPECT table below is `pos = team_slot + 1`, i.e. exactly what the
-- loader's own fallback answers when a fixture carries no `roles`. It cannot be
-- anything else: this game's `script_version` is the bare tree sha `829202a`,
-- with no `:s<seed>:`, so seed_draft.positions_for_game REFUSES it and the
-- drafted role is unrecoverable for this frame. What the anchor still proves is
-- the roster/player_id chain -- five allies, five DISTINCT positions, dead ones
-- included -- which is the pre-#53 collapse it was written to catch. What it
-- does NOT prove is that any of those five numbers is the hero's drafted role.
-- The separate contract for that is SLOT_DERIVED_ROLES below, and the worked
-- example of the two coming apart is tests/test_defstale_defend_bail.lua
-- (seed 868: a jakiro the slot called a pos 3 core is a drafted pos 5 support).

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')

-- Real frame from a real batch game (20260819_221200_slot1 @ t=300.0), the
-- first fixture generated with player_id. Two of the five allies are DEAD at
-- this instant, which is deliberate: the roster readers must still report all
-- five, the way the engine does.
local FIXTURE = 'tests/fixtures/f_221200_od_roles.lua'

-- player id -> what the role chain must answer for it, on the subject's team.
local EXPECT = {
    [0] = { hero = 'npc_dota_hero_lina',               pos = 1, core = true },
    [1] = { hero = 'npc_dota_hero_crystal_maiden',     pos = 2, core = true },
    [2] = { hero = 'npc_dota_hero_dragon_knight',      pos = 3, core = true },
    [3] = { hero = 'npc_dota_hero_juggernaut',         pos = 4, core = false },
    [4] = { hero = 'npc_dota_hero_obsidian_destroyer', pos = 5, core = false },
}

local tests = {}

tests['the roster reports the real player slots, dead members included'] = function()
    local _, bot = rf.load(FIXTURE)
    local ids = GetTeamPlayers(GetTeam())

    assert(#ids == 5, 'GetTeamPlayers must report the whole roster (5), got '
        .. #ids .. ' -- the alive-only list it used to return silently reindexes '
        .. 'every role whenever an ally is dead')
    for i, pid in ipairs(ids) do
        assert(pid == i - 1, 'roster slot ' .. i .. ' is player id ' .. tostring(pid)
            .. ', want ' .. (i - 1) .. ' (ids must be the engine\'s, in slot order)')
        local m = GetTeamMember(i)
        assert(m ~= nil, 'GetTeamMember(' .. i .. ') is nil while GetTeamPlayers '
            .. 'reports ' .. #ids .. ' members -- the two readers must agree')
        assert(m:GetPlayerID() == pid, 'GetTeamMember(' .. i .. ') is '
            .. m:GetUnitName() .. ' with id ' .. tostring(m:GetPlayerID())
            .. ', but GetTeamPlayers says ' .. tostring(pid))
        assert(m:GetUnitName() == EXPECT[pid].hero, 'slot ' .. (i - 1) .. ' is '
            .. m:GetUnitName() .. ', ground truth says ' .. EXPECT[pid].hero)
    end
    assert(bot:GetPlayerID() == 4, 'the subject must carry its own real id')

    -- Two allies are dead at this instant; they must still be on the roster.
    local dead = 0
    for i = 1, #ids do
        if not GetTeamMember(i):IsAlive() then dead = dead + 1 end
    end
    assert(dead == 2, 'expected 2 dead allies on this frame, got ' .. dead
        .. ' -- the anchor loses its point if the roster is all alive')
end

tests['J.GetPosition / J.IsCore answer the frame, not the default'] = function()
    local J = rf.load(FIXTURE)
    local seen = {}
    for i, pid in ipairs(GetTeamPlayers(GetTeam())) do
        local m = GetTeamMember(i)
        local want = EXPECT[pid]
        assert(J.GetPosition(m) == want.pos, want.hero .. ' (id ' .. pid
            .. '): GetPosition = ' .. tostring(J.GetPosition(m))
            .. ', want ' .. want.pos)
        assert(J.IsCore(m) == want.core, want.hero .. ': IsCore = '
            .. tostring(J.IsCore(m)) .. ', want ' .. tostring(want.core))
        seen[J.GetPosition(m)] = true
    end
    -- The #53 symptom, stated directly: five allies, five distinct positions.
    -- A world that collapses them (whatever it collapses them TO) decides every
    -- core/support fork by itself.
    for pos = 1, 5 do
        assert(seen[pos], 'no ally reads pos ' .. pos
            .. ' -- the roster collapsed, which is exactly the GH #53 defect')
    end
end

tests['both sides of the core/support fork are reachable on this frame'] = function()
    -- Guards the assertion above from rotting into a tautology: the anchor is
    -- only useful while it contains a hero the gate must ACCEPT and one it must
    -- REJECT. `J.IsCore` is what the shipped laning guards fork on.
    local J, _, heroes = rf.load(FIXTURE)
    assert(J.IsCore(heroes['npc_dota_hero_lina']) == true,
        'pos 1 must be a core')
    assert(J.IsCore(heroes['npc_dota_hero_obsidian_destroyer']) == false,
        'pos 5 must not be a core -- if this ever passes for free again, every '
        .. '"support only" / "core only" clause in jmz_func is untested')
end

tests['fixtures without role data are a shrinking, declared list'] = function()
    -- The ratchet. A fixture generated from here on carries player_id; one that
    -- does not must be named here, and a named one that gains it must be
    -- removed. Either way the degenerate world cannot grow or hide.
    local LEGACY_NO_ROLE_DATA = {
        -- the whole checked-in corpus at the time of GH #53; every one of
        -- them answers "everyone is pos 1". Names are explicit on purpose:
        -- a regenerated fixture must be deleted from here, and a new one
        -- may never be added without a reason written next to it.
        ['f_011405_jak_rescue_axe.lua'] = true,
        ['f_013254_ck_rescue_trade.lua'] = true,
        ['f_013254_lina_rescue_trade.lua'] = true,
        ['f_045650_lion_meatgrinder.lua'] = true,
        ['f_050713_es_defend_1v3.lua'] = true,
        ['f_071423_luna_chase.lua'] = true,
        ['f_071423_sky_rescue.lua'] = true,
        ['f_071859_oracle_screen.lua'] = true,
        ['f_071859_oracle_wandered.lua'] = true,
        ['f_071859_qop_salve.lua'] = true,
        ['f_071903_sven_idle.lua'] = true,
        ['f_072738_zuus_mana.lua'] = true,
        ['f_073148_zuus_lina.lua'] = true,
        ['f_080225_wk_lane.lua'] = true,
        ['f_080225_wk_revive.lua'] = true,
        ['f_113203_pudge_homeroute_silent.lua'] = true,
        ['f_113638_cm_chain_rescue.lua'] = true,
        ['f_114311_drow_pushguard_silent.lua'] = true,
        ['f_163714_zuus_commit_pin.lua'] = true,
        ['f_163732_sk_pull_ambush.lua'] = true,
        ['f_175703_sven_tp47.lua'] = true,
        ['f_181441_luna_deep_solo.lua'] = true,
        ['f_181441_zuus_lowhp_limbo.lua'] = true,
        ['f_181544_storm_escape_tp.lua'] = true,
        ['f_182552_warlock_ult_hoard.lua'] = true,
        ['f_222428_lion_lich_burst.lua'] = true,
        ['f_225947_wk_trade_kite.lua'] = true,
        ['f_230124_viper_roshan_abort.lua'] = true,
        ['f_230510_dp_luna_standoff.lua'] = true,
        ['f_230545_wk_laning_safe.lua'] = true,
        ['f_230545_wk_sven_burst.lua'] = true,
        ['f_230952_zuus_ult_hoard.lua'] = true,
        ['f_231411_ck_zoned.lua'] = true,
        ['f_232228_wk_ownhalf_standoff.lua'] = true,
        ['f_232320_wk_od_burst.lua'] = true,
        ['f_233217_lina_tp58.lua'] = true,
        ['f_260725_105305_wk_reincarn_gap.lua'] = true,
        ['f_260819_003005_cm_selfpreserve.lua'] = true,
        ['f_260819_004858_cm_centaur_far.lua'] = true,
        ['f_260819_122930_lich_rescue_doomed.lua'] = true,
        ['f_260819_122930_lina_landed_dead.lua'] = true,
        ['f_260819_123012_dk_rescue_far.lua'] = true,
        ['f_260819_123012_dp_landed_dead.lua'] = true,
        ['f_260819_123546_axe_rescue_ok.lua'] = true,
        ['f_260819_123546_jakiro_landed_ok.lua'] = true,
        ['f_260819_142047_zuus_ult_denied.lua'] = true,
        ['f_260819_142047_zuus_ult_manalock.lua'] = true,
        ['f_260819_181742_ss_chase_stalled.lua'] = true,
        ['f_260819_181742_ss_chase_start.lua'] = true,
        ['f_260819_182323_lion_drain_calm.lua'] = true,
        ['f_260819_183409_lion_drain_focused.lua'] = true,
        ['f_260819_183613_storm_collapse_lost.lua'] = true,
        ['f_260819_183613_storm_collapse_outnumbered.lua'] = true,
        ['f_260819_183613_storm_collapse_parity.lua'] = true,
        ['f_260819_222030_jugg_tp_eaten.lua'] = true,
        ['f_260819_222030_jugg_tp_start.lua'] = true,
        ['f_260819_222052_zuus_w2_leak.lua'] = true,
        ['f_260819_223607_sniper_rooted.lua'] = true,
        ['f_631400_dragon_knight_snowballtarget.lua'] = true,
        ['f_megabundle_051728_ogre_lanefront_deep.lua'] = true,
        ['f_megabundle_051728_slardar_idle.lua'] = true,
        ['f_megabundle_052241_sniper_l1trade_chase.lua'] = true,
    }

    local p = io.popen('ls tests/fixtures')
    local offenders, healed = {}, {}
    for file in p:lines() do
        if file:match('^f_.*%.lua$') then
            local fx = dofile('tests/fixtures/' .. file)
            local has = false
            for _, u in ipairs(fx.units or {}) do
                if u.player_id ~= nil then has = true end
            end
            if not has and not LEGACY_NO_ROLE_DATA[file] then
                offenders[#offenders + 1] = file
            elseif has and LEGACY_NO_ROLE_DATA[file] then
                healed[#healed + 1] = file
            end
        end
    end
    p:close()
    assert(#offenders == 0, 'fixture(s) carry no player_id, so every hero in '
        .. 'them reads pos 1 / IsCore = true: ' .. table.concat(offenders, ', ')
        .. ' -- regenerate with a current dumper, or (if the .dem is gone) add '
        .. 'the name here and say so in the test that uses it')
    assert(#healed == 0, 'these fixtures now carry player_id -- drop them from '
        .. 'LEGACY_NO_ROLE_DATA: ' .. table.concat(healed, ', '))
end

tests['the anchor pins the SLOT table, not the drafted role'] = function()
    -- Says out loud what the case above is and is not. `pos = player_id + 1`
    -- for every ally IS the loader's no-roles fallback, so the two role cases
    -- above are pinning the harness's own answer -- deliberately, because this
    -- game is unattributable (bare-sha script_version, no soak seed) and there
    -- is no drafted role to compare against. Naming it stops the next reader
    -- from citing the anchor as evidence that fixtures answer roles correctly.
    local J, _, _, fx = rf.load(FIXTURE)
    assert(fx.roles == nil, 'the anchor carries no drafted roles, and cannot: its '
        .. 'game has no soak seed. If it ever gains a `roles` table, this whole '
        .. 'file (and the EXPECT above) must be re-derived from the draft')
    for i, pid in ipairs(GetTeamPlayers(GetTeam())) do
        assert(J.GetPosition(GetTeamMember(i)) == pid + 1,
            'the anchor answers the SLOT for every ally; slot ' .. pid .. ' gave '
            .. tostring(J.GetPosition(GetTeamMember(i)))
            .. ' -- if that stopped being true the fallback changed')
    end
end

tests['fixtures whose roles are slot-derived are a declared, shrinking list'] = function()
    -- The second tier of the same debt, and until now it had no ratchet at all.
    -- A fixture can carry `player_id` (so the roster is real, and the case above
    -- passes) and STILL answer every jmz.GetPosition from the draft slot,
    -- because the drafted role is a property of the soak seed and travels glued
    -- to the hero -- hero_selection.X.ShufflePickOrder swaps sSelectList and
    -- Role.RoleAssignment together, so the pair moves and the SLOT is free.
    -- make_fixture.py --roles writes the real one; without it, GH #57 measured
    -- the slot fallback at 47.3%.
    --
    -- Membership here is a claim that nobody has re-read that fixture's
    -- conclusions under the real roles yet. Removing a name means someone did.
    local SLOT_DERIVED_ROLES = {
        -- unattributable: no soak seed in its script_version, so --roles
        -- refuses. This one can never leave the list; see the header.
        ['f_221200_od_roles.lua'] = true,
        -- attributable, simply not re-read yet -- each needs its own round
        -- (regenerate, re-run, re-read the conclusion), never a batch refresh:
        -- healing a frame may FLIP what it pins, which is the point.
        ['f_260819_182855_lion_drain_jungle.lua'] = true,
        ['f_260819_182855_lion_drain_midchannel.lua'] = true,
        ['f_260819_222559_od_eclipse_pair.lua'] = true,
        ['f_260819_222559_od_eclipse_solo.lua'] = true,
        ['f_260820_043124_axe_blink_kill.lua'] = true,
        ['f_260820_102645_cm_es_reach.lua'] = true,
        ['f_260820_103216_cm_es_aftershock.lua'] = true,
    }

    local p = io.popen('ls tests/fixtures')
    local offenders, healed = {}, {}
    for file in p:lines() do
        if file:match('^f_.*%.lua$') then
            local fx = dofile('tests/fixtures/' .. file)
            local has_pid = false
            for _, u in ipairs(fx.units or {}) do
                if u.player_id ~= nil then has_pid = true end
            end
            -- Fixtures with no player_id are the OTHER list's problem; they read
            -- pos 1 for everyone and are already declared above.
            if has_pid then
                if fx.roles == nil and not SLOT_DERIVED_ROLES[file] then
                    offenders[#offenders + 1] = file
                elseif fx.roles ~= nil and SLOT_DERIVED_ROLES[file] then
                    healed[#healed + 1] = file
                end
            end
        end
    end
    p:close()
    assert(#offenders == 0, 'fixture(s) carry player_id but no drafted roles, so '
        .. 'every jmz.GetPosition in them is the draft slot (47.3% per GH #57): '
        .. table.concat(offenders, ', ') .. ' -- regenerate with '
        .. 'make_fixture.py --roles <analysis.json>, re-read what the fixture '
        .. 'pins, or name it above with a reason')
    assert(#healed == 0, 'these fixtures now carry drafted roles -- drop them from '
        .. 'SLOT_DERIVED_ROLES and say in their test what the re-read found: '
        .. table.concat(healed, ', '))
end

tests['a legacy fixture still reads the pre-#53 world, and is known-wrong'] = function()
    -- Characterisation, not endorsement. The old fixtures were validated in
    -- this world and must not shift under anyone's feet; naming what it answers
    -- is what stops the next reader from mistaking it for an observation.
    local J = rf.load('tests/fixtures/f_072738_zuus_mana.lua')
    local ids = GetTeamPlayers(GetTeam())
    local all_pos1 = true
    for i = 1, #ids do
        if J.GetPosition(GetTeamMember(i)) ~= 1 then all_pos1 = false end
    end
    assert(all_pos1, 'a legacy fixture answered something OTHER than "everyone '
        .. 'is pos 1" -- if the fallback changed, every conclusion drawn on the '
        .. 'legacy corpus needs re-reading, starting with the pull bid in '
        .. 'test_replay_creeppull_reachable.lua')
end

return tests

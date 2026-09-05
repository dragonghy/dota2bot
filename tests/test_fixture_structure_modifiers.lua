-- [replay-check] A STRUCTURE's modifiers reach the fixture world.
--
-- WHY THIS FILE EXISTS (replay-check 2026-09-05, GH #511 handoff 甲)
-- -----------------------------------------------------------------
-- The strategy group's 04:34Z ruling on GH #511 refuted the root cause the
-- replay group had published for the 75%-abort finding and handed one thing
-- back: the surviving explanation (a mode-arbitration COMMITMENT fix, not a
-- Think() guard) has to be tested against
--
--     ClosestOutpost:HasModifier('modifier_watch_tower_capturing')
--
-- and the fixture world could not answer it. The combat log puts that modifier
-- on the OUTPOST (actor = the capturing hero, target = `#DOTA_OutpostName_*`),
-- and make_fixture.py read `active_modifiers` for HERO keys only, so every
-- structure in every fixture answered HasModifier = false. Same undeclared
-- world assumption as the pre-2026-08-19 blanket hero HasModifier default and
-- the GetTower / WasRecentlyDamagedBy* gaps -- one entity class over.
--
-- The handoff said "the dumper's `buildings` record needs `modifiers`". It did
-- not: the field was already in the dump, one table over (`events`).
--
-- WHAT THIS FILE TESTS, AND WHAT IT DOES NOT.  This is the LOADER half only:
-- given a fixture that declares structure modifiers, does the world answer
-- HasModifier / NumModifiers / GetModifier* on that structure, and does it keep
-- them separate per structure. The GENERATOR half -- does the right outpost get
-- the modifier, on real frames, and does the join refuse when it cannot tell --
-- is tests/test_fixture_structure_modifiers.py, which runs make_fixture.py
-- against the two verbatim dumper slices strategy checked in for the same issue.
--
-- The world below is written inline rather than checked in as a fixture on
-- purpose: those slices carry frames and events only (no abilities, no
-- player_id), so a fixture generated from them would land in the corpus as a
-- permanently deficient one and put two ratchets
-- (test_fixture_ability_slots.lua, test_fixture_roles.lua) on a declared-
-- exemption list to accommodate it. The numbers here are the real ones from
-- 20260905_010205_slot7 (run spot_20260905_003250_1_..._695907, seed 4763):
-- outposts at (3392,-448) and (-4096,-448), luna 138u from the first with a
-- capture channel open at t=1350.5 (ADD 1349.9 -> REMOVE 1351.8 => 1.3s left).

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')

local tests = {}

local SUBJ = 'npc_dota_hero_luna'
local CAPTURING = 'modifier_watch_tower_capturing'
local NEAR_X, FAR_X = 3392, -4096
local tmp_paths = {}

--- Write a fixture in the generator's own shape. `tMods` maps an outpost x to
--- the modifier list it carries; an outpost absent from it omits the field
--- entirely, which is what a real fixture does and what keeps the loader's
--- pre-change default (no modifiers) exercised.
local function write_fixture(tMods)
    local buf = { 'return {\n' }
    buf[#buf + 1] = "  game = 'synth_outpost', time = 1350.5, window = 5.0,\n"
    buf[#buf + 1] = "  self = '" .. SUBJ .. "',\n"
    buf[#buf + 1] = '  units = {\n'
    buf[#buf + 1] = "    { name = '" .. SUBJ .. "', team = 2, x = 3433.0, y = -581.0,"
        .. ' hp = 2000, max_hp = 2000, mp = 500, max_mp = 500, level = 27,'
        .. " alive = true, tp_cd = 0, items = { '', '', '', '', '', '', '', '', '' },"
        .. ' abilities = {} },\n'
    buf[#buf + 1] = '  },\n  buildings = {\n'
    for _, b in ipairs({ { NEAR_X, 3 }, { FAR_X, 2 } }) do
        local mods = tMods and tMods[b[1]]
        local tail = ''
        if mods then
            local parts = {}
            for _, m in ipairs(mods) do
                parts[#parts + 1] = string.format(
                    "{ name = '%s', remaining = %s, elapsed = %s, stacks = %d }",
                    m.name, m.remaining, m.elapsed, m.stacks or 0)
            end
            tail = '\n      modifiers = { ' .. table.concat(parts, ', ') .. ' },'
        end
        buf[#buf + 1] = string.format(
            "    { name = 'watch_tower', team = %d, x = %d, y = -448, alive = true,"
            .. ' hp = 1.0,%s },\n', b[2], b[1], tail)
    end
    buf[#buf + 1] = '  },\n'
    buf[#buf + 1] = '  observed = { burst = {}, died_after = nil },\n}\n'

    local path = os.tmpname() .. '.lua'
    local fh = assert(io.open(path, 'w'))
    fh:write(table.concat(buf))
    fh:close()
    tmp_paths[#tmp_paths + 1] = path
    return path
end

--- The real instant: only the outpost luna is standing on is being captured.
local function real_world()
    return write_fixture({
        [NEAR_X] = { { name = CAPTURING, remaining = 1.3, elapsed = 0.6, stacks = 0 } },
    })
end

local function outposts(path)
    local _, bot = rf.load(path)
    local found = {}
    for _, kind in ipairs({ UNIT_LIST_ALLIED_BUILDINGS, UNIT_LIST_ENEMY_BUILDINGS }) do
        for _, u in ipairs(GetUnitList(kind)) do
            if u:GetUnitName() == 'watch_tower' then found[#found + 1] = u end
        end
    end
    return bot, found
end

local function at_x(found, x)
    local hits = {}
    for _, u in ipairs(found) do
        if u:GetLocation().x == x then hits[#hits + 1] = u end
    end
    return hits
end

tests['§1 both outposts reach the world, one per position'] = function()
    local _, found = outposts(real_world())
    assert(#found == 2, 'expected 2 watch_towers, got ' .. #found)
    assert(#at_x(found, NEAR_X) == 1 and #at_x(found, FAR_X) == 1,
        'one outpost per position')
end

tests['§2 the outpost being captured answers HasModifier'] = function()
    local _, found = outposts(real_world())
    assert(at_x(found, NEAR_X)[1]:HasModifier(CAPTURING),
        'the outpost luna is standing 138u from must carry ' .. CAPTURING)
end

tests['§3 the OTHER outpost does not -- structures do not share a table'] = function()
    -- The failure this rules out is a loader that builds ONE modifier index and
    -- hands it to every building: §2 would still pass and every fixture would
    -- claim both outposts were being captured at once.
    local _, found = outposts(real_world())
    assert(not at_x(found, FAR_X)[1]:HasModifier(CAPTURING),
        'the outpost 7500u away must NOT carry the channel modifier')
end

tests['§4 a fixture that declares none keeps the old world (false, 0)'] = function()
    -- v1 fixtures omit the field; the loader must then leave the mock's
    -- Is/Has/Can default alone rather than answer from an empty table it built.
    local _, found = outposts(write_fixture(nil))
    assert(#found == 2, 'anti-vacuity: the no-modifier world still has outposts')
    for _, u in ipairs(found) do
        assert(not u:HasModifier(CAPTURING), 'nothing declared -> nothing carried')
        assert(u:NumModifiers() == 0, 'nothing declared -> 0 modifiers')
        assert(u:GetModifierName(0) == '', 'and an empty name at index 0')
        assert(u:GetModifierRemainingDuration(0) == 0, 'and 0 remaining')
        assert(u:GetModifierStackCount(0) == 0, 'and 0 stacks')
    end
end

tests['§5 the indexed readers agree with HasModifier, one past the end is safe'] =
function()
    local _, found = outposts(real_world())
    for _, u in ipairs(found) do
        local n = u:NumModifiers()
        local names = {}
        for i = 0, n do -- one PAST the end, the way jmz_func's own readers scan
            names[#names + 1] = u:GetModifierName(i)
        end
        assert(#names == n + 1, 'the extra index must answer, not crash')
        assert(names[n + 1] == '', 'one past the end must be the empty name')
        local by_index = false
        for i = 1, n do if names[i] == CAPTURING then by_index = true end end
        assert(by_index == u:HasModifier(CAPTURING),
            'GetModifierName and HasModifier disagree at x=' .. u:GetLocation().x)
    end
end

tests['§6 the remaining duration is carried through, not zeroed'] = function()
    -- A loader that dropped the payload and answered from names alone would
    -- pass every check above; the real interval is 1351.8 - 1350.5 = 1.3s.
    local _, found = outposts(real_world())
    local u = at_x(found, NEAR_X)[1]
    local got = nil
    for i = 0, u:NumModifiers() - 1 do
        if u:GetModifierName(i) == CAPTURING then
            got = u:GetModifierRemainingDuration(i)
        end
    end
    assert(got ~= nil, 'the capture modifier was not found by index')
    assert(math.abs(got - 1.3) < 1e-6, 'remaining should be 1.3, got ' .. tostring(got))
end

tests['§7 two structures carrying DIFFERENT modifiers stay separate'] = function()
    local path = write_fixture({
        [NEAR_X] = { { name = CAPTURING, remaining = 1.3, elapsed = 0.6, stacks = 0 } },
        [FAR_X] = { { name = 'modifier_fountain_glyph', remaining = 4.0,
                      elapsed = 1.0, stacks = 0 } },
    })
    local _, found = outposts(path)
    local near, far = at_x(found, NEAR_X)[1], at_x(found, FAR_X)[1]
    assert(near:HasModifier(CAPTURING) and not near:HasModifier('modifier_fountain_glyph'),
        'the near outpost carries only its own')
    assert(far:HasModifier('modifier_fountain_glyph') and not far:HasModifier(CAPTURING),
        'the far outpost carries only its own')
end

tests['§8 the synthetic fixtures are cleaned up'] = function()
    assert(#tmp_paths > 0, 'anti-vacuity: this run actually wrote fixtures')
    for _, p in ipairs(tmp_paths) do os.remove(p) end
end

return tests

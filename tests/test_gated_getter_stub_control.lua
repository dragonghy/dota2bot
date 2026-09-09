-- CONTROL for tools/agent/gated_getter_stub_census.py.
--
-- The census is a TEXT SCAN.  It says a getter is STUB0 because no assignment
-- to that name exists in either mock -- which is an argument about source, not
-- a reading of the loader.  Four director rounds in a row (§GD..§GF) were paid
-- for by exactly that distinction going unchecked, so the census does not get
-- to make its central claim on a grep.
--
-- This file takes the reading.  It loads ONE real fixture frame through the
-- real loader and asks the mock what it actually answers for each class of the
-- census's vocabulary:
--
--   STUB0    -> the number 0, from `default_for`'s `key:find('^Get')` catch-all
--   SERVED   -> the frame's own datum
--   DEFAULT  -> a declared default (150 attack range; nil for a handle getter)
--   REFUSED  -> a raise that names the loader (GH #61)
--
-- ⚠️ THIS FILE IS A RATCHET, AND GOING RED IS ITS JOB.  The day somebody wires
-- GetGold (or any other name below) into make_fixture.py and the loader, the
-- `== 0` assertion here fails.  That failure is the NEWS -- it means the
-- purchase was made -- and the fix is to move the name into the served list
-- here and re-read the census.  A silent pass after such a purchase would be
-- the census quietly reporting a debt that had already been paid.
--
-- ⚠️ WHAT THIS CONTROL CANNOT SEE (the same limit the census declares):
-- §GD's shape.  `sp.GetCastRange` IS installed, and it still answers the
-- catch-all 0 for the 350 of 487 handles whose KV roster carries no range.
-- "Installed" and "answers from the frame" are different claims and only the
-- first one is visible from here; see the census docstring.

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')

local FIXTURE = 'tests/fixtures/f_011405_jak_rescue_axe.lua'
local tests = {}

-- Every name below is one the census prints as STUB0 for at least one ARMED id
-- (reading of 2026-09-09, arm string 37, default depth 2).  The id list is the
-- reason the name is worth a control at all.
--
-- ⭐ GetAnimActivity is the cross-check that this tool is not just agreeing
-- with itself: §GF priced that exact getter BY HAND, over a full round, and the
-- census finds it from source with no knowledge of that ruling.
local STUB0 = {
    GetAssignedLane          = 'creepthink, pullcad, pullcamp, pulldrag, tbearly, tpdeathbuy',
    GetActiveMode            = 'arbheart, rotscope, tbearly, tpdeathbuy, zusult',
    GetHealthRegen           = 'overchase, ownhalf, rotscope, tbearly, tpdeathbuy',
    GetActiveModeDesire      = 'rotscope, tbearly, zusult',
    GetAnimActivity          = 'arbheart, rotscope   (§GF priced this one by hand)',
    GetAttackDamage          = 'rotscope, tbearly',
    GetAttackSpeed           = 'rotscope, tbearly',
    GetCurrentCharges        = 'fieldbuy, fieldsip',
    GetGold                  = 'rotscope, tpdeathbuy',
    GetOffensivePower        = 'rotscope, tbearly',
    GetRawOffensivePower     = 'rotscope, tbearly',
    GetCourierValue          = 'tpdeathbuy',
    GetCurrentVisionRange    = 'outlatch',
    GetStashValue            = 'tpdeathbuy',
    GetToggleState           = 'rotscope',
}

tests['STUB0: every one answers the catch-all 0 on a real frame'] = function()
    local _, bot = rf.load(FIXTURE)
    local bad = {}
    for name, ids in pairs(STUB0) do
        local v = bot[name](bot)
        if v ~= 0 then
            bad[#bad + 1] = string.format('%s answered %s (armed ids: %s)',
                name, tostring(v), ids)
        end
    end
    assert(#bad == 0,
        'these are no longer catch-all 0 -- the instrument was bought, so the '
        .. 'census row is stale and must be re-read: ' .. table.concat(bad, '; '))
end

tests['STUB0 is SILENT: 0 is a number, so no caller can tell it from an answer'] = function()
    -- The whole reason the §GF prescription is "refuse, do not answer 0".  A
    -- nil would at least be null-checked by the shipped code; a 0 is a legal
    -- reading of "no gold", "not in that mode", "no regen", and every
    -- comparison behind it is constant across the corpus without saying so.
    local _, bot = rf.load(FIXTURE)
    assert(type(bot:GetGold()) == 'number', 'GetGold must answer a number')
    assert(bot:GetGold() == 0, 'GetGold must be the catch-all 0 today')
    -- The fixture DOES carry the data that would make this a real reading for
    -- some names and does NOT for others -- that difference is the price list.
    -- Gold is not in the dump at all (no `gold =` key on any of the 110
    -- fixtures), so buying GetGold is a dumper change, not a loader one.
end

tests['SERVED positive control: the loader really does answer from the frame'] = function()
    local _, bot = rf.load(FIXTURE)
    assert(bot:GetTeam() == 2, 'subject jakiro is on team 2 in this fixture')
    assert(bot:GetLevel() == 1, 'subject is level 1 in this fixture')
    assert(bot:GetHealth() == 582, 'subject HP is 582 in this fixture')
    assert(bot:GetMaxHealth() == 758, 'subject max HP is 758 in this fixture')
end

tests['DEFAULT: a declared default is neither served nor the catch-all'] = function()
    local _, bot = rf.load(FIXTURE)
    -- handle_getters answer nil, NOT 0 -- a control that asserted `== 0` on one
    -- of these would have gone red for entirely the wrong reason, which is why
    -- the census reads `local handle_getters` out of the mock instead of
    -- guessing from the name.
    assert(bot:GetAttackTarget() == nil,
        'GetAttackTarget is a handle getter: nil, not 0')
    assert(bot:GetAttackRange() ~= 0,
        'GetAttackRange carries a seeded default, so it is not the catch-all')
end

tests['REFUSED: the one name the loader will not answer says so itself'] = function()
    rf.load(FIXTURE)
    local ok, err = pcall(function() return GetLaneFrontLocation(2, 1) end)
    assert(ok == false, 'GetLaneFrontLocation must raise, not answer (0,0,0)')
    assert(tostring(err):find('LOADER REFUSES', 1, true) ~= nil,
        'the raise must name the loader; got: ' .. tostring(err))
end

tests['NILGLOB: an engine global the mock never installs is nil, i.e. LOUD'] = function()
    -- The census prints this class separately on purpose: it fails loudly, so
    -- it is a different (and cheaper to notice) defect than STUB0.  What makes
    -- it worth printing at all is §GD's lesson that a raise swallowed by a
    -- two-bucket pcall gets scored as "measured, answered no".
    rf.load(FIXTURE)
    assert(rawget(_G, 'GetRoshanDesire') == nil,
        'GetRoshanDesire is not installed by the mock; if it now is, the '
        .. 'census NILGLOB row for tbearly is stale')
end

return tests

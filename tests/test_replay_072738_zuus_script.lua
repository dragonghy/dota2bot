-- FULL-SCRIPT slice feeding (the complete keystone): load the real
-- bots/BotLib/hero_zuus.lua under the mock API, world = the real 2:40 frame of
-- game 072738 (Zeus 148/495 mana, enemy at 59% nearby), run SkillsComplement,
-- and observe the ACTIONS it takes. No hand-written world: positions, HP,
-- mana, levels, ability levels/cooldowns all come from the replay dump; the
-- only supplied constants are static game data absent from dumps (cast
-- ranges / mana costs), marked below.
--
-- What this pins end-to-end:
--  * the full hero script runs on a real slice without error (infrastructure);
--  * on a 30%-mana laning frame it must NOT cast a harass nuke (Q/W) -- both
--    the lf_mana guard and Zeus's own nKeepMana reserve agree here; if a
--    future edit breaks lane mana discipline at the script level, a Q/W cast
--    appears on this frame and this test catches it.
-- (The armed-vs-off diff is deliberately NOT asserted on this frame: Zeus's
-- own reserve already suppresses at 148 mana, so the guard's marginal effect
-- shows only at mid-mana frames; the guard's own logic is pinned separately in
-- test_replay_072738_zuus_mana.lua.)

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')

local FIXTURE = 'tests/fixtures/f_072738_zuus_mana.lua'
local tests = {}

-- Static game constants the dump cannot carry (world config, not slice data).
local CONST = {
    zuus_arc_lightning = { range = 850, mana = 80 },
    zuus_lightning_bolt = { range = 825, mana = 125 },
}

local function run(gate_on)
    local J, bot = rf.load(FIXTURE)
    J.IsSoakCandidate = function(id) return gate_on and id == 'lf_mana' or false end
    for name, c in pairs(CONST) do
        local sp = rawget(bot:GetAbilityByName(name), '__spec')
        sp.GetCastRange = c.range
        sp.GetManaCost = c.mana
    end
    local log = rf.record_actions(bot)
    local ok, err = pcall(function() rf.load_hero('zuus').SkillsComplement() end)
    local cast_names = {}
    for _, a in ipairs(log) do
        local h = a.args[1]
        if a.fn:find('UseAbility') and h ~= nil and h.GetName ~= nil then
            cast_names[#cast_names + 1] = h:GetName()
        end
    end
    return ok, err, cast_names
end

tests['full hero script runs on the real slice (gate off)'] = function()
    local ok, err = run(false)
    assert(ok, 'SkillsComplement must not error on a real frame: ' .. tostring(err))
end

tests['full hero script runs on the real slice (gate armed)'] = function()
    local ok, err = run(true)
    assert(ok, 'SkillsComplement must not error with lf_mana armed: ' .. tostring(err))
end

local function assert_no_harass(cast_names, label)
    for _, n in ipairs(cast_names) do
        assert(n ~= 'zuus_arc_lightning' and n ~= 'zuus_lightning_bolt',
            label .. ': cast ' .. n .. ' on a 30%-mana laning frame -- lane mana '
            .. 'discipline broke at the script level')
    end
end

tests['no harass nuke on the low-mana frame (gate off)'] = function()
    local _, _, casts = run(false)
    assert_no_harass(casts, 'gate off')
end

tests['no harass nuke on the low-mana frame (gate armed)'] = function()
    local _, _, casts = run(true)
    assert_no_harass(casts, 'gate armed')
end

return tests

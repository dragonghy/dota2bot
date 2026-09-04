-- FULL-SCRIPT slice feeding (the complete keystone): load the real
-- bots/BotLib/hero_zuus.lua under the mock API, world = the real 2:40 frame of
-- game 072738 (Zeus 148/495 mana, enemy at 59% nearby), run SkillsComplement,
-- and observe the ACTIONS it takes. No hand-written world: positions, HP,
-- mana, levels, ability levels/cooldowns all come from the replay dump.
--
-- ============================================================================
-- 2026-09-04 -- BOTH SENTENCES IN THE ORIGINAL HEADER WERE FALSE. READ THIS.
-- ============================================================================
--
-- This file is the third of the four the `-76` backlog row held back for a
-- line-by-line read of their REASON sentences (the `-72` lesson: a test whose
-- result never moved can still have a rationale that went false under it, and
-- that class neither goes red nor answers a grep).  It had two, and the read
-- killed both.
--
-- (1) "the only supplied constants are static game data absent from dumps
--     (cast ranges / mana costs)".
--
--     ABSENT became PRESENT on 2026-09-01 (GetManaCost) and 2026-09-04
--     (GetCastRange), when tests/mock/replay_fixture.lua started serving both
--     off the AbilityCastRange / AbilityManaCost rows of the fixture's own KV
--     block, rank-indexed, for the five focus heroes -- Zeus among them.  So
--     the CONST block below stopped being a stand-in for a silent getter and
--     became an OVERWRITE of a live one, and nothing said so.
--
--     Worse, the four hand-written numbers all DISAGREE with the KV (§B).  Not
--     one is a rounding difference; they read like rank-independent values
--     recalled at writing time, and the loader answers the frame's real rank
--     (arc lightning 2, bolt 1).  The file was running the real hero script on
--     a Zeus whose two nukes cost and reach what neither the fixture nor the
--     engine says they do.
--
-- (2) "on a 30%-mana laning frame it must NOT cast a harass nuke (Q/W) -- both
--     the lf_mana guard and Zeus's own nKeepMana reserve agree here".
--
--     That names a MECHANISM, and the negative control refutes it (§D).
--     SkillsComplement queues ZERO actions on this frame -- so the two
--     assert_no_harass loops iterate an empty list, in both gate legs, and have
--     never once compared a name.  Take the naming away and give the frame
--     100% mana AND zero cooldowns on Q and W -- the levers the sentence
--     credits -- and the count is still zero, and all five Consider* functions
--     still return desire 0.  Whatever silences this frame, mana is provably
--     not it.  Arc Lightning is `IsFullyCastable() == true` here at the KV's
--     own price (90 of 148); it is not a castability stop either.
--
--     The sentinel is kept, because a script-level break that produced a cast
--     would still be caught by it.  What is not kept is the claim that the
--     silence is mana discipline, or that this frame currently distinguishes
--     anything: §D registers the empty domain so the next reader does not
--     mistake a green for a demonstration.  It is written to go RED the day the
--     frame stops being empty -- that is good news, and the message says so.
--
-- The armed-vs-off diff is still deliberately not asserted on this frame; the
-- lf_mana guard's own logic is pinned in test_replay_072738_zuus_mana.lua.
-- ============================================================================

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')

local FIXTURE = 'tests/fixtures/f_072738_zuus_mana.lua'
local tests = {}

-- The numbers this file used to WRITE OVER the loader with.  Kept only as the
-- subject of §B; nothing runs on them any more.
local ANCHOR = {
    zuus_arc_lightning  = { range = 850, mana = 80 },
    zuus_lightning_bolt = { range = 825, mana = 125 },
}

-- What the fixture's own KV answers today, through the repaired loader,
-- measured on 2026-09-04 and not recalled.  §A is the drift sentinel: if the
-- loader or the snapshot moves, this file says so instead of quietly changing
-- what the hero script was fed.
local KV = {
    zuus_arc_lightning  = { rank = 2, range = 800, mana = 90 },
    zuus_lightning_bolt = { rank = 1, range = 700, mana = 120 },
}

--- Run the real SkillsComplement on the real frame.
---
--- @param gate_on  arm lf_mana
--- @param bAnchor  when true, overwrite the loader's KV answers with ANCHOR --
---                 i.e. reproduce the pre-2026-09-04 world.  §C uses it to show
---                 that removing the overwrite moved no reading; no assertion
---                 outside §C runs in that world.
local function run(gate_on, bAnchor)
    local J, bot = rf.load(FIXTURE)
    J.IsSoakCandidate = function(id) return gate_on and id == 'lf_mana' or false end
    if bAnchor then
        for name, c in pairs(ANCHOR) do
            local sp = rawget(bot:GetAbilityByName(name), '__spec')
            sp.GetCastRange = c.range
            sp.GetManaCost = c.mana
        end
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
    return ok, err, cast_names, #log
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

-- §A -- the fixture's own KV, through the repaired loader.  A drift sentinel.
-- These four numbers are what the hero script is fed now; if one moves, the
-- file must be re-read before its readings are quoted, not silently re-based.
tests['A: the loader serves the frame KV, rank-indexed, for both nukes'] = function()
    local _, bot = rf.load(FIXTURE)
    for name, kv in pairs(KV) do
        local h = bot:GetAbilityByName(name)
        assert(h ~= nil, name .. ': no handle on the frame')
        assert(h:GetLevel() == kv.rank, ('%s: frame rank %s, registered %d')
            :format(name, tostring(h:GetLevel()), kv.rank))
        assert(h:GetCastRange() == kv.range, ('%s: loader cast range %s, registered %d -- '
            .. 'the KV or the loader moved; re-read this file before quoting it')
            :format(name, tostring(h:GetCastRange()), kv.range))
        assert(h:GetManaCost() == kv.mana, ('%s: loader mana cost %s, registered %d -- '
            .. 'the KV or the loader moved; re-read this file before quoting it')
            :format(name, tostring(h:GetManaCost()), kv.mana))
    end
end

-- §B -- the registered disagreement.  Four for four.  If a future KV ever
-- agrees with a hand anchor, DELETE that row from ANCHOR (it has stopped being
-- evidence of anything); do not loosen this to `>= 0` or to a tolerance.
tests['B: every hand anchor this file used to write disagrees with the KV'] = function()
    local nRows, nDisagree = 0, 0
    for name, a in pairs(ANCHOR) do
        local kv = KV[name]
        assert(kv ~= nil, name .. ': anchored but not registered in KV')
        for _, field in ipairs({ 'range', 'mana' }) do
            nRows = nRows + 1
            if a[field] ~= kv[field] then nDisagree = nDisagree + 1 end
        end
    end
    assert(nRows == 4, 'expected 4 anchored numbers, found ' .. nRows)
    assert(nDisagree == 4, ('registered 4/4 disagreements, measured %d/4 -- a hand anchor '
        .. 'now matches the KV; delete that ANCHOR row rather than relaxing this')
        :format(nDisagree))
end

-- §C -- why removing the overwrite was safe: it moved no reading.  Both worlds,
-- both gate legs, zero queued actions.  This is the negative control for the
-- edit itself, not for the frame.
tests['C: swapping the pre-repair anchors back in changes no reading'] = function()
    for _, gate in ipairs({ false, true }) do
        local okKV, _, castsKV, nKV = run(gate, false)
        local okAn, _, castsAn, nAn = run(gate, true)
        local label = 'gate=' .. tostring(gate) .. ': '
        assert(okKV and okAn, label .. 'SkillsComplement errored in one of the two worlds')
        assert(nKV == nAn, ('%sKV world queued %d action(s), anchor world %d -- the overwrite '
            .. 'was NOT a no-op after all; re-derive before trusting either leg')
            :format(label, nKV, nAn))
        assert(#castsKV == #castsAn, label .. 'cast lists differ in length between the two worlds')
    end
end

-- §D -- the empty domain, and the refuted attribution.  Written to go RED the
-- day the frame stops being empty; that is the good outcome.  When it fires,
-- re-derive the readings and say what the frame now decides -- do NOT delete
-- the section and do NOT weaken it to `>= 0`.
tests['D: the frame queues nothing, and mana is not the discriminator'] = function()
    for _, gate in ipairs({ false, true }) do
        local _, _, _, n = run(gate, false)
        assert(n == 0, ('gate=%s: the frame queued %d action(s); it used to queue 0, so the '
            .. 'no-harass sentinel finally has a domain -- re-derive it, this is good news')
            :format(tostring(gate), n))
    end

    -- Negative control: hand the frame the two levers the old header credited.
    local J, bot = rf.load(FIXTURE)
    J.IsSoakCandidate = function() return false end
    local sp = rawget(bot, '__spec')
    sp.GetMana = bot:GetMaxMana()
    sp.GetManaPct = 1.0
    for name in pairs(KV) do
        rawget(bot:GetAbilityByName(name), '__spec').GetCooldownTimeRemaining = 0
    end
    local log = rf.record_actions(bot)
    local X = rf.load_hero('zuus')
    local ok = pcall(function() X.SkillsComplement() end)
    assert(ok, 'SkillsComplement errored under the full-mana control')
    assert(#log == 0, ('full mana + zero Q/W cooldown queued %d action(s) -- mana IS the '
        .. 'discriminator on this frame after all; the header attribution can come back')
        :format(#log))

    -- and no Consider* wants anything either, so the silence is not a tie-break
    -- inside SkillsComplement.
    for _, fn in ipairs({ 'ConsiderQ', 'ConsiderW', 'ConsiderW2', 'ConsiderE', 'ConsiderR' }) do
        if type(X[fn]) == 'function' then
            local okc, d = pcall(X[fn])
            assert(okc, fn .. ' errored under the full-mana control: ' .. tostring(d))
            assert(d == 0, ('%s wants %s under full mana -- the frame is no longer silent '
                .. 'upstream of the action queue; re-derive §D'):format(fn, tostring(d)))
        end
    end

    -- and Arc Lightning really is castable here at the KV price, so the silence
    -- is not castability either.
    local _, bot2 = rf.load(FIXTURE)
    local q = bot2:GetAbilityByName('zuus_arc_lightning')
    assert(q:IsFullyCastable(), 'arc lightning is no longer fully castable on the raw frame; '
        .. 'the "not a castability stop" half of the header no longer holds')
end

return tests

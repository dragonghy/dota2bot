-- [pgchannel] THE CHANNEL IS THE RETREAT -- real-frame validation.
--
-- The defect: nothing in mode_retreat_generic's desire path knows the bot may
-- already be leaving by TP. This tree states the consequence itself, in
-- J.ShouldAbandonTpChannel's header -- "the caller raises retreat desire so the
-- move order cancels the channel" -- so a retreat floor fired on a mid-channel
-- hero spends the scroll and leaves him where he stands.
--
-- These are NOT gate-plumbing tests (charter rule 2). Every reading below comes
-- from driving the SHIPPED mode_retreat_generic.GetDesireHelper() on a real
-- dumped frame, in both arms, and comparing the numbers it returns.
--
-- POSITIVE CONTROL  f_260819_222030_jugg_tp_start (t=437.1, 7:17): juggernaut
-- deep past the midline, nearest ally 4,000+, lich 476u and viper 739u on him,
-- `modifier_teleporting` 0.1s ELAPSED -- the channel had just begun.
-- Shipped chain: 0.92, the pushguard floor. Armed: 0.
--
-- WHY THE VETO SITS ABOVE THE CHAIN AND NOT ON THE PUSHGUARD FLOOR. The first
-- shape of this fix was `ShouldAbortDeepSoloPush(bot) and not <exempt>` at that
-- one guard. Measured on this same frame it moved 0.92 -> 0.75 and stopped
-- there: J.ShouldRetreatLaneBurst (lanesurv-family, PROMOTED, live, and still
-- inside its laning-phase domain at 7:17) took over. A 0.75 floor cancels a
-- channel exactly as well as a 0.92 one, so that version changed a number and
-- nothing else -- and a gate-plumbing test on the conjunct would have passed
-- it. The fourth assertion below is the regression pin for that.
--
-- NEGATIVE CONTROL: the three pushguard frames that are NOT channeling keep
-- their shipped desire with the id armed -- the veto is domain-limited, not a
-- blanket retreat suppressor.

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')

local POS = { 'tests/fixtures/f_260819_222030_jugg_tp_start.lua',
    'npc_dota_hero_juggernaut' }
-- Every pushguard-firing frame in the corpus that carries no TP channel
-- (tests/_pgchannel_sweep.lua: pg_fires 4, pg_and_channeling 1).
local NEG = {
    { 'tests/fixtures/f_20260827_091703_slot12_zuus_473_1.lua', 'npc_dota_hero_slardar' },
    { 'tests/fixtures/f_260819_181742_ss_chase_start.lua', 'npc_dota_hero_dragon_knight' },
    { 'tests/fixtures/f_260820_043124_axe_blink_kill.lua', 'npc_dota_hero_shadow_shaman' },
}

-- Drive the real chain on a real frame. Returns shipped desire, armed desire,
-- and the loaded (J, bot) so a test can ask the frame further questions.
local function drive(path, hero, arm)
    local J, bot = rf.load(path, hero)
    local armed = {}
    J.IsSoakCandidate = function(id) return armed[id] == true end
    dofile('bots/mode_retreat_generic.lua')
    armed = {}
    local shipped = GetDesireHelper()
    armed = arm or { pgchannel = true }
    local got = GetDesireHelper()
    return shipped, got, J, bot
end

local function read_file(path)
    local f = assert(io.open(path, 'r'), path .. ' is not readable')
    local s = f:read('*a')
    f:close()
    return s
end

-- Long-comment form first, then line comments -- the other order leaves the
-- `--[[` opener's own line stripped and its body behind.
local function strip_lua_comments(src)
    src = src:gsub('%-%-%[%[.-%]%]', ' ')
    return (src:gsub('%-%-[^\n]*', ' '))
end

local tests = {}

tests['[frame] the positive-control frame really is mid-channel'] = function()
    local _, _, J, bot = drive(POS[1], POS[2])
    assert(bot:HasModifier('modifier_teleporting'),
        'f_260819_222030_jugg_tp_start no longer carries modifier_teleporting on '
        .. 'juggernaut -- the frame this lever is built on has changed')
    -- Not dying-in-place: the live release must NOT be the thing answering here,
    -- or the veto below would be measuring the release instead of itself.
    assert(J.IsIncomingBurstLethal(bot, 3.0) == false,
        'the visible burst now reads as lethal on the positive-control frame; '
        .. 'the veto would be released and the 0 below would mean nothing')
end

tests['[frame] shipped floors a just-started channel at the pushguard 0.92'] = function()
    local shipped = drive(POS[1], POS[2])
    assert(shipped == 0.92, 'shipped GetDesireHelper() returns '
        .. tostring(shipped) .. ' on the positive-control frame, not the 0.92 '
        .. 'pushguard floor this lever was measured against')
end

tests['[frame] armed, the channel frame gets no retreat floor at all'] = function()
    local shipped, got = drive(POS[1], POS[2])
    assert(got == 0, 'armed GetDesireHelper() returns ' .. tostring(got)
        .. ' on the positive-control frame, not the NONE the veto returns')
    assert(got < shipped, 'the veto did not lower the desire (shipped '
        .. tostring(shipped) .. ' -> armed ' .. tostring(got) .. '); direction '
        .. 'is the whole safety argument -- this lever may only ever LOWER it')
end

tests['[frame] the pushguard-conjunct shape would have been a no-op here'] = function()
    -- Regression pin for the measurement that redirected this fix. With the
    -- pushguard floor removed by hand -- which is exactly what the conjunct
    -- version did -- this frame does NOT fall to zero; the next live floor
    -- takes it. So "withhold pushguard" is not a fix, and a future edit that
    -- narrows the veto back down to that one guard must fail here.
    local J, bot = rf.load(POS[1], POS[2])
    J.IsSoakCandidate = function() return false end
    local shipped_abort = J.ShouldAbortDeepSoloPush
    J.ShouldAbortDeepSoloPush = function() return false end
    dofile('bots/mode_retreat_generic.lua')
    local without_pushguard = GetDesireHelper()
    J.ShouldAbortDeepSoloPush = shipped_abort
    assert(without_pushguard == 0.75, 'removing only the pushguard floor now '
        .. 'yields ' .. tostring(without_pushguard) .. ', not the 0.75 that '
        .. 'J.ShouldRetreatLaneBurst was measured to take over with')
    assert(J.ShouldRetreatLaneBurst(bot) == true,
        'J.ShouldRetreatLaneBurst no longer fires on this frame -- the 0.75 '
        .. 'above is coming from somewhere else and this pin has gone stale')
end

tests['[frame] the veto is domain-limited: no channel, no change'] = function()
    for _, cse in ipairs(NEG) do
        local shipped, got, _, bot = drive(cse[1], cse[2])
        assert(not bot:HasModifier('modifier_teleporting'), cse[1]
            .. ' is supposed to be a NON-channeling pushguard frame and now '
            .. 'carries modifier_teleporting')
        assert(shipped == got, cse[1] .. ': arming pgchannel moved the desire '
            .. tostring(shipped) .. ' -> ' .. tostring(got) .. ' on a frame with '
            .. 'no TP channel; the veto has leaked outside its domain')
    end
end

tests['[gate] the helper is turbo-only and gated, and has one call site'] = function()
    local jmz = read_file('bots/FunLib/jmz_func.lua')
    local at = jmz:find('function J.ShouldLetTpChannelFinish( bot )', 1, true)
    assert(at, 'J.ShouldLetTpChannelFinish is gone from jmz_func.lua')
    local body = jmz:sub(at, (jmz:find('\nfunction J.', at + 10) or #jmz))
    assert(body:find("J.IsSoakCandidate( 'pgchannel' )", 1, true),
        'the helper no longer carries its own pgchannel gate')
    assert(body:find('J.IsModeTurbo()', 1, true),
        'the helper is no longer turbo-only')
    assert(body:find('modifier_teleporting', 1, true),
        'the helper no longer reads the TP channel modifier')
    assert(body:find('J.IsIncomingBurstLethal( bot, 3.0 )', 1, true),
        'the LIVE release (lethal incoming burst) is gone from the helper; '
        .. 'without it the veto holds a channel that cannot survive')
    assert(body:find('J.ShouldAbandonTpChannel( bot )', 1, true),
        'the deference to tpwatch is gone from the helper')

    -- COMMENT-STRIPPED, because a call site is CODE and this count is the whole
    -- assertion. Landed uncounted: the director's 2026-09-07 note above this
    -- very veto quotes the call text while explaining what happened here, and
    -- an unstripped gsub read that prose as a second call site and went red on
    -- a tree whose code had exactly one. Same family as tpclaim_20260823's
    -- "a text judge reading its own header back as code" -- and the failure
    -- direction is the bad one: it reddens over a comment while a real second
    -- call site hidden inside a `--[[ ]]` block would still be counted.
    local retreat = strip_lua_comments(read_file('bots/mode_retreat_generic.lua'))
    local _, n = retreat:gsub('J%.ShouldLetTpChannelFinish%(bot%)', '')
    assert(n == 1, 'expected exactly one call site in mode_retreat_generic.lua, '
        .. 'found ' .. tostring(n) .. ' -- one lever, one call site')
    -- ...and no consumer inside the helper file either, so "one lever, one call
    -- site" is a fact about the tree and not about the one file we happened to
    -- read. (Scope stated: these two files. A consumer added in a third file
    -- would need its own check, and adding one is the change that should carry
    -- it.)
    local _, nAll = strip_lua_comments(read_file('bots/FunLib/jmz_func.lua')):gsub(
        'ShouldLetTpChannelFinish', '')
    assert(nAll == 1, 'ShouldLetTpChannelFinish appears ' .. tostring(nAll)
        .. ' times in jmz_func.lua; exactly the definition was expected')
end

tests['[gate] the veto sits ABOVE the guard chain, with the other vetoes'] = function()
    -- Placement is load-bearing, not cosmetic: inside the chain it would be
    -- ordered against the descending-desire invariant and, worse, could only
    -- pre-empt the guards below it. tests/test_retreat_priority_order.lua owns
    -- the invariant; this owns the placement.
    local retreat = read_file('bots/mode_retreat_generic.lua')
    local veto = retreat:find('J.ShouldLetTpChannelFinish(bot)', 1, true)
    local begin_mark = retreat:find('=== RETREAT GUARD CHAIN: BEGIN', 1, true)
    assert(veto and begin_mark, 'veto or chain marker missing')
    assert(veto < begin_mark, 'the pgchannel veto has moved INSIDE the retreat '
        .. 'guard chain; it is a NONE veto and belongs above the markers with '
        .. 'J.ShouldStayAndRegen / J.ShouldRegenNotWalkHome')
end

return tests

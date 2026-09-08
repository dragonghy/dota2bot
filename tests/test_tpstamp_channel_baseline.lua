-- [tpwatch / GH #607] THE CHANNEL-START BASELINE IS STAMPED WHEREVER THE CHAIN
-- HAPPENS TO STOP -- real-frame validation.
--
-- The defect: `J.ShouldAbandonTpChannel` decides "this TP channel is being
-- eaten" from `bot.tpChannelStartHealth`, and until this change that stamp had
-- exactly one writer -- the predicate's own body. So the baseline is not the
-- health at the channel's start; it is the health on the first frame somebody
-- reached the call. Both callers are conditional: mode_retreat_generic's chain
-- calls it BELOW the PROMOTED pushguard floor and returns on the first guard
-- that fires, and J.ShouldLetTpChannelFinish returns at its own 'pgchannel'
-- gate before it gets there.
--
-- These are NOT gate-plumbing tests (charter rule 2). Every reading below comes
-- from driving the real mode_retreat_generic.GetDesireHelper() on a real dumped
-- frame and asking what it left behind on the bot.
--
-- POSITIVE CONTROL  f_260819_222030_jugg_tp_start, juggernaut (t=437.1, 7:17):
-- deep past the midline, mid-channel, `modifier_teleporting` 0.1s elapsed.
-- The shipped chain returns 0.92 -- the pushguard floor -- so it never reaches
-- the stamp, and the guard whose whole job is noticing damage during THIS
-- channel has no baseline to notice it against. Arming an UNRELATED id
-- ('pgchannel') is what makes the stamp appear: that is the cross-id coupling
-- mode_retreat_generic's own GH #29 note calls out as breaking the "one
-- variable at a time" premise the soak-candidate A/B rests on.
--
-- SECOND POSITIVE CONTROL, and it is the one that says the fix is not just
-- "arm pgchannel"  f_260819_222559_od_eclipse_pair, juggernaut: also mid-
-- channel, shipped desire 0 (a veto above the chain returns NONE), and the
-- stamp is missing with 'pgchannel' armed TOO. The two witnesses fail for
-- DIFFERENT reasons and only the hoist reaches both.
--
-- NEGATIVE CONTROLS: unarmed the new writer must write nothing at all (shipped
-- play byte-identical), non-turbo the same, and a frame with no channel must
-- never acquire a baseline.
--
-- Corpus context (tests/_tpstamp_sweep.lua, 110 fixtures / 1021 live frames /
-- 23 carrying modifier_teleporting), the four arms:
--   shipped 21 stamped / 2 missed        pgchannel-only 22 / 1
--   tpwatch-only 23 / 0                  tpwatch+pgchannel 23 / 0
--   coupling_frames 1 (the defect)       coupling_open_armed 0 (closed by this)

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')

-- Mid-channel frames the shipped chain never reaches the stamp on.
local POS = { 'tests/fixtures/f_260819_222030_jugg_tp_start.lua',
    'npc_dota_hero_juggernaut' }
local POS2 = { 'tests/fixtures/f_260819_222559_od_eclipse_pair.lua',
    'npc_dota_hero_juggernaut' }
-- A mid-channel frame the shipped chain DOES reach the stamp on -- so "missed"
-- above is a discriminating reading and not something every frame answers.
-- ⚠ LIMIT, registered rather than smoothed over: J.ShouldLetTpChannelFinish's
-- header describes this same frame as having NO `modifier_teleporting` (it is
-- the post-channel freeze of the same game). Driven through
-- tests/mock/replay_fixture.lua the juggernaut here DOES carry it -- the
-- loader's `active_modifiers()` rebuilds intervals from the event stream and
-- this t lands inside one. Nothing below depends on which reading is right: the
-- assertion is only that the SHIPPED chain reaches the stamp here, which is a
-- property of the chain, not of that modifier.
local REACHED = { 'tests/fixtures/f_260819_222030_jugg_tp_eaten.lua',
    'npc_dota_hero_juggernaut' }
-- A live frame with no TP channel at all.
local NOCHAN = { 'tests/fixtures/f_260820_043637_axe_ring_close.lua',
    'npc_dota_hero_axe' }

-- Drive the real chain on a real frame under one arm. The stamp is cleared
-- first, so what is read back was written by THIS drive.
local function drive(path, hero, arm, turbo)
    local J, bot = rf.load(path, hero)
    local armed = arm or {}
    J.IsSoakCandidate = function(id) return armed[id] == true end
    if turbo == false then J.IsModeTurbo = function() return false end end
    dofile('bots/mode_retreat_generic.lua')
    bot.tpChannelStartHealth = nil
    local desire = GetDesireHelper()
    return bot.tpChannelStartHealth, desire, J, bot
end

local function read_file(path)
    local f = assert(io.open(path, 'r'), path .. ' is not readable')
    local s = f:read('*a')
    f:close()
    return s
end

local tests = {}

tests['[frame] the positive-control frame really is mid-channel'] = function()
    local _, _, _, bot = drive(POS[1], POS[2])
    assert(bot:HasModifier('modifier_teleporting'),
        'f_260819_222030_jugg_tp_start no longer carries modifier_teleporting '
        .. 'on juggernaut -- the frame this lever is built on has changed')
    local _, _, _, bot2 = drive(POS2[1], POS2[2])
    assert(bot2:HasModifier('modifier_teleporting'),
        'f_260819_222559_od_eclipse_pair no longer carries modifier_teleporting '
        .. 'on juggernaut -- the second witness has changed')
end

tests['[frame] shipped, the chain stops at pushguard and leaves NO baseline'] = function()
    local stamp, desire = drive(POS[1], POS[2])
    assert(desire == 0.92, 'shipped GetDesireHelper() returns ' .. tostring(desire)
        .. ' on the positive control, not the 0.92 pushguard floor this finding '
        .. 'was measured against')
    assert(stamp == nil, 'the shipped chain now leaves tpChannelStartHealth = '
        .. tostring(stamp) .. ' on a frame it returns at pushguard on; the '
        .. 'missed-stamp defect this lever exists for is gone and the readings '
        .. 'quoted above are stale')
end

tests['[frame] an UNRELATED id decides tpwatch baseline -- the coupling'] = function()
    local without = drive(POS[1], POS[2], {})
    local with = drive(POS[1], POS[2], { pgchannel = true })
    assert(without == nil, 'unarmed baseline is ' .. tostring(without)
        .. ', expected nil')
    assert(with ~= nil, 'arming pgchannel no longer produces a baseline on the '
        .. 'positive control; the coupling this test documents has changed shape')
    -- This is the whole point: pgchannel is an id about retreat desire during a
    -- channel. It has no business deciding whether tpwatch has a number to
    -- compare against, and on this frame it does.
end

tests['[frame] armed, the hoisted stamp reaches BOTH witnesses'] = function()
    for _, cse in ipairs({ POS, POS2 }) do
        local stamp, _, _, bot = drive(cse[1], cse[2], { tpwatch = true })
        assert(stamp ~= nil, cse[1] .. ': tpwatch armed still leaves no '
            .. 'baseline -- the record-only stamp is not running')
        assert(stamp == bot:GetHealth(), cse[1] .. ': baseline ' .. tostring(stamp)
            .. ' is not this frame\'s health ' .. tostring(bot:GetHealth()))
    end
end

tests['[frame] arming pgchannel is NOT a workaround for the second witness'] = function()
    -- The reason both witnesses are here. If pgchannel rescued every missed
    -- frame, the honest fix would be "arm pgchannel", not a new writer.
    local with_pg = drive(POS2[1], POS2[2], { pgchannel = true })
    assert(with_pg == nil, 'pgchannel now stamps the second witness too; the '
        .. 'two witnesses no longer fail for different reasons and this '
        .. 'lever\'s justification needs re-reading')
    local with_tw = drive(POS2[1], POS2[2], { tpwatch = true })
    assert(with_tw ~= nil, 'tpwatch does not reach the second witness either')
end

tests['[frame] adding pgchannel on top of tpwatch moves nothing -- closed'] = function()
    for _, cse in ipairs({ POS, POS2, REACHED }) do
        local alone = drive(cse[1], cse[2], { tpwatch = true })
        local both = drive(cse[1], cse[2], { tpwatch = true, pgchannel = true })
        assert((alone == nil) == (both == nil), cse[1]
            .. ': on tpwatch\'s own arm, adding pgchannel still changes whether '
            .. 'a baseline exists (' .. tostring(alone) .. ' -> ' .. tostring(both)
            .. '); the coupling is not closed')
    end
end

tests['[frame] "missed" is a reading, not something every frame answers'] = function()
    -- ANTI-VACUUM. If the shipped chain failed to reach the stamp everywhere,
    -- the two witnesses above would be saying nothing about the chain. It DOES
    -- reach it on this mid-channel frame, whose shipped desire is 0.75 rather
    -- than the pushguard floor -- i.e. the chain ran past pushguard and down to
    -- the tpwatch guard's own call.
    local stamp, desire, _, bot = drive(REACHED[1], REACHED[2])
    assert(bot:HasModifier('modifier_teleporting'), REACHED[1]
        .. ' no longer reads as mid-channel; the anti-vacuum control is stale')
    assert(stamp ~= nil, 'the shipped chain no longer reaches the stamp on ANY '
        .. 'channeling frame; "the shipped chain misses 2/23" would then be '
        .. 'vacuous rather than a finding')
    assert(desire ~= 0.92, 'the anti-vacuum control now stops at the pushguard '
        .. 'floor too, so it is no longer a control')
    -- ...and the corpus reading that carries this: 21/23 channeling frames DO
    -- get stamped by the shipped chain (tests/_tpstamp_sweep.lua).
end

tests['[control] no channel: no baseline, in any arm'] = function()
    local _, _, _, bot = drive(NOCHAN[1], NOCHAN[2])
    assert(bot:HasModifier('modifier_teleporting') == false,
        NOCHAN[1] .. ' is supposed to be a non-channeling frame')
    for _, arm in ipairs({ {}, { pgchannel = true }, { tpwatch = true } }) do
        local stamp = drive(NOCHAN[1], NOCHAN[2], arm)
        assert(stamp == nil, NOCHAN[1] .. ': a frame with no TP channel '
            .. 'acquired a baseline (' .. tostring(stamp) .. '); the stamp has '
            .. 'leaked outside its domain')
    end
end

tests['[control] unarmed, the new writer writes nothing'] = function()
    for _, cse in ipairs({ POS, POS2, REACHED, NOCHAN }) do
        local J, bot = rf.load(cse[1], cse[2])
        J.IsSoakCandidate = function() return false end
        bot.tpChannelStartHealth = 'SENTINEL'
        J.StampTpChannelHealth(bot)
        assert(bot.tpChannelStartHealth == 'SENTINEL', cse[1]
            .. ': J.StampTpChannelHealth touched the stamp with its id unarmed '
            .. '(got ' .. tostring(bot.tpChannelStartHealth) .. '); shipped play '
            .. 'is supposed to be byte-identical')
    end
end

tests['[control] non-turbo, the new writer writes nothing'] = function()
    local J, bot = rf.load(POS[1], POS[2])
    J.IsSoakCandidate = function(id) return id == 'tpwatch' end
    J.IsModeTurbo = function() return false end
    bot.tpChannelStartHealth = 'SENTINEL'
    J.StampTpChannelHealth(bot)
    assert(bot.tpChannelStartHealth == 'SENTINEL',
        'J.StampTpChannelHealth wrote outside turbo (got '
        .. tostring(bot.tpChannelStartHealth) .. ')')
end

tests['[control] a stale baseline is CLEARED when the channel is gone'] = function()
    local J, bot = rf.load(NOCHAN[1], NOCHAN[2])
    J.IsSoakCandidate = function(id) return id == 'tpwatch' end
    assert(bot:HasModifier('modifier_teleporting') == false,
        NOCHAN[1] .. ' is supposed to be a non-channeling frame')
    bot.tpChannelStartHealth = 12345
    J.StampTpChannelHealth(bot)
    assert(bot.tpChannelStartHealth == nil,
        'a stale baseline survived a non-channeling frame (got '
        .. tostring(bot.tpChannelStartHealth) .. '); the next channel would be '
        .. 'measured against a health from a previous one')
end

tests['[direction] the hoist can only move the baseline EARLIER'] = function()
    -- The safety argument, as an assertion rather than a sentence. The stamp is
    -- written once per channel (`if == nil`), so hoisting it can only capture a
    -- health from an EARLIER frame -- never a later, lower one. A later edit
    -- that turns the stamp into an unconditional re-write would let the baseline
    -- decay with the hero's health and silently disarm tpwatch.
    local jmz = read_file('bots/FunLib/jmz_func.lua')
    local at = jmz:find('function J.StampTpChannelHealth( bot )', 1, true)
    assert(at, 'J.StampTpChannelHealth is gone from jmz_func.lua')
    local body = jmz:sub(at, (jmz:find('\nfunction J.', at + 10) or #jmz))
    assert(body:find('if bot.tpChannelStartHealth == nil then', 1, true),
        'the hoisted stamp no longer guards its write with a nil test; it can '
        .. 'now overwrite a good baseline with a damaged one')
    assert(not body:find('WasRecentlyDamaged', 1, true),
        'the record-only stamp has grown a damage condition; it must see EVERY '
        .. 'frame of the channel or it reproduces the defect it fixes')
end

tests['[gate] the writer is turbo-only, gated on tpwatch, gates FIRST'] = function()
    local jmz = read_file('bots/FunLib/jmz_func.lua')
    local at = assert(jmz:find('function J.StampTpChannelHealth( bot )', 1, true))
    local body = jmz:sub(at, (jmz:find('\nfunction J.', at + 10) or #jmz))
    local turbo = body:find('J.IsModeTurbo()', 1, true)
    local gate = body:find("J.IsSoakCandidate( 'tpwatch' )", 1, true)
    local write = body:find('bot.tpChannelStartHealth =', 1, true)
    assert(turbo, 'the stamp lost its turbo gate')
    assert(gate, 'the stamp is no longer gated on tpwatch')
    assert(write, 'the stamp no longer writes anything')
    assert(turbo < write and gate < write,
        'a gate now sits BELOW the write (turbo@' .. tostring(turbo) .. ' gate@'
        .. tostring(gate) .. ' write@' .. tostring(write) .. '); the whole '
        .. '"unarmed writes nothing" argument depends on both gates running first')
end

tests['[placement] the call sits above GetDesireHelper\'s early-outs'] = function()
    -- The defect is "a return above the stamp hides a frame from it", so the
    -- call site is load-bearing and gets pinned like one. Mutation M4 moves it
    -- below the early-out block.
    local src = read_file('bots/mode_retreat_generic.lua')
    local call = src:find('J.StampTpChannelHealth(bot)', 1, true)
    assert(call, 'the record-only stamp call is gone from mode_retreat_generic')
    -- The first early-out that can hide a channeling frame: the modifier
    -- blocklist returning BOT_MODE_DESIRE_NONE.
    local earlyout = src:find('modifier_dazzle_nothl_projection_soul_clone', 1, true)
    assert(earlyout, 'the early-out block this placement is defined against is gone')
    assert(call < earlyout, 'J.StampTpChannelHealth(bot) has moved BELOW '
        .. 'GetDesireHelper\'s early-out block (call@' .. tostring(call)
        .. ' early-out@' .. tostring(earlyout) .. '); frames that return there '
        .. 'are hidden from the stamp again')
    -- And above the guard chain proper -- pushguard is the floor that was
    -- measured to hide the positive control.
    local pushguard = src:find('J.ShouldAbortDeepSoloPush(bot)', 1, true)
    assert(pushguard and call < pushguard,
        'the stamp call no longer precedes the pushguard floor')
    local _, n = src:gsub('J%.StampTpChannelHealth%(bot%)', '')
    assert(n == 1, 'expected exactly one call site, found ' .. tostring(n))
end

return tests

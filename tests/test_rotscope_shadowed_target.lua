-- [ratchet] `rotscope`: the queued attack in mode_roam_generic's Pudge block
-- is guarded by a variable it does not read.
--
-- THE DEFECT, in one sentence: `local botTarget` inside the Rot block shadows
-- the FILE-LOCAL `botTarget`, the shadow's scope ends with that block, and the
-- `bot:ActionQueue_AttackUnit(botTarget, false)` below it therefore fires on
-- the file-local handle -- which the `J.IsValidTarget(...) and dist > 400`
-- guard four lines above never touched.
--
-- Three independent consequences, each asserted below:
--   (1) UNCONDITIONAL. The order sits outside the `if Rot:GetToggleState()`
--       block, so it fires whether or not Rot is on, whether or not the target
--       is valid, at any distance.
--   (2) CONTINUOUS. bOnce = false. That is the shape 'roamreach' (GH #45)
--       exists to keep out of a Think the engine stops calling the moment
--       another mode wins the auction -- the release lives in the Think that
--       is no longer called.
--   (3) STALE-CAPABLE. The file-local is written only inside GetDesireHelper,
--       BELOW an early return that fires when the bot is invulnerable, dead,
--       an illusion or not a hero. On those frames the previous frame's handle
--       survives -- the 'roamstale' (GH #39, PROMOTED stable-v1) disease in a
--       second file.
--
-- WHY NOBODY HAD SEEN IT. tests/mock/replay_fixture.lua's record_actions did
-- not hook ActionQueue_AttackUnit until 2026-08-31, so every test that read
-- that log answered "no attack was ordered" on frames where one was. The
-- shipped tree issues ActionQueue_AttackUnit at five call expressions and
-- ActionQueue_AttackMove at one; all six were invisible. That gap is fixed in
-- the same change as this file, and case [source S5] pins it so it cannot
-- silently come back.
--
-- REAL FRAME: tests/fixtures/f_113203_pudge_homeroute_silent.lua, subject
-- pudge. Shipped, `ActionQueue_AttackUnit(nil, false)` is the ONLY order the
-- whole of ThinkIndividualRoaming issues on that frame.
--
-- LIMIT (recorded, not worked around): the corpus cannot produce the OTHER
-- half of the defect -- a non-nil target. J.GetProperTarget reads
-- bot:GetTarget() / bot:GetAttackTarget(), both of which live in
-- tests/mock/bot_api.lua's `handle_getters` (answer nil) and are supplied by
-- 0 of the 107 fixtures, so J.GetProperTarget is nil on 993/993 live-hero
-- frames BY CONSTRUCTION OF THE CORPUS, not by game state. What this file
-- pins is the nil half and the unconditionality; the far-creep continuous
-- chase is UNMEASURABLE here, not empty. See tests/_propertarget_sweep.lua.

package.path = 'tests/?.lua;' .. package.path

local rf = require('mock.replay_fixture')

local SRC = 'bots/mode_roam_generic.lua'
local FIXTURE = 'tests/fixtures/f_113203_pudge_homeroute_silent.lua'
local SUBJECT = 'npc_dota_hero_pudge'

-- The mock resolves unknown ALL_CAPS globals to sentinel integers, which ruins
-- the desire arithmetic these files run (same reason as
-- tests/test_roamreach_bounded_chase.lua).
local DESIRE = {
    BOT_MODE_DESIRE_NONE     = 0.0,
    BOT_MODE_DESIRE_VERYLOW  = 0.1,
    BOT_MODE_DESIRE_LOW      = 0.25,
    BOT_MODE_DESIRE_MODERATE = 0.5,
    BOT_MODE_DESIRE_HIGH     = 0.75,
    BOT_MODE_DESIRE_VERYHIGH = 0.9,
    BOT_MODE_DESIRE_ABSOLUTE = 1.0,
}

local tests = {}

--- Every line of the shipped mode file, 1-indexed. Read from the tree, never
--- copied into this file: charter 0SRC ("constants come from the source").
local function lines(path)
    local f = assert(io.open(path, 'r'), 'cannot open ' .. path)
    local out = {}
    for l in f:lines() do out[#out + 1] = l end
    f:close()
    return out
end

--- The single 1-indexed line matching `pat`; raises when it is not unique.
local function only(L, pat)
    local hit
    for i, l in ipairs(L) do
        if l:find(pat) then
            assert(hit == nil, 'pattern is no longer unique: ' .. pat)
            hit = i
        end
    end
    assert(hit, 'pattern is gone: ' .. pat)
    return hit
end

--- Drive ThinkIndividualRoaming on the real frame and return the action log.
--- `armed` controls the 'rotscope' candidate; `toggle` overrides what
--- pudge_rot's GetToggleState answers (the mock's generic Get* default is 0,
--- which is TRUTHY in Lua -- an artefact, so both sides are driven explicitly).
local function drive(armed, toggle)
    local J, bot = rf.load(FIXTURE, SUBJECT)
    for k, v in pairs(DESIRE) do _G[k] = v end
    J.IsSoakCandidate = function(id) return armed and id == 'rotscope' end
    dofile(SRC)
    -- GetDesireHelper is what assigns the file-local `botTarget`; the defect is
    -- about which variable Think reads, so the desire poll has to happen first
    -- exactly as the engine does it.
    local bid = GetDesire()
    local rot = bot:GetAbilityByName('pudge_rot')
    rawset(rot, 'GetToggleState', function() return toggle end)
    local log = rf.record_actions(bot)
    ThinkIndividualRoaming()
    return log, bid, J, bot
end

local function count(log, fn)
    local n = 0
    for _, a in ipairs(log) do if a.fn == fn then n = n + 1 end end
    return n
end

tests['[source S1] the guard and the order read different variables'] = function()
    local L = lines(SRC)

    -- The file-local declaration, and the fact that it is a plain `local` list
    -- at file scope rather than something re-declared per function.
    local decl = only(L, '^local nInRangeEnemy,.*botTarget,')
    local write = only(L, '^\tbotTarget = J%.GetProperTarget%(bot%)$')
    local helper = only(L, '^function GetDesireHelper%(%)$')
    assert(decl < helper and helper < write,
        'the file-local botTarget is no longer written inside GetDesireHelper')

    -- The shadow, its guard, and the consumer. The consumer must sit OUTSIDE
    -- the block the shadow is declared in -- that is the whole finding.
    -- The shadow line is NOT unique in this file (the Nevermore block below
    -- writes the same statement at the same indent), so it is located inside
    -- the Pudge block rather than by text alone.
    local blk = only(L, "if botName == 'npc_dota_hero_pudge' then")
    local shadow, guard
    for i = blk, blk + 20 do
        if L[i] and L[i]:find('^\t\t\tlocal botTarget = J%.GetProperTarget%(bot%)$') then shadow = i end
        if L[i] and L[i]:find('J%.IsValidTarget%(botTarget%) and GetUnitToUnitDistance%(bot, botTarget%) > 400')
        then guard = i end
    end
    assert(shadow and guard, 'the shadowed local or its guard is gone from the Pudge block')
    assert(shadow < guard, 'the guard no longer follows the shadowed local')

    -- The shipped consumer still stands, unchanged, behind `if not rotscope`:
    -- unarmed behaviour is the same statement on the same variable. It sits
    -- BELOW the `end` that closes the Rot block, i.e. where the shadow is
    -- already out of scope -- that is the whole finding, and if somebody ever
    -- deletes the gate and keeps only the fixed form, this case goes red and
    -- the file should be retired rather than edited.
    local unarmed
    for i = guard, blk + 30 do
        if L[i] and L[i]:find('if not rotscope', 1, true) then unarmed = i end
    end
    assert(unarmed, 'the unarmed leg of the Pudge block is gone -- if the defect was FIXED'
        .. ' outright, retire this file instead of editing it')
    assert(L[unarmed + 2]:find('ActionQueue_AttackUnit(botTarget, false)', 1, true),
        'the unarmed leg no longer issues the shipped order verbatim')

    -- The `end` closing the Rot block is between the guard and the unarmed
    -- leg: proof by position that the shipped consumer reads the file-local.
    local closed
    for i = guard, unarmed do
        if L[i] and L[i]:match('^\t\tend%s*$') then closed = i end
    end
    assert(closed and closed < unarmed,
        'the Rot block no longer closes above the shipped consumer -- re-derive the shadowing')
end

tests['[source S2] the order is continuous (bOnce = false) at every site'] = function()
    -- The finding is not "an attack happens", it is "a CONTINUOUS attack
    -- happens": bOnce=false outlives the mode that justified it. Pin that the
    -- queued attacks in this file are all of that form, so a future edit that
    -- flips one to `true` is a behaviour change somebody has to notice.
    local L = lines(SRC)
    local n = 0
    for _, l in ipairs(L) do
        if l:find('ActionQueue_AttackUnit', 1, true) and not l:match('^%s*%-%-') then
            n = n + 1
            assert(l:find(', false)', 1, true),
                'a queued attack in this file is no longer continuous: ' .. l)
        end
    end
    -- 4 before this change (Leshrac, Wisp, the Pudge consumer, and the
    -- ganking-in-lanes site), 5 after: the armed branch adds one inside the
    -- Rot block. The number is asserted so a new continuous order in this file
    -- has to be noticed by somebody.
    assert(n == 5, 'expected 5 ActionQueue_AttackUnit call expressions in ' .. SRC .. ', got ' .. n)
end

tests['[source S3] the gate exists, is turbo-only, and is a candidate'] = function()
    local L = lines(SRC)
    local g = only(L, "local rotscope = J%.IsModeTurbo%(%) and J%.IsSoakCandidate%('rotscope'%)")
    local blk = only(L, "if botName == 'npc_dota_hero_pudge' then")
    assert(g == blk + 1, 'the rotscope gate is no longer the first line of the Pudge block')
end

tests['[source S4] the file-local is written BELOW an early return'] = function()
    -- Consequence (3): the handle the shipped consumer reads is stale-capable.
    -- This is a property of GetDesireHelper, not of the Pudge block, so it is
    -- asserted separately -- a future edit that moves the write above the
    -- early return removes one of the three reasons this fix exists.
    local L = lines(SRC)
    local helper = only(L, '^function GetDesireHelper%(%)$')
    local write  = only(L, '^\tbotTarget = J%.GetProperTarget%(bot%)$')
    local early
    for i = helper, write do
        if L[i]:find('bot:IsInvulnerable()', 1, true) and L[i]:find('return BOT_MODE_DESIRE_NONE', 1, true) then
            early = i
        end
    end
    assert(early, 'the invulnerable/dead/illusion early return of GetDesireHelper is gone')
    assert(early < write,
        'the file-local botTarget is now written above the early return -- the stale half of'
        .. ' this finding is FIXED; re-derive before editing')
end

tests['[source S5] record_actions hooks the queued attack orders'] = function()
    -- The instrument gap that hid this defect from every previous reader.
    -- Asserted here rather than trusted: if somebody trims the list again,
    -- this file goes red instead of quietly passing on a blind log.
    local L = lines('tests/mock/replay_fixture.lua')
    local joined = table.concat(L, '\n')
    assert(joined:find("'ActionQueue_AttackUnit'", 1, true),
        'record_actions stopped hooking ActionQueue_AttackUnit -- this test drives that order')
    assert(joined:find("'ActionQueue_AttackMove'", 1, true),
        'record_actions stopped hooking ActionQueue_AttackMove')
end

tests['[drive] shipped: the ONLY order on the real frame is a nil-target continuous attack'] = function()
    -- toggle = 0: what the mock actually answers on this frame. 0 is truthy in
    -- Lua, so the Rot block IS entered; the inner guard is false because the
    -- target is nil, and control falls out to the out-of-scope consumer.
    local log = drive(false, 0)
    assert(#log == 1, 'expected exactly 1 order on this frame, got ' .. #log)
    assert(log[1].fn == 'ActionQueue_AttackUnit', 'the order is ' .. log[1].fn)
    assert(log[1].args[1] == nil, 'the shipped order target is no longer nil on this frame')
    assert(log[1].args[2] == false, 'the shipped order is no longer continuous')
end

tests['[drive] shipped: it fires with Rot OFF too -- the block guard is not a guard'] = function()
    -- Consequence (1). `false` is the honest reading of "Rot is not toggled";
    -- the shipped order is issued anyway, which is what makes it unconditional
    -- rather than merely mis-targeted.
    local log = drive(false, false)
    assert(#log == 1, 'expected exactly 1 order with Rot off, got ' .. #log)
    assert(log[1].fn == 'ActionQueue_AttackUnit' and log[1].args[1] == nil,
        'the Rot-off frame no longer issues the nil continuous attack')
end

tests['[drive] armed: no order is issued on either frame'] = function()
    -- Armed, the order moves inside the Rot block and onto the guarded handle,
    -- and is issued only when that handle is a valid unit. On this frame it is
    -- nil, so the correct outcome is NO order -- and the rest of Think keeps
    -- its chance to act instead of the frame ending on a nil target.
    for _, toggle in ipairs({ 0, false }) do
        local log = drive(true, toggle)
        assert(count(log, 'ActionQueue_AttackUnit') == 0,
            'armed still issued a queued attack (toggle=' .. tostring(toggle) .. ')')
    end
end

tests['[control] armed changes nothing outside the Pudge block on this frame'] = function()
    -- Separability: the ONLY difference between the two legs is the order this
    -- fix is about. Asserted as a set difference rather than claimed.
    local shipped = drive(false, 0)
    local armed   = drive(true, 0)
    assert(#shipped == 1 and #armed == 0,
        'the arms differ by more than the one order: shipped=' .. #shipped .. ' armed=' .. #armed)
end

tests['[control] the bid is untouched by the gate'] = function()
    -- This fix lives in Think only. If it ever moves a desire number, the
    -- scheduling argument for it (a lone arm is safe) stops holding.
    local _, bidOff = drive(false, 0)
    local _, bidOn  = drive(true, 0)
    assert(bidOff == bidOn, 'rotscope moved the roam bid: ' .. tostring(bidOff) .. ' -> ' .. tostring(bidOn))
end

--- Drive the frame with J.GetProperTarget overridden to hand back `unit`.
--- The override is applied BEFORE GetDesire, so the file-local and the shadow
--- receive the same handle -- which is precisely the case where the shipped
--- code looks correct and the fix must not change anything.
local function drive_with_target(armed, unit)
    local J, bot = rf.load(FIXTURE, SUBJECT)
    for k, v in pairs(DESIRE) do _G[k] = v end
    J.IsSoakCandidate = function(id) return armed and id == 'rotscope' end
    J.GetProperTarget = function() return unit end
    dofile(SRC)
    GetDesire()
    local rot = bot:GetAbilityByName('pudge_rot')
    rawset(rot, 'GetToggleState', function() return 0 end)
    local log = rf.record_actions(bot)
    ThinkIndividualRoaming()
    return log, bot
end

tests['[drive] a real far hero target takes the move branch in BOTH arms'] = function()
    -- The fix must not touch the path the guard was written for. The handle is
    -- the fixture's real ally juggernaut at 726u (> 400), so the guard is TRUE
    -- and both arms must issue the move and return.
    local _, bot0 = drive_with_target(false, nil)
    local ally = bot0:GetNearbyHeroes(20000, false, BOT_MODE_NONE)[1]
    assert(ally, 'the fixture no longer carries an ally hero handle')
    assert(GetUnitToUnitDistance(bot0, ally) > 400, 'the ally moved inside 400u; pick another handle')

    for _, armed in ipairs({ false, true }) do
        local log = drive_with_target(armed, ally)
        assert(count(log, 'Action_MoveToLocation') == 1,
            'the move branch did not fire (armed=' .. tostring(armed) .. ')')
        assert(count(log, 'ActionQueue_AttackUnit') == 0,
            'a queued attack leaked past the move branch (armed=' .. tostring(armed) .. ')')
    end
end

tests['[synthetic] armed issues the order on the GUARDED handle when it is in range'] = function()
    -- DECLARED SYNTHETIC. The fixture carries no unit that is both valid and
    -- within 400u (its only ally is at 726u and it has no creeps), so the
    -- in-range leg cannot be driven from the corpus. This handle is a stub
    -- placed at the bot's own location -- the ONLY thing it is used to prove
    -- is that the armed branch issues exactly one CONTINUOUS order on the
    -- handle the guard checked, which is a statement about this file's control
    -- flow and not about the game.
    local _, bot0 = drive_with_target(false, nil)
    local here = bot0:GetLocation()
    local stub = {
        GetLocation   = function() return here end,
        GetUnitName   = function() return 'npc_dota_creep_synthetic' end,
        IsNull        = function() return false end,
        CanBeSeen     = function() return true end,
        IsAlive       = function() return true end,
        IsBuilding    = function() return false end,
        IsHero        = function() return false end,
        IsIllusion    = function() return false end,
        GetTeam       = function() return 3 end,
        GetHealth     = function() return 100 end,
        GetMaxHealth  = function() return 100 end,
    }
    -- The handle is also read by GetDesireHelper (the file-local receives the
    -- same override), which asks it a long tail of predicates. They answer
    -- `false` -- stated, not hidden: the assertions below are about which
    -- statement in the Pudge block runs, and every `false` here can only make
    -- an EARLIER branch decline, never make the asserted one fire.
    setmetatable(stub, { __index = function() return function() return false end end })

    local shipped = drive_with_target(false, stub)
    assert(count(shipped, 'ActionQueue_AttackUnit') == 1, 'shipped no longer issues its one order')
    assert(shipped[1].args[1] == stub, 'shipped issued the order on some other handle')

    local armed = drive_with_target(true, stub)
    assert(count(armed, 'ActionQueue_AttackUnit') == 1,
        'armed did not issue the order on an in-range valid target')
    assert(armed[1].args[1] == stub, 'armed issued the order on some other handle')
    assert(armed[1].args[2] == false, 'armed changed the order from continuous to single')
end

tests['[recorded] J.GetProperTarget is nil on this frame, and why'] = function()
    -- The LIMIT in the header, made mechanical. If a fixture ever supplies an
    -- attack target, this case goes red and the far-creep half of the defect
    -- becomes measurable -- which is the outcome we WANT, and the reason it is
    -- an assertion instead of a sentence.
    local _, _, J, bot = drive(false, 0)
    assert(J.GetProperTarget(bot) == nil, 'J.GetProperTarget is no longer nil on this frame')
    assert(bot:GetTarget() == nil, 'bot:GetTarget() is no longer nil on this frame')
    assert(bot:GetAttackTarget() == nil, 'bot:GetAttackTarget() is no longer nil on this frame')

    local api = table.concat(lines('tests/mock/bot_api.lua'), '\n')
    assert(api:find('GetAttackTarget = true', 1, true) and api:find('GetTarget = true', 1, true),
        'the handle_getters attribution in this file header is stale -- re-derive it')
end

return tests

-- [hero] `axebhrecast` -- X.ConsiderW's "already has Battle Hunger" veto names a
-- modifier the target can never carry, so Axe has never once declined a re-cast on
-- that ground.  Written 2026-09-06 under OWNER_PRIORITIES P4.4 (bots/ 主体配额).
--
-- THE DEFECT, TWO INDEPENDENT HALVES, EITHER ONE SUFFICIENT
-- ---------------------------------------------------------
-- bots/BotLib/hero_axe.lua X.ConsiderW repeats one veto at EIGHT sites:
--
--     and not <target>:HasModifier( 'modifier_axe_battle_hunger_self' )
--
--   (i)  WRONG SIDE.  The debuff a TARGET carries is `modifier_axe_battle_hunger`.
--        That is the name bots/mode_team_roam_generic.lua:1605 reads off an enemy
--        and bots/BotLib/hero_largo.lua:316 reads off an ally, and it is the name
--        this repo's own fixtures carry on enemy heroes.  The `_self` family is what
--        Axe puts on HIMSELF.
--   (ii) ALSO STALE.  In the corpus the caster-side modifier is spelled
--        `modifier_axe_battle_hunger_self_movespeed`; the bare
--        `modifier_axe_battle_hunger_self` appears ZERO times on any unit in any
--        frame.  HasModifier is an EXACT-name lookup both in the engine and in
--        tests/mock/replay_fixture.lua, so a prefix does not rescue it.
--
-- Section 2 measures both halves off the loader rather than off a regex.
--
-- THE FIX AND ITS DOMAIN
-- ----------------------
-- X.axe_IsBattleHungerFresh, gated turbo + 'axebhrecast', wired at THREE of the
-- eight sites: the teamfight min-search, the laning-harass loop, the retreat loop.
-- Those three iterate a list (so a vetoed candidate hands the branch to the next
-- one) and none of them claims the cast will kill.  The other five stay literal.
--
-- ⚠️ THE KILL LOOP IS THE INTERESTING EXCLUSION AND IT WAS NOT FORESEEN -- THE
-- FIXTURE FOUND IT.  An earlier draft wired it too, because it is a list branch and
-- the subset argument covered it.  Driving f_260820_043124_axe_blink_kill end to end
-- showed what the subset argument cannot see: X.WillBattleHungerKill prices the cast
-- on a FULL 12s duration, which is precisely what a re-cast restores.  A Wraith King
-- at 199 HP carrying 6.5s of the debuff has 130 of those 199 already coming; only
-- the refresh's full 240 finishes him.  The armed side declined the kill.  Section 4
-- pins that site UNWIRED so the draft cannot come back.
--
-- ⭐ 2026-09-09: THE PREMISE BECAME A CONJUNCT, AND SECTION 3 FLIPPED WITH IT
-- ---------------------------------------------------------------------------
-- GH #562 sized the domain on 72 real games (577 replay episodes, 273 inside the
-- shard premise) and stratified it by the one thing this lever's dominance argument
-- rests on -- whether another candidate was there to take the cast:
--
--     pure cost    (target lived, ZERO other candidate)   121   1.68 / game
--     pure benefit (target lived, >= 1 other candidate)    30   0.42 / game
--     kill-confirm (target died within 5s)                122   (97 of them to Axe)
--
-- cost : benefit ~ 4 : 1; 81.3% of in-gate episodes had no alternative at all.  That
-- is not a new defect, it is this lever's OWN sentence ("dominated wherever another
-- candidate exists") never having been written into the code.  The armed leg now
-- carries X.axe_HasHungerAlternative as a conjunct, so it only refuses a refresh when
-- the site's own list holds somebody else it would accept.
--
-- ⚠️ THIS RE-BASELINES SECTION 3 AND THAT IS THE POINT, NOT AN ACCIDENT.  On the
-- drivable frame the hungered Wraith King is the ONLY enemy in cast range -- section 1
-- measured that and section 3 used to assert the armed side "declines, and issues
-- nothing at all".  That decline WAS the 121-episode stratum, one instance of it, and
-- the case now asserts the opposite: armed and shipped issue the SAME order.  A round
-- reading this file later should read the two cases as one pair, not as a weakened
-- test.  The veto itself is pinned live in section 6 on the ring frame, where an
-- alternative really is present.
--
-- HONEST BOUNDS -- READ BEFORE QUOTING ANY NUMBER FROM HERE
-- ---------------------------------------------------------
--   * DIRECTION IS STRUCTURAL BUT IT IS NOT "FEWER ACTIONS".  The shipped predicate
--     is bound first and the armed path may only turn its `true` into `false`, so
--     the accepted (branch, target) pairs are a strict SUBSET and `armed casts =>
--     shipped casts`.  It does NOT claim the same ORDER: the point of the lever is
--     that a vetoed candidate hands the branch to a different target.  Section 5
--     asserts the subset shape on the source and section 3 shows the action-level
--     difference.
--   * NO FIXTURE FRAME REPORTS A BOT MODE, so every mode-gated branch of
--     X.ConsiderW needs a LABELLED flip.  Section 3 uses exactly two flips and names
--     both: Battle Hunger's own remaining cooldown 4.0 -> 0, and one of
--     J.IsRetreating / J.IsInTeamFight / J.IsLaning -> true.  Everything else on the
--     frame -- positions, health, mana, ranks, modifiers, the other nine heroes --
--     is the replay's.
--   * THE CORPUS SHOWS THE COST SIDE, NOT THE BENEFIT SIDE.  On the frame section 3
--     drives, the already-hungered Wraith King is the ONLY enemy inside Battle
--     Hunger's 800u cast range, so the armed side DECLINES rather than spreads.
--     That is the honest reading and it is not hidden: the spread half of the claim
--     is what iterations/queue.json `hero-35` has to buy.
--   * SUBSET AND CORRECTNESS ARE TWO ASSERTIONS, NOT ONE (the `liondrainbkb`
--     lesson).  Section 5 also asserts that on a frame where NOBODY carries the
--     debuff, arming is a byte-for-byte no-op -- a veto inverted the wrong way would
--     still be a subset and the subset case alone would not see it.
--   * Corpus counts come from `dofile` via the loader, never from a regex over the
--     fixture files.
--   * `print` is a no-op after rf.install() (GH #546); this file asserts, never
--     prints.

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')

local SRC = 'bots/BotLib/hero_axe.lua'
local CAND = 'axebhrecast'
local AXE = 'npc_dota_hero_axe'
local WK = 'npc_dota_hero_skeleton_king'
local BH = 'axe_battle_hunger'

local MOD_TARGET = 'modifier_axe_battle_hunger'
local MOD_SELF_TESTED = 'modifier_axe_battle_hunger_self'
local MOD_SELF_REAL = 'modifier_axe_battle_hunger_self_movespeed'

-- The frame section 3 drives: Axe fleeing at 8:49 with a Wraith King 339u away who
-- is already carrying his Battle Hunger.
local FIXTURE = 'tests/fixtures/f_260820_043124_axe_blink_flee_529.lua'
-- The frame section 4 pins: the kill loop, where the re-cast IS the kill.
local KILL_FIXTURE = 'tests/fixtures/f_260820_043124_axe_blink_kill.lua'
-- A frame with an already-hungered enemy that Culling Blade takes first; used by
-- section 5's no-op control (nobody in ITS enemy set carries the debuff after the
-- named one is excluded).
local RING_FIXTURE = 'tests/fixtures/f_260820_043637_axe_ring_close.lua'

-- Every Axe-SUBJECT fixture, listed rather than globbed so a new one is a deliberate
-- edit and section 2's counts move with a named cause.
local AXE_FRAMES = {
    'tests/fixtures/f_260820_042612_axe_blink_init_573.lua',
    'tests/fixtures/f_260820_043124_axe_blink_flee_529.lua',
    'tests/fixtures/f_260820_043124_axe_blink_flee_555.lua',
    'tests/fixtures/f_260820_043124_axe_blink_kill.lua',
    'tests/fixtures/f_260820_043637_axe_ring_alone.lua',
    'tests/fixtures/f_260820_043637_axe_ring_close.lua',
}

-- Anchors for the KV cross-check in the last section.  Read off the repo's own
-- snapshot in that section; typed here so a drift is a RED, not a silent pass.
local BH_DURATION = 12.0
local BH_DPS = { 12, 16, 20, 24 }
local BH_COOLDOWN = { 20, 15, 10, 5 }

local tests = {}

local function read_file(path)
    local fh = assert(io.open(path, 'r'), 'cannot open ' .. path)
    local body = fh:read('*a')
    fh:close()
    return body
end

local function consider_w_body(src)
    local from = src:find('function X%.ConsiderW%s*%(%s*%)')
    assert(from, 'X.ConsiderW not found in ' .. SRC)
    local rest = src:sub(from)
    local to = rest:find('\nfunction X%.')
    return to and rest:sub(1, to) or rest
end

--- Load a real frame, optionally arm the candidate, optionally apply the two
--- declared flips, then drive the REAL X.SkillsComplement and report the orders it
--- issued.  Driving the DISPATCH and not X.ConsiderW directly is deliberate: the
--- consumer issues Action_ClearActions, and whether a frame ends with a cleared
--- queue and no cast is part of what the lever changes.
local function run(opt)
    opt = opt or {}
    local J, bot, heroes, fx = rf.load(opt.fixture or FIXTURE)
    -- `opt.armed == true`, not `opt.armed`: an absent key would make this return
    -- nil, and a helper asserted `== false` then fails on a nil that is
    -- behaviourally identical.
    J.IsSoakCandidate = function(id) return opt.armed == true and id == CAND end
    if opt.nonTurbo then
        -- rf.load's install() forces turbo; undo it AFTER load.
        GetGameMode = function() return 1 end
    end
    if opt.ready then
        rawget(bot:GetAbilityByName(BH), '__spec').GetCooldownTimeRemaining = 0
    end
    if opt.shard then
        J.HasAghanimsShard = function() return true end
    end
    if opt.mode == 'retreat' then J.IsRetreating = function() return true end end
    if opt.mode == 'fight' then J.IsInTeamFight = function() return true end end
    if opt.mode == 'lane' then J.IsLaning = function() return true end end
    local X = rf.load_hero('axe')
    local log = rf.record_actions(bot)
    X.SkillsComplement()
    local orders = {}
    for _, a in ipairs(log) do
        local abil, tgt = a.args[1], a.args[2]
        local an = (type(abil) == 'table' and abil.GetName) and abil:GetName() or nil
        local tn = (type(tgt) == 'table' and tgt.GetUnitName) and tgt:GetUnitName() or nil
        orders[#orders + 1] = a.fn .. (an and ('(' .. an .. (tn and (' -> ' .. tn) or '') .. ')') or '')
    end
    return orders, X, J, bot, heroes, fx
end

local function joined(orders)
    return (#orders == 0) and '(no action)' or table.concat(orders, ' | ')
end

--- Every enemy hero of `bot` on the loaded frame, as the candidate list a call site
--- would be iterating.  Built from the loader's own table, not from a fixture regex.
--- Declared HERE rather than beside its first use: the census in section 2 needs it,
--- and a `local function` further down would be a nil global read from up here.
local function enemy_list(bot, heroes)
    local t = {}
    for _, h in pairs(heroes) do
        if h:GetTeam() ~= bot:GetTeam() and h:IsAlive() then t[#t + 1] = h end
    end
    return t
end

-- ---------------------------------------------------------------- section 1 --
-- Ground truth on the untouched frame.  None of this is colour: every number here
-- is a clause of the branch section 3 drives.

tests['ground truth: 8:49, Axe fleeing with a hungered Wraith King 339u away'] = function()
    local _, _, _, bot, heroes, fx = run()
    assert(fx.self == AXE and fx.time == 529.6, 'the decision instant')
    assert(bot:GetLevel() == 10 and bot:GetHealth() == 1384 and bot:GetMana() == 349,
        'real Axe state, got lvl ' .. bot:GetLevel() .. ' hp ' .. bot:GetHealth()
        .. ' mp ' .. bot:GetMana())
    local wk = assert(heroes[WK], WK .. ' is not on this frame')
    assert(wk:GetTeam() ~= bot:GetTeam(), 'the Wraith King must be the enemy here')
    assert(wk:IsAlive() and wk:GetHealth() == 770, 'real Wraith King state')
    assert(wk:HasModifier(MOD_TARGET) == true,
        'the whole frame rests on this: the target ALREADY carries Battle Hunger')
end

tests['ground truth: the ONE ability flip is Battle Hunger\'s own 4.0s of cooldown'] = function()
    local _, _, _, bot = run()
    local w = bot:GetAbilityByName(BH)
    assert(w:GetLevel() == 3, 'Battle Hunger is rank 3 on this frame, got ' .. tostring(w:GetLevel()))
    assert(w:GetCooldownTimeRemaining() == 4, 'remaining cooldown, got '
        .. tostring(w:GetCooldownTimeRemaining()))
    assert(w:IsFullyCastable() == false, 'so the shipped first line of X.ConsiderW bails')
    assert(bot:GetMana() >= w:GetManaCost(),
        'and it is the COOLDOWN that bails it, not the mana: ' .. bot:GetMana()
        .. ' >= ' .. tostring(w:GetManaCost()))
end

tests['ground truth: the hungered Wraith King is the ONLY enemy in cast range'] = function()
    -- This is why section 3 reads as a DECLINE and not as a spread.  It is the
    -- cost side of the lever, measured rather than argued away.
    local _, _, _, bot, heroes = run()
    local w = bot:GetAbilityByName(BH)
    local nRange = w:GetCastRange()
    assert(nRange == 800, 'rank-3 cast range, got ' .. tostring(nRange))
    local nIn, sIn = 0, nil
    for name, h in pairs(heroes) do
        if h:GetTeam() ~= bot:GetTeam() and h:IsAlive()
            and GetUnitToUnitDistance(bot, h) <= nRange then
            nIn = nIn + 1
            sIn = name
        end
    end
    assert(nIn == 1 and sIn == WK,
        'exactly one enemy inside 800u and it must be the hungered one, got '
        .. nIn .. ' / ' .. tostring(sIn))
    assert(math.floor(GetUnitToUnitDistance(bot, heroes[WK])) == 339, 'his real distance')
end

-- ---------------------------------------------------------------- section 2 --
-- The two halves of the defect, measured off the loader.  One-sided tripwires: a
-- new fixture can only strengthen them, and the day one carries the tested name it
-- goes RED and says so.

tests['defect (ii): the tested name appears on NO unit in ANY Axe frame'] = function()
    local nFrames, nUnits, nTested, nRealSelf, nTarget = 0, 0, 0, 0, 0
    for _, path in ipairs(AXE_FRAMES) do
        local J, bot, heroes, fx = rf.load(path)
        J.IsSoakCandidate = function() return false end
        assert(fx.self == AXE, path .. ' is not an Axe-subject frame; AXE_FRAMES is stale')
        nFrames = nFrames + 1
        for _, h in pairs(heroes) do
            nUnits = nUnits + 1
            if h:HasModifier(MOD_SELF_TESTED) then nTested = nTested + 1 end
            if h:HasModifier(MOD_SELF_REAL) then nRealSelf = nRealSelf + 1 end
            if h:HasModifier(MOD_TARGET) then nTarget = nTarget + 1 end
        end
    end
    assert(nFrames == #AXE_FRAMES and nUnits >= 60,
        'the census must actually have walked the corpus, got ' .. nFrames
        .. ' frame(s) / ' .. nUnits .. ' hero-instant(s)')
    assert(nTested == 0,
        'GOOD NEWS: a unit now carries ' .. MOD_SELF_TESTED .. '.  The shipped veto '
        .. 'is no longer structurally dead; re-read this lever\'s header before '
        .. 'quoting it.  Sightings: ' .. nTested)
    assert(nRealSelf > 0,
        'the caster-side modifier DOES exist under its real name ' .. MOD_SELF_REAL
        .. ' -- that is what makes the tested name a typo and not an absence')
    assert(nTarget > 0,
        'and the target-side debuff ' .. MOD_TARGET .. ' is really carried by units '
        .. 'in this corpus, got ' .. nTarget)
end

tests['defect (i): the shipped veto is always-true on every unit of every frame'] = function()
    -- Stated as the predicate rather than as the name, because that is the claim
    -- the lever rests on: gate OFF, X.axe_IsBattleHungerFresh answers true for
    -- everybody, including the units that DO carry the real debuff.
    local nChecked, nCarriers = 0, 0
    for _, path in ipairs(AXE_FRAMES) do
        local J, bot, heroes = rf.load(path)
        J.IsSoakCandidate = function() return false end
        local X = rf.load_hero('axe')
        -- The list is handed in (2026-09-09) so this census keeps testing the GATE
        -- and not the premise: with no list the armed leg stands down by design, and
        -- a shipped sweep that passes nothing would go green even if the candidate
        -- check were deleted outright.
        local list = enemy_list(bot, heroes)
        for name, h in pairs(heroes) do
            nChecked = nChecked + 1
            assert(X.axe_IsBattleHungerFresh(h, list) == true,
                'shipped veto fired on ' .. name .. ' in ' .. path
                .. ' -- it is not supposed to be able to')
            if h:HasModifier(MOD_TARGET) then nCarriers = nCarriers + 1 end
        end
    end
    assert(nChecked >= 60 and nCarriers >= 3,
        'the census needs both a population and some carriers, got ' .. nChecked
        .. ' unit(s) / ' .. nCarriers .. ' carrier(s)')
end

tests['supply: three Axe frames carry a real debuff instance, and their remains'] = function()
    -- Registered because it is the corpus limit this lever will be sized against:
    -- three instances, none of them long-lived, and section 1 already showed that
    -- on the drivable one the carrier is the only candidate.
    local seen = {}
    for _, path in ipairs(AXE_FRAMES) do
        local J, _, heroes = rf.load(path)
        J.IsSoakCandidate = function() return false end
        for name, h in pairs(heroes) do
            if h:HasModifier(MOD_TARGET) then seen[#seen + 1] = path .. '/' .. name end
        end
    end
    assert(#seen == 3, 'expected 3 debuff instances across the Axe frames, got '
        .. #seen .. ' (' .. table.concat(seen, ', ') .. ')')
end

-- ---------------------------------------------------------------- section 3 --
-- The lever, driven end to end on the real frame.  Two labelled flips, named in
-- every case title.

tests['e2e: gate OFF + cooldown flip -- Axe re-hungers the already-hungered WK'] = function()
    for _, mode in ipairs({ 'retreat', 'fight', 'lane' }) do
        local orders = run({ ready = true, mode = mode })
        assert(joined(orders):find('axe_battle_hunger %-> ' .. WK),
            'shipped, mode ' .. mode .. ': ' .. joined(orders))
    end
end

tests['e2e: gate ON + cooldown flip -- NO alternative, so armed casts what shipped casts'] = function()
    -- Was `#orders == 0` until 2026-09-09.  See the header: this frame is one
    -- instance of GH #562's 121-episode pure-cost stratum -- section 1 already
    -- measured that the hungered Wraith King is the only enemy inside 800u -- and the
    -- premise conjunct is what turns the forfeited refresh back into the cast.
    for _, mode in ipairs({ 'retreat', 'fight', 'lane' }) do
        local shipped = run({ ready = true, mode = mode })
        local armed = run({ armed = true, ready = true, mode = mode })
        assert(joined(armed) == joined(shipped),
            'armed must be a no-op where there is nobody to spread to, mode ' .. mode
            .. ': shipped ' .. joined(shipped) .. ' / armed ' .. joined(armed))
        assert(joined(armed):find('axe_battle_hunger %-> ' .. WK),
            'and the order really is the re-cast, mode ' .. mode .. ': ' .. joined(armed))
    end
end

tests['e2e: the cooldown flip alone changes nothing -- no mode, no branch'] = function()
    -- The mode flip is load-bearing and this says so.  Without it the frame is
    -- silent on both legs, which is also the shape of "no fixture reports a mode".
    assert(#run({ ready = true }) == 0, 'shipped with no mode flip')
    assert(#run({ armed = true, ready = true }) == 0, 'armed with no mode flip')
end

tests['e2e: NON-turbo with the gate armed is the shipped behaviour'] = function()
    -- The turbo half of the gate, driven and not assumed.
    for _, mode in ipairs({ 'retreat', 'fight', 'lane' }) do
        local orders = run({ armed = true, nonTurbo = true, ready = true, mode = mode })
        assert(joined(orders):find('axe_battle_hunger %-> ' .. WK),
            'armed but non-turbo, mode ' .. mode .. ': ' .. joined(orders))
    end
end

tests['e2e: the SHARD premise stands the armed leg down'] = function()
    -- Battle Hunger stacks with Aghanim's Shard (`should_stack` is a shard grant),
    -- and both of this file's buy lists carry the shard, so this is not
    -- hypothetical.  With it held, a re-cast is a second stack and the lever must
    -- not fire.
    for _, mode in ipairs({ 'retreat', 'fight', 'lane' }) do
        local orders = run({ armed = true, shard = true, ready = true, mode = mode })
        assert(joined(orders):find('axe_battle_hunger %-> ' .. WK),
            'armed with shard, mode ' .. mode .. ': ' .. joined(orders))
    end
end

-- ---------------------------------------------------------------- section 4 --
-- The exclusion the fixture found.  This is a regression pin, not a demonstration:
-- an earlier draft wired the kill loop and the armed side threw the kill away.

tests['kill loop: armed and shipped issue the SAME order on the kill frame'] = function()
    local shipped = run({ fixture = KILL_FIXTURE, ready = true })
    local armed = run({ fixture = KILL_FIXTURE, armed = true, ready = true })
    assert(joined(shipped):find('axe_battle_hunger %-> ' .. WK),
        'the shipped kill order is the premise of this case: ' .. joined(shipped))
    assert(joined(armed) == joined(shipped),
        'the kill loop must stay UNWIRED.  shipped: ' .. joined(shipped)
        .. ' / armed: ' .. joined(armed))
end

tests['kill loop: the frame really is one where the refresh is the kill'] = function()
    local _, _, _, bot, heroes, fx = run({ fixture = KILL_FIXTURE })
    assert(fx.self == AXE and fx.time == 491.9, 'the kill frame')
    local wk = assert(heroes[WK], WK .. ' is not on the kill frame')
    assert(wk:GetHealth() == 199, 'the Wraith King is at 199 HP, got ' .. wk:GetHealth())
    assert(wk:HasModifier(MOD_TARGET) == true, 'and he already carries the debuff')
    local w = bot:GetAbilityByName(BH)
    assert(w:GetLevel() == 3, 'Battle Hunger rank 3, got ' .. tostring(w:GetLevel()))
    -- 20 dps x 12s = 240 > 199 on a full duration; the debuff's own remainder is
    -- worth less.  The exact remainder is the dumper's and is not re-typed here.
    assert(BH_DPS[3] * BH_DURATION > wk:GetHealth(),
        'a FULL duration kills him: ' .. (BH_DPS[3] * BH_DURATION) .. ' vs ' .. wk:GetHealth())
end

tests['kill loop: the source keeps the literal veto at that site'] = function()
    local body = consider_w_body(read_file(SRC))
    local from = body:find('X%.WillBattleHungerKill%(')
    assert(from, 'the kill loop is gone from X.ConsiderW')
    -- Cut at the branch's own `then`, not at a character count: a fixed window
    -- runs into the NEXT branch, which is wired, and the case then reads as a
    -- failure of this one.
    local rest = body:sub(from)
    local stop = assert(rest:find('\n%s*then\n'), 'the kill loop`s `then` is gone')
    local tail = rest:sub(1, stop)
    assert(tail:find('not npcEnemy:HasModifier%( \'' .. MOD_SELF_TESTED .. '\' %)'),
        'the kill loop must keep the literal shipped veto -- see this test\'s header')
    -- The `%(` matters: the site carries a comment that NAMES the helper to say
    -- why it is not used there, and a bare-name match would read that as wiring.
    assert(tail:find('X%.axe_IsBattleHungerFresh%(') == nil,
        'the kill loop must NOT be wired to the helper')
end

-- ---------------------------------------------------------------- section 5 --
-- Direction and correctness, asserted separately.  Subset alone would not see a
-- veto inverted the wrong way (the `liondrainbkb` lesson).

tests['direction: the helper binds the shipped answer and returns it last'] = function()
    local src = read_file(SRC)
    local from = src:find('function X%.axe_IsBattleHungerFresh')
    assert(from, 'X.axe_IsBattleHungerFresh is gone')
    local rest = src:sub(from)
    local body = rest:sub(1, assert(rest:find('\nend'), 'unterminated helper') + 4)
    assert(body:find('local bShipped = not hTarget:HasModifier%( \'' .. MOD_SELF_TESTED .. '\' %)'),
        'the shipped predicate must be computed FIRST and bound')
    assert(body:find('return bShipped'),
        'the last statement must return the shipped value, so armed can only narrow')
    assert(body:find('J%.IsModeTurbo%(%)') and body:find('J%.IsSoakCandidate%( \'' .. CAND .. '\' %)'),
        'turbo-only + soak-candidate gate')
    assert(body:find('J%.HasAghanimsShard%( bot %)'), 'the shard premise must be in the gate')
    local _, nReturns = body:gsub('return ', '')
    assert(nReturns == 2, 'exactly two returns (the veto and the shipped fallthrough), got '
        .. nReturns)
end

tests['direction: armed answers are a SUBSET of shipped, over the whole corpus'] = function()
    -- The sweep now passes the frame's whole enemy set as the candidate list, which
    -- is the widest list any call site can hand in -- so it is the sweep that gives
    -- the veto its best chance to fire, and any refusal it finds still has to be a
    -- carrier.
    local nDiff, nCarriers = 0, 0
    for _, path in ipairs(AXE_FRAMES) do
        local J, bot, heroes = rf.load(path)
        J.IsSoakCandidate = function(id) return id == CAND end
        local X = rf.load_hero('axe')
        local list = enemy_list(bot, heroes)
        for name, h in pairs(heroes) do
            if h:HasModifier(MOD_TARGET) then nCarriers = nCarriers + 1 end
            local armed = X.axe_IsBattleHungerFresh(h, list)
            if armed ~= true then
                nDiff = nDiff + 1
                assert(h:HasModifier(MOD_TARGET) == true,
                    'armed refused ' .. name .. ' in ' .. path
                    .. ' without the debuff being there -- that is not a subset of '
                    .. 'anything, it is a different predicate')
            end
        end
    end
    assert(nCarriers == 3, 'the corpus still carries 3 debuff instances, got ' .. nCarriers)
    -- NOT `== nCarriers`: a carrier with no alternative beside him is NOT refused any
    -- more, and that asymmetry is the 2026-09-09 change.  Refusals are a subset of
    -- carriers; the exact split is section 6's job, on named frames.
    assert(nDiff <= nCarriers, 'refusals must be a subset of the carriers, got '
        .. nDiff .. ' refusal(s) over ' .. nCarriers .. ' carrier(s)')
end

tests['direction: with NO candidate list the armed answer is the shipped answer'] = function()
    -- The conservative default, driven rather than asserted off the source.  Every
    -- one-argument caller -- and every future one -- keeps shipped behaviour, so an
    -- unproven alternative can never cost a refresh.
    for _, path in ipairs(AXE_FRAMES) do
        local J, _, heroes = rf.load(path)
        J.IsSoakCandidate = function(id) return id == CAND end
        local X = rf.load_hero('axe')
        for name, h in pairs(heroes) do
            assert(X.axe_IsBattleHungerFresh(h) == true,
                'armed refused ' .. name .. ' in ' .. path .. ' with no list to '
                .. 'prove an alternative with')
        end
    end
end

tests['correctness: arming is a byte-for-byte no-op where nobody is hungered'] = function()
    -- The assertion the subset case cannot make.  On the ring frame the enemy set
    -- Culling Blade reaches carries the debuff on ONE hero; strip that one and the
    -- armed and shipped answers must agree unit for unit.
    local J, bot, heroes = rf.load(RING_FIXTURE)
    J.IsSoakCandidate = function(id) return id == CAND end
    local X = rf.load_hero('axe')
    local list = enemy_list(bot, heroes)
    local n = 0
    for name, h in pairs(heroes) do
        if not h:HasModifier(MOD_TARGET) then
            n = n + 1
            assert(X.axe_IsBattleHungerFresh(h, list) == true,
                'arming changed the answer for ' .. name .. ', who carries no Battle '
                .. 'Hunger at all -- the veto is inverted or reads the wrong modifier')
        end
    end
    assert(n >= 8, 'the control needs a population, got ' .. n)
    assert(bot:GetTeam() ~= nil, 'loader sanity')
end

tests['wiring: exactly three call sites, and they are the three named ones'] = function()
    local body = consider_w_body(read_file(SRC))
    local _, n = body:gsub('X%.axe_IsBattleHungerFresh%(', '')
    assert(n == 3, 'X.ConsiderW must call the helper exactly 3 times, got ' .. n)
    -- ONE pattern with optional spaces: the file writes the call both ways, and
    -- two patterns double-count the spaced form.
    local _, nLiteral = body:gsub('HasModifier%(%s*\'' .. MOD_SELF_TESTED .. '\'%s*%)', '')
    assert(nLiteral == 5, 'the other five sites must keep the literal veto, got ' .. nLiteral)
    -- 2026-09-09: and every one of the three hands in a candidate list.  A site that
    -- calls with the target alone is back to the 4:1 stratum GH #562 measured, and
    -- would do it silently -- the conservative default answers "no alternative", so
    -- the lever would just stop firing there rather than go red.
    local _, nListed = body:gsub('X%.axe_IsBattleHungerFresh%(%s*npcEnemy%s*,%s*nIn', '')
    assert(nListed == 3, 'all 3 call sites must pass the list they are iterating, got '
        .. nListed)
    assert(body:find('X%.axe_IsBattleHungerFresh%(%s*npcEnemy%s*,%s*nInBonusEnemyList%s*%)'),
        'the teamfight site must hand in its own +200 ring, not the narrower list')
    local _, nIdle = body:gsub('X%.axe_IsHungerHarassIdle', '')
    assert(nIdle == 2, 'the lane site must both CALL its extra conjunct and hand it '
        .. 'in as fExtra, got ' .. nIdle .. ' mention(s).  Passing it only as a value '
        .. 'makes it the first function-value alias under bots/BotLib/, which '
        .. 'tests/test_hero_export_reachability.py reads as an orphan -- see that '
        .. 'file\'s LIMITS and the helper\'s header.')
    assert(body:find('X%.axe_IsHungerHarassIdle%( npcEnemy %)'),
        'and the call must be the site\'s own conjunct, on its own candidate')
end

-- ---------------------------------------------------------------- section 6 --
-- The premise conjunct (2026-09-09, GH #562).  Both strata on named real frames:
-- the veto must still fire where a spread is available, and must NOT fire where it
-- is not.  Section 3 already drives the second one end to end; here it is stated on
-- the predicate, where the two can sit side by side.

tests['premise: the veto still fires on the ring frame, where an alternative IS there'] = function()
    local J, bot, heroes = rf.load(RING_FIXTURE)
    J.IsSoakCandidate = function(id) return id == CAND end
    local X = rf.load_hero('axe')
    local list = enemy_list(bot, heroes)
    local carrier, sCarrier = nil, nil
    local nFresh = 0
    for name, h in pairs(heroes) do
        if h:GetTeam() ~= bot:GetTeam() and h:IsAlive() then
            if h:HasModifier(MOD_TARGET) then carrier, sCarrier = h, name
            else nFresh = nFresh + 1 end
        end
    end
    assert(carrier ~= nil, 'the ring frame must carry a hungered enemy; it is the '
        .. 'benefit-side frame this section rests on')
    assert(nFresh >= 1, 'and at least one enemy who is NOT hungered, got ' .. nFresh)
    assert(X.axe_HasHungerAlternative(carrier, list) == true,
        'the alternative test must see those ' .. nFresh .. ' fresh enemies')
    assert(X.axe_IsBattleHungerFresh(carrier, list) == false,
        'armed must still refuse the refresh on ' .. tostring(sCarrier)
        .. ' when there is somebody else to spread to -- if this passes, the '
        .. 'premise conjunct did not narrow the lever, it killed it')
    assert(X.axe_IsBattleHungerFresh(carrier) == true,
        'and the same carrier with no list must fall through to shipped')
end

tests['premise: on the flee frame the carrier is alone, so the veto stands down'] = function()
    -- The 121-episode stratum, on the frame section 1 measured.  The list handed in
    -- is the one the retreat and lane sites iterate: enemies inside cast range.
    local J, bot, heroes = rf.load(FIXTURE)
    J.IsSoakCandidate = function(id) return id == CAND end
    local X = rf.load_hero('axe')
    local nRange = bot:GetAbilityByName(BH):GetCastRange()
    local inRange = {}
    for _, h in pairs(heroes) do
        if h:GetTeam() ~= bot:GetTeam() and h:IsAlive()
            and GetUnitToUnitDistance(bot, h) <= nRange then
            inRange[#inRange + 1] = h
        end
    end
    assert(#inRange == 1 and inRange[1]:HasModifier(MOD_TARGET),
        'the premise of this case: one enemy in range and he is the carrier, got '
        .. #inRange)
    assert(X.axe_HasHungerAlternative(inRange[1], inRange) == false,
        'a list holding only the carrier himself is NOT an alternative')
    assert(X.axe_IsBattleHungerFresh(inRange[1], inRange) == true,
        'so the armed leg must stand down and let the refresh happen')
end

--- The ring frame, armed, with the carrier and the list section 6 keeps re-using.
--- `opt.nonTurbo` / `opt.shard` are the two premise flips, applied AFTER load exactly
--- as run() applies them.
local function ring(opt)
    opt = opt or {}
    local J, bot, heroes = rf.load(RING_FIXTURE)
    J.IsSoakCandidate = function(id) return id == CAND end
    if opt.nonTurbo then GetGameMode = function() return 1 end end
    if opt.shard then J.HasAghanimsShard = function() return true end end
    local X = rf.load_hero('axe')
    local carrier = nil
    for _, h in pairs(heroes) do
        if h:GetTeam() ~= bot:GetTeam() and h:IsAlive() and h:HasModifier(MOD_TARGET) then
            carrier = h
        end
    end
    assert(carrier ~= nil, 'the ring frame must carry a hungered enemy')
    return X, carrier, enemy_list(bot, heroes)
end

tests['premise: NON-turbo is the shipped answer even where an alternative exists'] = function()
    -- The turbo half of the gate, asserted on the frame where the veto CAN fire.
    -- Section 3's non-turbo case can no longer see this: its frame has no
    -- alternative, so both legs stand down there for the other reason.
    local X, carrier, list = ring({ nonTurbo = true })
    assert(X.axe_IsBattleHungerFresh(carrier, list) == true,
        'armed but non-turbo must answer the shipped true')
end

tests['premise: the SHARD stands the armed leg down even where an alternative exists'] = function()
    -- Same re-aim for the shard premise, and for the same reason.  With the shard
    -- Battle Hunger stacks, so a re-cast is a second stack and spreading is no
    -- longer dominant -- the lever must not fire no matter who else is standing there.
    local X, carrier, list = ring({ shard = true })
    assert(X.axe_IsBattleHungerFresh(carrier, list) == true,
        'armed with shard must answer the shipped true')
    local Xno, carrierNo, listNo = ring()
    assert(Xno.axe_IsBattleHungerFresh(carrierNo, listNo) == false,
        'control: without the shard the same frame DOES refuse -- otherwise the case '
        .. 'above passes for the wrong reason')
end

tests['premise: fExtra is the site`s own conjunct, and it can veto the alternative'] = function()
    -- The lane loop passes X.axe_IsHungerHarassIdle.  Driven on the ring frame so the
    -- ONLY thing separating the two answers is fExtra.
    local J, bot, heroes = rf.load(RING_FIXTURE)
    J.IsSoakCandidate = function(id) return id == CAND end
    local X = rf.load_hero('axe')
    local list = enemy_list(bot, heroes)
    local carrier = nil
    for _, h in pairs(heroes) do
        if h:GetTeam() ~= bot:GetTeam() and h:IsAlive() and h:HasModifier(MOD_TARGET) then
            carrier = h
        end
    end
    assert(carrier ~= nil, 'the ring frame must carry a hungered enemy')
    assert(X.axe_HasHungerAlternative(carrier, list) == true, 'without fExtra: alternative')
    assert(X.axe_HasHungerAlternative(carrier, list, function() return false end) == false,
        'a refusing fExtra must remove every alternative')
    assert(X.axe_IsBattleHungerFresh(carrier, list, function() return false end) == true,
        'and that must carry through to the lever itself')
    -- And the named one is a real predicate over the frame, not a stub.
    for _, h in ipairs(list) do
        assert(X.axe_IsHungerHarassIdle(h) == (h:GetAttackTarget() == nil),
            'X.axe_IsHungerHarassIdle must be exactly the lane loop`s conjunct')
    end
end

tests['premise: an already-hungered bystander is not an alternative'] = function()
    -- The one way this conjunct could be written and still be wrong: counting other
    -- carriers as somewhere to spread to.  Built on the flee frame's real units.
    local J, bot, heroes = rf.load(FIXTURE)
    J.IsSoakCandidate = function(id) return id == CAND end
    local X = rf.load_hero('axe')
    local carrier, other = nil, nil
    for _, h in pairs(heroes) do
        if h:GetTeam() ~= bot:GetTeam() and h:IsAlive() then
            if h:HasModifier(MOD_TARGET) then carrier = h elseif other == nil then other = h end
        end
    end
    assert(carrier ~= nil and other ~= nil, 'the frame needs a carrier and a bystander')
    assert(X.axe_HasHungerAlternative(carrier, { other }) == true,
        'a fresh bystander IS an alternative (control for the case above)')
    -- ONE labelled flip, and it is the only injected byte in this section: give the
    -- bystander the debuff too.  The loader builds HasModifier off a name table
    -- captured at load, so the flip goes on the spec rather than on that table.
    local spec = rawget(other, '__spec')
    local base = spec.HasModifier
    spec.HasModifier = function(u, sName)
        if sName == MOD_TARGET then return true end
        return base(u, sName)
    end
    assert(other:HasModifier(MOD_TARGET) == true, 'the flip must be visible')
    assert(other:HasModifier(MOD_SELF_TESTED) == false, 'and it must not answer everything')
    assert(X.axe_HasHungerAlternative(carrier, { other }) == false,
        'another carrier is not an alternative -- spreading onto him is the very '
        .. 'refresh this lever is trying to avoid')
end

-- ---------------------------------------------------------------- section KV --
-- Cross-check the anchors this lever's (c) argument rests on against the repo's own
-- KV snapshot, so a drift is RED rather than silent.

tests['KV: duration 12.0, dps ladder and cooldown ladder agree with the snapshot'] = function()
    local J, bot = rf.load(FIXTURE)
    J.IsSoakCandidate = function() return false end
    local w = bot:GetAbilityByName(BH)
    local sp = rawget(w, '__spec')
    local lv0 = sp.GetLevel
    for rank = 1, 4 do
        sp.GetLevel = rank
        assert(w:GetSpecialValueInt('damage_per_second') == BH_DPS[rank],
            ('rank %d dps: anchor %d, fixture KV %s'):format(
                rank, BH_DPS[rank], tostring(w:GetSpecialValueInt('damage_per_second'))))
        assert(w:GetCooldown() == BH_COOLDOWN[rank],
            ('rank %d cooldown: anchor %d, fixture KV %s'):format(
                rank, BH_COOLDOWN[rank], tostring(w:GetCooldown())))
    end
    sp.GetLevel = lv0
    assert(w:GetSpecialValueFloat('duration') == BH_DURATION,
        'duration anchor ' .. BH_DURATION .. ', fixture KV '
        .. tostring(w:GetSpecialValueFloat('duration')))
end

tests['KV: should_stack has NO base -- it is a shard grant, which is the premise'] = function()
    -- If this ever gains a base the lever's whole dominance argument reverses for
    -- every Axe, shard or not, and the gate must come out.
    local shapes = read_file('tests/mock/special_value_shapes.lua')
    local from = shapes:find("%['axe_battle_hunger'%]")
    assert(from, 'axe_battle_hunger is gone from the KV snapshot')
    local block = shapes:sub(from, shapes:find('\n        },', from))
    local line = block:match("%['should_stack'%][^\n]*")
    assert(line, 'should_stack is gone from the snapshot; re-derive the premise')
    assert(line:find('base = nil', 1, true),
        'should_stack now has a base -- Battle Hunger may stack without the shard, '
        .. 'and this lever\'s dominance argument no longer holds: ' .. line)
    assert(line:find('special_bonus_shard', 1, true),
        'should_stack must still be a SHARD grant: ' .. line)
end

return tests

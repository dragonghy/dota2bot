-- Charter item 8 ("final-bid reachability", the last id under it): `lf_rescue`.
--
-- THE RULE this file answers to (test_set.md 0b, director): a branch whose
-- comment argues "this value must beat X" is accepted on the FINAL quantity the
-- engine sees, after every downstream transform -- never on the helper's return
-- value. Every existing `lf_rescue` test asserts a helper:
-- test_replay_071423_sky_rescue.lua asserts `J.GetRescueTpTarget(bot) == luna`;
-- test_lf_rescue_landing_reach.lua asserts distances off
-- `J.GetNearbyLocationToTp`. Nothing had ever driven the shipped entry point.
--
-- VERDICT, and it is the first POSITIVE one this stream has read out of the
-- item layer: `lf_rescue`'s final quantity IS locally buyable. Driving the
-- shipped `ItemUsageThink()` on the rescue frames, armed, produces exactly one
-- `Action_UseAbilityOnLocation(item_tpscroll, <landing>)` on 37 of 39 of them,
-- and the landing is byte-equal to the helper's answer -- no downstream
-- transform mangles it. Off the candidate the same frames produce zero
-- actions. The two exceptions are enumerated, not tolerated: one hero the
-- item file cannot load at all (vengeful_spirit, GH #82's naming split), and
-- one honest refusal by the shipped enemy-tower guard two branches above the
-- rescue -- which happens to be GH #37's frame B, so that frame's published
-- landing number describes a TP the shipped chain would not have issued on
-- that snapshot (see TRIPLE below; routed back to #37, not acted on here).
--
-- ⭐ AND THERE IS NO BID. `ItemUsageThink` (aiug:8531) calls
-- `ItemUsageComplement()` as a bare statement and throws its return away; the
-- item loop's own `return nSlot + 1` (aiug:1031) dies in the same place. The
-- `BOT_ACTION_DESIRE_HIGH` the rescue branch returns is never compared with
-- anything -- the caller only asks `nItemDesire > 0`. So for this family item
-- 8's rule can only be discharged against the ACTION. That is written down for
-- the ids that come after, because reading "assert the final bid" literally
-- here would look for a number that does not exist.
--
-- ⭐ WHY THIS WAS INVISIBLE UNTIL NOW, and a correction to the SIXTEENTH world
-- assertion. That assertion (tests/test_itemdesire_world_assertion.lua) reports
-- that making the TP scroll honest and re-driving all 882 frames yields "no
-- real item decision on this corpus at all, only crashes and one
-- origin-phantom". That reading is true only of the SHIPPED DEFAULT: the sweep
-- never arms a soak candidate, so the two gated branches at the top of the TP
-- consider are dead in it. Arm `lf_rescue` and 37 real item decisions appear on
-- the same corpus -- and they appear ABOVE the unrunnable surfaces, because the
-- rescue branch returns at aiug:5117, before the generic TP block whose
-- `GetExtrapolatedLocation` / `GetFarmLaneDesire` calls produced those 209
-- crashes. The gap in the sixteenth assertion is not its arithmetic, it is its
-- arm.
--
-- HONEST BOUNDS. Read these before quoting any number below.
--
--   * The corpus cannot see a rescue frame with `--roles` untouched. GH #81:
--     every hero in every fixture reads pos 3 / `IsCore() == true`, and the
--     narrowed helper refuses laning-phase cores. Measured both ways in the
--     same run: 10 rescue frames with the shipped `J.IsCore`, 39 with it
--     overridden to false (the override every sibling lf_rescue test already
--     uses). Neither is the game's rate. 10 is an all-cores world, 39 an
--     all-supports world; the truth is bracketed, not located.
--   * `J.CanCastAbility` is false on every item handle in the corpus (the
--     sixteenth assertion), so the drive has to hand the TP scroll the two
--     clauses the loader never wires (IsTrained/IsActivated) -- exactly what
--     tests/_itemdesire_sweep.lua's "honest" pass does. Nothing else is
--     touched.
--   * The keystone fixture f_071423_sky_rescue carries no `buildings` block,
--     so `GetTower` is nil 11 times and `J.GetNearbyLocationToTp` takes its
--     no-towers-left fallback and answers the FOUNTAIN -- 540 units from where
--     Skywrath already stands. That frame pins the PLUMBING and says nothing
--     about the destination; the destination is pinned on the GH #37 triple,
--     which carries real structures.
--
-- ⭐ THE PREEMPTION QUESTION (charter item 8, concern (i)) IS NOW MEASURED
-- RATHER THAN ASSUMED -- and the measurement mostly disqualifies itself.
-- The shipped loop scans slots {5,4,3,2,1,0,15,16} and RETURNS on the first
-- item whose desire is positive; the TP scroll is seventh. Make every item in
-- the inventory honest, not just the scroll, and 10 of the 37 armed frames
-- lose the rescue to an earlier slot. But 8 of those 10 are a harness artifact
-- and are pinned as such below (the NINETEENTH world assertion): the winner is
-- `item_power_treads`, whose entire branch selection turns on
-- `GetPowerTreadsStat()`, which the loader never wires -- it answers 0 on
-- 270/270 treads handles in the corpus, and 0 matches NONE of
-- ATTRIBUTE_STRENGTH / ATTRIBUTE_AGILITY / ATTRIBUTE_INTELLECT as the mock
-- issues them. The two survivors are honest reads (`item_arcane_boots` at
-- <58% mana, `item_clarity` on a mana-starved ally) off fields the fixture
-- really carries. So the local answer is a bracket, not a rate:
--
--     honest lower bound  2/37   upper bound  10/37
--
-- and the real-game number is a replay-desk question, not a fixture one. That
-- is the whole point of measuring both halves: the mechanism is not in doubt
-- (it is the shipped `return`), only its size is, and this corpus cannot size
-- it. Changing the shared item loop on the strength of a static shape is the
-- `lanefix` entrance; nothing in bots/ changes here.
--
-- ⭐ A HAZARD FOR WHOEVER WRITES THE NEXT ONE OF THESE.
-- `J.GetRescueTpTarget` is SINGLE-SHOT. Its last conjunct is
-- `J.TryTakeTpResponseSlot()`, the team-wide one-responder-per-window quota,
-- and success also stamps `J.NoteRescueResponse`. Call it twice on one frame
-- and the second call answers nil -- not because the frame changed but because
-- the first call spent the ticket. (For `lf_rescue` itself this is CORRECT and
-- is not the `tpclaim` defect: the quota is the last conjunct, so it is only
-- spent once every other condition has passed, and the caller turns that same
-- answer into the action on the same frame. Ask and go are one step here.) The
-- consequence is only for test authors: a census that prefilters with the
-- helper and then drives the chain in the SAME load measures an empty world.
-- Every count below reloads the fixture between the prefilter and each arm.

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')

local tests = {}

local AIUG = 'bots/ability_item_usage_generic.lua'

local function read_file(path)
    local fh = assert(io.open(path, 'r'), 'cannot read ' .. path)
    local s = fh:read('*a')
    fh:close()
    return s
end

local AIUG_SRC = read_file(AIUG)

--- The slot scan order, READ OUT OF THE SHIPPED SOURCE rather than restated
--- here. A census that copies a constant measures its own copy (the M13 lesson
--- in test_itemdesire_world_assertion.lua); this way a mutation of the shipped
--- list moves every number in this file.
local SLOTS = (function()
    local body = assert(AIUG_SRC:match('local nItemSlot = {([^}]+)}'),
        'the item slot scan order moved out of `local nItemSlot = { ... }`')
    local t = {}
    for n in body:gmatch('%-?%d+') do t[#t + 1] = tonumber(n) end
    assert(#t >= 2, 'the slot scan order parsed to fewer than two slots')
    return t
end)()

local TP_SLOT = 15
local TP_POSITION = (function()
    for i, s in ipairs(SLOTS) do if s == TP_SLOT then return i end end
    return nil
end)()

-- The five globals the item file installs when its chunk runs. This file runs
-- the chunk ~120 times; they are captured now and restored at the end so no
-- successor test file inherits them.
local AIUG_GLOBALS = {
    'ItemUsageThink', 'AbilityUsageThink', 'BuybackUsageThink',
    'CourierUsageThink', 'AbilityLevelUpThink',
}
local BEFORE = {}
for _, g in ipairs(AIUG_GLOBALS) do BEFORE[g] = _G[g] end

local AIUG_CHUNK = assert(loadfile(AIUG), 'the item file no longer loads')

local KEYSTONE = 'tests/fixtures/f_071423_sky_rescue.lua'
local KEYSTONE_BOT = 'npc_dota_hero_skywrath_mage'

-- The GH #37 acceptance triple: the only rescue frames in the corpus that
-- carry real structures, hence the only ones that can speak about WHERE the
-- responder lands. Names and responders match
-- tests/test_lf_rescue_landing_reach.lua.
local TRIPLE = {
    { path = 'tests/fixtures/f_260819_123012_dk_rescue_far.lua',
      responder = 'npc_dota_hero_death_prophet' },
    -- ⭐ Frame B is SILENT through the shipped chain, and that is a finding of
    -- its own. GH #37 read frame B's landing (1579 units from the corpse) off
    -- `J.GetNearbyLocationToTp` directly; driven end to end, Lina never gets
    -- there -- she stands within 888 of an ENEMY tower, and the TP consider
    -- refuses at aiug:5095, two branches above the rescue. So the helper number
    -- for frame B describes a TP the shipped chain would not have issued on
    -- this snapshot. Bound it honestly: the fixture is a 1Hz snapshot of the
    -- decision instant (GH #107/#121), so "on this snapshot" is the whole
    -- claim -- the real cast may sit a sample either side of it. Routed back to
    -- GH #37 rather than acted on here.
    { path = 'tests/fixtures/f_260819_122930_lich_rescue_doomed.lua',
      responder = 'npc_dota_hero_lina', silent = 'enemy tower within 888' },
    { path = 'tests/fixtures/f_260819_123546_axe_rescue_ok.lua',
      responder = 'npc_dota_hero_jakiro' },
}

local function fixture_files()
    local p = assert(io.popen('ls tests/fixtures'))
    local files = {}
    for f in p:lines() do
        if f:match('^f_.*%.lua$') then files[#files + 1] = 'tests/fixtures/' .. f end
    end
    p:close()
    table.sort(files)
    return files
end

--- Load one frame and arm it. `opts.armed` arms `lf_rescue` and nothing else.
--- `opts.core` leaves the shipped `J.IsCore` alone (see HONEST BOUNDS).
--- `opts.all_honest` hands EVERY item the two clauses the loader never wires;
--- otherwise only the TP scroll gets them.
local function frame(path, hero, opts)
    local J, bot, heroes, fx = rf.load(path, hero)
    J.IsSoakCandidate = function(id) return opts.armed and id == 'lf_rescue' end
    if not opts.core then J.IsCore = function() return false end end
    local occupied = 0
    for _, s in ipairs(SLOTS) do
        local it = bot:GetItemInSlot(s)
        if type(it) == 'table' then
            occupied = occupied + 1
            if opts.all_honest or it:GetName() == 'item_tpscroll' then
                local sp = rawget(it, '__spec')
                sp.IsTrained = true
                sp.IsActivated = true
            end
        end
    end
    return J, bot, heroes, fx, occupied
end

--- Drive the SHIPPED entry point and return the action log (or an error tag).
local function drive(J, bot)
    local okl = pcall(AIUG_CHUNK)
    if not okl then return nil, 'aiug_load' end
    local log = rf.record_actions(bot)
    bot.lastItemFrameProcessTime = DotaTime() - 100
    local okt, terr = pcall(_G.ItemUsageThink)
    if not okt then return nil, 'crash:' .. tostring(terr) end
    return log, nil
end

local function item_name(entry)
    local a = entry.args[1]
    if type(a) == 'table' and a.GetName then return a:GetName() end
    return '?'
end

local function same_point(a, b)
    return type(a) == 'table' and type(b) == 'table'
        and a.x ~= nil and b.x ~= nil
        and math.abs(a.x - b.x) < 1 and math.abs(a.y - b.y) < 1
end

-- ---------------------------------------------------------------------------
-- The corpus census. One pass, memoised: every test below reads from it, and
-- both halves of every claim are recomputed here in the same run rather than
-- restated as literals (the GH #106 lesson -- growth is free, loss is caught).
-- ---------------------------------------------------------------------------

local CENSUS = nil
local function census()
    if CENSUS ~= nil then return CENSUS end
    local c = {
        fixtures = 0, subjects = 0, alive = 0,
        hits = 0, hits_core = 0, hits_with_buildings = 0,
        armed_tp = 0, armed_none = 0, armed_err = 0,
        off_action = 0, off_none = 0, off_err = 0,
        preempted = 0, preempt_by = {}, preempt_frames = {},
        treads_handles = 0, treads_stat_zero = 0, treads_stat_matches = 0,
        attr_ids = {},
        armed_none_frames = {}, armed_err_frames = {},
    }
    for _, path in ipairs(fixture_files()) do
        local ok0, _, _, heroes = pcall(rf.load, path)
        if ok0 then
            c.fixtures = c.fixtures + 1
            local names = {}
            for n in pairs(heroes) do names[#names + 1] = n end
            table.sort(names)
            for _, hero in ipairs(names) do
                c.subjects = c.subjects + 1
                -- Prefilter in its OWN load: J.GetRescueTpTarget spends the
                -- team response ticket, so asking here and driving here would
                -- drive an emptied world.
                local okp, J, bot, _h, fx = pcall(frame, path, hero, { armed = true })
                if okp and bot ~= nil and bot:IsAlive() then
                    c.alive = c.alive + 1
                    c.attr_ids[tostring(ATTRIBUTE_STRENGTH)] =
                        (c.attr_ids[tostring(ATTRIBUTE_STRENGTH)] or 0) + 1
                    for _, s in ipairs(SLOTS) do
                        local it = bot:GetItemInSlot(s)
                        if type(it) == 'table' and it:GetName() == 'item_power_treads' then
                            c.treads_handles = c.treads_handles + 1
                            local v = it:GetPowerTreadsStat()
                            if v == 0 then c.treads_stat_zero = c.treads_stat_zero + 1 end
                            if v == ATTRIBUTE_STRENGTH or v == ATTRIBUTE_AGILITY
                                or v == ATTRIBUTE_INTELLECT then
                                c.treads_stat_matches = c.treads_stat_matches + 1
                            end
                        end
                    end
                    local okr, ally = pcall(J.GetRescueTpTarget, bot)
                    if okr and ally ~= nil then
                        c.hits = c.hits + 1
                        if fx.buildings ~= nil then
                            c.hits_with_buildings = c.hits_with_buildings + 1
                        end
                        local tag = path:match('[^/]+$') .. '/' .. hero

                        local Ja, ba = frame(path, hero, { armed = true })
                        local la, ea = drive(Ja, ba)
                        if la == nil then
                            c.armed_err = c.armed_err + 1
                            c.armed_err_frames[#c.armed_err_frames + 1] = tag .. ' ' .. ea
                        elseif #la == 0 then
                            c.armed_none = c.armed_none + 1
                            c.armed_none_frames[#c.armed_none_frames + 1] = tag
                        elseif item_name(la[1]) == 'item_tpscroll' then
                            c.armed_tp = c.armed_tp + 1
                        end

                        local Jb, bb = frame(path, hero, { armed = false })
                        local lb, eb = drive(Jb, bb)
                        if lb == nil then c.off_err = c.off_err + 1
                        elseif #lb == 0 then c.off_none = c.off_none + 1
                        else c.off_action = c.off_action + 1 end

                        local Jc, bc = frame(path, hero, { armed = true, all_honest = true })
                        local lc = drive(Jc, bc)
                        if lc ~= nil and #lc > 0 then
                            local nm = item_name(lc[1])
                            if nm ~= 'item_tpscroll' then
                                c.preempted = c.preempted + 1
                                c.preempt_by[nm] = (c.preempt_by[nm] or 0) + 1
                                c.preempt_frames[#c.preempt_frames + 1] =
                                    { tag = tag, item = nm, path = path, hero = hero }
                            end
                        end

                        -- The same question with the SHIPPED J.IsCore, for the
                        -- lower end of the bracket. Only asked on frames that
                        -- already hit: the override only ever RELAXES the
                        -- helper (it turns one refusal off), so the shipped
                        -- world's hits are a subset of these. Asking it on all
                        -- 940 subjects instead would double the census's
                        -- wall-clock to buy the same number.
                        local okc, Jc2, bc2 = pcall(frame, path, hero,
                            { armed = true, core = true })
                        if okc and bc2 ~= nil and bc2:IsAlive() then
                            local okr2, ally2 = pcall(Jc2.GetRescueTpTarget, bc2)
                            if okr2 and ally2 ~= nil then c.hits_core = c.hits_core + 1 end
                        end
                    end
                end
            end
        end
    end
    CENSUS = c
    return c
end

-- ---------------------------------------------------------------------------

tests['[final action] the armed rescue reaches the engine as one TP-on-location'] = function()
    local J, bot, heroes = frame(KEYSTONE, KEYSTONE_BOT, { armed = true })
    local luna = assert(heroes['npc_dota_hero_luna'], 'the keystone lost Luna')
    local log, err = drive(J, bot)
    assert(log ~= nil, 'the shipped item chain did not run: ' .. tostring(err))
    assert(#log == 1, 'the rescue frame must produce exactly one action, got ' .. #log)
    assert(log[1].fn == 'Action_UseAbilityOnLocation',
        'the rescue TP must reach the engine as a ground cast, got ' .. tostring(log[1].fn))
    assert(item_name(log[1]) == 'item_tpscroll',
        'the action must carry the TP scroll, got ' .. item_name(log[1]))

    -- The landing the engine is handed is the helper's own answer -- no
    -- downstream transform between ConsiderItemDesire and Action_*.
    local J2, _b2, heroes2 = frame(KEYSTONE, KEYSTONE_BOT, { armed = true })
    local want = J2.GetNearbyLocationToTp(heroes2['npc_dota_hero_luna']:GetLocation())
    assert(same_point(log[1].args[2], want),
        'the action target drifted from J.GetNearbyLocationToTp')
    assert(luna ~= nil)
end

tests['[honest bound] on the keystone that landing is the fountain, and that is the fixture'] = function()
    local J, bot, heroes, fx = frame(KEYSTONE, KEYSTONE_BOT, { armed = true })
    assert(fx.buildings == nil,
        'f_071423_sky_rescue grew a buildings block -- re-derive this test, the '
        .. 'destination is no longer a fallback')
    local team = bot:GetTeam()
    for i = 0, 10 do
        assert(GetTower(team, i) == nil,
            'a tower became visible on the keystone; the fountain fallback no longer explains it')
    end
    local landing = J.GetNearbyLocationToTp(heroes['npc_dota_hero_luna']:GetLocation())
    assert(same_point(landing, J.GetTeamFountain()),
        'with no towers J.GetNearbyLocationToTp must take its fountain fallback')
    -- ...and the fountain is where Skywrath already is, so on THIS frame the
    -- rescue is a self-TP. That is the corpus talking, not the bot: the same
    -- helper on the GH #37 triple lands in front of a real tower.
    assert(bot:DistanceFromFountain() < 1000,
        'the keystone responder is meant to be idling at his own fountain')
end

tests['[final action] on the GH #37 triple the destination is a real tower-derived point'] = function()
    for _, f in ipairs(TRIPLE) do
        local J, bot, _h, fx = frame(f.path, f.responder, { armed = true })
        assert(fx.buildings ~= nil, f.path .. ' lost its buildings block')
        local log, err = drive(J, bot)
        assert(log ~= nil, f.path .. ': the item chain did not run: ' .. tostring(err))
        if f.silent then
            assert(#log == 0, f.path .. ': expected the shipped chain to refuse ('
                .. f.silent .. '), got ' .. #log .. ' action(s)')
            assert(#bot:GetNearbyTowers(888, true) > 0,
                f.path .. ': the stated reason (' .. f.silent .. ') no longer holds')
        else
            assert(#log == 1, f.path .. ': expected exactly one action, got ' .. #log)
            assert(item_name(log[1]) == 'item_tpscroll',
                f.path .. ': expected the TP scroll, got ' .. item_name(log[1]))
            local J2, bot2 = frame(f.path, f.responder, { armed = true })
            assert(not same_point(log[1].args[2], J2.GetTeamFountain()),
                f.path .. ': a rescue on a frame WITH towers must not land at the fountain')
            assert(bot2 ~= nil)
        end
    end
end

tests['[off-candidate equivalence] the shipped default takes no action on these frames'] = function()
    local frames = { { KEYSTONE, KEYSTONE_BOT } }
    for _, f in ipairs(TRIPLE) do frames[#frames + 1] = { f.path, f.responder } end
    for _, f in ipairs(frames) do
        local J, bot = frame(f[1], f[2], { armed = false })
        local log, err = drive(J, bot)
        assert(log ~= nil, f[1] .. ': the item chain did not run: ' .. tostring(err))
        assert(#log == 0,
            f[1] .. ': off `lf_rescue` the item layer must stay silent, got '
            .. #log .. ' action(s) (' .. (log[1] and item_name(log[1]) or '') .. ')')
    end
end

tests['[no bid] the shipped chain throws the desire away -- the action is the final quantity'] = function()
    -- ItemUsageComplement() is called as a bare statement.
    local call = assert(AIUG_SRC:match('\n[^\n]-J%.IsNoItemIllution%(bot%)[^\n]-\n'),
        'ItemUsageThink no longer calls ItemUsageComplement through IsNoItemIllution')
    assert(call:find('ItemUsageComplement()', 1, true),
        'ItemUsageComplement moved out of that line')
    assert(not call:find('return ItemUsageComplement', 1, true),
        'ItemUsageComplement is now returned -- the item layer grew a bid, and '
        .. 'item 8 must be re-asked against that number')
    assert(not call:find('= ItemUsageComplement', 1, true),
        'ItemUsageComplement result is now assigned -- re-derive this file')

    -- The loop's own return value is the slot index, not a desire, and it dies
    -- in the same place.
    assert(AIUG_SRC:find('\n\t\t\t\t\treturn nSlot + 1\n', 1, true),
        'the item loop no longer returns `nSlot + 1`; the no-bid reading must be redone')

    -- And the caller compares the desire with zero only -- never with another
    -- item's desire.
    assert(AIUG_SRC:find('if nItemDesire > 0', 1, true),
        'the item loop no longer selects on `nItemDesire > 0`; if it started '
        .. 'ranking desires, this family DOES have a bid now')
end

tests['[census] every rescue frame in the corpus, armed vs off'] = function()
    local c = census()
    assert(c.fixtures >= 100, 'fixture corpus shrank to ' .. c.fixtures)
    assert(c.alive >= 900, 'alive-subject corpus shrank to ' .. c.alive)
    assert(c.hits >= 30,
        'rescue-target frames fell to ' .. c.hits .. ' (was 39 on 2026-08-23); '
        .. 'either the helper narrowed or the corpus lost frames')
    assert(c.hits_with_buildings >= 20,
        'rescue frames carrying real structures fell to ' .. c.hits_with_buildings)

    -- The load-bearing ratio: armed, nearly every rescue frame produces the TP.
    assert(c.armed_tp + c.armed_none + c.armed_err == c.hits,
        'the armed arms do not close: ' .. c.armed_tp .. '+' .. c.armed_none
        .. '+' .. c.armed_err .. ' ~= ' .. c.hits)
    assert(c.armed_tp >= math.floor(c.hits * 0.9),
        'armed, only ' .. c.armed_tp .. ' of ' .. c.hits
        .. ' rescue frames put a TP on the engine (was 37/39)')

    -- The exceptions are enumerated, so a NEW one is a red rather than noise.
    assert(c.armed_none <= 1, 'a new silent armed rescue frame appeared: '
        .. table.concat(c.armed_none_frames, ', '))
    assert(c.armed_err <= 1, 'a new failing armed rescue frame appeared: '
        .. table.concat(c.armed_err_frames, ', '))

    -- Off the candidate: silence, except the same single load failure.
    assert(c.off_action == 0,
        'off `lf_rescue` the item layer produced ' .. c.off_action
        .. ' action(s) on rescue frames -- the gate leaks')
end

tests['[census] the one silent armed frame is the shipped enemy-tower guard'] = function()
    -- Enumerated rather than tolerated: Lina stands within 888 of an ENEMY
    -- tower, and the TP consider refuses before it ever reaches the rescue
    -- branch (aiug:5095). Pin the reason, so if the count moves the message
    -- says which guard moved.
    local J, bot = frame('tests/fixtures/f_260819_122930_lich_rescue_doomed.lua',
        'npc_dota_hero_lina', { armed = true })
    assert(#bot:GetNearbyTowers(888, true) > 0,
        'the silent frame no longer has an enemy tower in reach -- re-derive it')
    local log = drive(J, bot)
    assert(log ~= nil and #log == 0,
        'the enemy-tower guard stopped suppressing the rescue on this frame')
end

tests['[bracket] the corpus cannot locate the rescue rate, only bracket it'] = function()
    local c = census()
    -- GH #81: with the shipped J.IsCore every hero reads core, and the narrowed
    -- helper refuses laning-phase cores. Both ends measured in one run.
    assert(c.hits_core < c.hits,
        'the IsCore override no longer changes the rescue-frame count ('
        .. c.hits_core .. ' vs ' .. c.hits .. ') -- GH #81 may be fixed, in '
        .. 'which case this bracket collapses to a real rate and the HONEST '
        .. 'BOUNDS note above must be rewritten')
    assert(c.hits_core >= 5,
        'the all-cores end of the bracket fell to ' .. c.hits_core .. ' (was 10)')
end

tests['[preemption] measured on both halves: the mechanism is certain, the size is not'] = function()
    local c = census()
    assert(TP_POSITION ~= nil,
        'the TP scroll slot left the scan order entirely -- preemption analysis void')
    assert(TP_POSITION == #SLOTS - 1,
        'the TP scroll moved in the scan order (position ' .. TP_POSITION
        .. ' of ' .. #SLOTS .. '); the preemption reading must be redone')

    assert(c.preempted >= 1,
        'no earlier slot preempts the rescue any more -- if the shipped loop '
        .. 'changed, delete this test; if the corpus changed, re-measure')
    assert(c.preempted <= math.floor(c.hits * 0.5),
        'preemption jumped to ' .. c.preempted .. '/' .. c.hits
        .. ' (was 10/37) -- re-read the breakdown before quoting it')

    -- The breakdown, and the reason most of it does not count.
    local treads = c.preempt_by['item_power_treads'] or 0
    assert(treads >= 1, 'the treads preemptions vanished; re-derive the artifact claim')
    local honest = c.preempted - treads
    assert(honest >= 1,
        'the honest lower bound went to zero (was 2/37: arcane_boots, clarity)')
    assert(honest <= treads,
        'the honest half of the preemptions overtook the artifact half ('
        .. honest .. ' vs ' .. treads .. ') -- the bracket in the header is stale')
end

tests['[nineteenth world assertion] GetPowerTreadsStat is 0, and 0 is no ATTRIBUTE_*'] = function()
    local c = census()
    assert(c.treads_handles >= 200,
        'the corpus lost its Power Treads handles (' .. c.treads_handles .. ')')
    assert(c.treads_stat_zero == c.treads_handles,
        'GetPowerTreadsStat is no longer uniformly 0 ('
        .. c.treads_stat_zero .. '/' .. c.treads_handles
        .. ') -- the loader may have started wiring it; re-read the preemption '
        .. 'test, whose artifact half rests on this')
    assert(c.treads_stat_matches == 0,
        'a treads handle now reports an attribute the mock actually issued ('
        .. c.treads_stat_matches .. ') -- the branch selection became meaningful')
    -- What the item file does with that: every ordinary branch of
    -- ConsiderItemDesire["item_power_treads"] is chosen by comparing that 0
    -- against the three constants, so on this corpus the choice is made by an
    -- unwired default. NOT asserted here, because it is not knowable from this
    -- repo: the engine's own numbering. docs/BOT_API_REFERENCE.md lists the
    -- names (line 1931) and never their values, so whether the engine's
    -- ATTRIBUTE_STRENGTH happens to BE 0 -- which would make the unwired
    -- default silently mean "strength treads" rather than "no attribute" -- is
    -- open. It is worth settling, because the two readings send the shipped
    -- branch down different arms.
    assert(AIUG_SRC:find('GetPowerTreadsStat()', 1, true),
        'the treads consider stopped reading GetPowerTreadsStat')
end

tests['[nineteenth world assertion] the mock ids are not stable across loads'] = function()
    local c = census()
    local n, ids = 0, {}
    for id in pairs(c.attr_ids) do n = n + 1; ids[#ids + 1] = id end
    table.sort(ids)
    -- 2026-08-23T06:36Z (replay-check): adding ONE fixture
    -- (f_260823_002103_wk_ancient_camp_634) collapsed this from two ids
    -- (1051 on 760 loads / 1068 on 250) to one -- first-touch order shifted.
    -- ** That is exactly why `n >= 2` was the wrong shape of witness: it made a
    -- claim about instability that any corpus edit can flip, in either
    -- direction, without the underlying fact changing. ** The fact is that the
    -- value is issued by the MOCK, not the engine, so nothing may depend on
    -- it.  Asserted below in a form that survives re-ordering: whatever ids
    -- appear, they are mock handle numbers (>= 1000), not anything an engine
    -- enum would plausibly be (0, 1, 2 for the three attributes).
    assert(n >= 1, 'no ATTRIBUTE_STRENGTH id was observed at all')
    for _, id in ipairs(ids) do
        assert(tonumber(id) and tonumber(id) >= 1000,
            'ATTRIBUTE_STRENGTH now reads ' .. id .. ' -- a value in engine-enum '
            .. 'range means the mock started wiring it, and every reader that '
            .. 'compares GetPowerTreadsStat() against it changes meaning; '
            .. 'settle that before touching this test')
    end
end

tests['[successor hygiene] the five item-file globals are put back'] = function()
    census()
    for _, g in ipairs(AIUG_GLOBALS) do _G[g] = BEFORE[g] end
    for _, g in ipairs(AIUG_GLOBALS) do
        assert(_G[g] == BEFORE[g], g .. ' was not restored for the next test file')
    end
end

return tests

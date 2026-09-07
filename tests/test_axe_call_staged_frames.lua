-- [hero] `axecallbkb_i` / `axecallbkb_ii` on TWO REAL FRAMES.  Written
-- 2026-09-07 under OWNER_PRIORITIES P4.4, paying backlog item `-112` (the baton
-- handed over by the 2026-09-06T22:48Z split round) against the two coordinates
-- GH #577 section 5 registered.
--
-- WHAT THESE TWO FRAMES CHANGE, STATED FIRST SO NOBODY QUOTES A STALE BOUND
-- ------------------------------------------------------------------------
-- tests/test_axe_call_immune_veto.lua is built on the one CORPUS frame that puts
-- an enemy inside the Call ring, and that frame costs it THREE counterfactual
-- flips (cooldown 17.0 -> 0, channeling false -> true, immunity false -> true)
-- before branch (i) can be observed at all.  Frame (i) below costs **zero**:
--
--   * the cooldown needs no flip -- Berserker's Call is rank 3 at cd 0 in the
--     replay itself, with 324 mana against a 110 cost;
--   * the immunity needs no invention -- the frame's own modifier list carries
--     `modifier_black_king_bar_immune` on the enemy, which is a name the SHIPPED
--     IsMagicImmune override reads (section 2 reads that list out of the
--     override rather than retyping it);
--   * the channel needs no invention either -- the same modifier list carries
--     `modifier_teleporting`, and the replay corroborates it behaviourally:
--     Bristleback holds 190.2u for two consecutive 1.0s samples and is GONE by
--     t=1211.9, i.e. the teleport completed.
--
-- So what section 3 drives is not a counterfactual world.  It is the real frame
-- with two READER GAPS repaired, and section 2 measures those gaps rather than
-- asserting them.
--
-- ⚠️ THE TWO REPAIRS DO NOT HAVE THE SAME STANDING, and section 2 asserts the
-- difference so it cannot be flattened into one sentence:
--   * immunity -- the shipped override names `modifier_black_king_bar_immune`
--     explicitly.  Repairing it makes the mock agree with the SHIPPED reader's
--     own criterion.  This is the method tests/test_lion_drain_immune_target.lua
--     established.
--   * channeling -- the shipped IsChanneling override names NO modifier at all;
--     it adds a CanBeSeen guard and delegates to the engine.  So there is no
--     shipped criterion to agree with, and `modifier_teleporting` is the FRAME's
--     ground truth, not the reader's.  It is weaker, it is labelled weaker here,
--     and anyone quoting section 3 has to carry this bullet with it.
--
-- HONEST BOUNDS -- READ BEFORE QUOTING ANY NUMBER FROM HERE
-- ---------------------------------------------------------
--   * BOTH FRAMES ARE STAGED, NOT ADMITTED.  They live in tests/frames/ and are
--     loaded BY NAME.  Their admission price to tests/fixtures/ is NOT measured
--     by this round and nothing here claims a number for it -- same disposition
--     as `f_260828_124358_axe_cull_promise.lua`, and see tests/frames/README.md.
--   * BRANCH (ii) IS STILL SOURCE-LEVEL COVERAGE ONLY, and section 5 upgrades
--     the REASON from "the corpus is unlucky" to "no frame from this generator
--     can ever reach it".  Frame (ii) carries branch (ii)'s value column -- a
--     spell-immune enemy inside the initiation range with two non-immune enemies
--     in the same Call radius -- and arming `axecallbkb_ii` on it STILL changes
--     nothing, which section 5 asserts rather than argues.
--   * Section 5's schema leg is what makes that claim falsifiable: the day the
--     dumper grows a target or active-mode channel, it goes RED and says so.
--   * The distances, health, mana, levels, modifiers and the other nine heroes
--     on both frames are the replay's.  Only the two readers named above move,
--     and only in section 3.

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')

local SRC = 'bots/BotLib/hero_axe.lua'
local OVERRIDES = 'bots/FunLib/aba_global_overrides.lua'
local DUMPER = 'tools/batch_test/behavioral/dumper/main.go'

-- Frame (i): GH #577 section 5's first coordinate.
local FRAME_I = 'tests/frames/f_260831_061811_axe_call_tp_channel.lua'
-- Frame (ii): GH #577 section 5's second coordinate.
local FRAME_II = 'tests/frames/f_260828_002127_axe_call_bkb_ring.lua'

local AXE = 'npc_dota_hero_axe'
local BB = 'npc_dota_hero_bristleback'
local LINA = 'npc_dota_hero_lina'
local NECRO = 'npc_dota_hero_necrolyte'
local SS = 'npc_dota_hero_shadow_shaman'
local CALL = 'axe_berserkers_call'
local BKB_MOD = 'modifier_black_king_bar_immune'
local TP_MOD = 'modifier_teleporting'
local CAND_I = 'axecallbkb_i'
local CAND_II = 'axecallbkb_ii'

local Q_RADIUS = 315         -- the cast radius; the AoE taunt reaches this far
local RING = Q_RADIUS - 50   -- 265, the interrupt branch's GetAroundEnemyHeroList arg
local INIT_RANGE = Q_RADIUS - 90  -- 225, the initiation branch's IsInRange arg
local Q_MANA_R3 = 110
local DESIRE_HIGH = 0.75

local tests = {}

local function read_file(path)
    local fh = assert(io.open(path, 'r'), 'cannot open ' .. path)
    local body = fh:read('*a')
    fh:close()
    return body
end

-- ---------------------------------------------------------------- section 0 --
-- Provenance.  Both frames were re-derived by this stream from the archived
-- .dem, not transcribed from another group's table:
--
--   bash tools/batch_test/aws/session_setup.sh
--   BIN=$(bash tools/batch_test/behavioral/get_dumper.sh)
--
--   # frame (i)
--   awsx s3 cp s3://dota2bot-batch-results-4924/replays/20260831_061811_slot1__\
-- spot_20260831_061721_1_1dd5705f43a6bb10f1071464db32035199388141_731a21.dem g1.dem
--   "$BIN" g1.dem > t1.json
--   python3 tools/batch_test/replayscope/make_fixture.py t1.json \
--       --t 1209.9 --hero axe -o tests/frames/f_260831_061811_axe_call_tp_channel.lua
--
--   # frame (ii)
--   awsx s3 cp s3://dota2bot-batch-results-4924/dem21/spot_20260828_002039_1_\
-- 3110f323ead440674cef721a4797352366516d29_db92df/20260828_002127_slot1.dem g2.dem
--   "$BIN" g2.dem > t2.json
--   python3 tools/batch_test/replayscope/make_fixture.py t2.json \
--       --t 982.1 --hero axe -o tests/frames/f_260828_002127_axe_call_bkb_ring.lua
--
-- Neither carries `--roles`: the two analysis.json files are not attributable to
-- a soak seed, so make_fixture refuses to guess (GH #57).  Nothing below reads
-- jmz.GetPosition, which is why that is a note and not a blocker.

--- Load a staged frame, arm any subset of the two ids, optionally repair either
--- of the two blind readers section 2 measures, then drive the REAL X.ConsiderQ.
---
--- `opt.arm` is a LIST, never a boolean: arming (i), arming (ii) and arming both
--- are three different worlds and GH #577 split the id precisely so they cannot
--- be collapsed into one.
local function bid(frame, subject, opt)
    opt = opt or {}
    local armed = {}
    for _, id in ipairs(opt.arm or {}) do
        assert(id == CAND_I or id == CAND_II,
            'bid() asked to arm ' .. tostring(id) .. ', which is not one of this '
            .. "lever's ids -- a typo here would arm nothing and look like a finding")
        armed[id] = true
    end
    local J, bot, heroes, fx = rf.load(frame)
    -- `== true` and not a bare lookup: an absent key would answer nil, and a
    -- helper asserted `== false` then fails on a nil that behaves identically.
    J.IsSoakCandidate = function(id) return armed[id] == true end
    if opt.repairImmune then
        rawget(heroes[subject], '__spec').IsMagicImmune = true
    end
    if opt.repairChannel then
        rawget(heroes[subject], '__spec').IsChanneling = true
    end
    local X = rf.load_hero('axe')
    local d, m = X.ConsiderQ()
    return d, m, J, bot, heroes, fx
end

local function bid_i(opt) return bid(FRAME_I, BB, opt) end
local function bid_ii(opt) return bid(FRAME_II, LINA, opt) end

--- The modifier names the shipped IsMagicImmune override consults, read out of
--- that file so this test cannot drift away from the shipped reader.
local function immunity_modifiers()
    local src = read_file(OVERRIDES)
    local from = src:find('function CDOTA_Bot_Script:IsMagicImmune%(%)')
    assert(from, 'the IsMagicImmune override is gone from ' .. OVERRIDES
        .. '; this file was reading its modifier list out of it')
    local rest = src:sub(from)
    local body = rest:sub(1, rest:find('\nend') or #rest)
    local set, n = {}, 0
    for name in body:gmatch("HasModifier%('([%w_]+)'%)") do
        if not set[name] then set[name], n = true, n + 1 end
    end
    assert(n >= 11, 'the shipped override now consults ' .. n
        .. ' modifier names, was 11 -- re-read it before quoting anything here')
    return set, n
end

-- ---------------------------------------------------------------- section 1 --
-- Frame (i) ground truth, all of it off the replay.

tests['frame (i): 20:09, Call is rank 3 and READY in the replay itself'] = function()
    local _, _, _, bot, _, fx = bid_i()
    assert(fx.self == AXE and fx.time == 1209.9,
        'the decision instant moved: ' .. tostring(fx.self) .. ' @ ' .. tostring(fx.time))
    assert(bot:GetLevel() == 19, 'real Axe level, got ' .. tostring(bot:GetLevel()))
    local q = bot:GetAbilityByName(CALL)
    assert(q ~= nil, 'no ' .. CALL .. ' handle on the frame')
    assert(q:GetLevel() == 3, 'Call rank, got ' .. tostring(q:GetLevel()))
    -- THIS is what makes the frame worth staging: the corpus frame needed flip
    -- (a) because Axe had just cast Call there.  Here he has not.
    assert(q:GetCooldownTimeRemaining() == 0,
        'Call is on cooldown here after all (' .. tostring(q:GetCooldownTimeRemaining())
        .. 's) -- section 3 would then be a THREE-flip counterfactual like the '
        .. 'corpus one, not a zero-flip reading; re-read this whole file')
    assert(q:IsFullyCastable(), 'and the shipped first line does not bail')
    assert(bot:GetMana() == 324 and bot:GetMana() >= Q_MANA_R3,
        'real mana against the rank-3 cost, got ' .. tostring(bot:GetMana()))
end

tests['frame (i): bristleback is the ONLY live enemy inside the 265u ring'] = function()
    local _, _, _, bot, heroes = bid_i()
    local inRing, far = {}, 0
    for name, h in pairs(heroes) do
        if h:GetTeam() ~= bot:GetTeam() and h:IsAlive() then
            local d = GetUnitToUnitDistance(bot, h)
            if d <= RING then inRing[#inRing + 1] = name else far = far + 1 end
        end
    end
    assert(#inRing == 1 and inRing[1] == BB,
        'the interrupt branch loops over every enemy in the ring, so a second one '
        .. 'would make "the gate moved THIS decision" ambiguous; in-ring: '
        .. table.concat(inRing, ',') .. ' (' .. far .. ' further out)')
    local d = GetUnitToUnitDistance(bot, heroes[BB])
    assert(d > 190 and d < 191, 'bristleback really is ~190.2u away, got ' .. tostring(d))
end

tests['frame (i): the enemy carries BOTH the BKB modifier and the TP modifier'] = function()
    local _, _, _, _, heroes = bid_i()
    local bb = heroes[BB]
    assert(bb:HasModifier(BKB_MOD),
        'the frame no longer carries ' .. BKB_MOD .. ' -- the immunity repair in '
        .. 'section 3 would then be an INVENTION, not a reader repair')
    assert(bb:HasModifier(TP_MOD),
        'the frame no longer carries ' .. TP_MOD .. ' -- the channel repair in '
        .. 'section 3 would then be an INVENTION, not the frame\'s ground truth')
end

-- ---------------------------------------------------------------- section 2 --
-- The two reader gaps, MEASURED.  If either of these goes red the mock grew a
-- reader, which is good news -- drop the corresponding repair from section 3
-- rather than editing this section to match.

tests['gap: the mock answers IsMagicImmune FALSE on a unit carrying the BKB modifier'] = function()
    local _, _, _, _, heroes = bid_i()
    local bb = heroes[BB]
    assert(bb:HasModifier(BKB_MOD), 'precondition: the frame carries ' .. BKB_MOD)
    assert(bb:IsMagicImmune() == false,
        'GOOD NEWS, HARNESS GAP CLOSED: the mock now answers IsMagicImmune from the '
        .. 'modifier list.  Drop opt.repairImmune from section 3 and re-read it.')
end

tests['gap: and the SHIPPED reader does name that modifier, so the repair is agreement'] = function()
    local mods, n = immunity_modifiers()
    assert(mods[BKB_MOD] == true,
        'the shipped IsMagicImmune override stopped naming ' .. BKB_MOD .. ' (it '
        .. 'consults ' .. n .. ' names) -- the immunity repair loses its criterion')
end

tests['gap: IsChanneling has NO modifier criterion, so its repair is weaker'] = function()
    -- This is the asymmetry the header insists on.  It is asserted, not narrated,
    -- because the day somebody adds a modifier list to the IsChanneling override,
    -- the channel repair becomes an agreement too and this file should say so.
    local src = read_file(OVERRIDES)
    local from = src:find('function CDOTA_Bot_Script:IsChanneling%(%)')
    assert(from, 'the IsChanneling override is gone from ' .. OVERRIDES)
    local rest = src:sub(from)
    local body = rest:sub(1, rest:find('\nend') or #rest)
    assert(body:find('HasModifier') == nil,
        'GOOD NEWS: the shipped IsChanneling override now consults a modifier list. '
        .. 'If it names ' .. TP_MOD .. ', the channel repair in section 3 has the '
        .. 'same standing as the immunity one -- say so in the header.')
    local _, _, _, _, heroes = bid_i()
    assert(heroes[BB]:IsChanneling() == false,
        'GOOD NEWS: the mock now answers IsChanneling on this frame; drop '
        .. 'opt.repairChannel from section 3 and re-read it.')
end

-- ---------------------------------------------------------------- section 3 --
-- THE DECISION, on frame (i), with zero invented state.  This is the only place
-- in the tree where branch (i) is observed changing a decision on a frame whose
-- cooldown, immunity and channel are all the replay's.

tests['frame (i) DEFECT: the repaired frame, gate OFF, bids nothing'] = function()
    local d, m = bid_i({ repairImmune = true, repairChannel = true })
    assert(d == 0, 'the shipped bot casts here after all, got ' .. tostring(d)
        .. ' -- then there is no defect on this frame; re-read section 1')
    assert(m == nil, 'and no motive, got ' .. tostring(m))
end

tests['frame (i) FIX: arming axecallbkb_i breaks the teleport'] = function()
    local d, m = bid_i({ repairImmune = true, repairChannel = true, arm = { CAND_I } })
    assert(d == DESIRE_HIGH, CAND_I .. ' does not fire branch (i) here, got ' .. tostring(d))
    assert(m ~= nil and m:find('Q%-'), 'no Call motive, got ' .. tostring(m))
end

tests['frame (i) ISOLATION: it is the IMMUNITY term the gate moves, not the channel'] = function()
    -- Repair the channel WITHOUT the immunity: the shipped bot already casts.
    -- So the gate is not buying "Axe now interrupts channels"; it is buying
    -- "Axe stops declining a channel he can in fact break".
    local d = bid_i({ repairChannel = true })
    assert(d == DESIRE_HIGH,
        'a channeling, NON-immune enemy in the ring no longer fires the shipped '
        .. 'branch (got ' .. tostring(d) .. ') -- then this frame is not isolating '
        .. 'the immunity term and section 3 claims more than it shows')
end

tests['frame (i) ISOLATION: and the channel is required, immunity alone is not enough'] = function()
    local d = bid_i({ repairImmune = true, arm = { CAND_I } })
    assert(d == 0, 'branch (i) fired on a non-channeling enemy, got ' .. tostring(d)
        .. ' -- the interrupt premise is gone and the cost argument in the helper '
        .. 'header ("an enemy who is CHANNELING inside 265u is not attacking") '
        .. 'no longer bounds this lever')
end

tests['frame (i) SEPARABLE: arming axecallbkb_ii alone leaves branch (i) refusing'] = function()
    local w = { repairImmune = true, repairChannel = true }
    local dOff = bid_i(w)
    local dII = bid_i({ repairImmune = true, repairChannel = true, arm = { CAND_II } })
    local dI = bid_i({ repairImmune = true, repairChannel = true, arm = { CAND_I } })
    local dBoth = bid_i({ repairImmune = true, repairChannel = true,
                          arm = { CAND_I, CAND_II } })
    assert(w ~= nil and dOff == 0, 'the disarmed baseline moved, got ' .. tostring(dOff))
    assert(dII == dOff, CAND_II .. ' moved branch (i) (got ' .. tostring(dII)
        .. ' vs the disarmed ' .. tostring(dOff) .. ') -- the two ids are not '
        .. 'separable, so a wave arming either buys the composite reading GH #577 '
        .. 'split them to avoid')
    assert(dBoth == dI, 'arming both differs from arming ' .. CAND_I .. ' alone ('
        .. tostring(dBoth) .. ' vs ' .. tostring(dI) .. ') -- if the two ids had '
        .. 'been ANDed rather than kept independent, the case above would still pass')
end

-- ---------------------------------------------------------------- section 4 --
-- Frame (ii): branch (ii)'s VALUE COLUMN on a real frame.  Berserker's Call is
-- `No Target` -- an AoE taunt centred on Axe -- so gating it on ONE enemy's
-- immunity throws away every other enemy in the same radius.  That sentence has
-- been in the helper header since 2026-09-05 as an argument.  Here it is a frame.

tests['frame (ii): 16:22, Call rank 3 ready, and Lina is spell-immune by the shipped criterion'] = function()
    local _, _, _, bot, heroes, fx = bid_ii()
    assert(fx.self == AXE and fx.time == 982.1,
        'the decision instant moved: ' .. tostring(fx.self) .. ' @ ' .. tostring(fx.time))
    assert(bot:GetLevel() == 22, 'real Axe level, got ' .. tostring(bot:GetLevel()))
    local q = bot:GetAbilityByName(CALL)
    assert(q:GetLevel() == 3 and q:GetCooldownTimeRemaining() == 0 and q:IsFullyCastable(),
        'Call is not rank-3-and-ready on this frame')
    assert(bot:GetMana() == 319 and bot:GetMana() >= Q_MANA_R3,
        'real mana, got ' .. tostring(bot:GetMana()))
    local lina = heroes[LINA]
    assert(lina:GetTeam() ~= bot:GetTeam(), 'lina is the enemy carry here')
    local d = GetUnitToUnitDistance(bot, lina)
    assert(d > 75 and d < 76, 'lina really is ~75.1u away, got ' .. tostring(d))
    assert(d <= INIT_RANGE, 'and inside the initiation range of ' .. INIT_RANGE)
    local mods = immunity_modifiers()
    assert(lina:HasModifier(BKB_MOD) and mods[BKB_MOD],
        'lina no longer carries a modifier the shipped IsMagicImmune override '
        .. 'names -- the whole point of this frame is that the veto fires on her')
end

tests['frame (ii) VALUE: one immune enemy, TWO non-immune, all inside the 315u radius'] = function()
    local _, _, _, bot, heroes = bid_ii()
    local mods = immunity_modifiers()
    local immune, plain = {}, {}
    for name, h in pairs(heroes) do
        if h:GetTeam() ~= bot:GetTeam() and h:IsAlive()
            and GetUnitToUnitDistance(bot, h) <= Q_RADIUS
        then
            local bImmune = false
            for m in pairs(mods) do
                if h:HasModifier(m) then bImmune = true end
            end
            if bImmune then immune[#immune + 1] = name else plain[#plain + 1] = name end
        end
    end
    table.sort(immune); table.sort(plain)
    assert(#immune == 1 and immune[1] == LINA,
        'immune enemies in the Call radius: ' .. table.concat(immune, ','))
    assert(#plain == 2, 'non-immune enemies in the Call radius: '
        .. table.concat(plain, ',') .. ' -- this frame is staged BECAUSE there are '
        .. 'two of them; the value column is the taunt the shipped bot throws away')
    assert((plain[1] == NECRO and plain[2] == SS) or (plain[1] == SS and plain[2] == NECRO),
        'the two are meant to be necrolyte and shadow_shaman, got '
        .. table.concat(plain, ','))
    -- The cheaper half of the same reading: one of the two is nearly dead.
    assert(heroes[SS]:GetHealth() == 228,
        'shadow_shaman health, got ' .. tostring(heroes[SS]:GetHealth()))
end

-- ---------------------------------------------------------------- section 5 --
-- WHY BRANCH (ii) STAYS SOURCE-LEVEL-ONLY, and the upgrade this round buys: the
-- reason is no longer "the corpus is unlucky", it is "no frame this generator
-- can produce will ever reach it".  tests/test_axe_call_immune_veto.lua section 5
-- pinned three blockers on the CORPUS frame; here they are re-read on the frame
-- that carries branch (ii)'s value column.

tests['blocker 3 GIVES WAY here: no in-ring enemy is disabled on frame (ii)'] = function()
    -- On the corpus frame J.IsDisabled answered TRUE for the only in-ring enemy.
    -- That one really was corpus luck, and it is gone.  The other two are not.
    local _, _, J, bot, heroes = bid_ii()
    for name, h in pairs(heroes) do
        if h:GetTeam() ~= bot:GetTeam() and h:IsAlive()
            and GetUnitToUnitDistance(bot, h) <= Q_RADIUS
        then
            assert(J.IsDisabled(h) == false,
                name .. ' reads disabled on frame (ii); the last guard on the '
                .. 'initiation branch is back and this frame stops being the '
                .. 'three-blockers-minus-one reading section 5 claims')
        end
    end
end

tests['blockers 1 and 2 do NOT: botTarget is nil and IsGoingOnSomeone is false'] = function()
    local _, _, J, bot = bid_ii()
    assert(J.GetProperTarget(bot) == nil,
        'GOOD NEWS: J.GetProperTarget answers on a staged frame now -- branch (ii) '
        .. 'may be reachable without stubs.  Write that case and re-read this section.')
    assert(J.IsGoingOnSomeone(bot) == false,
        'GOOD NEWS: the frame reaches the initiation branch premise; re-read this '
        .. 'whole section before quoting "source-level coverage only" again.')
end

tests['and the REASON is the dump schema, not the corpus: no target, no mode channel'] = function()
    -- This is the assertion that outlives both frames.  J.GetProperTarget reads
    -- bot:GetTarget()/GetAttackTarget(); J.IsGoingOnSomeone reads
    -- bot:GetActiveMode().  Neither is entity state a replay networks -- they are
    -- bot-script runtime state -- so the dumper's snapshot struct carries no
    -- field for either, and make_fixture cannot write what the dump does not hold.
    local src = read_file(DUMPER)
    local from = src:find('type snapshot struct')
    assert(from, 'the snapshot struct is gone from ' .. DUMPER
        .. '; this leg was reading the frame schema out of it')
    local rest = src:sub(from)
    local body = rest:sub(1, rest:find('\n}') or #rest)
    local fields = {}
    for tag in body:gmatch('json:"([%w_]+)"') do fields[#fields + 1] = tag end
    assert(#fields >= 18, 'the snapshot struct now declares ' .. #fields
        .. ' json fields, was 19 -- this scan may be matching the wrong block, '
        .. 'which would make it vacuous rather than passing')
    for _, tag in ipairs(fields) do
        assert(not tag:find('target'),
            'GOOD NEWS: the dumper grew a `' .. tag .. '` channel.  A frame can now '
            .. 'carry bot:GetTarget()/GetAttackTarget(), so J.GetProperTarget can be '
            .. 'non-nil and branch (ii) may finally have a reachable frame -- take '
            .. 'that reading instead of restating this bound.')
        assert(tag ~= 'mode' and not tag:find('active_mode'),
            'GOOD NEWS: the dumper grew a `' .. tag .. '` channel.  J.IsGoingOnSomeone '
            .. 'can now be true on a frame; same instruction as above.')
    end
end

tests['GetActiveMode answers a value outside the BOT_MODE enum entirely'] = function()
    -- Not colour: it is why blocker 2 is structural rather than a property of
    -- this Axe at this instant.  The mock's generic `^Get` default answers 0, and
    -- 0 is not any BOT_MODE_* constant, so IsGoingOnSomeone is false BY
    -- CONSTRUCTION on every frame -- including one where the real Axe was
    -- mid-gank.
    local _, _, _, bot = bid_ii()
    local mode = bot:GetActiveMode()
    for _, m in ipairs({ BOT_MODE_ROAM, BOT_MODE_TEAM_ROAM, BOT_MODE_GANK,
                         BOT_MODE_ATTACK, BOT_MODE_DEFEND_ALLY }) do
        assert(m ~= nil, 'a BOT_MODE constant is missing from the mock; this scan '
            .. 'would then compare against nil and pass vacuously')
        assert(mode ~= m,
            'GOOD NEWS: the loaded frame answers a real active mode ('
            .. tostring(mode) .. ') -- branch (ii) premise may be reachable now.')
    end
    assert(mode ~= BOT_MODE_NONE,
        'the mock now answers BOT_MODE_NONE rather than its generic default; that '
        .. 'is a deliberate change somewhere, so re-read this leg before trusting it')
end

tests['CONSEQUENCE: arming axecallbkb_ii on its own value column changes nothing'] = function()
    -- The claim "branch (ii) is unreachable from a fixture" is asserted here
    -- behaviourally rather than argued from the three blockers.  If a wave is
    -- ever tempted to read (ii) off a fixture test, this is the case that says
    -- the reading would be vacuous.
    local dOff = bid_ii()
    local dII = bid_ii({ arm = { CAND_II } })
    local dBoth = bid_ii({ arm = { CAND_I, CAND_II } })
    assert(dOff == 0, 'the shipped bot bids on frame (ii) after all, got ' .. tostring(dOff))
    assert(dII == dOff,
        CAND_II .. ' changed the decision on frame (ii) (got ' .. tostring(dII)
        .. ') -- branch (ii) IS reachable from a fixture now, which is the good '
        .. 'news this whole section is waiting for; write the case and re-read it')
    assert(dBoth == dOff, 'arming both moved frame (ii), got ' .. tostring(dBoth))
end

-- ---------------------------------------------------------------- section 6 --
-- The staged frames are loaded BY NAME, and nothing here globs tests/fixtures/.
-- This case exists so that "staged, not admitted" is a property of the file
-- rather than a promise in its header (tests/frames/README.md's own finding:
-- a scan that claims to read "the tree" has to enumerate tests/frames/ too).

tests['both frames are staged in tests/frames/, not admitted to the corpus'] = function()
    for _, path in ipairs({ FRAME_I, FRAME_II }) do
        assert(path:find('^tests/frames/'), path .. ' is no longer staged')
        local fh = io.open(path, 'r')
        assert(fh, 'cannot open ' .. path)
        fh:close()
        local moved = io.open(path:gsub('^tests/frames/', 'tests/fixtures/'), 'r')
        if moved then
            moved:close()
            error(path .. ' has been ADMITTED to tests/fixtures/ as well. Admission '
                .. 'has a price (tests/frames/README.md) and this round did not '
                .. 'measure it; pay the reopen list or remove the copy.')
        end
    end
end

return tests

-- Replay-fixture regression for the `axeblink` guard on the FIRST real frame
-- where Axe actually owns and uses a Blink Dagger (hero backlog #5, GH #56 §5
-- "必须放行" frame).
--
-- Why this file exists on top of tests/test_replay_222428_axe_blink_call.lua:
-- that test pins the guard's inputs on a frame where Axe carries NO dagger
-- (its own caveat #1), and both of its crowd cases are MUTATIONS. Until the
-- `axebuyblink` reorder was armed on the farm, no frame of an Axe holding a
-- dagger existed anywhere in the corpus. The 04:11Z (a)-evidence wave produced
-- the first ones, and this is the single most load-bearing of them: the guard's
-- "Call is unavailable" clause is TRUE here, so the ONLY thing standing between
-- the shipped decision and a veto is the crowd clause -- and the blink that
-- clause lets through kills Skeleton King 6.1 seconds later.
--
-- Real frame: soak/spot_20260820_041137_1_7c8b5167…/20260820_043124_slot1
-- (seed 885, ARMED side), t=491.9 (8:11). Everything the guard reads is real:
--   * axe level 10, 1365/1711 HP, 137/395 mana, at (4048.8, -3108.2),
--   * axe_berserkers_call level 1 with 4.3s of cooldown left -- NOT castable,
--     while 137 mana is MORE than enough to pay for it, so "unavailable" here
--     means cooldown and nothing else,
--   * skeleton_king (enemy) at (3422.3, -3407.4) -- 694 away, i.e. inside the
--     shipped branch's 500..1200 window -- on 199/1221 HP (16%) with
--     Reincarnation on a 167.3s cooldown,
--   * and NO second enemy anywhere near him: the next closest is shadow_shaman,
--     ~2687 away from the landing point.
--
-- What the replay then shows (ground truth from the same .dem, event log):
--   t=492.3  axe casts item_blink        (the dagger reached his bag between
--                                         this snapshot and the next -- it is
--                                         in `items` at t=492.4, not at 491.9)
--   t=493.9  axe casts axe_culling_blade on skeleton_king
--   t=498.4  skeleton_king DIES to axe
-- and the fixture's own observed block records that Axe survived (died_after
-- nil) having taken 116 damage from SK in the following 5s.
--
-- POPULATION FACT measured this round (5 armed games of that wave, all the
-- mirror-valid ones with a surviving .dem): 10 blink casts, and the guard would
-- have held ZERO of them -- the landing point never carried 2 visible enemies
-- (exactly 1 in 5 of the 10 casts; the other 5 landed with none at all). So relaxing the
-- >= 2 threshold is the only way to make the guard fire in this population, and
-- THIS frame is the arithmetic proof that relaxing it to >= 1 is the wrong
-- direction: it would veto the blink that produced the kill.
--
-- CAVEATS, stated plainly:
--   1. Berserker's Call's mana cost is anchored from outside the frame (70 at
--      level 1, Liquipedia 2026-08) -- make_fixture.py does not dig ability
--      specs. The conclusion does not depend on the value: any cost <= 137
--      leaves the cooldown as the sole reason Call is unavailable.
--   2. The Call radius likewise is not in the dump. The guard reads
--      GetSpecialValueInt('radius') and falls back to 315.
--      RE-ANCHORED 2026-09-04 (hero), which is what the sentence that used to
--      close this caveat asked for: "if the dumper ever starts carrying
--      specials, this test says so instead of silently drifting". It is not the
--      dumper that changed -- tests/mock/replay_fixture.lua now serves
--      GetSpecialValue* out of the KV snapshot it already held
--      (tests/test_fixture_kv_getters.lua), so the reader answers 315 from KV
--      instead of 0-and-fallback. The VALUE is unchanged, so every number below
--      is unchanged; what changed is which of the two equal paths produced it,
--      and the branch under test is now the KV path. The test below asserts the
--      equality rather than either constant, so a rebalance of Berserker's Call
--      turns this file red instead of leaving the caveat quietly false.
--   3. The consumer adds RandomVector(150) to the landing point. The tests use
--      the un-jittered point and separately assert that no jitter of that size
--      can bring a second enemy inside the radius on this frame.
--   4. The consumer itself (X.ConsiderItemDesire['item_blink']) is not driven
--      end to end here; its wiring is pinned by the source tripwire in
--      tests/test_replay_222428_axe_blink_call.lua.
--
-- 2026-08-21 RE-READ (strategy backlog 0c, GH #57): this fixture was generated
-- WITHOUT `--roles`, so every jmz/Role position reader answered the draft SLOT.
-- It has been regenerated with the drafted roles (soak seed 885) and with real
-- structure HP. All thirteen cases above passed unchanged; the re-read is the
-- RE-READ section at the bottom of this file. Short version: the pin holds
-- because the guard never asks for a role at all, and the thing that DID move
-- is one layer out -- this Axe ran the `pos_3` item build, not the `pos_2` one
-- the slot-derived world had him on.

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')

local FIXTURE = 'tests/fixtures/f_260820_043124_axe_blink_kill.lua'
local CALL_MANA_COST_LV1 = 70   -- Liquipedia 2026-08; not carried by the dump.
local CALL_RADIUS_FALLBACK = 315 -- the guard's own fallback, see caveat 2.
local BLINK_CAST_RANGE = 1200   -- shop stat; the shipped branch's outer window.

local tests = {}

--- Load the real frame with the gate armed. Subject is already Axe (fx.self),
--- so the fixture's observed ground truth stays attached to him.
local function load_axe()
    local J, bot, heroes, fx = rf.load(FIXTURE)
    local call = bot:GetAbilityByName('axe_berserkers_call')
    rawget(call, '__spec').GetManaCost = CALL_MANA_COST_LV1
    J.IsSoakCandidate = function(id) return id == 'axeblink' end
    return J, bot, call, heroes, fx
end

--- The landing point the shipped branch computes on this frame, using the real
--- helper it uses: toward the target, min(cast range, distance) away.
local function landing(J, bot, hTarget)
    local d = GetUnitToUnitDistance(bot, hTarget)
    if d > BLINK_CAST_RANGE then d = BLINK_CAST_RANGE end
    return J.GetUnitTowardDistanceLocation(bot, hTarget, d)
end

tests['ground truth: axe at 8:11 holding a 4.3s Call cooldown, lone 16% SK 694 away'] = function()
    local J, bot, call, heroes, fx = load_axe()
    assert(fx.time == 491.9, 'frame time')
    assert(bot:GetUnitName() == 'npc_dota_hero_axe', 'subject is Axe')
    assert(bot:GetHealth() == 1365 and bot:GetMaxHealth() == 1711, 'real HP')
    assert(bot:GetMana() == 137 and bot:GetMaxMana() == 395, 'real mana')
    assert(bot:GetLevel() == 10, 'real level')
    assert(call:GetLevel() == 1, 'Call really is learned')
    assert(call:GetCooldownTimeRemaining() == 4.3, 'Call really is on cooldown')

    local sk = heroes['npc_dota_hero_skeleton_king']
    assert(sk:GetTeam() ~= bot:GetTeam(), 'skeleton king is the enemy here')
    assert(sk:GetHealth() == 199 and sk:GetMaxHealth() == 1221,
        'SK really is at 16% -- this is a finishable target, not a brawl')
    local d = GetUnitToUnitDistance(bot, sk)
    assert(d > 690 and d < 700, 'SK really is ~694 away, got ' .. tostring(d))
    -- The shipped branch's own window: > 500 and <= blink cast range. Without
    -- this the frame would not reach the guard at all and the test is vacuous.
    assert(d > 500 and d <= BLINK_CAST_RANGE,
        'the shipped offensive-blink branch really would fire on this gap')
    assert(J.GetEnemiesNearLoc(landing(J, bot, sk), CALL_RADIUS_FALLBACK)[1] ~= nil,
        'and the landing point really has the target on it')
end

tests['ground truth: Call is unavailable by COOLDOWN only, so the guard reaches its last clause'] = function()
    local _, bot, call = load_axe()
    assert(call:IsFullyCastable() == false, 'Call is not castable this instant')
    assert(bot:GetMana() >= CALL_MANA_COST_LV1,
        'but he could pay for it -- the cooldown is the whole reason')
end

tests['ground truth: the crowd clause reads 315, whichever of its two paths supplies it'] = function()
    local _, _, call = load_axe()
    local nRead = call:GetSpecialValueInt('radius')
    assert(nRead == CALL_RADIUS_FALLBACK,
        'the guard reads GetSpecialValueInt(\'radius\') and falls back to '
        .. CALL_RADIUS_FALLBACK .. '; the fixture world now serves the KV, and '
        .. 'the KV says the same number, so the arithmetic below is untouched. '
        .. 'Got ' .. tostring(nRead) .. ' -- if Berserker\'s Call was rebalanced, '
        .. 're-anchor caveat 2 and the fallback in hero_axe.lua with it')
end

tests['ground truth: exactly ONE enemy on the landing point'] = function()
    local J, bot, _, heroes = load_axe()
    local land = landing(J, bot, heroes['npc_dota_hero_skeleton_king'])
    local near = J.GetEnemiesNearLoc(land, CALL_RADIUS_FALLBACK)
    assert(#near == 1, 'lone target, got ' .. tostring(#near))
    assert(near[1]:GetUnitName() == 'npc_dota_hero_skeleton_king', 'and it is SK')
end

-- Caveat 3: the consumer jitters the landing point by up to 150. On this frame
-- no jitter of that size can change the head count, so the conclusion holds for
-- every point the consumer could actually have picked.
tests['ground truth: no RandomVector(150) jitter can turn this into a crowd'] = function()
    local J, bot, _, heroes = load_axe()
    local land = landing(J, bot, heroes['npc_dota_hero_skeleton_king'])
    local nSecond = nil
    for _, h in pairs(heroes) do
        if h:GetTeam() ~= bot:GetTeam() and h:IsAlive()
            and h:GetUnitName() ~= 'npc_dota_hero_skeleton_king' then
            local d = GetUnitToLocationDistance(h, land)
            if nSecond == nil or d < nSecond then nSecond = d end
        end
    end
    assert(nSecond ~= nil, 'there are other living enemies on this frame')
    assert(nSecond > CALL_RADIUS_FALLBACK + 150,
        'the second-closest enemy must stay out of reach of any jitter, got '
        .. tostring(nSecond))
end

tests['gate ON, UNTOUCHED real frame: the blink is NOT held (this one kills SK)'] = function()
    local J, bot, _, heroes = load_axe()
    local land = landing(J, bot, heroes['npc_dota_hero_skeleton_king'])
    assert(J.ShouldHoldAxeBlinkForCall(bot, land) == false,
        'jumping a lone 16% hero to finish it must stay allowed even with Call '
        .. 'on cooldown -- the replay shows this exact blink culling SK 1.6s '
        .. 'later and killing him at t=498.4')
end

tests['gate OFF (not turbo): inert on the same frame'] = function()
    local J, bot, _, heroes = load_axe()
    GetGameMode = function() return 1 end -- set after rf.load(); install() forces turbo
    assert(J.ShouldHoldAxeBlinkForCall(bot, landing(J, bot, heroes['npc_dota_hero_skeleton_king'])) == false,
        'outside turbo the guard must never hold a blink')
end

tests['gate OFF (turbo, candidate not armed): inert on the same frame'] = function()
    local J, bot, _, heroes = load_axe()
    J.IsSoakCandidate = function() return false end
    assert(J.ShouldHoldAxeBlinkForCall(bot, landing(J, bot, heroes['npc_dota_hero_skeleton_king'])) == false,
        'turbo alone must not hold a blink without the axeblink id')
end

-- MUTATION of the real frame: bring the one other living enemy in reach
-- (shadow_shaman) onto SK. Everything else -- Call cooldown, mana, levels,
-- Axe's position -- is untouched, so this isolates the crowd clause as the ONE
-- thing separating "allow" from "hold" on this frame.
tests['MUTATION: same frame + a second enemy on the landing point => the blink IS held'] = function()
    local J, bot, _, heroes = load_axe()
    local sk = heroes['npc_dota_hero_skeleton_king']
    rawget(heroes['npc_dota_hero_shadow_shaman'], '__spec').GetLocation = sk:GetLocation()
    local land = landing(J, bot, sk)
    assert(#J.GetEnemiesNearLoc(land, CALL_RADIUS_FALLBACK) == 2, 'the landing point is now a crowd')
    assert(J.ShouldHoldAxeBlinkForCall(bot, land) == true,
        'no Call and two enemies: that is the case the guard exists for')
end

-- Same crowd, Call available: the guard keys on Call availability, not on the
-- head count alone.
tests['MUTATION: crowd but Call ready => the blink is NOT held'] = function()
    local J, bot, call, heroes = load_axe()
    local sk = heroes['npc_dota_hero_skeleton_king']
    rawget(heroes['npc_dota_hero_shadow_shaman'], '__spec').GetLocation = sk:GetLocation()
    rawget(call, '__spec').GetCooldownTimeRemaining = 0
    assert(call:IsFullyCastable() == true, 'Call is castable once the cooldown is cleared')
    assert(J.ShouldHoldAxeBlinkForCall(bot, landing(J, bot, sk)) == false,
        'blinking into a crowd WITH Call is exactly what the dagger is for')
end

tests['the >= 2 threshold is load-bearing: a >= 1 rule would veto this kill'] = function()
    local J, bot, _, heroes = load_axe()
    local land = landing(J, bot, heroes['npc_dota_hero_skeleton_king'])
    -- The behavioural half: this frame sits at exactly one enemy and is allowed.
    assert(#J.GetEnemiesNearLoc(land, CALL_RADIUS_FALLBACK) == 1, 'one enemy')
    assert(J.ShouldHoldAxeBlinkForCall(bot, land) == false, 'and it is allowed')
    -- The source half: the constant that makes that true. Measured population
    -- (10 casts over 5 armed games) never reaches 2, so the standing temptation
    -- is to relax this to 1 -- which by the two assertions above would have
    -- vetoed the blink that killed SK.
    local f = assert(io.open('bots/FunLib/jmz_func.lua', 'r'))
    local src = f:read('*a')
    f:close()
    local body = src:match('function J%.ShouldHoldAxeBlinkForCall.-\nend')
    assert(body, 'could not locate J.ShouldHoldAxeBlinkForCall')
    assert(body:find('J%.GetEnemiesNearLoc%( vLandLoc, nRadius %) >= 2'),
        'the crowd threshold must stay at >= 2; see this test for why')
end

tests['the guard stays Axe-only on this frame'] = function()
    local J, bot, heroes = rf.load(FIXTURE, 'npc_dota_hero_skeleton_king')
    J.IsSoakCandidate = function(id) return id == 'axeblink' end
    assert(bot:GetUnitName() == 'npc_dota_hero_skeleton_king', 'subject override took')
    local axe = heroes['npc_dota_hero_axe']
    assert(J.ShouldHoldAxeBlinkForCall(bot, axe:GetLocation()) == false,
        'the guard is Axe-only; it must not touch any other hero blinking')
end

-- The fixture's own recorded consequences, so the "this blink was good" claim
-- is anchored in the dump rather than in this file's prose.
tests['ground truth: Axe survived the jump, paying 116 HP to SK for the kill'] = function()
    local _, _, _, _, fx = load_axe()
    assert(fx.observed.died_after == nil, 'Axe did not die in the ground-truth window')
    assert(fx.observed.burst['npc_dota_hero_skeleton_king'] == 116,
        'SK dealt 116 to him over the next 5s')
    local total = 0
    for _, e in ipairs(fx.observed.damage) do
        if e.actor == 'npc_dota_hero_skeleton_king' then total = total + e.value end
    end
    assert(total == 267, 'and 267 over the 30s horizon, got ' .. tostring(total))
end

-- ---------------------------------------------------------------------------
-- RE-READ under the real drafted roles (strategy backlog 0c, GH #57).
--
-- Every case above was written while this fixture carried no `roles` table, so
-- Role.GetPosition fell through to RoleAssignment[team][slot] -- the draft SLOT,
-- measured against the real draft at 47.3% (GH #57). The game is attributable
-- (`script_version = mirror:...:s885:dire`), so the drafted role is recoverable
-- and the fixture has been regenerated with `--roles`.
--
-- What moved (measured below, not assumed): ALL FIVE allies read a different
-- position -- viper 1->2, axe 2->3, sniper 3->1, CM 4->5, earthshaker 5->4 --
-- while the core/support partition happens to be preserved, and the ENEMY
-- team's draft happens to be the identity permutation. What did not move: any
-- assertion above, for the plain reason that the guard reads no role at all.
--
-- The margin is one layer out, and it is the layer this frame exists to serve.
-- `Item.GetRoleItemsBuyList` keys the whole item build on the position, so
-- the single corpus frame where Axe ever held a Blink Dagger was being read
-- against the WRONG build list: he really ran `pos_3` (blink is the 4th entry,
-- behind tank outfit + Crimson Guard + Blade Mail), not the `pos_2`/`pos_1`
-- list (blink 3rd, behind sven outfit + Blade Mail) the slot said. That makes
-- the shipped-vs-`axebuyblink` gap on THIS Axe one item deeper than recorded.
-- ---------------------------------------------------------------------------

local ROLE_MODULE = 'bots/FunLib/aba_role.lua'
local ITEM_MODULE = 'bots/FunLib/aba_item.lua'

local function slurp(path)
    local f = assert(io.open(path, 'r'))
    local s = f:read('*a')
    f:close()
    return s
end

--- Load the frame and hand back the aba_role module bound to that world, so a
--- test can force a counterfactual position on the subject only.
local function with_role_module()
    local J, bot, heroes, fx = rf.load(FIXTURE)
    local Role = require(GetScriptDirectory() .. '/FunLib/aba_role')
    return J, bot, heroes, fx, Role
end

--- The item build Axe actually ends up with on this frame, for a given
--- position and gate state. Drives the REAL hero file, not a copy of its list.
local function buy_list_for(nPos, bArmed)
    local J, bot, _, _, Role = with_role_module()
    local real = Role.GetPosition
    Role.GetPosition = function(u)
        if u == bot then return nPos end
        return real(u)
    end
    J.IsSoakCandidate = function(id) return bArmed == true and id == 'axebuyblink' end
    local ok, X = pcall(dofile, GetScriptDirectory() .. '/BotLib/hero_axe.lua')
    Role.GetPosition = real
    assert(ok, 'hero_axe.lua must load on this real frame: ' .. tostring(X))
    assert(type(X) == 'table' and X.sBuyList ~= nil,
        'hero_axe must publish an sBuyList for pos ' .. tostring(nPos))
    return X.sBuyList
end

local function index_of(tList, sItem)
    for i, v in ipairs(tList) do
        if v == sItem then return i end
    end
    return nil
end

tests['RE-READ: the frame carries the drafted roles now, and all five allies moved'] = function()
    local J, bot, _, fx = with_role_module()
    assert(fx.roles ~= nil, 'the fixture must carry the drafted roles -- without '
        .. 'them every position here is the draft slot (GH #57, 47.3% accurate)')

    local ids = GetTeamPlayers(GetTeam())
    assert(#ids == 5 and GetTeamMember(2) == bot,
        'Axe is the SECOND roster slot on this frame, which is what the '
        .. 'slot-derived world answered 2 from')
    assert(J.GetPosition(bot) == 3, 'drafted role of this Axe is pos 3, got '
        .. tostring(J.GetPosition(bot)) .. ' -- 2 means the fixture lost its roles')

    -- Not one lucky hero: the whole allied roster permuted.
    local moved = 0
    for i = 1, 5 do
        if J.GetPosition(GetTeamMember(i)) ~= i then moved = moved + 1 end
    end
    assert(moved == 5, 'all five allies must read a position other than their '
        .. 'slot; got ' .. moved .. ' -- if this drops, the fixture is answering '
        .. 'slots again')

    -- ...but the core/support fork does NOT flip here: {1,2,3} is
    -- {viper, axe, sniper} in both worlds. Stated as a measurement so nobody
    -- generalises the defstale round's CORE->SUPPORT flip into a rule.
    local cores = {}
    for i = 1, 5 do
        local m = GetTeamMember(i)
        if J.IsCore(m) then cores[m:GetUnitName()] = true end
    end
    assert(cores['npc_dota_hero_viper'] and cores['npc_dota_hero_axe']
        and cores['npc_dota_hero_sniper'], 'drafted cores are viper/axe/sniper')
    assert(cores['npc_dota_hero_crystal_maiden'] == nil
        and cores['npc_dota_hero_earthshaker'] == nil,
        'CM and earthshaker are supports in both worlds -- on THIS frame only '
        .. 'the numbers move, the partition does not')
end

tests['RE-READ: the enemy draft is the identity permutation on this frame'] = function()
    -- The guard reads enemies by position nowhere, but plenty of shipped code
    -- does; on this frame that half of the heal is a no-op and it is worth
    -- knowing it was CHECKED rather than assumed.
    local _, _, _, fx = with_role_module()
    local EXPECT = {
        ['npc_dota_hero_skeleton_king'] = 1,   -- player id 0 -> enemy slot 1
        ['npc_dota_hero_obsidian_destroyer'] = 2,
        ['npc_dota_hero_slardar'] = 3,
        ['npc_dota_hero_skywrath_mage'] = 4,
        ['npc_dota_hero_shadow_shaman'] = 5,
    }
    for name, pos in pairs(EXPECT) do
        assert(fx.roles[name] == pos, name .. ' drafted pos ' ..
            tostring(fx.roles[name]) .. ', want ' .. pos ..
            ' -- the enemy draft is the identity here; if this ever changes, '
            .. 'every enemy-position fork on this frame has to be re-read')
    end
end

tests['RE-READ: the guard never asks for a role, which is WHY the pin survived'] = function()
    -- "Thirteen cases passed unchanged" is worthless without this: the heal
    -- could not have moved them because ShouldHoldAxeBlinkForCall reads no
    -- position. Both entry points are counted -- J.GetPosition (the jmz
    -- wrapper) and Role.GetPosition (the module the wrapper calls, which
    -- aba_item reaches directly), because they are NOT the same function.
    local J, bot, call, heroes = load_axe()
    local Role = require(GetScriptDirectory() .. '/FunLib/aba_role')
    assert(J.GetPosition ~= Role.GetPosition,
        'the two role entry points are distinct functions -- hooking only one '
        .. 'of them undercounts')

    local reads = 0
    local realJ, realR = J.GetPosition, Role.GetPosition
    J.GetPosition = function(u) reads = reads + 1 return realJ(u) end
    Role.GetPosition = function(u) reads = reads + 1 return realR(u) end
    local held = J.ShouldHoldAxeBlinkForCall(bot, landing(J, bot, heroes['npc_dota_hero_skeleton_king']))
    J.GetPosition, Role.GetPosition = realJ, realR

    assert(held == false, 'the decision under test is still "allow"')
    assert(reads == 0, 'the guard asked for a position ' .. reads .. ' times; it '
        .. 'must ask ZERO -- if this ever becomes non-zero, the surviving cases '
        .. 'above stop being independent of the role heal and must be re-derived')
    assert(call ~= nil)
end

tests['RE-READ: the margin is the item build -- this Axe ran pos_3, not pos_2'] = function()
    local J, bot = with_role_module()
    assert(J.Item.GetRoleItemsBuyList(bot) == 'pos_3',
        'the drafted role puts this Axe on the pos_3 build; got '
        .. tostring(J.Item.GetRoleItemsBuyList(bot)))

    -- SHIPPED (gate off): the two worlds are different builds, not different
    -- labels for one build.
    local drafted = buy_list_for(3, false)
    local slot = buy_list_for(2, false)
    assert(index_of(drafted, 'item_blink') == 4,
        'shipped pos_3 buries blink at index 4 (tank outfit, Crimson Guard, '
        .. 'Blade Mail first); got ' .. tostring(index_of(drafted, 'item_blink')))
    assert(index_of(slot, 'item_blink') == 3,
        'shipped pos_2 (= the pos_1 list) has it at index 3; got '
        .. tostring(index_of(slot, 'item_blink')))
    assert(drafted[1] == 'item_tank_outfit' and slot[1] == 'item_sven_outfit',
        'even the starting bundle differs between the two worlds')
    assert(drafted[2] == 'item_crimson_guard',
        'and the extra item in front of blink is Crimson Guard')

    -- ARMED: the axebuyblink reorder collapses the blink prefix in BOTH
    -- worlds, so the gate neutralises this particular fork -- but not the
    -- starting bundle, which still differs.
    local draftedOn = buy_list_for(3, true)
    local slotOn = buy_list_for(2, true)
    assert(index_of(draftedOn, 'item_blink') == 2 and index_of(slotOn, 'item_blink') == 2,
        'armed, blink sits immediately after the starting bundle either way')
    assert(draftedOn[1] == 'item_tank_outfit' and slotOn[1] == 'item_sven_outfit',
        'the gate does not touch the starting bundle, so the role still picks it')
end

tests['RE-READ: the item build is the ONE role reader that bypasses the wrapper'] = function()
    -- Discovered while measuring the margin above, and worth a tripwire: of
    -- every Role.GetPosition call site outside aba_role itself, exactly two
    -- exist -- the jmz wrapper, and aba_item's build-list key. The build-list
    -- one therefore does NOT get the wrapper's nil handling, and the two
    -- floors are different numbers (wrapper 2, module 3). Nothing is broken --
    -- the module's own floor makes the bypass safe -- but a future edit that
    -- "cleans up" either floor changes which build every hero buys.
    local nOutside = 0
    local p = io.popen('grep -rn "Role\\.GetPosition" bots/ | grep -v "^' .. ROLE_MODULE .. '"')
    for line in p:lines() do
        if line:find('Role.GetPosition', 1, true) then nOutside = nOutside + 1 end
    end
    p:close()
    assert(nOutside == 2, 'expected exactly 2 Role.GetPosition call sites outside '
        .. ROLE_MODULE .. ' (the jmz wrapper and the item build-list key); got '
        .. nOutside .. ' -- a new bypass needs its own nil analysis')

    local item = slurp(ITEM_MODULE)
    assert(item:find("'pos_'..tostring(Role.GetPosition(bot))", 1, true),
        'the build-list key must still be the direct, unwrapped call -- this '
        .. 'test exists to notice if it is rewired')

    local jmz = slurp('bots/FunLib/jmz_func.lua')
    local wrapper = jmz:match('function J%.GetPosition%(bot%).-\nend')
    assert(wrapper and wrapper:find('role = 2', 1, true),
        "the jmz wrapper's nil floor must still be 2")

    local role = slurp(ROLE_MODULE)
    assert(role:find('if role == nil then\n        role = 3\n    end', 1, true),
        "aba_role's own nil floor must still be 3 -- it is what keeps the "
        .. 'build-list bypass from producing a nil sBuyList')
end

tests['RE-READ: the regeneration also brought real structure HP to this frame'] = function()
    -- Before the heal every building in every fixture stood at full health.
    -- The guard does not read structures, but the same regenerated frame is
    -- the input to anything that does, so the values are pinned here.
    local _, _, _, fx = with_role_module()
    local damaged, dead = 0, 0
    for _, b in ipairs(fx.buildings) do
        assert(b.hp ~= nil, b.name .. ' carries no hp -- the fixture went stale')
        if b.hp < 1.0 then damaged = damaged + 1 end
        if b.hp == 0 then dead = dead + 1 end
    end
    assert(damaged == 5, 'five structures are below full health on this frame, '
        .. 'got ' .. damaged)
    assert(dead == 1, 'exactly one of them is the already-dead Radiant top tier 2 '
        .. '(alive=false, hp=0), got ' .. dead)
end

return tests

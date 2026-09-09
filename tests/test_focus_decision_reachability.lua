-- [hero] The reachability table charter backlog `-131` asked for, built once and
-- KEPT.  It answers one question for the whole stream:
--
--     Across the entire fixture corpus, on how many instants does the SHIPPED
--     tree (every gate OFF) actually make an ability decision for one of the
--     five focus heroes -- and which ones?
--
-- THE READING, 2026-09-09.  110 fixtures.  Driving each focus hero as SUBJECT on
-- every frame that carries it alive gives 183 alive-subject instants
-- (axe 28 / zuus 45 / skeleton_king 36 / lion 24 / crystal_maiden 50).  The
-- shipped dispatch X.SkillsComplement issues an ability order on FOUR of them:
--
--     zuus            f_260819_222052_zuus_w2_leak            zuus_lightning_bolt
--     lion            f_260820_042607_zuus_reserve_cross      lion_finger_of_death
--     axe             f_260820_043637_axe_ring_close          axe_culling_blade
--     crystal_maiden  f_260820_182906_lion_drain_survived     crystal_maiden_crystal_nova
--
-- and on ZERO for Wraith King (0 of 36).
--
-- WHY THIS IS WORTH A FILE AND NOT A PARAGRAPH IN ONE REPORT.  Fifteen-odd
-- rounds of this stream have each independently measured "the domain of the
-- lever I wanted is empty" and written it up as a fact about that lever.  It is
-- not.  It is ONE fact about the corpus, and this table states it once, with the
-- funnel that produces it (§3) and the register of the specific predicates that
-- are unanswerable offline (§4).  A round that wants a NEW drivable focus-hero
-- lever should read §2 first: unless the four rows below have grown, the corpus
-- cannot show a shipped/armed DIFFERENCE on any decision that is not already
-- levered, and the answer is frame supply, not source reading.
--
-- ⚠️ WHAT THIS FILE DOES NOT SAY.  It does NOT say the bots are idle in real
-- games.  Every count here is about the fixture world, and §4 names the reason:
-- the single largest blocker is `bot:GetActiveMode()`, which is bot-VM state
-- that no .dem carries, and which gates most branches of every Consider* in the
-- five files.  A silent frame here is a harness fact, never a bot defect --
-- reading one as the other is the mistake this file exists to prevent.
--
-- ⚠️ THESE COUNTS ARE A RATCHET, NOT A CONSTANT.  Adding fixtures moves them,
-- and that is the point: the day a fifth live decision appears, §2 goes red and
-- names it, which is a new target for this stream.  Re-pin with the new reading
-- AND update the prose above it -- a stale sentence beside a re-pinned number is
-- the shape tests/test_focus_mana_cost_consumer_census.lua opens by warning
-- about.
--
-- ZERO behaviour change: `bots/` and `game/` carry no executable edit from the
-- commit that adds this file, no new gate id, no arm, no promote.

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')

local tests = {}

--- part -> unit name, for the five focus heroes.
local FOCUS = {
    { 'axe',            'npc_dota_hero_axe' },
    { 'zuus',           'npc_dota_hero_zuus' },
    { 'skeleton_king',  'npc_dota_hero_skeleton_king' },
    { 'lion',           'npc_dota_hero_lion' },
    { 'crystal_maiden', 'npc_dota_hero_crystal_maiden' },
}

--- The alive-subject frame count per hero, as measured 2026-09-09.
local ALIVE = {
    axe = 28, zuus = 45, skeleton_king = 36, lion = 24, crystal_maiden = 50,
}

--- Every instant on which the shipped dispatch orders an ability, as measured
--- 2026-09-09.  `part .. ' ' .. fixture basename` -> ability ordered.
local LIVE = {
    ['zuus f_260819_222052_zuus_w2_leak.lua']                = 'zuus_lightning_bolt',
    ['lion f_260820_042607_zuus_reserve_cross.lua']          = 'lion_finger_of_death',
    ['axe f_260820_043637_axe_ring_close.lua']               = 'axe_culling_blade',
    ['crystal_maiden f_260820_182906_lion_drain_survived.lua'] = 'crystal_maiden_crystal_nova',
}

local function fixture_paths()
    local t = {}
    local p = io.popen('ls tests/fixtures/*.lua 2>/dev/null')
    for l in p:lines() do t[#t + 1] = l end
    p:close()
    table.sort(t)
    return t
end

local function base(path) return (path:gsub('.*/', '')) end

--- Drive one focus hero as SUBJECT on one frame with every gate OFF.
--- @return nil when the hero is absent or dead on that frame, else the ability
---         name X.SkillsComplement ordered ('' when it ordered nothing).
local function drive(path, part, uname, fx)
    local present = false
    for _, u in ipairs(fx.units or {}) do
        if u.name == uname and u.alive == true then present = true end
    end
    if not present then return nil end
    local ordered = ''
    pcall(function()
        local J, bot = rf.load(path, uname)
        J.IsSoakCandidate = function() return false end
        local X = rf.load_hero(part)
        local log = rf.record_actions(bot)
        pcall(X.SkillsComplement)
        for _, a in ipairs(log) do
            if a.fn:find('UseAbility') then
                local ab = a.args[1]
                if type(ab) == 'table' and ab.GetName then ordered = ab:GetName() end
                break
            end
        end
    end)
    return ordered
end

--- One full sweep of the corpus.  Cached: sections 1-2 both need it.
local sweep_cache = nil
local function sweep()
    if sweep_cache ~= nil then return sweep_cache end
    local alive, live = {}, {}
    for _, path in ipairs(fixture_paths()) do
        local ok, fx = pcall(dofile, path)
        if ok and type(fx) == 'table' and fx.units then
            for _, h in ipairs(FOCUS) do
                local part, uname = h[1], h[2]
                local ordered = drive(path, part, uname, fx)
                if ordered ~= nil then
                    alive[part] = (alive[part] or 0) + 1
                    if ordered ~= '' then
                        live[part .. ' ' .. base(path)] = ordered
                    end
                end
            end
        end
    end
    sweep_cache = { alive = alive, live = live }
    return sweep_cache
end

--- --------------------------------------------------------------- section 1 --
--- Corpus shape: how much focus-hero material exists at all.

tests['1.1: the corpus carries 183 alive focus-hero instants, by hero'] = function()
    local s = sweep()
    local total, want = 0, 0
    for part, n in pairs(ALIVE) do
        want = want + n
        assert(s.alive[part] == n,
            ('%s: %d alive-subject frames, expected %d. The corpus moved -- '
             .. 'RE-PIN this number and the header prose together, then read '
             .. 'section 2: a hero that gained frames may have gained a target.')
            :format(part, s.alive[part] or 0, n))
    end
    for _, h in ipairs(FOCUS) do total = total + (s.alive[h[1]] or 0) end
    assert(total == want, ('total alive-subject instants %d, expected %d'):format(total, want))
end

--- --------------------------------------------------------------- section 2 --
--- The headline.  Four decisions in 183 instants, and each of the four already
--- carries a gated lever -- `zusboltcap` on the Zeus bolt, `lionrreach` /
--- `lionultcash` on the Lion finger, `axecullreach` / `cullthresh` on the Axe
--- blade, `cmqreach` on the CM nova.  That is why "measure the domain first,
--- then write the lever" (backlog -131) currently returns "no target".

tests['2.1: exactly the four known live decisions, and no others'] = function()
    local s = sweep()
    for k, v in pairs(s.live) do
        assert(LIVE[k] ~= nil,
            ('NEW LIVE DECISION: %s orders %s. That is a drivable target this '
             .. 'stream did not have -- read it before writing anything else, '
             .. 'and add it to LIVE.'):format(k, v))
        assert(LIVE[k] == v,
            ('%s now orders %s, was %s'):format(k, v, LIVE[k]))
    end
    for k, v in pairs(LIVE) do
        assert(s.live[k] == v,
            ('%s no longer orders %s (got %s). A live decision was LOST -- the '
             .. 'four in this table are the whole drivable surface, so find out '
             .. 'which change took it.'):format(k, v, tostring(s.live[k])))
    end
end

tests['2.2: Wraith King is the one focus hero with no live decision at all'] = function()
    local s = sweep()
    for k in pairs(s.live) do
        assert(not k:find('^skeleton_king '),
            'Wraith King gained a live decision (' .. k .. '). Section 3\'s funnel '
            .. 'is now stale; re-measure it.')
    end
    assert(s.alive.skeleton_king == 36,
        'the WK frame count moved; section 3 is pinned against 36')
end

--- --------------------------------------------------------------- section 3 --
--- WHY Wraith King's 36 frames are silent, measured rather than assumed -- and
--- one correction to a load-bearing sentence in bots/BotLib/hero_skeleton_king.lua.
---
--- The funnel: 36 alive -> 18 reach X.ConsiderQ's body (the rest are refused
--- upstream: not fully castable, or X.ShouldSaveMana holding mana for
--- Reincarnation) -> the ring the body builds is 855, i.e. nCastRange = 525 ->
--- 2 of the 18 have any enemy hero inside that ring -> 0 have one inside the
--- kill-confirm gate (nCastRange + 80 = 605).
---
--- ⭐ THE CORRECTION.  That file's block comment above `local nDamage` says
--- nCastRange "has been ZERO on every frame ever driven through this function:
--- GetCastRange is on no spec in tests/mock/".  It is 525 today -- the KV
--- getters were wired since -- and the comment even predicted this reading
--- ("entered on 0 under the zero and on 2 with 525 fed back").  So the sentence
--- that reads "a fixture-archive zero on this branch is ... a reading that was
--- never able to disagree" is no longer why the branch is dark.  It is dark for
--- a NARROWER and checkable reason: with the real 525 the loop IS entered, and
--- nobody is inside its distance gate.

local function wk_funnel()
    local nAlive, nBody, nBonus, nGate = 0, 0, 0, 0
    local radii = {}
    for _, path in ipairs(fixture_paths()) do
        local ok, fx = pcall(dofile, path)
        local row = nil
        if ok and type(fx) == 'table' and fx.units then
            for _, u in ipairs(fx.units) do
                if u.name == 'npc_dota_hero_skeleton_king' and u.alive == true then row = u end
            end
        end
        if row ~= nil then
            nAlive = nAlive + 1
            pcall(function()
                local J, bot, heroes = rf.load(path, 'npc_dota_hero_skeleton_king')
                J.IsSoakCandidate = function() return false end
                local X = rf.load_hero('skeleton_king')
                pcall(X.SkillsComplement)
                -- Read nCastRange OUT of the running function: the body builds
                -- (nCastRange+43, nCastRange+330) back to back, a delta of 287
                -- that no other pair in the function produces.
                local orig = J.GetNearbyHeroes
                local asked = {}
                J.GetNearbyHeroes = function(b, r, e, m)
                    asked[#asked + 1] = r
                    return orig(b, r, e, m)
                end
                pcall(X.ConsiderQ)
                J.GetNearbyHeroes = orig
                local bonus = nil
                for i = 2, #asked do
                    if asked[i] - asked[i - 1] == 287 then bonus = asked[i] end
                end
                if bonus ~= nil then
                    nBody = nBody + 1
                    radii[bonus] = true
                    local me = heroes['npc_dota_hero_skeleton_king']
                    local inBonus, inGate = 0, 0
                    for _, u2 in ipairs(fx.units) do
                        local h = heroes[u2.name]
                        if h ~= nil and u2.alive == true and u2.team ~= row.team
                            and u2.name ~= 'npc_dota_hero_skeleton_king' then
                            local d = GetUnitToUnitDistance(me, h)
                            if d <= bonus then inBonus = inBonus + 1 end
                            if d <= bonus - 330 + 80 then inGate = inGate + 1 end
                        end
                    end
                    if inBonus > 0 then nBonus = nBonus + 1 end
                    if inGate > 0 then nGate = nGate + 1 end
                end
            end)
        end
    end
    return nAlive, nBody, nBonus, nGate, radii
end

tests['3.1: the WK funnel -- 36 alive, 18 reach the body, 2 in ring, 0 in gate'] = function()
    local nAlive, nBody, nBonus, nGate = wk_funnel()
    assert(nAlive == 36, 'alive-WK frames ' .. nAlive .. ', expected 36')
    assert(nBody == 18, 'frames reaching X.ConsiderQ body ' .. nBody .. ', expected 18')
    assert(nBonus == 2, 'frames with a non-empty bonus ring ' .. nBonus .. ', expected 2')
    assert(nGate == 0,
        'frames with an enemy inside nCastRange+80 is now ' .. nGate .. ', was 0. '
        .. 'The kill-confirm branch just became drivable -- that is a target.')
end

tests['3.2: nCastRange inside X.ConsiderQ is the real 525, not the old 0'] = function()
    local _, _, _, _, radii = wk_funnel()
    local seen = {}
    for r in pairs(radii) do seen[#seen + 1] = r end
    assert(#seen == 1, 'the body built more than one bonus radius: ' .. #seen)
    assert(seen[1] == 855,
        ('bonus ring %s => nCastRange %s. It was 525+330=855 on 2026-09-09; if '
         .. 'this is 330 the KV cast-range getter regressed to 0 and every reach '
         .. 'reading in this file is understated.'):format(seen[1], seen[1] - 330))
end

--- --------------------------------------------------------------- section 4 --
--- The instrument register: the predicates that make section 2's number four.
--- Each is MEASURED on a real frame here, so "the domain was empty" can never
--- again be recorded as a fact about a lever when it is a fact about a meter.
--- (`IsFacingLocation` is deliberately absent -- it already has its own measured
--- home in tests/test_cm_w_selfdefense_facing.lua section 6.)

local REG_FRAME = 'tests/fixtures/f_260820_103216_cm_es_aftershock.lua'

tests['4.1: GetActiveMode answers 0 -- not even BOT_MODE_NONE'] = function()
    local _, bot = rf.load(REG_FRAME, 'npc_dota_hero_crystal_maiden')
    assert(bot:GetActiveMode() == 0,
        'GetActiveMode now answers ' .. tostring(bot:GetActiveMode())
        .. '. If a .dem learned to carry a bot mode, most of section 2 is stale.')
    assert(BOT_MODE_NONE ~= 0,
        'BOT_MODE_NONE is 0, so the mock default is now a REAL mode value and '
        .. 'every `GetActiveMode() == BOT_MODE_x` guard changed meaning')
end

tests['4.2: the four Is* the corpus cannot answer are all false by default'] = function()
    local _, bot, heroes = rf.load(REG_FRAME, 'npc_dota_hero_crystal_maiden')
    local other = heroes['npc_dota_hero_earthshaker']
    assert(other ~= nil, 'the register frame lost its earthshaker')
    for _, k in ipairs({ 'IsChanneling', 'IsMagicImmune', 'IsInvulnerable', 'IsCastingAbility' }) do
        assert(other[k](other) == false,
            k .. ' now answers something on a fixture unit -- a branch that was '
            .. 'structurally dark may have become drivable. Re-read section 2.')
    end
    -- Not an Is*, and the one people keep re-measuring: no fixture carries creeps.
    assert(#bot:GetNearbyCreeps(1600, true) == 0,
        'the corpus grew creep units. Every "creeps are not in fixtures" note in '
        .. 'bots/BotLib/hero_crystal_maiden.lua and this stream\'s reports is stale.')
end

--- ⭐ 4.3 CORRECTS A PREMISE THIS STREAM HAS BEEN CARRYING.  `J.IsInTeamFight`
--- reads `J.GetNearbyHeroes( bot, r, false, BOT_MODE_ATTACK )`, so the obvious
--- expectation is that it is false everywhere offline, ally modes being 0.  It
--- is NOT: the loader's `GetNearbyHeroes` override ignores the mode argument
--- entirely, so the predicate degenerates to ">= 2 allies inside the radius"
--- and is TRUE on 2 of Crystal Maiden's 50 frames.  The teamfight branches of
--- the focus files are therefore ENTERED offline; what stops them one line
--- later is a different meter -- `GetEstimatedDamageToTarget` answers 0, and
--- every one of those branches seeds its "most dangerous enemy" search at 0 and
--- tests with a strict `>`, so no candidate is ever selected.  Measured on
--- f_260820_162821_lion_drain_lethal: 2 allies inside 1200, two legal enemies
--- inside it (lion, necrolyte), both projecting 0.
--- ⛔ AND THE CONSEQUENCE FOR LEVER-WRITING, because it is a trap: the 0-seed /
--- strict-`>` shape looks like a defect and is NOT one to repair here.  In a
--- real game any living enemy that can attack projects > 0, so a "seed at -1"
--- lever would change nothing in Turbo and everything offline -- a fixture-only
--- repair wearing a behaviour change's clothes.
tests['4.3: J.IsInTeamFight is TRUE on 2 CM frames -- the mock ignores ally mode'] = function()
    local nAlive, nFight = 0, 0
    for _, path in ipairs(fixture_paths()) do
        local ok, fx = pcall(dofile, path)
        if ok and type(fx) == 'table' and fx.units then
            for _, u in ipairs(fx.units) do
                if u.name == 'npc_dota_hero_crystal_maiden' and u.alive == true then
                    pcall(function()
                        local J, bot = rf.load(path, 'npc_dota_hero_crystal_maiden')
                        nAlive = nAlive + 1
                        if J.IsInTeamFight(bot, 1200) then nFight = nFight + 1 end
                    end)
                end
            end
        end
    end
    assert(nAlive == 50, 'CM alive frames ' .. nAlive .. ', expected 50')
    assert(nFight == 2,
        'J.IsInTeamFight answered true on ' .. nFight .. ' CM frame(s), was 2. '
        .. 'If this went to 0 the loader started honouring the ally MODE argument; '
        .. 'if it grew, the corpus did. Either way the teamfight branches\' domain '
        .. 'moved and section 2 needs re-reading.')
end

tests['4.3b: and what actually stops them is GetEstimatedDamageToTarget = 0'] = function()
    local PIN = 'tests/fixtures/f_260820_162821_lion_drain_lethal.lua'
    local J, bot = rf.load(PIN, 'npc_dota_hero_crystal_maiden')
    assert(J.IsInTeamFight(bot, 1200), PIN .. ' is no longer a teamfight frame')
    local seen = 0
    for _, h in pairs(J.GetNearbyHeroes(bot, 1200, true, BOT_MODE_NONE)) do
        seen = seen + 1
        assert(h:GetEstimatedDamageToTarget(false, bot, 3.0, DAMAGE_TYPE_PHYSICAL) == 0,
            h:GetUnitName() .. ' now projects damage. The "most dangerous enemy" '
            .. 'searches in CM/WK/Lion seed at 0 and test with a strict `>`, so '
            .. 'this is the single value that decides whether their teamfight '
            .. 'branches can fire at all offline.')
    end
    assert(seen == 2, 'expected 2 enemy heroes inside 1200 on the pin, got ' .. seen)
end

tests['4.4: GetHealthRegen is 0, so every kill-confirm ignores its own delay'] = function()
    local _, bot, heroes = rf.load(REG_FRAME, 'npc_dota_hero_crystal_maiden')
    for name, h in pairs(heroes) do
        assert(h:GetHealthRegen() == 0,
            name .. ' has a health regen now. J.WillMagicKillTarget subtracts '
            .. '`GetHealthRegen() * nDelay`, so any lever about a kill-confirm\'s '
            .. 'DELAY argument became measurable -- it was a strict no-op before.')
    end
    assert(bot:GetHealthRegen() == 0, 'the subject grew a health regen')
end

--- --------------------------------------------------------------- section 5 --
--- A lever this round PRICED AND DID NOT WRITE, recorded so the next round does
--- not re-derive it.  hero_zuus.lua's `zusfightquorum` header registers a second
--- half of the same defect and leaves it open, by name:
---
---     "measuring the fight from the CASTER's position is measuring it from the
---      one position a backline mage should never be in ... Repointing the count
---      at the fight rather than at Zeus is a second lever with its own id"
---
--- The argument is right (Thundergod's Wrath is global; the quorum is measured
--- in a 1400 circle around Zeus).  The PRICE is not: re-centring the count on
--- the densest enemy cluster -- max over the enemies Zeus can see of the
--- castable enemies within X.nUltFightRadius of THEM, floored at the shipped
--- reading so the direction stays one-way -- moves the count on 2 of 45
--- alive-Zeus frames, from 1 to 2, and never past either quorum (shipped 5,
--- `zusfightquorum` armed 3).  Corpus effect on the DECISION: zero.
---
--- ⚠️ And the header's own supporting number does not transfer.  It reads "two
--- of Zeus's own enemies each see FOUR enemies inside 1400 while Zeus sees two",
--- but an enemy of Zeus sees ITS enemies -- Zeus's own team.  That is a count of
--- the other side, not a better-centred count of this one, so it does not price
--- this lever.  Under P4.2's admission freeze a new id that cannot cross a
--- threshold in the corpus is inventory, not progress; it stays unwritten until
--- frames exist that can move it.

tests['5.1: the re-centred ult quorum count moves 2 of 45 frames, and never past a quorum'] = function()
    local R = 1400
    local nAlive, nDiff, nMax = 0, 0, 0
    for _, path in ipairs(fixture_paths()) do
        local ok, fx = pcall(dofile, path)
        local has = false
        if ok and type(fx) == 'table' and fx.units then
            for _, u in ipairs(fx.units) do
                if u.name == 'npc_dota_hero_zuus' and u.alive == true then has = true end
            end
        end
        if has then
            pcall(function()
                local J, bot = rf.load(path, 'npc_dota_hero_zuus')
                nAlive = nAlive + 1
                local seen = J.GetNearbyHeroes(bot, R, true, BOT_MODE_NONE)
                local shipped = J.GetInvUnitCount(false, seen)
                local pool = GetUnitList(UNIT_LIST_ENEMY_HEROES)
                local best = shipped
                for _, c in pairs(seen) do
                    local around = {}
                    for _, e in pairs(pool) do
                        if e ~= nil and GetUnitToUnitDistance(c, e) <= R then
                            table.insert(around, e)
                        end
                    end
                    local n = J.GetInvUnitCount(false, around)
                    if n > best then best = n end
                end
                if best ~= shipped then nDiff = nDiff + 1 end
                if best > nMax then nMax = best end
            end)
        end
    end
    assert(nAlive == 45, 'alive-Zeus frames ' .. nAlive .. ', expected 45')
    assert(nDiff == 2, 'the re-centred count now differs on ' .. nDiff .. ' frames, was 2')
    assert(nMax < 3,
        'the re-centred count reached ' .. nMax .. ', i.e. `zusfightquorum`\'s armed '
        .. 'quorum of 3. The lever section 5 declined to write can now change a '
        .. 'DECISION -- re-price it and write it.')
end

return tests

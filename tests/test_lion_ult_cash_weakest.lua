-- [hero] `lionultcash` -- the "团战对最弱的敌人" exit of Lion's X.ConsiderR is
-- unreachable as shipped, and the gated widening that opens it.
--
-- ===========================================================================
-- §0  WHAT IS WRONG, IN CLOSED FORM
-- ===========================================================================
--
-- bots/BotLib/hero_lion.lua X.ConsiderR has ten firing points.  Two of them sit
-- thirty lines apart and read the SAME list, `nInBonusEnemyList`
-- (J.GetNearbyHeroes at nCastRange + 400):
--
--   the 击杀 loop      for e in nInBonusEnemyList:
--                         J.IsValidHero(e) and X.CanCastAbilityROnTarget(e)
--                         and J.WillMagicKillTarget(bot, e, nDamage, nCastPoint + 0.25)
--                         -> return HIGH, e
--
--   the 团战 exit      npcWeakestEnemy := argmin GetHealth over
--                         { e in nInBonusEnemyList : J.IsValid(e)
--                                                    and X.CanCastAbilityROnTarget(e) }
--                      if npcWeakestEnemy ~= nil
--                         and J.WillMagicKillTarget(bot, npcWeakestEnemy, nDamage, nCastPoint + 0.25)
--                         -> return HIGH, npcWeakestEnemy
--
-- Same list.  Same nDamage.  Same delay.  Same helper.  Reaching the second
-- test means the first loop found nothing, i.e. NO element of that list
-- satisfies the conjunction -- and npcWeakestEnemy is an element of that list
-- which has already passed X.CanCastAbilityROnTarget.  So its
-- WillMagicKillTarget answer is false by construction.
--
-- The two selectors differ in exactly one predicate, J.IsValidHero vs J.IsValid,
-- and on this list those are the same answer once X.CanCastAbilityROnTarget has
-- passed:
--
--   J.IsValidHero(e) = not IsNull and CanBeSeen and IsAlive
--                      and not IsInvulnerable and IsHero      (utils.lua:547)
--   J.IsValid(e)     = e ~= nil and not IsNull and CanBeSeen
--                      and IsAlive and not IsBuilding         (jmz_func.lua:3295)
--
-- X.CanCastAbilityROnTarget -> J.CanCastOnNonMagicImmune already demands
-- CanBeSeen and not IsInvulnerable; J.GetNearbyHeroes returns heroes, so IsHero
-- holds and IsBuilding does not.  Both reduce to `not IsNull and IsAlive`.
--
-- ⇒ THE SHIPPED 团战 EXIT CANNOT RETURN.  §2 proves that by driving, not by
-- reading: it enumerates the ENTIRE lethality cube over the frame's roster.
--
-- What that costs: the comment above the block says "[ultcash / freehunt#1] a
-- DYING lion cashes the finger out even at ult level 1".  That describes
-- something this exit has never done.  The `or J.IsDyingUnderAttack( bot )`
-- disjunct buys entry to the BLOCK, whose only reachable exit is the scepter
-- AoE branch below it.
--
-- ===========================================================================
-- §0.1  THE READING (both legs, one real frame, exhaustive over lethality)
-- ===========================================================================
--
-- Frame tests/fixtures/f_222428_lion_lich_burst.lua, Lion subject, two enemy
-- heroes really in range: lich 701 hp at 676.4u, axe 629 hp at 740.9u,
-- nCastRange 900.  The weakest is AXE.  Actions recorded off the real
-- X.SkillsComplement dispatch:
--
--     lethal target | gate off (shipped)      | gate on (armed)
--     --------------+-------------------------+------------------------
--     nobody        | NO CAST                 | finger -> axe   <- the lever
--     lich          | finger -> lich  (击杀)   | finger -> lich  (identical)
--     axe           | finger -> axe   (击杀)   | finger -> axe   (identical)
--
-- Three of three: gate-off is byte-for-byte shipped; armed differs on exactly
-- the one point shipped declines, and where both fire the TARGET IS THE SAME.
-- The first column is also the unreachability proof -- there is no assignment
-- of lethality answers over this roster under which the shipped 团战 exit fires.
--
-- ===========================================================================
-- §0.2  REPRODUCE
-- ===========================================================================
--
--     lua5.1 tests/run_tests.lua lion_ult_cash_weakest
--     bash tools/agent/luacheck_gate.sh
--
-- ===========================================================================
-- §0.3  LIMITS -- load-bearing, quote these with any number above
-- ===========================================================================
--
-- 1. THE ARCHIVE CANNOT CORROBORATE THIS LEVER, and §1 is that statement's
--    evidence rather than an aside.  Measured over tests/fixtures/ +
--    tests/frames/, 2026-09-07:
--
--        live-Lion instants ................................ 27
--        ... Finger of Death fully castable ................  5
--        ... and Lion below the block's own `nHP < 0.4` ....  0   <- the domain
--
--    The five that reach X.ConsiderR's body sit at HP 1.000, 1.000, 0.967,
--    0.927 and 0.838 -- the closest is more than twice the threshold.
--    The second armed conjunct fares no better, though for a different reason
--    worth keeping straight: WasRecentlyDamagedByAnyHero(2.0) IS answered by
--    the archive -- 5 of the 27 instants say true -- but NONE of those five is
--    one of the five with a castable Finger, so the conjunction is empty.
--    "the loader has no answer" and "the answer is there and never co-occurs"
--    are different limits, and only the second one is true here; §1 counts them
--    separately so a later round cannot collapse them.  And
--    of the castable five, the only one whose block opens
--    unaided -- tests/frames/f_20260831_004433_cm_creepreach.lua, where
--    J.IsInTeamFight(bot, 600) is genuinely true -- has an EMPTY enemy list at
--    nCastRange + 400, so npcWeakestEnemy is nil and neither leg can fire.
--    ⚠️ An earlier draft of this limit said "zero archive frames reach the
--    body".  That was wrong by five, and it was wrong because the first scan
--    only looked at the three frames whose SUBJECT is Lion; §1 enumerates every
--    frame in which Lion is present as any unit.  The assertion in §1 is what
--    caught it.
-- 2. THREE LABELLED INJECTIONS therefore stand in for what the archive does not
--    supply, and they are named here so nobody quotes §0.1 as an archive
--    reading: Finger rank 2 / cooldown 0 / IsFullyCastable (limit 1), the
--    subject's GetHealth lowered to 300 of 823 = 0.365 so the block's own
--    `nHP < 0.4` entry opens (the real frame is 0.430, just outside), and
--    WasRecentlyDamagedByAnyHero true (this frame's own answer is false; see
--    the co-occurrence zero in limit 1).  §3 asserts each injection was
--    actually read on the frame before any reading is taken from it.
-- 3. GEOMETRY AND ROSTER ARE REAL AND UNTOUCHED: both enemies' health,
--    positions, distances and modifiers come from the .dem.  No health was
--    fabricated to make a target un-killable; §2 moves the LETHALITY ORACLE
--    instead, which is what makes the enumeration exhaustive.
-- 4. WHETHER CASHING A NON-LETHAL FINGER IS WORTH ITS COOLDOWN IS NOT SETTLED
--    HERE.  This file settles that the shipped exit cannot fire and that the
--    armed leg is a strict superset with the same target.  The value question
--    is a wave reading (queue request hero-43).

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')

local SRC    = 'bots/BotLib/hero_lion.lua'
local CAND   = 'lionultcash'
local HELPER = 'lion_ShouldCashUltAtWeakest'
local UNIT   = 'npc_dota_hero_lion'
local FINGER = 'lion_finger_of_death'
local FRAME  = 'tests/fixtures/f_222428_lion_lich_burst.lua'

local FIXTURE_DIR = 'tests/fixtures'
local STAGED_DIR  = 'tests/frames'

-- The frame's real roster, read off the .dem-generated fixture and re-asserted
-- in §3 so a frame edit cannot slide underneath these names.
local LICH = 'npc_dota_hero_lich'
local AXE  = 'npc_dota_hero_axe'

local tests = {}

local function read_file(path)
    local fh = assert(io.open(path, 'r'), 'cannot open ' .. path)
    local body = fh:read('*a')
    fh:close()
    return body
end

--- Both corpus directories, enumerated -- never a hardcoded list.  An empty
--- enumerator and an empty corpus are the same integer; the assert is the only
--- thing that tells them apart.
local function corpus_paths()
    local out = {}
    for _, dir in ipairs({ FIXTURE_DIR, STAGED_DIR }) do
        local n = 0
        local p = assert(io.popen('ls ' .. dir .. ' 2>/dev/null'))
        for name in p:lines() do
            if name:match('^f_.*%.lua$') then
                out[#out + 1] = dir .. '/' .. name
                n = n + 1
            end
        end
        p:close()
        assert(n > 0, 'corpus directory ' .. dir .. ' yielded no f_*.lua frame')
    end
    table.sort(out)
    return out
end

local function helper_body(src)
    local from = src:find('function%s+X%.' .. HELPER .. '%s*%(')
    assert(from, 'X.' .. HELPER .. ' is not defined in ' .. SRC
        .. ' -- this whole file is about that function')
    local rest = src:sub(from)
    local to = rest:find('\nend')
    assert(to, 'X.' .. HELPER .. ' has no closing end in ' .. SRC)
    return rest:sub(1, to)
end

local function consider_r_body(src)
    local from = src:find('function%s+X%.ConsiderR%s*%(')
    assert(from, 'X.ConsiderR is gone from ' .. SRC)
    local rest = src:sub(from)
    local to = rest:find('\nend\n')
    assert(to, 'X.ConsiderR has no closing end in ' .. SRC)
    return rest:sub(1, to)
end

-- ---------------------------------------------------------------- the stand --

--- Install `v` as the answer to `h:k()` and drop any lazily-cached method, the
--- same two steps rf.record_actions takes.  Setting only the spec entry leaves
--- an already-materialised method in place and the injection silently does not
--- take -- which reads exactly like a lever that does nothing.
local function inject(h, k, v)
    rawget(h, '__spec')[k] = v
    rawset(h, k, nil)
end

--- Drive the REAL X.SkillsComplement dispatch on the real frame, with the
--- candidate armed or not and with the lethality oracle answering true for at
--- most one named unit.  Returns the recorded action log and the world.
local function drive(bArmed, sLethal)
    local J, bot = rf.load(FRAME, UNIT)
    J.IsSoakCandidate = function(id) return bArmed and id == CAND end

    -- INJECTIONS -- see §0.3 limit 2.  Asserted to have taken, in §3.
    inject(bot, 'GetHealth', 300)
    inject(bot, 'WasRecentlyDamagedByAnyHero', true)

    local X = rf.load_hero('lion')
    local hR = bot:GetAbilityByName(FINGER)
    inject(hR, 'GetLevel', 2)
    inject(hR, 'GetCooldownTimeRemaining', 0)
    inject(hR, 'IsFullyCastable', true)

    -- THE ORACLE.  Moving this, rather than moving anybody's health, is what
    -- makes §2 an enumeration of the whole cube instead of one sample of it.
    J.WillMagicKillTarget = function(_, hTarget)
        return sLethal ~= nil and hTarget:GetUnitName() == sLethal
    end

    local log = rf.record_actions(bot)
    X.SkillsComplement()
    return log, J, bot, X
end

--- The finger target the dispatch actually ordered, or nil if it ordered none.
local function fingered(log)
    for _, a in ipairs(log) do
        if a.fn:find('UseAbilityOnEntity') then
            local h = a.args[2]
            if h ~= nil and h.GetUnitName ~= nil then return h:GetUnitName() end
        end
    end
    return nil
end

-- ---------------------------------------------------------------- section 1 --
-- Why the archive cannot answer this. §0.3 limit 1's evidence.

tests['§1 the archive reaches the body 5 times and the domain 0 times'] = function()
    local nLive, nReady, nInDomain, nRecent, nReadyRecent = 0, 0, 0, 0, 0
    local nFiles, nMaxReadyHP = 0, 0
    for _, path in ipairs(corpus_paths()) do
        nFiles = nFiles + 1
        local ok, chunk = pcall(dofile, path)
        if ok and type(chunk) == 'table' then
            local present = false
            for _, u in ipairs(chunk.units or {}) do
                if u.name == UNIT and u.alive ~= false then present = true end
            end
            if present then
                nLive = nLive + 1
                local _, bot = rf.load(path, UNIT)
                if bot:WasRecentlyDamagedByAnyHero(2.0) then nRecent = nRecent + 1 end
                local hR = bot:GetAbilityByName(FINGER)
                if hR ~= nil and (hR:GetLevel() or 0) > 0 and hR:IsFullyCastable() then
                    nReady = nReady + 1
                    if bot:WasRecentlyDamagedByAnyHero(2.0) then
                        nReadyRecent = nReadyRecent + 1
                    end
                    local nMax = bot:GetMaxHealth() or 0
                    local nHP = (nMax > 0) and (bot:GetHealth() / nMax) or 0
                    if nHP > nMaxReadyHP then nMaxReadyHP = nHP end
                    if nHP < 0.4 then nInDomain = nInDomain + 1 end
                end
            end
        end
    end
    assert(nFiles > 0, 'the corpus enumerator returned nothing')
    -- NON-VACUITY first: over an empty set "0 in the domain" is true for free
    -- and this case would stay green whatever the corpus did.
    assert(nLive == 27, nLive .. ' live-Lion instants, was 27 as of 2026-09-07. '
        .. 'The corpus moved -- re-take §0.3 limit 1 rather than re-baselining it.')
    assert(nReady == 5, nReady .. ' of them have Finger of Death fully castable, '
        .. 'was 5.  That count is §0.3 limit 1\'s middle line.')
    assert(nInDomain == 0, nInDomain .. ' archive instants are inside this lever\'s '
        .. 'domain (Finger castable AND HP < 0.4), was 0.  THIS IS GOOD NEWS: the '
        .. 'lever can now be measured on a real frame.  Go take that reading and '
        .. 'rewrite §0.3 limit 1 -- do not relax this assertion.')
    assert(nMaxReadyHP > 0.4, 'the castable instants are no longer all above the '
        .. 'threshold; re-read the census')
    -- The archive DOES carry damage-recency -- on 5 of the 27 -- and none of
    -- those five is one of the five with a castable Finger.  The two counts
    -- are kept apart on purpose: "the loader has no answer" and "the answer is
    -- there but never co-occurs" are different limits, and only the second is
    -- true here.
    assert(nRecent == 5, nRecent .. ' archive instants answer '
        .. 'WasRecentlyDamagedByAnyHero(2.0), was 5')
    assert(nReadyRecent == 0, nReadyRecent .. ' archive instants have BOTH a '
        .. 'castable Finger and recent hero damage, was 0.  That zero is why the '
        .. 'second armed conjunct is injected in §3 rather than observed.')
end

-- ---------------------------------------------------------------- section 2 --
-- The shipped 团战 exit is unreachable -- driven, over the whole lethality cube.

tests['§2 shipped: whenever anybody is lethal the 击杀 loop returns first'] = function()
    for _, sLethal in ipairs({ LICH, AXE }) do
        local log = drive(false, sLethal)
        assert(fingered(log) == sLethal, 'gate off, oracle lethal on ' .. sLethal
            .. ': the dispatch fingered ' .. tostring(fingered(log))
            .. '.  The 击杀 loop is what must answer here, and it returns the '
            .. 'FIRST lethal element of nInBonusEnemyList.')
    end
end

tests['§2 shipped: with nobody lethal the block opens and still casts nothing'] = function()
    local log, _, bot, X = drive(false, nil)
    assert(fingered(log) == nil, 'gate off with no lethal target: the dispatch '
        .. 'fingered ' .. tostring(fingered(log)) .. '.  Shipped has no exit here.')
    -- The block really did OPEN -- otherwise "no cast" would be proving that
    -- the entry condition is shut, not that the exit is unreachable.
    assert(bot:GetHealth() / bot:GetMaxHealth() < 0.4,
        'the injected HP no longer opens the block\'s `nHP < 0.4` half; §2 would '
        .. 'then be measuring the entry condition, not the exit')
    local hR = bot:GetAbilityByName(FINGER)
    assert(hR:GetLevel() >= 2, 'the injected Finger rank no longer satisfies the '
        .. 'block\'s `nSkillLV >= 2` disjunct')
    assert(hR:IsFullyCastable(), 'X.ConsiderR returns at its first line; nothing '
        .. 'below it ran and §2 proves nothing')
    -- And the weakest really is a castable member of the same list, so the
    -- selector had a candidate to hand the (unreachable) exit.
    local nWeakest, hWeakest = nil, nil
    for _, e in ipairs(bot:GetNearbyHeroes(1300, true, BOT_MODE_NONE)) do
        if X.CanCastAbilityROnTarget(e) and (nWeakest == nil or e:GetHealth() < nWeakest) then
            nWeakest, hWeakest = e:GetHealth(), e:GetUnitName()
        end
    end
    assert(hWeakest == AXE, 'the weakest castable enemy on this frame is '
        .. tostring(hWeakest) .. ', was ' .. AXE .. ' at 629 hp')
end

-- ---------------------------------------------------------------- section 3 --
-- Gate-off equivalence, the armed leg, and the injections having taken.

tests['§3 the three injections were really read on this frame'] = function()
    local _, _, bot = drive(false, nil)
    assert(bot:GetHealth() == 300, 'the GetHealth injection did not take (got '
        .. tostring(bot:GetHealth()) .. ') -- every reading in this file would '
        .. 'then be about the untouched 354/823 frame')
    assert(bot:WasRecentlyDamagedByAnyHero(2.0) == true,
        'the damage-recency injection did not take')
    local hR = bot:GetAbilityByName(FINGER)
    assert(hR:GetLevel() == 2 and hR:GetCooldownTimeRemaining() == 0
        and hR:IsFullyCastable() == true, 'the Finger injections did not take')
    -- The roster this file names is the roster on the frame.
    local seen = {}
    for _, e in ipairs(bot:GetNearbyHeroes(1300, true, BOT_MODE_NONE)) do
        seen[e:GetUnitName()] = e:GetHealth()
    end
    assert(seen[LICH] == 701 and seen[AXE] == 629,
        'the frame\'s roster moved: lich=' .. tostring(seen[LICH]) .. ' axe='
        .. tostring(seen[AXE]) .. ', was 701 / 629.  Re-take §0.1.')
end

tests['§3 armed is a strict superset, same target where both fire'] = function()
    local nDiff = 0
    for _, sLethal in ipairs({ LICH, AXE }) do
        local shipped = fingered(drive(false, sLethal))
        local armed   = fingered(drive(true,  sLethal))
        assert(shipped ~= nil, 'gate off should fire on a lethal ' .. sLethal)
        assert(armed == shipped, 'arming MOVED the target on the lethal-'
            .. sLethal .. ' point: ' .. tostring(shipped) .. ' -> ' .. tostring(armed)
            .. '.  This lever may only ADD casts, never move one.')
    end
    local shipped = fingered(drive(false, nil))
    local armed   = fingered(drive(true,  nil))
    assert(shipped == nil, 'gate off now fires with nobody lethal; §2 is stale')
    assert(armed == AXE, 'armed fingered ' .. tostring(armed) .. ' with nobody '
        .. 'lethal, was ' .. AXE .. ' (the weakest castable enemy in range)')
    nDiff = 1
    assert(nDiff == 1, 'the armed leg must differ on exactly the one point '
        .. 'shipped declines')
end

-- ---------------------------------------------------------------- section 4 --
-- Each armed conjunct is load-bearing.  Drop one, the lever stops firing.

tests['§4 drop-one: every armed conjunct is load-bearing'] = function()
    local J, bot = rf.load(FRAME, UNIT)
    J.IsSoakCandidate = function(id) return id == CAND end
    inject(bot, 'WasRecentlyDamagedByAnyHero', true)
    local X = rf.load_hero('lion')
    local tEnemies = bot:GetNearbyHeroes(1300, true, BOT_MODE_NONE)
    local hAxe = nil
    for _, e in ipairs(tEnemies) do if e:GetUnitName() == AXE then hAxe = e end end
    assert(hAxe ~= nil, 'the frame no longer carries ' .. AXE)

    -- all conjuncts satisfied -> fires
    assert(X[HELPER](bot, hAxe, 900, 0.365, false) == true,
        'the armed leg refuses a case with every conjunct satisfied')
    -- HP at or above the block's own 0.4 -> refuses
    assert(X[HELPER](bot, hAxe, 900, 0.400, false) == false,
        'the HP conjunct is not load-bearing at exactly 0.4')
    assert(X[HELPER](bot, hAxe, 900, 0.700, false) == false,
        'the HP conjunct is not load-bearing')
    -- target beyond cast range -> refuses (axe is at 740.9u)
    assert(X[HELPER](bot, hAxe, 700, 0.365, false) == false,
        'the reach conjunct is not load-bearing: axe is 740.9u away and the '
        .. 'lever accepted it at nCastRange 700, which is a WALK order')
    -- not being hit -> refuses
    inject(bot, 'WasRecentlyDamagedByAnyHero', false)
    assert(X[HELPER](bot, hAxe, 900, 0.365, false) == false,
        'the damage-recency conjunct is not load-bearing')
    -- gate off -> shipped answer, verbatim, on every one of the above
    J.IsSoakCandidate = function() return false end
    inject(bot, 'WasRecentlyDamagedByAnyHero', true)
    assert(X[HELPER](bot, hAxe, 900, 0.365, false) == false,
        'gate off must return the shipped answer')
    assert(X[HELPER](bot, hAxe, 900, 0.365, true) == true,
        'gate off must return the shipped answer')
    -- And non-turbo, armed, is still shipped.  J.IsModeTurbo is overridden on
    -- the module table rather than via GetGameMode: jmz_func.lua:10890 caches
    -- the answer in a module-local the first time anything asks, and `require`
    -- keeps that module alive for the whole process -- so by this line the
    -- cache is already warm and moving GetGameMode would change nothing while
    -- LOOKING like it had (the failure shape this comment exists to stop).
    J.IsSoakCandidate = function(id) return id == CAND end
    local fTurbo = J.IsModeTurbo
    J.IsModeTurbo = function() return false end
    assert(J.IsModeTurbo() == false, 'the non-turbo override did not take')
    assert(X[HELPER](bot, hAxe, 900, 0.365, false) == false,
        'the lever fired outside turbo')
    J.IsModeTurbo = fTurbo
    assert(X[HELPER](bot, hAxe, 900, 0.365, false) == true,
        'restoring turbo did not restore the lever; the case above proved nothing')
end

-- ---------------------------------------------------------------- section 5 --
-- Shape, pinned on the source.  These stop the lever turning into something
-- else without a round noticing.

tests['§5 shape: WIDENING by construction -- shipped first, short-circuits true'] = function()
    local body = helper_body(read_file(SRC))
    assert(body:find('if%s+bShippedLethal%s+then%s+return%s+true%s+end'),
        'the true short-circuit is gone.  Without it the armed detour is reachable '
        .. 'for targets shipped ACCEPTS, which is how a widening lever silently '
        .. 'becomes a narrowing one.')
    local iShort = body:find('if%s+bShippedLethal%s+then%s+return%s+true%s+end')
    local iGate  = body:find('J%.IsSoakCandidate%(')
    assert(iGate and iShort < iGate, 'the gate is consulted before the shipped '
        .. 'answer short-circuits; the superset argument dies')
    assert(body:find('return%s+false') == nil,
        'a bare `return false` appeared in the body.  For a WIDENING lever that is '
        .. 'the forbidden direction -- every refusal must hand back bShippedLethal, '
        .. 'so gate-off equivalence is a structure and not a claim.')
    local nBail = 0
    for _ in body:gmatch('return%s+bShippedLethal') do nBail = nBail + 1 end
    assert(nBail >= 5, 'only ' .. nBail .. ' of the armed bail-outs return '
        .. 'bShippedLethal, was 5 -- one of them now invents an answer')
end

tests['§5 shape: turbo-only and STANDALONE (the pullcad trap)'] = function()
    local body = helper_body(read_file(SRC))
    assert(body:find("J%.IsModeTurbo%(%)%s*and%s*J%.IsSoakCandidate%(%s*'" .. CAND .. "'%s*%)"),
        'the gate is no longer `IsModeTurbo() and IsSoakCandidate(\'' .. CAND
        .. '\')`.  If it was PROMOTED, this file has to be re-read, not edited green.')
    local n = 0
    for _ in body:gmatch('IsSoakCandidate%(') do n = n + 1 end
    assert(n == 1, 'the body makes ' .. n .. ' IsSoakCandidate calls, was 1 -- a '
        .. 'second candidate id conjoined here is the pullcad trap.  In particular '
        .. 'do NOT reach for J.IsDyingUnderAttack: it is gated on \'ultcash\'.')
    assert(body:find('IsDyingUnderAttack') == nil,
        'the body calls J.IsDyingUnderAttack, which is itself gated on \'ultcash\' '
        .. '-- that is the pullcad trap wearing a helper name')
    local nTree = 0
    local p = assert(io.popen('grep -rl "' .. CAND .. '" bots 2>/dev/null'))
    for _ in p:lines() do nTree = nTree + 1 end
    p:close()
    assert(nTree == 1, CAND .. ' appears in ' .. nTree .. ' files under bots/, was 1')
end

tests['§5 shape: wired at the 团战 exit, and the other exits untouched'] = function()
    local body = consider_r_body(read_file(SRC))
    assert(body:find('X%.' .. HELPER .. '%(%s*bot,%s*npcWeakestEnemy,%s*nCastRange,%s*nHP,'),
        'the 团战 exit no longer calls X.' .. HELPER
        .. '( bot, npcWeakestEnemy, nCastRange, nHP, ... ) -- the lever is defined '
        .. 'but not wired, which reads as "tested, no effect"')
    -- nHP is PASSED, not re-derived: J.GetHP(bot) reads OriginalGetHealth for a
    -- unit on the bot's own team and is a different number from the block's nHP.
    local hbody = helper_body(read_file(SRC))
    assert(hbody:find('J%.GetHP%(') == nil,
        'the helper re-derives HP with J.GetHP instead of taking the block\'s own '
        .. '`nHP`.  For an ally J.GetHP reads OriginalGetHealth()/OriginalGetMaxHealth() '
        .. '(jmz_func.lua:4079) -- the two 0.4 tests would then disagree.')
    -- The 击杀 loop above it still asks the same question, unchanged.  That
    -- identity IS the unreachability argument, so it is anchored on the 击杀
    -- loop specifically rather than counted across the function: X.ConsiderR
    -- has THREE `nCastPoint + 0.25` call sites (击杀, 团战, 打架), and a count
    -- with slack in it survives the one mutation that matters -- moving the
    -- 击杀 loop's delay alone (mutstand_lionultcash.sh M10, which is exactly
    -- how this assertion came to be written this way).
    local iKill = body:find("J%.WillMagicKillTarget%(%s*bot,%s*npcEnemy,%s*nDamage,%s*nCastPoint%s*%+%s*0%.25%s*%)")
    assert(iKill, 'the 击杀 loop no longer asks '
        .. 'J.WillMagicKillTarget( bot, npcEnemy, nDamage, nCastPoint + 0.25 ). '
        .. '§0\'s closed form rests on the 击杀 loop and the 团战 exit asking the '
        .. 'IDENTICAL question; if one of them moved, re-derive it before trusting '
        .. 'any reading in this file.')
    local iWeak = body:find("J%.WillMagicKillTarget%(%s*bot,%s*npcWeakestEnemy,%s*nDamage%s*,%s*nCastPoint%s*%+%s*0%.25%s*%)")
    assert(iWeak and iKill < iWeak, 'the 团战 exit no longer asks the same '
        .. 'question AFTER the 击杀 loop; the unreachability argument needs both '
        .. 'the identity and the order.')
    -- The retreat exit still reads nInRangeEnemyList, not the bonus list.
    assert(body:find('R死前大'), 'the 撤退 exit vanished from X.ConsiderR')
end

return tests

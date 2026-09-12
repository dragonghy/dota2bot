-- [hero] `zusarcimm` -- X.ConsiderQ's retreat firing point picks the target of
-- a MAGICAL spell with a selector that screens for ATTACK immunity only, and
-- the gated narrowing that stops it.
--
-- ===========================================================================
-- §0  WHAT IS WRONG
-- ===========================================================================
--
-- bots/BotLib/hero_zuus.lua X.ConsiderQ elects the target of Arc Lightning
-- through two different helpers, eleven lines apart, for the same ability:
--
--     retreat     J.GetVulnerableWeakestUnit( bot, true, true, nCastRange )
--     fight/push  J.GetVulnerableUnitNearLoc( bot, ..., locationAoE.targetloc )
--
-- The second carries `J.CanCastOnNonMagicImmune( u )` inside its own loop.  The
-- first delegates to J.GetAttackableWeakestUnitFromList, whose filter is the
-- ATTACK-immunity family -- IsAttackImmune, IsInvulnerable, HasForbiddenModifier,
-- IsSuspiciousIllusion -- and which never asks about SPELL immunity.
--
-- That helper is not the defect.  Its name says `Attackable`, and it is shared
-- tree-wide by branches that queue an ATTACK, where the attack-immunity family
-- is exactly the right question.  The defect is at the CALL SITE: its answer is
-- handed to a unit-targeted magical spell that does not pierce spell immunity,
-- so an armed BKB in the pool is selected and the cast is 85-100 mana and a
-- 1.6s cooldown for nothing -- spent on the frame Zeus is retreating and can
-- least afford a wasted one.
--
-- ⛔ SCOPE.  Do NOT repair this by adding a spell term to
-- J.GetAttackableWeakestUnitFromList: §1.2 below counts its other readers, and
-- most of them are attack decisions for which the shipped filter is correct.
--
-- ===========================================================================
-- §0.1  THE READING (one real frame, the real selector, one injection)
-- ===========================================================================
--
-- tests/frames/f_260909_215227_zeus_exec_od_1467.lua, Zeus the subject:
--
--     obsidian_destroyer  389u away, 590 hp, carrying
--                         modifier_black_king_bar_immune on the frame itself
--     J.GetVulnerableWeakestUnit  elects exactly that unit -- the candidate is
--                         not chosen by this test, it is what the shipped
--                         selector returns
--     J.CanCastOnTargetAdvanced( od )  answers TRUE
--
-- so every remaining shipped conjunct on that frame passes and the only thing
-- that would have refused the cast is the term this branch does not have.
--
--     leg      | X.zuus_IsArcTargetSpellVulnerable( od )
--     ---------+----------------------------------------
--     gate off | true    (the shipped answer, byte for byte)
--     armed    | FALSE   <- the lever
--
-- ===========================================================================
-- §0.2  WHAT THIS FILE CANNOT SHOW, stated rather than papered
-- ===========================================================================
--
--   1. `J.IsRetreating( bot )` is a mode predicate and reads FALSE on every
--      fixture frame (GH #474).  So the archive cannot show the BRANCH firing;
--      what §2 and §3 measure is the SELECTOR's answer, which is the half this
--      lever changes.  §4 asserts that limit so it cannot quietly go stale.
--   2. tests/mock/replay_fixture.lua does NOT connect `IsMagicImmune()` to the
--      modifier list it already carries: on the loader's own reading that BKB'd
--      obsidian destroyer is not immune, and this lever is a no-op offline.
--      §5 asserts that gap directly -- the day the loader is repaired, §5 goes
--      RED and names itself, and the injection in this file can be retired.
--      Until then the one injection here is GROUND TRUTH read off the frame's
--      own modifier list, not a number this test invented.
--   3. 1 domain frame is a DOMAIN, not a frequency.  Nothing here says how
--      often a retreating Zeus faces a BKB; sizing that needs a wave.
--
-- Run:  lua5.1 tests/run_tests.lua zuus_arc_retreat_immunity

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')

local SRC        = 'bots/BotLib/hero_zuus.lua'
local JMZ        = 'bots/FunLib/jmz_func.lua'
local FRAME      = 'tests/frames/f_260909_215227_zeus_exec_od_1467.lua'
local FIXTURE_DIR = 'tests/fixtures'
local STAGED_DIR  = 'tests/frames'
local UNIT       = 'npc_dota_hero_zuus'
local OD         = 'npc_dota_hero_obsidian_destroyer'
local CAND       = 'zusarcimm'
local HELPER     = 'zuus_IsArcTargetSpellVulnerable'

--- The spell-immunity modifiers this corpus actually exhibits, plus the
--- canonical BKB one.  NOT a complete list of Dota's spell-immunity sources --
--- it is the ground-truth reader §2/§3 need while limit 2 above holds.
local IMMUNE_MODS = {
    'modifier_black_king_bar_immune',
    'modifier_juggernaut_blade_fury',
    'modifier_life_stealer_rage',
    'modifier_omniknight_repel',
}

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

--- Spell immunity read off the frame's own modifier list.  Returns the modifier
--- name, so a reading can say WHICH one rather than just "immune".
local function immune_mod(h)
    for _, m in ipairs(IMMUNE_MODS) do
        if h:HasModifier(m) then return m end
    end
    return nil
end

--- Install `v` as the answer to `h:k()` and drop any lazily-cached method --
--- setting only the spec entry leaves an already-materialised method in place
--- and the injection silently does not take, which reads exactly like a lever
--- that does nothing.
local function inject(h, k, v)
    rawget(h, '__spec')[k] = v
    rawset(h, k, nil)
end

--- Connect IsMagicImmune to the frame's own modifier list, for every hero on
--- the frame.  Returns how many units it moved, so a caller can assert the
--- injection was not vacuous.
local function connect_immunity(heroes)
    local n = 0
    for _, h in pairs(heroes) do
        if immune_mod(h) ~= nil then
            inject(h, 'IsMagicImmune', true)
            n = n + 1
        end
    end
    return n
end

local function function_body(src, sName)
    local from = src:find('\nfunction%s+' .. sName .. '%s*%(')
    assert(from, sName .. ' is gone from the source this test reads')
    local rest = src:sub(from + 1)
    local to = rest:find('\nend\n')
    assert(to, sName .. ' has no closing end')
    return rest:sub(1, to)
end

--- Load the named frame with Zeus as subject and arm (or not) the candidate.
local function frame(bArmed)
    local J, bot, heroes = rf.load(FRAME, UNIT)
    J.IsSoakCandidate = function(id) return bArmed and id == CAND end
    local X = rf.load_hero('zuus')
    return J, bot, X, heroes
end

local function enemy_handle(bot, sName)
    for _, e in ipairs(bot:GetNearbyHeroes(1600, true, BOT_MODE_NONE)) do
        if e:GetUnitName() == sName then return e end
    end
    return nil
end

-- ---------------------------------------------------------------- section 1 --
-- The asymmetry, counted out of the sources rather than asserted in prose.

tests['§1.1 the two sibling selectors really differ on the spell question'] = function()
    local src = read_file(JMZ)
    local near = function_body(src, 'J%.GetVulnerableUnitNearLoc')
    local weak = function_body(src, 'J%.GetAttackableWeakestUnitFromList')

    assert(near:find('CanCastOnNonMagicImmune', 1, true),
        'J.GetVulnerableUnitNearLoc no longer asks the spell question.  The '
        .. 'asymmetry this lever is built on is gone -- re-read §0 before '
        .. 'keeping the gate.')
    assert(not weak:find('MagicImmune', 1, true),
        'J.GetAttackableWeakestUnitFromList now carries a spell-immunity term.  '
        .. 'If a round repaired it tree-wide, this call-site lever is redundant '
        .. '-- retire `' .. CAND .. '` rather than keeping two answers.')
    -- the attack-immunity family IS there: the helper is not careless, it is
    -- answering a different question.
    assert(weak:find('IsAttackImmune', 1, true) and weak:find('IsInvulnerable', 1, true),
        'J.GetAttackableWeakestUnitFromList lost its attack-immunity filter; §0 '
        .. 'calls that filter correct-for-attacks and rests on it.')
end

tests['§1.2 the shared helper still has readers this lever must not disturb'] = function()
    local n = 0
    local p = assert(io.popen(
        'grep -rl "GetAttackableWeakestUnitFromList" bots/ 2>/dev/null'))
    for _ in p:lines() do n = n + 1 end
    p:close()
    assert(n >= 2, 'J.GetAttackableWeakestUnitFromList is read in ' .. n
        .. ' file(s).  §0 refuses a tree-wide repair because the helper is '
        .. 'SHARED; if it no longer is, that argument has to be re-made.')
end

-- ---------------------------------------------------------------- section 2 --
-- The domain, counted over the whole corpus.

tests['§2 the corpus still holds a frame where the selector elects a BKB'] = function()
    local nLive, nTrained, nPicked, nImmRing, nImmPicked = 0, 0, 0, 0, 0
    local tHits = {}
    for _, path in ipairs(corpus_paths()) do
        local ok, res = pcall(function()
            local a, b, c = rf.load(path, UNIT)
            return { a, b, c }
        end)
        if ok and res[2] ~= nil and res[2]:GetUnitName() == UNIT and res[2]:IsAlive() then
            local J, bot, heroes = res[1], res[2], res[3]
            nLive = nLive + 1
            connect_immunity(heroes)
            local hQ = bot:GetAbilityByName('zuus_arc_lightning')
            if hQ ~= nil and hQ:GetLevel() > 0 then
                nTrained = nTrained + 1
                local nCastRange = hQ:GetCastRange()
                for _, e in pairs(J.GetNearbyHeroes(bot, nCastRange, true, BOT_MODE_NONE)) do
                    if immune_mod(e) ~= nil then nImmRing = nImmRing + 1 break end
                end
                local t = J.GetVulnerableWeakestUnit(bot, true, true, nCastRange)
                if t ~= nil then
                    nPicked = nPicked + 1
                    if immune_mod(t) ~= nil then
                        nImmPicked = nImmPicked + 1
                        tHits[#tHits + 1] = path
                    end
                end
            end
        end
    end

    assert(nLive > 0 and nTrained > 0,
        'the corpus no longer carries a live Zeus with Arc Lightning trained; '
        .. 'every reading in this file is about that population')
    assert(nPicked > 0,
        'J.GetVulnerableWeakestUnit returns nil on every Zeus frame in the '
        .. 'corpus (' .. nTrained .. ' with Arc trained).  The selector this '
        .. 'lever narrows answers nothing -- the domain is gone, not merely small.')
    assert(nImmPicked >= 1,
        'no corpus frame has the retreat selector electing a spell-immune unit '
        .. 'any more (' .. nPicked .. ' picks, ' .. nImmRing .. ' frames with an '
        .. 'immune enemy in range).  The domain went to zero: re-measure before '
        .. 'quoting §0.1, and do not promote on a reading this file can no '
        .. 'longer take.')
    local bNamed = false
    for _, p in ipairs(tHits) do if p == FRAME then bNamed = true end end
    assert(bNamed, 'the named frame ' .. FRAME .. ' is no longer one of the '
        .. nImmPicked .. ' domain frame(s); §0.1 quotes it by name')
end

-- ---------------------------------------------------------------- section 3 --
-- The one real frame: every OTHER shipped conjunct passes on it.

tests['§3 on the real frame the shipped chain has nothing left to refuse with'] = function()
    local J, bot, _, heroes = frame(false)
    assert(connect_immunity(heroes) >= 1,
        'nothing on ' .. FRAME .. ' carries a spell-immunity modifier any more; '
        .. 'the injection is vacuous and §0.1 is stale')
    local hQ = bot:GetAbilityByName('zuus_arc_lightning')
    local t = J.GetVulnerableWeakestUnit(bot, true, true, hQ:GetCastRange())
    assert(t ~= nil and t:GetUnitName() == OD,
        'the shipped selector no longer elects ' .. OD .. ' on ' .. FRAME
        .. ' -- §0.1 reads its candidate off this call, not off a handle the '
        .. 'test picked')
    assert(immune_mod(t) == 'modifier_black_king_bar_immune',
        'the elected candidate is no longer the BKB carrier')
    assert(J.CanCastOnTargetAdvanced(t) == true,
        'J.CanCastOnTargetAdvanced now refuses that target by itself.  Then the '
        .. 'branch was never going to cast and this lever has no work to do on '
        .. 'this frame -- find another before quoting §0.1.')
end

tests['§3 gate off admits the BKB; armed refuses it'] = function()
    local _, bot, X, heroes = frame(false)
    connect_immunity(heroes)
    local hOD = enemy_handle(bot, OD)
    assert(hOD ~= nil, OD .. ' is not on ' .. FRAME .. ' any more')
    assert(X[HELPER](hOD) == true,
        'gate off must be the shipped answer (true) even for a spell-immune '
        .. 'target -- an unarmed tree has to be byte-equivalent to what shipped')

    local _, bot2, X2, heroes2 = frame(true)
    connect_immunity(heroes2)
    local hOD2 = enemy_handle(bot2, OD)
    assert(X2[HELPER](hOD2) == false,
        'armed, the lever did NOT refuse a spell-immune Arc Lightning target -- '
        .. 'it is wired to nothing')
end

--- The no-collateral reading, and it is taken on the population the helper is
--- ACTUALLY called on: whatever the shipped selector returns, frame by frame.
--- `J.CanCastOnNonMagicImmune` asks four things (CanBeSeen, magic immunity,
--- invulnerability, illusion/forbidden modifier) and the selector's own filter
--- already answers three of them, so the claim worth pinning is not "the helper
--- is that call" but "over the corpus it differs from the shipped `true` on
--- exactly the spell-immune picks and on nothing else".
tests['§3 corpus-wide, armed refuses the immune picks and only those'] = function()
    local nPicked, nRefused, nImmune = 0, 0, 0
    for _, path in ipairs(corpus_paths()) do
        local ok, res = pcall(function()
            local a, b, c = rf.load(path, UNIT)
            return { a, b, c }
        end)
        if ok and res[2] ~= nil and res[2]:GetUnitName() == UNIT and res[2]:IsAlive() then
            local J, bot, heroes = res[1], res[2], res[3]
            connect_immunity(heroes)
            J.IsSoakCandidate = function(id) return id == CAND end
            local X = rf.load_hero('zuus')
            local hQ = bot:GetAbilityByName('zuus_arc_lightning')
            if hQ ~= nil and hQ:GetLevel() > 0 then
                local t = J.GetVulnerableWeakestUnit(bot, true, true, hQ:GetCastRange())
                if t ~= nil then
                    nPicked = nPicked + 1
                    local bImm = immune_mod(t) ~= nil
                    if bImm then nImmune = nImmune + 1 end
                    local bArmed = X[HELPER](t)
                    if not bArmed then nRefused = nRefused + 1 end
                    assert(bArmed == (not bImm),
                        'armed answer for ' .. t:GetUnitName() .. ' on ' .. path
                        .. ' is ' .. tostring(bArmed) .. ', but its spell immunity '
                        .. 'is ' .. tostring(bImm) .. '.  The lever is refusing (or '
                        .. 'admitting) a pick for some reason OTHER than spell '
                        .. 'immunity -- that is a wider lever than §0 describes.')
                end
            end
        end
    end
    assert(nPicked > 0, 'the selector returns nil everywhere; nothing was compared')
    assert(nRefused == nImmune and nImmune >= 1,
        'armed refused ' .. nRefused .. ' of ' .. nPicked .. ' picks against '
        .. nImmune .. ' spell-immune ones')
end

-- ---------------------------------------------------------------- section 4 --
-- Inertness and wiring.

tests['§4 armed does nothing outside turbo'] = function()
    local J, bot, X, heroes = frame(true)
    connect_immunity(heroes)
    J.IsModeTurbo = function() return false end
    local hOD = enemy_handle(bot, OD)
    assert(X[HELPER](hOD) == true,
        'the lever fired outside turbo -- every soak candidate in this tree is '
        .. 'turbo-only and this one would ship into normal games')
end

tests['§4 the helper names exactly one id, and it is this one'] = function()
    local body = function_body(read_file(SRC), 'X%.' .. HELPER)
    local n = 0
    for _ in body:gmatch("IsSoakCandidate%s*%(%s*'") do n = n + 1 end
    assert(n == 1, 'X.' .. HELPER .. ' names ' .. n .. ' soak ids, was 1.  A gate '
        .. 'that names a sibling freezes FALSE the day the sibling is promoted '
        .. '(the `pullcad` trap) and check_armed_wiring.py still calls it WIRED.')
    assert(body:find("'" .. CAND .. "'", 1, true),
        'X.' .. HELPER .. ' no longer names ' .. CAND)
end

tests['§4 the retreat branch really routes through the helper, once'] = function()
    local body = function_body(read_file(SRC), 'X%.ConsiderQ')
    -- The paren is load-bearing: the helper is also NAMED in the prose above
    -- its definition, and a bare-name count would read that as a call site.
    local n = 0
    for _ in body:gmatch('X%.' .. HELPER .. '%s*%(') do n = n + 1 end
    assert(n == 1, 'X.' .. HELPER .. ' has ' .. n .. ' call sites in X.ConsiderQ, '
        .. 'was 1.  A second site is a different firing point with a different '
        .. 'domain; give it its own id and its own frame.')
    assert(body:find('GetVulnerableWeakestUnit', 1, true),
        'X.ConsiderQ no longer calls J.GetVulnerableWeakestUnit -- the selector '
        .. 'this lever guards is gone and every reading above is vacuous')
end

tests['§4 the mode predicate is still the offline limit -- §0.2 limit 1'] = function()
    local J, bot = frame(false)
    assert(J.IsRetreating(bot) == false,
        'J.IsRetreating answers TRUE on a fixture frame now.  Then the BRANCH '
        .. 'is drivable offline and §0.2 limit 1 is stale -- take the stronger '
        .. 'reading (drive X.ConsiderQ end to end) instead of the selector one.')
end

-- ---------------------------------------------------------------- section 5 --
-- The loader gap this file works around.  It is asserted, not described, so the
-- day it is repaired this test names itself instead of going quietly stale.

tests['§5 the loader still does not connect IsMagicImmune -- §0.2 limit 2'] = function()
    local _, bot, _, heroes = frame(false)
    local hOD = enemy_handle(bot, OD)
    assert(hOD ~= nil, OD .. ' is not on ' .. FRAME .. ' any more')
    assert(hOD:HasModifier('modifier_black_king_bar_immune'),
        'the frame no longer carries the BKB modifier it was cut for')
    if hOD:IsMagicImmune() then
        error('tests/mock/replay_fixture.lua now connects IsMagicImmune to the '
            .. 'modifier list.  GOOD -- this is the repair §0.2 limit 2 asks '
            .. 'for.  Retire connect_immunity() from this file and re-take the '
            .. '§2 funnel on the loader\'s own reading; then delete this test.')
    end
    -- and the consequence, stated as a reading rather than left implicit: the
    -- shipped guard that exists to stop exactly this is silently satisfied.
    local J = select(1, frame(false))
    assert(J.CanCastOnNonMagicImmune(hOD) == true,
        'J.CanCastOnNonMagicImmune already refuses the BKB carrier without the '
        .. 'injection -- then the loader gap is closed by some other route and '
        .. 'the line above should have caught it')
end

return tests

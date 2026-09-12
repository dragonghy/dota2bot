-- [hero] `zusboltimm` -- X.ConsiderW's retreat firing point elects the target
-- of a MAGICAL spell with a selector that screens for ATTACK immunity only.
-- The SECOND of the three call sites `zusarcimm` scoped itself away from.
--
-- ===========================================================================
-- §0  WHAT IS WRONG
-- ===========================================================================
--
-- bots/BotLib/hero_zuus.lua has THREE readers of the same selector:
--
--     X.ConsiderQ   retreat branch      -- repaired by `zusarcimm`
--     X.ConsiderW   retreat branch      -- THIS FILE
--     X.ConsiderW2  kill-AoE branch     -- deliberately left alone (§0.3)
--
-- J.GetVulnerableWeakestUnit delegates to J.GetAttackableWeakestUnitFromList,
-- whose filter is the ATTACK-immunity family -- IsAttackImmune, IsInvulnerable,
-- HasForbiddenModifier, IsSuspiciousIllusion -- and which never asks about
-- SPELL immunity.  The shipped X.ConsiderW retreat branch then asks only
-- J.CanCastOnTargetAdvanced, which answers TRUE for a spell-immune hero (§3),
-- so nothing behind the missing term refuses the cast either.
--
-- ⛔ SCOPE.  Do NOT repair this by adding a spell term to
-- J.GetAttackableWeakestUnitFromList: §1.2 counts its other readers, and most
-- of them are attack decisions for which the shipped filter is correct.
--
-- ===========================================================================
-- §0.1  WHY A SECOND ID RATHER THAN WIDENING `zusarcimm`
-- ===========================================================================
--
-- The price of the identical mistake is not the identical number.  From
-- odota/dotaconstants build/abilities.json (read 2026-09-12, the same source
-- the `axecull` / `axecallbkb` blocks anchor on):
--
--     zuus_arc_lightning    bkbpierce No   Magical   cd 1.6   mana  85-100
--     zuus_lightning_bolt   bkbpierce No   Magical   cd 6     mana 120-135
--
-- ~1.4x the mana and 3.75x the cooldown, spent on the frame Zeus is running.
-- Two ids also keep the two waves separable; one id would make either reading
-- a blend of two firing points.  §1.3 pins the two-id discipline.
--
-- ===========================================================================
-- §0.2  THE READING (real corpus, real selector, one injection)
-- ===========================================================================
--
--     60 live-Zeus instants -> 56 with Lightning Bolt trained
--  -> 16 on which THIS ring's selector returns any target at all
--  ->  2 that hold a spell-immune enemy inside Lightning Bolt's cast range
--  ->  1 on which the selector RETURNS that spell-immune enemy:
--        tests/frames/f_260909_215227_zeus_exec_od_1467.lua -- obsidian
--        destroyer, modifier_black_king_bar_immune, 388.7u, 590 hp, inside
--        that frame's own 850u bolt range, J.CanCastOnTargetAdvanced TRUE.
--
--     leg      | X.zuus_IsBoltTargetSpellVulnerable( od )
--     ---------+----------------------------------------
--     gate off | true    (the shipped answer, byte for byte)
--     armed    | FALSE   <- the lever
--
-- ⚠️ SAME FRAME AS `zusarcimm`, DIFFERENT FUNNEL.  The rings differ (Arc's cast
-- range vs Bolt's 700/750/800/850, which is why "picked" is 16 here against
-- Arc's 15) and the trained counts differ (56 vs 57).  The corpus holds ONE
-- instant in which a retreating Zeus faces an armed BKB and BOTH spells would
-- be thrown at it.  The pair is NOT two independent sightings; §2 asserts the
-- funnel this lever's own ring produces rather than reusing Arc's numbers.
--
-- ===========================================================================
-- §0.3  WHAT THIS LEVER IS NOT
-- ===========================================================================
--
--   * It does not touch X.ConsiderW2:  that branch casts on a LOCATION, where
--     a spell-immune aim point still delivers damage to everyone else in the
--     325u ring.  Refusing there needs a splash reading nobody has taken.
--   * It does not re-rank.  Armed DECLINES; it does not walk to the
--     next-weakest.  That would ADD casts (opposite direction).
--   * It exempts the t25 world.  X.SkillsComplement dispatches this bid as a
--     ground cast when talent7 (AoE Lightning Bolt, +325) is trained, and the
--     argument above stops holding there.  §4 pins that carve-out.
--
-- ===========================================================================
-- §0.4  WHAT THIS FILE CANNOT SHOW, stated rather than papered
-- ===========================================================================
--
--   1. `J.IsRetreating( bot )` is a mode predicate and reads FALSE on every
--      fixture frame (GH #474).  The archive cannot show the BRANCH firing;
--      §2/§3 measure the SELECTOR's answer, which is the half this lever
--      changes.  §4 asserts that limit so it cannot quietly go stale.
--   2. tests/mock/replay_fixture.lua does NOT connect `IsMagicImmune()` to the
--      modifier list it already carries (GH #769): on the loader's own reading
--      that BKB'd obsidian destroyer is not immune and this lever is a no-op
--      offline.  §5 asserts that gap directly -- the day the loader is
--      repaired, §5 goes RED and names itself.  Until then the one injection
--      here is GROUND TRUTH read off the frame's own modifier list.
--   3. 1 domain frame is a DOMAIN, not a frequency.  Sizing needs a wave
--      (iterations/queue.json hero-65).
--
-- Run:  lua5.1 tests/run_tests.lua zuus_bolt_retreat_immunity

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')

local SRC         = 'bots/BotLib/hero_zuus.lua'
local JMZ         = 'bots/FunLib/jmz_func.lua'
local FRAME       = 'tests/frames/f_260909_215227_zeus_exec_od_1467.lua'
local FIXTURE_DIR = 'tests/fixtures'
local STAGED_DIR  = 'tests/frames'
local UNIT        = 'npc_dota_hero_zuus'
local OD          = 'npc_dota_hero_obsidian_destroyer'
local BOLT        = 'zuus_lightning_bolt'
local CAND        = 'zusboltimm'
local SIBLING     = 'zusarcimm'
local HELPER      = 'zuus_IsBoltTargetSpellVulnerable'

--- The spell-immunity modifiers this corpus actually exhibits, plus the
--- canonical BKB one.  NOT a complete list of Dota's spell-immunity sources --
--- it is the ground-truth reader §2/§3 need while §0.4 limit 2 holds.
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

--- The bolt ring this branch actually uses, read off the frame rather than
--- hardcoded: X.ConsiderW builds it as GetCastRange() + AetherReach().  The
--- aether term is 0 on every corpus frame (no lens in any inventory), and §2
--- does not depend on that -- it only needs the SAME ring the branch reads.
local function bolt_ring(bot)
    local h = bot:GetAbilityByName(BOLT)
    if h == nil or h:GetLevel() <= 0 then return nil end
    return h:GetCastRange()
end

-- ---------------------------------------------------------------- section 1 --
-- The asymmetry and the scope, counted out of the sources rather than asserted.

tests['§1.1 the selector this branch reads still asks no spell question'] = function()
    local src = read_file(JMZ)
    local weak = function_body(src, 'J%.GetAttackableWeakestUnitFromList')

    assert(not weak:find('MagicImmune', 1, true),
        'J.GetAttackableWeakestUnitFromList now carries a spell-immunity term.  '
        .. 'If a round repaired it tree-wide, this call-site lever is redundant '
        .. '-- retire `' .. CAND .. '` rather than keeping two answers.')
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

tests['§1.3 the three call sites are still three, and hold two distinct ids'] = function()
    local src = read_file(SRC)
    -- CODE lines only.  Both `zusarcimm`'s header and this lever's quote the
    -- selector by name in prose, so a whole-file gmatch reads 5 and the number
    -- this section is about is 3.  Comment lines are dropped rather than the
    -- pattern tightened: a doc line can carry a paren too.
    local n = 0
    for line in (src .. '\n'):gmatch('([^\n]*)\n') do
        if not line:match('^%s*%-%-')
            and line:find('J.GetVulnerableWeakestUnit(', 1, true)
        then
            n = n + 1
        end
    end
    assert(n == 3, 'hero_zuus.lua now has ' .. n .. ' J.GetVulnerableWeakestUnit '
        .. 'call sites, was 3 (ConsiderQ retreat / ConsiderW retreat / '
        .. 'ConsiderW2 kill-AoE).  §0 enumerates them by name and §0.3 argues '
        .. 'about the third one specifically -- re-read it before adding a site.')
    assert(src:find("'" .. SIBLING .. "'", 1, true),
        SIBLING .. ' is gone from this file.  If it was promoted, the ConsiderQ '
        .. 'site now ships the guard by default and this file should say so; if '
        .. 'it was rejected, re-read §0.1 before keeping ' .. CAND .. '.')
    assert(src:find("'" .. CAND .. "'", 1, true), CAND .. ' is gone from this file')
end

-- ---------------------------------------------------------------- section 2 --
-- The domain, counted over the whole corpus on THIS branch's own ring.

tests['§2 the corpus still holds a frame where the bolt selector elects a BKB'] = function()
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
            local nRing = bolt_ring(bot)
            if nRing ~= nil then
                nTrained = nTrained + 1
                for _, e in pairs(J.GetNearbyHeroes(bot, nRing, true, BOT_MODE_NONE)) do
                    if immune_mod(e) ~= nil then nImmRing = nImmRing + 1 break end
                end
                local t = J.GetVulnerableWeakestUnit(bot, true, true, nRing)
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
        'the corpus no longer carries a live Zeus with Lightning Bolt trained; '
        .. 'every reading in this file is about that population')
    assert(nPicked > 0,
        'J.GetVulnerableWeakestUnit returns nil on every Zeus frame at the bolt '
        .. 'ring (' .. nTrained .. ' with Bolt trained).  The selector this lever '
        .. 'narrows answers nothing -- the domain is gone, not merely small.')
    assert(nImmPicked >= 1,
        'no corpus frame has the bolt retreat selector electing a spell-immune '
        .. 'unit any more (' .. nPicked .. ' picks, ' .. nImmRing .. ' frames with '
        .. 'an immune enemy in the bolt ring).  The domain went to zero: '
        .. 're-measure before quoting §0.2, and do not promote on a reading this '
        .. 'file can no longer take.')
    local bNamed = false
    for _, p in ipairs(tHits) do if p == FRAME then bNamed = true end end
    assert(bNamed, 'the named frame ' .. FRAME .. ' is no longer one of the '
        .. nImmPicked .. ' domain frame(s); §0.2 quotes it by name')
end

-- ---------------------------------------------------------------- section 3 --
-- The one real frame: every OTHER shipped conjunct passes on it.

tests['§3 on the real frame the shipped chain has nothing left to refuse with'] = function()
    local J, bot, _, heroes = frame(false)
    assert(connect_immunity(heroes) >= 1,
        'nothing on ' .. FRAME .. ' carries a spell-immunity modifier any more; '
        .. 'the injection is vacuous and §0.2 is stale')
    local nRing = bolt_ring(bot)
    assert(nRing ~= nil, 'Lightning Bolt is no longer trained on ' .. FRAME)
    local t = J.GetVulnerableWeakestUnit(bot, true, true, nRing)
    assert(t ~= nil and t:GetUnitName() == OD,
        'the shipped selector no longer elects ' .. OD .. ' at the bolt ring on '
        .. FRAME .. ' -- §0.2 reads its candidate off this call, not off a '
        .. 'handle the test picked')
    assert(immune_mod(t) == 'modifier_black_king_bar_immune',
        'the elected candidate is no longer the BKB carrier')
    assert(J.CanCastOnTargetAdvanced(t) == true,
        'J.CanCastOnTargetAdvanced now refuses that target by itself.  Then the '
        .. 'branch was never going to cast and this lever has no work to do on '
        .. 'this frame -- find another before quoting §0.2.')
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
        'armed, the lever did NOT refuse a spell-immune Lightning Bolt target '
        .. '-- it is wired to nothing')
end

--- Taken on the population the helper is ACTUALLY called on: whatever the
--- shipped selector returns at the bolt ring, frame by frame.  The claim worth
--- pinning is not "the helper is that call" but "over the corpus it differs
--- from the shipped `true` on exactly the spell-immune picks and nothing else".
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
            local nRing = bolt_ring(bot)
            if nRing ~= nil then
                local t = J.GetVulnerableWeakestUnit(bot, true, true, nRing)
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
-- Inertness, the t25 carve-out, and wiring.

tests['§4 armed does nothing outside turbo'] = function()
    local J, bot, X, heroes = frame(true)
    connect_immunity(heroes)
    J.IsModeTurbo = function() return false end
    local hOD = enemy_handle(bot, OD)
    assert(X[HELPER](hOD) == true,
        'the lever fired outside turbo -- every soak candidate in this tree is '
        .. 'turbo-only and this one would ship into normal games')
end

tests['§4 the t25 ground-cast world is exempt -- §0.3'] = function()
    local J, bot, X, heroes = frame(true)
    connect_immunity(heroes)
    local hOD = enemy_handle(bot, OD)
    assert(X[HELPER](hOD) == false,
        'precondition: armed must refuse before the talent is trained, or the '
        .. 'carve-out below proves nothing')

    -- X.SkillsComplement dispatches this bid as ActionQueue_UseAbilityOnLocation
    -- once talent7 is trained, and a spell-immune AIM POINT still delivers the
    -- 325u splash to everyone else.  Drive the real handle rather than the
    -- helper's belief about it.
    local src = read_file(SRC)
    assert(src:find('talent7:IsTrained()', 1, true)
        and src:find('ActionQueue_UseAbilityOnLocation( abilityW', 1, true),
        'X.SkillsComplement no longer swaps this bid to a LOCATION cast on '
        .. 'talent7.  Then the carve-out inside X.' .. HELPER .. ' guards a '
        .. 'world that does not exist -- delete it and re-take §0.3.')

    -- Drive the REAL handle the hero file bound, not the helper's belief about
    -- it: sTalentList[7] is what hero_zuus.lua hands GetAbilityByName, and the
    -- loader answers the same table for the same name, so training it here is
    -- training the same `talent7` the helper reads.  The before/after pair is
    -- the proof of identity -- an injection that missed would leave `false`.
    local sT7 = J.Skill.GetTalentList(bot)[7]
    local hT7 = bot:GetAbilityByName(sT7)
    assert(hT7 ~= nil, 'the loader no longer answers a handle for talent slot 7')
    assert(hT7:IsTrained() == false, 'talent7 is already trained on ' .. FRAME
        .. '; the carve-out cannot be shown to flip anything here')
    inject(hT7, 'IsTrained', true)
    assert(X[HELPER](hOD) == true,
        'with talent7 trained the armed leg still refuses a spell-immune aim '
        .. 'point.  That is the ground-cast world, where the 325u splash still '
        .. 'lands on everyone else -- §0.3 says this lever does not claim it.')
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
    assert(not body:find("'" .. SIBLING .. "'", 1, true),
        'X.' .. HELPER .. ' now names ' .. SIBLING .. ' as well.  That is the '
        .. '`pullcad` trap: promoting the sibling freezes this gate FALSE '
        .. 'forever and nothing raises a hand.')
end

tests['§4 the bolt retreat branch really routes through the helper, once'] = function()
    local body = function_body(read_file(SRC), 'X%.ConsiderW')
    -- The paren is load-bearing: the helper is also NAMED in the prose above
    -- its definition, and a bare-name count would read that as a call site.
    local n = 0
    for _ in body:gmatch('X%.' .. HELPER .. '%s*%(') do n = n + 1 end
    assert(n == 1, 'X.' .. HELPER .. ' has ' .. n .. ' call sites in X.ConsiderW, '
        .. 'was 1.  A second site is a different firing point with a different '
        .. 'domain; give it its own id and its own frame.')
    assert(body:find('GetVulnerableWeakestUnit', 1, true),
        'X.ConsiderW no longer calls J.GetVulnerableWeakestUnit -- the selector '
        .. 'this lever guards is gone and every reading above is vacuous')
end

tests['§4 X.ConsiderW2 is still NOT guarded -- §0.3 bullet 1'] = function()
    local body = function_body(read_file(SRC), 'X%.ConsiderW2')
    assert(body:find('GetVulnerableWeakestUnit', 1, true),
        'X.ConsiderW2 no longer reads the selector; §0.3 enumerates it')
    assert(not body:find(HELPER, 1, true),
        'X.' .. HELPER .. ' is now called from X.ConsiderW2 as well.  That '
        .. 'branch casts on a LOCATION, so the argument this lever rests on '
        .. 'does not carry there -- §0.3 bullet 1.  Give it its own id and its '
        .. 'own splash reading.')
end

tests['§4 the mode predicate is still the offline limit -- §0.4 limit 1'] = function()
    local J, bot = frame(false)
    assert(J.IsRetreating(bot) == false,
        'J.IsRetreating answers TRUE on a fixture frame now.  Then the BRANCH '
        .. 'is drivable offline and §0.4 limit 1 is stale -- take the stronger '
        .. 'reading (drive X.ConsiderW end to end) instead of the selector one.')
end

-- ---------------------------------------------------------------- section 5 --
-- The loader gap this file works around.  Asserted, not described, so the day
-- it is repaired this test names itself instead of going quietly stale.

tests['§5 the loader still does not connect IsMagicImmune -- §0.4 limit 2'] = function()
    local J, bot, _, heroes = frame(false)
    local hOD = enemy_handle(bot, OD)
    assert(hOD ~= nil, OD .. ' is not on ' .. FRAME .. ' any more')
    assert(hOD:HasModifier('modifier_black_king_bar_immune'),
        'the frame no longer carries the BKB modifier it was cut for')
    if hOD:IsMagicImmune() then
        error('tests/mock/replay_fixture.lua now connects IsMagicImmune to the '
            .. 'modifier list.  GOOD -- this is the repair §0.4 limit 2 asks '
            .. 'for (GH #769).  Retire connect_immunity() from this file and '
            .. 're-take the §2 funnel on the loader\'s own reading; then delete '
            .. 'this test.')
    end
    assert(J.CanCastOnNonMagicImmune(hOD) == true,
        'J.CanCastOnNonMagicImmune already refuses the BKB carrier without the '
        .. 'injection -- then the loader gap is closed by some other route and '
        .. 'the line above should have caught it')
end

return tests

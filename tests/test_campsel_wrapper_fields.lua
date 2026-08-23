-- GH #137 follow-up: J.Site.GetClosestNeutralSpwan hands its own two filters a
-- value that carries neither of the fields they read. Gated soak candidate
-- 'campsel' (turbo-only) makes them read the camp record instead.
--
-- THE DEFECT (bots/FunLib/aba_site.lua, shipped default)
-- ------------------------------------------------------
-- RefreshCamp emits WRAPPERS: `{ idx = camp.idx, cattr = camp }`. Every other
-- consumer in that file goes through `.cattr` for a camp attribute --
-- GetCampStackTime reads `camp.cattr.speed`, and the two location reads inside
-- GetClosestNeutralSpwan itself read `camp.cattr.location`. Two calls on those
-- same two lines do not:
--
--     if IsEnemyCamp(camp) then dist = dist * 1.5 end                 -- .team
--     ... and (bot:GetLevel() >= 10 or not IsAncientCamp(camp))       -- .type
--
-- The wrapper has no `.team` and no `.type`. So:
--
--   * IsEnemyCamp(wrapper) is `nil ~= GetTeam()` => TRUE for EVERY camp. The
--     1.5x is therefore applied uniformly, and a uniform factor cannot change
--     an argmin: the enemy-jungle penalty this line exists to apply does not
--     exist. What does survive is its side effect -- the 15000 cut-off two
--     lines down is scaled to an effective 10000, for own-side camps too.
--   * IsAncientCamp(wrapper) is `nil == "ancient"` => FALSE for EVERY camp, so
--     `bot:GetLevel() >= 10 or not IsAncientCamp(camp)` is TRUE at every
--     level. The level-10 ancient gate is dead code.
--
-- The second one is the other half of GH #137 §2's "6 of 40 ancient-camp
-- engagements happen at level <= 9 -- not even GetClosestNeutralSpwan's own
-- `>= 10` stopped it (the list comes from RefreshCamp, and RefreshCamp stops
-- nobody)". The list half is real and is what 'campgrade' fixes. But it is not
-- why THIS clause let a level-1 jakiro into an ancient camp at t=77.7: this
-- clause cannot fire at any level, on any list. Two independent gates on the
-- same decision, both dead, for two unrelated reasons.
--
-- THE FIX (one lever, one wrong operand): read `camp.cattr` in those two
-- calls. Armed only, turbo only. The gate is resolved once, at the single
-- wrapper `ClosestCamp` in bots/mode_farm_generic.lua -- see [structure] below,
-- which asserts that no second call site exists to miss it.
--
-- DECLARED CONSEQUENCE -- not a side effect this file hides
-- --------------------------------------------------------
-- Restoring the operand also restores the reach the 15000 literal was written
-- to give. Unarmed, every camp is multiplied by 1.5, so every camp is capped
-- at an effective 10000. Armed, own-side camps regain the full 15000 while
-- enemy-side camps keep the 10000 the 1.5x implies. Own-side reach therefore
-- WIDENS. That is inseparable from the fix -- the multiplier and the cut-off
-- are the same expression -- so it is pinned in both directions below
-- ([declared consequence] and its two bounds) rather than mentioned in prose.
--
-- WHAT THIS FILE CAN AND CANNOT BUY LOCALLY
-- -----------------------------------------
-- The SUBJECT half is real: every bot driven below is a real hero off a real
-- .dem frame carrying the level the game gave it, and level is the only bot
-- operand either predicate reads.
--
-- The CAMP half is not in the corpus and is not pretended to be -- world fact
-- (W1) below. The camp tables here are a DECLARED STAND-IN whose fields are
-- exactly what the two predicates read (`type`, `team`) plus the `location`
-- the distance maths needs. No count in this file is claimed to be corpus data.
-- The distances, however, are not arbitrary: each is placed to straddle a
-- threshold that the source states as a literal (1.5, 15000, 10).

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')

local tests = {}

-- Real frames straddling the `>= 10` threshold with real levels. Level 1 is
-- the population GH #137 §2 measured 6 times in 40 games (its own worst case
-- is a level-1 jakiro in an ancient camp at 1:17); level 9 is the top of that
-- bucket; level 10 is the first level the clause was written to admit.
local L1  = { 'tests/fixtures/f_011405_jak_rescue_axe.lua',            'npc_dota_hero_axe' }
local L9  = { 'tests/fixtures/f_045650_lion_meatgrinder.lua',          'npc_dota_hero_earthshaker' }
local L10 = { 'tests/fixtures/f_260820_043124_axe_blink_flee_555.lua', 'npc_dota_hero_skeleton_king' }

local function subject(spec)
    local J, _, heroes = rf.load(spec[1], spec[2])
    local bot = heroes[spec[2]]
    assert(bot ~= nil, 'fixture no longer carries ' .. spec[2] .. ' -- ' .. spec[1])
    return J, bot
end

-- A camp entry in exactly the shape RefreshCamp emits, placed `dist` away from
-- the bot's real position (split over x and y so the distance is the hypotenuse).
local function entry(bot, idx, sType, nTeam, dist)
    local loc = bot:GetLocation()
    local d = dist / math.sqrt(2)
    return { idx = idx, cattr = { idx = idx, type = sType, team = nTeam,
                                  location = Vector(loc.x + d, loc.y + d, 0) } }
end

local function own(bot) return bot:GetTeam() end
local function foe(bot) return bot:GetTeam() == 2 and 3 or 2 end

local function pick(J, bot, list, bArmed)
    local got = J.Site.GetClosestNeutralSpwan(bot, list, bArmed)
    return got and got.idx or nil
end

-- The 4x2 (type, side) stand-in RefreshCamp reads, used only where the test is
-- about RefreshCamp's OUTPUT SHAPE rather than about selection.
local function with_camps(nOwnTeam, fn)
    local camps, i = {}, 0
    for _, team in ipairs({ nOwnTeam, nOwnTeam == 2 and 3 or 2 }) do
        for _, sType in ipairs({ 'small', 'medium', 'large', 'ancient' }) do
            i = i + 1
            camps['c' .. i] = { idx = i, type = sType, team = team,
                                location = Vector(100 * i, 100 * i, 0) }
        end
    end
    local prev = GetNeutralSpawners
    GetNeutralSpawners = function() return camps end -- luacheck: ignore
    local ok, err = pcall(fn, i)
    GetNeutralSpawners = prev -- luacheck: ignore
    if not ok then error(err, 0) end
end

--============================================================================
-- The three world facts this file rests on.
--============================================================================

tests['[world W1] the corpus carries no neutral spawners at all'] = function()
    local J, bot = subject(L10)
    local camps = GetNeutralSpawners()
    assert(type(camps) == 'table' and next(camps) == nil,
        'GetNeutralSpawners() is no longer empty on a fixture -- if the dumper ' ..
        'started carrying the spawner table, this file should drive the real one ' ..
        'and every claim below gets stronger')
    local _, n = J.Site.RefreshCamp(bot)
    assert(n == 0, 'with no camps in the world the shipped entry point returns an ' ..
        'empty list -- that is why the camp tables here are declared, not loaded')
end

tests['[world W2] the wrapper RefreshCamp emits carries neither .team nor .type'] = function()
    -- The root cause, read off the real producer rather than described. If a
    -- future RefreshCamp starts copying the fields onto the wrapper, this test
    -- is how you find out that the fix below became a no-op.
    local J, bot = subject(L10)
    local nSeen = 0
    with_camps(own(bot), function(nTotal)
        local list = J.Site.RefreshCamp(bot, false)
        assert(#list == nTotal, 'the unarmed ladder still admits every camp')
        for _, e in ipairs(list) do
            nSeen = nSeen + 1
            assert(e.team == nil, 'the wrapper gained a .team field')
            assert(e.type == nil, 'the wrapper gained a .type field')
            assert(e.cattr ~= nil and e.cattr.team ~= nil and e.cattr.type ~= nil,
                'the record under .cattr must still carry both fields')
        end
    end)
    assert(nSeen == 8, 'expected the 4x2 stand-in, saw ' .. nSeen)
end

tests['[world W3] the teammate filter never disqualifies anything locally'] = function()
    -- IsTheClosestOne is the third condition on the selection line. It only
    -- disqualifies a camp when another team member is BOTH closer to it AND in
    -- farm mode. Nothing in the mock reads BOT_MODE_FARM, so it answers TRUE
    -- for every camp here -- which is what lets every number below be read as a
    -- statement about the two predicates and nothing else. Both halves are
    -- asserted: the count of farming members, and the answer itself.
    local J, bot = subject(L10)
    local nFarming = 0
    for _, id in ipairs(GetTeamPlayers(GetTeam())) do
        local m = GetTeamMember(id)
        if m ~= nil then
            local ok, mode = pcall(function() return m:GetActiveMode() end)
            if ok and mode == BOT_MODE_FARM then nFarming = nFarming + 1 end
        end
    end
    assert(nFarming == 0, 'a team member now reads BOT_MODE_FARM (' .. nFarming ..
        ') -- IsTheClosestOne can start refusing camps and the counts below stop ' ..
        'isolating the two predicates')
    local loc = bot:GetLocation()
    assert(J.Site.IsTheClosestOne(bot, Vector(loc.x + 3000, loc.y + 3000, 0)) == true,
        'IsTheClosestOne no longer answers TRUE unconditionally in the mock')
end

--============================================================================
-- Today's defect, driving the real predicates on the real wrapper.
--============================================================================

tests["[today's defect] IsEnemyCamp is TRUE for every camp, own-side ones included"] = function()
    local J, bot = subject(L10)
    with_camps(own(bot), function()
        local list = J.Site.RefreshCamp(bot, false)
        local nOwnSide, nCalledEnemy = 0, 0
        for _, e in ipairs(list) do
            if e.cattr.team == own(bot) then nOwnSide = nOwnSide + 1 end
            if J.Site.IsEnemyCamp(e) then nCalledEnemy = nCalledEnemy + 1 end
        end
        assert(nOwnSide == 4, 'stand-in changed shape')
        assert(nCalledEnemy == 8, 'the shipped call reads the wrapper: all 8 camps ' ..
            'answer "enemy", got ' .. nCalledEnemy)
        -- and the same predicate on the record is the honest answer
        local nRecordEnemy = 0
        for _, e in ipairs(list) do
            if J.Site.IsEnemyCamp(e.cattr) then nRecordEnemy = nRecordEnemy + 1 end
        end
        assert(nRecordEnemy == 4, 'on the record exactly the 4 enemy-side camps ' ..
            'answer "enemy", got ' .. nRecordEnemy)
    end)
end

tests["[today's defect] IsAncientCamp is FALSE for every camp, ancient ones included"] = function()
    local J, bot = subject(L10)
    with_camps(own(bot), function()
        local list = J.Site.RefreshCamp(bot, false)
        local nAncientRecords, nCalledAncient = 0, 0
        for _, e in ipairs(list) do
            if e.cattr.type == 'ancient' then nAncientRecords = nAncientRecords + 1 end
            if J.Site.IsAncientCamp(e) then nCalledAncient = nCalledAncient + 1 end
        end
        assert(nAncientRecords == 2, 'stand-in changed shape')
        assert(nCalledAncient == 0, 'the shipped call reads the wrapper: no camp ' ..
            'answers "ancient", got ' .. nCalledAncient)
    end)
end

tests["[today's defect] a level-1 hero is handed an ancient camp"] = function()
    -- GH #137 §2's own worst case, reproduced at the selection line: the list
    -- is not the reason this happens. Even a list containing exactly one camp,
    -- and that camp ancient, is accepted at level 1.
    local J, bot = subject(L1)
    assert(bot:GetLevel() == 1, 'frame no longer carries level 1')
    local list = { entry(bot, 1, 'ancient', own(bot), 1000) }
    assert(pick(J, bot, list, false) == 1,
        'the `>= 10` clause cannot fire -- this is the defect, not a passing test')
end

tests["[today's defect] the enemy-jungle penalty does not exist"] = function()
    -- Own camp at 1000, enemy camp at 800. With the 1.5x applied to BOTH
    -- (1500 vs 1200) the enemy camp wins -- i.e. the penalty line changes
    -- nothing, and the bot walks into the enemy jungle to farm.
    local J, bot = subject(L10)
    local list = { entry(bot, 1, 'small', own(bot), 1000),
                   entry(bot, 2, 'small', foe(bot), 800) }
    assert(pick(J, bot, list, false) == 2,
        'shipped default picks the enemy-side camp: a uniform 1.5x is no penalty')
end

--============================================================================
-- The fix.
--============================================================================

tests['[the fix] armed, the level-1 hero is refused the ancient camp'] = function()
    local J, bot = subject(L1)
    local list = { entry(bot, 1, 'ancient', own(bot), 1000) }
    assert(pick(J, bot, list, true) == nil,
        'armed, the `>= 10` clause must refuse an ancient camp at level 1')
end

tests['[the fix] it is a level gate, not a ban: 9 refuses, 10 admits'] = function()
    local J9, b9 = subject(L9)
    assert(b9:GetLevel() == 9, 'frame no longer carries level 9')
    assert(pick(J9, b9, { entry(b9, 1, 'ancient', own(b9), 1000) }, true) == nil,
        'level 9 is below the clause the source states')

    local J10, b10 = subject(L10)
    assert(b10:GetLevel() == 10, 'frame no longer carries level 10')
    assert(pick(J10, b10, { entry(b10, 1, 'ancient', own(b10), 1000) }, true) == 1,
        'level 10 is the first admitted level -- a fix that refused it would be ' ..
        'moving the constant, which is a different lever')
end

tests['[the fix] armed, the low-level hero still gets non-ancient camps'] = function()
    -- The reverse guard on the clause above: refusing ancients must not empty
    -- the selection. A nil return sends mode_farm_generic down its "no camp
    -- found" path, which is a far wider behaviour change than this lever.
    local J, bot = subject(L1)
    local list = { entry(bot, 1, 'ancient', own(bot), 500),
                   entry(bot, 2, 'medium', own(bot), 1400) }
    assert(pick(J, bot, list, true) == 2,
        'the medium camp must still be selectable at level 1')
end

tests['[the fix] armed, the enemy penalty flips the argmin'] = function()
    local J, bot = subject(L10)
    local list = { entry(bot, 1, 'small', own(bot), 1000),
                   entry(bot, 2, 'small', foe(bot), 800) }
    assert(pick(J, bot, list, true) == 1,
        'armed: own 1000 vs enemy 800*1.5=1200 -- the own-side camp wins')
end

tests['[the fix] the penalty is a penalty, not a ban'] = function()
    -- A clearly closer enemy camp still wins. If this ever flips, someone has
    -- turned a 1.5x weighting into an exclusion, which is a second lever.
    local J, bot = subject(L10)
    local list = { entry(bot, 1, 'small', own(bot), 1000),
                   entry(bot, 2, 'small', foe(bot), 500) }
    assert(pick(J, bot, list, true) == 2,
        'armed: enemy 500*1.5=750 still beats own 1000')
end

--============================================================================
-- The declared consequence: own-side reach widens from 10000 to 15000.
--============================================================================

tests['[declared consequence] own-side reach widens to the 15000 the source states'] = function()
    local J, bot = subject(L10)
    local list = { entry(bot, 1, 'small', own(bot), 12000) }
    assert(pick(J, bot, list, false) == nil,
        'unarmed: 12000*1.5 = 18000 is over the 15000 cut-off -- effective reach 10000')
    assert(pick(J, bot, list, true) == 1,
        'armed: 12000 < 15000. This is a WIDENING and it is inseparable from the ' ..
        'fix; the batch read must watch for camp trips getting longer')
end

tests['[declared consequence] the 15000 cut-off itself is untouched'] = function()
    local J, bot = subject(L10)
    local list = { entry(bot, 1, 'small', own(bot), 15500) }
    assert(pick(J, bot, list, true) == nil,
        'armed must not reach past 15000 -- the literal is not part of this lever')
end

tests['[declared consequence] enemy-side reach stays at the 10000 the 1.5x implies'] = function()
    local J, bot = subject(L10)
    local list = { entry(bot, 1, 'small', foe(bot), 12000) }
    assert(pick(J, bot, list, false) == nil, 'unarmed: over the cut-off')
    assert(pick(J, bot, list, true) == nil,
        'armed: 12000*1.5 = 18000 is still over -- the widening is own-side only')
end

--============================================================================
-- Off-candidate equivalence.
--============================================================================

tests['[off-candidate equivalence] unarmed is the pre-fix function, pick for pick'] = function()
    -- The pre-fix body, transcribed verbatim from the shipped source, run
    -- beside the patched one over a battery of layouts on every real level
    -- this file uses. If these disagree the candidate is not dark.
    local function pre_fix(J, bot, availableCampList)
        local minDist = 15000
        local closestCamp = nil
        for _, camp in ipairs(availableCampList) do
            local dist = GetUnitToLocationDistance(bot, camp.cattr.location)
            if J.Site.IsEnemyCamp(camp) then dist = dist * 1.5 end
            if J.Site.IsTheClosestOne(bot, camp.cattr.location) and dist < minDist
                and (bot:GetLevel() >= 10 or not J.Site.IsAncientCamp(camp)) then
                minDist = dist
                closestCamp = camp
            end
        end
        return closestCamp
    end

    local kinds = { 'small', 'medium', 'large', 'ancient' }
    local dists = { 300, 1000, 2500, 7000, 9500, 10500, 14000, 16000 }
    local nCases = 0
    for _, spec in ipairs({ L1, L9, L10 }) do
        local J, bot = subject(spec)
        for _, sType in ipairs(kinds) do
            for _, nTeam in ipairs({ own(bot), foe(bot) }) do
                for _, d in ipairs(dists) do
                    -- alone, and paired against a fixed own-side medium camp
                    local solo = { entry(bot, 1, sType, nTeam, d) }
                    local pair = { entry(bot, 1, sType, nTeam, d),
                                   entry(bot, 2, 'medium', own(bot), 1200) }
                    for _, list in ipairs({ solo, pair }) do
                        nCases = nCases + 1
                        local want = pre_fix(J, bot, list)
                        local gotFalse = J.Site.GetClosestNeutralSpwan(bot, list, false)
                        local gotNil = J.Site.GetClosestNeutralSpwan(bot, list)
                        assert(gotFalse == want, string.format(
                            'unarmed(false) diverged: %s level %d, %s/%s at %d',
                            spec[2], bot:GetLevel(), sType, tostring(nTeam), d))
                        assert(gotNil == want, string.format(
                            'unarmed(no third argument) diverged: %s level %d, %s/%s at %d',
                            spec[2], bot:GetLevel(), sType, tostring(nTeam), d))
                    end
                end
            end
        end
    end
    assert(nCases == 3 * 4 * 2 * 8 * 2, 'battery shrank: ' .. nCases)
end

--============================================================================
-- Structure: the gate, the call-site census, TS parity, one lever.
--============================================================================

local function read(path)
    local f = assert(io.open(path, 'r'))
    local s = f:read('*a')
    f:close()
    return s
end

-- Comment text is not code, and the header above quotes every identifier below.
local function strip_comments(src)
    src = src:gsub('%-%-%[%[.-%]%]', ' ')
    return (src:gsub('%-%-[^\n]*', ' '))
end

tests['[structure] the wrapper owns the gate, turbo-first'] = function()
    local code = strip_comments(read('bots/mode_farm_generic.lua'))
    local call = code:match('J%.Site%.GetClosestNeutralSpwan%s*(%b())')
    assert(call, 'the GetClosestNeutralSpwan call site moved or changed shape')
    local iTurbo = call:find('J%.IsModeTurbo%s*%(%s*%)')
    local iCand = call:find("J%.IsSoakCandidate%s*%(%s*'campsel'%s*%)")
    assert(iTurbo, 'the fix must be turbo-only; got: ' .. call)
    assert(iCand, "the fix must be gated on 'campsel'; got: " .. call)
    -- Both halves: turbo inheritance is structural here (an `and` chain), so
    -- assert the ORDER too. Asserting only that both appear cannot tell
    -- "turbo gates the candidate" from "the candidate gates turbo".
    assert(iTurbo < iCand, 'IsModeTurbo() must be evaluated before the candidate ' ..
        'check, so the candidate id can never arm outside turbo; got: ' .. call)
end

tests['[structure] there is exactly one call site, so none can miss the gate'] = function()
    -- The fix threads a flag. Ten call sites were rewritten onto one wrapper
    -- precisely so this is a count and not a promise: a new caller that goes
    -- straight to J.Site.GetClosestNeutralSpwan would be unarmed and silent.
    local p = assert(io.popen("grep -rl 'GetClosestNeutralSpwan' bots/"))
    local files = {}
    for path in p:lines() do files[#files + 1] = path end
    p:close()
    local nTotal = 0
    for _, path in ipairs(files) do
        if path ~= 'bots/FunLib/aba_site.lua' then
            local _, n = strip_comments(read(path)):gsub('GetClosestNeutralSpwan%s*%(', '')
            nTotal = nTotal + n
        end
    end
    assert(nTotal == 1, 'GetClosestNeutralSpwan is called ' .. nTotal ..
        ' times outside aba_site.lua -- every call must go through ClosestCamp ' ..
        'in bots/mode_farm_generic.lua or it silently runs unarmed')
end

tests['[structure] one lever: campsel does not touch the camp LIST'] = function()
    -- 'campgrade' decides which camps are in the list; 'campsel' decides which
    -- of them is picked. Keeping them apart is what lets a wave read either one
    -- on its own.
    local code = strip_comments(read('bots/FunLib/aba_site.lua'))
    local refresh = code:match('RefreshCamp%s*=%s*function.-\nend')
    assert(refresh, 'RefreshCamp is gone or reshaped')
    assert(not refresh:find('campsel'), "'campsel' reached RefreshCamp -- that is " ..
        "'campgrade' territory and would make the two ids inseparable")
    local sel = code:match('GetClosestNeutralSpwan%s*=%s*function.-\nend')
    assert(sel, 'GetClosestNeutralSpwan is gone or reshaped')
    assert(not sel:find('campgrade'), "'campgrade' reached the selector")
    -- and the fix really is the operand, not a new clause
    assert(sel:find('IsEnemyCamp%s*%(%s*rec%s*%)') and sel:find('IsAncientCamp%s*%(%s*rec%s*%)'),
        'both predicates must read the resolved record')
    assert(sel:find('camp%.cattr%.location'), 'the location reads were already correct ' ..
        'and must stay on the wrapper path')
end

tests['[ts parity] the TypeScript source carries the same operand fix'] = function()
    local ts = read('typescript/bots/FunLib/aba_site.ts')
    ts = ts:gsub('/%*.-%*/', ' '):gsub('//[^\n]*', ' ')
    local sel = ts:match('GetClosestNeutralSpwan%s*=%s*function.-\n};')
    assert(sel, 'the TS selector is gone or reshaped')
    assert(sel:find('bReadCampRecord'), 'the TS selector lost the gate parameter')
    assert(sel:find('IsEnemyCamp%(rec%)') and sel:find('IsAncientCamp%(rec%)'),
        'the TS predicates drifted from the Lua ones')
end

--============================================================================
-- Domain: the population the revived level gate newly bites.
--============================================================================

tests['[domain] most real hero-frames are below the level the clause names'] = function()
    -- Floors, not equalities (GH #106): adding a fixture must not turn this red.
    local p = assert(io.popen('ls tests/fixtures/*.lua'))
    local nFiles, nSlots, nBelow, nAtOrAbove = 0, 0, 0, 0
    for path in p:lines() do
        local ok, fx = pcall(dofile, path)
        if ok and type(fx) == 'table' and fx.units then
            nFiles = nFiles + 1
            for _, u in ipairs(fx.units) do
                if u.level then
                    nSlots = nSlots + 1
                    if u.level < 10 then nBelow = nBelow + 1
                    else nAtOrAbove = nAtOrAbove + 1 end
                end
            end
        end
    end
    p:close()
    assert(nFiles >= 100 and nSlots >= 1000,
        string.format('corpus shrank: %d files / %d hero-slots', nFiles, nSlots))
    assert(nBelow + nAtOrAbove == nSlots, 'the two buckets must close on the total')
    -- Measured 2026-08-24 on 104 fixtures / 1040 hero-slots: 818 below level 10
    -- (78.7%), 222 at or above. This is a FRAME domain and is not comparable to
    -- an episode rate (charter 0DOM): it says how much of the corpus the clause
    -- could speak about, NOT how often a bot picks an ancient camp. The event
    -- rate for that is GH #137 §2's 1.0 ancient engagement per game, 15% of
    -- them at level <= 9, and the two numbers are never to be subtracted.
    assert(nBelow >= 780, 'the sub-10 bucket collapsed: ' .. nBelow)
    assert(nAtOrAbove >= 200, 'the level >= 10 bucket collapsed: ' .. nAtOrAbove ..
        ' -- the population the fix must NOT touch has to exist to be checked')
end

return tests

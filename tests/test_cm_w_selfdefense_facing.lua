-- [hero] `cmwface` -- the heading cone that Crystal Maiden's SELF-DEFENCE
-- Frostbite branch alone carries.
--
-- THE DEFECT, in one line of shipped source (X.ConsiderW, the 保护自己 branch):
--
--     and bot:IsFacingLocation( npcEnemy:GetLocation(), 45 )
--
-- X.ConsiderW has five branches that commit Frostbite -- 击杀 (kill), 打断TP
-- (interrupt a teleport), 团战 (team fight), 保护自己 (self defence) and 对线期
-- 消耗 (lane harass).  Exactly ONE asks where Crystal Maiden happens to be
-- looking, and it is the defensive one: the branch whose premise is
-- `bot:WasRecentlyDamagedByAnyHero( 3.0 )`, i.e. the branch that only opens
-- while a hero is beating on her.
--
-- Frostbite is UNIT-TARGETED, and the engine turns the caster through the cast
-- point for a unit-targeted order -- heading is not a precondition of the cast,
-- which is why no sibling branch treats it as one.  Worse, the guard is
-- ANTI-correlated with its own branch: a support being focused walks away from
-- whoever is focusing her, and heading follows the movement order, so "a hero
-- damaged me in the last 3 seconds" is exactly the state in which she is least
-- likely to be looking at him.
--
-- THE FRAME (§3).  tests/fixtures/f_260820_103216_cm_es_aftershock.lua --
-- tl_103216 @ t=473.5 (7:53).  CM 292/1110 hp (0.26), Frostbite rank 4 off
-- cooldown, 531 of the 155 mana it costs.  TWO enemy heroes inside its real
-- 600u cast range -- earthshaker 196u, zuus 268u -- and BOTH had just dealt her
-- hero damage (earthshaker 331 over the previous 2.5s, zuus 588 over 3.8s).
-- Neither is disabled, neither is disarmed, both pass every other guard on the
-- loop.  The shipped dispatch orders NOTHING.  Ground truth: `died_after = 1`.
--
-- ⚠️⚠️ THE METER, AND THE CLAIM THIS FILE DOES NOT MAKE.  `IsFacingLocation` is
-- NOT answerable from the corpus: make_fixture.py dumps x/y and no heading, the
-- loader installs no spec for it, and the mock's generic Is* default answers
-- FALSE -- at all 317 call sites under bots/, on every fixture.  §6.1 proves
-- that it is a DEFAULT and not a computation by asking for a 360-degree cone,
-- which every possible heading satisfies, and still getting false.
--   So the §3.2 flip is produced by the mock's default, NOT by a recorded
-- heading, and NOTHING here claims that the shipped tree failed to cast in that
-- game.  What the pin buys is that on a real frame every OTHER conjunct of the
-- branch holds at once, with ZERO injections -- no mode, no HP, no movespeed --
-- and that the armed dispatch then orders Frostbite on a named hero who had in
-- fact just been hitting her.  How often the cone actually blocks is a
-- FREQUENCY and needs a wave: iterations/queue.json `hero-53`.
--
-- ⛔ NOT CLAIMED EITHER: that the cone is wrong in the two SIBLING files that
-- carry the identical line (hero_skeleton_king.lua's 受到伤害时保护自己 branch,
-- hero_zuus.lua).  They are not gated here -- one lever at a time -- and §5
-- records the measurement that decided which hero moved this round: the Wraith
-- King branch's corpus domain is EMPTY -- exactly one frame clears its
-- non-geometric conjuncts, and there the nearest enemy hero is 1699u away, i.e.
-- past the 1600u ceiling J.GetNearbyHeroes itself clamps to.

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')

local SRC  = 'bots/BotLib/hero_crystal_maiden.lua'
local CAND = 'cmwface'
local HELPER = 'cm_IsSelfDefenseFacingOk'

local PIN = 'tests/fixtures/f_260820_103216_cm_es_aftershock.lua'
local UNIT = 'npc_dota_hero_crystal_maiden'

-- Every Crystal-Maiden-SUBJECT fixture, listed rather than globbed so a new one
-- is a deliberate edit.  Same list tests/test_cm_r_crowd_release.lua carries.
local CM_FRAMES = {
    'tests/fixtures/f_113638_cm_chain_rescue.lua',
    'tests/fixtures/f_260819_003005_cm_selfpreserve.lua',
    'tests/fixtures/f_260819_004858_cm_centaur_far.lua',
    'tests/fixtures/f_260820_042009_cm_cask_far.lua',
    'tests/fixtures/f_260820_043039_cm_cask_close.lua',
    'tests/fixtures/f_260820_102645_cm_es_reach.lua',
    'tests/fixtures/f_260820_102645_cm_laning_release.lua',
    'tests/fixtures/f_260820_103216_cm_es_aftershock.lua',
    'tests/fixtures/f_260902_154755_cm_wandbleed_residue.lua',
    'tests/fixtures/f_260903_101254_cm_farm_stealcamp.lua',
}

local tests = {}

local function read_file(path)
    local fh = assert(io.open(path, 'r'), 'cannot open ' .. path)
    local body = fh:read('*a')
    fh:close()
    return body
end

--- Comments stripped, so a ratchet counting code shapes cannot be satisfied by
--- prose that merely mentions the expression.
local function strip_comments(s)
    return (s:gsub('%-%-[^\n]*', ''))
end

--- The source of one X.<name> function, comments included.
local function fn_body(src, name)
    local from = src:find('function X%.' .. name .. '%s*%(')
    assert(from, 'X.' .. name .. ' not found in ' .. SRC)
    local rest = src:sub(from)
    local to = rest:find('\nfunction X%.')
    return to and rest:sub(1, to) or rest
end

local function count(hay, needle)
    local n, at = 0, 1
    while true do
        local s, e = hay:find(needle, at, true)
        if not s then return n end
        n, at = n + 1, e + 1
    end
end

--- Drive the REAL X.SkillsComplement dispatch on a real frame.  Returns what it
--- ordered ('<ability>-><unit>' or 'none'), X.ConsiderW's own answer, and the
--- named target.  NOTHING is injected: no mode, no HP, no movespeed, no cooldown.
local function drive(path, opt)
    opt = opt or {}
    local J, bot, heroes, fx = rf.load(path, UNIT)
    J.IsSoakCandidate = function(id)
        return opt.armed == true and id == (opt.cand or CAND)
    end
    if opt.nonTurbo then
        -- rf.load's install() forces turbo; undo it AFTER load, exactly as
        -- tests/test_cm_far_creep_floor.lua does.
        GetGameMode = function() return 1 end
    end
    local X = rf.load_hero('crystal_maiden')
    local log = rf.record_actions(bot)
    -- The file locals (nLV/nHP/nMP/botTarget/aetherRange) are set by
    -- X.SkillsComplement, so the dispatch is the entry point, not X.ConsiderW.
    pcall(X.SkillsComplement)
    local ordered = 'none'
    for _, a in ipairs(log) do
        if a.fn:find('UseAbilityOnEntity') then
            local ab, h = a.args[1], a.args[2]
            local abn = (type(ab) == 'table' and ab.GetName) and ab:GetName() or '?'
            local hn = (h ~= nil and h.GetUnitName) and h:GetUnitName() or '?'
            ordered = abn .. '->' .. hn
        end
    end
    local desire, target = 0, 'nil'
    local ok, a, b = pcall(X.ConsiderW)
    if ok then
        desire = a
        if type(b) == 'table' and b.GetUnitName then target = b:GetUnitName() end
    else
        desire = 'ERR'
    end
    return ordered, desire, target, J, bot, heroes, fx, X
end

--- ---------------------------------------------------------------- section 1 --
--- The defect and the repair, pinned in the source.  These say WHERE the change
--- is, so a later edit that moves the cone back into the branch, or points the
--- gate at a second id, fails here rather than silently.

tests['1.1: the cone left the branch and lives behind the named helper'] = function()
    local src = strip_comments(read_file(SRC))
    local w = fn_body(src, 'ConsiderW')
    assert(count(w, 'IsFacingLocation') == 0,
        'X.ConsiderW still calls IsFacingLocation directly -- the whole lever is '
        .. 'that the self-defence branch reads the cone through X.' .. HELPER)
    assert(count(w, 'X.' .. HELPER .. '( bot, npcEnemy )') == 1,
        'the self-defence branch must consume X.' .. HELPER .. ' exactly once')
end

tests['1.2: the gate is turbo-only, names cmwface, and names NOTHING else'] = function()
    local src = strip_comments(read_file(SRC))
    local h = fn_body(src, HELPER)
    assert(h:find("J.IsModeTurbo()", 1, true), 'the gate must be turbo-only')
    assert(count(h, "J.IsSoakCandidate( '" .. CAND .. "' )") == 1,
        'the helper must name ' .. CAND .. ' exactly once')
    -- The pullcad trap (AGENTS.md): a gate whose condition also names a SIBLING
    -- id freezes FALSE the day that sibling is promoted.  cmlaneband sits three
    -- lines above this helper and cmrcrowd/cmrguard/cmrself/cmrcap live in the
    -- same file, so the trap is close.
    for id in h:gmatch("IsSoakCandidate%(%s*'([%w_]+)'") do
        assert(id == CAND,
            'X.' .. HELPER .. " conjoins a second soak id '" .. id .. "'. That is "
            .. 'the pullcad trap: this gate would freeze FALSE the day that id is '
            .. 'promoted. Express a dependency as a promote-atom, never in code.')
    end
end

tests['1.3: the cone is one named number, read from one place'] = function()
    local src = strip_comments(read_file(SRC))
    local h = fn_body(src, HELPER)
    assert(h:find('X.nWSelfDefenseFacingCone', 1, true),
        'the helper must read the named cone, not a literal')
    assert(not h:find('45', 1, true),
        'a literal 45 is left in X.' .. HELPER .. ' -- the cone has two homes again')
    local J, bot = rf.load(PIN, UNIT)
    J.IsSoakCandidate = function() return false end
    local X = rf.load_hero('crystal_maiden')
    assert(X.nWSelfDefenseFacingCone == 45,
        ('the cone moved off the shipped 45 (now %s). Gate OFF must be the '
         .. 'shipped predicate byte for byte.'):format(tostring(X.nWSelfDefenseFacingCone)))
end

--- ---------------------------------------------------------------- section 2 --
--- Gate semantics, at the helper, with no frame in the way.  A stub bot records
--- what the helper asked it, so "gate off is the shipped call" is a reading and
--- not a claim about the source text.

--- @return hBot, hTarget, tSeen  -- tSeen collects the arguments the helper passed
local function stubs(bFacing)
    local tSeen = { calls = 0 }
    local hTarget = { GetLocation = function() return 'THE-TARGET-LOCATION' end }
    local hBot = {
        IsFacingLocation = function(_, vLoc, nCone)
            tSeen.calls = tSeen.calls + 1
            tSeen.loc, tSeen.cone = vLoc, nCone
            return bFacing
        end,
    }
    return hBot, hTarget, tSeen
end

local function helper_world(opt)
    opt = opt or {}
    local J, bot = rf.load(PIN, UNIT)
    J.IsSoakCandidate = function(id)
        return opt.armed == true and id == (opt.cand or CAND)
    end
    if opt.nonTurbo then GetGameMode = function() return 1 end end
    return rf.load_hero('crystal_maiden')
end

tests['2.1: gate OFF is the shipped call -- same handle, same location, cone 45'] = function()
    local X = helper_world()
    for _, bFacing in ipairs({ true, false }) do
        local hBot, hTarget, tSeen = stubs(bFacing)
        local got = X.cm_IsSelfDefenseFacingOk(hBot, hTarget)
        assert(got == bFacing,
            'gate off must hand back the engine answer unchanged, got '
            .. tostring(got) .. ' for ' .. tostring(bFacing))
        assert(tSeen.calls == 1, 'the engine must be asked exactly once')
        assert(tSeen.loc == 'THE-TARGET-LOCATION',
            'the helper asked about a location that is not the target\'s')
        assert(tSeen.cone == 45, 'the shipped cone is 45, got ' .. tostring(tSeen.cone))
    end
end

tests['2.2: armed in turbo returns true and does not consult the engine'] = function()
    local X = helper_world({ armed = true })
    for _, bFacing in ipairs({ true, false }) do
        local hBot, hTarget, tSeen = stubs(bFacing)
        assert(X.cm_IsSelfDefenseFacingOk(hBot, hTarget) == true,
            'armed, the cone must not be able to refuse (facing=' .. tostring(bFacing) .. ')')
        assert(tSeen.calls == 0,
            'armed, the helper still called IsFacingLocation -- DEAD WIRING: the '
            .. 'lever would be inert whenever the engine happened to answer false')
    end
end

tests['2.3: armed OUTSIDE turbo is the shipped answer, both polarities'] = function()
    local X = helper_world({ armed = true, nonTurbo = true })
    for _, bFacing in ipairs({ true, false }) do
        local hBot, hTarget, tSeen = stubs(bFacing)
        assert(X.cm_IsSelfDefenseFacingOk(hBot, hTarget) == bFacing,
            'outside turbo the armed leg must be the shipped predicate')
        assert(tSeen.calls == 1, 'outside turbo the engine must still be asked')
    end
end

tests['2.4: a DIFFERENT armed id does not open this gate'] = function()
    local X = helper_world({ armed = true, cand = 'cmrcrowd' })
    local hBot, hTarget, tSeen = stubs(false)
    assert(X.cm_IsSelfDefenseFacingOk(hBot, hTarget) == false,
        'the gate opened for an id that is not ' .. CAND)
    assert(tSeen.calls == 1, 'the engine must still be asked')
end

--- ---------------------------------------------------------------- section 3 --
--- The pin frame.  §3.1 MEASURES the premise off the frame rather than asserting
--- it in prose; §3.2 is the flip; §3.4 is the meter that bounds what §3.2 means.

tests['3.1: the pin frame carries the premise, measured not asserted'] = function()
    local _, _, _, J, bot, _, fx = drive(PIN)
    assert(fx.self == UNIT, 'the subject')
    assert(fx.time == 473.5, 'decision instant')
    assert(fx.observed and fx.observed.died_after == 1,
        'ground truth: Crystal Maiden dies 1.0s after this instant')
    assert(bot:GetHealth() == 292 and bot:GetMaxHealth() == 1110, 'CM hp on the real frame')

    local sAbilityList = J.Skill.GetAbilityList(bot)
    assert(sAbilityList[2] == 'crystal_maiden_frostbite', 'W is Frostbite (GH #36)')
    local abilityW = bot:GetAbilityByName(sAbilityList[2])
    assert(abilityW:GetLevel() == 4, 'Frostbite rank 4 on the real frame')
    assert(abilityW:IsFullyCastable(),
        'Frostbite is off cooldown AND affordable on this real frame')
    -- Not an external anchor: the loader serves AbilityCastRange from the KV.
    assert(abilityW:GetCastRange() == 600, 'Frostbite cast range from the KV')
    assert(abilityW:GetManaCost() == 155 and bot:GetMana() == 531, 'the mana term')

    assert(bot:WasRecentlyDamagedByAnyHero(3.0),
        'the branch premise: a hero hit her inside 3s -- real DAMAGE rows')

    local nCastRange = abilityW:GetCastRange() + 30
    local inRange = J.GetNearbyHeroes(bot, nCastRange, true, BOT_MODE_NONE)
    assert(#inRange == 2, ('two enemies inside %du, got %d'):format(nCastRange, #inRange))
    local seen = {}
    for _, e in pairs(inRange) do
        seen[e:GetUnitName()] = GetUnitToUnitDistance(bot, e)
        -- Every OTHER conjunct of the loop, on the real frame.
        assert(J.IsValid(e) and J.CanCastOnNonMagicImmune(e)
               and J.CanCastOnTargetAdvanced(e)
               and not J.IsDisabled(e) and not e:IsDisarmed(),
            e:GetUnitName() .. ' fails a NON-facing guard, so the cone is not the '
            .. 'only thing holding this branch shut and §3.2 means less than it says')
        assert(bot:WasRecentlyDamagedByHero(e, 3.0),
            e:GetUnitName() .. ' is in range but is not one of the heroes who hit '
            .. 'her -- the pin\'s "she froze the hero who was hitting her" reading '
            .. 'depends on this')
    end
    assert(math.abs(seen.npc_dota_hero_earthshaker - 195.94) < 0.01,
        'earthshaker at 195.94u, got ' .. tostring(seen.npc_dota_hero_earthshaker))
    assert(math.abs(seen.npc_dota_hero_zuus - 268.02) < 0.01,
        'zuus at 268.02u, got ' .. tostring(seen.npc_dota_hero_zuus))
end

tests['3.2: shipped orders NOTHING here; armed orders Frostbite on the attacker'] = function()
    local oOff, dOff, tOff = drive(PIN)
    assert(oOff == 'none' and dOff == BOT_ACTION_DESIRE_NONE,
        ('the shipped dispatch was expected to order nothing, got %s (desire %s)')
            :format(oOff, tostring(dOff)))
    assert(tOff == 'nil', 'shipped names no Frostbite target')

    local oOn, dOn, tOn = drive(PIN, { armed = true })
    assert(oOn == 'crystal_maiden_frostbite->npc_dota_hero_earthshaker',
        ('armed, the REAL X.SkillsComplement dispatch must order Frostbite on the '
         .. 'earthshaker who had just dealt her 331 damage; got %s'):format(oOn))
    assert(dOn == BOT_ACTION_DESIRE_HIGH,
        'armed X.ConsiderW must bid HIGH, got ' .. tostring(dOn))
    assert(tOn == 'npc_dota_hero_earthshaker', 'armed names the attacker')
end

tests['3.3: outside Turbo the armed leg is byte-for-byte the shipped bid'] = function()
    local oOff, dOff, tOff = drive(PIN)
    local oNt, dNt, tNt = drive(PIN, { armed = true, nonTurbo = true })
    assert(oOff == oNt and dOff == dNt and tOff == tNt,
        'armed outside turbo diverged from shipped -- the gate is not turbo-only')
end

tests['3.4: the flip is the mock\'s DEFAULT, not a recorded heading'] = function()
    local _, _, _, J, bot = drive(PIN)
    local inRange = J.GetNearbyHeroes(bot, 630, true, BOT_MODE_NONE)
    assert(#inRange == 2, 'the two pinned enemies')
    for _, e in pairs(inRange) do
        assert(bot:IsFacingLocation(e:GetLocation(), 45) == false,
            'IsFacingLocation started answering true. If the dump began carrying '
            .. 'heading, §3.2 is now a REAL reading and this file\'s headline '
            .. 'limit must be rewritten, not deleted.')
    end
end

--- ---------------------------------------------------------------- section 4 --
--- The domain over the whole CM corpus, and the DIRECTION guarantee.
--- §4.1 asserts the changed set by EQUALITY, not by "the pin is in it": a mutant
--- that made the helper return true unconditionally, or that broke a sibling
--- branch, is a superset and must not be able to pass here.

local function domain()
    local changed, checked = {}, 0
    for _, p in ipairs(CM_FRAMES) do
        local oOff, dOff, tOff = drive(p)
        local oOn, dOn, tOn = drive(p, { armed = true })
        checked = checked + 1
        if oOff ~= oOn or dOff ~= dOn or tOff ~= tOn then
            changed[#changed + 1] = p
        end
    end
    return changed, checked
end

tests['4.1: exactly one CM frame changes, and it is the pin (set equality)'] = function()
    assert(#CM_FRAMES == 10,
        'the CM subject corpus changed size; re-measure the domain before quoting it')
    local changed, checked = domain()
    assert(checked == #CM_FRAMES, 'every listed CM fixture was driven')
    assert(#changed == 1 and changed[1] == PIN,
        ('armed changes {%s}; expected exactly {%s}'):format(
            table.concat(changed, ', '), PIN))
end

tests['4.2: the lever can only ADD a cast, never remove or redirect one'] = function()
    local nChecked = 0
    for _, p in ipairs(CM_FRAMES) do
        local oOff, dOff = drive(p)
        local oOn, dOn = drive(p, { armed = true })
        nChecked = nChecked + 1
        if oOff ~= oOn then
            assert(oOff == 'none',
                ('%s: armed REDIRECTED a shipped order (%s -> %s). This lever '
                 .. 'drops one conjunct from one branch; it must only ever turn '
                 .. '"no order" into "an order".'):format(p, oOff, oOn))
            assert(dOff == BOT_ACTION_DESIRE_NONE and dOn == BOT_ACTION_DESIRE_HIGH,
                p .. ': the desire moved in an unexpected direction')
        end
    end
    assert(nChecked == #CM_FRAMES, 'the whole CM corpus was driven')
end

--- ---------------------------------------------------------------- section 5 --
--- The siblings, registered so the next round does not re-derive them -- and the
--- measurement that decided which hero moved this round.

tests['5.1: the identical cone is still live in the two sibling files'] = function()
    local wk = strip_comments(read_file('bots/BotLib/hero_skeleton_king.lua'))
    assert(wk:find('bot:IsFacingLocation( npcEnemy:GetLocation(), 45 )', 1, true),
        'the Wraith King self-defence cone is gone. If it was fixed, say so here '
        .. 'and in bots/BotLib/hero_crystal_maiden.lua\'s cmwface note -- this '
        .. 'file claims the two are the same idiom.')
    local zu = strip_comments(read_file('bots/BotLib/hero_zuus.lua'))
    assert(zu:find('IsFacingLocation', 1, true), 'the Zeus site is gone; see above')
end

tests['5.2: the Wraith King branch has an EMPTY corpus domain (why CM moved)'] = function()
    -- The geometric term is deliberately NOT Hellfire Blast's cast range: 1600 is
    -- the ceiling J.GetNearbyHeroes clamps its own radius to, so a frame that
    -- fails at 1600 cannot put a hero in `nEnemysHerosInRange` for ANY cast
    -- range.  That keeps this reading free of an ability anchor and makes it an
    -- upper bound on the domain rather than an estimate of it.
    local REPORTABLE = 1600
    local p = io.popen('ls tests/fixtures/*.lua 2>/dev/null')
    local nLive, nHit, nNonGeom = 0, 0, 0
    for path in p:lines() do
        local ok, fx = pcall(dofile, path)
        if ok and type(fx) == 'table' and fx.units then
            for _, u in ipairs(fx.units) do
                if u.name == 'npc_dota_hero_skeleton_king' and u.alive then
                    nLive = nLive + 1
                    local q
                    for _, a in ipairs(u.abilities or {}) do
                        if a.name == 'skeleton_king_hellfire_blast' then q = a end
                    end
                    local bHit = false
                    for _, d in ipairs(u.recent_damage or {}) do
                        if d.dt <= 3.0 and d.kind == 'hero' then bHit = true end
                    end
                    if u.level >= 6 and q ~= nil and q.level >= 1 and q.cd <= 0 and bHit
                    then
                        nNonGeom = nNonGeom + 1
                        local nNear = math.huge
                        for _, v in ipairs(fx.units) do
                            if v.team ~= u.team and v.alive
                               and v.name:match('^npc_dota_hero_') then
                                local dx, dy = v.x - u.x, v.y - u.y
                                local d = math.sqrt(dx * dx + dy * dy)
                                if d < nNear then nNear = d end
                            end
                        end
                        if nNear <= REPORTABLE then nHit = nHit + 1 end
                    end
                end
            end
        end
    end
    p:close()
    assert(nLive > 0, 'the corpus lost every live Wraith King frame')
    assert(nNonGeom == 1,
        ('%d Wraith King frame(s) clear the non-geometric conjuncts (level>=6 + '
         .. 'Hellfire Blast ready + hero damage inside 3s); the round that wrote '
         .. 'this measured exactly 1.'):format(nNonGeom))
    assert(nHit == 0,
        ('%d Wraith King frame(s) now ALSO put an enemy hero inside %du. The '
         .. 'branch became pinnable; this round\'s "CM was the only one with a '
         .. 'domain" reason is stale and the sibling deserves its own id.')
            :format(nHit, REPORTABLE))
end

--- ---------------------------------------------------------------- section 6 --
--- Limits, machine-checked so they cannot go quietly stale.

tests['6.1: IsFacingLocation is a DEFAULT -- a 360-degree cone still answers false'] = function()
    local _, _, _, J, bot = drive(PIN)
    local inRange = J.GetNearbyHeroes(bot, 630, true, BOT_MODE_NONE)
    assert(#inRange >= 1, 'at least one enemy to ask about')
    for _, e in pairs(inRange) do
        -- Every possible heading lies inside a 360-degree cone, so an
        -- implementation that computed anything could not answer false here.
        assert(bot:IsFacingLocation(e:GetLocation(), 360) == false,
            'IsFacingLocation now answers a 360-degree cone truthfully, i.e. it is '
            .. 'MODELLED. The headline limit ("the flip is the mock\'s default") '
            .. 'is no longer true and must be rewritten.')
    end
end

tests['6.2: no fixture carries a heading, which is WHY 6.1 holds'] = function()
    local p = io.popen('ls tests/fixtures/*.lua 2>/dev/null')
    local nFiles, nUnits = 0, 0
    for path in p:lines() do
        local ok, fx = pcall(dofile, path)
        if ok and type(fx) == 'table' and fx.units then
            nFiles = nFiles + 1
            for _, u in ipairs(fx.units) do
                nUnits = nUnits + 1
                for _, k in ipairs({ 'facing', 'heading', 'rotation', 'yaw', 'angle' }) do
                    assert(u[k] == nil,
                        ('%s: unit %s now carries a `%s` field. The corpus can '
                         .. 'answer heading; teach the loader and rewrite this '
                         .. 'file\'s headline limit.'):format(path, u.name, k))
                end
            end
        end
    end
    p:close()
    assert(nFiles > 0 and nUnits > 0, 'the fixture corpus did not load')
end

return tests

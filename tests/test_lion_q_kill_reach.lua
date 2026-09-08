-- [hero] `lionqkill` -- X.ConsiderQ's 击杀 loop is the only one of twelve
-- drop-out points in that function that can hand the engine a cast point Earth
-- Spike cannot be cast at; and the gated reach term that stops it.
--
-- ===========================================================================
-- §0  WHAT IS WRONG
-- ===========================================================================
--
-- X.ConsiderQ returns a LOCATION.  X.SkillsComplement feeds it straight to
-- `bot:ActionQueue_UseAbilityOnLocation( abilityQ, castQLocation )`, so every
-- drop-out point in that function is a promise that the point it returns is a
-- point Earth Spike can be cast at.  Eleven of the twelve keep it:
--
--   Aoe, 团战, Farm x2, Push, Farm-neutrals   bot:FindAoELocation( ...,
--       bot:GetLocation(), nCastRange, ... ) -- targetloc is by construction
--       within nCastRange of the base, and J.GetAoeEnemyHeroLocation wraps the
--       same call with the same nCastRange
--   攻击                                      J.GetDelayCastLocation( ...,
--       nCastRange, 260, ... ) -- nil beyond nCastRange + 244, otherwise
--       clamped to nCastRange + 8 (jmz_func.lua :3036-3046)
--   撤退, 常规, Roshan, Tormentor              read nInRangeEnemyList
--       (nCastRange) or test J.IsInRange( ..., nCastRange ) outright
--
-- The twelfth is the 击杀 loop.  It iterates nInBonusEnemyList
-- (`nCastRange + 200`), has NO distance term of any kind, and returns
-- `npcEnemy:GetLocation()` verbatim.  A cast order on a point outside cast
-- range is a MOVE order first, so Lion walks the gap.
--
-- WHAT THAT COSTS, and it is not the walk.  X.SkillsComplement stamps
-- `lastCastQTime = DotaTime()` when the BID is made, not when the spell leaves,
-- and X.ConsiderW's first guard is `lastCastQTime > DotaTime() - 0.8`.  An
-- in-range bid casts, Q goes on cooldown, IsFullyCastable() turns false and the
-- Hex lock lifts a tick later.  An out-of-range bid casts nothing, so the next
-- tick re-enters the same loop, re-bids and re-stamps: Hex is locked out for the
-- whole walk by a cast that has not happened.  That failure mode exists only on
-- the branch that can bid out of range.
--
-- ===========================================================================
-- §0.1  THE READING (real frame, real KV, ONE derived number)
-- ===========================================================================
--
-- tests/fixtures/f_222428_lion_lich_burst.lua, Lion the subject:
--
--     lion_impale rank 2, GetCastRange() 650 off the KV snapshot (Lion is one
--     of the focus five, so the snapshot is real), aetherRange 0, and
--     X.ConsiderQ's own `+ 20`  =>  nCastRange = 670.
--     lich at 676.42u   -- 6.42u OUTSIDE the ring, inside the +200 list
--     axe  at 740.90u   -- 70.90u outside
--
-- Driven end to end (§4) the shipped tree orders Earth Spike at the point
-- 676.42u away.  Armed, it orders nothing on that frame.
--
-- ===========================================================================
-- §0.2  THE DOMAIN SITS BEHIND ANOTHER GATE, AND §5 PINS THAT RATHER THAN
--       ASSERTING IT IN PROSE
-- ===========================================================================
--
-- The 击杀 loop is DEAD on shipped defaults.  X.GetImpaleKillDamage returns
-- hAbility:GetAbilityDamage(); lion_impale declares no top-level AbilityDamage
-- (the per-rank 105/170/235/300 lives in AbilityValues/damage), so nDamage is a
-- hard 0, J.WillMagicKillTarget's estimate is <= 0 for every rank and every
-- target, and the loop cannot fire.  GH #175 filed exactly that direction and
-- declined to fix it; the id that un-deadens it is `lionqdmg`, registered and
-- not yet waved.
--
-- So arming `lionqkill` ALONE measures a no-op.  That is a fact about the wave
-- ORDER, not a licence to conjoin the two ids in code -- naming `lionqdmg` in
-- this predicate is the pullcad trap (AGENTS.md), and §5 asserts the predicate
-- does not.  §5 also DRIVES the no-op claim over the whole corpus rather than
-- stating it, because "this lever is inert alone" is precisely the sentence a
-- wave verdict would otherwise read back as "tested, no effect".
--
-- The reason to land the term now: `lionqdmg` resurrects a kill branch that has
-- no reach term, so a wave of `lionqdmg` alone buys a widening AND a dive in one
-- reading with no way to separate them.  iterations/queue.json hero-49 therefore
-- asks for the PAIR and never for this id alone.
--
-- ===========================================================================
-- §0.3  LIMITS (each one has an assertion in §6)
-- ===========================================================================
--
--   1. §2's 4-in-band count is a reading about the RING, not about the branch
--      firing.  The branch's own gate cannot fire on this corpus at all, so §4
--      pays two DECLARED injections (arm `lionqdmg`; drop every visible enemy to
--      40 hp) to reach it.  Each injection is asserted to have taken.
--   2. NOT fixed here: the 攻击 branch's `nCastRange + 300` guard.  Its slack is
--      already clamped downstream by J.GetDelayCastLocation (nil past
--      nCastRange + 244), so the guard's outer 56 units are dead guard, not a
--      dive.  Different shape, different id, and widening this file's id count
--      to cover it would conjoin two questions.
--   3. NOT fixed here: the second Farm block at the bottom of X.ConsiderQ is
--      unreachable for every input -- it shares all three guards with the Farm
--      block above it and asks a strictly STRONGER AoE count (3 vs 2), so any
--      frame reaching it has already returned.  That is dead code, not a
--      behaviour lever; making it live would be a WIDENING and needs its own
--      evidence.  Registered here so the next reader does not re-derive it.
--   4. A fixture corpus is a set of instants chosen for OTHER investigations.
--      18/4 is a DOMAIN, not a frequency: nothing here says how often a lethal
--      target sits in the band in a real game.  Sizing that needs a wave.

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')

local SRC    = 'bots/BotLib/hero_lion.lua'
local CAND   = 'lionqkill'
local DMGID  = 'lionqdmg'
local HELPER = 'lion_IsImpaleKillTargetInReach'
local UNIT   = 'npc_dota_hero_lion'
local IMPALE = 'lion_impale'

local FRAME  = 'tests/fixtures/f_222428_lion_lich_burst.lua'

local FIXTURE_DIR = 'tests/fixtures'
local STAGED_DIR  = 'tests/frames'

-- X.ConsiderQ's own arithmetic, at the rank FRAME is really at.  Both halves are
-- ASSERTED against the ability in §2 rather than trusted.
local CAST_RANGE = 650          -- KV AbilityCastRange
local SLACK      = 20           -- the file's own `+ 20`
local RING       = CAST_RANGE + SLACK
local BONUS      = 200          -- nInBonusEnemyList's extra radius

local EPS = 0.01

local tests = {}

local function read_file(path)
    local fh = assert(io.open(path, 'r'), 'cannot open ' .. path)
    local body = fh:read('*a')
    fh:close()
    return body
end

--- Both corpus directories, enumerated -- never a hardcoded list.  An empty
--- enumerator and an empty corpus are the same integer; the asserts below are
--- the only thing that tells them apart.
local function corpus_paths()
    local out, seen = {}, {}
    for _, dir in ipairs({ FIXTURE_DIR, STAGED_DIR }) do
        local n = 0
        -- UNRESOLVED_HAND_READ: io.popen, registered per GH #596's habit.
        local p = assert(io.popen('ls ' .. dir .. ' 2>/dev/null'))
        for name in p:lines() do
            if name:match('^f_.*%.lua$') and not seen[name] then
                seen[name] = true
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

--- Install `v` as the answer to `h:k()` AND drop any lazily-materialised method.
--- Setting only the spec entry leaves an already-built method in place and the
--- injection silently does not take -- which reads exactly like a lever that
--- does nothing.
local function inject(h, k, v)
    rawget(h, '__spec')[k] = v
    rawset(h, k, nil)
end

local function lion_alive(path)
    local ok, chunk = pcall(dofile, path)
    if not ok or type(chunk) ~= 'table' then return false end
    for _, u in ipairs(chunk.units or {}) do
        if u.name == UNIT and u.alive ~= false then return true end
    end
    return false
end

--- Load a frame with Lion as the subject and arm exactly the ids named in `tOn`.
local function frame(path, tOn)
    local J, bot = rf.load(path, UNIT)
    J.IsSoakCandidate = function(id) return tOn[id] == true end
    J.IsModeTurbo = function() return true end
    local X = rf.load_hero('lion')
    return J, bot, X
end

--- Drive the REAL X.SkillsComplement dispatch with the two declared injections
--- of limit 1 in place, and report the Earth Spike cast point it ordered (nil if
--- none).  Returns the distance, plus the handles §4 needs to prove each
--- injection took.
local function drive(path, tOn)
    local J, bot, X = frame(path, tOn)
    local hQ = bot:GetAbilityByName(IMPALE)
    if hQ == nil or hQ:GetLevel() == 0 then return nil end
    inject(hQ, 'IsFullyCastable', true)                        -- injection A
    local tSeen = bot:GetNearbyHeroes(1600, true, BOT_MODE_NONE)
    for _, e in ipairs(tSeen) do inject(e, 'GetHealth', 40) end -- injection B
    local log = rf.record_actions(bot)
    X.SkillsComplement()
    local nDist = nil
    for _, a in ipairs(log) do
        if a.fn == 'ActionQueue_UseAbilityOnLocation' then
            local h = a.args[1]
            if h ~= nil and h.GetName ~= nil and h:GetName() == IMPALE then
                nDist = GetUnitToLocationDistance(bot, a.args[2])
            end
        end
    end
    return nDist, bot, hQ, tSeen, X, J
end

-- ---------------------------------------------------------------- section 1 --
-- The census claim of §0, in its load-bearing half.  The prose lists twelve
-- drop-out points; what actually carries the argument is that the WIDE list is
-- read in exactly one place, and that that place has no distance term of its own
-- beyond the one this lever adds.

tests['§1 nInBonusEnemyList is built once and read in exactly one branch'] = function()
    local src = read_file(SRC)
    local iFn = assert(src:find('\nfunction%s+X%.ConsiderQ%s*%('), 'X.ConsiderQ is gone from ' .. SRC)
    local rest = src:sub(iFn + 1)
    local iEnd = assert(rest:find('\nend\n'), 'X.ConsiderQ has no closing end')
    local body = rest:sub(1, iEnd)

    local nBuilt = select(2, body:gsub('local%s+nInBonusEnemyList', ''))
    assert(nBuilt == 1, 'X.ConsiderQ builds nInBonusEnemyList ' .. nBuilt .. ' times, expected 1')
    assert(body:find('nCastRange%s*%+%s*' .. BONUS),
        'nInBonusEnemyList no longer uses the +' .. BONUS .. ' radius this file assumes')

    -- Built once, read twice: the declaration and the 击杀 loop's `pairs`.
    local nRead = select(2, body:gsub('nInBonusEnemyList', ''))
    assert(nRead == 2, 'nInBonusEnemyList is now mentioned ' .. nRead
        .. ' times in X.ConsiderQ (was 2: the declaration and the 击杀 loop). '
        .. 'A SECOND reader would need its own reach term -- see the two-call-site '
        .. 'note on X.lion_ShouldCommitUltKill for what happens when one is missed')

    assert(body:find('X%.' .. HELPER .. '%('),
        'the 击杀 loop no longer routes through X.' .. HELPER)
end

-- ---------------------------------------------------------------- section 2 --
-- The geometry, over the whole corpus, with NOTHING injected.  This is a reading
-- about the RING (limit 1): it counts enemy-hero sightings the 击杀 loop would
-- consider, and how many of them the ability cannot reach.

tests['§2 18 of 22 in-list sightings are reachable, 4 are not'] = function()
    local nLive, nTrained, nInner, nBand = 0, 0, 0, 0
    local bHasFrame = false
    for _, path in ipairs(corpus_paths()) do
        if lion_alive(path) then
            nLive = nLive + 1
            local _, bot = rf.load(path, UNIT)
            local hQ = bot:GetAbilityByName(IMPALE)
            local nLv = hQ and hQ:GetLevel() or 0
            if nLv > 0 then
                nTrained = nTrained + 1
                local nRing = hQ:GetCastRange() + SLACK
                for _, e in ipairs(bot:GetNearbyHeroes(nRing + BONUS, true, BOT_MODE_NONE)) do
                    if GetUnitToUnitDistance(bot, e) <= nRing then nInner = nInner + 1
                    else nBand = nBand + 1 end
                end
            end
            if path == FRAME then bHasFrame = true end
        end
    end
    assert(bHasFrame, FRAME .. ' no longer holds a live ' .. UNIT)
    assert(nLive == 27, 'live-Lion instants moved: ' .. nLive .. ' (was 27)')
    assert(nTrained == 27, 'Impale-trained instants moved: ' .. nTrained .. ' (was 27)')
    assert(nInner == 18, 'in-ring sightings moved: ' .. nInner .. ' (was 18)')
    assert(nBand == 4, 'out-of-ring sightings moved: ' .. nBand .. ' (was 4)')
end

tests['§2 the FRAME margin is 6.42u, and both halves of nCastRange are real'] = function()
    local _, bot = rf.load(FRAME, UNIT)
    local hQ = assert(bot:GetAbilityByName(IMPALE), IMPALE .. ' is gone from ' .. FRAME)
    assert(hQ:GetLevel() == 2, 'Impale rank on ' .. FRAME .. ' moved: ' .. hQ:GetLevel())
    assert(hQ:GetCastRange() == CAST_RANGE,
        'the KV cast range answered ' .. tostring(hQ:GetCastRange()) .. ', not ' .. CAST_RANGE)
    assert(read_file(SRC):find('abilityQ:GetCastRange%(%)%s*%+%s*aetherRange%s*%+%s*' .. SLACK),
        "X.ConsiderQ's nCastRange is no longer GetCastRange() + aetherRange + " .. SLACK)

    local tOut = {}
    for _, e in ipairs(bot:GetNearbyHeroes(RING + BONUS, true, BOT_MODE_NONE)) do
        tOut[e:GetUnitName()] = GetUnitToUnitDistance(bot, e)
    end
    local nLich = assert(tOut['npc_dota_hero_lich'], 'lich left ' .. FRAME .. "'s +200 list")
    local nAxe  = assert(tOut['npc_dota_hero_axe'],  'axe left ' .. FRAME .. "'s +200 list")
    assert(math.abs(nLich - 676.42) < 0.5, 'lich distance moved: ' .. nLich)
    assert(math.abs(nAxe  - 740.90) < 0.5, 'axe distance moved: '  .. nAxe)
    -- The whole point of the frame: inside the list the loop reads, outside the
    -- ring the ability can be cast at.
    assert(nLich > RING and nLich <= RING + BONUS, 'lich is no longer in the band')
end

-- ---------------------------------------------------------------- section 3 --
-- The predicate itself.  Gate-off equivalence is what makes a soak candidate
-- inert in real games, so it is driven for every off configuration rather than
-- read off the source shape.

tests['§3 gate off returns the shipped answer unchanged, in every off config'] = function()
    local _, bot, X = frame(FRAME, {})
    local hLich
    for _, e in ipairs(bot:GetNearbyHeroes(1600, true, BOT_MODE_NONE)) do
        if e:GetUnitName() == 'npc_dota_hero_lich' then hLich = e end
    end
    assert(hLich ~= nil, 'lich is gone from ' .. FRAME)

    for _, bShipped in ipairs({ true, false }) do
        -- (a) candidate not armed at all
        assert(X[HELPER](bot, hLich, RING, bShipped) == bShipped,
            'gate-off changed the answer for bShippedLethal=' .. tostring(bShipped))
    end

    -- (b) armed but NOT turbo
    local J2, bot2, X2 = frame(FRAME, { [CAND] = true })
    J2.IsModeTurbo = function() return false end
    local hLich2
    for _, e in ipairs(bot2:GetNearbyHeroes(1600, true, BOT_MODE_NONE)) do
        if e:GetUnitName() == 'npc_dota_hero_lich' then hLich2 = e end
    end
    assert(X2[HELPER](bot2, hLich2, RING, true) == true, 'armed outside turbo refused a target')
end

tests['§3 armed: the ring decides, and it can only turn true into false'] = function()
    local _, bot, X = frame(FRAME, { [CAND] = true })
    local tHero = {}
    for _, e in ipairs(bot:GetNearbyHeroes(1600, true, BOT_MODE_NONE)) do
        tHero[e:GetUnitName()] = e
    end
    local hLich = assert(tHero['npc_dota_hero_lich'])

    -- 676.42 > 670: refused.
    assert(X[HELPER](bot, hLich, RING, true) == false, 'armed accepted a target 6.42u out of range')
    -- One-way: a shipped false is never turned into a true, even for a target
    -- the ring would accept.
    assert(X[HELPER](bot, hLich, RING + BONUS, false) == false, 'armed manufactured a cast')
    -- The ring is the thing being read, not a constant: widen it past the
    -- distance and the same target is accepted.
    assert(X[HELPER](bot, hLich, RING + BONUS, true) == true, 'armed refused an in-ring target')

    -- Degenerate arguments fall back to shipped rather than inventing a default.
    assert(X[HELPER](nil, hLich, RING, true) == true, 'nil bot did not fall back to shipped')
    assert(X[HELPER](bot, nil, RING, true) == true, 'nil target did not fall back to shipped')
    assert(X[HELPER](bot, hLich, 'not a number', true) == true,
        'a non-numeric range did not fall back to shipped')
end

-- ---------------------------------------------------------------- section 4 --
-- End to end on the real dispatch, over the whole corpus, with the two declared
-- injections of limit 1.  This is the section that shows the lever moves the
-- thing it claims to move -- and it asserts each injection actually took, rather
-- than inferring that from the result.

tests['§4 both declared injections take, on the frame the reading is quoted from'] = function()
    local _, bot, X = frame(FRAME, { [DMGID] = true })
    local hQ = bot:GetAbilityByName(IMPALE)
    assert(hQ:IsFullyCastable() == false,
        'injection A is no longer an injection: Impale is already castable on ' .. FRAME)
    inject(hQ, 'IsFullyCastable', true)
    assert(hQ:IsFullyCastable() == true, 'injection A did not take')

    -- Injection B, and the reason it is needed: the corpus health is far above
    -- what a rank-2 Impale can kill even with `lionqdmg` armed.
    assert(hQ:GetSpecialValueInt('damage') == 170,
        'the KV damage ladder answered ' .. tostring(hQ:GetSpecialValueInt('damage')) .. ', not 170')
    local hLich
    for _, e in ipairs(bot:GetNearbyHeroes(1600, true, BOT_MODE_NONE)) do
        if e:GetUnitName() == 'npc_dota_hero_lich' then hLich = e end
    end
    assert(hLich:GetHealth() > 170, 'lich is already inside Impale range on ' .. FRAME
        .. '; injection B would no longer be an injection')
    inject(hLich, 'GetHealth', 40)
    assert(hLich:GetHealth() == 40, 'injection B did not take')
    assert(X ~= nil)
end

tests['§4 armed refuses exactly the 2 out-of-ring casts and keeps the other 10'] = function()
    local nCast, nKept, nRefused = 0, 0, 0
    local tRefused = {}
    for _, path in ipairs(corpus_paths()) do
        if lion_alive(path) then
            local nOff = drive(path, { [DMGID] = true })
            local nOn  = drive(path, { [DMGID] = true, [CAND] = true })
            if nOff ~= nil then
                nCast = nCast + 1
                if nOn == nil then
                    nRefused = nRefused + 1
                    tRefused[#tRefused + 1] = string.format('%s@%.2f', path, nOff)
                    assert(nOff > RING, 'armed refused an IN-ring cast on ' .. path
                        .. ' (' .. nOff .. 'u) -- this lever may only remove out-of-ring casts')
                else
                    nKept = nKept + 1
                    assert(math.abs(nOn - nOff) < EPS, 'armed MOVED the cast point on ' .. path
                        .. ': ' .. nOff .. ' -> ' .. nOn .. '. This lever never re-picks a target')
                    assert(nOff <= RING, 'an in-ring-kept cast is at ' .. nOff .. 'u, outside ' .. RING)
                end
            else
                assert(nOn == nil, 'armed ADDED a cast on ' .. path .. ' -- direction is one-way')
            end
        end
    end
    assert(nCast == 12, 'frames driving an Impale cast moved: ' .. nCast .. ' (was 12)')
    assert(nKept == 10, 'kept casts moved: ' .. nKept .. ' (was 10)')
    assert(nRefused == 2, 'refused casts moved: ' .. nRefused .. ' (was 2) -- '
        .. table.concat(tRefused, ', '))
end

-- ---------------------------------------------------------------- section 5 --
-- The pullcad guard, and the "inert alone" claim DRIVEN rather than written.

tests['§5 the predicate does not name the other id, and the id is named once'] = function()
    local src = read_file(SRC)
    assert(select(2, src:gsub("IsSoakCandidate%(%s*'" .. CAND .. "'%s*%)", '')) == 1,
        CAND .. ' is named by more than one gate in ' .. SRC)

    local iFn = assert(src:find('\nfunction%s+X%.' .. HELPER .. '%s*%('),
        'X.' .. HELPER .. ' is gone from ' .. SRC)
    local rest = src:sub(iFn + 1)
    local iEnd = assert(rest:find('\nend\n'), 'X.' .. HELPER .. ' has no closing end')
    local body = rest:sub(1, iEnd)
    assert(not body:find(DMGID), 'X.' .. HELPER .. ' names ' .. DMGID
        .. ' in its own body -- that is the pullcad trap: the day ' .. DMGID
        .. ' is promoted this gate freezes FALSE and no tool notices')

    -- And no OTHER gate anywhere in bots/ may name this id in its condition.
    local nOther = 0
    -- UNRESOLVED_HAND_READ: io.popen, registered per GH #596's habit.
    local p = assert(io.popen("grep -rl \"'" .. CAND .. "'\" bots 2>/dev/null"))
    for line in p:lines() do
        if line ~= SRC then nOther = nOther + 1 end
    end
    p:close()
    assert(nOther == 0, CAND .. ' is named in ' .. nOther .. ' other bots/ file(s)')
end

tests['§5 armed ALONE is a no-op on every frame -- the wave-order fact, driven'] = function()
    local nCast, nSame = 0, 0
    for _, path in ipairs(corpus_paths()) do
        if lion_alive(path) then
            local nShipped = drive(path, {})
            local nAlone   = drive(path, { [CAND] = true })
            assert((nShipped == nil) == (nAlone == nil),
                CAND .. ' alone changed WHETHER a cast happened on ' .. path)
            if nShipped ~= nil then
                nCast = nCast + 1
                assert(math.abs(nAlone - nShipped) < EPS,
                    CAND .. ' alone MOVED the cast point on ' .. path)
                nSame = nSame + 1
            end
        end
    end
    -- Byte-identical on every frame, and that is the claim: with `lionqdmg` off
    -- the kill loop cannot fire, so this id has nothing to narrow.  A wave that
    -- arms it alone buys a no-op.
    assert(nCast == nSame, 'unreachable')

    -- And the sharper half: of the 12 casts §4 drives, exactly ONE survives
    -- without `lionqdmg`.  It is not a kill-loop cast at all -- it is the 常规
    -- branch on tests/frames/f_260905_004847_lion_drain_bkb.lua (Lion level 24,
    -- bristleback 386.86u, inside the ring), and it is exactly why §4 asserts
    -- the KEPT casts are unmoved rather than assuming every §4 cast is a kill
    -- cast.  The other 11 exist only because §4 arms the damage id.
    assert(nCast == 1, 'the shipped tree drives ' .. nCast .. ' Impale cast(s) '
        .. 'under §4\'s injections without ' .. DMGID .. ' armed (was 1, the 常规 '
        .. 'branch). If this rose, the "dead kill branch" premise of §0.2 has '
        .. 'changed and iterations/queue.json hero-49 must be re-read')
end

-- ---------------------------------------------------------------- section 6 --
-- The registered limits.  A limit with no assertion is a sentence; these go red
-- when the thing they excuse stops being true.

tests['§6 limit 2: the 攻击 branch slack is still clamped downstream'] = function()
    local src = read_file(SRC)
    assert(src:find('J%.IsInRange%(%s*botTarget,%s*bot,%s*nCastRange%s*%+%s*300%s*%)'),
        "the 攻击 branch's +300 guard moved -- limit 2 was written about that number")
    assert(src:find('J%.GetDelayCastLocation%(%s*bot,%s*botTarget,%s*nCastRange,%s*260,'),
        'the 攻击 branch no longer clamps through J.GetDelayCastLocation; its slack '
        .. 'is then a real dive and limit 2 no longer excuses leaving it alone')
    local jm = read_file('bots/FunLib/jmz_func.lua')
    assert(jm:find('nDistance%s*>%s*nCastRange%s*%+%s*nRadius%s*%-%s*16'),
        'J.GetDelayCastLocation stopped refusing beyond nCastRange + nRadius - 16')
end

tests['§6 limit 3: the second Farm block is still unreachable'] = function()
    local src = read_file(SRC)
    local iFn = assert(src:find('\nfunction%s+X%.ConsiderQ%s*%('))
    local rest = src:sub(iFn + 1)
    local body = rest:sub(1, assert(rest:find('\nend\n')))
    -- Two Farm blocks, same three guards, same neutral-creep test, and the lower
    -- one asks a STRICTLY STRONGER AoE count -- so it can never be reached.
    local nNeutral = select(2, body:gsub('GetNearbyNeutralCreeps%(%s*nCastRange%s*%)', ''))
    assert(nNeutral == 2, 'the two neutral-creep Farm blocks moved: ' .. nNeutral .. ' (was 2)')
    local tCount = {}
    for n in body:gmatch('locationAoE%.count%s*>=%s*(%d)') do tCount[#tCount + 1] = tonumber(n) end
    assert(#tCount == 3, 'locationAoE.count guards moved: ' .. #tCount .. ' (was 3)')
    assert(tCount[1] <= tCount[3], 'the lower Farm block no longer asks a stronger count than '
        .. 'the upper one; it may be REACHABLE now and limit 3 is stale')
end

tests['§6 limit 4: the domain is a domain, and the corpus is not empty'] = function()
    local n = 0
    for _, path in ipairs(corpus_paths()) do if lion_alive(path) then n = n + 1 end end
    assert(n > 0, 'no live-Lion frame in the corpus at all -- every reading above is vacuous')
end

return tests

-- [hero] `cmwhit` -- X.ConsiderW's SELF-DEFENCE branch opens on "some hero has
-- been hitting me" and then picks its Frostbite target by DISTANCE, never
-- asking which hero that was.
--
-- ===========================================================================
-- §0  WHAT IS WRONG
-- ===========================================================================
--
-- bots/BotLib/hero_crystal_maiden.lua X.ConsiderW, 保护自己 branch, as shipped:
--
--     if bot:WasRecentlyDamagedByAnyHero( 3.0 )        <- the TRIGGER
--         and #nEnemysHeroesInRange >= 1
--     then
--         for _, npcEnemy in pairs( nEnemysHeroesInRange ) do
--             if <validity, non-magic-immune, CanCastOnTargetAdvanced,
--                 not disabled, not disarmed, [cmwface] heading cone>
--             then return BOT_ACTION_DESIRE_HIGH, npcEnemy end   <- the TARGET
--
-- The trigger is an EXISTENTIAL fact about damage.  The target is the first
-- member of a list sorted by distance.  Nothing in between asks whether the
-- hero being frozen is the hero doing the damage.
--
-- ⭐ THE LIST IS SORTED CORRECTLY, AND THAT IS THE POINT.  J.GetNearbyHeroes
-- (jmz_func.lua:2856) filters the engine's GetNearbyHeroes and never reorders,
-- and docs/BOT_API_REFERENCE.md makes sorted-by-distance a promise for that
-- whole family.  So this is NOT the `anyhero` shape (GH #724), where an
-- existential was handed to an ARBITRARY member and sorting would have fixed
-- it.  It is the GH #731 / `zusjumpany` shape: the ordering is right and
-- irrelevant, because the predicate is AUTHORSHIP OF THE DAMAGE and the sort
-- key is distance.
--
-- ⭐ THE PER-CANDIDATE FORM ALREADY EXISTS AND IS THIS TREE'S LIVE IDIOM.
-- `bot:WasRecentlyDamagedByHero( npcEnemy, t )` has 19 call sites under bots/,
-- four of them in the focus five (this file's own X.ConsiderQ, WK, Lion, Zeus).
-- §5 counts them rather than asserting the number here.
--
-- ===========================================================================
-- §0.1  WHAT THE LEVER DOES, AND ITS DIRECTION
-- ===========================================================================
--
-- X.cm_IsSelfDefenseCastable is the shipped per-candidate chain, in the shipped
-- order.  X.cm_FindSelfDefenseTarget scans with it; armed it runs a FIRST pass
-- that additionally requires `WasRecentlyDamagedByHero(e, 3.0)` and falls back
-- to the shipped scan when that pass is empty.
--
-- So the lever is NEITHER a widening NOR a narrowing: the armed leg returns
-- non-nil exactly when the shipped leg does, which means the branch fires on
-- the same frames, the same number of times, at the same desire.  Only the
-- TARGET IDENTITY can move.  §4 drives that over the whole CM corpus in both
-- directions; §3 is the one frame where the identity actually moves.
--
-- ===========================================================================
-- §0.2  THE READING (one real frame, real positions, REAL recorded damage)
-- ===========================================================================
--
-- tests/fixtures/f_260820_102645_cm_es_reach.lua -- two enemies in the ring:
--
--     earthshaker   536.0u   did NOT damage her inside the 3s window
--     bristleback   556.9u   DID damage her inside the 3s window
--
-- 20.9 units decide the shipped target, and they decide it against the only
-- hero in the ring who was hitting her.  ⭐ Unlike `cmwface`'s pin, the
-- discriminating fact here is NOT a mock default: the damage history is the
-- .dem's own `recent_damage` rows, installed by the loader
-- (tests/mock/replay_fixture.lua:550) and absent -> not installed at all.  §3.0
-- asserts the rows are really there before any flip is read off them.
--
-- ===========================================================================
-- §0.3  LIMITS -- READ BEFORE QUOTING ANY NUMBER OUT OF THIS FILE
-- ===========================================================================
--
--  1. NO FREQUENCY IS CLAIMED.  §1 measures the SUPPLY: over the CM corpus,
--     how many instants have her recently damaged and how many of those have a
--     ring whose nearest legal target is not a damager.  One frame out of 13 is
--     a statement about this corpus, not about Turbo.  The frequency question
--     is iterations/queue.json hero-60.
--  2. NO PAYOFF IS CLAIMED.  The lever moves a root onto the damage source.
--     Whether that converts into survival or a kill is a wave question; nothing
--     here reports one.
--  3. ⚠️ THE HEADING CONE IS STILL A MOCK DEFAULT.  The shipped chain's last
--     conjunct is X.cm_IsSelfDefenseFacingOk, and `IsFacingLocation` is on no
--     spec in tests/mock/ (see tests/test_cm_w_selfdefense_facing.lua §6).  So
--     with `cmwface` unarmed the chain is FALSE for every candidate and both
--     legs of this lever return nil everywhere.  Every section that reads a
--     target therefore arms `cmwface` TOO and says so at the call.  That is a
--     harness fact about the cone, not a dependency in the gate: §6 asserts the
--     two ids are independently armable and that neither gate names the other.
--  4. THE SIBLINGS ARE NOT IN THIS LEVER.  The same ANY-trigger-then-nearest
--     shape sits in hero_skeleton_king.lua and hero_zuus.lua.  §1 counts their
--     corpus flips (0 today) so the next reader does not have to re-measure to
--     find out whether they could have ridden along.

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')

local SRC    = 'bots/BotLib/hero_crystal_maiden.lua'
local CAND   = 'cmwhit'
local FACE   = 'cmwface'
local UNIT   = 'npc_dota_hero_crystal_maiden'
local FINDER = 'cm_FindSelfDefenseTarget'
local CHAIN  = 'cm_IsSelfDefenseCastable'
local PIN    = 'tests/fixtures/f_260820_102645_cm_es_reach.lua'
local NEAR   = 'npc_dota_hero_earthshaker'   -- nearest legal target, did NOT hit her
local HITTER = 'npc_dota_hero_bristleback'   -- farther, and the one who did

local FIXTURE_DIR = 'tests/fixtures'
local STAGED_DIR  = 'tests/frames'

local tests = {}

local function read_file(path)
    local fh = assert(io.open(path, 'r'), 'cannot open ' .. path)
    local body = fh:read('*a')
    fh:close()
    return body
end

--- Comments stripped, so a ratchet counting code shapes cannot be satisfied by
--- prose that merely mentions the expression.  (backlog -149: an assertion must
--- count CODE, never the file's own writing about the code.)
local function strip_comments(s)
    return (s:gsub('%-%-[^\n]*', ''))
end

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

--- Both corpus directories, enumerated -- never a hardcoded list, so a corpus
--- that GROWS cannot turn this file red (the `-145`/`-149` family of same-cause
--- reds was every time a `== N` pin on corpus size).
local function corpus_paths()
    local out = {}
    for _, dir in ipairs({ FIXTURE_DIR, STAGED_DIR }) do
        local n = 0
        -- UNRESOLVED_HAND_READ: io.popen, registered per GH #596's habit.
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

local function frame_has(path, sUnit)
    local ok, chunk = pcall(dofile, path)
    if not ok or type(chunk) ~= 'table' then return false end
    for _, u in ipairs(chunk.units or {}) do
        if u.name == sUnit and u.alive ~= false then return true end
    end
    return false
end

--- One loaded world.  `opt.armed` arms CAND; `opt.face` arms FACE as well (see
--- limit 3 -- without it the shipped chain is false for every candidate and no
--- section below can read a target at all).
local function world(path, opt)
    opt = opt or {}
    local J, bot = rf.load(path or PIN, UNIT)
    J.IsSoakCandidate = function(id)
        if id == CAND then return opt.armed == true end
        if id == FACE then return opt.face == true end
        return false
    end
    if opt.nonTurbo then
        -- rf.load's install() forces turbo; undo it AFTER load, exactly as
        -- tests/test_cm_w_selfdefense_facing.lua does.
        GetGameMode = function() return 1 end
    end
    local X = rf.load_hero('crystal_maiden')
    return J, bot, X
end

--- Frostbite's real ring on this frame, the way X.ConsiderW builds it.
local function ring(J, bot)
    local hAb = bot:GetAbilityByName('crystal_maiden_frostbite')
    local nCastRange = (hAb and hAb:GetCastRange() or 0) + 30
    return J.GetNearbyHeroes(bot, nCastRange, true, BOT_MODE_NONE)
end

--- The NAME the leg hands back, or nil.  ⭐ Names, never handles: two rf.load
--- calls build two different tables for the same hero, so comparing handles
--- across worlds is true-by-construction nonsense (backlog -150 bought that
--- lesson at the price of a whole round's reading).
local function leg(path, opt)
    local J, bot, X = world(path, opt)
    local h = X.cm_FindSelfDefenseTarget(bot, ring(J, bot))
    return h ~= nil and h:GetUnitName() or nil
end

-- ---------------------------------------------------------------- section 1 --
-- THE SUPPLY, counted over the corpus.  Direction-safe bounds only: every
-- number that is not itself the conclusion is a FLOOR, so corpus growth may
-- only make these larger.

tests['§1 the corpus supply: 13 CM instants under fire, exactly one where the nearest legal target is not a damager'] = function()
    local nLive, nHit, nFlip = 0, 0, 0
    local sFlip = nil
    for _, path in ipairs(corpus_paths()) do
        if frame_has(path, UNIT) then
            nLive = nLive + 1
            local J, bot = rf.load(path, UNIT)
            if bot:WasRecentlyDamagedByAnyHero(3.0) then
                nHit = nHit + 1
                local t = ring(J, bot)
                local bAnyHitter, bNearestHitter = false, false
                for i, e in ipairs(t) do
                    local b = bot:WasRecentlyDamagedByHero(e, 3.0)
                    if b then bAnyHitter = true end
                    if i == 1 then bNearestHitter = b end
                end
                if #t >= 2 and bAnyHitter and not bNearestHitter then
                    nFlip = nFlip + 1
                    sFlip = path
                end
            end
        end
    end
    assert(nLive >= 70, 'live-CM instants fell to ' .. nLive .. ' (floor 70)')
    assert(nHit >= 13, 'CM instants under recent hero fire fell to ' .. nHit
        .. ' (floor 13)')
    -- This one IS the conclusion: the lever's whole locally-checkable domain.
    assert(nFlip >= 1, 'no corpus frame has a ring whose nearest legal target is '
        .. 'not a damager -- the lever has no local domain left')
    assert(sFlip == PIN or nFlip > 1,
        'the single qualifying frame moved: ' .. tostring(sFlip)
        .. ' (this file reads ' .. PIN .. ')')
end

--- ⚠️ ONLY the two heroes whose self-defence branch is the SAME shape are in
--- this census: a single-target disable chosen out of a distance-ordered ring
--- (hero_skeleton_king.lua X.ConsiderQ / Hellfire Blast, hero_zuus.lua
--- X.ConsiderW / Lightning Bolt -- the pair tests/test_cm_w_selfdefense_facing
--- .lua's header already named).  Axe is NOT in the family and must not be
--- added to it: Berserker's Call is a no-target taunt, so its branch has no
--- per-target choice for authorship to move.  (Measured while writing this:
--- Axe does have 1 corpus frame where the nearest ring member is not a damager.
--- That number is real and it is about nothing -- there is no target to pick.)
tests['§1.1 the two same-shape sibling branches have 0 corpus flips -- which is why they did not ride along'] = function()
    local tSeen = {}
    for _, sUnit in ipairs({ 'npc_dota_hero_skeleton_king', 'npc_dota_hero_zuus' }) do
        local nFlip, nLive = 0, 0
        for _, path in ipairs(corpus_paths()) do
            if frame_has(path, sUnit) then
                nLive = nLive + 1
                local J, bot = rf.load(path, sUnit)
                if bot:WasRecentlyDamagedByAnyHero(3.0) then
                    local t = J.GetNearbyHeroes(bot, 630, true, BOT_MODE_NONE)
                    local bAny, bNear = false, false
                    for i, e in ipairs(t) do
                        local b = bot:WasRecentlyDamagedByHero(e, 3.0)
                        if b then bAny = true end
                        if i == 1 then bNear = b end
                    end
                    if #t >= 2 and bAny and not bNear then nFlip = nFlip + 1 end
                end
            end
        end
        assert(nLive > 0, sUnit .. ' has no live instant in the corpus')
        tSeen[sUnit] = nFlip
    end
    -- A CEILING is the direction-safe bound here: the claim is "they could not
    -- have been pinned this round", so growth that CREATES a sibling frame must
    -- speak up.  It is not a defect when it does -- it is the next work unit.
    for sUnit, n in pairs(tSeen) do
        assert(n == 0, sUnit .. ' now has ' .. n .. ' flip frame(s) in the corpus. '
            .. 'The sibling branch can be pinned now; open it as its own lever '
            .. '(one lever at a time) and re-anchor this assertion.')
    end
end

-- ---------------------------------------------------------------- section 2 --
-- The one claim the call-site comment makes about its own rewrite: the loop
-- moved from `pairs` to `ipairs`.  Asserted over the corpus rather than argued.

tests['§2 pairs and ipairs visit the same ring members in the same order, on every corpus frame'] = function()
    local nChecked = 0
    for _, path in ipairs(corpus_paths()) do
        if frame_has(path, UNIT) then
            local J, bot = rf.load(path, UNIT)
            local t = ring(J, bot)
            local a, b = {}, {}
            for _, e in pairs(t) do a[#a + 1] = e:GetUnitName() end
            for _, e in ipairs(t) do b[#b + 1] = e:GetUnitName() end
            assert(#a == #b, path .. ': pairs saw ' .. #a .. ' members, ipairs '
                .. #b .. ' -- the ring has a hole and the rewrite is not neutral')
            for i = 1, #a do
                assert(a[i] == b[i], path .. ': pairs and ipairs disagree at index '
                    .. i .. ' (' .. a[i] .. ' vs ' .. b[i] .. ')')
            end
            if #a > 0 then nChecked = nChecked + 1 end
        end
    end
    assert(nChecked >= 1, 'no corpus frame put a hero in the ring -- §2 checked nothing')
end

-- ---------------------------------------------------------------- section 3 --
-- THE PIN.  One real frame, and the instrument is checked before it is read.

tests['§3.0 the pin frame really carries recorded damage, and the two enemies really differ on it'] = function()
    local fx = dofile(PIN)
    local nRows = 0
    for _, u in ipairs(fx.units or {}) do
        if u.name == UNIT then nRows = #(u.recent_damage or {}) end
    end
    assert(nRows > 0, PIN .. ' carries no recent_damage rows for ' .. UNIT
        .. ' -- the loader installs NO damage readers and every reading below '
        .. 'would be the mock default, not the game')

    local J, bot = rf.load(PIN, UNIT)
    local t = ring(J, bot)
    assert(#t == 2, 'the pin frame ring now holds ' .. #t .. ' heroes, not 2')
    assert(t[1]:GetUnitName() == NEAR,
        'the nearest ring member is now ' .. t[1]:GetUnitName() .. ', not ' .. NEAR)
    assert(t[2]:GetUnitName() == HITTER,
        'the second ring member is now ' .. t[2]:GetUnitName() .. ', not ' .. HITTER)
    -- ⭐ THE POSITIVE CONTROL ON THIS FILE'S OWN INSTRUMENT.  A reader that
    -- answered `false` to everything would make §3.1 read exactly like a lever
    -- that does nothing, and the row count above cannot tell the two apart.
    assert(bot:WasRecentlyDamagedByHero(t[2], 3.0) == true,
        'the damage reader does not recognise ' .. HITTER .. ' -- nothing in §3 '
        .. 'is about recorded damage')
    assert(bot:WasRecentlyDamagedByHero(t[1], 3.0) == false,
        'the damage reader now says ' .. NEAR .. ' hit her too -- the frame no '
        .. 'longer separates the two legs')
    local d1 = GetUnitToUnitDistance(bot, t[1])
    local d2 = GetUnitToUnitDistance(bot, t[2])
    assert(d1 < d2, 'the ring is no longer distance-ordered on the pin frame')
    assert(d2 - d1 < 60, ('the gap grew to %.1fu; this file\'s headline reads '
        .. '20.9u'):format(d2 - d1))
end

tests['§3.1 on the pin frame the shipped leg takes the bystander and the armed leg takes the damager'] = function()
    -- limit 3: FACE must be armed or the shipped chain is false for everyone.
    local sShipped = leg(PIN, { armed = false, face = true })
    local sArmed   = leg(PIN, { armed = true,  face = true })
    assert(sShipped == NEAR, 'the shipped leg returned ' .. tostring(sShipped)
        .. ', expected the nearest legal target ' .. NEAR)
    assert(sArmed == HITTER, 'the armed leg returned ' .. tostring(sArmed)
        .. ', expected the damager ' .. HITTER)
end

tests['§3.2 CONTROL: the same leg run twice returns the same answer -- read before §3.1'] = function()
    -- Without this, a finder that returned something arbitrary per load would
    -- produce §3.1's "flip" for a reason that has nothing to do with the gate.
    -- (backlog -150: a detector that is wrong in BOTH directions is worse than
    -- no detector, because the next reader writes it up.)
    for _, bArmed in ipairs({ false, true }) do
        local a = leg(PIN, { armed = bArmed, face = true })
        local b = leg(PIN, { armed = bArmed, face = true })
        assert(a == b, 'the ' .. (bArmed and 'armed' or 'shipped') .. ' leg is not '
            .. 'reproducible on one frame (' .. tostring(a) .. ' then '
            .. tostring(b) .. ') -- §3.1 reads noise')
    end
end

--- ⛔ THE HONEST HALF OF THE PIN, AND IT IS ASSERTED RATHER THAN FOOTNOTED.
--- X.ConsiderW cannot be reached on the pin frame: Frostbite is 1.5s into its
--- cooldown there, so the function returns NONE at its first line and the
--- 保护自己 branch is never evaluated.  §3.1's flip is therefore a reading at
--- the FINDER, on the ring the branch would have built -- not a recorded
--- failure to cast in that game.  This assertion exists so the next reader
--- cannot quote §3.1 as an end-to-end firing, and so the day a fixture arrives
--- that carries both the flip AND a ready Frostbite, this file goes red and
--- says what to rewrite.
tests['§3.3 the pin frame does NOT reach X.ConsiderW -- Frostbite is on cooldown, and the cooldown is the reason'] = function()
    local J, bot, X = world(PIN, { armed = true, face = true })
    local hAb = bot:GetAbilityByName('crystal_maiden_frostbite')
    local nCd = hAb:GetCooldownTimeRemaining()
    assert(nCd > 0, 'Frostbite is ready on the pin frame now (cd '
        .. tostring(nCd) .. ') -- the branch IS reachable, so rewrite this '
        .. 'section into the end-to-end assertion it was standing in for')
    assert(hAb:IsFullyCastable() == false, 'Frostbite is fully castable on the '
        .. 'pin frame -- see above')
    pcall(X.SkillsComplement)
    local ok, desire = pcall(X.ConsiderW)
    assert(ok, 'X.ConsiderW raised: ' .. tostring(desire))
    assert(desire == BOT_ACTION_DESIRE_NONE,
        'X.ConsiderW answered ' .. tostring(desire) .. ' with Frostbite on '
        .. 'cooldown -- the castability guard at the top of the function moved')
end

--- The complement of §3.3: the branch IS reachable elsewhere in the corpus, so
--- "unreachable" is a property of the pin instant, not of the branch.  What the
--- corpus does NOT supply is one frame carrying both at once -- that is exactly
--- the gap iterations/queue.json hero-60 asks a wave to fill.
tests['§3.4 the branch is reachable on other corpus frames -- but none of those is a flip frame'] = function()
    local nReach, nReachFlip = 0, 0
    for _, path in ipairs(corpus_paths()) do
        if frame_has(path, UNIT) then
            local J, bot = rf.load(path, UNIT)
            local hAb = bot:GetAbilityByName('crystal_maiden_frostbite')
            local bReady = hAb ~= nil and hAb:IsFullyCastable()
            if bReady and bot:WasRecentlyDamagedByAnyHero(3.0) then
                local t = ring(J, bot)
                if #t >= 1 then
                    nReach = nReach + 1
                    local s = leg(path, { armed = false, face = true })
                    local a = leg(path, { armed = true,  face = true })
                    if s ~= nil and s ~= a then nReachFlip = nReachFlip + 1 end
                end
            end
        end
    end
    assert(nReach >= 3, 'frames where the whole branch is reachable fell to '
        .. nReach .. ' (floor 3)')
    assert(nReachFlip == 0, nReachFlip .. ' reachable frame(s) now also flip the '
        .. 'target. That is BETTER supply, not a defect: promote one of them to '
        .. 'the pin and turn §3.3 into the end-to-end assertion.')
end

-- ---------------------------------------------------------------- section 4 --
-- THE DIRECTION, measured.  "Neither a widening nor a narrowing" is a claim
-- about the firing DOMAIN, so it is driven in both directions over the corpus.

tests['§4 over the whole CM corpus the two legs fire on exactly the same frames'] = function()
    local nBoth, nDisagree, nIdentityMoved = 0, 0, 0
    for _, path in ipairs(corpus_paths()) do
        if frame_has(path, UNIT) then
            local s = leg(path, { armed = false, face = true })
            local a = leg(path, { armed = true,  face = true })
            if (s == nil) ~= (a == nil) then nDisagree = nDisagree + 1 end
            if s ~= nil then
                nBoth = nBoth + 1
                if s ~= a then nIdentityMoved = nIdentityMoved + 1 end
            end
        end
    end
    assert(nBoth >= 1, 'neither leg fired anywhere in the corpus -- §4 checked nothing')
    assert(nDisagree == 0, 'the two legs differ on WHETHER to fire on '
        .. nDisagree .. ' frame(s). This lever is specified to move target '
        .. 'identity ONLY; a domain change means the fallback pass is broken.')
    assert(nIdentityMoved >= 1, 'the armed leg never moved the target anywhere in '
        .. 'the corpus -- the lever is a no-op here and §3.1 must be re-read')
end

tests['§4.1 the armed target is always a target the shipped chain accepts'] = function()
    for _, path in ipairs(corpus_paths()) do
        if frame_has(path, UNIT) then
            local J, bot, X = world(path, { armed = true, face = true })
            local h = X.cm_FindSelfDefenseTarget(bot, ring(J, bot))
            if h ~= nil then
                assert(X.cm_IsSelfDefenseCastable(bot, h),
                    path .. ': the armed leg returned ' .. h:GetUnitName()
                    .. ', which the shipped per-candidate chain rejects')
            end
        end
    end
end

-- ---------------------------------------------------------------- section 5 --
-- The premise of the whole lever: the per-candidate call is this tree's own
-- idiom, not a new judgement invented here.

--- ⚠️ Read by LITERAL paths, deliberately: a recursive walk of bots/ would have
--- to carry lua_source_scan's farm-only clause or it reads bots/Customize/
--- (tests/test_bots_walk_farm_only.py).  The premise only needs the focus five,
--- and naming them keeps this file off that census entirely.
tests['§5 WasRecentlyDamagedByHero is the live per-candidate idiom in the focus five'] = function()
    local nFiles = 0
    for _, part in ipairs({ 'crystal_maiden', 'skeleton_king', 'lion', 'zuus', 'axe' }) do
        local body = strip_comments(read_file('bots/BotLib/hero_' .. part .. '.lua'))
        if count(body, 'WasRecentlyDamagedByHero') > 0 then nFiles = nFiles + 1 end
    end
    -- Floor, not a pin: more call sites is more support for the premise.
    assert(nFiles >= 4, 'only ' .. nFiles .. ' of the five focus hero files use '
        .. 'the per-candidate form (floor 4) -- re-read this lever\'s premise')

    local src = strip_comments(read_file(SRC))
    assert(count(src, 'WasRecentlyDamagedByHero') >= 2,
        'hero_crystal_maiden.lua no longer carries the per-candidate form twice '
        .. '(X.ConsiderQ had one before this lever added the second)')
end

-- ---------------------------------------------------------------- section 6 --
-- GATE HYGIENE.  Counted on CODE, with comments stripped.

tests['§6.1 the gate is turbo-only, names cmwhit, and names NOTHING else'] = function()
    local src = strip_comments(read_file(SRC))
    local h = fn_body(src, FINDER)
    assert(h:find('J.IsModeTurbo()', 1, true), 'the gate must be turbo-only')
    assert(count(h, "J.IsSoakCandidate( '" .. CAND .. "' )") == 1,
        'X.' .. FINDER .. ' must name ' .. CAND .. ' exactly once')
    -- The pullcad trap: a gate whose condition also names a SIBLING id freezes
    -- FALSE the day that sibling is promoted, and check_armed_wiring.py still
    -- calls it WIRED.  cmwface/cmlaneband/cmrcrowd/cmrguard live in this file.
    for id in h:gmatch("IsSoakCandidate%(%s*'([%w_]+)'") do
        assert(id == CAND, 'X.' .. FINDER .. " conjoins a second soak id '" .. id
            .. "'. That is the pullcad trap -- express a dependency as a "
            .. 'promote-atom, never in code.')
    end
    -- The shipped chain must carry no gate of its own: both legs have to be
    -- demonstrably about the same predicate.
    local c = fn_body(src, CHAIN)
    assert(count(c, 'IsSoakCandidate') == 0,
        'X.' .. CHAIN .. ' grew a soak gate; it is the shipped chain and must '
        .. 'stay one predicate for both legs')
end

tests['§6.2 cmwhit and cmwface are independently armable -- neither gate is the other\'s'] = function()
    -- Arming only cmwface must leave the shipped TARGET choice untouched.
    assert(leg(PIN, { armed = false, face = true }) == NEAR,
        'arming cmwface alone moved the target -- the two ids are entangled')
    -- Arming only cmwhit must be inert here, because the cone (limit 3) refuses
    -- every candidate.  That is a statement about the harness, and it is the
    -- reason every reading section above arms both.
    assert(leg(PIN, { armed = true, face = false }) == nil,
        'the shipped heading cone now admits a candidate on the pin frame -- '
        .. 'limit 3 is stale, re-read tests/test_cm_w_selfdefense_facing.lua §6')
end

tests['§6.3 outside Turbo the armed id is inert'] = function()
    assert(leg(PIN, { armed = true, face = true, nonTurbo = true }) == nil
        or leg(PIN, { armed = true, face = true, nonTurbo = true }) == NEAR,
        'outside Turbo the lever must answer exactly as the shipped leg does')
    -- Said again in the direction that matters: non-turbo armed == turbo shipped.
    local sNonTurbo = leg(PIN, { armed = true, face = true, nonTurbo = true })
    local sShipped  = leg(PIN, { armed = false, face = true, nonTurbo = true })
    assert(sNonTurbo == sShipped, 'non-turbo armed answered ' .. tostring(sNonTurbo)
        .. ' but the shipped leg answers ' .. tostring(sShipped))
end

tests['§6.4 the call site consumes the finder exactly once, and the old inline scan is gone'] = function()
    local src = strip_comments(read_file(SRC))
    local w = fn_body(src, 'ConsiderW')
    assert(count(w, 'X.' .. FINDER .. '( bot, nEnemysHeroesInRange )') == 1,
        'X.ConsiderW must consume X.' .. FINDER .. ' exactly once')
    -- The cone call was the self-defence branch's alone (X.cm_IsSelfDefenseFacingOk
    -- has exactly one consumer), so its absence from X.ConsiderW is the precise
    -- statement "the inline chain moved into the helper" -- and unlike counting
    -- `IsDisarmed()`, it cannot be satisfied or broken by a SIBLING branch (the
    -- 团战 loop carries its own IsDisarmed conjunct and always has).
    assert(count(w, 'X.cm_IsSelfDefenseFacingOk') == 0,
        'the self-defence branch still carries its own inline copy of the chain '
        .. '-- the two legs can drift apart again')
    local c = fn_body(src, CHAIN)
    assert(count(c, 'X.cm_IsSelfDefenseFacingOk( hBot, hEnemy )') == 1,
        'X.' .. CHAIN .. ' must be the one consumer of the cone now')
end

return tests

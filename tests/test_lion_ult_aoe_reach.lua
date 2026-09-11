-- [hero] `lionraoe` -- the THIRD reach convention in Lion's X.ConsiderR, the one
-- `lionrreach` named and deliberately left for its own id; plus the closed-form
-- correction of a load-bearing sentence in the same function's neighbouring
-- header.
--
-- ===========================================================================
-- §0  WHAT IS WRONG
-- ===========================================================================
--
-- bots/BotLib/hero_lion.lua X.ConsiderR uses three different reach conventions
-- on one ability.  Two of them already route through `lionrreach`
-- (X.lion_ShouldCommitUltKill).  The third is the scepter AoE exit:
--
--     if J.IsValidHero( npcEnemy )
--         and J.IsInRange( bot, npcEnemy, nCastRange + 150 )
--
-- and that helper's own header lists it as "NOT IN THIS ID ... the scepter AoE
-- branch's `nCastRange + 150` (an AoE-value branch, not a kill claim)".  That
-- is the right scoping call and the wrong resting place.  Being a value branch
-- rather than a kill claim is an argument for a SEPARATE id, not for leaving
-- the slack: a kill claim at least buys something with the walk, while this
-- branch walks 150 units to line up a splash on a target free to keep walking.
-- The order is the same `ActionQueue_UseAbilityOnEntity` on a unit outside cast
-- range -- a MOVE order first -- and X.SkillsComplement returns the moment R is
-- queued, so Q/W/E go unconsidered for as long as the desire holds.
--
-- ===========================================================================
-- §0.1  THE CORRECTION, and it is the reason this round opened the file
-- ===========================================================================
--
-- X.lion_ShouldCashUltAtWeakest's header used to end a closed-form proof with:
--
--     "What the `or J.IsDyingUnderAttack( bot )` disjunct actually buys is
--      entry to the BLOCK, whose only reachable exit is the scepter AoE branch
--      below."
--
-- That sentence was already false when it was written, and it was falsified by
-- a fact landed in this same tree: GH #162 (`lionsplash`) proved the scepter
-- AoE branch is ALSO dead on shipped defaults.  X.GetAbilityRSplashRadius reads
-- `splash_radius_scepter`, a key that is not in this patch's
-- lion_finger_of_death KV at all (the live key is `splash_radius`, base ABSENT,
-- special_bonus_scepter 325), so nRadius is 0, so the branch's inner
-- `J.IsInRange( npcEnemy, nEnemy, 0 )` can only count a unit coincident with
-- npcEnemy, so nAoeCount <= 1 against an acceptance floor of 3.
--
-- Two closed-form deadness proofs, thirty lines apart in one function, each
-- written as if the OTHER exit were the live one.  The corrected statement is
-- stronger than either: on shipped defaults the 团战 block has NO reachable
-- exit at all, so `lionultcash` is the only registered id that can ever give it
-- one -- which is a (b)/(c) argument for that id, not a footnote to it.  The
-- watched replay `lionultcash` was written for (231244 t=10:50, a Lion who died
-- holding a ready finger) cannot be fixed by this block in any other armed
-- state.  §1 pins both halves.
--
-- ===========================================================================
-- §0.2  WHY IT IS LANDED NOW -- the `lionqkill` argument, verbatim
-- ===========================================================================
--
-- The branch is dead on shipped defaults for TWO independent reasons and only
-- one of them has an id: (i) nRadius == 0 (GH #162, id `lionsplash`), and
-- (ii) bot:HasScepter() is false on all 42 alive-Lion corpus frames -- though
-- all four of this file's buy lists carry item_ultimate_scepter, so it is a
-- live path in a real Turbo game.  `lionsplash` repairs (i) and nothing else,
-- so arming it alone resurrects a branch with no reach term: a widening and a
-- dive in one reading, with no way to separate them.  With this term already in
-- the tree the pair reads as one question.  The dependency is registered as a
-- promote-time ATOM in iterations/queue.json and is NOT written into the
-- predicate -- naming `lionsplash` inside the gate is the pullcad trap, and §5
-- asserts it is absent.
--
-- ===========================================================================
-- §0.3  HONEST BOUNDS, four, and none of them is a footnote
-- ===========================================================================
--
--   1. The DECISION cannot be driven end to end offline, for THREE independent
--      reasons, all measured in §2 rather than assumed: no corpus frame gives
--      Lion a scepter (0 of 42), both splash keys read 0, and the densest enemy
--      cluster at radius 325 anywhere in the corpus is 2 -- below the branch's
--      own floor of 3.  A green run over this file is NOT evidence that the
--      exit behaves; it is evidence about the PREDICATE.
--   2. The PREDICATE, by contrast, has a real non-empty domain and §4 drives it
--      on real frames with no injection at all: 4 (frame, enemy) pairs on 4
--      distinct frames sit in the band (nCastRange, nCastRange + 150] where the
--      armed leg disagrees with the shipped one.
--   3. Each of the three zeros in §2 is asserted as a zero WITH ITS CAUSE, so
--      the day the corpus grows a scepter-holding Lion or a three-hero cluster
--      this file goes red and names what moved (GH #741's discipline: an
--      unmeasurable quantity is pinned as unmeasurable or it gets quoted as a
--      measured zero).
--   4. Whether refusing the 150-unit walk helps a team win is the emergent
--      question and only a batch can answer it; the lanefix lesson applies in
--      full.
--
-- ZERO change to shipped behaviour: `lionraoe` is unarmed, turbo-only, and §3
-- drives gate-off equivalence over the whole corpus.

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')

local SRC         = 'bots/BotLib/hero_lion.lua'
local UNIT        = 'npc_dota_hero_lion'
local FINGER      = 'lion_finger_of_death'
local CAND        = 'lionraoe'
local HELPER      = 'lion_IsUltAoeTargetInReach'
local OTHER_CAND  = 'lionsplash'

local FIXTURE_DIR = 'tests/fixtures'
local STAGED_DIR  = 'tests/frames'

local CAST_RANGE = 900          -- abilityR:GetCastRange() on every corpus frame
local AOE_SLACK  = 150          -- the scepter AoE exit's extra radius
local KILL_BAND  = 400          -- nInBonusEnemyList, the list the exit iterates
local SPLASH     = 325          -- lion_finger_of_death/splash_radius under scepter

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

--- Every corpus path on which Lion is present and not dead.
local function lion_frames()
    local out = {}
    for _, path in ipairs(corpus_paths()) do
        local ok, fx = pcall(dofile, path)
        if ok and type(fx) == 'table' and fx.units ~= nil then
            for _, u in ipairs(fx.units) do
                if u.name == UNIT and u.alive ~= false then
                    out[#out + 1] = path
                    break
                end
            end
        end
    end
    return out
end

--- Drop every full-line Lua comment.  A gate-site census that counts over the
--- raw file counts the PROSE ABOUT the gate as a gate -- and this file's own
--- §5 caught exactly that on its first run: the header paragraph warning against
--- writing `IsSoakCandidate('lionraoe') and IsSoakCandidate('lionsplash')` was
--- itself read as a second gate site.  Count what executes.
local function code_only(src)
    local out = {}
    for line in (src .. '\n'):gmatch('([^\n]*)\n') do
        if not line:match('^%s*%-%-') then out[#out + 1] = line end
    end
    return table.concat(out, '\n')
end

local function consider_r_body(src)
    local from = src:find('function%s+X%.ConsiderR%s*%(')
    assert(from, 'X.ConsiderR is gone from ' .. SRC)
    local rest = src:sub(from)
    local to = rest:find('\nend\n')
    assert(to, 'X.ConsiderR has no closing end in ' .. SRC)
    return rest:sub(1, to)
end

--- Load one frame with Lion as subject and the gate answering `bArmed` for CAND
--- only.  Returns J, bot, X.
local function stand(path, bArmed)
    local J, bot = rf.load(path, UNIT)
    J.IsSoakCandidate = function(id) return bArmed and id == CAND end
    local X = rf.load_hero('lion')
    return J, bot, X
end

-- ---------------------------------------------------------------- section 1 --
-- The closed form: on shipped defaults the 团战 block has NO reachable exit.
-- §0.1's correction, expressed as things that go red rather than as prose.

tests['§1.1 the shipped splash radius is 0 on every alive-Lion frame'] = function()
    local tFrames = lion_frames()
    assert(#tFrames >= 30, 'the enumerator found ' .. #tFrames .. ' alive-Lion '
        .. 'frames, floor 30 -- an empty scan and a clean scan are the same integer')
    for _, path in ipairs(tFrames) do
        local _, _, X = stand(path, false)
        local n = X.GetAbilityRSplashRadius()
        assert(n == 0, path .. ': X.GetAbilityRSplashRadius() answered ' .. tostring(n)
            .. ' with every gate OFF.  The shipped read is the ABSENT key '
            .. '`splash_radius_scepter` (GH #162); a non-zero here means either the '
            .. 'KV grew that key back or the mock started folding special_bonus_* '
            .. 'into a no-base entry.  Either way the deadness proof in §1.2 and '
            .. 'the corrected sentence in X.lion_ShouldCashUltAtWeakest are stale.')
    end
end

tests['§1.2 with nRadius 0 the AoE count cannot leave its seed -- measured'] = function()
    -- The exit seeds nMaxAoeCount at 1 and only advances on a strict `>`, and
    -- its inner term is J.IsInRange( npcEnemy, nEnemy, nRadius ).  With
    -- nRadius == 0 (§1.1) that term is `GetUnitToUnitDistance(a,b) <= 0`, true
    -- only for a unit coincident with npcEnemy.  MEASURED, not assumed: across
    -- the whole corpus no enemy hero has a second enemy hero at distance <= 0.
    local nPairs, nCoincident = 0, 0
    for _, path in ipairs(lion_frames()) do
        local _, bot = stand(path, false)
        local tEnemies = bot:GetNearbyHeroes(1600, true, BOT_MODE_NONE)
        for _, a in pairs(tEnemies) do
            local c = 0
            for _, b in pairs(tEnemies) do
                if GetUnitToUnitDistance(a, b) <= 0 then c = c + 1 end
            end
            nPairs = nPairs + 1
            if c > 1 then nCoincident = nCoincident + 1 end
        end
    end
    assert(nPairs >= 30, 'only ' .. nPairs .. ' enemy handles swept, floor 30 -- '
        .. 'the zero below has to be a reading, not an empty loop')
    assert(nCoincident == 0, nCoincident .. ' enemy heroes now carry a second enemy '
        .. 'at distance <= 0.  Hero collision used to make that impossible, which '
        .. 'is what makes `nRadius == 0 => nAoeCount <= 1` a proof rather than a '
        .. 'guess.  The scepter AoE exit may be reachable on shipped defaults now.')
end

tests['§1.3 the exit still carries the floors the deadness proof is against'] = function()
    local body = consider_r_body(read_file(SRC))
    assert(body:find('local nMaxAoeCount = 1'),
        'the AoE count no longer seeds at 1 -- §1.2 proves `nAoeCount <= 1` and '
        .. 'that only kills the exit while the seed is at or above 1')
    assert(body:find('nMaxAoeCount >= 4') and body:find('nMaxAoeCount >= 3'),
        'the AoE acceptance floors moved off 4 / 3.  §1.2 proves the count cannot '
        .. 'exceed 1 on shipped defaults; a floor of 1 would make the exit live '
        .. 'and the corrected sentence in X.lion_ShouldCashUltAtWeakest wrong again.')
    assert(body:find('nRadius%s*=%s*X%.GetAbilityRSplashRadius%(%)'),
        'the AoE radius no longer comes from X.GetAbilityRSplashRadius -- §1.1 '
        .. 'measures that function and nothing else')
end

tests['§1.4 the corrected sentence is in the tree and the false one is gone'] = function()
    local src = read_file(SRC)

    -- The false sentence is QUOTED by the correction that retires it, so
    -- "absent" is the wrong assertion and would force the record to be
    -- paraphrased away.  The right one: it survives exactly once, and that one
    -- occurrence is inside the block that calls it false.
    local nSaid, at = 0, nil
    for i in src:gmatch('()whose only reachable exit is the scepter AoE') do
        nSaid = nSaid + 1
        at = i
    end
    assert(nSaid == 1, 'the retired sentence appears ' .. nSaid .. ' times in ' .. SRC
        .. ', expected exactly 1 (the quotation inside its own correction).  '
        .. 'GH #162 already proved the scepter AoE exit dead on shipped defaults; '
        .. 'see §0.1.')
    assert(src:sub(at, at + 600):find('SENTENCE IS FALSE'),
        'the surviving occurrence of the retired sentence is no longer inside the '
        .. 'block that calls it false -- it reads as a live claim again')

    assert(src:find('block has NO reachable exit at all'),
        'the corrected sentence left ' .. SRC .. ' -- it is the (b)/(c) argument '
        .. 'for `lionultcash`, not decoration')
end

-- ---------------------------------------------------------------- section 2 --
-- The corpus limit, asserted WITH ITS CAUSE so a growing corpus says so.

tests['§2 three independent reasons the DECISION is undrivable offline'] = function()
    local tFrames = lion_frames()
    local nScepter, nBestCluster, nKeyReads = 0, 0, 0
    local sBest = ''
    for _, path in ipairs(tFrames) do
        local _, bot = stand(path, false)
        if bot:HasScepter() then nScepter = nScepter + 1 end

        local hR = bot:GetAbilityByName(FINGER)
        if hR ~= nil then
            nKeyReads = nKeyReads + 1
            assert(hR:GetSpecialValueInt('splash_radius') == 0
                and hR:GetSpecialValueInt('splash_radius_scepter') == 0,
                path .. ': a splash key started answering.  `splash_radius` is a '
                .. 'NO-BASE entry and `splash_radius_scepter` is absent; both zeros '
                .. 'are the ENGINE\'s answer (GH #162), and if either moved, '
                .. '`lionsplash` has a frame for the first time.')
            assert(hR:GetCastRange() == CAST_RANGE,
                path .. ': Finger of Death cast range is now ' .. hR:GetCastRange()
                .. ', not ' .. CAST_RANGE .. ' -- every band figure in this file is '
                .. 'stated against that number')
        end

        local tEnemies = bot:GetNearbyHeroes(1600, true, BOT_MODE_NONE)
        for _, a in pairs(tEnemies) do
            local c = 0
            for _, b in pairs(tEnemies) do
                if GetUnitToUnitDistance(a, b) <= SPLASH then c = c + 1 end
            end
            if c > nBestCluster then nBestCluster, sBest = c, path end
        end
    end
    assert(nKeyReads >= 30, 'only ' .. nKeyReads .. ' Finger handles read, floor 30')
    assert(nScepter == 0, nScepter .. ' corpus frames now give Lion a scepter (was 0 '
        .. 'of ' .. #tFrames .. ' on 2026-09-11).  Reason (ii) in §0.2 is gone: the '
        .. 'scepter AoE exit just became drivable, which is a TARGET for this stream.')
    assert(nBestCluster <= 2, 'the densest enemy cluster inside the ' .. SPLASH
        .. '-unit splash is now ' .. nBestCluster .. ' (' .. sBest .. '), was 2.  The '
        .. 'exit\'s own floor is 3, so a cluster of 3 means the DECISION can be '
        .. 'driven end to end for the first time -- stop paying injections and '
        .. 'drive the frame.')
end

-- ---------------------------------------------------------------- section 3 --
-- Gate OFF is byte-for-byte the shipped predicate, driven over every real
-- (frame, enemy) pair rather than argued from the helper's shape.

tests['§3 unarmed, the helper returns the shipped answer on every corpus pair'] = function()
    local nPairs = 0
    for _, path in ipairs(lion_frames()) do
        local J, bot, X = stand(path, false)
        for _, e in pairs(bot:GetNearbyHeroes(CAST_RANGE + KILL_BAND, true, BOT_MODE_NONE)) do
            local bShipped = J.IsInRange(bot, e, CAST_RANGE + AOE_SLACK)
            local bGot = X.lion_IsUltAoeTargetInReach(bot, e, CAST_RANGE, bShipped)
            assert(bGot == bShipped, path .. ' / ' .. e:GetUnitName()
                .. ': gate OFF answered ' .. tostring(bGot) .. ' where the shipped '
                .. 'predicate says ' .. tostring(bShipped) .. '.  Gate-off equivalence '
                .. 'is the whole claim that this lands dark.')
            nPairs = nPairs + 1
        end
    end
    assert(nPairs >= 30, 'only ' .. nPairs .. ' (frame, enemy) pairs swept, floor 30 '
        .. '-- a green equivalence over an empty sweep is not equivalence')
end

-- ---------------------------------------------------------------- section 4 --
-- The armed leg, driven on real frames with NO injection: it refuses exactly
-- the band and nothing else.

tests['§4 armed refuses exactly the band, on 4 real (frame, enemy) pairs'] = function()
    local nPairs, nBand, nFlip = 0, 0, 0
    local tFlipFrames = {}
    for _, path in ipairs(lion_frames()) do
        local J, bot, X = stand(path, true)
        for _, e in pairs(bot:GetNearbyHeroes(CAST_RANGE + KILL_BAND, true, BOT_MODE_NONE)) do
            nPairs = nPairs + 1
            local d = GetUnitToUnitDistance(bot, e)
            local bShipped = J.IsInRange(bot, e, CAST_RANGE + AOE_SLACK)
            local bArmed = X.lion_IsUltAoeTargetInReach(bot, e, CAST_RANGE, bShipped)

            -- DIRECTION, checked on every pair rather than asserted once: the
            -- armed leg may only turn a true into a false.
            assert(not bArmed or bShipped, path .. ' / ' .. e:GetUnitName()
                .. ': armed accepted a candidate the shipped predicate refused. '
                .. 'The lever is declared one-way (armed subset of shipped).')

            if d > CAST_RANGE and d <= CAST_RANGE + AOE_SLACK then
                nBand = nBand + 1
                assert(bShipped and not bArmed, path .. ' / ' .. e:GetUnitName()
                    .. ' sits in the band at ' .. string.format('%.1f', d)
                    .. ' but shipped=' .. tostring(bShipped) .. ' armed='
                    .. tostring(bArmed) .. ' -- the band IS the refusal set')
            end
            if bShipped ~= bArmed then
                nFlip = nFlip + 1
                tFlipFrames[#tFlipFrames + 1] = path .. ' (' .. e:GetUnitName()
                    .. ' @ ' .. string.format('%.1f', d) .. ')'
            end
        end
    end
    assert(nPairs >= 30, 'only ' .. nPairs .. ' pairs swept, floor 30')
    -- ⭐ This is the ONE number in this file that is a conclusion rather than a
    -- corpus size, so it is a floor and not a pin: the claim is "the predicate
    -- discriminates on real frames", and the corpus growing can only help it.
    -- Recorded reading when this landed (2026-09-11): 4 flips on 4 distinct
    -- frames, out of 44 pairs over 42 alive-Lion frames.  Quote that from here;
    -- do not re-pin it.
    assert(nFlip >= 1, 'the armed leg flipped ' .. nFlip .. ' of ' .. nPairs
        .. ' real (frame, enemy) pairs.  It was 4 when this landed.  A DROP to 0 '
        .. 'means the discriminator went blind -- either every enemy left the band '
        .. '(900, 1050] or J.IsInRange stopped answering -- and §4 would then be '
        .. 'green for the reason that makes it worthless.')
    assert(nFlip == nBand, 'flips ' .. nFlip .. ' but band members ' .. nBand
        .. ' -- the refusal set must be exactly the band: ' ..
        table.concat(tFlipFrames, ', '))
end

-- ---------------------------------------------------------------- section 5 --
-- The pullcad guard and the wiring tripwires.

tests['§5 the gate does not name lionsplash, and is read at exactly one site'] = function()
    local src  = read_file(SRC)
    local code = code_only(src)

    local nId = 0
    for _ in code:gmatch("IsSoakCandidate%(%s*'" .. CAND .. "'%s*%)") do nId = nId + 1 end
    assert(nId == 1, "'" .. CAND .. "' is read at " .. nId .. ' EXECUTING gate sites, '
        .. 'expected 1 (inside X.' .. HELPER .. ' only)')

    assert(src:find('function%s+X%.' .. HELPER .. '%s*%('),
        'X.' .. HELPER .. ' is gone from ' .. SRC)

    -- The predicate body, isolated: the dependency on `lionsplash` is a
    -- promote-time ATOM in queue.json and must not be code.  Counting by
    -- OCCURRENCE, not by line -- a line-granular count reads `f(a) and f(b)` as
    -- one call and lets a second one through (the M5 lesson, 2026-09-11).
    local from = src:find('function%s+X%.' .. HELPER .. '%s*%(')
    local rest = src:sub(from)
    local to = rest:find('\nend\n')
    assert(to, 'X.' .. HELPER .. ' has no closing end')
    local body = rest:sub(1, to)
    assert(not body:find(OTHER_CAND, 1, true),
        'X.' .. HELPER .. " names '" .. OTHER_CAND .. "'.  A gate written as "
        .. "IsSoakCandidate('" .. CAND .. "') and IsSoakCandidate('" .. OTHER_CAND
        .. "') freezes FALSE the day either id is promoted, while "
        .. 'check_armed_wiring.py still calls it WIRED.  That is the pullcad trap; '
        .. 'the dependency belongs in iterations/queue.json as a promote-time atom.')

    -- and the AoE exit really routes through it, exactly once.
    local rbody = code_only(consider_r_body(src))
    local n = 0
    for _ in rbody:gmatch('X%.' .. HELPER .. '%s*%(') do n = n + 1 end
    assert(n == 1, 'X.ConsiderR calls X.' .. HELPER .. ' ' .. n .. ' times, expected 1 '
        .. '(the scepter AoE exit).  A site that stops routing through the helper '
        .. 'is a door this lever no longer closes.')
    assert(rbody:find('nCastRange%s*%+%s*' .. AOE_SLACK),
        'the shipped `nCastRange + ' .. AOE_SLACK .. '` term left X.ConsiderR -- it '
        .. 'is what the helper takes as bShippedInReach, and without it gate-off '
        .. 'equivalence (§3) is about nothing')
end

return tests

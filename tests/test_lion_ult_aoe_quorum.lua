-- [hero] The QUORUM of Lion's scepter AoE Finger exit -- the one term in that
-- exit that no landed file has ever priced.
--
-- ===========================================================================
-- §0  WHAT THIS FILE IS, AND WHAT IT IS NOT
-- ===========================================================================
--
-- bots/BotLib/hero_lion.lua X.ConsiderR ends its 团战 block with
--
--     if nBestAoeEnemy ~= nil
--         and ( nMaxAoeCount >= 4
--             or ( nMaxAoeCount >= 3 and nHP < 0.46 ) )
--
-- Two landed ids already sit on this exit: `lionraoe` (its reach term) and
-- `lionsplash` (the radius the count is taken at, GH #162).  NEITHER of them
-- touches the number 4.  This file prices that number, and it registers the
-- price as a finding rather than acting on it -- ⛔ `bots/` carries zero
-- behaviour change from this round, and the reason is §4, not caution.
--
-- ⭐ WHY IT IS WORTH A ROUND ANYWAY.  The exit is dead on shipped defaults for
-- two independent reasons, both already measured elsewhere in this tree
-- (tests/test_lion_ult_aoe_reach.lua §2): nRadius reads 0, and no corpus frame
-- gives Lion a scepter.  `iterations/queue.json:hero-58` already asks for the
-- domain of the `lionraoe` + `lionsplash` promote-time atom, i.e. it asks what
-- happens when the branch is RESURRECTED.  The quorum is the term that decides
-- how much of that resurrection is reachable -- and the answer measured below
-- is "almost none of it".  A wave bought against hero-58 without this number in
-- hand comes back "tested, no effect" with nothing raising a hand, which is the
-- failure mode AGENTS.md names by name.
--
-- ===========================================================================
-- §0.1  THE CLAIM, stated so it can be falsified
-- ===========================================================================
--
--   (1) `nAoeCount` counts members of `hNearbyEnemyList`, an ENEMY-hero list.
--       Its arithmetic ceiling is therefore the enemy team size, 5.  A quorum
--       of 4 is ceiling minus one.  This is the shape this tree has twice
--       ruled on already -- `zusfightquorum` (`>= 5` against a count whose
--       observed maximum was 4) and `zusultstrand` -- and the ruling in both
--       cases was "off-switch, not filter".
--
--   (2) The corpus agrees, and it agrees under EVERY quantifier this file can
--       build, including one deliberately much looser than the branch's own:
--       over 310 (frame, viewer-team) perspectives the densest same-team
--       cluster inside the 325-unit splash reaches 3 twenty-two times and 4
--       five times.  ⇒ the shipped quorum refuses SEVENTEEN of the twenty-two
--       occasions on which the branch's own fallback floor is met.
--       ⚠️ The first draft of this file reported 9 and 1.  That reading swept
--       `tests/fixtures` and forgot `tests/frames`, i.e. it was a reading of
--       ONE of the two corpus directories -- §3c's own enumerator assert is
--       what caught it, before the number left this container.  Quote 22/5.
--
--   (3) The fallback that does accept 3 accepts it only while `nHP < 0.46`.
--       ⚠️ This file does NOT call that clause wrong.  It is the `ultcash`
--       shape (cash the ult out before dying) and it is coherent on its own
--       terms.  What is registered here is only that the quorum question and
--       the desperation question are two questions sharing one expression, and
--       that nobody has priced the first one.
--
-- ===========================================================================
-- §0.2  HONEST BOUNDS -- read these before quoting any number below
-- ===========================================================================
--
--   A. EVERY count in §3 is an UPPER BOUND on `nAoeCount`, never `nAoeCount`
--      itself.  The real loop additionally drops magic-immune and invulnerable
--      units and requires the pivot to pass X.lion_IsUltAoeTargetInReach.  An
--      upper bound is the right direction for claim (2): if the bound reaches 4
--      five times in 310, the real count reaches it at most that often.  It is the
--      WRONG direction for any claim of the form "the branch would have fired
--      N times", and ⛔ no such claim is made.
--
--   B. §3's three quantifiers are NOT interchangeable and the loosest one is
--      not the branch's.  (a) is the branch's own (Lion-centric, the 1600 ring
--      the exit's list is drawn from); (c) is every frame from both sides and
--      no ring at all.  ⭐ They also run over DIFFERENT CORPORA: (a) and (b)
--      use the same `ls`-based enumerator as the sibling file, which does not
--      descend into `tests/fixtures/<subdir>/`; (c) uses `find`, which does.
--      All five readings at or above the quorum sit in frames (a) cannot use:
--      one in `tests/fixtures/skillstall/` (invisible to `ls`) and four in
--      `tests/frames/` on frames with no live Lion.  ⛔ Do not read (c)'s 5 as
--      contradicting the sibling file's pinned `nBestCluster <= 2`: different
--      quantifier, different corpus, and that pin is still true under its own
--      terms -- §3a re-derives it here independently rather than quoting it,
--      and gets the same 2 over the same 42 alive-Lion frames.
--
--   C. The frames are instants picked for OTHER investigations.  They bound the
--      SHAPE of the quantity, not its rate in a real Turbo teamfight, and a
--      teamfight is exactly the state fixtures are least likely to be sampled
--      in.  That is why the finding is routed to a wave request and not to a
--      helper.
--
--   D. 325 is this repo's KV snapshot (`lion_finger_of_death/splash_radius`,
--      `special_bonus_scepter = 325`), not an engine reading.  A patch that
--      moves it moves every count in §3; §2 asserts the number is still what
--      the file is written against.

package.path = 'tests/?.lua;' .. package.path

local SRC         = 'bots/BotLib/hero_lion.lua'
local UNIT        = 'npc_dota_hero_lion'

local FIXTURE_DIR = 'tests/fixtures'
local STAGED_DIR  = 'tests/frames'

local SPLASH      = 325     -- lion_finger_of_death/splash_radius under scepter
local RING        = 1600    -- the ring the exit's hNearbyEnemyList is drawn from
local QUORUM      = 4       -- the number this file exists to price
local FALLBACK    = 3       -- the same exit's own low-HP floor
local TEAM_SIZE   = 5       -- arithmetic ceiling of nAoeCount

local tests = {}

local function read_file(path)
    local fh = assert(io.open(path, 'r'), 'cannot open ' .. path)
    local body = fh:read('*a')
    fh:close()
    return body
end

--- Drop full-line Lua comments.  A census over the raw file counts the PROSE
--- ABOUT a gate as a gate; this file's §4 would otherwise be satisfied by its
--- own header.  (The sibling file caught exactly that on its first run.)
local function code_only(src)
    local out = {}
    for line in (src .. '\n'):gmatch('([^\n]*)\n') do
        if not line:match('^%s*%-%-') then out[#out + 1] = line end
    end
    return table.concat(out, '\n')
end

--- The same `ls`-based enumerator the sibling file uses, deliberately: §3a has
--- to be comparable with the reading that file pins, and an enumerator that saw
--- more frames would make the two numbers look like a disagreement when they
--- are a difference of corpus.
local function corpus_paths_flat()
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
        assert(n > 0, 'corpus directory ' .. dir .. ' yielded no f_*.lua frame -- '
            .. 'an empty enumerator and an empty corpus are the same integer, and '
            .. 'every zero in section 3 would be free')
    end
    table.sort(out)
    return out
end

--- The recursive enumerator.  Used ONLY by §3c, and the difference between the
--- two lists is itself asserted below so that the day `ls` starts descending
--- (or the subdirectories vanish) this file says so instead of quietly reading
--- the same corpus twice.
local function corpus_paths_deep()
    local out = {}
    local p = assert(io.popen("find " .. FIXTURE_DIR .. " " .. STAGED_DIR
        .. " -name 'f_*.lua' 2>/dev/null | sort"))
    for name in p:lines() do out[#out + 1] = name end
    p:close()
    return out
end

local function load_frame(path)
    local ok, fx = pcall(dofile, path)
    if ok and type(fx) == 'table' and type(fx.units) == 'table' then return fx end
    return nil
end

local function is_hero(u)
    return type(u.name) == 'string' and u.name:find('^npc_dota_hero_') ~= nil
end

local function alive_heroes(fx)
    local out = {}
    for _, u in ipairs(fx.units) do
        if is_hero(u) and u.alive ~= false then out[#out + 1] = u end
    end
    return out
end

local function dist(a, b)
    local dx, dy = (a.x or 0) - (b.x or 0), (a.y or 0) - (b.y or 0)
    return math.sqrt(dx * dx + dy * dy)
end

--- Densest cluster inside `SPLASH` among `tSet`, counting the pivot itself --
--- which is what the shipped loop does (`J.IsInRange(npcEnemy, npcEnemy, r)` is
--- true at every radius, and the seed `nMaxAoeCount = 1` is written for it).
local function densest(tSet)
    local best = 0
    for _, e in ipairs(tSet) do
        local c = 0
        for _, o in ipairs(tSet) do
            if dist(e, o) <= SPLASH then c = c + 1 end
        end
        if c > best then best = c end
    end
    return best
end

-- ---------------------------------------------------------------- section 1 --
-- The quorum, read off the source rather than retyped.  Everything below is
-- about this expression; if it moves, nothing below means what it says.

tests['§1 the exit still reads `>= 4`, with `>= 3` behind a health term'] = function()
    local src = code_only(read_file(SRC))

    local from = src:find('nBestAoeEnemy%s*~=%s*nil')
    assert(from, SRC .. ': the scepter AoE exit guard `nBestAoeEnemy ~= nil` is '
        .. 'gone.  Every reading in this file is about the expression that guard '
        .. 'introduces.')
    local exit = src:sub(from, from + 400)

    assert(exit:find('nMaxAoeCount%s*>=%s*' .. QUORUM),
        SRC .. ': the AoE exit no longer asks `nMaxAoeCount >= ' .. QUORUM
        .. '`.  That number IS the subject of this file -- re-read it, and the '
        .. 'corpus pricing in section 3 with it, rather than editing the constant '
        .. 'here.')
    assert(exit:find('nMaxAoeCount%s*>=%s*' .. FALLBACK),
        SRC .. ': the `>= ' .. FALLBACK .. '` fallback left the exit.  Claim (3) '
        .. 'in the header is about the two floors COEXISTING; with one gone the '
        .. 'claim is about nothing.')
    assert(exit:find('nHP%s*<%s*0%.46'),
        SRC .. ': the `nHP < 0.46` term the ' .. FALLBACK .. '-floor hangs on is '
        .. 'gone.  If the fallback became unconditional, this whole file is the '
        .. 'record of a question somebody already answered -- say so, do not '
        .. 'lower the assert.')

    -- The seed is the other half of the arithmetic: a seed of 1 with a strict
    -- `>` is what makes a one-hit splash unable to become nBestAoeEnemy, and it
    -- is why `densest()` above counts the pivot itself.
    local rbody = src:find('local%s+nMaxAoeCount%s*=%s*1')
    assert(rbody, SRC .. ': `nMaxAoeCount` no longer seeds at 1.  densest() in '
        .. 'this file counts the pivot itself precisely to match that seed; a '
        .. 'different seed makes every section 3 number off by one in a direction '
        .. 'nobody would notice.')
end

-- ---------------------------------------------------------------- section 2 --
-- The ceiling argument, and the constant the corpus readings are stated
-- against.  Both are cheap; both are load-bearing for §3's interpretation.

tests['§2 the quorum sits one below the arithmetic ceiling of its own quantity'] = function()
    local src = code_only(read_file(SRC))

    -- The counted set is an ENEMY list, so the ceiling is the enemy team size.
    assert(src:find('hNearbyEnemyList%s*=%s*J%.GetEnemyList'),
        SRC .. ': the AoE loop no longer counts over J.GetEnemyList.  The ceiling '
        .. 'argument (' .. TEAM_SIZE .. ' enemy heroes) is derived from WHAT is '
        .. 'counted; if the set changed, re-derive it.')

    assert(QUORUM == TEAM_SIZE - 1, 'the quorum ' .. QUORUM .. ' is no longer '
        .. 'ceiling minus one against a team size of ' .. TEAM_SIZE)
    assert(FALLBACK < QUORUM, 'the fallback floor is not below the quorum -- the '
        .. 'whole finding is the gap between them')

    -- The radius every count in §3 is taken at.  ⚠️ KV snapshot, not engine.
    local shapes = dofile('tests/mock/special_value_shapes.lua')
    local tLion = assert(shapes.SHAPES, 'special_value_shapes lost its SHAPES table')['lion']
    assert(tLion ~= nil, 'lion vanished from the KV snapshot')
    local tAb = tLion['lion_finger_of_death']
    assert(tAb ~= nil, 'lion_finger_of_death vanished from the KV snapshot')
    local tSplash = tAb['splash_radius']
    assert(tSplash ~= nil and tSplash.bonus ~= nil,
        'lion_finger_of_death/splash_radius vanished from the KV snapshot -- the '
        .. SPLASH .. '-unit radius every count in section 3 uses came from there')
    assert(tostring(tSplash.bonus['special_bonus_scepter']):find(tostring(SPLASH)),
        'the scepter splash radius is no longer ' .. SPLASH .. ' in the KV '
        .. 'snapshot; every cluster count in section 3 is stated against it')
end

-- ---------------------------------------------------------------- section 3 --
-- The pricing.  Three nested quantifiers, loosest last, each with the liveness
-- guard that separates "measured zero" from "measured an empty enumerator".

tests['§3a under the branch\'s own quantifier the quorum is unreachable'] = function()
    local nLionFrames, nRings, best, sBest = 0, 0, 0, ''
    for _, path in ipairs(corpus_paths_flat()) do
        local fx = load_frame(path)
        if fx ~= nil then
            local lion
            for _, u in ipairs(fx.units) do
                if u.name == UNIT and u.alive ~= false then lion = u break end
            end
            if lion ~= nil then
                nLionFrames = nLionFrames + 1
                -- the exit's own list: enemies of Lion inside the 1600 ring
                local tRing = {}
                for _, u in ipairs(alive_heroes(fx)) do
                    if u.team ~= lion.team and dist(u, lion) <= RING then
                        tRing[#tRing + 1] = u
                    end
                end
                if #tRing > 0 then nRings = nRings + 1 end
                local c = densest(tRing)
                if c > best then best, sBest = c, path end
            end
        end
    end

    -- ⭐ LIVENESS, both factors, BEFORE the reading is allowed to mean anything.
    assert(nLionFrames >= 20, 'only ' .. nLionFrames .. ' alive-Lion frames found, '
        .. 'floor 20 -- below that the reading below is about the enumerator')
    assert(nRings >= 5, 'only ' .. nRings .. ' of those frames put ANY enemy hero '
        .. 'inside the ' .. RING .. ' ring.  A maximum taken over empty sets is 0 '
        .. 'for a reason that has nothing to do with the quorum.')

    assert(best < FALLBACK, 'the densest enemy cluster inside the ' .. SPLASH
        .. '-unit splash under the branch\'s own quantifier is now ' .. best
        .. ' (' .. sBest .. ').  At ' .. FALLBACK .. ' the exit\'s low-HP fallback '
        .. 'becomes drivable offline and at ' .. QUORUM .. ' the quorum itself '
        .. 'does -- stop paying injections and drive the frame.')
end

tests['§3b dropping the ring does not reach it either'] = function()
    local nLionFrames, nExcluded, best = 0, 0, 0
    for _, path in ipairs(corpus_paths_flat()) do
        local fx = load_frame(path)
        if fx ~= nil then
            local lion
            for _, u in ipairs(fx.units) do
                if u.name == UNIT and u.alive ~= false then lion = u break end
            end
            if lion ~= nil then
                nLionFrames = nLionFrames + 1
                local tEnemies = {}
                for _, u in ipairs(alive_heroes(fx)) do
                    if u.team ~= lion.team then
                        tEnemies[#tEnemies + 1] = u
                        if dist(u, lion) > RING then nExcluded = nExcluded + 1 end
                    end
                end
                local c = densest(tEnemies)
                if c > best then best = c end
            end
        end
    end
    assert(nLionFrames >= 20, 'only ' .. nLionFrames .. ' alive-Lion frames')

    -- ⭐ LIVENESS, and this one was bought by a surviving mutant rather than
    -- foreseen.  Without it, "(b) agrees with (a)" is satisfied for free by a
    -- ring so wide that it excludes nothing -- (a) and (b) then compute the same
    -- set and agreeing is not evidence about the ring at all.  The stand's M12
    -- (RING -> 99999) survived the first version of this file for exactly that
    -- reason, and the defect was the assertion's, not the mutant's.
    assert(nExcluded >= 5, 'the ' .. RING .. ' ring excludes only ' .. nExcluded
        .. ' (frame, enemy) pairs across the corpus, floor 5.  Below that (b) is '
        .. 'not a control on (a): the two sections are measuring one set and '
        .. 'their agreement says nothing about the ring.')

    -- ⭐ The point of this section is that (a)'s reading is NOT the ring's doing.
    -- Removing the only term that could have caused it leaves it where it was.
    assert(best < FALLBACK, 'without the ' .. RING .. ' ring the densest enemy '
        .. 'cluster is now ' .. best .. '.  (a) and (b) must be re-read together: '
        .. 'a gap between them means the RING is what suppresses the count, which '
        .. 'is a different finding from the one this file registers.')
end

tests['§3c the loosest bound reaches the quorum once in the whole corpus'] = function()
    local tPaths = corpus_paths_deep()
    local nPersp, n3, n4 = 0, 0, 0
    local sFour = ''
    for _, path in ipairs(tPaths) do
        local fx = load_frame(path)
        if fx ~= nil then
            local byTeam = {}
            for _, u in ipairs(alive_heroes(fx)) do
                byTeam[u.team] = byTeam[u.team] or {}
                table.insert(byTeam[u.team], u)
            end
            -- one perspective per (frame, viewer team); the viewer's ENEMY set
            -- is the other team, which is the set the shipped loop counts over
            for _, vt in ipairs({ 2, 3 }) do
                local et = (vt == 2) and 3 or 2
                nPersp = nPersp + 1
                local c = densest(byTeam[et] or {})
                if c >= FALLBACK then n3 = n3 + 1 end
                if c >= QUORUM then n4 = n4 + 1 ; sFour = path end
            end
        end
    end

    -- ⭐ The enumerators must actually differ, or (c) is (a) wearing a hat.
    assert(#tPaths > #corpus_paths_flat(), 'the recursive enumerator found '
        .. #tPaths .. ' frames, no more than the flat one.  Section 3c exists to '
        .. 'be a LOOSER quantifier over a LARGER corpus; if the two lists agree, '
        .. 'this section is a duplicate of 3a and its numbers must not be quoted '
        .. 'as independent.')
    assert(nPersp >= 200, 'only ' .. nPersp .. ' perspectives swept, floor 200')
    assert(n3 >= 10, 'the loosest bound reaches the fallback floor only ' .. n3
        .. ' times, floor 10.  Below that the ratio this file reports is noise '
        .. 'and claim (2) has no content -- say that, do not report a ratio.')

    -- ⭐ THE READING, and why it is a RELATION and not a pin.  Recorded
    -- 2026-09-16 over 310 perspectives (155 frames): clusters of 1/2/3/4/5 seen
    -- 189/99/17/4/1 times, so the fallback floor is met 22 times and the quorum
    -- 5 -- the shipped `>= 4` refuses 17 of the 22.  The corpus only grows, and
    -- growth moves both counts, so pinning either integer would be pinning the
    -- corpus size.  What IS the finding is the GAP, so that is what is pinned:
    -- the quorum must stay at least twice as rare as the floor it sits above.
    -- ⛔ A failure here is not a reason to widen the factor.  It means the
    -- quantity stopped behaving like a ceiling, which is exactly the premise
    -- iterations/queue.json:hero-58 would be bought against.
    assert(n4 * 2 <= n3, 'perspectives reaching the quorum (' .. n4 .. ') are no '
        .. 'longer at least twice as rare as those reaching the fallback floor ('
        .. n3 .. '); it was 5 against 22 on 2026-09-16 (last quorum frame: '
        .. sFour .. ').  Re-price the `>= ' .. QUORUM .. '` term and re-read '
        .. 'hero-58 before a wave is bought against that atom.')
end

-- ---------------------------------------------------------------- section 4 --
-- Why `bots/` carries no behaviour change: the quorum is BUNDLE-ONLY.  Arming
-- any new id on it alone cannot move a decision, because the branch it sits in
-- is dead for two reasons that have nothing to do with the quorum.

tests['§4 the quorum is bundle-only, so a lone id on it would be a no-op'] = function()
    local src = code_only(read_file(SRC))

    -- (i) the radius the count is taken at is 0 unless `lionsplash` is armed --
    -- read off the helper's shape, which is what makes it structural.
    local from = src:find('function%s+X%.GetAbilityRSplashRadius%s*%(')
    assert(from, SRC .. ': X.GetAbilityRSplashRadius is gone; reason (i) for the '
        .. 'branch being dead was read off its body')
    local rest = src:sub(from)
    local body = rest:sub(1, assert(rest:find('\nend\n'),
        'X.GetAbilityRSplashRadius has no closing end'))
    assert(body:find("splash_radius_scepter", 1, true),
        'the shipped key `splash_radius_scepter` left X.GetAbilityRSplashRadius. '
        .. 'That key answering 0 is why nRadius is 0 and why the AoE loop cannot '
        .. 'count past its seed -- GH #162.')
    assert(body:find("IsSoakCandidate%s*%(%s*'lionsplash'"),
        'the `lionsplash` gate left X.GetAbilityRSplashRadius -- if the live key '
        .. 'became the default, the branch is no longer dead for reason (i) and '
        .. 'this section 4 is stale')

    -- (ii) and the exit's quorum itself still holds NO gate of its own.  This is
    -- the tripwire: the day somebody lands one, they must read §3 first.
    local qfrom = src:find('nBestAoeEnemy%s*~=%s*nil')
    assert(qfrom, 'the AoE exit guard is gone')
    local exit = src:sub(qfrom, qfrom + 400)
    assert(not exit:find('IsSoakCandidate', 1, true),
        SRC .. ': the AoE exit now carries an IsSoakCandidate call.  Landing an id '
        .. 'on the quorum is exactly what this file rules AGAINST doing alone: the '
        .. 'branch is dead for two other reasons, so such an id is BUNDLE-ONLY '
        .. '(GH #606 shape) -- check_armed_wiring.py would call it WIRED and a wave '
        .. 'would read "no effect" with nothing raising a hand.  If it is landing '
        .. 'anyway, it belongs in the same promote-time atom as `lionsplash` and '
        .. '`lionraoe`, and this assert is where that decision gets recorded.')

    -- ⛔ and the ruling must not be written as code either: a gate conditioned on
    -- a sibling id freezes FALSE the day that sibling is promoted (the pullcad
    -- trap).  The dependency lives in iterations/queue.json, as an atom.
    assert(not exit:find('lionsplash', 1, true),
        'the AoE exit names `lionsplash` in executable code.  A predicate that '
        .. 'names a sibling candidate is frozen FALSE the day the sibling is '
        .. 'promoted while every automatic reader still calls it WIRED.  The '
        .. 'dependency belongs in queue.json as a promote-time atom.')
end

return tests

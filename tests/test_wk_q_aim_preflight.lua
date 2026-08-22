-- [hero] Pre-flight for the proposed candidate `wkqaim` (queue.json: hero-1).
--
-- WHAT WAS PROPOSED
-- -----------------
-- X.ConsiderQ's last branch ("通用消耗敌人或受到伤害时保护自己", hero level >= 7,
-- enemies inside cast range + 43 = 568u) walks nEnemysHerosInRange and casts on the
-- FIRST entry.  bot:GetNearbyHeroes is distance-sorted (docs/BOT_API_REFERENCE.md
-- :1229, "All return tables sorted by distance (closest first)") and
-- J.GetNearbyHeroes only filters -- it never reorders (jmz_func.lua:2517) -- so
-- "first" really is "nearest".  The two branches above it each express a
-- preference (killability; biggest threat), so the proposal was to give the
-- catch-all one too: prefer the lowest-health enemy in the ring.
--
-- WHY THAT CANDIDATE WAS NOT WRITTEN
-- ----------------------------------
-- Two independent reasons, and this file machine-checks both.
--
--   (1) SUPPLY.  The catch-all is the LAST of nine branches competing for one
--       14-second ability.  The shipped build (tAllAbilityBuildList) leaves
--       Wraithfire Blast at rank 1 -- 14s cooldown -- from hero level 2 all the
--       way to level 11, and GH #84's level census read a turbo high-water of 19
--       across 210 hero-slots, so rank 1 is what WK actually plays with for most
--       of a turbo game.  Section 3 pins that build fact.
--
--       Measured on real frames: across this repo's fixture library, EVERY frame
--       that has a living Wraith King with two or more living enemies inside 568u
--       has Wraithfire Blast either unlearned or on cooldown.  Not one frame
--       reaches the branch at all.  Section 1 is that scan, written as a tripwire.
--
--   (2) SIBLING, UPSTREAM.  Fixing aim in the catch-all alone would not change the
--       combat frames it was proposed for.  ConsiderQ takes the nearest entry of
--       nEnemysHerosInRange in THREE places, and the one immediately above the
--       catch-all ("受到伤害时保护自己", level >= 6) fires on exactly the frames
--       where WK was recently damaged -- i.e. the fights.  Whatever the catch-all
--       would have aimed better, that branch has already cast.  This is the
--       liondrain/liondrainstop shape (GH #97) with the sibling UPSTREAM and
--       unarmed, so it takes the frames unconditionally.  Section 2 pins the
--       branch order.
--
-- WHAT THIS FILE IS FOR, GOING FORWARD
-- ------------------------------------
-- Section 1 is deliberately a TRIPWIRE, not a census equality.  It asserts a
-- universal ("no frame in the library reaches the branch"), so adding fixtures can
-- only ever strengthen it -- and the day a fixture DOES reach it, this test turns
-- red and names the frame, which is precisely the real frame `wkqaim` would need.
-- That is the opposite of pinning the corpus size as an equation, which GH #106
-- filed as a hazard.
--
-- HONEST BOUNDS -- READ BEFORE QUOTING ANY NUMBER FROM HERE
--   * The fixture library is a CURATED set of frames, cut for other
--     investigations.  It is not a random sample of turbo play.  A zero here is
--     EXISTENCE-negative on a biased sample; it is NOT a density estimate, and it
--     does not retire the corpus scan that queue.json hero-1 asked for (153 games
--     with .dem from the 2026-08-22 wave).  This is the stream's standing §Y.2
--     limit in its local form: a desk or fixture read can show EMPTY, it cannot
--     show RARE.
--   * The ring below ignores vision.  The engine's GetNearbyHeroes is
--     vision-limited; counting every living enemy regardless of who can see it
--     makes each ring an UPPER bound, so "no frame reaches the branch" is measured
--     against a ring that is at least as large as the one the bot would see.  The
--     conclusion survives the approximation in the safe direction.
--   * Ability anchors (525 cast range, 95/110/125/140 mana, 14/12/10/8s cooldown,
--     Reincarnation 220/110/0 mana) are RECORDED from
--     https://www.dota2.com/datafeed/herodata?language=english&hero_id=42, read
--     2026-08-22.  This test cannot reach the network.  They are used only to
--     decide affordability; the supply conclusion below rests on cooldown and
--     ability level, which come off the frames themselves.

package.path = 'tests/?.lua;' .. package.path

local WK = 'npc_dota_hero_skeleton_king'
local SRC = 'bots/BotLib/hero_skeleton_king.lua'

-- Recorded 2026-08-22 from the live datafeed (hero_id 42).  See HONEST BOUNDS.
local Q_MANA = { 95, 110, 125, 140 }
local R_MANA = { 220, 110, 0 }
local Q_CAST_RANGE = 525
-- X.ConsiderQ's own ring: J.GetNearbyHeroes(bot, nCastRange + 43, ...).
local RING = Q_CAST_RANGE + 43

local function read_file(path)
    local fh = assert(io.open(path, 'r'), 'cannot open ' .. path)
    local body = fh:read('*a')
    fh:close()
    return body
end

local function fixture_files()
    local files = {}
    local p = assert(io.popen('ls tests/fixtures'))
    for line in p:lines() do
        if line:match('^.+%.lua$') then files[#files + 1] = 'tests/fixtures/' .. line end
    end
    p:close()
    table.sort(files)
    return files
end

local function dist(a, b)
    local dx, dy = a.x - b.x, a.y - b.y
    return math.sqrt(dx * dx + dy * dy)
end

local function ability(unit, name)
    for _, a in ipairs(unit.abilities or {}) do
        if a.name == name then return a end
    end
    return nil
end

-- One row per (fixture, living Wraith King) with two or more living enemies in the
-- ring.  `castable` reproduces the guard ConsiderQ actually runs before any branch
-- is reached: abilityQ:IsFullyCastable() and not X.ShouldSaveMana(abilityQ).
local function scan()
    local rows, wk_frames, ring_hist = {}, 0, {}
    for _, path in ipairs(fixture_files()) do
        local ok, fx = pcall(dofile, path)
        if ok and type(fx) == 'table' and type(fx.units) == 'table' then
            for _, me in ipairs(fx.units) do
                if me.name == WK and me.alive then
                    wk_frames = wk_frames + 1
                    local ring = {}
                    for _, u in ipairs(fx.units) do
                        if u.name:match('^npc_dota_hero_') and u.team ~= me.team and u.alive
                            and dist(u, me) <= RING
                        then
                            ring[#ring + 1] = u
                        end
                    end
                    ring_hist[#ring] = (ring_hist[#ring] or 0) + 1
                    if #ring >= 2 then
                        table.sort(ring, function(a, b) return dist(a, me) < dist(b, me) end)
                        local q = ability(me, 'skeleton_king_hellfire_blast')
                        local r = ability(me, 'skeleton_king_reincarnation')
                        local qlv = (q and q.level) or 0
                        local reason = nil
                        if qlv < 1 then
                            reason = 'Wraithfire Blast unlearned'
                        elseif (q.cd or 0) > 0 then
                            reason = string.format('Wraithfire Blast on cooldown (%.1fs)', q.cd)
                        elseif me.mp < Q_MANA[qlv] then
                            reason = string.format('mana %d < cost %d', me.mp, Q_MANA[qlv])
                        elseif r and (r.level or 0) >= 1 and (r.cd or 99) <= 3.0
                            and me.mp - Q_MANA[qlv] < R_MANA[r.level]
                        then
                            -- X.ShouldSaveMana: hold enough for Reincarnation.
                            reason = 'X.ShouldSaveMana holds mana for Reincarnation'
                        end
                        local weakest = ring[1]
                        for _, u in ipairs(ring) do
                            if u.hp < weakest.hp then weakest = u end
                        end
                        rows[#rows + 1] = {
                            file = path:gsub('.*/', ''),
                            time = fx.time,
                            hero_level = me.level,
                            q_level = qlv,
                            blocked_by = reason,
                            nearest = ring[1].name,
                            weakest = weakest.name,
                            ring = #ring,
                        }
                    end
                end
            end
        end
    end
    return rows, wk_frames, ring_hist
end

-- Parse the shipped ability build so section 3 reads the real table rather than a
-- copy of it.  Index 1 is Wraithfire Blast (the file's own ABILITY INDEX MAP).
local function shipped_builds(src)
    local block = src:match('local tAllAbilityBuildList = (%b{})')
    assert(block, 'tAllAbilityBuildList not found in ' .. SRC)
    local builds = {}
    for row in block:gmatch('%b{}') do
        local order = {}
        for n in row:gmatch('%d+') do order[#order + 1] = tonumber(n) end
        if #order > 0 then builds[#builds + 1] = order end
    end
    assert(#builds > 0, 'no build rows parsed out of tAllAbilityBuildList')
    return builds
end

-- Hero level at which `index` reaches rank `rank` in a build order, or nil.
local function level_of_rank(order, index, rank)
    local seen = 0
    for level, picked in ipairs(order) do
        if picked == index then
            seen = seen + 1
            if seen == rank then return level end
        end
    end
    return nil
end

local function consider_q_body(src)
    local body = src:match('function X%.ConsiderQ%(%)(.-)\nfunction X%.ConsiderW%(%)')
    assert(body, 'could not isolate X.ConsiderQ in ' .. SRC)
    return body
end

local T = {}

-- ---------------------------------------------------------------- section 1 --
-- Real frames: does any frame in the library actually reach the catch-all?

T['section 1: the scan is not vacuous -- it sees Wraith King on real frames'] = function()
    local _, wk_frames = scan()
    -- A floor, never an equality: fixtures get added, and GH #106 filed
    -- corpus-size-as-equation as a hazard in its own right.
    assert(wk_frames >= 20,
        string.format('expected the library to carry a living Wraith King on at least 20 frames, saw %d '
            .. '-- if this dropped, the tripwire below is passing because it looked at nothing', wk_frames))
end

T['section 1: the ring geometry itself occurs -- >=2 enemies inside 568u is not the empty set'] = function()
    local rows = scan()
    assert(#rows >= 1,
        'no frame in the library has a living Wraith King with two or more living enemies inside '
        .. RING .. 'u; without one, section 1 proves nothing about the branch')
end

T['section 1 TRIPWIRE: every ring frame has Wraithfire Blast unavailable, so the branch is never reached'] = function()
    local rows = scan()
    local reachable = {}
    for _, r in ipairs(rows) do
        if r.blocked_by == nil then
            reachable[#reachable + 1] = string.format(
                '%s @t=%.1f (hero level %d, Q level %d, ring %d, nearest=%s weakest=%s)',
                r.file, r.time, r.hero_level, r.q_level, r.ring,
                r.nearest:gsub('npc_dota_hero_', ''), r.weakest:gsub('npc_dota_hero_', ''))
        end
    end
    -- This is the tripwire.  Going red here is GOOD NEWS for `wkqaim`: the frame
    -- named in the message is a real frame on which the candidate's domain is
    -- non-empty, which is exactly what queue.json hero-1 asked someone to find.
    -- Re-read the pre-flight before treating the red as a regression.
    assert(#reachable == 0, string.format(
        'the `wkqaim` domain is no longer empty in the fixture library -- %d frame(s) reach '
        .. 'X.ConsiderQ\'s catch-all with Wraithfire Blast castable:\n  %s\n'
        .. 'This does not mean something broke.  It means the pre-flight in this file is stale and '
        .. 'the candidate can now be pinned on a real frame.',
        #reachable, table.concat(reachable, '\n  ')))
end

T['section 1: each ring frame records WHICH conjunct blocked it, and it is supply every time'] = function()
    local rows = scan()
    local by_reason = {}
    for _, r in ipairs(rows) do
        local key = (r.blocked_by or 'REACHED'):gsub('%b()', '(...)')
        by_reason[key] = (by_reason[key] or 0) + 1
    end
    -- The claim under test is specifically that ABILITY SUPPLY is what empties the
    -- domain -- not the geometry, and not the level gate.  If a ring frame ever
    -- fails for a mana reason instead, the supply story in the header needs
    -- rewriting, so pin the shape rather than only the emptiness.
    local supply = (by_reason['Wraithfire Blast unlearned'] or 0)
        + (by_reason['Wraithfire Blast on cooldown (...)'] or 0)
    assert(supply == #rows, string.format(
        'expected every ring frame to be blocked by Wraithfire Blast being unlearned or on cooldown; '
        .. 'got %d of %d.  Breakdown: %s', supply, #rows, (function()
            local parts = {}
            for k, v in pairs(by_reason) do parts[#parts + 1] = string.format('%s x%d', k, v) end
            table.sort(parts)
            return table.concat(parts, '; ')
        end)()))
end

-- ---------------------------------------------------------------- section 2 --
-- Branch order: the catch-all is not the only place that takes the nearest enemy,
-- and it is the last one to get a chance.

T['section 2: ConsiderQ takes the nearest entry of nEnemysHerosInRange in more than one branch'] = function()
    local body = consider_q_body(read_file(SRC))
    local n = 0
    for _ in body:gmatch('for%s+_,%s*npcEnemy%s+in%s+pairs%(%s*nEnemysHerosInRange%s*%)') do n = n + 1 end
    assert(n >= 3, string.format(
        'expected at least 3 branches of X.ConsiderQ to walk nEnemysHerosInRange (the teamfight pick, '
        .. 'the retreat guard, the recently-damaged guard and the catch-all); found %d.  If this fell, '
        .. 'the "aim is blind in more than one place" half of the pre-flight no longer holds', n))
end

T['section 2: the recently-damaged branch is UPSTREAM of the catch-all, so it takes the combat frames'] = function()
    local body = consider_q_body(read_file(SRC))
    -- The self-defence branch: recently damaged, not retreating, level >= 6.
    local selfdef = body:find('bot:WasRecentlyDamagedByAnyHero%( 3%.0 %)%s*\n%s*and bot:GetActiveMode%(%) ~= BOT_MODE_RETREAT')
    -- The catch-all: enemies in view OR recently damaged, level >= 7.
    local catchall = body:find('#nEnemysHerosInView > 0 or bot:WasRecentlyDamagedByAnyHero%( 3%.0 %)')
    assert(selfdef, 'could not locate the recently-damaged self-defence branch in X.ConsiderQ')
    assert(catchall, 'could not locate the catch-all branch in X.ConsiderQ')
    assert(selfdef < catchall, string.format(
        'the recently-damaged branch is expected to sit ABOVE the catch-all (that is why aiming the '
        .. 'catch-all alone would not change a fight); source order says otherwise (%d vs %d)',
        selfdef, catchall))
end

T['section 2: the catch-all is the LAST branch -- nothing downstream can re-aim it'] = function()
    local body = consider_q_body(read_file(SRC))
    local catchall = assert(body:find('#nEnemysHerosInView > 0 or bot:WasRecentlyDamagedByAnyHero%( 3%.0 %)'))
    -- Counting, not just ordering: "the last cast sits after the catch-all guard"
    -- is satisfied by ANY branch appended below it, which is precisely the case
    -- this test exists to catch.  The catch-all owns exactly one cast, so anything
    -- past that is a tenth branch and the pre-flight's "nothing downstream can
    -- re-aim it" claim is stale.  (Found by mutation M7, which walked through the
    -- ordering-only version.)
    local casts_after = 0
    for pos in body:gmatch('()return BOT_ACTION_DESIRE_HIGH') do
        if pos > catchall then casts_after = casts_after + 1 end
    end
    assert(casts_after == 1, string.format(
        'expected exactly one BOT_ACTION_DESIRE_HIGH below the catch-all guard (its own); found %d.  '
        .. 'A branch has been added downstream of the catch-all, so it is no longer the last word on '
        .. 'target choice and this pre-flight must be re-read', casts_after))
end

-- ---------------------------------------------------------------- section 3 --
-- Supply, from the shipped build: how long Wraithfire Blast sits at rank 1.

T['section 3: the shipped build leaves Wraithfire Blast at rank 1 through hero level 11'] = function()
    local builds = shipped_builds(read_file(SRC))
    for i, order in ipairs(builds) do
        local rank1 = level_of_rank(order, 1, 1)
        local rank2 = level_of_rank(order, 1, 2)
        assert(rank1, string.format('build row %d never learns Wraithfire Blast at all', i))
        assert(rank2 and rank2 >= 12, string.format(
            'build row %d takes Wraithfire Blast rank 2 at hero level %s; the pre-flight\'s supply '
            .. 'argument assumes rank 1 (14s cooldown) holds through level 11, which is where GH #84\'s '
            .. 'turbo level census actually lives.  If the build changed, re-run the pre-flight',
            i, tostring(rank2)))
    end
end

T['section 3: rank 1 is the rank a turbo game actually plays with (level census cross-check)'] = function()
    local builds = shipped_builds(read_file(SRC))
    -- GH #84 read level >= 20 on 0 of 210 hero-slots, high-water 19.  The point is
    -- not the exact high-water; it is that the level at which Wraithfire Blast
    -- stops being a 14-second ability sits deep into the reachable range, so the
    -- catch-all is bidding for a scarce cast for most of the game.
    for i, order in ipairs(builds) do
        local rank4 = level_of_rank(order, 1, 4)
        assert(rank4 == nil or rank4 >= 14, string.format(
            'build row %d maxes Wraithfire Blast at hero level %s; the pre-flight assumes it is not '
            .. 'maxed until level 14 or later', i, tostring(rank4)))
    end
end

return T

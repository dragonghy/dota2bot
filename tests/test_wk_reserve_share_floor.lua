-- [hero] Soak candidate `wkidleshare` (turbo-only): the RATIO term that
-- `wksaveidle`'s own value sentence is about and that its code never had.
--
-- WHAT MADE THIS A LEVER, AND IT IS A FALSIFIED PREMISE RATHER THAN A NEW FRAME
-- ---------------------------------------------------------------------------
-- X.IsReincarnationReserveIdle's note argued the release from a RATIO -- "at
-- level 6-9 the reserve is most of the pool (220 against a 272-399 max), so
-- 'hold it always' is close to 'never cast'" -- and then bounded the lever with
-- a sentence that turns out to be false:
--
--     "Note the reserve already collapses on its own at R rank 3, where
--      Reincarnation is FREE ... this lever is about the rank-1/2 window, not
--      about the late game."
--
-- The KV read (220/110/0) is right.  The conclusion is not, because R rank 3 is
-- ENTRY 15 of both of this file's build rows, and GH #366 is settled as (a) by
-- tests/test_skill_point_stall_frame.lua: every hero stops at 13 build points
-- plus at most one talent, and entry 15 is a wall for the rest of any game that
-- ends below level 26.  Section 5 re-derives the entry-15 fact from the file's
-- own rows rather than quoting it.
--
-- So the bound the paragraph claimed was never in the code: `wksaveidle` armed
-- releases the reserve at EVERY hero level, on an argument that only holds while
-- the reserve is most of the pool.  `wkidleshare` supplies the missing term.
--
-- ⛔ THE DOMAIN IS ZERO ON THIS CORPUS.  Section 3 DRIVES the real helpers over
-- all 33 priced frames and measures it: the shipped rule fires on 6, `wksaveidle`
-- releases 2 of them, and arming `wkidleshare` on top releases the SAME 2.  This
-- lever moves no frame here.  It is landed because what it guards against is off
-- the end of the corpus rather than absent from the game (section 4: the corpus
-- tops out at hero level 12, and its only two rank-2 frames are frames where the
-- shipped rule does not fire).  Condition (a) is requested in
-- iterations/queue.json, not claimed here.
--
-- ⚠️ READ BEFORE QUOTING ANY NUMBER FROM THIS FILE
--   * A fixture corpus is a set of instants chosen for OTHER investigations.
--     "6 of 33 fire" is a domain, not a frequency, and nothing here says how
--     often any of these shapes occurs in a game.
--   * The 0.5 floor is inside a band the corpus cannot resolve: section 4
--     measures that any floor in (0.492, 0.506] selects the same frames.  0.5 is
--     chosen because "most of the pool" means "at least half", not because the
--     corpus picked it.
--   * Section 5 CORROBORATES the entry-15 wall (zero rank-3 frames, max level
--     12); it does not prove it.  The proof is GH #366's, quoted as a registered
--     reading.

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')

local WK_SRC = 'bots/BotLib/hero_skeleton_king.lua'
local WK = 'npc_dota_hero_skeleton_king'
local Q  = 'skeleton_king_hellfire_blast'
local R  = 'skeleton_king_reincarnation'
local CAND = 'wkidleshare'
local HOST = 'wksaveidle'

-- The two frames `wksaveidle`'s own note names as its whole measured domain.
local RELEASE_FRAMES = {
    'tests/fixtures/f_114311_drow_pushguard_silent.lua',
    'tests/fixtures/f_260820_103216_cm_es_aftershock.lua',
}

local NONE = {}
local HOST_ONLY = { [HOST] = true }
local BOTH = { [HOST] = true, [CAND] = true }

local tests = {}

local function read_file(path)
    local fh = assert(io.open(path, 'r'), 'cannot open ' .. path)
    local s = fh:read('*a')
    fh:close()
    return s
end

local function fixture_files()
    local files = {}
    local p = assert(io.popen('ls tests/fixtures'))
    for line in p:lines() do
        if line:match('%.lua$') then files[#files + 1] = 'tests/fixtures/' .. line end
    end
    p:close()
    table.sort(files)
    return files
end

--- The priced corpus, split exactly as tests/test_wk_save_mana_lock_census.lua
--- section 1 splits it and for the same two reasons: a row with no abilities
--- list gives blank handles (rank 0 / cost 0 is an ABSENCE, not a zero), and a
--- DEAD row never reaches this decision in a game at all (the GH #794 ruling --
--- AbilityUsageThink refuses to call SkillsComplement unless bot:IsAlive(), and
--- X.SkillsComplement returns on J.CanNotUseAbility whose first disjunct is the
--- same test).  Reproduced here rather than imported so this file states the
--- population it measured.
local function priced_frames()
    local out = {}
    for _, path in ipairs(fixture_files()) do
        local ok, fx = pcall(dofile, path)
        if ok and type(fx) == 'table' and type(fx.units) == 'table' then
            for _, u in ipairs(fx.units) do
                if u.name == WK and u.alive ~= false and type(u.abilities) == 'table' then
                    out[#out + 1] = path
                    break
                end
            end
        end
    end
    return out
end

local function short(path) return (path:gsub('^tests/fixtures/', '')) end

--- One real frame through the real loader.  `opt.arm` is a SET of ids, so a leg
--- can arm the host alone, the candidate alone, or both -- and an id not in the
--- set must read false, which is what makes a typo arm nothing rather than
--- everything.
local function frame(path, opt)
    opt = opt or {}
    local armed = opt.arm or {}
    local J, bot = rf.load(path, WK)
    J.IsSoakCandidate = function(id) return armed[id] == true end
    if opt.nonTurbo then
        -- rf.load's install() forces turbo; undo it AFTER load, the same way
        -- tests/test_wk_reserve_idle_release.lua does.
        GetGameMode = function() return 1 end  -- luacheck: ignore
    end
    local X = rf.load_hero('skeleton_king')
    pcall(function() X.SkillsComplement() end)   -- primes the file-level nLV/abilityR
    return X, bot, J
end

--- Everything one frame contributes, read out of the REAL helpers.  Nothing here
--- re-implements the release decision -- which is also why `arm` is explicit: with
--- the HOST armed, X.ShouldSaveMana returns the POST-RELEASE answer, so reading
--- the shipped five-conjunct off it requires the host UNARMED.  The first draft of
--- this file read `shipped` off a host-armed call and counted 4 firing frames
--- instead of 6; the two it lost were exactly the two the release had flipped.
local function measure(path, arm)
    local X, bot = frame(path, { arm = arm or {} })
    local hR = bot:GetAbilityByName(R)
    local hQ = bot:GetAbilityByName(Q)
    local nMax = bot:GetMaxMana()
    return {
        path     = path,
        level    = bot:GetLevel(),
        r_rank   = hR:GetLevel(),
        r_cost   = hR:GetManaCost(),
        max_mana = nMax,
        share    = (nMax and nMax > 0) and (hR:GetManaCost() / nMax) or -1,
        -- X.ShouldSaveMana's answer AS ARMED.  With arm == NONE this is the
        -- shipped five-conjunct `bShipped`; with the host armed it is already
        -- post-release.  Section 3 reads it under NONE for exactly that reason.
        save     = X.ShouldSaveMana(hQ) and true or false,
        release  = X.IsReincarnationReserveIdle() and true or false,
        share_ok = X.IsReserveShareHigh() and true or false,
    }
end

-- ---------------------------------------------------------------------------
-- 1. Gate plumbing, DRIVEN on a real frame rather than asserted about source.
--    Unarmed and non-turbo must both be byte-for-byte the shipped answer.

tests['[section 1] unarmed and non-turbo are both no-ops on a real release frame'] = function()
    local path = RELEASE_FRAMES[1]

    -- The host's release, read at the decision: shipped says save, host-armed
    -- says do not.  That flip IS the release.
    assert(measure(path, NONE).save == true,
        short(path) .. ' must be a frame where the SHIPPED reserve rule fires; it '
        .. 'is one of the two the host\'s note is built on')
    local host_only = measure(path, HOST_ONLY)
    assert(host_only.save == false,
        short(path) .. ' is one of the two frames `' .. HOST .. '` releases; with the '
        .. 'host armed and ' .. CAND .. ' unarmed it must still release, or this '
        .. 'lever changed the host instead of narrowing it')
    assert(host_only.share_ok == true,
        'X.IsReserveShareHigh must answer true while unarmed, on every frame -- '
        .. 'that is what makes the new conjunct a no-op')

    -- armed, but outside turbo: the id is turbo-only ON ITS OWN TERMS, so that a
    -- future `wksaveidle` promote cannot leave it firing in normal mode.
    local X, bot = frame(path, { arm = { [HOST] = true, [CAND] = true }, nonTurbo = true })
    assert(X.IsReserveShareHigh() == true,
        'armed outside turbo, X.IsReserveShareHigh must still answer true; the '
        .. 'turbo guard belongs to this id and not to its host')
    assert(bot ~= nil)
end

tests['[section 1] armed, the helper is the ratio and nothing else'] = function()
    local path = RELEASE_FRAMES[1]
    local m = measure(path, BOTH)
    assert(m.share >= 0.5,
        short(path) .. ' has reserve share ' .. string.format('%.3f', m.share)
        .. '; this frame is the lever\'s own evidence base and must clear the floor')
    assert(m.share_ok == true, 'a share above the floor must answer true')

    -- Drive the other side of the floor without inventing a frame: take the same
    -- real frame and move ONE labelled operand.
    --
    -- ⚠️ WHICH operand is the whole methodological point, and the first draft got
    -- it wrong.  Dropping R's cost to its rank-2 KV value (110) looks like the
    -- natural mutation -- it is the real late-game number -- but `bShipped`'s last
    -- conjunct is `GetMana() - Q:GetManaCost() < abilityR:GetManaCost()`, so that
    -- one edit ALSO turns the shipped predicate off (271 - 95 is not < 110) and the
    -- leg would then be reading a frame where nothing fires, not a frame where the
    -- floor refused.  Raising MAX mana moves the share and nothing else: `bShipped`
    -- never reads it.  Same shape, one operand, no coupling.
    local X, bot = frame(path, { arm = { [HOST] = true, [CAND] = true } })
    local nReserve = bot:GetAbilityByName(R):GetManaCost()
    bot.GetMaxMana = function() return 500 end    -- LABELLED MUTATION: a bigger pool
    local nMax = bot:GetMaxMana()
    assert(nMax == 500 and nReserve / nMax < 0.5,
        'the staged pool must put the same real reserve under the floor for the '
        .. 'next assertions to mean anything (' .. tostring(nReserve) .. '/'
        .. tostring(nMax) .. ')')
    assert(X.IsReserveShareHigh() == false,
        'with the reserve at its rank-2 price the share falls under the floor and '
        .. 'the helper must refuse; if it does not, the ratio is not being read')
    assert(X.IsReincarnationReserveIdle() == false,
        'and the refusal must reach the release decision -- otherwise the new '
        .. 'conjunct is wired somewhere that never runs')
    assert(X.ShouldSaveMana(bot:GetAbilityByName(Q)) == true,
        'and it must reach the ANSWER: with the share under the floor the shipped '
        .. 'save stands again.  This is the only leg in the file that drives the '
        .. 'lever end to end, and it does so on one labelled operand')
end

-- ---------------------------------------------------------------------------
-- 2. The direction, as a property of the shape.  Armed, this id can only ever
--    turn a release OFF.  Measured across the whole corpus, not argued.

tests['[section 2] armed can only withdraw a release, never create one'] = function()
    local frames = priced_frames()
    assert(#frames == 33, 'the priced corpus is 33 frames, got ' .. #frames
        .. '; every count in this file is against that population, so a change '
        .. 'in it must be read before any number here is quoted')
    -- ⚠️ Read at the DECISION, not at the helper.  X.IsReincarnationReserveIdle
    -- answers on its own terms and says "idle" on 10 of the 33; only `bShipped and
    -- <helper>` changes anything, and X.ShouldSaveMana is where that conjunction
    -- lives.  A release is therefore a frame whose save answer went true -> false.
    -- The ONE illegal direction: arming a narrowing conjunct inside the host's
    -- release can only put a suppressed save BACK (false -> true).  It must never
    -- suppress a save the host alone left standing.
    local illegal, legal = {}, {}
    for _, path in ipairs(frames) do
        local before = measure(path, HOST_ONLY)
        local after  = measure(path, BOTH)
        if before.save and not after.save then illegal[#illegal + 1] = short(path) end
        if after.save and not before.save then legal[#legal + 1] = short(path) end
    end
    assert(#illegal == 0,
        'arming ' .. CAND .. ' SUPPRESSED a save on: ' .. table.concat(illegal, ', ')
        .. '.  This lever is a narrowing conjunct on the release; it can only put a '
        .. 'suppressed save back, never take a standing one away.')
    -- ⚠️ And the counter that matters is shown to be able to fire: `legal` is the
    -- lever's whole domain, measured by the SAME loop.  It is 0 here (section 3),
    -- which is a reading, not a silent instrument.
    assert(#legal == 0, 'domain appeared: ' .. table.concat(legal, ', ')
        .. ' -- see section 3, which is where this count is interpreted')
end

-- ---------------------------------------------------------------------------
-- 3. THE DOMAIN, and it is zero.  Stated as a measurement so the day a frame
--    lands in it this file goes red and names it.

tests['[section 3] domain on this corpus: 6 fire, 2 release, and arming moves 0'] = function()
    local frames = priced_frames()
    local fired, released_before, released_after, moved = {}, {}, {}, {}
    for _, path in ipairs(frames) do
        -- ⚠️ THREE readings, not two, and the third is why: `fired` is the SHIPPED
        -- predicate and must be read with NOTHING armed.  Read off a host-armed
        -- call it comes back 4, because the release has already flipped the two
        -- frames this lever is about -- a count that looks like a measurement and
        -- is the answer to a different question.
        local shipped = measure(path, NONE)
        local before  = measure(path, HOST_ONLY)
        local after   = measure(path, BOTH)
        if shipped.save then fired[#fired + 1] = short(path) end
        -- A RELEASE is a shipped save the arming flipped off -- `bShipped and
        -- <helper>`, read at X.ShouldSaveMana where that conjunction lives.  The
        -- helper alone answers "idle" on 10 of the 33 and 8 of those are frames
        -- the shipped rule never fires on; counting those would inflate the
        -- host's own domain fivefold.
        if shipped.save and not before.save then
            released_before[#released_before + 1] = short(path)
        end
        if shipped.save and not after.save then
            released_after[#released_after + 1] = short(path)
        end
        if before.save ~= after.save then moved[#moved + 1] = short(path) end
    end

    assert(#fired == 6, 'the shipped reserve rule fires on 6 of the 33 priced '
        .. 'frames (the reading X.IsReincarnationReserveIdle\'s note is built on); '
        .. 'got ' .. #fired .. ': ' .. table.concat(fired, ', '))
    assert(#released_before == 2, '`' .. HOST .. '` releases 2 of those 6; got '
        .. #released_before .. ': ' .. table.concat(released_before, ', '))
    table.sort(released_before)
    assert(table.concat(released_before, ', ') ==
        short(RELEASE_FRAMES[1]) .. ', ' .. short(RELEASE_FRAMES[2]),
        'and they are the two frames the note names by name; got '
        .. table.concat(released_before, ', '))

    -- The headline, and it is a zero that CAN be non-zero: section 2's loop is
    -- the same loop and it reports the whole population, so this counter has been
    -- shown to count.
    assert(#moved == 0, 'arming ' .. CAND .. ' moved the release decision on: '
        .. table.concat(moved, ', ') .. '.  That is NEW DOMAIN -- update this '
        .. 'section, the helper note in ' .. WK_SRC .. ', and the queue row, '
        .. 'rather than loosening the assertion.')
    assert(#released_after == 2, 'and the released set is unchanged, got '
        .. #released_after)
end

-- ---------------------------------------------------------------------------
-- 4. The floor, and the band the corpus cannot resolve.

tests['[section 4] the floor sits inside a band the corpus cannot resolve'] = function()
    local frames = priced_frames()
    local shares = {}
    for _, path in ipairs(frames) do shares[#shares + 1] = measure(path, HOST_ONLY).share end
    table.sort(shares)

    -- The largest share strictly below the floor, and the smallest at or above.
    local below, above = nil, nil
    for _, s in ipairs(shares) do
        if s < 0.5 then below = s elseif above == nil then above = s end
    end
    assert(below ~= nil and above ~= nil,
        'the corpus must straddle the floor for this section to say anything; '
        .. 'it no longer does')
    assert(below < 0.5 and above >= 0.5)
    -- Any floor in (below, above] selects the same frames.  The width is the
    -- honesty: this is a 0.014-wide band, not a calibrated constant.
    assert(above - below < 0.02,
        'the indistinguishability band is now ' .. string.format('%.4f', above - below)
        .. ' wide.  The note in ' .. WK_SRC .. ' quotes it as narrow; if the corpus '
        .. 'has grown enough to resolve the floor, that note must be rewritten '
        .. 'rather than left claiming it cannot')

    -- The floor is a named constant, and the two release frames clear it.  This
    -- is the ratchet: it may be tightened by evidence, never loosened to fit.
    local X = frame(RELEASE_FRAMES[1], { arm = {} })
    assert(X.nReserveShareFloor == 0.5,
        'X.nReserveShareFloor is ' .. tostring(X.nReserveShareFloor) .. '.  "Most of '
        .. 'the pool" means at least half; a different number needs a different '
        .. 'sentence in the helper note, not a quiet edit here')
    for _, path in ipairs(RELEASE_FRAMES) do
        -- Read the arithmetic AND the real helper.  The arithmetic alone cannot see
        -- a flipped comparison (mutation stand M5): `share >= floor` recomputed here
        -- stays true however the helper is written.  Arming CAND and asking the
        -- helper is what makes this ratchet sensitive to direction.
        local armed = measure(path, BOTH)
        assert(armed.share_ok == true,
            short(path) .. ' is part of `' .. HOST .. '`\'s measured domain and the '
            .. 'armed helper now REFUSES it (share '
            .. string.format('%.3f', armed.share) .. ', floor '
            .. tostring(X.nReserveShareFloor) .. ').  Either the floor moved or the '
            .. 'comparison is inverted; an inverted floor releases only in the late '
            .. 'game, which is the one case the value argument says not to')
        local m = measure(path, HOST_ONLY)
        assert(m.share >= X.nReserveShareFloor,
            short(path) .. ' is part of `' .. HOST .. '`\'s measured domain and its '
            .. 'share (' .. string.format('%.3f', m.share) .. ') has fallen under the '
            .. 'floor.  Narrowing the host\'s own evidence base out of existence is '
            .. 'not what this lever was argued for')
    end
end

-- ---------------------------------------------------------------------------
-- 5. The falsified premise, re-derived rather than quoted: R's third point is
--    entry 15, and entry 15 is behind the GH #366 wall.

tests['[section 5] R rank 3 is entry 15 of every build row in this file'] = function()
    local src = read_file(WK_SRC)
    local rows = {}
    for row in src:gmatch('{([%d,]+)}%s*,?%s*%-%-pos') do
        local entries = {}
        for n in row:gmatch('%d+') do entries[#entries + 1] = tonumber(n) end
        if #entries == 15 then rows[#rows + 1] = entries end
    end
    assert(#rows >= 2, 'expected both 15-entry build rows in ' .. WK_SRC
        .. ', found ' .. #rows .. '; this section reads them rather than quoting '
        .. 'the note, so a row edit must be seen here')

    -- Index 6 is Reincarnation: the build rows in this file name only 1,2,3,6
    -- (the block above tAllAbilityBuildList says so) and 6 is the ultimate slot.
    for i, entries in ipairs(rows) do
        local points = {}
        for pos, idx in ipairs(entries) do
            if idx == 6 then points[#points + 1] = pos end
        end
        assert(#points == 3, 'build row ' .. i .. ' spends ' .. #points
            .. ' points on R, expected 3')
        assert(points[3] == 15, 'build row ' .. i .. ' puts R\'s THIRD point at entry '
            .. points[3] .. ', not 15.  The premise correction in ' .. WK_SRC
            .. ' rests on that 15; if it moved, re-read the correction')
        assert(points[3] > 13, 'R rank 3 is at entry ' .. points[3] .. ', which is '
            .. 'within the 13 build points GH #366 measured every hero reaching.  '
            .. 'The "rank 3 collapses the reserve" premise would be LIVE again and '
            .. 'the ⛔ blocks in ' .. WK_SRC .. ' must be revisited')
    end
end

tests['[section 5] the corpus corroborates the wall: no rank-3 frame, max level 12'] = function()
    local frames = priced_frames()
    local maxLevel, maxRank = 0, 0
    local cost_by_rank = {}
    for _, path in ipairs(frames) do
        local m = measure(path, HOST_ONLY)
        if m.level > maxLevel then maxLevel = m.level end
        if m.r_rank > maxRank then maxRank = m.r_rank end
        cost_by_rank[m.r_rank] = cost_by_rank[m.r_rank] or {}
        cost_by_rank[m.r_rank][m.r_cost] = true
    end
    assert(maxRank <= 2, 'a rank-' .. maxRank .. ' Reincarnation is now in the '
        .. 'corpus.  That is the frame GH #366\'s wall says cannot exist in play; '
        .. 'read it before trusting either the wall or this fixture')
    -- ⚠️ This is corroboration, not proof: the corpus simply does not reach far
    -- enough to test the wall.  Asserted so the bound is visible, not hidden.
    assert(maxLevel <= 12, 'the corpus now reaches hero level ' .. maxLevel
        .. '; the notes in ' .. WK_SRC .. ' say it tops out at 12, which is exactly '
        .. 'why they defer to GH #366 rather than to these frames')
    -- The KV columns, measured off the handles rather than typed in.
    for rank, costs in pairs(cost_by_rank) do
        for cost in pairs(costs) do
            if rank >= 2 then
                assert(cost == 110, 'R at rank ' .. rank .. ' reads cost ' .. cost
                    .. ', KV says 110')
            else
                assert(cost == 220, 'R at rank ' .. rank .. ' reads cost ' .. cost
                    .. ', KV says 220 (rank 0 answers the rank-1 column)')
            end
        end
    end
end

-- ---------------------------------------------------------------------------
-- 6. Source assertions: the gate names one id, the promote recipe survives, and
--    the falsified sentence does not come back.

tests['[section 6] the gate names exactly one id and keeps its own turbo guard'] = function()
    local src = read_file(WK_SRC)
    local body = src:match('function X%.IsReserveShareHigh%b()(.-)\nend')
    assert(body ~= nil, 'X.IsReserveShareHigh is gone from ' .. WK_SRC)
    assert(body:find("J.IsSoakCandidate( '" .. CAND .. "' )", 1, true),
        'the helper no longer names ' .. CAND .. '; a wave arming that string would '
        .. 'move nothing while check_armed_wiring.py still calls it wired')
    assert(body:find('J.IsModeTurbo()', 1, true),
        'the helper lost its own turbo guard.  It must not inherit one from its '
        .. 'host: a ' .. HOST .. ' promote would then leave this id live in normal mode')
    -- ⛔ the pullcad trap, in its ordinary direction.
    local n = 0
    for _ in body:gmatch('IsSoakCandidate') do n = n + 1 end
    assert(n == 1, 'the helper names ' .. n .. ' soak ids.  A gate written as a '
        .. 'conjunction of two ids freezes FALSE the day either is promoted; the '
        .. 'coupling to ' .. HOST .. ' is by CALL SITE, which survives that promote')
    assert(not body:find(HOST, 1, true),
        'the helper now mentions ' .. HOST .. ' inside its own gate')

    -- and it is actually consulted from the host.
    local rel = src:match('function X%.IsReincarnationReserveIdle%b()(.-)\nend')
    assert(rel ~= nil, 'X.IsReincarnationReserveIdle is gone')
    assert(rel:find('if not X.IsReserveShareHigh()', 1, true),
        'the release no longer consults the ratio term, so this whole file measures '
        .. 'a helper nothing calls')
end

tests['[section 6] the promote recipe is written down, because the polarity inverts it'] = function()
    local src = read_file(WK_SRC)
    local note = src:match('(%-%-%-[^\n]*PROMOTE RECIPE.-)function X%.IsReserveShareHigh')
    assert(note ~= nil,
        'the PROMOTE RECIPE block is gone from ' .. WK_SRC .. '.  This gate is '
        .. 'PERMISSIVE when unarmed, so promoting it by deleting the id from the '
        .. 'armed string DELETES the behaviour instead of shipping it.  That is the '
        .. 'one thing a future promoter cannot be allowed to rediscover.')
    assert(note:find('DELETING THE GUARD CLAUSE', 1, true),
        'the recipe no longer says what promoting this id means')
end

tests['[section 6] the falsified rank-3 premise does not come back'] = function()
    local src = read_file(WK_SRC)
    -- ⛔ FLATTEN THE COMMENT BLOCK FIRST, and this is not tidiness.  The GH #235
    -- hole in X.ShouldSaveMana's own note is that a claim SPLIT ACROSS A `---` LINE
    -- BREAK is invisible to any substring or line-by-line sweep.  The first draft of
    -- this section matched raw source, and the mutation stand's M7 -- which
    -- re-asserts the struck premise across two comment lines, the way a human
    -- rewriting the paragraph naturally would -- SURVIVED it
    -- (tools/agent/mutstand_wkidleshare.sh).  Joining comment continuations into one
    -- line before matching is what closes that, and it is the same fix
    -- tests/test_level_premise_registry.lua section 3 reaches for by scanning
    -- adjacent pairs.
    local flat = src:gsub('\n%s*%-%-%-?%s*', ' '):gsub('%s+', ' ')
    -- The exact claims, in both the shapes they stood in, written single-spaced
    -- because that is what `flat` is.  Struck 2026-09-13; both headers now carry a
    -- ⛔ block explaining why.
    for _, dead in ipairs({
        'the reserve already collapses on its own at R rank 3',
        'which is why the armed floor collapses to',
        'this lever is about the rank-1/2 window, not about the late game',
    }) do
        local hits = 0
        for _ in flat:gmatch(dead:gsub('%p', '%%%0')) do hits = hits + 1 end
        -- The strings survive ONCE each, quoted inside the correction blocks that
        -- strike them.  Two live occurrences means the claim was re-asserted.
        assert(hits <= 1, 'the struck premise "' .. dead .. '" appears ' .. hits
            .. ' times in ' .. WK_SRC .. '.  R rank 3 is entry 15 (section 5) and '
            .. 'GH #366 settled that entry 15 is a wall; re-deriving the collapse '
            .. 'is the failure this assertion exists to stop')
    end
    for _, needle in ipairs({ 'PREMISE CORRECTED 2026-09-13', 'ENTRY 15', 'GH #366' }) do
        assert(src:find(needle, 1, true),
            'the correction block no longer carries "' .. needle .. '"; a reader '
            .. 'cannot check the premise without it')
    end
end

return tests

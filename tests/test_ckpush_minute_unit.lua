-- [strategy] `ckpush` -- SECONDS-PER-MINUTE, and the round where the SHAPE and
-- the DOMAIN PRICE disagreed about the direction of the repair.
--
-- WHAT THE DEFECT IS
-- ------------------
-- bots/BotLib/hero_chaos_knight.lua X.ConsiderR gates its push branch on
--
--     if J.IsPushing( bot ) and DotaTime() > 8 * 30
--
-- `* 30` is the only seconds-per-minute constant in bots/ that is not 60.
-- Section 1 counts it rather than asserting it. Counting rule: comment-stripped
-- lines under bots/**/*.lua, pattern `DotaTime() <op> N * <mult>`. BEFORE this
-- commit that read 127 sites at `* 60` against exactly 2 at `* 30` -- 127:2 --
-- and those 2 were THE SAME expression: this one and its rubick twin in
-- bots/FunLib/rubick_hero/chaos_knight.lua. The correct twin is therefore not
-- one site but twelve (every other BotLib `and DotaTime() > N * 60` gate).
-- Inherited verbatim from the upstream OHA snapshot (74727e4:485).
--
-- AFTER this commit the live count is 1, because the site below now reads its
-- threshold from X.GetPushCommitTime instead of from an inline literal. Section
-- 1 asserts the 1 and names it; section 2 asserts that the resolver still hands
-- back the shipped 8 * 30 when the gate is off, which is where the vanished
-- second site actually went.
--
-- THE MAIN FINDING, WHICH IS NOT THE DEFECT
-- -----------------------------------------
-- A shape this clean normally settles its own repair: write 60, close the issue.
-- Here the domain price says otherwise, and it says so with a number. Over the
-- 27 fixture frames that carry a chaos_knight (24 of them alive; the dumper
-- omits the ability table for the 3 dead ones), Phantasm is first LEARNED at
-- t = 306.0s and NO frame at or below 240s carries it at all (section 4). So:
--
--   * the SHIPPED 240 never binds in turbo -- by the time the ultimate exists,
--     the clause is already true. It is a placeholder-shaped condition, in the
--     measured sense rather than the type-shaped sense the archive's
--     `hpbool` / `roshdist` entries used;
--   * the IDIOMATIC 480 binds hard -- 12 frames sit in the disagreement band
--     240 < t < 480 and 5 of them hold a learned Phantasm.
--
-- So "repairing the typo" is a real turbo behaviour change that REMOVES
-- push-Phantasm across the stretch where CK's ultimate first comes online. That
-- is a sign only the batch can call, which is exactly what a soak candidate is
-- for. It ships GATED (turbo + 'ckpush'), NOT as a correction.
--
-- ⚠ DIRECTION: this lever is a NARROWING (it removes casts the shipped tree
-- makes), and it is the FIRST lever in this archive whose shape and whose
-- domain price point opposite ways. Read the acceptance that way.
--
-- WHAT THIS FILE CAN AND CANNOT BUY
-- ---------------------------------
-- Condition (a) at the DECISION level is not buyable from today's corpus and
-- section 3 proves it rather than skipping it: the only two chaos_knight-SUBJECT
-- fixtures sit at t = 37.3 and t = 192.0, both BELOW 240, where the two
-- constants answer identically. That is the `0EQUIV` failure mode read forward
-- instead of backwards -- a parallel stand whose corpus cannot make its two legs
-- disagree reports "nothing", in the same green as "the same". So section 3
-- asserts the AGREEMENT it can actually see, and section 5 does the separating
-- on an ANNOTATED clock, labelled as annotated.
--
-- The frames that would buy (a) are requested on iterations/queue.json
-- (strategy-38): a chaos_knight-subject instant in 240 < t < 480 with Phantasm
-- learned, pushing, near an enemy tower with allied creeps.

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')

local tests = {}

local SRC = 'bots/BotLib/hero_chaos_knight.lua'
local TWIN = 'bots/FunLib/rubick_hero/chaos_knight.lua'

-- The two chaos_knight-SUBJECT frames in the archive. Both below 240.
local CK_SUBJECT_FRAMES = {
    'tests/fixtures/f_013254_ck_rescue_trade.lua',
    'tests/fixtures/f_231411_ck_zoned.lua',
}

local function read_file(path)
    local fh = assert(io.open(path, 'r'), 'cannot open ' .. path)
    local src = fh:read('*a')
    fh:close()
    return src
end

local function lua_files_under(dir)
    local names = {}
-- Farm-only files are skipped: `bots/Customize/` holds two gitignored,
-- TRANSIENT switch files that every gate test in this suite creates and
-- deletes, so listing one and then reading it is a race whose red names a
-- file this test has no business reading (GH #365 §2 / #438; hero backlog
-- -79 measured the population at 18 walks in 18 files).  The rule lives in
-- tests/lua_source_scan.lua and is referenced, never copied -- the path
-- literal is load-bearing text and a second copy is the defect.
    local ph = io.popen('find ' .. dir .. ' -name "*.lua" '
        .. require('lua_source_scan').FARM_ONLY_FIND_CLAUSE .. ' 2>/dev/null')
    assert(ph ~= nil, 'could not enumerate ' .. dir)
    for line in ph:lines() do names[#names + 1] = line end
    ph:close()
    assert(#names > 0, 'enumerating ' .. dir .. ' produced nothing')
    return names
end

-- Load a real frame, arm the ids given, and hand back the REAL hero module.
local function ck_module(frame, armed_ids, turbo)
    local J = rf.load(frame)
    local armed = {}
    for _, id in ipairs(armed_ids or {}) do armed[id] = true end
    J.IsSoakCandidate = function(id) return armed[id] == true end
    J.IsModeTurbo = function() return turbo ~= false end
    return rf.load_hero('chaos_knight'), J
end

-- ---------------------------------------------------------------------------
-- 1. [census] the discriminant, counted over the shipped tree. One-sided on the
--    60s (the tree grows), EXACT on the 30s (a third one is drift, and the
--    whole ruling below rests on there being no house convention here).

tests['[census] every DotaTime minute gate multiplies by 60, except two'] = function()
    local by_sixty, by_thirty, thirty_files = 0, 0, {}
    for _, path in ipairs(lua_files_under('bots')) do
        local src = read_file(path)
        for line in src:gmatch('[^\n]+') do
            local code = line:match('^(.-)%-%-') or line
            for mult in code:gmatch('DotaTime%s*%(%s*%)%s*[<>=]+%s*%-?[%d%.]+%s*%*%s*(%d+)') do
                if mult == '60' then
                    by_sixty = by_sixty + 1
                elseif mult == '30' then
                    by_thirty = by_thirty + 1
                    thirty_files[#thirty_files + 1] = path
                end
            end
        end
    end

    assert(by_sixty >= 127, string.format(
        'the N*60 population fell to %d (recorded 127). This ruling rests on '
        .. '"* 60 is the house idiom"; if that population shrank, re-derive it.',
        by_sixty))
    -- Was 2 before this commit; the gated site now resolves through
    -- X.GetPushCommitTime, so only the registered-not-fixed twin is left inline.
    assert(by_thirty == 1, string.format(
        'expected exactly 1 inline `DotaTime() <op> N * 30` site (the rubick '
        .. 'twin), found %d. A NEW one would mean `* 30` is a convention after '
        .. 'all, and the "typo" reading has to be re-argued, not patched; a '
        .. 'ZERO means somebody repaired the twin without reading its domain '
        .. 'price.', by_thirty))

    local seen = {}
    for _, p in ipairs(thirty_files) do seen[p] = true end
    assert(seen[TWIN], TWIN .. ' is no longer the remaining `* 30` site')
    assert(not seen[SRC], SRC .. ' has an inline `* 30` minute gate again -- '
        .. 'the gated resolver was bypassed or reverted')
end

tests['[census] the twin is registered-not-fixed, and its domain is why'] = function()
    -- 0ROSHTWIN precedent: one lever per round, and the second site is left
    -- alone ON PURPOSE. `corpus_hero_census.py --hero rubick` answers
    -- DOMAIN-EMPTY (files=0, games=0, exit 3), so condition (a) is
    -- unbuyable for the twin by construction -- it is not a backlog item that
    -- was forgotten, it is one that cannot be validated here.
    local src = read_file(TWIN)
    assert(src:find('DotaTime%(%) > 8 %* 30'),
        'the rubick twin moved; re-read the domain price before touching it')
    -- And the twin must NOT have picked up the gate: one lever, one site.
    assert(not src:find('ckpush', 1, true),
        'the rubick twin now names ckpush -- that is two sites on one lever')
end

-- ---------------------------------------------------------------------------
-- 2. [gate] the resolution point, driven on a real frame. Gate-off must be the
--    shipped VALUE, and only turbo + this exact id may move it.

tests['[gate] unarmed is the shipped value, 8 * 30'] = function()
    local X = ck_module(CK_SUBJECT_FRAMES[1], {}, true)
    assert(X.GetPushCommitTime() == 8 * 30, string.format(
        'gate-off returned %s, not the shipped 8 * 30 = 240',
        tostring(X.GetPushCommitTime())))
end

tests['[gate] armed in turbo returns the idiomatic 8 * 60'] = function()
    local X = ck_module(CK_SUBJECT_FRAMES[1], { 'ckpush' }, true)
    assert(X.GetPushCommitTime() == 8 * 60, string.format(
        'armed gate returned %s, not 8 * 60 = 480',
        tostring(X.GetPushCommitTime())))
end

tests['[gate] outside turbo the repair stays off'] = function()
    local X = ck_module(CK_SUBJECT_FRAMES[1], { 'ckpush' }, false)
    assert(X.GetPushCommitTime() == 8 * 30, 'gate escaped the turbo condition')
end

tests['[off-candidate] an unrelated armed id does not move it'] = function()
    local X = ck_module(CK_SUBJECT_FRAMES[1], { 'roshdist', 'slotdust', 'tpwatch' }, true)
    assert(X.GetPushCommitTime() == 8 * 30,
        'some other candidate id moved this gate')
end

-- ---------------------------------------------------------------------------
-- 3. [decision domain] what today's corpus can actually see -- AGREEMENT, and
--    the reason it is agreement rather than a passing comparison.

tests['[decision domain] both CK-subject frames sit below BOTH constants'] = function()
    for _, frame in ipairs(CK_SUBJECT_FRAMES) do
        local Xoff = ck_module(frame, {}, true)
        local t = DotaTime()  -- luacheck: ignore
        assert(t < 240, string.format(
            '%s is at t=%.1f, which is no longer below the shipped 240. It can '
            .. 'now separate the two legs -- promote it into section 5 and stop '
            .. 'annotating the clock.', frame, t))
        -- Both legs answer the SAME thing here, and the answer is "not yet".
        assert((t > Xoff.GetPushCommitTime()) == false, 'shipped leg opened early')
        local Xon = ck_module(frame, { 'ckpush' }, true)
        assert((t > Xon.GetPushCommitTime()) == false, 'armed leg opened early')
    end
end

tests['[decision domain] and the whole decision agrees too, for a second reason'] = function()
    -- Not merely "the clause agrees": on these two frames X.ConsiderR bails on
    -- its FIRST line, because Phantasm is unlearned (section 4 measures that no
    -- frame at or below 240 has it). So even a corpus that put a CK subject at
    -- t = 300 would still need a LEARNED ult to separate the decision.
    for _, frame in ipairs(CK_SUBJECT_FRAMES) do
        local Xoff = ck_module(frame, {}, true)
        local Xon = ck_module(frame, { 'ckpush' }, true)
        local dOff = Xoff.ConsiderR()
        local dOn = Xon.ConsiderR()
        assert(dOff == dOn, string.format(
            '%s now separates the two legs at the decision level (%s vs %s) -- '
            .. 'that is good news, and it means condition (a) is buyable here.',
            frame, tostring(dOff), tostring(dOn)))
    end
end

-- ---------------------------------------------------------------------------
-- 4. [domain price] the reading the ruling rests on, COUNTED not quoted, so it
--    self-updates into a failure the day the corpus grows past it.

local function ck_frames()
    local rows = {}
    local ph = io.popen('ls tests/fixtures/*.lua 2>/dev/null')
    assert(ph ~= nil, 'could not enumerate tests/fixtures')
    for path in ph:lines() do
        local src = read_file(path)
        local t = tonumber(src:match('time = ([%d%.]+)'))
        if t ~= nil and src:find("name = 'npc_dota_hero_chaos_knight'", 1, true) then
            -- `chaos_knight_phantasm` occurs only inside CK's own ability
            -- table, so the rank can be read off the whole file without
            -- reassembling the (two-line) unit record. A MISSING entry is not
            -- rank 0 by accident: the dumper omits the ability table for DEAD
            -- units, and 3 of these frames carry a dead chaos_knight.
            local raw = src:match("chaos_knight_phantasm', level = (%d+)")
            rows[#rows + 1] = {
                path = path, t = t,
                rank = tonumber(raw) or 0,
                dead = (raw == nil),
            }
        end
    end
    ph:close()
    return rows
end

tests['[domain price] no frame at or below the shipped 240 has Phantasm at all'] = function()
    local rows = ck_frames()
    assert(#rows >= 27, string.format(
        'chaos_knight frames fell to %d (recorded 27); the census below is '
        .. 'computed, but a shrinking corpus means re-reading it', #rows))
    local dead = 0
    for _, r in ipairs(rows) do if r.dead then dead = dead + 1 end end
    assert(dead <= 3, string.format(
        '%d chaos_knight records now carry no ability table (recorded 3, all '
        .. 'dead units). More of them means the rank read below is answering '
        .. 'about absence, not about rank.', dead))

    local early_with_ult, earliest = 0, nil
    for _, r in ipairs(rows) do
        if r.rank >= 1 then
            if earliest == nil or r.t < earliest then earliest = r.t end
            if r.t <= 8 * 30 then early_with_ult = early_with_ult + 1 end
        end
    end

    assert(earliest ~= nil, 'no chaos_knight frame carries a learned Phantasm '
        .. 'any more -- the domain price cannot be read, so do not arm this id')
    assert(early_with_ult == 0, string.format(
        '%d frame(s) at or below 240s now carry a learned Phantasm. The ruling '
        .. '"the shipped 240 never binds" is measured, not assumed: re-read it.',
        early_with_ult))
    assert(earliest > 8 * 30, string.format(
        'Phantasm is now first learned at t=%.1f, which is at or below the '
        .. 'shipped 240 -- the shipped clause binds after all', earliest))
end

tests['[domain price] the band the lever actually changes is not empty'] = function()
    local rows = ck_frames()
    local in_band, in_band_with_ult = 0, 0
    for _, r in ipairs(rows) do
        if r.t > 8 * 30 and r.t < 8 * 60 then
            in_band = in_band + 1
            if r.rank >= 1 then in_band_with_ult = in_band_with_ult + 1 end
        end
    end
    -- These two are the whole reason this ships as a lever rather than as a
    -- registered-not-fixed entry: the two constants are SEPARABLE on real
    -- frames, and separable on frames where the ultimate exists to be spent.
    assert(in_band >= 12, string.format(
        'the 240<t<480 band fell to %d chaos_knight frames (recorded 12)', in_band))
    assert(in_band_with_ult >= 5, string.format(
        'only %d band frame(s) carry a learned Phantasm (recorded 5). Below 1 '
        .. 'this lever stops being separable and becomes registered-not-fixed.',
        in_band_with_ult))
end

-- ---------------------------------------------------------------------------
-- 5. [separability, ANNOTATED] the two legs really do disagree -- shown on a
--    real chaos_knight frame with the CLOCK, and only the clock, moved into the
--    band. Labelled ANNOTATED because the archive holds no CK-subject frame
--    there; this is the assertion section 3 could not buy.

tests['[separability] ANNOTATED clock: the legs disagree across the band'] = function()
    local Xoff = ck_module(CK_SUBJECT_FRAMES[2], {}, true)
    local Xon = ck_module(CK_SUBJECT_FRAMES[2], { 'ckpush' }, true)
    -- ANNOTATED: our archive holds no chaos_knight-SUBJECT frame in this band.
    for _, t in ipairs({ 241, 306, 373.4, 423.4, 479 }) do
        assert(t > Xoff.GetPushCommitTime(),
            'shipped leg blocked at t=' .. t .. ', inside the band')
        assert(not (t > Xon.GetPushCommitTime()),
            'armed leg allowed at t=' .. t .. ', inside the band')
    end
    -- ...and agree outside it, in both directions.
    for _, t in ipairs({ 0, 192, 240 }) do
        assert((t > Xoff.GetPushCommitTime()) == (t > Xon.GetPushCommitTime()),
            'legs disagreed below the band at t=' .. t)
    end
    for _, t in ipairs({ 481, 900 }) do
        assert((t > Xoff.GetPushCommitTime()) == (t > Xon.GetPushCommitTime()),
            'legs disagreed above the band at t=' .. t)
    end
end

-- ---------------------------------------------------------------------------
-- 6. [source-parity] the gate is a SELECTION, and the branch reads it. Fails on
--    an empty corpus too, which is the point: it checks a different thing from
--    every assertion above.

tests['[source-parity] the branch reads the resolver, and nothing else moved'] = function()
    local src = read_file(SRC)
    assert(src:find('DotaTime%(%) > X%.GetPushCommitTime%(%)'),
        'the push branch no longer reads X.GetPushCommitTime')
    assert(src:find('function X%.GetPushCommitTime'),
        'X.GetPushCommitTime is gone or renamed')
    -- Exactly one resolution point for this id in the whole file.
    local n = 0
    for _ in src:gmatch("IsSoakCandidate%( 'ckpush' %)") do n = n + 1 end
    assert(n == 1, string.format(
        "'ckpush' resolves at %d places in %s; it must resolve at exactly one",
        n, SRC))
    -- And it is conjoined with turbo, not with another candidate id (the
    -- promote-kills-the-gate trap, AGENTS.md).
    assert(src:find("J%.IsModeTurbo%(%) and J%.IsSoakCandidate%( 'ckpush' %)"),
        'the ckpush gate is not the plain turbo + id conjunction any more')
end

return tests

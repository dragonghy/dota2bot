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
-- t = 306.0s and no frame at or below 240s carries it (section 4). So:
--
--   * the SHIPPED 240 does not bind IN EFFECT in turbo -- by the time a
--     Phantasm is there to be spent, the clause is already true. It is a
--     placeholder-shaped condition, in the measured sense rather than the
--     type-shaped sense the archive's `hpbool` / `roshdist` entries used;
--   * the IDIOMATIC 480 binds hard -- 12 frames sit in the disagreement band
--     240 < t < 480 and 5 of them hold a learned Phantasm.
--
-- ⚠ CORRECTED 2026-09-03 (GH #447) -- AND THE CORRECTION IS ABOUT DOMAIN, NOT
-- ARITHMETIC. The bullet above used to read "the SHIPPED 240 NEVER BINDS",
-- because section 4 saw no chaos_knight frame at or below 240 holding a learned
-- Phantasm. That is a UNIVERSAL, and its domain was the fixture archive -- about
-- one game's worth of frames. Replay-check re-asked it on all 82 games of W41
-- and it is FALSE there: 2 of 82 games learn Phantasm at or below 240s, the
-- earliest at t = 220.5s, which is 85.5s before this archive's earliest, and 38
-- snapshot frames at or below 240 carry a learned Phantasm (20 of them alive).
--
-- What SURVIVES is the weaker and genuinely different claim the ruling needs:
-- across those 82 games there is ZERO push-Phantasm casting at or below 240s.
-- "Does not bind in effect" is buyable from that corpus; "never binds" never was
-- buyable from this one. Both readings are now registered below as ARCHIVE and
-- CORPUS_W41, each carrying the name of the domain it was read on, and section 4
-- asserts the archive one AS AN ARCHIVE READING.
--
-- ⚠ AND SO THE SHAPE OF THIS ROUND'S REPAIR IS A GUARD, NOT A NUMBER. The
-- assertion that carried the universal was GREEN the whole time it was wrong,
-- and it would have stayed green forever: its domain structurally cannot contain
-- the frames that falsify it. A green whose domain cannot hold the counterexample
-- is not evidence, and the fix is not a better number -- it is section 4a, which
-- makes the two domains impossible to write as one sentence again.
--
-- So "repairing the typo" is a real turbo behaviour change that REMOVES
-- push-Phantasm across the stretch where CK's ultimate first comes online. It
-- shipped GATED (turbo + 'ckpush') rather than as a correction, precisely so
-- that sign question could be handed to the batch.
--
-- ⚠ PROMOTED 2026-09-07 (director ruling, test_set.md §FQ): turbo default, no
-- gate left, non-turbo untouched. And the ruling records WHY the batch never
-- answered the sign question and never could: the attributable effect is 1 cast
-- in 82 games (in-band cast rate 1.292 vs 1.294 per game), which no wave this
-- project can afford will separate from zero. What carried the promote is
-- condition (c) -- an intent repair with the counter-theory ("turbo rewards an
-- earlier objective commit") registered, not resolved -- plus (a) WORKING/40 and
-- eight family-level waves with no obvious negative. Sections 2, 3, 5 and 6 were
-- flipped in the same commit; each says so at its own head.
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

-- ---------------------------------------------------------------------------
-- THE TWO REGISTERED READINGS. They are kept apart on purpose: GH #447 was
-- caused by one of them being worn as the other, and nothing in the suite
-- stopped it, because a reading of the archive and a claim about the game are
-- the same English sentence with the domain left off.

-- (1) ARCHIVE -- tests/fixtures/*.lua. RECOMPUTED live in section 4; the numbers
-- here are last-measured values, not the authority. `first_learn` and
-- `at_or_below_240_with_ult` are the two the corpus predicts WILL move: W41
-- holds frames this archive does not, so an archive that grows toward
-- CORPUS_W41 is CONFIRMING it, not contradicting it. Section 4 is written so
-- that direction is not a red.
local ARCHIVE = {
    ck_frames                = 27,     -- records carrying a chaos_knight
    dead                     = 3,      -- no ability table (dumper omits for dead units)
    first_learn              = 306.0,  -- earliest frame holding a learned Phantasm
    at_or_below_240_with_ult = 0,      -- the reading that used to be a universal
    band                     = 12,     -- frames in 240 < t < 480
    band_with_ult            = 5,      -- of those, holding a learned Phantasm
}

-- (2) CORPUS_W41 -- all 82 games of W41, read frame-by-frame off the `.dem`
-- side by tools/batch_test/behavioral/ckpush_domain.py --learn-census.
-- Source: GH #447, iterations/reports/replay-check/20260903T072000Z.md §4.4.
--
-- ⚠ NOT RECOMPUTABLE FROM THIS SUITE, AND THAT IS THE POINT. The timelines live
-- in the batch corpus, not in the tree; this file cannot re-derive these numbers
-- and does not pretend to. They are registered here so the ruling's evidence is
-- IN the tree with its provenance attached, rather than restated from memory in
-- a comment -- which is exactly how the falsified universal survived.
local CORPUS_W41 = {
    games                       = 82,
    learn_at_or_below_240       = 2,      -- games, not frames
    earliest_learn              = 220.5,  -- 85.5s before ARCHIVE.first_learn
    carrying_frames_le_240      = 38,
    carrying_frames_le_240_alive = 20,
    casts_at_or_below_240       = 0,      -- the claim the ruling actually rests on
}

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
-- 2. [promoted] the resolution point, driven on a real frame.
--
--    ⚠ THIS SECTION WAS FLIPPED 2026-09-07 WHEN 'ckpush' WAS PROMOTED (director
--    ruling, test_set.md §FQ). It used to assert that gate-OFF was the shipped
--    8 * 30 and that only turbo + this exact id could move it. Both halves have
--    changed sign: turbo IS the repair now, and NOTHING about the armed set may
--    move it. The direction that still holds verbatim is the third one --
--    outside turbo the inherited value is untouched, byte for byte -- and that
--    is deliberately the assertion left unedited, because it is the one whose
--    meaning the promote did not change.

tests['[promoted] turbo is the repaired value, 8 * 60, with nothing armed'] = function()
    local X = ck_module(CK_SUBJECT_FRAMES[1], {}, true)
    assert(X.GetPushCommitTime() == 8 * 60, string.format(
        'turbo returned %s, not the promoted 8 * 60 = 480. If somebody re-gated '
        .. 'this, the promote is silently undone and every real turbo game is '
        .. 'back on the inherited typo.', tostring(X.GetPushCommitTime())))
end

tests['[promoted] outside turbo the inherited 8 * 30 is untouched'] = function()
    local X = ck_module(CK_SUBJECT_FRAMES[1], {}, false)
    assert(X.GetPushCommitTime() == 8 * 30,
        'the promote escaped the turbo condition -- this repo only rules on '
        .. 'turbo, and non-turbo must read the shipped value')
end

tests['[promoted] the armed set can no longer move it, in either direction'] = function()
    -- The negative control for "the gate is really gone". Arming the id that
    -- used to drive this must now be indistinguishable from arming nothing --
    -- and so must arming a handful of unrelated live ids.
    local bare  = ck_module(CK_SUBJECT_FRAMES[1], {}, true).GetPushCommitTime()
    local self_ = ck_module(CK_SUBJECT_FRAMES[1], { 'ckpush' }, true).GetPushCommitTime()
    local other = ck_module(CK_SUBJECT_FRAMES[1],
        { 'roshdist', 'slotdust', 'tpwatch' }, true).GetPushCommitTime()
    assert(bare == self_, "arming 'ckpush' still moves the resolver: the gate "
        .. 'was not removed, it was only renamed out of the comments')
    assert(bare == other, 'some other candidate id moves this resolver')
    -- Outside turbo too: the armed set must not reach the non-turbo leg either.
    local off = ck_module(CK_SUBJECT_FRAMES[1], { 'ckpush' }, false).GetPushCommitTime()
    assert(off == 8 * 30, 'the armed set reached the non-turbo leg')
end

-- ---------------------------------------------------------------------------
-- 3. [decision domain] what today's corpus can actually see -- AGREEMENT, and
--    the reason it is agreement rather than a passing comparison.

tests['[decision domain] both CK-subject frames sit below BOTH constants'] = function()
    -- ⚠ THE TWO LEGS ARE NOW THE TWO MODES, NOT TWO ARMED SETS ('ckpush' was
    -- promoted 2026-09-07, so the armed set no longer separates anything -- see
    -- section 2). What is compared here is unchanged: the two CONSTANTS, both
    -- of which still live in the tree, one per mode.
    for _, frame in ipairs(CK_SUBJECT_FRAMES) do
        local nPromoted = ck_module(frame, {}, true).GetPushCommitTime()
        local nInherited = ck_module(frame, {}, false).GetPushCommitTime()
        assert(nPromoted == 8 * 60 and nInherited == 8 * 30,
            'section 2 owns these two values; if they moved, fix them there')
        local t = DotaTime()  -- luacheck: ignore
        assert(t < 240, string.format(
            '%s is at t=%.1f, which is no longer below the inherited 240. It can '
            .. 'now separate the two constants -- promote it into section 5 and '
            .. 'stop annotating the clock.', frame, t))
        -- Both constants answer the SAME thing here, and the answer is "not yet".
        assert((t > nInherited) == false, 'the inherited constant opened early')
        assert((t > nPromoted) == false, 'the promoted constant opened early')
    end
end

tests['[decision domain] and the whole decision is closed too, for a second reason'] = function()
    -- Not merely "the clause is closed": on these two frames X.ConsiderR bails
    -- on its FIRST line, because Phantasm is unlearned (section 4 measures that
    -- no frame at or below 240 in the ARCHIVE has it). So even a corpus that put
    -- a CK subject at t = 300 would still need a LEARNED ult to reach the clock.
    --
    -- ⚠ WHY THIS IS NO LONGER A LEG-VS-LEG COMPARISON. Before the promote this
    -- read `dOff == dOn` over two armed sets. Post-promote those two loads are
    -- the same tree, so that equality would hold by construction -- an 0EQUIV
    -- green (§DJ.9): a comparison whose two sides cannot differ reports nothing
    -- in the same colour as reporting agreement. The observable that survives is
    -- the ABSOLUTE one: the decision is NONE here, and the clock is not why.
    for _, frame in ipairs(CK_SUBJECT_FRAMES) do
        local X = ck_module(frame, {}, true)
        local d = X.ConsiderR()
        assert(d == BOT_ACTION_DESIRE_NONE, string.format(  -- luacheck: ignore
            '%s now returns %s from X.ConsiderR -- the decision-level domain is '
            .. 'no longer empty on this frame, so condition (a) may be buyable '
            .. 'here after all; re-read section 5 before trusting it.',
            frame, tostring(d)))
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

tests['[domain price, ARCHIVE] the fixture-archive reading, and the domain it is a reading OF'] = function()
    local rows = ck_frames()
    assert(#rows >= ARCHIVE.ck_frames, string.format(
        'chaos_knight frames fell to %d (registered %d); the census below is '
        .. 'computed, but a shrinking archive means re-reading it',
        #rows, ARCHIVE.ck_frames))
    local dead = 0
    for _, r in ipairs(rows) do if r.dead then dead = dead + 1 end end
    assert(dead <= ARCHIVE.dead, string.format(
        '%d chaos_knight records now carry no ability table (registered %d, all '
        .. 'dead units). More of them means the rank read below is answering '
        .. 'about absence, not about rank.', dead, ARCHIVE.dead))

    local early_with_ult, earliest = 0, nil
    for _, r in ipairs(rows) do
        if r.rank >= 1 then
            if earliest == nil or r.t < earliest then earliest = r.t end
            if r.t <= 8 * 30 then early_with_ult = early_with_ult + 1 end
        end
    end

    assert(earliest ~= nil, 'no chaos_knight frame carries a learned Phantasm '
        .. 'any more -- the archive reading cannot be taken, so do not arm this id')

    -- Pinned as an EQUALITY so any drift is a conscious update rather than a
    -- silent re-reading. Read the message before touching either number: the two
    -- directions mean opposite things, and only one of them is about the ruling.
    if early_with_ult ~= ARCHIVE.at_or_below_240_with_ult
        or earliest ~= ARCHIVE.first_learn then
        error(string.format(
            'ARCHIVE reading moved: at_or_below_240_with_ult %d -> %d, '
            .. 'first_learn %.1f -> %.1f.\n'
            .. '  This is a reading of tests/fixtures/*.lua ONLY. It is NOT a '
            .. 'statement about turbo games.\n'
            .. '  * MOVED TOWARD CORPUS_W41 (earlier first_learn, more frames at '
            .. 'or below 240 holding Phantasm)?\n'
            .. '    Then the archive just gained frames of a kind W41 already '
            .. 'showed exists (%d of %d games learn at or below 240, earliest '
            .. 't=%.1f). That CONFIRMS the corpus. Update ARCHIVE above and move '
            .. 'on -- the ruling is untouched, because the ruling rests on '
            .. 'casts_at_or_below_240 = %d, not on this number.\n'
            .. '  * MOVED THE OTHER WAY (archive lost its early frames)?\n'
            .. '    Same action, but say so in the report: the archive is drifting '
            .. 'AWAY from the corpus it is supposed to sample.\n'
            .. '  What must NOT happen either way is the old sentence coming back: '
            .. 'this reading was once written as the universal "no frame at or '
            .. 'below 240s carries it at all", 82 games falsified it (GH #447), '
            .. 'and it stayed GREEN the whole time because this domain cannot '
            .. 'hold the counterexample.',
            ARCHIVE.at_or_below_240_with_ult, early_with_ult,
            ARCHIVE.first_learn, earliest,
            CORPUS_W41.learn_at_or_below_240, CORPUS_W41.games,
            CORPUS_W41.earliest_learn, CORPUS_W41.casts_at_or_below_240))
    end
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
    assert(in_band >= ARCHIVE.band, string.format(
        'the 240<t<480 band fell to %d chaos_knight frames (registered %d)',
        in_band, ARCHIVE.band))
    assert(in_band_with_ult >= ARCHIVE.band_with_ult, string.format(
        'only %d band frame(s) carry a learned Phantasm (registered %d). Below 1 '
        .. 'this lever stops being separable and becomes registered-not-fixed.',
        in_band_with_ult, ARCHIVE.band_with_ult))
end

-- ---------------------------------------------------------------------------
-- 4a. [claim scope] THE GUARD THIS ROUND EXISTS FOR (GH #447).
--
-- Section 4's reading was green for as long as it was wrong, and it could not
-- have been anything else: its domain is the fixture archive, and the frames
-- that falsify a claim about turbo games are not in it. So the repair cannot be
-- another assertion over the same domain -- it has to be over the PROSE, which
-- is where the domain got dropped.
--
-- The rule: a sentence about frames at or below 240 must not be written as an
-- unqualified universal in either place that carries this ruling. The banned
-- phrasing is pinned literally because it is the exact sentence that shipped;
-- the required anchor is the corpus citation, so the next reader lands on the
-- 82-game reading instead of re-deriving a universal from 27 fixture frames.

local function assert_no_universal(path, src)
    -- The literal that shipped, and the near-misses of it. Matched on
    -- comment-stripped-insensitive whole text on purpose: the sentence is bad
    -- wherever it appears in the file, prose or assertion message.
    --
    -- ⚠ SPLIT ON PURPOSE, and the split is not cosmetic. Written whole, this
    -- table IS a carrier of the sentence it bans, in the one file that scans
    -- itself -- and the guard duly failed on its own pattern list, one edit
    -- after failing on its own correcting prose. Concatenation keeps the phrases
    -- readable and greppable while leaving no literal occurrence to match.
    local banned = {
        'carries it' .. ' at all',
        'never binds' .. ' in turbo',
        'NEVER BINDS' .. ' in turbo',
    }
    -- The correction itself has to be allowed to QUOTE the bad sentence,
    -- otherwise this guard forbids explaining what it guards against. A
    -- quotation is an occurrence that sits inside the CORRECTION REGION: within
    -- WINDOW characters of a citation anchor.
    --
    -- ⚠ The first version keyed the exemption on the LINE the phrase sat on, and
    -- it red-flagged this round's own correcting sentence -- a sentence whose
    -- next line named the issue. That is GH #442's defect (a key made of
    -- incidental layout) in different clothes, caught here by the guard failing
    -- on its author. Anchors are CONTENT.
    --
    -- ⚠ LIMIT, stated rather than discovered later: a genuinely new universal
    -- written INSIDE the correction paragraph passes this guard. The window buys
    -- "the banned sentence cannot reappear far from its own correction"; it does
    -- not buy "no universal is ever written again". Nothing textual buys that.
    local WINDOW = 600
    local anchors = { '#447', 'used to', 'falsif', 'UNIVERSAL' }
    local function in_correction_region(at)
        local lo = math.max(1, at - WINDOW)
        local hi = math.min(#src, at + WINDOW)
        local region = src:sub(lo, hi)
        for _, anchor in ipairs(anchors) do
            if region:find(anchor, 1, true) ~= nil then return true end
        end
        return false
    end

    for _, phrase in ipairs(banned) do
        local at = src:find(phrase, 1, true)
        if at ~= nil and not in_correction_region(at) then
            local line_start = (src:sub(1, at):find('\n[^\n]*$') or 0) + 1
            local line_end = (src:find('\n', at) or (#src + 1)) - 1
            local line = src:sub(line_start, line_end)
            assert(false, string.format(
                '%s states "%s" as its own claim, not as a quotation.\n'
                .. '  That is a UNIVERSAL over turbo games, and its evidence is '
                .. '%d fixture frames -- about one game. GH #447 falsified it on '
                .. '%d games (earliest learn t=%.1f, %d of them at or below 240).\n'
                .. '  Write the claim the corpus actually buys instead: at or '
                .. 'below 240s there are %d push-Phantasm CASTS, so the shipped '
                .. '240 does not bind IN EFFECT.\n'
                .. '  Offending line: %s',
                path, phrase, ARCHIVE.ck_frames, CORPUS_W41.games,
                CORPUS_W41.earliest_learn, CORPUS_W41.learn_at_or_below_240,
                CORPUS_W41.casts_at_or_below_240, line))
        end
    end
end

tests['[claim scope] neither carrier states the falsified universal as its own claim'] = function()
    for _, path in ipairs({ SRC, 'tests/test_ckpush_minute_unit.lua' }) do
        assert_no_universal(path, read_file(path))
    end
end

tests['[claim scope] the source comment routes the reader to the corpus reading'] = function()
    local src = read_file(SRC)
    -- Content anchors, never line numbers: GH #442 is the standing ruling that a
    -- line-number key is a ratchet that breaks on its own next edit, and hero
    -- backlog -79 reproduced it inside a day.
    assert(src:find('GH #447', 1, true),
        SRC .. ' no longer cites GH #447, so a reader who hits the 240 has no '
        .. 'route to the 82-game reading that corrected it')
    assert(src:find('CORPUS_W41', 1, true) and src:find('ARCHIVE', 1, true),
        SRC .. ' no longer names the two registered readings; the domain '
        .. 'distinction they carry is the whole content of GH #447')
    assert(src:find('does not bind IN EFFECT', 1, true) or src:find('IN EFFECT', 1, true),
        SRC .. ' no longer states the surviving claim in its corrected form. The '
        .. 'ruling rests on ZERO casts at or below 240, not on the ultimate being '
        .. 'unlearned there -- those are different claims and only one is true.')
end

tests['[claim scope] the two readings are registered with different domains'] = function()
    -- A guard against the cheapest way to "simplify" this file later: folding
    -- ARCHIVE and CORPUS_W41 into one table. They disagree on purpose -- that
    -- disagreement IS the finding -- and one table cannot carry two domains.
    assert(CORPUS_W41.earliest_learn < 8 * 30, 'CORPUS_W41 no longer records a '
        .. 'learn at or below the shipped 240; if the corpus reading really '
        .. 'changed, re-open GH #447 rather than editing it here')
    assert(ARCHIVE.first_learn > 8 * 30, 'ARCHIVE now records a learn at or '
        .. 'below 240 -- update it in section 4 (that is a CONFIRMATION of '
        .. 'CORPUS_W41), and keep the two tables separate')
    assert(CORPUS_W41.earliest_learn < ARCHIVE.first_learn,
        'the corpus no longer reaches earlier than the archive; the sampling '
        .. 'claim this file rests on has inverted, so re-read both')
end

-- ---------------------------------------------------------------------------
-- 5. [separability, ANNOTATED] the two legs really do disagree -- shown on a
--    real chaos_knight frame with the CLOCK, and only the clock, moved into the
--    band. Labelled ANNOTATED because the archive holds no CK-subject frame
--    there; this is the assertion section 3 could not buy.

tests['[separability] ANNOTATED clock: the two constants disagree across the band'] = function()
    -- Post-promote the two legs are the two MODES: turbo carries the repair,
    -- non-turbo carries the inherited value. The band 240 < t < 480 is still the
    -- stretch the repair takes away, and it is still the whole content of the
    -- ruling -- what changed is which real games are on which side of it.
    local nInherited = ck_module(CK_SUBJECT_FRAMES[2], {}, false).GetPushCommitTime()
    local nPromoted = ck_module(CK_SUBJECT_FRAMES[2], {}, true).GetPushCommitTime()
    -- ANNOTATED: our archive holds no chaos_knight-SUBJECT frame in this band.
    for _, t in ipairs({ 241, 306, 373.4, 423.4, 479 }) do
        assert(t > nInherited,
            'non-turbo blocked at t=' .. t .. ', inside the band')
        assert(not (t > nPromoted),
            'turbo allowed at t=' .. t .. ', inside the band')
    end
    -- ...and agree outside it, in both directions.
    for _, t in ipairs({ 0, 192, 240 }) do
        assert((t > nInherited) == (t > nPromoted),
            'the constants disagreed below the band at t=' .. t)
    end
    for _, t in ipairs({ 481, 900 }) do
        assert((t > nInherited) == (t > nPromoted),
            'the constants disagreed above the band at t=' .. t)
    end
end

-- ---------------------------------------------------------------------------
-- 6. [source-parity] the resolver is a turbo SELECTION with NO gate left, and
--    the branch reads it. Fails on an empty corpus too, which is the point: it
--    checks a different thing from every assertion above.
--
--    ⚠ FLIPPED 2026-09-07 BY THE PROMOTE, and flipped in the load-bearing
--    direction: this used to assert that `IsSoakCandidate( 'ckpush' )` appears
--    EXACTLY ONCE. Left as it was, it would now be asserting that the thing the
--    ruling removed is still present -- a ratchet that has to be re-read as
--    demanding the defect back. It asserts ZERO instead.

tests['[source-parity] the branch reads the resolver, and the gate is gone'] = function()
    local src = read_file(SRC)
    assert(src:find('DotaTime%(%) > X%.GetPushCommitTime%(%)'),
        'the push branch no longer reads X.GetPushCommitTime')
    assert(src:find('function X%.GetPushCommitTime'),
        'X.GetPushCommitTime is gone or renamed')
    -- No gate left anywhere in the file: promoting means the id is in no armed
    -- string ever again, so a surviving call site would freeze FALSE (the
    -- `pullcad` trap, AGENTS.md) and silently restore the inherited constant.
    local n = 0
    for _ in src:gmatch("IsSoakCandidate%s*%(%s*'ckpush'%s*%)") do n = n + 1 end
    assert(n == 0, string.format(
        "'ckpush' still resolves at %d place(s) in %s; it was PROMOTED, so a "
        .. 'gate naming it can never be true again and every real turbo game '
        .. 'would be back on the inherited 8 * 30', n, SRC))
    -- The selection is on turbo alone, and the non-turbo leg is untouched.
    assert(src:find('if J%.IsModeTurbo%(%)%s*\n%s*then%s*\n%s*return 8 %* 60'),
        'the promoted resolver is not the plain turbo selection returning 8 * 60')
    assert(src:find('\n\treturn 8 %* 30\n'),
        'the non-turbo leg no longer returns the inherited 8 * 30')
end

return tests

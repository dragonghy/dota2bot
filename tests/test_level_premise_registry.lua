-- [hero] The level-ceiling premise: who still argues from a zero the harness put
-- there, and who has stopped.
--
-- THE PREMISE.  GH #84's turbo level census read `level >= 20` on 0 of 210
-- hero-slots, high-water 19.  That reading was correct about the corpus and
-- wrong about turbo: every batch game self-terminated at a 10-minute economy
-- cap, so no hero-slot COULD reach 20.  Owner priority P3 (GH #108) raised the
-- cap to 25 minutes; the first frame taken past it (GH #235,
-- iterations/pending/tpgap_159_fixture/, t=1382.2 = 23:02 of a 24.9-minute
-- naturally-ended game) reads ten heroes at level 22-27, three of them focus
-- heroes -- crystal_maiden 22, zuus 23, skeleton_king 26.  Real turbo games
-- average ~20 minutes, so the premise was never true of the shipped product
-- either: it was true of a measurement rig.
--
-- WHY A REGISTRY AND NOT NINE COMMENT EDITS.  The premise is not one sentence
-- in one place.  It is quoted at 9 sites in 4 shipped hero files and at 20 sites
-- across 9 test files, and behind several of those it is not prose at all but
-- the ARGUMENT of a verdict -- "this branch is unreachable in turbo", "this
-- domain is empty", "this read is dead weight".  Re-reading a verdict is work;
-- rewriting a sentence is not.  Mixing the two would let the cheap edits stand
-- in for the expensive re-reads, which is exactly how a premise rots quietly the
-- second time.  So this file splits them:
--
--   * bots/ is held at ZERO uncorrected sites, as an equality.  That is the
--     shipped Workshop deliverable and the only place a future reader meets the
--     claim without a test alongside it; the hero desk corrected all 9 on
--     2026-08-27 and owes no more.
--   * tests/ is a CEILING over a closed registry.  The count may fall as each
--     verdict is genuinely re-read; it may not rise, and no file may join the
--     list.  A number that can only go down is the honest shape for a debt
--     somebody else has to work off -- several of these rows belong to the
--     harness and director seats (GH #236 owns the ordering), not to this one.
--
-- WHAT COUNTS AS CORRECTED.  Not deleting the quote -- the premise SHOULD stay
-- quoted, because the verdicts written on top of it are unreadable without it
-- (the same shape as section 4 of tests/test_focus_talent_anchor.lua: the stale
-- ladder may be quoted, never used).  A site is corrected when the surrounding
-- comment block says so, i.e. carries GH #235 or the 2026-08-27 date within 14
-- lines.  So this ratchet cannot be satisfied by censorship, only by writing
-- down what replaced the claim.
--
-- HONEST BOUNDS
--   * This is a PROSE ratchet.  It proves that a premise-bearing comment
--     acknowledges the correction; it proves nothing about whether the verdict
--     built on that premise was actually re-read.  A file can pass here and
--     still hold a stale INERT.
--   * The fingerprints below are the literal forms the claim has taken in this
--     repo, collected by sweep on 2026-08-27.  A tenth phrasing would not be
--     caught.  That is why bots/ is an equality and not merely a ceiling: the
--     one place a new phrasing is cheap to notice is the place with nine known
--     ones already.
--
-- SECTION 3 EXISTS BECAUSE THE TENTH PHRASING HAPPENED THE SAME DAY.  Section 1
-- read ZERO uncorrected sites under bots/ from the hour it landed, and it was
-- wrong twice, both misses found by hand on 2026-08-27 while pricing Zeus's t20
-- row -- which is the row one of them sat on:
--
--   * hero_zuus.lua said "a t20 row, never trained in turbo (GH #84)".  It quotes
--     NO NUMBER, so not one of the six numeric fingerprints could see it, and it
--     stood 930 lines below a header block that had already been corrected to say
--     the opposite.  The file contradicted itself and the ratchet read clean.
--   * hero_skeleton_king.lua said "and unreachable in\n turbo regardless".  That
--     phrasing IS on the claim list -- but it is split across a line break, and a
--     line-by-line scan cannot match it however many phrasings it carries.
--
-- The two misses are different failures, so section 3 answers both: a CLAIM list
-- that keys on the verdict wording instead of on the number, scanned over ADJACENT
-- LINE PAIRS instead of single lines.  The obvious cheap fix -- adding the bare
-- string "GH #84" to FINGERPRINTS -- was measured and rejected: it does find the
-- Zeus site, and it also drags 7 new test files onto the registry whose only sin
-- is citing the issue as provenance, inflating a debt ceiling from 9 to 16 with
-- rows nobody owes.  A citation is not an argument.
--
--   * SECTION 3 IS bots/ ONLY, deliberately.  Over tests/ the same sweep read 6
--     uncorrected sites in 3 files on 2026-08-27 (test_focus_talent_anchor,
--     test_wk_fact_anchor x4, test_lion_hex_talent_slot), all three ALREADY on
--     PENDING below for the numeric list.  Ratcheting them twice would
--     double-count one debt; the re-read that clears their row clears these too.
--     That is what happened to test_wk_fact_anchor on 2026-08-28 -- its four went
--     with its row, which is the mechanism working, not a gap opening -- and to
--     test_lion_hex_talent_slot the same day.  All three are now clean, so the
--     bots/-only scope of section 3 currently costs nothing; keep reading it as a
--     deliberate scope and not as a measured all-clear over tests/, because the
--     lion file's miss WAS a section-3 shape (a header contradicting its own
--     section 6) that only the numeric list happened to catch.
--   * THIS FILE EXCLUDES ITSELF, and has to.  It is the file whose subject is
--     those strings, so it contains every one of them; a sweep that included it
--     would report its own prose as a defect.  Same lesson GH #228 paid for --
--     an assertion about a string cannot run over the file that discusses the
--     string.

local tests = {}

local SELF = 'tests/test_level_premise_registry.lua'

-- The literal shapes the GH #84 zero takes in this repo.  Lua patterns.
local FINGERPRINTS = {
    '0 of 210',
    'level >= 20',
    'level 20 does not happen',
    'high%-water 19',
    '0 of 940',
    'ge20',
}

-- A site is corrected when its own comment block names the correction.
local MARKERS = { 'GH #235', '2026%-08%-27' }
local WINDOW = 14

-- tests/ files that still argue from the uncorrected premise, and who owes the
-- re-read.  Recorded 2026-08-27.  Removing a row means the verdict in it was
-- re-read, not that the sentence was deleted.
local PENDING = {
    ['tests/corpus_scale.lua']                     = 'harness -- states the ge20==0 policy itself (GH #236)',
    ['tests/test_level_gate_census.lua']           = 'harness/director -- the 22 GH #84 verdicts (GH #235)',
}

-- The debt, as a number.  Kept as its own constant so the ratchet below can check
-- that it still DESCRIBES the list -- see CEILING_TRACKS_PENDING.
local CEILING = 2

-- CEILING_TRACKS_PENDING.  The ceiling assertion says this number "may only
-- fall", and until 2026-08-28 nothing enforced that: raising it to 9 and touching
-- nothing else was measured (mutation M7 of the wkrosh re-read round) and passed
-- silently, because a ceiling cannot catch its own loosening.  Binding it to the
-- row count closes that: paying a debt down means DELETING A ROW, and inventing
-- headroom now has to invent a row to hold it -- which section 2's `gone` check
-- then rejects, because an invented row carries no uncorrected premise.  This is
-- the registry's own rule made mechanical; it is not a new policy.
local function pending_count()
    local n = 0
    for _ in pairs(PENDING) do n = n + 1 end
    return n
end

-- CLEARED, newest first.  A row leaves this list when the VERDICT above the
-- premise was re-read, not when the sentence was deleted -- so what the row
-- becomes is a line saying what the re-read decided.
--
--   test_wk_q_aim_preflight.lua  (hero, 2026-08-28)
--     The premise was reason (1)'s cross-check: the shipped build leaves
--     Wraithfire Blast at rank 1 through level 11, "and GH #84's census read a
--     turbo high-water of 19, so rank 1 is what WK plays with for most of a turbo
--     game".  With the ceiling retired the correction cuts BOTH WAYS, and the
--     honest reading is NARROWER than the one it replaces: the levels where the
--     ability stops being scarce are reachable, so supply is a claim about the
--     early and mid game and is SILENT about the late game instead of covering
--     it.  The assertion under the note never needed the census -- it measures
--     the build level at which rank 4 arrives -- so it stands unchanged and only
--     the clause dressing it as a cross-check is struck.  The verdict does not
--     move, because reason (2) (the recently-damaged branch sits UPSTREAM of the
--     catch-all and takes the combat frames) never depended on a level.
--     What the re-read ADDED is the horizon check: section 1's tripwire
--     enumerated `ls tests/fixtures` while the only post-cap frame in the repo
--     sat in iterations/pending/, so its universal was a statement about one
--     directory -- the exact mechanism GH #281 carries repo-wide.  Checked rather
--     than assumed here, and the universal SURVIVES: that frame's Wraith King is
--     the one case in the corpus where supply is NOT the blocker (level 26,
--     Wraithfire Blast rank 4, off cooldown, 762 mana), and its 568u ring is
--     empty by a margin of most of a map -- nearest living enemy 10,309u.  The
--     frame is now enumerated by fixture_files() so the universal covers it
--     mechanically, and new section 4 asserts the reading against the file so a
--     future move cannot turn a measured answer back into an unasked question.
--
--   test_wk_bone_guard_thresholds.lua  (hero, 2026-08-28)
--     The premise was load-bearing in the frame BUILDER, not in prose: make_frame
--     handed X.ConsiderW an untrained talent6 stub because "an untrained stub is
--     the turbo reality (GH #84: level >= 20 on 0 of 210 hero-slots)", and that
--     stub is what makes the two `or talent6:IsTrained()` disjuncts inert so the
--     charge thresholds can be swept at all.  With the ceiling retired the stub
--     needed a reason that is still true, and it has one that never looks at the
--     reachable range: condition (c) is a claim about WHEN THE CAP RISES, and
--     both shipped rows spend all four Bone Guard points by hero level 12
--     (default 1/3/5/7, 'wkbuild' 1/9/10/12) -- eight levels below the earliest
--     level at which the t20 row can exist.  Every cap transition the file sweeps
--     therefore happens while the bypass is untrainable.  New section 7 asserts
--     that gap off the shipped build rows rather than leaving it as prose.
--     The re-read also PRICED what the correction costs, which the ceiling had
--     hidden: the stub is now a PARAMETER, and driving the shipped ConsiderW with
--     it trained collapses every threshold section 4 read to zero on both
--     branches -- rank-4 lane goes 8 -> 0.  So condition (c) has a LIFETIME.  The
--     'wkbuild' delay buys its frequency advantage over levels 12-19 and that
--     advantage expires at 20, and post-cap turbo demonstrably plays past the
--     expiry (this hero at 26, Bone Guard already rank 4, in the parked frame).
--     Not shown, and it cannot be shown here: that the bypass ever fires in a
--     game.  The dumper drops hero-unique talent rows (GH #260) and slot 6 is
--     one, so a corpus read of talent6:IsTrained() returns zero either way.
--
--   test_wk_roshan_mana_ceiling.lua  (hero, 2026-08-28)
--     The premise WAS the verdict's supporting clause, not decoration: the file
--     concluded the shipped 600 floor is crossable "in the TAIL of the turbo level
--     distribution, not never", and the tail was GH #84's high-water of 19 sitting
--     just under the crossing levels 21/19/18.  The re-read retires the tail by
--     OBSERVATION rather than by arithmetic -- the parked post-cap frame has this
--     hero at level 26 with a pool of 855, past all three -- so the conclusion
--     strengthens from "not arithmetically dead" to "observed alive", and the
--     defect the file names survives untouched because it was never about the
--     level (600 is 99.5% of the 603 crossing pool and 4.3x the spell it gates).
--     TURBO_HIGH_WATER_LEVEL is KEPT as a dated census reading: section 3 uses it
--     as an UPPER BOUND on the shipped build's crossing level, and an observed 26
--     only loosens that bound, so the one live use of the number survives its own
--     retirement.  Read together with the sibling floor file, whose mana margin is
--     the same quantity in the other unit -- the joint read, the sign-flip it
--     found, and the 14-intelligence miss in this file's pool model on its first
--     testable extrapolation past level 12 are in
--     tests/test_wk_roshan_lategame_reconciliation.lua.
--
--   test_focus_build_level_legality.lua  (hero, 2026-08-28)
--     The premise sat in WHAT IS NOT CLAIMED, excusing the t20/t25 queue
--     positions from the file's scope on TWO grounds, and the re-read retired
--     both.  Ground one was the ceiling itself ("out of turbo's domain") -- void
--     for the usual reason (GH #235), and pointedly so here: the recorded frame
--     puts crystal_maiden at 22 and zuus at 23, INSIDE the very 21-24 band the
--     bullet declared unreachable.  Ground two survived the ceiling and died on
--     its own: "it costs nothing ... by then there is nothing else in the queue"
--     is false as measured.  Driving the shipped GetTalentBuild/GetSkillList over
--     all seven focus rows, the queue runs to position 23 -- picks at 10/15/18/19
--     and the four ABANDONED talent halves at 20-23 -- so there IS something else
--     and the bot asks the engine for every bit of it.  What replaced the reason
--     is a criterion that never looks at a level: every entry behind the last
--     pick is the other half of a tier whose pick sits earlier in the SAME queue,
--     and one talent per tier makes it unspendable at any hero level.  The
--     verdict (both parks costless, both out of scope) therefore stands on new
--     ground, and the level-19 park now uses exactly one level fact instead of a
--     census: the single entry behind it is the t25 pick.  New section 4; the
--     level-free half is asserted at level 25, so it cannot be satisfied by the
--     ceiling coming back.
--
--   test_lion_hex_talent_slot.lua  (hero, 2026-08-28)
--     The premise sat in that file's ⚠️ LIMIT header, which ruled `lionhexaoe`'s
--     domain empty because no fixture reached level 25 and then said section 6
--     "goes RED when the corpus first contains a level-25 hero, which is the
--     moment this becomes proposable".  Section 6 itself was re-derived on
--     2026-08-27 and the header was not, so for a day the file argued both ways
--     400 lines apart -- the hero_zuus.lua shape section 3 below exists to catch,
--     this time inside tests/ where section 3 does not reach.  Re-read: the
--     disposition (not armed, not proposed, no queue request) SURVIVES and its
--     final sentence does not.  The domain is empty structurally, not by harvest:
--     the t25 row takes [7], one talent per tier, so talent8 is never trained and
--     no number of new frames can change that.  What the re-read added is a
--     measurement that keeps "structural" from being read as "the bot never asks"
--     -- driven through the real J.Skill.GetSkillList, the shipped queue carries
--     all four ABANDONED talent halves behind the picks (positions 20-23 against
--     picks at 10/15/18/19), so special_bonus_unique_lion_2 -- the exact handle
--     talent8 binds -- is requested in every game that reaches 25, and the
--     level-up ladder's fallback branch issues that order without consulting
--     CanAbilityBeUpgraded().  The guard is therefore held against a live request,
--     not against a hypothetical future edit.
--
--   test_wk_fact_anchor.lua  (hero, 2026-08-28)
--     Section 4 is a repo-wide census of structural t20/t25 reads, and the read
--     RECORDED with it priced them by unreachability -- "the else branch is the
--     correct default, so their unreachability costs nothing observable".  With
--     the ceiling retired (GH #235) that question is void, not merely wrong:
--     there is no unreachability left to price.  What replaced it is a
--     discriminator that never depended on levels -- a hero takes ONE talent per
--     tier, so a structural read is dead only when the hero's own
--     tTalentTreeList never trains the index it binds.  Run over the focus heroes
--     (new section 4b, driven through the real J.Skill.GetTalentBuild) it SPLITS
--     a bucket the old read had collapsed: zuus [7] and skeleton_king [6] are
--     trained and therefore live in shipped turbo from level 25 and 20, while
--     lion [8] is structurally untrained because his t25 row takes [7].  zuus and
--     lion sat in the same 08-22 bucket.  Not priced: the four non-focus heroes
--     in the census, which keep their counts and LOSE their verdict.
--
--   test_wk_bone_guard_talent_bypass.lua  (hero, 2026-08-27)
--     The premise sat in HONEST BOUNDS and in section 5, both saying the
--     bypass question is about a level-20 world turbo never reaches.  Re-read:
--     that world is real (GH #235 -- ten heroes at 22-27 in a naturally-ended
--     24.9-minute game, this hero at 26), so section 5's own re-open trigger
--     has fired and is recorded as fired.  The verdict that survived is
--     narrower than the premise it was written under: the bypass is live from
--     level 20, and no frame can confirm it fires -- for a MECHANICAL reason
--     found the same day, not for a level one (the dumper drops hero-unique
--     talents before writing them; tests/test_lategame_talent_visibility.lua).

local function read_lines(path)
    local fh = io.open(path, 'r')
    if not fh then return nil end
    local lines = {}
    for line in fh:lines() do lines[#lines + 1] = line end
    fh:close()
    return lines
end

local function ls(pattern)
    local out = {}
    local p = io.popen('ls ' .. pattern .. ' 2>/dev/null')
    if not p then return out end
    for path in p:lines() do out[#out + 1] = path end
    p:close()
    return out
end

--- { hits = n, uncorrected = n } for one file.
local function scan(path)
    local lines = read_lines(path)
    if not lines then return { hits = 0, uncorrected = 0 } end
    local hits, uncorrected = 0, 0
    for i, line in ipairs(lines) do
        local hit = false
        for _, fp in ipairs(FINGERPRINTS) do
            if line:find(fp) then hit = true; break end
        end
        if hit then
            hits = hits + 1
            local marked = false
            for j = math.max(1, i - WINDOW), math.min(#lines, i + WINDOW) do
                for _, m in ipairs(MARKERS) do
                    if lines[j]:find(m) then marked = true; break end
                end
                if marked then break end
            end
            if not marked then uncorrected = uncorrected + 1 end
        end
    end
    return { hits = hits, uncorrected = uncorrected }
end

local function sweep(paths)
    local out = {}
    for _, path in ipairs(paths) do
        if path ~= SELF then
            local r = scan(path)
            if r.hits > 0 then out[path] = r end
        end
    end
    return out
end

local function bots_paths()
    local out = {}
    for _, pat in ipairs({ 'bots/*.lua', 'bots/BotLib/*.lua', 'bots/FunLib/*.lua' }) do
        for _, p in ipairs(ls(pat)) do out[#out + 1] = p end
    end
    return out
end

-- ---------------------------------------------------------------------------
-- 1. The shipped deliverable carries no uncorrected copy of the premise.

tests['[hero] no file under bots/ still asserts the GH #84 level ceiling'] = function()
    local found = sweep(bots_paths())
    local bad, total = {}, 0
    for path, r in pairs(found) do
        total = total + r.hits
        if r.uncorrected > 0 then
            bad[#bad + 1] = path .. ' (' .. r.uncorrected .. ' of ' .. r.hits .. ')'
        end
    end
    table.sort(bad)
    assert(#bad == 0,
        'these shipped files quote the GH #84 level ceiling without saying it was '
        .. 'corrected: ' .. table.concat(bad, ', ') .. '. The claim may stay quoted '
        .. '-- the verdicts written on it are unreadable otherwise -- but the block '
        .. 'has to say what replaced it (name GH #235 or the 2026-08-27 correction '
        .. 'within ' .. WINDOW .. ' lines). bots/ is the Workshop deliverable: it is '
        .. 'the one place a reader meets this claim with no test beside it.')

    -- Anti-vacuum. If the sweep stops finding the premise at all, this test has
    -- become a test that a `ls` succeeded.  9 sites were corrected by hand on
    -- 2026-08-27 and a correction keeps the quote, so they must still be here.
    assert(total >= 9,
        'the premise sweep found only ' .. total .. ' quoted site(s) under bots/, '
        .. 'and 9 were corrected in place on 2026-08-27. Corrections KEEP the '
        .. 'quote, so this reads as a broken sweep or as somebody deleting the '
        .. 'premise instead of answering it -- which loses the reason the verdicts '
        .. 'above it are phrased the way they are.')
end

-- ---------------------------------------------------------------------------
-- 2. The tests/ debt is closed and can only shrink.

tests['[hero] no new test file joins the stale-premise registry'] = function()
    local found = sweep(ls('tests/*.lua'))
    local joined = {}
    for path, r in pairs(found) do
        if r.uncorrected > 0 and not PENDING[path] then
            joined[#joined + 1] = path .. ' (' .. r.uncorrected .. ')'
        end
    end
    table.sort(joined)
    assert(#joined == 0,
        table.concat(joined, ', ') .. ' argues from the GH #84 level ceiling and is '
        .. 'not on the registry in this file. That premise was retired on '
        .. '2026-08-27 (GH #235): a NEW argument built on it is being written '
        .. 'against a zero the batch harness produced, not against turbo. Either '
        .. 'stop leaning on it or add the row here with who owes the re-read.')
end

tests['[hero] the stale-premise registry shrinks or holds, never grows'] = function()
    local found = sweep(ls('tests/*.lua'))
    local still = 0
    local gone = {}
    for path in pairs(PENDING) do
        local r = found[path]
        if r and r.uncorrected > 0 then
            still = still + 1
        else
            gone[#gone + 1] = path
        end
    end
    table.sort(gone)
    assert(CEILING == pending_count(), 'the registered ceiling is ' .. CEILING
        .. ' but PENDING holds ' .. pending_count() .. ' rows. The ceiling is a '
        .. 'description of that list, not a free parameter: pay the debt down by '
        .. 'DELETING a row (with its CLEARED entry), never by raising the number.')

    assert(still <= CEILING,
        still .. ' registry files still argue from the retired premise; the '
        .. 'registered ceiling is ' .. CEILING .. ' (9 on 2026-08-27, lowered as '
        .. 'test_wk_bone_guard_talent_bypass.lua, test_wk_fact_anchor.lua, '
        .. 'test_lion_hex_talent_slot.lua, test_focus_build_level_legality.lua, '
        .. 'test_wk_roshan_mana_ceiling.lua, test_wk_bone_guard_thresholds.lua and '
        .. 'test_wk_q_aim_preflight.lua were re-read). This number is a debt, '
        .. 'so it may only fall. What is left belongs to the harness/director '
        .. 'seats (GH #236 owns the ordering); the hero desk owes none of it.')

    -- When a row is genuinely re-read, delete it from PENDING in the same change.
    -- Leaving a settled row on the list makes the ceiling read as more debt than
    -- there is, which is the failure mode that makes a registry stop being read.
    if #gone > 0 then
        assert(false,
            'these registry rows no longer carry an uncorrected premise: '
            .. table.concat(gone, ', ') .. '. Good -- now delete them from PENDING '
            .. 'in this file and lower the ceiling, so the number keeps meaning '
            .. 'what it says.')
    end
end

-- ---------------------------------------------------------------------------
-- 3. The two holes section 1 read straight through (2026-08-27).
--
-- The claim wording, not the number, and scanned over adjacent line pairs so a
-- sentence that wraps is still one sentence.  Plain substring matching on
-- purpose: these are prose, and a Lua pattern escape is one more thing to get
-- wrong in a file whose whole job is quoting strings.

local CLAIM_FINGERPRINTS = {
    'never trained in turbo',
    'unreachable in turbo',
    'dead row',
    'dead weight in turbo',
    'can ever be taken in turbo',
    'cannot be taken in turbo',
    'never reached in turbo',
}

-- A retraction always carries a retraction verb, which is what separates a
-- QUOTED claim from an ASSERTED one.  GH #235 and the date cover the 08-27
-- sweep; WITHDRAWN and RETIRED cover the earlier rounds that retired a claim
-- for their own reasons and named it.
local CLAIM_MARKERS = { 'GH #235', '2026-08-27', 'WITHDRAWN', 'RETIRED' }

--- Comment leader and indentation stripped, internal whitespace collapsed, so
--- that joining two source lines reproduces the sentence the author wrote.
local function norm(line)
    if line == nil then return '' end
    return (line:gsub('^%s*', ''):gsub('^%-%-+%s*', ''):gsub('%s+', ' '))
end

local function has_plain(hay, needles)
    for _, n in ipairs(needles) do
        if hay:find(n, 1, true) then return true end
    end
    return false
end

--- Hits are attributed to the line the sentence STARTS on: a pair matches only
--- when the second line alone does not, so one occurrence is never counted twice.
---
--- Takes LINES, not a path, so the wrap case below can drive this exact function
--- on a two-line fixture.  Written the other way first, and the wrap test then
--- re-implemented the join instead of testing it -- so deleting the join from
--- here left the suite green (mutation M7, caught by running it).
local function scan_claim_lines(lines)
    local hits, uncorrected, bad = 0, 0, {}
    for i = 1, #lines do
        local next_alone = norm(lines[i + 1])
        local pair = norm(lines[i]) .. ' ' .. next_alone
        if has_plain(pair, CLAIM_FINGERPRINTS)
            and not has_plain(next_alone, CLAIM_FINGERPRINTS)
        then
            hits = hits + 1
            local marked = false
            for j = math.max(1, i - WINDOW), math.min(#lines, i + WINDOW) do
                if has_plain(lines[j], CLAIM_MARKERS) then marked = true; break end
            end
            if not marked then
                uncorrected = uncorrected + 1
                bad[#bad + 1] = i
            end
        end
    end
    return { hits = hits, uncorrected = uncorrected, bad = bad }
end

local function scan_claims(path)
    local lines = read_lines(path)
    if not lines then return { hits = 0, uncorrected = 0, bad = {} } end
    return scan_claim_lines(lines)
end

tests['[hero] no file under bots/ asserts the level ceiling in words either'] = function()
    local bad, total = {}, 0
    for _, path in ipairs(bots_paths()) do
        if path ~= SELF then
            local r = scan_claims(path)
            total = total + r.hits
            if r.uncorrected > 0 then
                bad[#bad + 1] = path .. ':' .. table.concat(r.bad, ',')
            end
        end
    end
    table.sort(bad)
    assert(#bad == 0,
        'these shipped files state the retired level ceiling as a VERDICT rather '
        .. 'than quoting it: ' .. table.concat(bad, ', ') .. '. Section 1 keys on '
        .. 'the numbers GH #84 reported; this one keys on the wording, because on '
        .. '2026-08-27 two sites carried the claim with no number in it and section '
        .. '1 read them as clean. Keep the sentence if a verdict above it needs it, '
        .. 'and name the correction within ' .. WINDOW .. ' lines (GH #235, the '
        .. '2026-08-27 date, WITHDRAWN or RETIRED).')

    -- Anti-vacuum, and it is doing real work here: the two sites this section was
    -- built for were corrected by QUOTING the struck clause, so if the pair scan
    -- silently stops matching -- a norm() regression, a changed comment leader --
    -- this count is what notices.
    assert(total >= 7,
        'the claim sweep found only ' .. total .. ' site(s) under bots/, and 7 were '
        .. 'standing when it was written (5 already-corrected quotes plus the two '
        .. 'sites corrected in the same change). This reads as a broken sweep, not '
        .. 'as a clean tree. One of the seven WRAPS across two lines, so a scan that '
        .. 'quietly went back to reading single lines lands here at 6.')
end

tests['[hero] the claim sweep still sees a sentence split across two lines'] = function()
    -- The hero_skeleton_king.lua miss, driven through the real scanner rather
    -- than through a re-implementation of it.
    local wrapped = { '-- said this branch was "unreachable in', '-- turbo regardless".' }

    local both = scan_claim_lines(wrapped)
    assert(both.hits == 1,
        'the claim scanner reads ' .. both.hits .. ' hit(s) in a claim that wraps '
        .. 'across two comment lines, not 1. A sentence is not a line: this is the '
        .. 'miss section 3 was added for on 2026-08-27, and a single-line scan '
        .. 'cannot see it however many phrasings the list carries.')
    assert(both.bad[1] == 1,
        'the wrapped claim was attributed to line ' .. tostring(both.bad[1])
        .. ', not to the line the sentence starts on.')

    assert(scan_claim_lines({ wrapped[1] }).hits == 0
        and scan_claim_lines({ wrapped[2] }).hits == 0,
        'one half of the wrapped claim now matches on its own, so this case no '
        .. 'longer tests wrapping at all -- rewrite it against a claim that really '
        .. 'straddles the break.')
end

return tests

-- [hero] The FIRST early return in X.ConsiderE, measured -- and split into its
-- two halves, because a conjunction's real constraint and a conjunction's
-- readability are two different things (backlog -115, handed over by -114).
--
-- ===========================================================================
-- WHY THIS FILE EXISTS
-- ===========================================================================
--
-- hero_lion.lua carries this line, and both combat drain branches sit under it:
--
--     if X.IsOtherAbilityFullyCastable() or nSkillLV <= 1 then return 0 end
--
-- and immediately below it a `[liondrain]` note that reads the line as a
-- DESIGN CLAIM: the drain branches "only ever fire when Impale, Hex and Finger
-- are all unavailable", which "is exactly the state in which a support being
-- hit at close range should be walking away".  That note is an argument, and
-- until this file it was an argument with NO READING UNDER IT -- nothing in the
-- repo said how often the line is true.  That matters because `liondrainmi`
-- (the soak candidate landed 2026-09-07 in the 打架抽蓝 branch, GH #587,
-- queue.json hero-40) lives BELOW this line, so whatever this line rejects is
-- subtracted from that lever's domain before hero-40's column (1) ever gets to
-- count it.
--
-- -115 also wrote down the trap in advance, and it is the same shape as -114's:
-- `nSkillLV <= 1` is a LEVEL, not a cooldown.  Turbo's level curve is much
-- faster than a normal game's, so "E rarely gets past this line" must not be
-- read as "the cooldowns are what stopped it" without separating the halves.
-- Sections 2 and 3 do the subtraction; the answer is that the trap was real but
-- points the other way -- see below.
--
-- ===========================================================================
-- THE READING (every live-Lion instant in the archive, real loader)
-- ===========================================================================
--
--     live-Lion instants ................................ 27
--     ... E (Mana Drain) fully castable ................. 20   <- line reachable
--     ... and the early return FIRES .................... 17
--     ... and it does NOT fire (falls through) ...........  3   <- everything below
--
-- So the line is not a formality: it is the MAIN CONSTRAINT on the whole lower
-- half of ConsiderE, rejecting 17 of the 20 instants that reach it (85%).
--
-- THE TWO HALVES, separately.  The two are a disjunction, so they overlap and
-- the interesting quantity is each one's MARGINAL veto -- the instants that
-- only IT rejects:
--
--     IsOtherAbilityFullyCastable() true ......... 16 / 20     marginal 15 / 20
--     nSkillLV <= 1 true .........................  2 / 20     marginal  1 / 20
--
-- The level half is very nearly REDUNDANT: of the two instants where Mana Drain
-- is at rank <= 1, one is already rejected by the other half, so removing the
-- level clause entirely would change the line's answer on ONE of 20 instants.
-- -115's warning ("don't read 'E rarely fires' as 'cooldown stuck'") was the
-- right question and the answer is the opposite of the trap it guarded against:
-- the castability half really is doing the work, 15 to 1.
--
-- WHICH ability supplies the castability half (overlapping, one instant can
-- have several up):
--
--     Impale (Q) fully castable ....... 12 / 20
--     Hex    (W) fully castable ....... 11 / 20
--     Finger (R) fully castable .......  5 / 20
--
-- It is the BASICS that close this line, not the ult.  That is worth writing
-- down because the `[liondrain]` note names all three abilities symmetrically,
-- and they are not symmetric: Finger is on cooldown or untrained on 15 of 20.
--
-- ===========================================================================
-- WHAT THIS BUYS FOR `liondrainmi` -- a domain CEILING, not a domain
-- ===========================================================================
--
-- The 打架抽蓝 branch that calls X.lion_IsDrainCombatTargetCastable (the only
-- call site of the widened predicate) is BELOW this line in the source -- that
-- is asserted structurally in section 5, not restated from prose.  So on this
-- corpus the lever's domain is at most the fall-through count:
--
--     ceiling = 3 / 27 live-Lion instants = 11%
--
-- and the true domain is strictly smaller, because between the line and the
-- branch sit X.lion_IsDrainSafeToStart, J.IsInTeamFight (the 团战吸蓝 branch
-- returns first when it is true -- measured in test_lion_drain_combat_widen.lua)
-- and J.IsGoingOnSomeone.  -115 predicted this would come out "an order of
-- magnitude smaller than hero-40 column (1) would estimate"; 11% before three
-- further conjuncts is that prediction landing.
--
-- THIS IS A CEILING AND MUST NEVER BE QUOTED AS A RATE.  See bound (A).
--
-- ===========================================================================
-- WHAT THIS FILE DOES *NOT* DO
-- ===========================================================================
--
-- No lever, no gate, no new candidate id, no behaviour change.  The line
-- measures as DESIGNED-CORRECT, not as a bug: section 4 asserts that all three
-- fall-through instants are exactly the state the `[liondrain]` note names --
-- every basic on cooldown -- so the reading CONFIRMS the design claim it was
-- sent to check rather than undermining it.  Widening this line would hand
-- Mana Drain (a multi-second stationary channel with no defensive value) the
-- frames on which Lion still has a disable up, which is the trade the note
-- already refuses.  Section 6 is the absence assertion that keeps it that way.
--
-- ===========================================================================
-- HONEST BOUNDS -- load-bearing, quote these with any number above
-- ===========================================================================
--
-- (A) EXISTENCE READS, NOT DENSITIES -- and this bound came out STRONGER than
--     it was drafted, caught by its own assertion rather than by re-reading.
--     The draft said "two of the three fall-through instants are frames cut to
--     study Lion's drain"; section 4 answered THREE OF THREE:
--
--         tests/fixtures/f_260819_182323_lion_drain_calm.lua
--         tests/fixtures/f_260819_183409_lion_drain_focused.lua
--         tests/frames/f_260905_004847_lion_drain_bkb.lua
--
--     Every instant that gets past this line is one a previous round cut
--     BECAUSE Lion's drain was interesting there.  Not one arrived from a frame
--     sampled for any other reason.  A set selected on the outcome being
--     measured over-represents that outcome about as hard as a sample can, so
--     3/27 is biased UPWARD as a rate -- the safe direction for a CEILING and
--     the wrong direction for anything else.  The per-game rate is still
--     queue.json hero-4 / hero-40, and this bound is the reason it has to stay
--     there: the archive cannot answer it even in principle, because the only
--     frames in it that reach the branch were chosen for reaching it.
-- (B) `IsFullyCastable` INCLUDES MANA, and this is not incidental here: the
--     state Mana Drain exists to fix (Lion low on mana) is also a state in
--     which Q/W/R stop being fully castable, so the castability half OPENS
--     exactly when the drain is most wanted.  The 15/20 marginal veto is
--     therefore a reading on THIS corpus's mana levels, not a structural fact.
--     The fixture world's mana meter was only repaired on 2026-09-01
--     (tests/mock/replay_fixture.lua, mana_ladder); before it `GetManaCost`
--     answered 0 for everything and this clause could not be evaluated at all.
-- (C) THE LINE'S REACHABILITY IS AN UPPER BOUND.  "E fully castable" is a
--     necessary but not sufficient condition for control flow to REACH the
--     line: two branches sit above it (the mana-refill branch and the illusion
--     branch) and either can return first.  Neither can lift the 20; both can
--     only lower it, which is the safe direction for a CEILING.
--
--     ⚠️ THE REFILL BRANCH'S ZERO IS A MOCK DEFAULT, NOT A READING -- and the
--     repo currently records the wrong layer for it.  -114 established that the
--     branch cannot fire in the fixture world because `GetNearbyCreeps` answers
--     empty on every frame, and wrote the cause down as "the dumper schema has
--     no creep channel" (test_lion_drain_refill_domain.lua, HONEST BOUNDS).
--     The cause is one layer NEARER than that: tests/mock/replay_fixture.lua
--     wires GetNearbyHeroes, GetNearbyTowers and GetNearbyBarracks to the real
--     fixture world and does NOT wire GetNearbyCreeps, so the call lands on
--     tests/mock/bot_api.lua's blanket `if key:find('^GetNearby') then return {}
--     end`.  The distinction is not pedantry, it is a revival condition: adding
--     a creep channel to the DUMPER would move nothing here, because the answer
--     never reaches the dumper.  Only wiring the LOADER moves it.
--     Section 7 therefore asserts the WIRING, not the zero -- summing
--     `#GetNearbyCreeps` over 27 instants and asserting 0 would be the same
--     tautology bound (B) records for the pre-2026-09-01 mana meter, where
--     `GetManaCost` answered 0 for everything and `mp >= cost` was `mp >= 0`.
--     (tests/test_cm_frostbite_creep_cap.lua and tests/test_cm_ranged_creep_
--     health.lua already treat this zero as the mock's; the Lion files are the
--     ones that read it as the corpus's.)
-- (D) ABILITY IDENTITY IS READ BY NAME, and the shipped file binds by INDEX
--     (sAbilityList[1], [2], [3], [6]).  Section 8 asserts the shipped file
--     still binds those four indices; that the lion index->name map is
--     {1,2,3,6} = {impale, voodoo, mana_drain, finger_of_death} is pinned
--     independently in tests/test_focus_innate_index_anchor.lua and is NOT
--     re-derived here.
-- (E) TURBO IS NOT SEPARATED.  The corpus carries no game-mode field, so
--     "Turbo levels faster" -- the premise behind -115's trap -- is reasoned
--     about, not measured.  What IS measured is that the level half is nearly
--     redundant on the archive as it stands.

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')

local UNIT   = 'npc_dota_hero_lion'
local DRAIN  = 'lion_mana_drain'
local IMPALE = 'lion_impale'
local HEX    = 'lion_voodoo'
local FINGER = 'lion_finger_of_death'

local FIXTURE_DIR = 'tests/fixtures'
local STAGED_DIR  = 'tests/frames'
local HERO_SRC    = 'bots/BotLib/hero_lion.lua'

-- The refill branch's ring, and the guard ring above it, are both 1600 --
-- parsed out of the source and asserted equal in test_lion_drain_refill_domain.
-- lua.  It is retyped here only as the radius section 7 calls GetNearbyCreeps
-- with, and section 7 does not depend on the number: the call answers {} for
-- ANY radius, which is the whole point of that section.
local REFILL_RING = 1600

-- ---------------------------------------------------------------- enumeration

--- Every corpus file, from BOTH directories, enumerated -- never a hardcoded
--- path.  A "whole archive" sweep written as a glob over one directory plus a
--- literal path silently stopped being exhaustive the day tests/frames/ was
--- created and stayed green for three days (hero backlog -66).
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
        assert(n > 0, 'corpus directory ' .. dir .. ' yielded no f_*.lua frame. '
            .. 'An empty enumerator and an empty corpus are the same integer; '
            .. 'this assertion is the only thing that tells them apart.')
    end
    table.sort(out)
    return out
end

--- The refill branch's creep supply on one frame, or a readable failure.
--- See bound (C): this answers 0 because the LOADER does not wire
--- GetNearbyCreeps, not because the corpus is creep-free.
local function count_creeps(bot)
    local answer = bot:GetNearbyCreeps(REFILL_RING, true)
    if answer == nil then return 0 end
    assert(type(answer) == 'table',
        'bot:GetNearbyCreeps answered a ' .. type(answer) .. ', not a table or nil. '
        .. 'The usual cause is that tests/mock/bot_api.lua no longer carries its '
        .. 'blanket `^GetNearby` default, so the call fell through to the generic '
        .. '`^Get` fallback and got the number 0. Section 7 is the assertion that '
        .. 'explains what that default is doing for bound (C); fix it there.')
    return #answer
end

--- Every live-Lion instant, with the loader's real answers for the four bound
--- abilities plus the refill branch's creep supply.
local function lion_instants()
    local rows = {}
    for _, path in ipairs(corpus_paths()) do
        local ok, chunk = pcall(dofile, path)
        if ok and type(chunk) == 'table' then
            local present = false
            for _, u in ipairs(chunk.units or {}) do
                if u.name == UNIT and u.alive ~= false then present = true end
            end
            if present then
                local _, bot = rf.load(path, UNIT)
                local function ask(name)
                    local h = bot:GetAbilityByName(name)
                    if h == nil then return false, 0, 0 end
                    return (h:IsFullyCastable() and true or false),
                           h:GetLevel() or 0,
                           h:GetCooldownTimeRemaining() or 0
                end
                local eFC, eLv = ask(DRAIN)
                local qFC, qLv, qCd = ask(IMPALE)
                local wFC, wLv, wCd = ask(HEX)
                local rFC, rLv, rCd = ask(FINGER)
                rows[#rows + 1] = {
                    path = path, time = chunk.time,
                    eFC = eFC, eLv = eLv,
                    qFC = qFC, qLv = qLv, qCd = qCd,
                    wFC = wFC, wLv = wLv, wCd = wCd,
                    rFC = rFC, rLv = rLv, rCd = rCd,
                    -- NOT `#(... or {})`: when bot_api's blanket GetNearby*
                    -- default is absent the call falls through to the generic
                    -- `^Get` fallback, which answers the NUMBER 0, and `#0`
                    -- raises "attempt to get length of a number value" out of
                    -- this line -- an error every funnel-reading test in the
                    -- file then reports instead of the one sentence that
                    -- explains it (section 7).  Say what happened instead.
                    creeps = count_creeps(bot),
                }
            end
        end
    end
    return rows
end

--- The funnel.  Buckets are EXHAUSTIVE and DISJOINT -- section 1 asserts they
--- re-sum, which is what stops a silently dropped record from reading as a
--- smaller domain (and, here, as a smaller ceiling).
local function funnel()
    local rows = lion_instants()
    local t = {
        live = #rows, unreachable = 0, reach = 0, fires = 0, falls = 0,
        other = 0, lowlv = 0, otherMarginal = 0, lowlvMarginal = 0, bothHalves = 0,
        byQ = 0, byW = 0, byR = 0,
        fallRows = {}, creepTotal = 0,
    }
    for _, r in ipairs(rows) do
        t.creepTotal = t.creepTotal + r.creeps
        if not r.eFC then
            t.unreachable = t.unreachable + 1
        else
            t.reach = t.reach + 1
            local other = r.qFC or r.wFC or r.rFC
            local lowlv = r.eLv <= 1
            if other then t.other = t.other + 1 end
            if lowlv then t.lowlv = t.lowlv + 1 end
            if other and lowlv then t.bothHalves = t.bothHalves + 1 end
            if other and not lowlv then t.otherMarginal = t.otherMarginal + 1 end
            if lowlv and not other then t.lowlvMarginal = t.lowlvMarginal + 1 end
            if r.qFC then t.byQ = t.byQ + 1 end
            if r.wFC then t.byW = t.byW + 1 end
            if r.rFC then t.byR = t.byR + 1 end
            if other or lowlv then
                t.fires = t.fires + 1
            else
                t.falls = t.falls + 1
                t.fallRows[#t.fallRows + 1] = r
            end
        end
    end
    return t, rows
end

--- The shipped hero file, read once.
local function hero_source()
    local f = assert(io.open(HERO_SRC, 'r'),
        HERO_SRC .. ' cannot be opened; every structural assertion below is '
        .. 'about that file and none of them can be evaluated without it')
    local s = f:read('*a')
    f:close()
    return s
end

local tests = {}

-- ------------------------------------------------------------------ section 1
-- The funnel is exhaustive, disjoint, and has the shape the header claims.

function tests.funnel_buckets_are_exhaustive_and_disjoint()
    local t = funnel()
    assert(t.live == 27, 'live-Lion instants moved: ' .. t.live .. ' (was 27). '
        .. 'Every number in this file is over that set -- re-read, do not '
        .. 'rebaseline: a ceiling computed on a different corpus is not the '
        .. 'same ceiling.')
    assert(t.unreachable + t.reach == t.live,
        'reachable/unreachable do not re-sum to the corpus')
    assert(t.fires + t.falls == t.reach,
        'fires/falls do not re-sum to the reachable set')
    assert(t.reach == 20, 'E fully castable on ' .. t.reach .. ', expected 20')
    assert(t.fires == 17, 'early return fires on ' .. t.fires .. ', expected 17')
    assert(t.falls == 3, 'fall-through count is ' .. t.falls .. ', expected 3')
end

function tests.the_line_is_the_main_constraint_not_a_formality()
    local t = funnel()
    -- 17/20.  Stated as an inequality as well as an equality so that the CLAIM
    -- ("main constraint") survives a corpus change even when the exact integer
    -- does not.
    assert(t.fires > t.falls * 4,
        'the early return no longer dominates the lower half of ConsiderE: '
        .. t.fires .. ' rejected vs ' .. t.falls .. ' passed. The [liondrain] '
        .. 'note in hero_lion.lua and the liondrainmi ceiling both rest on it '
        .. 'dominating; re-read both.')
end

-- ------------------------------------------------------------------ section 2
-- THE SUBTRACTION -115 asked for: the two halves, separately, by MARGINAL veto.

function tests.the_two_halves_are_measured_separately()
    local t = funnel()
    assert(t.other == 16, 'IsOtherAbilityFullyCastable() true on ' .. t.other
        .. ' reachable instants, expected 16')
    assert(t.lowlv == 2, 'nSkillLV <= 1 true on ' .. t.lowlv
        .. ' reachable instants, expected 2')
    -- The disjunction's own arithmetic, asserted rather than trusted: the two
    -- marginals plus the overlap must be the whole rejected set.
    assert(t.otherMarginal + t.lowlvMarginal + t.bothHalves == t.fires,
        'the two halves and their overlap do not re-sum to the rejected set; '
        .. 'one of the three counters is measuring something else')
end

function tests.the_level_half_is_very_nearly_redundant()
    local t = funnel()
    assert(t.lowlvMarginal == 1,
        'the level clause `nSkillLV <= 1` now changes the line\'s answer on '
        .. t.lowlvMarginal .. ' instants, not 1')
    assert(t.otherMarginal == 15,
        'the castability clause now changes the line\'s answer on '
        .. t.otherMarginal .. ' instants, not 15')
    -- This is the sentence -115 sent the round to buy, written as an assertion
    -- so it cannot rot into prose: the castability half does the work, 15 to 1.
    assert(t.otherMarginal >= t.lowlvMarginal * 5,
        'the castability half no longer dominates the level half. -115\'s trap '
        .. '("do not read `E rarely fires` as `cooldown stuck`") was answered '
        .. 'the other way round on the 2026-09-07 archive; if that flipped, the '
        .. 'trap is live again and the halves must be re-separated before any '
        .. 'lever is priced against this line.')
end

-- ------------------------------------------------------------------ section 3
-- Which ability supplies the castability half.  The [liondrain] note names all
-- three symmetrically; they are not symmetric.

function tests.the_basics_close_this_line_not_the_ult()
    local t = funnel()
    assert(t.byQ == 12, 'Impale fully castable on ' .. t.byQ .. ', expected 12')
    assert(t.byW == 11, 'Hex fully castable on ' .. t.byW .. ', expected 11')
    assert(t.byR == 5, 'Finger fully castable on ' .. t.byR .. ', expected 5')
    assert(t.byR < t.byQ and t.byR < t.byW,
        'Finger of Death is no longer the rarest of the three. The header says '
        .. 'the basics close this line; that sentence is now wrong.')
end

-- ------------------------------------------------------------------ section 4
-- The design claim in the [liondrain] note, asserted on the real frames rather
-- than restated: everything that falls through has EVERY basic unavailable.

function tests.every_fallthrough_instant_has_all_three_unavailable()
    local t = funnel()
    assert(#t.fallRows == 3, 'expected 3 fall-through instants')
    for _, r in ipairs(t.fallRows) do
        assert(not r.qFC and not r.wFC and not r.rFC,
            r.path .. ' falls through the early return while one of Impale/Hex/'
            .. 'Finger is still fully castable. That is impossible under the '
            .. 'shipped predicate, so either the predicate or this reader moved.')
        assert(r.eLv >= 2, r.path .. ' falls through at Mana Drain rank '
            .. r.eLv .. '; the level clause should have rejected it')
    end
end

function tests.every_fallthrough_frame_was_cut_to_study_the_drain()
    -- Bound (A) as an assertion, and the assertion is what found the number:
    -- the header was drafted saying "two of three" and this test answered
    -- three of three.  If it ever stops being true the archive has acquired an
    -- instant that reaches the branch WITHOUT having been selected for it --
    -- which is the first frame the ceiling could be read as a rate on, and it
    -- must be re-argued (not re-baselined) when that happens.
    local t = funnel()
    local cut_for_drain = 0
    for _, r in ipairs(t.fallRows) do
        if r.path:match('lion_drain') then cut_for_drain = cut_for_drain + 1 end
    end
    assert(cut_for_drain == #t.fallRows and cut_for_drain == 3,
        cut_for_drain .. ' of ' .. #t.fallRows .. ' fall-through instants are '
        .. 'frames cut to study Lion\'s drain; bound (A) says ALL THREE are, and '
        .. 'that total selection on the outcome is the whole reason 3/27 may '
        .. 'only ever be quoted as a ceiling and never as a rate.')
end

-- ------------------------------------------------------------------ section 5
-- The ceiling is only a ceiling if the lever really is downstream of the line.
-- Asserted STRUCTURALLY on the shipped source, not restated from prose.

--- The byte offset of the early return AS CODE.
---
--- ⚠️ The naive `src:find('if X.IsOtherAbilityFullyCastable() ...')` matches the
--- FILE HEADER first: the t10 talent note quotes the same line verbatim inside a
--- comment, ~980 lines above the code.  Every ordering assertion below was
--- drafted that way and was therefore comparing offsets against a COMMENT --
--- which made "the call site is below the line" trivially true and let the
--- mutant that hoists the call site above the real line pass.  Caught by
--- tools/agent/mutstand_lionearlyreturn.sh M4.  The leading tab is what tells
--- the statement from the quotation, and the count assertion is what stops a
--- third copy from silently re-introducing the ambiguity.
local function early_return_offset(src)
    local n = 0
    for _ in src:gmatch('\n\tif X%.IsOtherAbilityFullyCastable%(%) or nSkillLV <= 1 then return 0 end') do
        n = n + 1
    end
    assert(n == 1, 'expected exactly one TAB-INDENTED (i.e. code, not quoted) '
        .. 'copy of the early return in ' .. HERO_SRC .. ', found ' .. n
        .. '. Every ordering assertion in this file resolves the line by that '
        .. 'indentation; two copies make them ambiguous and zero makes them void.')
    local at = src:find('\n\tif X%.IsOtherAbilityFullyCastable%(%) or nSkillLV <= 1 then return 0 end')
    return at + 1
end

function tests.liondrainmi_call_site_is_below_the_early_return()
    local src = hero_source()
    local line = early_return_offset(src)
    assert(line, 'the early return this whole file measures is no longer in '
        .. HERO_SRC .. ' in the form it was measured on')
    local callsite = src:find('X%.lion_IsDrainCombatTargetCastable%( botTarget %)')
    assert(callsite, 'the 打架抽蓝 call site of the widened predicate is gone; '
        .. 'the ceiling in the header is about that branch')
    assert(callsite > line,
        'X.lion_IsDrainCombatTargetCastable is now called ABOVE the early '
        .. 'return. The 3/27 ceiling is derived from it being below; it is void.')
    -- The single-call-site claim, re-asserted here because the ceiling is about
    -- the LEVER, not about one branch: a second call site elsewhere in the file
    -- would put part of liondrainmi outside this line's shadow.
    local n = 0
    for _ in src:gmatch('X%.lion_IsDrainCombatTargetCastable%(') do n = n + 1 end
    assert(n == 2, 'expected exactly one call site plus one definition of '
        .. 'X.lion_IsDrainCombatTargetCastable, found ' .. n .. ' occurrences')
end

function tests.further_conjuncts_still_sit_between_the_line_and_the_branch()
    -- The ceiling is loose BECAUSE of these; if they vanish the ceiling tightens
    -- toward the truth and the header's "strictly smaller" stops being true.
    local src = hero_source()
    local line = early_return_offset(src)
    local callsite = src:find('X%.lion_IsDrainCombatTargetCastable%( botTarget %)')
    local between = src:sub(line, callsite)
    for _, needle in ipairs({
        'X%.lion_IsDrainSafeToStart%( bot %)',
        'J%.IsInTeamFight%( bot, 1000 %)',
        'J%.IsGoingOnSomeone%( bot %)',
    }) do
        assert(between:find(needle),
            'the guard matching ' .. needle .. ' no longer sits between the '
            .. 'early return and the widened branch. The header calls the '
            .. '3/27 ceiling "strictly" loose on the strength of all three.')
    end
end

-- ------------------------------------------------------------------ section 6
-- ABSENCE.  This round wrote no lever; these are the revival lines.

function tests.no_gate_was_added_to_this_line()
    local src = hero_source()
    -- ⚠️ Deliberately NOT early_return_offset, and deliberately not any pattern
    -- that pins the text AROUND the call either.  A gate inserted into the line
    -- changes that text, so a text-pinned anchor makes this test VANISH on
    -- exactly the mutation it exists to catch -- which is what the first run of
    -- mutstand_lionearlyreturn.sh M6 demonstrated: the gate mutant scored on
    -- "the early return is gone", not on "someone gated it".
    -- So: find the CODE line that calls the helper, whatever else is on it.
    local stmt, hits = nil, 0
    for ln in src:gmatch('[^\n]+') do
        if ln:sub(1, 1) == '\t' and ln:find('X.IsOtherAbilityFullyCastable()', 1, true) then
            hits = hits + 1
            stmt = ln
        end
    end
    assert(hits == 1, 'expected exactly one CODE line calling '
        .. 'X.IsOtherAbilityFullyCastable in ' .. HERO_SRC .. ', found ' .. hits
        .. '. At zero the early return this file measured is gone; above one the '
        .. 'reading no longer has a single line to be about.')
    assert(not stmt:find('IsSoakCandidate'),
        'someone put a soak-candidate gate on ConsiderE\'s first early return. '
        .. 'This file measured the line as DESIGNED-CORRECT (section 4): all '
        .. 'three fall-through instants are exactly the state the [liondrain] '
        .. 'note names. Widening it hands a stationary channel the frames on '
        .. 'which Lion still has a disable up.')
    assert(stmt:find('X%.IsOtherAbilityFullyCastable%(%) or nSkillLV <= 1 then return 0 end'),
        'the early return was rewritten in place without a gate -- the other way '
        .. 'to make this round\'s NOT-TAKEN silently false. Every count in this '
        .. 'file was taken on the disjunction exactly as it stood.')
end

function tests.the_helper_is_still_the_plain_disjunction_it_was_measured_as()
    local src = hero_source()
    assert(src:find('return abilityQ:IsFullyCastable%(%) or abilityW:IsFullyCastable%(%) or abilityR:IsFullyCastable%(%)'),
        'X.IsOtherAbilityFullyCastable is no longer the three-way disjunction '
        .. 'every count in this file was taken on')
end

-- ------------------------------------------------------------------ section 7
-- Bound (C): the refill branch's zero, and WHY it is not evidence.

function tests.the_refill_branch_zero_is_the_mock_default_not_a_corpus_reading()
    -- ⚠️ THE WIRING ASSERTIONS RUN FIRST, BEFORE funnel().  Order is load-bearing
    -- here, not stylistic: removing bot_api's blanket default sends
    -- GetNearbyCreeps to the generic `^Get` fallback, which answers the NUMBER 0,
    -- and `#(0 or {})` raises before any assertion in this file is reached.  Put
    -- the funnel first and the mutant that deletes the attribution's own source
    -- reports a length-of-a-number error instead of the sentence that explains
    -- it (mutstand_lionearlyreturn.sh M9, first run).
    --
    -- THE ASSERTIONS THAT ARE NOT TAUTOLOGIES: the loader wires three GetNearby*
    -- methods to the fixture world and leaves GetNearbyCreeps to bot_api's
    -- blanket default.  THAT is why the sum below is 0, and it would still be 0
    -- on a corpus full of creeps.  A red here means the wiring changed, which
    -- is the only event that can turn the zero into a reading.
    local rfsrc = assert(io.open('tests/mock/replay_fixture.lua', 'r')):read('*a')
    for _, wired in ipairs({ 'GetNearbyHeroes', 'GetNearbyTowers', 'GetNearbyBarracks' }) do
        assert(rfsrc:find(wired, 1, true),
            'tests/mock/replay_fixture.lua no longer wires ' .. wired .. '; the '
            .. 'contrast this assertion draws (wired vs unwired GetNearby*) is '
            .. 'what makes the creep zero attributable to the loader at all')
    end
    assert(not rfsrc:find('GetNearbyCreeps', 1, true),
        'tests/mock/replay_fixture.lua now mentions GetNearbyCreeps. If it WIRES '
        .. 'it, the fixture world can serve creeps for the first time and three '
        .. 'things must be re-read, none of them re-baselined: (1) -114\'s NOT '
        .. 'TAKEN on the refill branch, whose whole supply argument rests on the '
        .. 'branch being unreachable here; (2) bound (C) of this file, because '
        .. 'the refill branch could then return BEFORE the early return and the '
        .. '20 would stop being an upper bound on reachability; (3) the cause '
        .. 'sentence in test_lion_drain_refill_domain.lua, which attributes the '
        .. 'zero to the DUMPER schema rather than to this file.')

    local basrc = assert(io.open('tests/mock/bot_api.lua', 'r')):read('*a')
    assert(basrc:find("key:find('^GetNearby') then return {}", 1, true),
        'tests/mock/bot_api.lua no longer answers unwired GetNearby* with an '
        .. 'empty table. That default is the actual source of the zero below; '
        .. 'without it the zero has no explanation in this repo.')

    -- The zero itself, LAST -- and only so the assertions above have something
    -- to be the explanation OF.  On its own this line is a tautology, which is
    -- precisely what bound (C) records.
    local t = funnel()
    assert(t.creepTotal == 0,
        'GetNearbyCreeps answered ' .. t.creepTotal .. ' creep(s) across the '
        .. 'corpus. If the loader was wired since (see above) this is GOOD NEWS '
        .. 'and both -114\'s NOT TAKEN and bound (C) must be re-read; if it was '
        .. 'not, something is answering non-empty for a reason nobody declared.')
end

-- ------------------------------------------------------------------ section 8
-- Bound (D): this file reads abilities BY NAME; the shipped file binds BY INDEX.

function tests.shipped_file_still_binds_the_four_indices_this_file_assumes()
    local src = hero_source()
    for _, pair in ipairs({
        { 'abilityQ', '1' }, { 'abilityW', '2' }, { 'abilityE', '3' }, { 'abilityR', '6' },
    }) do
        assert(src:find('local ' .. pair[1] .. ' = bot:GetAbilityByName%( sAbilityList%['
            .. pair[2] .. '%] %)'),
            pair[1] .. ' is no longer bound to sAbilityList[' .. pair[2] .. ']. '
            .. 'This file reads Impale/Hex/Mana Drain/Finger by NAME; the '
            .. 'index->name map is pinned in '
            .. 'tests/test_focus_innate_index_anchor.lua and is what makes the '
            .. 'two agree.')
    end
end

return tests

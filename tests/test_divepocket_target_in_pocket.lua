-- [divepocket 20260913] THE ANTI-SUICIDE-DIVE GUARD NOW TAKES ITS SAFETY READ
-- AT THE POCKET IT WAS ASKED ABOUT.
--
-- ⭐ WHAT LANDED, IN ONE LINE: inside J.ShouldSuppressDive, the caller's target
-- is kept as the representative only when it is one of the flanking enemies
-- (identity membership in `tEnemies`); otherwise the function falls through to
-- the lowest-HP enemy in the pocket -- the branch it ALREADY has. One conjunct
-- and one small loop, NEW soak id 'divepocket'.
--
-- ⭐ THE DEFECT IN THE CODE'S OWN WORDS. The comment directly above the line
-- reads "representative lethal target: the caller's target IF IT IS ONE OF THE
-- FLANKING ENEMIES, else the lowest-HP enemy in the pocket". The predicate
-- under it is `J.IsValidHero( target ) and target or nil` -- alive, visible, a
-- hero, not ours. It never asks about the pocket. Same shape as the GH #782
-- family that closed this morning (a shipped comment naming a narrower thing
-- than its predicate tests), but in a different instrument: there it was a
-- unit-name test, here it is a MEMBERSHIP test that was never written.
--
-- ⭐ WHY IT IS NOT COSMETIC. hTarget is the LOCATION THE SAFETY READ IS TAKEN
-- AT: J.SafeToCommitFight( bot, hTarget ) scores allies and enemies within 1200
-- of hTarget:GetLocation(), and the self-critical branch reads
-- J.GetAlliesNearLoc( hTarget:GetLocation(), 1200 ). With an off-pocket target
-- the guard answers "is that OTHER fight winnable" and then bids
-- BOT_MODE_DESIRE_HIGH retreat -- or declines to -- for the pocket the bot is
-- standing in.
--
-- ⭐ AND THE CALLER CAN SUPPLY ONE. The shipped, PROMOTED call site is
-- bots/mode_retreat_generic.lua's retreat desire, which passes
-- `botTarget = J.GetProperTarget( bot )`. That helper is `bot:GetTarget()` (the
-- bot's current ORDER target) falling back to `bot:GetAttackTarget()`, filtered
-- only by "not one of our own heroes/buildings". It contains no distance call of
-- any kind. §1 asserts that against the source, so the day somebody adds a leash
-- there this file goes red instead of quietly overstating the domain.
--
-- ⭐⭐ THE LOAD-BEARING WITNESS IS THE ONE REVERSE FLIP, and it is the NEAREST
-- flipping pair in the corpus at 1,657.4 units -- an ordinary order-target
-- distance, not a map-width artefact. f_260909_215227_zeus_bolt_od_1084,
-- subject-team Pudge at 0.38 HP in a 2-enemy pocket with an obsidian_destroyer
-- 1,657u away: SHIPPED answers "don't suppress" because SafeToCommitFight liked
-- the neighbourhood around the Destroyer; NARROWED, the read is taken at the
-- pocket, the low-HP clause is reached, and a 38%-HP hero in a two-man pocket
-- retreats. That is the guard's whole stated job.
-- ⇒ The evidence this file is built around is deliberately NOT the 21 flips
-- that go the other way. Those all sit beyond 5.6k units, where the two
-- 1200-radius discs are disjoint and a flip is nearly free; they price the
-- effect where it is cheap. The single near-band flip is the one that shows the
-- repair doing the thing the guard exists to do, and it is pinned BY NAME in §4
-- so it cannot leave the corpus quietly.
--
-- ⭐ NEW SOAK ID, ON PURPOSE -- criterion (甲′)'s FIRST state. The host is
-- PROMOTED ('nodive'), so it runs in every turbo game today and there is NO host
-- gate to inherit; narrowing in place would change shipped play with no wave
-- behind it. Same call as 'divepost' (2026-09-13) under the same promoted-host
-- rule, and the opposite of 'rescpost'/'roshpost'/'tpdeftower', whose hosts were
-- gated as a whole. Under owner P4.2's admission freeze the id lands REGISTERED
-- AND UNARMED: iterations/streams/test_set.md and iterations/queue.json are
-- untouched, so shipped play is byte-for-byte unchanged.
--
-- ⚠️ DIRECTION IS MEASURED, NOT CONSTRUCTED. Swapping the representative can
-- move the answer either way, so there is no subset argument to lean on here
-- (unlike every member of the GH #782 family). §3 prices it instead, and reports
-- BOTH signs: 21 suppress -> don't-suppress and 1 the other way. A file claiming
-- one-sidedness here would be claiming a narrowing this is not.
--
-- ⚠️ CORPUS LIMITS, registered rather than worked around:
--   (i) the mock's GetEstimatedDamageToTarget answers real damage only for
--       enemies acting on the fixture's own subject, so SafeToCommitFight's
--       LETHAL branch is near-dead here and essentially every arm difference
--       below is a NUMBERS-branch difference (the GH #611 shape).
--  (ii) the dumper carries no attack-target field (GH #786), so this corpus
--       cannot say how OFTEN a real bot:GetTarget() sits outside the pocket --
--       only what happens when it does. The rate is not claimed anywhere in this
--       file, and §5's near-band control is a WITNESS count, not a frequency.
-- (iii) subject-team rows only. J.GetEnemiesNearLoc / J.GetAlliesNearLoc resolve
--       teams through the global GetTeam(), which is the FIXTURE SUBJECT's team,
--       so driving an opposing-team handle as `bot` would score the wrong side's
--       allies. §2 asserts the filter is doing real work rather than silently
--       emptying the drive.

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')

local tests = {}

local JMZ = 'bots/FunLib/jmz_func.lua'
local RETREAT = 'bots/mode_retreat_generic.lua'
local GATE_ID = 'divepocket'
local WITNESS = 'f_260909_215227_zeus_bolt_od_1084.lua'
local WITNESS_HERO = 'npc_dota_hero_pudge'

local function read_file(path)
    local f = assert(io.open(path, 'r'), path .. ' is not readable')
    local s = f:read('*a')
    f:close()
    return s
end

local function block(src, header)
    local at = src:find(header, 1, true)
    if at == nil then return nil end
    local stop = src:find('\nfunction J.', at + 10) or #src
    return src:sub(at, stop)
end

local SRC = read_file(JMZ)
local HOST = block(SRC, 'function J.ShouldSuppressDive( bot, vLoc, target )')
local PROPER = block(SRC, 'function J.GetProperTarget( bot )')
local RETREAT_SRC = read_file(RETREAT)

-- Every threshold is PARSED OUT OF THE SHIPPED SOURCE, never typed here (the
-- M13 lesson): move the number in jmz_func and this file moves with it. A
-- failed parse reads as nil, never as a zero (the GH #171 shape).
local POCKET_R = HOST and tonumber(HOST:match('GetEnemiesNearLoc%( vLoc, (%d+) %)'))

-- ------------------------------------------------------------- §1 source ---

tests['[divepocket] 1. the shipped prose, the predicate, the gate and the caller'] = function()
    assert(HOST ~= nil, 'J.ShouldSuppressDive is gone from ' .. JMZ)
    assert(PROPER ~= nil, 'J.GetProperTarget is gone from ' .. JMZ)

    -- (a) The comment this repair is named after. If it is reworded, the claim
    --     "the code disagrees with its own prose" must be re-read, not assumed.
    assert(HOST:find('the caller\'s target if it is one of the', 1, true) ~= nil,
        'the representative-target comment no longer says "the caller\'s target '
        .. 'if it is one of the flanking enemies". This whole file is built on '
        .. 'that sentence being the shipped intent -- re-read it before trusting '
        .. 'any count below.')

    -- (b) The predicate the comment sits on. It is still a bare validity test:
    --     the membership question lives in the gated block, not here.
    assert(HOST:find('local hTarget = J.IsValidHero( target ) and target or nil',
        1, true) ~= nil,
        'the representative-target line changed shape. The defect this file '
        .. 'pins is that the UNGATED line asks only J.IsValidHero -- if that is '
        .. 'no longer true the narrowing may now be unconditional.')

    -- (c) The gate is present AND is the thing standing between the two arms.
    --     §3's flip_ab > 0 is the behavioural half of this claim; a text match
    --     alone would only guard the spelling.
    assert(HOST:find("J.IsSoakCandidate( '" .. GATE_ID .. "' )", 1, true) ~= nil,
        'the ' .. GATE_ID .. ' gate is gone from J.ShouldSuppressDive. Without '
        .. 'it the narrowing is unconditional and changes SHIPPED play: the host '
        .. 'is promoted.')

    -- (d) ...and the host really is promoted, which is WHY (c) is required.
    --     If 'nodive' ever regains a gate, criterion (甲′) changes state and
    --     this id should be reconsidered rather than kept out of habit.
    assert(SRC:find("PROMOTED (was soak-candidate 'nodive')", 1, true) ~= nil,
        'J.ShouldSuppressDive no longer carries its PROMOTED note. The reason '
        .. GATE_ID .. ' exists as its own id is that there was no host gate to '
        .. 'inherit -- re-price the placement.')

    -- (e) The caller, quoted rather than described.
    assert(RETREAT_SRC:find('J.ShouldSuppressDive(bot, botLocation, botTarget)',
        1, true) ~= nil,
        RETREAT .. ' no longer passes (botLocation, botTarget) to '
        .. 'J.ShouldSuppressDive. The whole domain argument is about what that '
        .. 'third argument can be.')
    assert(RETREAT_SRC:find('botTarget      = J.GetProperTarget(bot)', 1, true) ~= nil,
        RETREAT .. ' no longer sources botTarget from J.GetProperTarget.')
    assert(RETREAT_SRC:find('botLocation    = bot:GetLocation()', 1, true) ~= nil,
        RETREAT .. ' no longer sources botLocation from bot:GetLocation(); the '
        .. 'drives below pass the hero\'s own location on that basis.')

    -- (f) ⭐ THE CLAIM THAT MAKES THE DOMAIN REAL, WRITTEN AS A RED-ABLE
    --     ASSERTION INSTEAD OF A SENTENCE: J.GetProperTarget applies no
    --     distance bound. Not "we read it and it looked unbounded" -- the three
    --     distance calls the tree has are absent from its body.
    for _, fn in ipairs({ 'GetUnitToUnitDistance', 'GetUnitToLocationDistance',
        'GetLocationToLocationDistance' }) do
        assert(PROPER:find(fn, 1, true) == nil,
            'J.GetProperTarget now calls ' .. fn .. '. It may be leashed, and '
            .. 'if it is, the "the caller can hand us a target anywhere on the '
            .. 'map" premise of this file must be re-measured, not restated.')
    end

    assert(POCKET_R ~= nil, 'could not parse the pocket radius out of the host; '
        .. 'refusing to hardcode it (the M13 lesson).')
end

-- -------------------------------------------------------------- the sweep ---

--- ONE pass over the corpus: the census plus four drives per (row, enemy) pair.
---
--- ⚠️ BUDGET IS NOT MEMBERSHIP. This file is not registered in
--- tools/agent/lua_gate_manifest.json; the only sanctioned way in is a full
--- re-measure of every file, which rewrites the whole manifest and is not a
--- small work unit's business (GH #783). A red here therefore does not block
--- anybody's push -- the GH #624 shape, registered rather than papered over.
--- Memoised: every section reads the same numbers.
local SWEEP, SWEEP_ERR = nil, nil
local WITNESS_SEEN = false
local MIN_FLIP_D, MIN_FAR_D, MAX_IN_D = nil, nil, nil

local function corpus_paths()
    local out = {}
    for _, dir in ipairs({ 'tests/fixtures', 'tests/frames' }) do
        -- Registered in tests/test_bots_walk_farm_only.py:UNRESOLVED_HAND_READ:
        -- a plain non-recursive `ls` over two literal directories.
        local p = assert(io.popen('ls ' .. dir .. ' 2>/dev/null'),
            'could not list ' .. dir)
        for line in p:lines() do
            if line:sub(-4) == '.lua' then out[#out + 1] = dir .. '/' .. line end
        end
        p:close()
    end
    assert(#out > 100, 'expected the frame corpus, got ' .. #out)
    return out
end

local function run_sweep()
    local c = setmetatable({}, { __index = function() return 0 end })
    local function bump(k) rawset(c, k, c[k] + 1) end
    -- Zero-initialised, so "never reached" and "measured zero" are never the
    -- same thing to a reader (the GH #171 shape).
    for _, k in ipairs({ 'frames', 'load_fail', 'rows', 'own', 'off_team',
        'pocket2', 'far', 'in_p', 'raised',
        'fire_a', 'fire_a2', 'fire_b', 'fire_d',
        'flip_ab', 'a1b0', 'a0b1', 'flip_ac', 'flip_ad', 'bd_mismatch',
        'near_pairs', 'near_flip',
        'in_rep_kept', 'in_rep_swapped', 'in_rep_unseen',
        'far_rep_kept', 'far_rep_swapped', 'far_rep_unseen' }) do
        rawset(c, k, 0)
    end

    for _, path in ipairs(corpus_paths()) do
        local ok, J, _, heroes = pcall(rf.load, path)
        if not ok or J == nil then
            bump('load_fail')
        else
            bump('frames')
            local nMyTeam = GetTeam()

            --- ⛔ `armed` is a real boolean and `tgt` a real handle or nil.
            --- There is no nil-as-"shipped" sentinel here: arm D passes nil
            --- DELIBERATELY, because nil is the shipped way to reach the
            --- fallback, and that is exactly what makes it the end-to-end
            --- confirmation of arm B rather than a second copy of arm A.
            ---
            --- ⭐⭐ IT ALSO RECORDS WHICH HANDLE BECAME THE REPRESENTATIVE, and
            --- that is not decoration -- it is this file's (戊) correction.
            --- The first version of §3 asserted arm C as `flip_ac == 0` and the
            --- mutation stand's M4 (discard the target UNCONDITIONALLY, so the
            --- gate throws away the in-pocket targets it exists to keep)
            --- SURVIVED it: on this corpus swapping an in-pocket representative
            --- for the pocket's lowest-HP enemy changes no ANSWER, so a count of
            --- answers is true either way. `flip_ac == 0` is therefore a real
            --- reading and NOT a discriminating one. The branch is counted
            --- instead, by wrapping the one function the representative is
            --- actually spent on -- J.SafeToCommitFight -- and reading its
            --- second argument back.
            local REP = nil
            local real_safe = J.SafeToCommitFight
            J.SafeToCommitFight = function(b, t)
                REP = t
                return real_safe(b, t)
            end

            local function drive(h, vLoc, armed, tgt)
                J.IsSoakCandidate = function(id)
                    return armed and id == GATE_ID
                end
                REP = nil
                local okr, r = pcall(J.ShouldSuppressDive, h, vLoc, tgt)
                if not okr then
                    bump('raised')
                    return 'ERR', nil
                end
                return (r and 'T' or 'F'), REP
            end

            for name, h in pairs(heroes or {}) do
                bump('rows')
                if h ~= nil and h:GetTeam() ~= nMyTeam then
                    -- Limit (iii): scored against the wrong side's team globals.
                    bump('off_team')
                elseif h ~= nil and h:IsAlive() then
                    bump('own')
                    local vLoc = h:GetLocation()
                    local tE = J.GetEnemiesNearLoc(vLoc, POCKET_R) or {}
                    if #tE >= 2 then
                        bump('pocket2')
                        -- arm D: gate OFF, no target at all -> the shipped
                        -- fallback. Row-level, so it is driven once.
                        local rD = drive(h, vLoc, false, nil)
                        for _, e in pairs(GetUnitList(UNIT_LIST_ENEMY_HEROES) or {}) do
                            if J.IsValidHero(e) and not J.IsSuspiciousIllusion(e)
                                and not J.IsMeepoClone(e) then
                                local bIn = false
                                for _, p in pairs(tE) do
                                    if p == e then bIn = true end
                                end
                                local d = GetUnitToLocationDistance(e, vLoc)
                                local rA = drive(h, vLoc, false, e)   -- shipped
                                local rB, pB = drive(h, vLoc, true, e) -- narrowed
                                local rA2 = drive(h, vLoc, false, e)  -- shipped, again
                                if rA2 == rA then bump('fire_a2') end
                                if bIn then
                                    bump('in_p')
                                    if MAX_IN_D == nil or d > MAX_IN_D then
                                        MAX_IN_D = d
                                    end
                                    -- arm C is arm B restricted to the INTENDED
                                    -- domain: the gate must not touch it.
                                    if rA ~= rB then bump('flip_ac') end
                                    -- ...and the BRANCH behind that claim: armed,
                                    -- an in-pocket target must still be the
                                    -- representative the guard spends.
                                    if pB == nil then
                                        bump('in_rep_unseen')
                                    elseif pB == e then
                                        bump('in_rep_kept')
                                    else
                                        bump('in_rep_swapped')
                                    end
                                else
                                    bump('far')
                                    if MIN_FAR_D == nil or d < MIN_FAR_D then
                                        MIN_FAR_D = d
                                    end
                                    if d < 3000 then bump('near_pairs') end
                                    -- Armed, an OFF-pocket target must never be
                                    -- the representative. Same branch count, on
                                    -- the other side of the membership test.
                                    if pB == nil then
                                        bump('far_rep_unseen')
                                    elseif pB == e then
                                        bump('far_rep_kept')
                                    else
                                        bump('far_rep_swapped')
                                    end
                                    if rA == 'T' then bump('fire_a') end
                                    if rB == 'T' then bump('fire_b') end
                                    if rD == 'T' then bump('fire_d') end
                                    if rB ~= rD then bump('bd_mismatch') end
                                    if rA ~= rD then bump('flip_ad') end
                                    if rA ~= rB then
                                        bump('flip_ab')
                                        if rA == 'T' then
                                            bump('a1b0')
                                        else
                                            bump('a0b1')
                                        end
                                        if d < 3000 then bump('near_flip') end
                                        if MIN_FLIP_D == nil or d < MIN_FLIP_D then
                                            MIN_FLIP_D = d
                                        end
                                        if path:sub(-#WITNESS) == WITNESS
                                            and name == WITNESS_HERO
                                            and rA == 'F' and rB == 'T' then
                                            WITNESS_SEEN = true
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end
    return c
end

local function census_or_die()
    if SWEEP == nil and SWEEP_ERR == nil then
        local ok, res = pcall(run_sweep)
        if ok then SWEEP = res else SWEEP_ERR = tostring(res) end
    end
    assert(SWEEP ~= nil, 'the corpus sweep did not run: ' .. tostring(SWEEP_ERR))
end

-- ------------------------------------------------------------- §2 census ---

tests['[divepocket] 2. the corpus drove, and the domain is not empty'] = function()
    census_or_die()
    assert(SWEEP['load_fail'] == 0,
        SWEEP['load_fail'] .. ' corpus file(s) failed to load. Every count in '
        .. 'this file is then taken over a smaller corpus than it claims.')
    -- 2026-09-17 (replay-check): 142 -> 144, the two staged `campbind`
    -- condition-(a) frames (tests/frames/README.md carries the row).
    -- RE-MEASURED, not edited: every count below was re-run over the grown
    -- corpus and is asserted unchanged, so this is a denominator move.
    assert(SWEEP['frames'] == 144,
        'corpus size moved: ' .. SWEEP['frames'] .. ' frames, was 144. Re-read '
        .. 'every count below before quoting it.')
    -- 657 -> 665 on 2026-09-17: the two staged `campbind` frames each carry 4
    -- live subject-team hero rows besides the subject.  The guard's own domain
    -- counts below are asserted unchanged over the grown corpus.
    assert(SWEEP['own'] == 665,
        'live subject-team rows moved: ' .. SWEEP['own'] .. ', was 665.')
    assert(SWEEP['raised'] == 0,
        SWEEP['raised'] .. ' drive(s) raised. An arm that errored is not an arm '
        .. 'that answered.')
    -- ⭐ The team filter is doing real work rather than silently emptying the
    --    drive: limit (iii) is a restriction, not a wipe.
    assert(SWEEP['off_team'] > 0,
        'no opposing-team rows were skipped, so either the corpus changed shape '
        .. 'or GetTeam() no longer separates the sides -- limit (iii) is then '
        .. 'not describing this drive.')
    assert(SWEEP['pocket2'] == 58,
        'the 2+ enemy pocket domain moved: ' .. SWEEP['pocket2'] .. ' rows, '
        .. 'was 58. This is the guard\'s own entry condition; nothing below is '
        .. 'comparable across a change in it.')
    assert(SWEEP['far'] == 154 and SWEEP['in_p'] == 126,
        'the (row, enemy) pair split moved: far=' .. SWEEP['far'] .. ' in='
        .. SWEEP['in_p'] .. ', was 154/126.')
    -- ⭐ THE INSTRUMENT CONTROL. A broken distance call would hand back the same
    --    split for free. The two sides must straddle the parsed radius.
    assert(MIN_FAR_D ~= nil and MIN_FAR_D > POCKET_R,
        'an "off-pocket" pair sits at ' .. tostring(MIN_FAR_D) .. ' <= the '
        .. 'parsed pocket radius ' .. tostring(POCKET_R) .. '. The membership '
        .. 'split and the distance instrument disagree.')
    assert(MAX_IN_D ~= nil and MAX_IN_D <= POCKET_R,
        'an "in-pocket" pair sits at ' .. tostring(MAX_IN_D) .. ' > the parsed '
        .. 'pocket radius ' .. tostring(POCKET_R) .. '.')
end

-- --------------------------------------------------------------- §3 arms ---

tests['[divepocket] 3. four arms: the gate is load-bearing and both signs are reported'] = function()
    census_or_die()
    -- Arm A (shipped) vs arm B (narrowed), on the off-pocket pairs.
    assert(SWEEP['fire_a'] == 49,
        'arm A (shipped) fires ' .. SWEEP['fire_a'] .. ', was 49.')
    assert(SWEEP['fire_b'] == 29,
        'arm B (narrowed) fires ' .. SWEEP['fire_b'] .. ', was 29.')
    -- ⭐ THE GATE-BEARING ASSERTION. If the `J.IsSoakCandidate` conjunct were
    --    dropped, arm A would BE arm B and this would read 0. A textual match
    --    (§1c) guards the spelling; this guards the branch.
    assert(SWEEP['flip_ab'] == 22,
        'the armed/shipped difference moved: flip_ab=' .. SWEEP['flip_ab']
        .. ', was 22. A ZERO here means the gate is no longer separating the '
        .. 'two arms -- check that the narrowing is still conditional before '
        .. 'reading anything else.')
    -- ⭐ BOTH SIGNS, because this is not a subset narrowing and a one-sided
    --    claim here would be false.
    assert(SWEEP['a1b0'] == 21 and SWEEP['a0b1'] == 1,
        'the flip signs moved: suppress->not ' .. SWEEP['a1b0'] .. ', not->'
        .. 'suppress ' .. SWEEP['a0b1'] .. ', was 21/1. The single reverse flip '
        .. 'is the witness this repair is argued from (§4) -- losing it is not '
        .. 'a tidier result, it is the evidence leaving.')
    -- Arm C: the INTENDED domain is untouched by the gate.
    assert(SWEEP['flip_ac'] == 0,
        SWEEP['flip_ac'] .. ' of the ' .. SWEEP['in_p'] .. ' in-pocket pairs '
        .. 'changed answer when the gate was armed. The narrowing is supposed '
        .. 'to be invisible there -- an in-pocket target is kept.')
    -- ⭐⭐ COUNT THE BRANCH, NOT THE ANSWER. The line above is a real reading
    --    and NOT a discriminating one: the mutation stand's M4 (discard the
    --    target unconditionally) SURVIVES it, because on this corpus swapping an
    --    in-pocket representative for the pocket's lowest-HP enemy changes no
    --    answer. These two read the representative J.SafeToCommitFight was
    --    actually handed, so "kept" and "silently swapped" stop being the same
    --    observation. (This desk's (戊) rule, earned here the same way: the first
    --    stand run scored M4 SURVIVED and that was the product, not the rework.)
    assert(SWEEP['in_rep_swapped'] == 0,
        SWEEP['in_rep_swapped'] .. ' in-pocket target(s) were REPLACED as the '
        .. 'representative while the gate was armed. An in-pocket target is the '
        .. 'one case the narrowing must leave alone; the answers may be '
        .. 'unchanged on this corpus, but the branch taken is wrong.')
    assert(SWEEP['far_rep_kept'] == 0,
        SWEEP['far_rep_kept'] .. ' OFF-pocket target(s) were still spent as the '
        .. 'representative while the gate was armed. That is the defect itself, '
        .. 'not a narrowing of it.')
    -- The branch counters must actually have observed something, or both zeros
    -- above are free (the GH #171 shape, one layer down).
    assert(SWEEP['in_rep_kept'] > 0 and SWEEP['far_rep_swapped'] > 0,
        'the representative was never observed on one side or the other (in_kept='
        .. SWEEP['in_rep_kept'] .. ' far_swapped=' .. SWEEP['far_rep_swapped']
        .. '). J.SafeToCommitFight may no longer be the function the '
        .. 'representative is spent on, in which case the wrapper is reading a '
        .. 'branch that no longer exists and the two zeros above are free.')
    -- Arm D: end-to-end confirmation that "narrowed" == "fell through to the
    -- pocket representative", driven through the shipped nil path.
    assert(SWEEP['bd_mismatch'] == 0,
        SWEEP['bd_mismatch'] .. ' off-pocket pair(s) where the ARMED answer and '
        .. 'the shipped no-target answer differ. Armed, the off-pocket target is '
        .. 'supposed to be discarded outright -- if these two ever part, the '
        .. 'narrowing is doing something other than falling through.')
    assert(SWEEP['flip_ad'] == SWEEP['flip_ab'],
        'flip_ad=' .. SWEEP['flip_ad'] .. ' but flip_ab=' .. SWEEP['flip_ab']
        .. '. These count the same set by two routes; a split means arm B is no '
        .. 'longer the fallback.')
    -- Statelessness, measured rather than assumed: the sisters had to re-load
    -- per arm because their host accumulated module state across calls.
    assert(SWEEP['fire_a2'] == SWEEP['far'] + SWEEP['in_p'],
        'arm A answered differently when re-driven on '
        .. (SWEEP['far'] + SWEEP['in_p'] - SWEEP['fire_a2'])
        .. ' pair(s). J.ShouldSuppressDive now carries state across calls, so '
        .. 'every arm in this file needs a fresh rf.load.')
end

-- ------------------------------------------------------------ §4 witness ---

tests['[divepocket] 4. the near-band witness, pinned by name'] = function()
    census_or_die()
    -- ⭐⭐ The frame the repair is argued from. Pinned by fixture AND hero AND
    --    direction, so a corpus change cannot turn this section green on an
    --    empty set (the way an unpinned "flip_ab > 0" would).
    assert(WITNESS_SEEN,
        'the near-band witness is gone: ' .. WITNESS .. ' / ' .. WITNESS_HERO
        .. ' no longer flips DON\'T-SUPPRESS -> SUPPRESS when the gate is '
        .. 'armed. Every claim in this file about the repair doing the guard\'s '
        .. 'stated job rests on that one pair; re-find it or re-argue the fix.')
    assert(MIN_FLIP_D ~= nil and MIN_FLIP_D < 3000,
        'the nearest flipping pair is now at ' .. tostring(MIN_FLIP_D)
        .. ' units. Beyond ~3000 the two 1200-radius discs are disjoint and a '
        .. 'flip is nearly free -- with nothing left inside that band this file '
        .. 'would be pricing only the cheap half of the effect.')
end

-- ------------------------------------------------------------ §5 control ---

tests['[divepocket] 5. positive controls for the small numbers'] = function()
    census_or_die()
    -- ⭐ A ZERO HERE WOULD BE A DEAD INSTRUMENT, NOT A FINDING. The near band is
    --   where the repair is realistic, so the corpus must actually hold pairs in
    --   it -- otherwise §4's single witness is the whole band and the "10 pairs,
    --   1 flip" reading below is not a reading.
    assert(SWEEP['near_pairs'] == 10,
        'the near band (off-pocket, < 3000u) moved: ' .. SWEEP['near_pairs']
        .. ' pairs, was 10.')
    assert(SWEEP['near_flip'] == 1,
        'the near band now holds ' .. SWEEP['near_flip'] .. ' flip(s), was 1.')
    -- ⭐ THE OTHER HALF OF THE CONTROL: the guard fires at all on this corpus,
    --   so the narrowing is trimming a leg that DOES answer, not emptying one
    --   that never fires. (The GH #782 family's (庚), restated here.)
    assert(SWEEP['fire_a'] > 0 and SWEEP['fire_d'] > 0,
        'the guard answers TRUE on no off-pocket pair in either arm (a=' ..
        SWEEP['fire_a'] .. ' d=' .. SWEEP['fire_d'] .. '). Then nothing here is '
        .. 'measuring a live branch.')
    assert(SWEEP['fire_b'] == SWEEP['fire_d'],
        'arm B and arm D disagree in total (' .. SWEEP['fire_b'] .. ' vs '
        .. SWEEP['fire_d'] .. ') even though §3 found them pairwise identical.')
end

return tests

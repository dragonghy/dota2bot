-- [ratchet] [hero] GH #799 acceptance 3, paid on REAL FRAMES: the skill queue
-- head leaves untrained while the entries BEHIND it are consumed.
--
-- ZERO behaviour change.  No line of bots/ or game/ moves in the change that
-- adds this file; no gate id, no arm, no promote, no AWS, no wave request.
--
-- WHAT THIS FILE ADDS THAT THE EXISTING FILES DO NOT HAVE
-- ----------------------------------------------------------------------------
-- tests/test_skillstall_lookahead.lua closes its header with, verbatim:
--     "⛔ NOT CLAIMED HERE: any in-game reading.  Nothing in this file says how
--      often the branch is entered, and the corpus cannot say"
-- and tests/test_skill_point_stall_frame.lua reads ONE staged frame -- the END
-- state (ten heroes already walled), never the wall going up or coming down.
-- So every existing assertion in this family is either source shape or a single
-- terminal snapshot.  This file pins the TRANSITION, off two real frames of one
-- real game, which is what acceptance 3 asked for.
--
-- THE GAME, AND WHY THESE TWO INSTANTS
-- ----------------------------------------------------------------------------
-- dem21/spot_20260902_214528_1_..._ab6c0d/20260902_220100_slot6.dem
-- subject: npc_dota_hero_bristleback, dumper idx=1498 (ONE body in this game --
-- checked, because the W71 pit is that a name can own five).
--
--   t=650.4   hero level 14.  Build ranks {goo 3, quill 4, bristle 4, warpath 2}
--             = THIRTEEN build points, plus ONE talent (special_bonus_m_p_regen150,
--             taken at t=478.4, hero level 10).  FOURTEEN skill-list entries
--             consumed.  `prickly` sits at rank 1 and is the innate -- never a
--             build point, and section 4 refuses to let it be counted as one.
--             This is the wall going up.
--
--   t=1085.4  hero level 24.  Build ranks {goo 4, quill 4, bristle 4, warpath 2}
--             = FOURTEEN build points, and STILL ONE talent.  FIFTEEN entries
--             consumed.  This is the wall coming down -- and the entry that came
--             out is an ABILITY while the talent count did not move.
--
-- Between them the hero was ALIVE and thinking from t=650.4 to t=1012.7 (its
-- next death), climbing hero level 14 -> 19, and spent NOTHING: five levels, ~362
-- seconds, five banked points.  That is the defect, measured, in a shipped-default
-- game (`skillstall` did not exist when this corpus was recorded).
--
-- WHY THE HEAD AT t=650.4 IS SLOT 15 = T2 -- ARITHMETIC, NOT A READ
-- ----------------------------------------------------------------------------
-- aba_skill.lua X.GetSkillList places a talent when `i >= 10 and (i % 5 == 0 or
-- abilities exhausted)`.  With 15 ability entries and 8 talents the queue is
--     [a1..a9, T1, a10..a13, T2, a14, a15, T3..T8]
-- so 13 abilities + 1 talent fill slots 1..14 exactly, and the head is slot 15 = T2.
-- ⛔ THIS IS SOURCE ARITHMETIC PLUS THE MEASURED LEDGER, NOT A DIRECT READ OF T2.
-- The dumper cannot see an untrained talent at all (tests/test_fixture_talent_blindness.lua:
-- an untrained talent has no parsable handle -- it appears only when taken), so no
-- frame in this repo can show T2 sitting at the head.  Section 3 asserts the
-- ledger, which is what the frames actually carry; it does NOT assert T2's identity.
--
-- ⚠️ WHAT THIS FILE REFUSES TO SAY, and the previous round said it
-- ----------------------------------------------------------------------------
-- The 2026-09-14T00:51Z replay-check round read this same game as settling
-- acceptance 1's survivor -- "23 级假、24 级真, so the flipping term can only be
-- GetHeroLevelRequiredToUpgrade".  Frame by frame that does not hold, for two
-- independent reasons, and section 5 pins both so the claim cannot come back:
--
--   1. THE HERO IS NEVER ALIVE AT LEVEL 23.  A single XP event of 12376 at
--      t=1012.2 carried it 19 -> 24 in one step.  There is no level-23 frame to
--      have observed anything at.
--   2. LEVEL 24 AND THE RESPAWN ARE CONFOUNDED.  It died 0.5s after that XP grant
--      (t=1012.7, to nevermore), lay dead ~71s (hp_pct 0.000 on every frame from
--      t=1013.4 to t=1083.4), respawned at t=1084.4, and spent at t=1085.4 -- one
--      second after its first live frame in 71 seconds.  "the level requirement
--      turned true at 24" and "a dead bot cannot think, and it spent on its first
--      live frame" predict the SAME timestamp in this game.  Nothing here separates
--      them.
--
-- Nor does this file name the branch.  Below hero level 26 the terminal `else`
-- removes nothing, so the head left by one of the two middle branches of
-- ability_item_usage_generic.lua: `generic_hidden` (removes the head untrained AND
-- immediately levels the entry behind it) or "still try it".  The observed pair --
-- goo 3->4 at t=1085.4, warpath 2->3 at t=1086.4 -- fits both.  ⛔ The previous
-- round ruled `generic_hidden` out on the grounds that `skillstall` was unarmed;
-- that does not follow -- the gate sits inside the terminal `else`, and
-- `generic_hidden` is a different branch that the gate has no bearing on.
--
-- Tagged [ratchet]: sections 1-3 are REGISTERED EXCEPTIONS -- they assert the
-- defect is still there.  The day the stall is fixed they go red, which is the
-- notification.  Delete them then; do not loosen them.

package.path = 'tests/?.lua;' .. package.path

local rf = require('mock.replay_fixture')

-- ⚠️ PARKED IN A SUBDIRECTORY ON PURPOSE, and it was a MEASURED decision, not a
-- filing preference.  95 tests enumerate the corpus with `ls tests/fixtures` and
-- 47 more with `tests/fixtures/*.lua`; both globs are flat, so a subdirectory is
-- outside them (the existing `tests/fixtures/outchan/` is the precedent).
-- Dropped into the flat corpus instead, these two frames added two Crystal Maiden
-- instants and a second talent row to a sample that several censuses pin exactly:
--     test_cm_ult_reach_meter_domain.lua:429  live-CM instants: expected 70, got 72
--     test_cm_cmqreach_transit_frame.lua:321  "2 talent rows on some hero, not 1"
-- Both are GREEN with these fixtures parked and RED with them flat -- measured
-- both ways before this line was written.  That is the GH #624 shape exactly: a
-- census asserts "the corpus is the set already read", so ANY desk landing a new
-- frame reddens tests it never touched, and the red surfaces on the NEXT desk.
-- ⛔ Do not "fix" this by moving them up one level and bumping the census numbers:
-- 415 tests read this corpus and the suite that covers them is the ~100-min one
-- (GH #124), so that edit cannot be validated inside one work unit.  These two
-- frames are a targeted PAIR for one defect, not sample material -- they have no
-- business changing anybody's denominator.
local WALL  = 'tests/fixtures/skillstall/f_ab6c0d_bristleback_skillwall_650.lua'
local DRAIN = 'tests/fixtures/skillstall/f_ab6c0d_bristleback_skilldrain_1085.lua'

local SUBJECT = 'npc_dota_hero_bristleback'
local INNATE  = 'bristleback_prickly'

local BUILD_ABILITIES = {
    'bristleback_viscous_nasal_goo',
    'bristleback_quill_spray',
    'bristleback_bristleback',
    'bristleback_warpath',
}

local tests = {}

--- Read the subject's ledger off a fixture with the REAL mock handles: total
--- build points, talent count, and the per-ability ranks.
--- `prickly` is excluded BY NAME as the innate; section 4 proves that exclusion
--- is load-bearing rather than cosmetic.
local function ledger(sFixture)
    local J, bot, heroes, fx = rf.load(sFixture)
    local t = { ranks = {}, build_points = 0, talents = 0, level = bot:GetLevel() }
    for _, sName in ipairs(BUILD_ABILITIES) do
        local h = bot:GetAbilityByName(sName)
        assert(h ~= nil, sFixture .. ': no handle for ' .. sName)
        local n = h:GetLevel()
        t.ranks[sName] = n
        t.build_points = t.build_points + n
    end
    local hInnate = bot:GetAbilityByName(INNATE)
    t.innate_rank = hInnate and hInnate:GetLevel() or 0
    -- Talent count: the engine's own `special_bonus_` name prefix, which
    -- classifies nothing (it is the dumper's own filter key too).
    for _, u in ipairs(fx.units or {}) do
        if u.name == SUBJECT then
            for _, a in ipairs(u.abilities or {}) do
                if a.name:sub(1, 14) == 'special_bonus_' then
                    t.talents = t.talents + (a.level or 0)
                end
            end
        end
    end
    return t, J, bot, heroes
end

-- =========================================================================
-- SECTION 1 -- the wall goes up: 14 entries consumed at hero level 14
-- =========================================================================
tests.wall_frame_holds_fourteen_entries = function()
    local L = ledger(WALL)
    assert(L.level == 14,
        'wall frame: expected hero level 14, got ' .. tostring(L.level))
    assert(L.build_points == 13,
        'wall frame: expected 13 build points, got ' .. tostring(L.build_points))
    assert(L.talents == 1,
        'wall frame: expected exactly 1 talent, got ' .. tostring(L.talents))
    -- 13 + 1 = the FOURTEEN consumed entries #366 measured on ten unrelated heroes.
    assert(L.build_points + L.talents == 14,
        'wall frame: expected 14 consumed skill-list entries, got '
        .. tostring(L.build_points + L.talents))
end

-- =========================================================================
-- SECTION 2 -- the wall comes down: one more ABILITY, talent count unmoved
-- =========================================================================
tests.drain_frame_spends_an_ability_not_the_talent = function()
    local L = ledger(DRAIN)
    assert(L.level == 24,
        'drain frame: expected hero level 24, got ' .. tostring(L.level))
    assert(L.build_points == 14,
        'drain frame: expected 14 build points, got ' .. tostring(L.build_points))
    assert(L.talents == 1,
        'drain frame: talent count must NOT have moved; expected 1, got '
        .. tostring(L.talents))
end

-- =========================================================================
-- SECTION 3 -- ⭐ acceptance 3 itself: the head left UNTRAINED and the
--              entries behind it were consumed anyway.
-- =========================================================================
tests.head_leaves_untrained_while_tail_is_consumed = function()
    local W = ledger(WALL)
    local D = ledger(DRAIN)

    -- Ten hero levels apart.
    assert(D.level - W.level == 10,
        'expected the two frames to be 10 hero levels apart, got '
        .. tostring(D.level - W.level))

    -- The queue ADVANCED: a later entry was consumed.
    assert(D.build_points - W.build_points == 1,
        'expected exactly one further build point spent across the wall, got '
        .. tostring(D.build_points - W.build_points))

    -- ...and the entry that was sitting at the head was NOT trained.  If the
    -- head (slot 15, a talent by GetSkillList's arithmetic) had been levelled,
    -- this delta would be 1, not 0.
    assert(D.talents - W.talents == 0,
        'THE acceptance-3 assertion: the talent at the queue head must leave '
        .. 'untrained.  talents went ' .. tostring(W.talents) .. ' -> '
        .. tostring(D.talents))

    -- The one that moved is a build ability, and it is the next build entry.
    assert(D.ranks['bristleback_viscous_nasal_goo'] == 4
        and W.ranks['bristleback_viscous_nasal_goo'] == 3,
        'expected the consumed entry to be viscous_nasal_goo 3->4')
end

-- =========================================================================
-- SECTION 4 -- the innate is not a build point (guards the count above)
-- =========================================================================
tests.innate_is_rank_one_and_excluded = function()
    for _, f in ipairs({ WALL, DRAIN }) do
        local L = ledger(f)
        assert(L.innate_rank == 1,
            f .. ': prickly is the innate and must read rank 1, got '
            .. tostring(L.innate_rank))
    end
    -- If prickly were folded in, both counts would be one too high and
    -- section 1's "14 consumed entries" would silently become 15.
    local W = ledger(WALL)
    assert(W.build_points + W.talents + W.innate_rank == 15,
        'sanity: folding the innate in would read 15, which is why it is excluded')
end

-- =========================================================================
-- SECTION 5 -- ⚠️ the two confounds, pinned so the retracted claim cannot
--              quietly come back.  These assert the EVIDENCE's shape, not a
--              mechanism.
-- =========================================================================
tests.level_23_is_absent_and_respawn_is_confounded = function()
    local W = ledger(WALL)
    local D = ledger(DRAIN)
    -- The corpus jumps 19 -> 24 on one XP event, so no level-23 frame exists and
    -- the two frames are 10 levels apart rather than adjacent.  A future reader
    -- who believes "23 false, 24 true" was read here has to break this first.
    assert(D.level - W.level > 1,
        'the two frames are not adjacent levels; no per-level threshold can be '
        .. 'read off this pair')
    assert(D.level == 24 and W.level == 14,
        'the pinned pair is exactly (14, 24)')
end

-- ---------------------------------------------------------------------------
-- ⛔ NO inline runner here, and the reason is a measured trap: rf.load replaces
-- the global `print` with a no-op (the mock enforces the repo's "no bot-side
-- debugging" rule).  A hand-rolled runner that reports through `print` therefore
-- emits NOTHING and still exits 0 -- which reads exactly like a clean pass and
-- is not one.  Report through tests/run_tests.lua, which does not use `print`.
return tests

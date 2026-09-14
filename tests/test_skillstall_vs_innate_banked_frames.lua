-- [ratchet] [bug] GH #822 acceptance 1, paid on REAL FRAMES -- and it pays back
-- a CORRECTION to the very reading that asked for it.
--
-- ZERO behaviour change.  No line of bots/ or game/ moves in the change that
-- adds this file; no gate id, no arm, no promote, no AWS, no wave request.
--
-- ⚠️ READ THIS FIRST: THE ISSUE'S OWN TABLE IS OFF BY ONE, IN THE SAFE DIRECTION
-- ----------------------------------------------------------------------------
-- GH #822 publishes, for this exact body, "可见已花 14 / banked >= 2" at hero
-- level 18 and ">= 5" at level 22, from
--
--     banked = level - sum(visible ability ranks) - #{tiers 10,15,20,25 reached}
--
-- as `tools/batch_test/behavioral/ability_exhaustion_split.py:160` computes it.
-- That sum counts `vengeful_spirit_revenge` -- a rank the bot NEVER BOUGHT.
-- Section 1 buys that on frames rather than on Dota folklore:
--
--   t=-68.9  hero level 1, ranks {revenge 1, everything else 0} -- sum 1.
--   t=0.1    hero level 1 STILL, ranks {revenge 1, wave_of_terror 1} -- sum 2.
--
-- Two visible ranks while the engine has granted exactly ONE point (level 1)
-- ⇒ at least one rank was never bought.  WHICH one is settled by the same pair:
-- the row that MOVED between the two frames is wave_of_terror (that is the
-- level-1 point being spent), and the row already standing at 1 before any
-- spend is `revenge`.  ⇒ visible spent at level 18/22 is 13, not 14, and the
-- corrected banked counts are 3 and 6.
--
-- ⭐ DIRECTION MATTERS MORE THAN THE DIGIT.  The uncorrected formula makes
-- `banked` SMALLER, so #822's `PROVEN 229` is a LOWER BOUND and its conclusion
-- survives intact.  Section 3 pins BOTH numbers -- the corrected one and the
-- published one -- so the day someone fixes the meter, this file states what
-- the old number was instead of silently re-baselining.
--
-- ⛔ WHAT THIS IS NOT.  It is NOT the nevermore linked-raze inflation (LIMIT A
-- of that same tool, and the subject of tests/test_skillstall_banked_point_
-- frames.lua's `ledger()` invariant).  Linked rows move TOGETHER LATER; a free
-- innate rank stands at 1 BEFORE the first point is spent and never moves
-- again.  Both inflate the same subtraction; they are different mechanisms and
-- a fix for one does not touch the other.  (Measured in this same game at hero
-- level 1: nevermore's three razes sum to 3 against 1 granted point -- linked;
-- VS/WD/SK/BB/SS each carry exactly one standing rank -- innate.)
--
-- THE GAME, AND WHY THESE FOUR INSTANTS
-- ----------------------------------------------------------------------------
-- All four from W40, dem21/spot_20260902_214528_1_..._ab6c0d/,
-- 20260902_214620_slot1.dem, npc_dota_hero_vengeful_spirit, idx=1243.
-- ⚠️ Body identity checked per the W71 pit (a name can own five bodies in one
-- game, and "the first one called X" silently reads an illusion or a corpse):
-- `sorted({s['idx'] for s in snaps if s['hero']=='npc_dota_hero_vengeful_
-- spirit'})` is [1243] -- ONE body, no illusion to confuse -- and each fixture
-- below carries exactly one row for the subject.
--
--   t=-68.9   level 1, pre-spend.  Section 1's open end.
--   t=0.1     level 1, post-spend (horn).  Section 1's close end.
--   t=1007.1  level 18, LAST frame of the level.  Ledger {magic_missile 4,
--             wave_of_terror 4, command_aura 3, revenge 1, nether_swap 2}.
--   t=1514.1  level 22, LAST frame of the level, 507.0 s later.  Ledger
--             BIT-IDENTICAL.  The dump says: alive on all 508 of the 1 Hz
--             frames between them, levels 18/19/20/21/22, command_aura pinned
--             at 3 throughout, and the next ledger movement is t=1520.1 at hero
--             level 24 -- where `command_aura` 3->4 and `nether_swap` 2->3 land
--             ONE SECOND APART.  A fixture carries the ENDS, which is what it
--             can; the interior is read off the dump and stated in the issue.
--
-- ⭐ WHY command_aura AND NOT A TALENT.  `vengeful_spirit_command_aura` is a
-- plain ability: its own entity class, kept by the dumper, rank 3 read directly
-- off the frame.  Nothing in this file rests on the talent blind spot that
-- forced GH #817's acceptance onto OD (tests/test_talent_uptake_visibility.lua
-- is the authority for that mechanism).  Section 4 pins that the blind spot is
-- still there and still not load-bearing here.
--
-- ⚠️ WHAT THIS FILE REFUSES TO SAY
-- ----------------------------------------------------------------------------
--   * ANY claim resting on a level requirement.  "rank 4 of command_aura is
--     legal at hero level 18" is a Dota rule, not a reading; nothing here reads
--     GetHeroLevelRequiredToUpgrade, and the dumper cannot buy it offline.
--   * WHICH branch left the point unspent.  These frames separate none of the
--     survivors named in FindUpgradableBehindHead's header comment.
--   * That any point was WASTED.  LIMIT B of the wave meter: a point held at
--     18 and spent at 24 is a DELAY.  This file measures the delay's ends.
--
-- Tagged [ratchet]: sections 1-3 are REGISTERED EXCEPTIONS -- they assert the
-- defect is still there.  The day the stall is fixed they go red, which is the
-- notification.  Delete them then; do not loosen them.

package.path = 'tests/?.lua;' .. package.path

local rf = require('mock.replay_fixture')

-- ⚠️ PARKED IN A SUBDIRECTORY for the reason measured by the sibling file: the
-- 95 + 47 corpus globs under tests/ are flat, so tests/fixtures/skillstall/ is
-- outside them.  ⛔ That does NOT hide these frames from the RECURSIVE census
-- in tests/test_slotdust_dust_arbitration.lua (`grep -rho tests/fixtures/`),
-- which does read them -- measured when this file landed, see the report.
local VS_PRE   = 'tests/fixtures/skillstall/f_ab6c0d_vs_innatepre_m69.lua'
local VS_POST  = 'tests/fixtures/skillstall/f_ab6c0d_vs_innatepost_0.lua'
local VS_L18   = 'tests/fixtures/skillstall/f_ab6c0d_vs_banked18_1007.lua'
local VS_L22   = 'tests/fixtures/skillstall/f_ab6c0d_vs_banked22_1514.lua'

local SUBJECT = 'npc_dota_hero_vengeful_spirit'

-- Vengeful Spirit has no linked group (contrast nevermore's three razes), so
-- one point raises exactly one row and `spent` is a plain sum.
local ROWS = {
    'vengeful_spirit_magic_missile',
    'vengeful_spirit_wave_of_terror',
    'vengeful_spirit_command_aura',
    'vengeful_spirit_revenge',
    'vengeful_spirit_nether_swap',
}

local TIERS = { 10, 15, 20, 25 }

local tests = {}

--- Read the subject's ledger off a fixture through the REAL mock handles.
local function ledger(sFixture)
    local _, bot, _, fx = rf.load(sFixture)
    local t = { ranks = {}, level = bot:GetLevel(), talent_rows = 0, visible = 0,
                t = fx.time }
    for _, sName in ipairs(ROWS) do
        local h = bot:GetAbilityByName(sName)
        assert(h ~= nil, sFixture .. ': no handle for ' .. sName)
        local n = h:GetLevel()
        t.ranks[sName] = n
        t.visible = t.visible + n
    end
    for _, u in ipairs(fx.units or {}) do
        if u.name == SUBJECT then
            for _, a in ipairs(u.abilities or {}) do
                if a.name:sub(1, 14) == 'special_bonus_' then
                    t.talent_rows = t.talent_rows + 1
                end
            end
        end
    end
    return t
end

local function tiers_reached(nLevel)
    local n = 0
    for _, nTier in ipairs(TIERS) do
        if nLevel >= nTier then n = n + 1 end
    end
    return n
end

-- =========================================================================
-- SECTION 1 -- ⭐ THE CORRECTION, bought on frames: exactly one of this body's
--              visible ranks was never paid for, and it is `revenge`.
-- =========================================================================
tests.one_visible_rank_was_never_bought_and_it_is_revenge = function()
    local P, Q = ledger(VS_PRE), ledger(VS_POST)

    -- ⚠️ THE ENDS MUST BE TWO DIFFERENT INSTANTS.  Without this, two paths that
    -- happen to name the same file make the whole section trivially true.
    assert(math.abs((Q.t - P.t) - 69.0) < 0.05,
        'the level-1 pair must span 69.0 s, got ' .. tostring(Q.t - P.t)
        .. ' (t=' .. tostring(P.t) .. ' -> ' .. tostring(Q.t) .. ')')
    assert(P.level == 1 and Q.level == 1,
        'BOTH frames must still be hero level 1 -- that is what caps the granted '
        .. 'points at one.  Got ' .. tostring(P.level) .. ' / ' .. tostring(Q.level))

    assert(P.visible == 1,
        'pre-spend frame: expected 1 visible rank, got ' .. tostring(P.visible))
    assert(Q.visible == 2,
        'post-spend frame: expected 2 visible ranks, got ' .. tostring(Q.visible))

    -- THE inequality.  One point granted, two ranks standing.
    local nFree = Q.visible - Q.level
    assert(nFree == 1,
        'THE acceptance inequality: visible ranks minus granted points must be '
        .. '1 free rank at hero level 1, got ' .. tostring(nFree))

    -- ...and the free row is identified, not assumed: it is the one that is
    -- already >= 1 BEFORE the first spend and does not move across it.
    assert(P.ranks['vengeful_spirit_revenge'] == 1
        and Q.ranks['vengeful_spirit_revenge'] == 1,
        'revenge must read 1 at BOTH level-1 frames (a free rank never moves), got '
        .. tostring(P.ranks['vengeful_spirit_revenge']) .. ' / '
        .. tostring(Q.ranks['vengeful_spirit_revenge']))
    -- Positive control for that "does not move" read: the SAME reader, on the
    -- SAME pair, DOES see the level-1 point land on wave_of_terror.  Without
    -- this, "revenge did not move" would also be green in a frozen world.
    assert(P.ranks['vengeful_spirit_wave_of_terror'] == 0
        and Q.ranks['vengeful_spirit_wave_of_terror'] == 1,
        'wave_of_terror must go 0 -> 1 across the pair (that IS the level-1 '
        .. 'point being spent), got ' .. tostring(P.ranks['vengeful_spirit_wave_of_terror'])
        .. ' -> ' .. tostring(Q.ranks['vengeful_spirit_wave_of_terror']))
    for _, sName in ipairs({ 'vengeful_spirit_magic_missile',
                             'vengeful_spirit_command_aura',
                             'vengeful_spirit_nether_swap' }) do
        assert(P.ranks[sName] == 0 and Q.ranks[sName] == 0,
            sName .. ' must read 0 at both level-1 frames, got '
            .. tostring(P.ranks[sName]) .. ' / ' .. tostring(Q.ranks[sName]))
    end
end

-- =========================================================================
-- SECTION 2 -- the pure read: FOUR hero levels are crossed with the ability
--              ledger frozen, alive at both ends.
--              ⛔ No claim about banking here -- section 3 buys that.
-- =========================================================================
tests.four_hero_levels_are_crossed_with_the_ledger_frozen = function()
    local O, C = ledger(VS_L18), ledger(VS_L22)

    assert(math.abs((C.t - O.t) - 507.0) < 0.05,
        'the stall pair must span 507.0 s, got ' .. tostring(C.t - O.t)
        .. ' (t=' .. tostring(O.t) .. ' -> ' .. tostring(C.t) .. ')')
    assert(O.level == 18 and C.level == 22,
        'the pair must be hero level 18 -> 22, got '
        .. tostring(O.level) .. ' / ' .. tostring(C.level))
    assert(C.visible == O.visible,
        'the ledger MUST NOT have moved across four hero levels; '
        .. tostring(O.visible) .. ' -> ' .. tostring(C.visible))
    for sName, n in pairs(O.ranks) do
        assert(C.ranks[sName] == n,
            sName .. ' moved ' .. tostring(n) .. ' -> ' .. tostring(C.ranks[sName])
            .. ' inside the 18->22 stall')
    end
    -- The absolute ledger, asserted once so a mutant that drops a row from
    -- ROWS cannot keep this file green on a delta alone.
    assert(O.visible == 14,
        'expected 14 VISIBLE ranks on the stall frames, got ' .. tostring(O.visible))
end

-- =========================================================================
-- SECTION 3 -- ⭐ GH #822 acceptance 1: points provably in hand while an
--              unlocked rank of a PLAIN ABILITY sits unbought -- with the
--              published number and the corrected number both pinned.
-- =========================================================================
tests.vs_holds_banked_points_while_command_aura_sits_at_three = function()
    local O, C = ledger(VS_L18), ledger(VS_L22)

    -- ⛔ This is a SUBTRACTION, not a handle: nothing in the Bot API mock
    -- reports unspent points.  Every tier reached is handed, unconditionally,
    -- to "maybe spent on a row the dumper cannot see" -- so what is left over
    -- is banked no matter what was spent invisibly.
    local nSpentO = O.visible - 1        -- minus the free innate rank, section 1
    local nSpentC = C.visible - 1
    assert(nSpentO == 13 and nSpentC == 13,
        'corrected visible-spent must be 13 at both ends, got '
        .. tostring(nSpentO) .. ' / ' .. tostring(nSpentC))

    local nBankedO = O.level - nSpentO - tiers_reached(O.level)
    local nBankedC = C.level - nSpentC - tiers_reached(C.level)
    assert(nBankedO == 3,
        'THE acceptance assertion (level 18): three banked points, got '
        .. tostring(nBankedO))
    assert(nBankedC == 6,
        'THE acceptance assertion (level 22): six banked points, got '
        .. tostring(nBankedC))
    assert(nBankedC > nBankedO,
        'the banked count must GROW across the stall, got '
        .. tostring(nBankedO) .. ' -> ' .. tostring(nBankedC))

    -- ⚠️ AND the published pair, pinned as published.  ability_exhaustion_
    -- split.py:160 does not subtract the free rank, so GH #822's table reads
    -- one lower at every level.  When that tool is fixed, THIS assertion is the
    -- one that goes red -- which is the notification, not a baseline to bump.
    assert(O.level - O.visible - tiers_reached(O.level) == 2
        and C.level - C.visible - tiers_reached(C.level) == 5,
        'the UNCORRECTED formula must still read 2 / 5 -- those are the numbers '
        .. 'GH #822 published; got '
        .. tostring(O.level - O.visible - tiers_reached(O.level)) .. ' / '
        .. tostring(C.level - C.visible - tiers_reached(C.level)))

    -- ...and the unbought entry is a PLAIN ABILITY, which this instrument sees
    -- perfectly.  No talent blindness is load-bearing anywhere in section 3.
    assert(O.ranks['vengeful_spirit_command_aura'] == 3
        and C.ranks['vengeful_spirit_command_aura'] == 3,
        'command_aura must read rank 3 at both ends of the stall, got '
        .. tostring(O.ranks['vengeful_spirit_command_aura']) .. ' / '
        .. tostring(C.ranks['vengeful_spirit_command_aura']))
    -- Positive control for that rank-3 read: the SAME predicate reads 4 for a
    -- maxed ability in the SAME world.  Without this, "command_aura is at 3"
    -- would also be green in an empty world.
    assert(O.ranks['vengeful_spirit_magic_missile'] == 4,
        'positive control: magic_missile must read rank 4 here, got '
        .. tostring(O.ranks['vengeful_spirit_magic_missile']))
end

-- =========================================================================
-- SECTION 4 -- ⛔ THE REFUSAL, pinned so it cannot decay back into prose.
--              The talent blind spot is still there; it is simply not
--              load-bearing for this subject.
-- =========================================================================
tests.no_frame_here_can_see_an_untrained_talent = function()
    for _, sPath in ipairs({ VS_PRE, VS_POST, VS_L18, VS_L22 }) do
        local L = ledger(sPath)
        assert(L.talent_rows == 0,
            sPath .. ': expected ZERO talent rows on the subject (an untrained '
            .. 'talent has no parsable handle, and a hero-unique trained one is '
            .. 'dropped by the dumper).  Got ' .. tostring(L.talent_rows)
            .. ' -- if the dumper now emits them, the queue-head question is '
            .. 'buyable and this refusal should be replaced by a real read.')
    end
end

-- ---------------------------------------------------------------------------
-- ⛔ NO inline runner here, and the reason is a measured trap: rf.load replaces
-- the global `print` with a no-op (the mock enforces the repo's "no bot-side
-- debugging" rule).  A hand-rolled runner that reports through `print` therefore
-- emits NOTHING and still exits 0 -- which reads exactly like a clean pass and
-- is not one.  Report through tests/run_tests.lua, which does not use `print`.
return tests

-- [ratchet] [bug] GH #817 acceptance 1, paid on REAL FRAMES -- and paid on the
-- subject the instrument can actually answer for.
--
-- ZERO behaviour change.  No line of bots/ or game/ moves in the change that
-- adds this file; no gate id, no arm, no promote, no AWS, no wave request.
--
-- ⚠️ READ THIS FIRST: THE OBVIOUS SUBJECT IS THE WRONG ONE
-- ----------------------------------------------------------------------------
-- GH #817's own "suggested acceptance 1" names nevermore's t=376.1 / t=504.1
-- pair and asks for "the hero reached level 10, points went up, talent count did
-- not move".  Built literally, that assertion is UNSOUND, and the reason landed
-- in the issue thread AFTER the suggestion was written (#817 comment by the hero
-- desk, pinned in tests/test_talent_uptake_visibility.lua):
--
--   nevermore's own build selects `special_bonus_unique_nevermore_4` at t10.
--   Hero-UNIQUE talent rows share the Special_Bonus_Base entity class, which the
--   dumper's isRealAbility() drops BEFORE the "keep it if level > 0" branch.
--   So a point spent on that row does not raise the ledger and does not appear
--   as a talent row.  "nevermore spent nothing at hero level 10" is what this
--   ruler MUST print whether the bot banked the point or spent it.
--
-- ⇒ `hero level - visible points spent` is NOT a banked-point count for
-- nevermore, and section 4 pins exactly that refusal rather than letting it live
-- on as prose.  Sections 1 and 3 keep the nevermore frames for what they DO
-- buy -- pure reads of an ability ledger that does not move.
--
-- The hero desk also named the one subject in that wave where the same
-- arithmetic IS sound: obsidian_destroyer, whose t10 selection is
-- `special_bonus_mp_200` -- a GENERIC row, with its own entity class, which the
-- dumper keeps.  Section 2 is the acceptance, on OD.
--
-- THE GAMES, AND WHY THESE FIVE INSTANTS
-- ----------------------------------------------------------------------------
-- Both from W40, dem21/spot_20260902_214528_1_..._ab6c0d/.
-- ⚠️ Body identity checked per the W71 pit (a name can own five bodies, and
-- "the first one called X" silently reads an illusion or a corpse):
-- `sorted({s['idx'] for s in snaps if s['hero']==h})` is [1352] for nevermore in
-- slot1 and [1462] for OD in slot2 -- ONE body each -- and each fixture below
-- carries exactly one row for its subject.
--
--   20260902_214630_slot2.dem, npc_dota_hero_obsidian_destroyer, idx=1462
--     t=467.1  hero level 10, FIRST frame of the level.  Ranks {arcane_orb 1,
--              astral_imprisonment 4, sanity_eclipse 1, objurgation 0} = SIX
--              points spent.  Ten granted.  FOUR in hand.
--     t=496.1  hero level 10, LAST frame, 29.0 s later.  Ledger bit-identical.
--              Alive on all 30 of the level's 1 Hz frames (the interior is read
--              off the dump; a fixture carries the ENDS, which is what it can).
--     The whole game: OD's last ledger movement is t=342.1 at hero level 7.
--     It reaches level 24 and 1543 s having spent SIX points, and
--     `obsidian_destroyer_objurgation` -- a plain ABILITY, fully visible to this
--     instrument, no talent blindness anywhere near it -- sits at rank 0 from
--     the first frame to the last.  That is GH #286's collapse, measured.
--
--   20260902_214620_slot1.dem, npc_dota_hero_nevermore, idx=1352
--     t=444.1  hero level 10, FIRST frame.  Ranks {shadowraze1/2/3 4,
--              presence 4, requiem 1, frenzy 0}.
--     t=503.1  hero level 10, LAST frame, 59.0 s later.  Ledger bit-identical,
--              alive on all 60 frames.
--     t=504.1  hero level 11, and frenzy goes 0 -> 1 in the same second the
--              level lands.  ⛔ This does NOT show a point was banked through
--              level 10 -- see the warning above.  It shows the ledger moved
--              once across the boundary, and it is section 3's positive control.
--
-- WHY NINE AND NOT SEVENTEEN FOR NEVERMORE -- MEASURED, NOT ASSUMED
-- ----------------------------------------------------------------------------
-- Shadow Fiend's three shadowraze entries are LINKED: one point raises all
-- three.  That is this game's own ledger, not folklore -- all four raze rises
-- are simultaneous and equal (t=-59.9 0->1, t=82.1 1->2, t=168.1 2->3, t=270.1
-- 3->4; 4 of 4 same-frame, no raze ever moves alone).  `ledger()` asserts the
-- necessary half of that on every frame it reads, so the day a raze moves alone
-- this file goes red instead of quietly mis-counting.  ⛔ This is LIMIT 2 of
-- skillstall_wave_meter.py in its smallest form: the ledger-of-LEVELS reads 17
-- where the points spent are 9.  OD has no linked ability, so for OD the two
-- coincide -- which is a second reason the acceptance belongs on OD.
--
-- `nevermore_necromastery` is the innate and is NOT in the ability list at all
-- (it survives only as modifier_nevermore_necromastery), so unlike the
-- bristleback pair in tests/test_skillstall_wall_frame.lua there is no innate
-- row to exclude.  `nevermore_frenzy` is not an innate: it starts at rank 0 and
-- climbs 0->1->2->3->4 over the game, which an innate never does.
--
-- ⚠️ WHAT THIS FILE REFUSES TO SAY
-- ----------------------------------------------------------------------------
--   * ANY claim resting on a level requirement.  "rank 1 of objurgation is
--     legal at hero level 10" is a Dota rule, not a reading; nothing here reads
--     GetHeroLevelRequiredToUpgrade, and the dumper cannot buy it offline.  What
--     section 2 reads is that the point count exceeds the spent count and that
--     an ability sits at rank 0 -- not that the engine would have accepted it.
--   * WHICH branch left the point unspent.  ability_item_usage_generic.lua has
--     several ways to leave a head untrained and these frames separate none of
--     them.  tests/test_skillstall_wall_frame.lua registers the same refusal.
--   * WHAT sat at the queue head.  An untrained talent has no parsable handle
--     (tests/test_fixture_talent_blindness.lua), so no frame in this repo can
--     show it.  Section 4 pins the blindness itself.
--
-- Tagged [ratchet]: sections 1-3 are REGISTERED EXCEPTIONS -- they assert the
-- defect is still there.  The day the stall is fixed they go red, which is the
-- notification.  Delete them then; do not loosen them.

package.path = 'tests/?.lua;' .. package.path

local rf = require('mock.replay_fixture')

-- ⚠️ PARKED IN A SUBDIRECTORY, same measured reason as the bristleback pair:
-- 95 tests enumerate the corpus with `ls tests/fixtures` and 47 more with
-- `tests/fixtures/*.lua`; both globs are flat, so a subdirectory is outside
-- them.  ⛔ That does NOT hide these frames from the RECURSIVE census in
-- tests/test_slotdust_dust_arbitration.lua (`grep -rho tests/fixtures/`), which
-- does read them.  Measured both ways when this file landed: the five fixtures
-- contribute 47 item names and ALL 47 were already in the corpus, so that
-- census's two ratchets held at 124 / 25 and were not touched.  (Contrast the
-- bristleback pair, which widened the hole 23 -> 25 -- a silent census move is
-- the GH #624 shape, so it is measured rather than hoped for.)
local OD_OPEN  = 'tests/fixtures/skillstall/f_ab6c0d_od_lvl10open_467.lua'
local OD_CLOSE = 'tests/fixtures/skillstall/f_ab6c0d_od_lvl10close_496.lua'
local NM_OPEN  = 'tests/fixtures/skillstall/f_ab6c0d_nevermore_lvl10open_444.lua'
local NM_CLOSE = 'tests/fixtures/skillstall/f_ab6c0d_nevermore_lvl10close_503.lua'
local NM_SPEND = 'tests/fixtures/skillstall/f_ab6c0d_nevermore_lvl11spend_504.lua'

local SUBJECT = {
    od        = 'npc_dota_hero_obsidian_destroyer',
    nevermore = 'npc_dota_hero_nevermore',
}

-- Ability sets, split by whether one point raises one row or several.
local SPEC = {
    od = {
        linked = {},
        solo   = { 'obsidian_destroyer_arcane_orb',
                   'obsidian_destroyer_astral_imprisonment',
                   'obsidian_destroyer_objurgation',
                   'obsidian_destroyer_sanity_eclipse' },
    },
    nevermore = {
        linked = { 'nevermore_shadowraze1', 'nevermore_shadowraze2',
                   'nevermore_shadowraze3' },
        solo   = { 'nevermore_presence', 'nevermore_requiem', 'nevermore_frenzy' },
    },
}

local tests = {}

--- Read a subject's ledger off a fixture through the REAL mock handles.
--- `spent` counts a linked group ONCE (see the header's measured argument).
local function ledger(sFixture, sWho)
    local spec = SPEC[sWho]
    local _, bot, _, fx = rf.load(sFixture)
    local t = { ranks = {}, level = bot:GetLevel(), talent_rows = 0, spent = 0,
                t = fx.time }

    local nLinked = nil
    for _, sName in ipairs(spec.linked) do
        local h = bot:GetAbilityByName(sName)
        assert(h ~= nil, sFixture .. ': no handle for ' .. sName)
        local n = h:GetLevel()
        t.ranks[sName] = n
        if nLinked == nil then nLinked = n end
        assert(n == nLinked, sFixture .. ': the linked group is no longer linked ('
            .. sName .. ' reads ' .. tostring(n) .. ', expected ' .. tostring(nLinked)
            .. ').  The `spent` arithmetic depends on this.')
    end
    t.spent = nLinked or 0

    for _, sName in ipairs(spec.solo) do
        local h = bot:GetAbilityByName(sName)
        assert(h ~= nil, sFixture .. ': no handle for ' .. sName)
        local n = h:GetLevel()
        t.ranks[sName] = n
        t.spent = t.spent + n
    end

    for _, u in ipairs(fx.units or {}) do
        if u.name == SUBJECT[sWho] then
            for _, a in ipairs(u.abilities or {}) do
                if a.name:sub(1, 14) == 'special_bonus_' then
                    t.talent_rows = t.talent_rows + 1
                end
            end
        end
    end
    return t
end

-- =========================================================================
-- SECTION 1 -- the pure read, both subjects: an entire hero level is crossed
--              with the ability ledger frozen, alive at both ends.
--              ⛔ No claim about banking here -- section 2 buys that, and only
--              for the subject it can be bought for.
-- =========================================================================
tests.level_ten_is_crossed_with_the_ledger_frozen = function()
    local cases = {
        { OD_OPEN, OD_CLOSE, 'od', 29.0 },
        { NM_OPEN, NM_CLOSE, 'nevermore', 59.0 },
    }
    for _, c in ipairs(cases) do
        local O, C = ledger(c[1], c[3]), ledger(c[2], c[3])
        -- ⚠️ THE ENDS MUST BE TWO DIFFERENT INSTANTS.  Without this, a pair of
        -- paths that happen to name the same file makes "the ledger did not
        -- move" trivially true -- a mutant that SURVIVED the first stand built
        -- for this file, which is why the span is asserted rather than assumed.
        assert(math.abs((C.t - O.t) - c[4]) < 0.05,
            c[3] .. ': the two frames must span ' .. tostring(c[4])
            .. ' s of level 10, got ' .. tostring(C.t - O.t)
            .. ' (t=' .. tostring(O.t) .. ' -> ' .. tostring(C.t) .. ')')
        assert(O.level == 10 and C.level == 10,
            c[3] .. ': both frames must be hero level 10, got '
            .. tostring(O.level) .. ' / ' .. tostring(C.level))
        assert(C.spent == O.spent,
            c[3] .. ': the ledger MUST NOT have moved across level 10; '
            .. tostring(O.spent) .. ' -> ' .. tostring(C.spent))
        for sName, n in pairs(O.ranks) do
            assert(C.ranks[sName] == n,
                c[3] .. ': ' .. sName .. ' moved ' .. tostring(n) .. ' -> '
                .. tostring(C.ranks[sName]) .. ' inside level 10')
        end
    end
end

-- =========================================================================
-- SECTION 2 -- ⭐ GH #817 acceptance 1, on the subject where the arithmetic is
--              sound: OD holds FOUR points across level 10 while alive, and an
--              ABILITY sits untrained the whole time.
-- =========================================================================
tests.od_holds_four_points_across_level_ten = function()
    local O, C = ledger(OD_OPEN, 'od'), ledger(OD_CLOSE, 'od')

    assert(O.spent == 6, 'OD open frame: expected 6 points spent, got ' .. tostring(O.spent))
    -- Ten levels granted, six spent.  ⛔ This is a SUBTRACTION, not a handle:
    -- nothing in the Bot API mock reports unspent points.  It is sound here and
    -- unsound for nevermore for the reason section 4 pins.
    assert(O.level - O.spent == 4,
        'THE acceptance assertion (open): four banked points, got '
        .. tostring(O.level - O.spent))
    assert(C.level - C.spent == 4,
        'THE acceptance assertion (close): still four banked at the last frame '
        .. 'of the level, got ' .. tostring(C.level - C.spent))

    -- ...and the untrained entry is an ABILITY, which this instrument sees
    -- perfectly.  No talent blindness is load-bearing anywhere in section 2.
    assert(O.ranks['obsidian_destroyer_objurgation'] == 0
        and C.ranks['obsidian_destroyer_objurgation'] == 0,
        'objurgation must read rank 0 at both ends of level 10, got '
        .. tostring(O.ranks['obsidian_destroyer_objurgation']) .. ' / '
        .. tostring(C.ranks['obsidian_destroyer_objurgation']))
    -- Positive control for that rank-0 read: the SAME predicate reads 4 for a
    -- trained ability in the SAME world.  Without this, "objurgation is
    -- untrained" would also be green in an empty world.
    assert(O.ranks['obsidian_destroyer_astral_imprisonment'] == 4,
        'positive control: astral_imprisonment must read rank 4 here, got '
        .. tostring(O.ranks['obsidian_destroyer_astral_imprisonment']))
end

-- =========================================================================
-- SECTION 3 -- nevermore's boundary frame: the ledger moves exactly once as
--              level 11 lands.  This is the positive control for section 1's
--              "frozen" -- the same reader, on the same body, one second later,
--              DOES see a change.
-- =========================================================================
tests.the_nevermore_ledger_moves_once_at_the_boundary = function()
    local C, S = ledger(NM_CLOSE, 'nevermore'), ledger(NM_SPEND, 'nevermore')

    assert(math.abs((S.t - C.t) - 1.0) < 0.05,
        'the boundary pair must be 1.0 s apart, got ' .. tostring(S.t - C.t))
    -- ⚠️ The absolute VISIBLE ledger, asserted here and nowhere else.  This is
    -- what pays for the linked-group invariant in `ledger()`: a second mutant
    -- that survived the first stand double-counted a shadowraze into the solo
    -- list, and no assertion in this file noticed, because section 3 reads only
    -- a DELTA.  ⛔ Nine is the visible count, NOT a claim that nine points were
    -- all that was spent -- see the header.
    assert(C.spent == 9,
        'nevermore close frame: expected 9 VISIBLE points on the ledger '
        .. '(raze group once), got ' .. tostring(C.spent))
    assert(S.level == 11 and S.level - C.level == 1,
        'the pinned pair must be ADJACENT levels (10, 11), got '
        .. tostring(C.level) .. ' -> ' .. tostring(S.level))
    assert(C.ranks['nevermore_frenzy'] == 0 and S.ranks['nevermore_frenzy'] == 1,
        'frenzy must read 0 at the close frame and 1 at the spend frame, got '
        .. tostring(C.ranks['nevermore_frenzy']) .. ' / '
        .. tostring(S.ranks['nevermore_frenzy']))
    assert(S.spent - C.spent == 1,
        'exactly one visible point across the level boundary, got '
        .. tostring(S.spent - C.spent))
end

-- =========================================================================
-- SECTION 4 -- ⛔ THE REFUSAL, pinned so it cannot decay back into prose.
--              The two subjects differ in exactly one way that matters, and it
--              is a property of the INSTRUMENT, not of the bots.
-- =========================================================================
local UNIQUE = 'special_bonus_unique_'

--- Which of the t10 pair a hero's own build selects, and the row it lands on.
--- Same derivation as tests/test_talent_uptake_visibility.lua (the hero desk's
--- file, which is the authority for the mechanism): aba_skill.X.GetTalentBuild
--- reads `tTalentTreeList['t10'][1] == 0` as left (slot 9), else right (slot 10).
local function t10_row(hero)
    local f = assert(io.open('bots/BotLib/hero_' .. hero .. '.lua'))
    local src = f:read('*a'); f:close()
    local tree = assert(src:match('tTalentTreeList%s*=%s*(%b{})'),
        hero .. ': no tTalentTreeList in its BotLib file')
    local first = assert(tree:match("%['t10'%]%s*=%s*{%s*(%d+)%s*,"),
        hero .. ": no ['t10'] = { n, m } row")
    local slot = (tonumber(first) == 0) and 9 or 10
    local map = assert(dofile('tests/mock/hero_slots.lua')[hero],
        hero .. ': absent from tests/mock/hero_slots.lua')
    local name = map[slot]
    assert(type(name) == 'string' and name:sub(1, 14) == 'special_bonus_',
        hero .. ': slot ' .. slot .. " holds '" .. tostring(name) .. "', not a talent")
    return name
end

tests.the_banked_count_is_sound_for_od_and_unsound_for_nevermore = function()
    local sOD = t10_row('obsidian_destroyer')
    local sNM = t10_row('nevermore')

    -- OD's t10 row is GENERIC: its own entity class, kept by the dumper.  That
    -- is what makes section 2's subtraction mean "banked" rather than "invisible".
    assert(sOD:sub(1, #UNIQUE) ~= UNIQUE,
        "section 2 is only sound while OD's t10 row is generic and therefore "
        .. "visible to the dumper.  It now reads '" .. sOD .. "' -- if OD's build "
        .. 'or slot map changed, section 2 must be re-derived, not re-baselined.')
    assert(sOD == 'special_bonus_mp_200',
        "OD's t10 row moved: expected special_bonus_mp_200, got '" .. sOD .. "'")

    -- nevermore's is hero-UNIQUE: Special_Bonus_Base class, dropped by
    -- isRealAbility() before the level>0 branch.  A point spent there raises
    -- nothing, so `level - spent` cannot distinguish banked from spent.
    assert(sNM:sub(1, #UNIQUE) == UNIQUE,
        'THE refusal: nevermore\'s t10 row must be hero-unique (and so invisible) '
        .. "for this file's warning to be the right one.  It reads '" .. sNM .. "'.")
    assert(sNM == 'special_bonus_unique_nevermore_4',
        "nevermore's t10 row moved: expected special_bonus_unique_nevermore_4, got '"
        .. sNM .. "'")
end

tests.no_frame_here_can_see_an_untrained_talent = function()
    local cases = {
        { OD_OPEN, 'od' }, { OD_CLOSE, 'od' },
        { NM_OPEN, 'nevermore' }, { NM_CLOSE, 'nevermore' }, { NM_SPEND, 'nevermore' },
    }
    for _, c in ipairs(cases) do
        local L = ledger(c[1], c[2])
        assert(L.talent_rows == 0,
            c[1] .. ': expected ZERO talent rows on the subject (an untrained '
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

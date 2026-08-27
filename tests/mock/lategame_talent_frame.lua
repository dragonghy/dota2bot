-- RECORDED snapshot: the ten hero-slots of the first post-cap frame this repo
-- holds, as `tools/agent/lategame_talent_census.py` reads them on 2026-08-27.
--
-- SOURCE  iterations/pending/tpgap_159_fixture/f_260826_155416_slardar_tpgap.lua
--         (game 155416_slot4, t=1382.2 = 23:02 of a 24.9-minute naturally-ended
--         turbo game; run spot_20260826_151427_1_..._a2baf3, seed 895 -- the
--         corrected address, GH #234).
--
-- WHY A SNAPSHOT AND NOT A READ OF THE FILE.  That fixture is parked in
-- iterations/pending/ behind GH #236 (landing it turns 16 corpus files red, and
-- the ordering is the harness/director seat's call, not this one's).  A test
-- that read it directly would either block on that decision or break the day it
-- moves.  The snapshot is the reading, dated; the tool re-derives it from
-- wherever the file lives.
--
-- `must` is not observed -- it is what the SHIPPED level-up routine spends by
-- that hero level (FunLib/aba_skill.lua X.GetSkillList puts a talent at every
-- level i >= 10 with i % 5 == 0).  Section 1 of the test drives the real
-- function rather than trusting this column.

return {
    source = 'iterations/pending/tpgap_159_fixture/f_260826_155416_slardar_tpgap.lua',
    game = '155416_slot4.timeline',
    time = 1382.2,
    recorded = '2026-08-27',

    -- Corpus-wide totals from the same run, over tests/fixtures/ + the parked
    -- frame: the denominators that make the eight below a shortfall and not a
    -- sample size.
    corpus = {
        files = 106,
        slots = 1060,
        talent_rows = 75,
        unique_rows = 0,
        late_slots = 10,
    },

    slots = {
        { hero = 'bristleback',    level = 25, must = 4, seen = 1,
          rows = { 'special_bonus_m_p_regen150' } },
        { hero = 'crystal_maiden', level = 22, must = 3, seen = 1,
          rows = { 'special_bonus_h_p200' } },
        { hero = 'dragon_knight',  level = 26, must = 4, seen = 2,
          rows = { 'special_bonus_attack_damage15', 'special_bonus_h_p300' } },
        { hero = 'jakiro',         level = 24, must = 3, seen = 0, rows = {} },
        { hero = 'lina',           level = 27, must = 4, seen = 1,
          rows = { 'special_bonus_attack_damage25' } },
        { hero = 'necrolyte',      level = 25, must = 4, seen = 0, rows = {} },
        { hero = 'skeleton_king',  level = 26, must = 4, seen = 1,
          rows = { 'special_bonus_h_p300' } },
        { hero = 'slardar',        level = 27, must = 4, seen = 1,
          rows = { 'special_bonus_h_p250' } },
        { hero = 'venomancer',     level = 24, must = 3, seen = 0, rows = {} },
        { hero = 'zuus',           level = 23, must = 3, seen = 1,
          rows = { 'special_bonus_h_p200' } },
    },
}

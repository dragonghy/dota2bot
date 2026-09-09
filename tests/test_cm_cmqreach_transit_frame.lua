-- [ratchet] [hero] The `cmqreach` TRANSIT frame, read by name.  Claims GH #659,
-- which measured the price of putting this frame in the tree and handed the one
-- non-arithmetic row of that price -- queue `hero-10`'s "n=1 is not a rate" --
-- to this desk.  The frame:
--
--     0eb22d / 20260908_094909_slot6, t = 1191.5 (19:51), subject
--     crystal_maiden (dump idx 1534, globally unique => no illusion ambiguity)
--
-- WHY THE FRAME EXISTS AT ALL
--
-- The replay group's `cmqreach` cell-(3) instrument reads "the armed leg dies
-- more".  Across three drafts its transit share sat near 56%, i.e. more than
-- half the instants the cell scores are frames on which the hero is WALKING,
-- not fighting.  This is one of them, and it is the extreme of the shape: full
-- health, near-full mana, moving at very nearly hero top speed in a straight
-- line, with no enemy hero within 2.7k -- and dead 17.3 seconds later.  A death
-- that a per-frame decision reading cannot be charged for, scored inside a cell
-- that charges it.
--
-- WHAT THIS FILE CLAIMS, AND WHAT IT DOES NOT
--
--   IT CLAIMS the frame is what GH #659 says it is, in the tree, reproducibly:
--   the geometry, the clock and the two hero-slots the price table turns on.
--   Those are ground truth off the dump, and every one of them is asserted here
--   rather than narrated, so a regenerated or edited frame fails loudly instead
--   of silently re-basing the six enumerating scans that now count it.
--
--   ⛔ IT DOES NOT CLAIM `cmqreach`'s condition (a).  Condition (a) is "the
--   change executes and behaves correctly in a real game", which is a WAVE's
--   evidence, not a frame's.  What this frame supplies is the thing the wave
--   reading needs in order to be read at all: a pinned instance of the transit
--   contamination in the cell that the wave reading is taken from.  Anyone
--   quoting this file for (a) is quoting it for something it says the opposite
--   of.
--
--   ⛔ IT DOES NOT CLAIM A RATE, for the transit share or for anything else.
--   n = 1 frame.  The 56% belongs to the replay group's drafts and is cited
--   here, not re-derived.
--
-- WHY IT IS STAGED IN tests/frames/ AND NOT ADMITTED TO tests/fixtures/
--
-- Measured, not estimated, by moving the file in and out and reading the DIFF
-- (tests/frames/README.md's own method note: both runs exit 0, so an exit code
-- decides nothing here):
--
--     into tests/fixtures/  -> 4 files / 5 assertions red
--     into tests/frames/    -> 6 files / 9 assertions red  <- PAID 2026-09-09
--
-- The staging price is paid; the admission price is not, and admitting the
-- frame is a separate work unit with a separate list.  Independently measured
-- this round and matching GH #659's table file for file.
--
-- THE ONE ROW THAT WAS A JUDGEMENT AND NOT A COUNT (queue hero-10)
--
-- This frame carries the tree's SECOND live Wraith King above level 12, and it
-- is the first one whose CURRENT mana is below the shipped 600 Roshan floor
-- while its POOL is above it.  The full reading, with the bound that survives,
-- lives in tests/test_wk_level_supply_horizon.lua section 6 -- next to the
-- ledger it moves -- and section 3 here pins the frame's own numbers so that
-- reading keeps a witness.

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')

local FRAME = 'tests/frames/f_260908_094909_cm_cmqreach_transit.lua'
local CM    = 'npc_dota_hero_crystal_maiden'
local WK    = 'npc_dota_hero_skeleton_king'
local SF    = 'npc_dota_hero_nevermore'

local tests = {}

local function frame()
    return rf.load(FRAME, CM)
end

-- ---------------------------------------------------------------- section 1 --
-- The frame is in the tree and the loader reads it.  A discriminant, not a
-- tautology: an empty unit list would satisfy "no enemy within 2500u" just as
-- well as a real one does, so the reading is taken as a PAIR of rings that an
-- empty list cannot satisfy.

tests['§1 the loader reads real coordinates, not an empty roster'] = function()
    local fh = io.open(FRAME, 'r')
    assert(fh ~= nil, FRAME .. ' is not in the tree.  Six enumerating scans now '
        .. 'count it (test_cm_ult_reach_meter_domain, test_cm_w_lane_band, '
        .. 'test_wk_level_supply_horizon, test_wk_q_castrange_meter_domain, '
        .. 'test_wk_q_lane_reach, test_zuus_jump_landing_reach); without the '
        .. 'file their denominators are wrong in the quiet direction')
    fh:close()

    local _, bot = frame()
    assert(bot ~= nil, 'the loader did not produce a Crystal Maiden subject')

    local near = #bot:GetNearbyHeroes(2500, true, BOT_MODE_NONE)
    local far  = #bot:GetNearbyHeroes(3000, true, BOT_MODE_NONE)
    assert(near == 0, 'enemy heroes within 2500u: ' .. near .. ', recorded 0')
    assert(far == 1, 'enemy heroes within 3000u: ' .. far .. ', recorded 1 '
        .. '(nevermore at 2790u).  This is the discriminant: an empty roster '
        .. 'would pass the 2500 assertion above and fail this one, so the two '
        .. 'together are what prove the geometry is being read')
end

-- ---------------------------------------------------------------- section 2 --
-- The transit reading itself: what the hero looks like on the frame, and what
-- the clock does afterwards.  Both halves are ground truth off the dump.

tests['§2 full health, near-full mana, nothing near her -- and dead in 17.3s'] = function()
    local fx = dofile(FRAME)
    assert(fx.time == 1191.5, 'frame time is ' .. tostring(fx.time) .. ', recorded 1191.5')

    local cm, wk, sf
    for _, u in ipairs(fx.units) do
        if u.name == CM then cm = u elseif u.name == WK then wk = u
        elseif u.name == SF then sf = u end
    end
    assert(cm ~= nil and wk ~= nil and sf ~= nil,
        'the frame lost one of the three hero-slots this file reads')

    assert(cm.alive == true and cm.hp == cm.max_hp,
        'the subject is no longer alive at full health (' .. tostring(cm.hp)
        .. '/' .. tostring(cm.max_hp) .. ') -- the "nothing was going wrong on '
        .. 'this frame" half of the transit reading rests on it')
    assert(cm.mp / cm.max_mp > 0.98, 'subject mana fraction is '
        .. string.format('%.3f', cm.mp / cm.max_mp) .. ', recorded 0.987 '
        .. '(1060/1074).  She is not short of anything on this frame')
    assert(cm.level == 18, 'the subject is level ' .. tostring(cm.level)
        .. ', recorded 18')

    -- The clock.  died_after is the generator's ground truth, and the damage
    -- horizon says WHEN the game first touched her: 12.0s of nothing, then the
    -- fight that kills her.  A per-frame decision reading over this instant is
    -- scoring a death that had not started yet.
    assert(fx.observed ~= nil and fx.observed.died_after == 17.3,
        'died_after is ' .. tostring(fx.observed and fx.observed.died_after)
        .. ', recorded 17.3')
    local first = nil
    for _, d in ipairs(fx.observed.damage or {}) do
        if first == nil or d.t < first.t then first = d end
    end
    assert(first ~= nil and first.t == 12.00 and first.actor == SF,
        'the first hero damage after this frame is '
        .. tostring(first and first.t) .. 's from '
        .. tostring(first and first.actor) .. ', recorded 12.00s from ' .. SF
        .. '.  That 12-second gap IS the transit reading')
    -- observed.burst is the 5s window, and it is EMPTY here.  Named explicitly
    -- because an empty burst is exactly what a transit frame looks like and
    -- exactly what a broken generator looks like -- the 12.0s entry above is
    -- what tells the two apart, and it is outside the 5s window by 7 seconds.
    local nBurst = 0
    for _ in pairs(fx.observed.burst or {}) do nBurst = nBurst + 1 end
    assert(nBurst == 0, 'observed.burst has ' .. nBurst .. ' entries, recorded 0 '
        .. '-- see the note above before reading that zero as a generator fault')
end

-- ---------------------------------------------------------------- section 3 --
-- The hero-10 witness.  The ledger reading is in
-- tests/test_wk_level_supply_horizon.lua section 6; this pins the numbers it
-- reads, on the frame, so that reading cannot outlive its own evidence.

tests['§3 the second live late-game Wraith King: pool above 600, mana below it'] = function()
    local fx = dofile(FRAME)
    local wk
    for _, u in ipairs(fx.units) do if u.name == WK then wk = u end end
    assert(wk ~= nil, 'the Wraith King slot is gone from this frame')

    assert(wk.alive == true, 'the Wraith King on this frame is no longer alive.  '
        .. 'A dead row has its capacity fields zeroed, and then neither pool nor '
        .. 'mana below is quotable in any direction (the 711 caveat)')
    assert(wk.level == 20, 'level is ' .. tostring(wk.level) .. ', recorded 20')
    assert((wk.max_hp or 0) > 0 and wk.hp < wk.max_hp,
        'hp/max_hp is ' .. tostring(wk.hp) .. '/' .. tostring(wk.max_hp)
        .. ', recorded 2142/2575.  Both halves matter: max_hp > 0 is what makes '
        .. 'the pool quotable, and hp < max_hp is what retires the `hp == max_hp` '
        .. 'proxy the n=1 reading had leaned on')
    assert(wk.max_mp == 735, 'max_mp is ' .. tostring(wk.max_mp) .. ', recorded '
        .. '735 -- above the shipped 600 absolute floor')
    assert(wk.mp == 556, 'mp is ' .. tostring(wk.mp) .. ', recorded 556 -- BELOW '
        .. 'the shipped 600 floor.  This is the first row in the tree on which '
        .. 'that floor is observed REFUSING a cast rather than being cleared')

    -- What it refuses.  Rank 3 Hellfire Blast costs 125; she is carrying 556.
    local q
    for _, a in ipairs(wk.abilities or {}) do
        if a.name == 'skeleton_king_hellfire_blast' then q = a end
    end
    assert(q ~= nil and q.level == 3, 'Hellfire Blast is at rank '
        .. tostring(q and q.level) .. ', recorded 3 -- the mana cost quoted '
        .. 'below is that rank\'s')
    assert(wk.mp > 4 * 125, 'the hero carries ' .. tostring(wk.mp) .. ' mana '
        .. 'against a 125 cost at this rank, recorded as more than 4x over.  '
        .. 'That gap is hero-10\'s surviving defect with an instance under it: '
        .. 'the 600 floor is an absolute, not a fraction of what the spell costs')
    -- ⚠️ n = 2, and two frames from two games are not a rate.  hero-10 asks for
    -- a distribution over archived timelines; nothing here supplies one, and
    -- the request stays pending for that reason and no other.
end

return tests

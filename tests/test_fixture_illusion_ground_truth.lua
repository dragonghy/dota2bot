-- [fixture fidelity] The eleventh undeclared world assumption: a fixture's
-- "ground truth" damage is keyed by hero NAME, and an illusion is logged under
-- the name of the hero it copies.
--
-- The snapshot stream identifies units by entity index, so make_fixture.py has
-- always dropped illusions from the unit list cleanly. The COMBAT LOG does not:
-- every DAMAGE row spells `actor`/`target` as a bare hero name. So while a copy
-- of hero H is on the field, every damage row naming H is ambiguous between the
-- hero and the copy -- and the generator wrote those rows out as
--     observed.burst = "damage each enemy hero ACTUALLY dealt to the subject"
-- which tests/mock/replay_fixture.lua installs as GetEstimatedDamageToTarget.
-- That is the input of J.WillAllySurviveTpWindow (SHIPPED, ungated),
-- J.IsIncomingBurstLethal ('tpdying') and J.ShouldRetreatLaneBurst.
--
-- MEASURED, not hypothesised. 20260820_102030_slot1 @ t=639.5, subject
-- tidehunter: the name-keyed sum says 849 damage from four enemy heroes over
-- the next 3s (lion 64 / slardar 229 / ogre_magi 211 / obsidian_destroyer 329
-- / necrolyte 16), while the hero's own entity (idx 1316) went
--     1419 -> 1452 -> 1435 -> 1423
-- across those same three seconds: it REGENERATED. All 849 points landed on
-- illusion entity 2537, which was alive 613.5-640.5 and stood 4000u away from
-- the hero, inside the ogre/slardar/OD focus. GH #68 section 1.3 read that same
-- 849 as "the hero ate 1063 in one second and the gate correctly held" -- the
-- gate did hold, but not for the reason the number suggested.
--
-- There is nothing to reconstruct: the log simply does not record which copy
-- was hit. So the generator now WITHHOLDS the block and says so
-- (observed.ground_truth_ambiguous / per-unit recent_damage_ambiguous), the
-- same rule the loader already applied to `sSubject` overrides -- "0, rather
-- than a number that would silently mean damage dealt to someone else".

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')

local tests = {}

local DIRTY = 'tests/fixtures/f_260820_102030_tide_illusion_burst.lua'
local CLEAN = 'tests/fixtures/f_260820_103644_necro_pinned_dying.lua'

-- ---- the refusal is declared, not silent -------------------------------------

tests['[world] the contaminated frame declares its ground truth unattributable'] = function()
    local _, _, _, fx = rf.load(DIRTY)
    assert(fx.observed.ground_truth_ambiguous == true,
        'the generator must SAY it withheld the block; a silently empty burst '
        .. 'table is exactly the undeclared world assumption this fixes')
    assert(next(fx.observed.burst) == nil,
        'and the block itself is empty rather than carrying the illusion sum')
    assert(fx.observed.died_after == nil,
        'died_after rides with it -- DEATH rows are name-keyed too')
    assert(fx.observed.damage == nil,
        'so does the per-event damage timeline')
end

tests['[world] the withheld frame answers 0 for every damage estimate'] = function()
    local _, bot, heroes = rf.load(DIRTY)
    for name, h in pairs(heroes) do
        assert(h:GetEstimatedDamageToTarget(true, bot, 3.0, 0) == 0,
            name .. ' must answer 0, not an illusion-inflated number')
    end
end

tests['[world] the subject really did survive the window it was credited to'] = function()
    local _, bot = rf.load(DIRTY)
    assert(bot:GetHealth() == 1419 and bot:GetMaxHealth() == 1452,
        'tidehunter is at 1419/1452 = 97.7% on the frame the name-keyed sum '
        .. 'called 849 damage in three seconds')
end

-- ---- what the refusal means to the two consumers ------------------------------

tests['[consumers] both burst consumers read the refusal as "no evidence"'] = function()
    local J, bot = rf.load(DIRTY)
    assert(J.IsIncomingBurstLethal(bot, 3.0) == false,
        'no attributable burst -> not lethal, which is the conservative '
        .. 'direction for a release that can only DROP a commitment')
    assert(J.WillAllySurviveTpWindow(bot) == true,
        'and the shipped, ungated rescue-window check reads the same way: '
        .. 'without evidence it does not declare the ally doomed')
end

tests['[limitation] on THIS frame the corrupted number would not have flipped either consumer'] = function()
    -- Honest scope: the contamination corrupted the EVIDENCE, and the frame
    -- that also flips a decision has not been produced. Of the five heroes the
    -- log credited, only lion (340u) is inside the 1100 estimator radius at
    -- all -- the other four were beating on the illusion 4000u away -- so even
    -- the pre-fix fixture summed 64 against a 1419 HP pool here.
    local J, bot, heroes = rf.load(DIRTY)
    local dirty = { npc_dota_hero_lion = 64, npc_dota_hero_slardar = 229,
                    npc_dota_hero_ogre_magi = 211,
                    npc_dota_hero_obsidian_destroyer = 329,
                    npc_dota_hero_necrolyte = 16 }
    local nTotal = 0
    for name, v in pairs(dirty) do
        nTotal = nTotal + v
        rawget(heroes[name], '__spec').GetEstimatedDamageToTarget = function() return v end
    end
    assert(nTotal == 849, 'the withheld sum, restored: ' .. tostring(nTotal))
    assert(J.IsIncomingBurstLethal(bot, 3.0) == false,
        'and it still does not flip this predicate on this frame -- if a '
        .. 'future frame does flip one, this assertion is where to record it')
end

-- ---- the backward-looking half ------------------------------------------------

tests['[recent] a hero whose damage history is ambiguous keeps the mock default'] = function()
    local _, _, heroes = rf.load(DIRTY)
    -- tidehunter (its own copy was being focused) and ogre_magi (it was hitting
    -- that copy, so the rows credit it with hitting "tidehunter") are both
    -- marked; neither may claim a history it cannot own.
    for _, name in ipairs({ 'npc_dota_hero_tidehunter', 'npc_dota_hero_ogre_magi' }) do
        assert(heroes[name]:WasRecentlyDamagedByAnyHero(3.0) == false,
            name .. ' must fall back to the declared default, not a '
            .. 'fabricated history')
    end
end

tests['[recent] a hero on the same frame with a clean history still answers it'] = function()
    local _, _, _, fx = rf.load(DIRTY)
    local nAmbiguous, nClean = 0, 0
    for _, u in ipairs(fx.units) do
        if u.recent_damage_ambiguous then nAmbiguous = nAmbiguous + 1 end
        if u.recent_damage ~= nil then nClean = nClean + 1 end
    end
    assert(nAmbiguous == 2,
        'exactly the two heroes the illusion fight touched: got ' .. nAmbiguous)
    assert(nClean == 0,
        'nobody else was hit in the lookback on this frame, so the rest keep '
        .. 'the same default for the ordinary reason: got ' .. nClean)
end

-- ---- control: a clean frame is untouched --------------------------------------

tests['[control] a frame with no live copy keeps its ground truth'] = function()
    local J, bot, _, fx = rf.load(CLEAN)
    assert(fx.observed.ground_truth_ambiguous == nil,
        'necrolyte had two stale entity handles in this game, but both were '
        .. 'dead from 396s on -- nothing was alive inside the window')
    assert(fx.observed.burst['npc_dota_hero_lina'] == 644
        and fx.observed.burst['npc_dota_hero_zuus'] == 436,
        'so the real 1080-point burst is installed as before')
    assert(fx.observed.died_after == 5.1,
        'and so is the death that followed it')
    assert(J.IsIncomingBurstLethal(bot, 3.0) == true,
        '1080 against a 965 HP pool')
end

-- ---- reverse assertions: this test expires if either side stops refusing ------

tests['[reverse] the loader still gates the burst install on the declaration'] = function()
    local src = io.open('tests/mock/replay_fixture.lua'):read('*a')
    assert(src:find('ground_truth_ambiguous', 1, true) ~= nil,
        'if the loader stops reading the flag, a regenerated contaminated '
        .. 'fixture would silently install illusion damage again')
end

tests['[reverse] the generator still withholds rather than repairs'] = function()
    local src = io.open('tools/batch_test/replayscope/make_fixture.py'):read('*a')
    assert(src:find('burst, damage, died_after = Counter(), [], None', 1, true) ~= nil,
        'the fix must stay a REFUSAL. Reconstructing "the hero\'s share" from '
        .. 'the HP trajectory is modelling (heals, regen, damage block) and '
        .. 'would put a fabricated number back where the honest gap is')
end

return tests

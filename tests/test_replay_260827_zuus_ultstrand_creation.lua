-- [replay-check] `zusultstrand` -- THE CREATION FRAME.
--
-- Match : soak/spot_20260827_091422_1_d9585a29…_15b77f / 20260827_091703_slot12
--         (mirror leg `…:s896:radiant`; `zusultstrand` was NOT armed in that
--         game -- this is a BASELINE frame, and that is what makes it evidence
--         for a widening rather than a verification of an armed run).
-- Frame : t = 473.1 (7:53), subject npc_dota_hero_zuus, radiant.
-- Fixture: tests/fixtures/f_20260827_091703_slot12_zuus_473_1.lua
--
-- WHAT THE BOT COULD SEE AT t=473.1, all of it frame data:
--   * itself at 177/1006 HP = 17.6%, mana 405, level 8;
--   * Thundergod's Wrath at rank 1, cooldown 0, mana cost 250 -- castable;
--   * Slardar (alive, team 3) 304.9u away, having landed 112/114/121 damage on
--     it in the last 1.9s; Ogre Magi dead on the same spot;
--   * ground truth from the replay: it died 8.3s later (t=481.4-481.6) with the
--     ultimate still unspent. The first Thundergod's Wrath of that game was cast
--     at t=600.8 -- 119s AFTER this death.
--
-- WHY THIS FILE EXISTS
-- --------------------
-- tests/test_zuus_ult_strand.lua section 6 carries a one-way tripwire saying the
-- corpus held NO creation frame for the armed branch: its only sub-28% Zeus frame
-- (f_181441_zuus_lowhp_limbo, 15.8%) missed on two other conjuncts at once -- the
-- ult on a 2.2s cooldown AND its nearest enemy at 2017u. The header of
-- bots/BotLib/hero_zuus.lua states the same limit. This frame retires it: every
-- conjunct the branch reads is satisfied here by REAL frame data, and the armed
-- decision differs from the shipped one on this exact instant.
--
-- ✅ BATON LANDED 2026-09-08 (hero stream, GH #593). When this file was written
-- it deliberately left both artefacts stale and pinned the handover in a section
-- 4 that asserted the two stale limits moved TOGETHER. Both have now been
-- retired: this path is in test_zuus_ult_strand.lua's ZUUS_FRAMES and its
-- section 6 states the creation frame as a reading (with the name of the frame),
-- and the hero_zuus.lua header carries the correction plus its three limits.
-- Section 4 was deleted rather than re-armed -- that is what its own failure
-- message instructed the round that landed the baton to do.
--
-- WHAT IS REAL AND WHAT IS DECLARED -- THE TWO MAY NOT BE MERGED
-- --------------------------------------------------------------
--   REAL (read off the frame): HP percentage, ult rank/cooldown/mana cost, the
--   subject's mana, `WasRecentlyDamagedByAnyHero( 2.0 )` (it is answered from the
--   fixture's own recent_damage rows), and the chaser distance -- enemy hero
--   POSITIONS are frame data.
--
--   DECLARED (an injection, labelled at every call site): `J.IsRetreating`.
--   Retreat is bot-VM mode state and no .dem carries it (the replay-fixture
--   skill lists GetActiveMode among the world facts a fixture cannot have). The
--   raw loader answers FALSE, so section 3 states BOTH readings: the end-to-end
--   0 -> 0.75 flip is bought with that one substitution named, and section 5
--   pins the raw answer as a one-way tripwire rather than hiding it.
--
--   ⚠️ Consequently this file does NOT claim "the armed branch fired in a real
--   game". It claims: on a real frame that a real bot really occupied and really
--   died on, every conjunct the branch can read offline is true, and the lever
--   changes the decision there. Sizing how often retreat mode coincides is a
--   corpus question, not a fixture question.

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')

local FRAME = 'tests/fixtures/f_20260827_091703_slot12_zuus_473_1.lua'
local ULT = 'zuus_thundergods_wrath'
local CAND = 'zusultstrand'
local SUBJECT = 'npc_dota_hero_zuus'
local CHASER = 'npc_dota_hero_slardar'

local tests = {}

--- Load the frame. `opt.armed == true` (not a truthiness test: an absent key
--- would arm nothing and a shipped-answer assertion would then pass for the
--- wrong reason). `opt.retreating` is the DECLARED injection -- pass it only
--- where the surrounding comment says so.
local function on_frame(opt)
    opt = opt or {}
    local J, bot, heroes, fx = rf.load(FRAME)
    J.IsSoakCandidate = function(id) return opt.armed == true and id == CAND end
    if opt.retreating ~= nil then
        J.IsRetreating = function() return opt.retreating end
    end
    local X = rf.load_hero('zuus')
    return X, J, bot, heroes, fx
end

--- Push a hero out of every radius this branch reads. MUTATION of the real
--- frame -- every caller says so in its own comment.
local function banish(heroes, sName)
    assert(heroes[sName], 'test setup: ' .. sName .. ' must be on this frame')
    rawget(heroes[sName], '__spec').GetLocation = { x = 90000, y = 90000, z = 0 }
    rawset(heroes[sName], 'GetLocation', nil)
end

-- ---------------------------------------------------------------- section 1 --
-- The frame itself. These are the numbers the report and the issue quote; if the
-- fixture is ever regenerated from a different instant, this section goes red
-- instead of leaving the prose above pointing at a frame that no longer exists.

tests['section 1: the subject is the dying Zeus the report describes'] = function()
    local _, _, bot, _, fx = on_frame()
    assert(fx.self == SUBJECT, 'fixture subject is ' .. tostring(fx.self))
    assert(math.abs(fx.time - 473.1) < 0.001,
        'fixture instant moved to ' .. tostring(fx.time) .. '; this file argues about t=473.1')
    assert(bot:GetHealth() == 177 and bot:GetMaxHealth() == 1006,
        string.format('HP moved to %d/%d', bot:GetHealth(), bot:GetMaxHealth()))
    local pct = bot:GetHealth() / bot:GetMaxHealth()
    assert(pct <= 0.28, string.format(
        'the subject is at %.1f%% HP, above the 0.28 bar ConsiderR compares against '
        .. '-- then this is not a frame inside the branch at all.', pct * 100))
end

tests['section 1: the ultimate is genuinely castable here'] = function()
    local _, _, bot = on_frame()
    local h = bot:GetAbilityByName(ULT)
    assert(h:GetLevel() == 1, 'ult rank moved to ' .. tostring(h:GetLevel()))
    assert(h:GetCooldownTimeRemaining() == 0, string.format(
        'ult now reports %s s of cooldown; the whole point of this frame is that '
        .. 'the spell was READY and went unused.', tostring(h:GetCooldownTimeRemaining())))
    assert(h:IsFullyCastable(), 'the ult is not fully castable on this frame')
    assert(bot:GetMana() >= h:GetManaCost(), string.format(
        'mana %s is below the rank-1 cost %s; then the frame misses on mana and is '
        .. 'not a creation frame.', tostring(bot:GetMana()), tostring(h:GetManaCost())))
end

tests['section 1: the outer ConsiderR conjunct that IS readable holds'] = function()
    -- `J.IsRetreating( bot ) and bot:WasRecentlyDamagedByAnyHero( 2.0 )` -- the
    -- right half is answered from the fixture's own recent_damage rows (Slardar
    -- at dt=0.3/1.1/1.9, Ogre Magi at dt=0.7/1.7), so it is a READING. The left
    -- half is section 5's tripwire.
    local _, _, bot = on_frame()
    assert(bot:WasRecentlyDamagedByAnyHero(2.0) == true,
        'no hero damage inside 2.0s on this frame -- the outer conjunct would fail '
        .. 'even with retreat mode, and the frame stops being a creation frame.')
end

tests['section 1: a living chaser is inside the armed radius'] = function()
    local X, J, bot, heroes = on_frame({ armed = true })
    local t = J.GetNearbyHeroes(bot, X.nUltCashChaseRadius, true, BOT_MODE_NONE)
    assert(t ~= nil and #t == 1, string.format(
        'the 1600 ring now holds %d enemies, not the 1 this frame carries (Ogre '
        .. 'Magi lies dead on the same spot and must not be counted).',
        t and #t or -1))
    assert(t[1]:GetUnitName() == CHASER, 'the chaser is ' .. tostring(t[1]:GetUnitName()))
    local d = GetUnitToUnitDistance(bot, t[1])
    assert(d > 300 and d < 310, string.format(
        'chaser distance moved to %.1fu; the report and the issue quote 304.9u.', d))
end

tests['section 1: ground truth -- it died with the ult still in hand'] = function()
    local _, _, _, _, fx = on_frame()
    local died = fx.observed and fx.observed.died_after
    assert(died ~= nil and math.abs(died - 8.3) < 0.05, string.format(
        'died_after moved to %s. The value of this widening rests on that number: '
        .. 'an ultimate held at death is worth exactly zero.', tostring(died)))
end

-- ---------------------------------------------------------------- section 2 --
-- The gated helper, both arms, on the real frame. No injection here at all.

tests['section 2: gate OFF -- the shipped tree refuses, as it always has'] = function()
    local X, _, bot = on_frame({ armed = false })
    assert(X.zuus_ShouldCashUltBeforeDeath(bot) == false,
        'the UNARMED helper answered true on this frame. The shipped conjunct is '
        .. 'argued to be structurally false; a real frame that makes it true '
        .. 'retires that argument and this lever needs re-diagnosing.')
end

tests['section 2: gate ON -- the widening fires on this frame'] = function()
    local X, _, bot = on_frame({ armed = true })
    assert(X.zuus_ShouldCashUltBeforeDeath(bot) == true,
        'the ARMED helper refused the creation frame. This is the frame the whole '
        .. 'lever was written for -- 17.6% HP, ult ready, a chaser at 305u, dead '
        .. '8.3s later. If it refuses here it fires nowhere.')
end

tests['section 2: the armed answer is the RADIUS term, not a constant true'] = function()
    -- MUTATION of the real frame: Slardar is pushed to (90000, 90000). Nothing
    -- else changes, so a helper that returned true regardless of its inputs --
    -- the mutant that would make section 2's green meaningless -- does not
    -- survive this.
    local X, _, bot, heroes = on_frame({ armed = true })
    banish(heroes, CHASER)
    assert(X.zuus_ShouldCashUltBeforeDeath(bot) == false,
        'with the only living enemy 90000u away the armed helper still fired. Then '
        .. 'the radius term is not doing the narrowing the hero file claims, and '
        .. 'the widening is a blank cheque.')
end

-- ---------------------------------------------------------------- section 3 --
-- End to end through X.ConsiderR, with the one declared injection.
--
-- X.SkillsComplement() is called first because `nHealthPercentage` -- the second
-- conjunct of the branch -- is a FILE-LEVEL variable this hero assigns there
-- (hero_zuus.lua:643) one line before it calls ConsiderR. Driving ConsiderR
-- without it does not test the shipped path; it tests an uninitialised one.

local function considerR_with_retreat(bArmed)
    local X, _, bot = on_frame({ armed = bArmed, retreating = true })  -- DECLARED INJECTION
    X.SkillsComplement()
    return X.ConsiderR()
end

tests['section 3: gate OFF, retreat declared -- ConsiderR wants nothing'] = function()
    local r = considerR_with_retreat(false)
    assert(r == BOT_ACTION_DESIRE_NONE, string.format(
        'the shipped tree returned desire %s on this frame. It is supposed to walk '
        .. 'past a ready global nuke here -- that is the defect being priced.',
        tostring(r)))
end

tests['section 3: gate ON, retreat declared -- ConsiderR casts'] = function()
    local r = considerR_with_retreat(true)
    assert(r == BOT_ACTION_DESIRE_HIGH, string.format(
        'the armed tree returned desire %s, not BOT_ACTION_DESIRE_HIGH. The helper '
        .. 'answering true is not enough: the branch also re-reads nHealthPercentage, '
        .. 'and this assertion is the only one that covers that second conjunct.',
        tostring(r)))
end

tests['section 3: the flip is the LEVER -- same frame, same injection'] = function()
    -- Stated as its own assertion so the pair is read as a difference and not as
    -- two independent numbers that happen to differ.
    assert(considerR_with_retreat(false) ~= considerR_with_retreat(true),
        'arming no longer changes the decision on the creation frame.')
end

-- ---------------------------------------------------------------- section 4 --
-- DELETED 2026-09-08 (hero stream, GH #593). It asserted that the two "no
-- creation frame" limits were both still stale, and that they moved together.
-- They moved together, in the round that landed this baton, and the section's own
-- failure message said to delete it rather than re-arm it. The one thing it was
-- protecting -- that neither artefact is retired while the other still claims the
-- limit -- is now protected by the artefacts themselves: test_zuus_ult_strand.lua
-- section 6 goes red if this fixture ever stops satisfying the armed helper, and
-- names this file as where the end-to-end reading lives.

-- ---------------------------------------------------------------- section 5 --
-- The limits, as one-way tripwires. Each going red is GOOD NEWS: it means the
-- loader grew a reading this round had to declare instead of read.

tests['section 5: TRIPWIRE -- retreat mode is not frame data'] = function()
    local _, J, bot = on_frame()
    assert(J.IsRetreating(bot) == false, string.format(
        'GOOD NEWS: J.IsRetreating answered %s off the raw frame. Something now '
        .. 'wires bot-VM mode into the loader, so section 3 no longer needs its '
        .. 'declared injection -- re-read this file and take the reading.',
        tostring(J.IsRetreating(bot))))
end

tests['section 5: without the injection the armed branch does NOT fire'] = function()
    -- The honest other half of section 3, stated so nobody quotes the 0.75 as an
    -- unconditional reading. Raw retreat is false, so the outer `if` is not
    -- entered and ConsiderR falls through the whole branch.
    local X = select(1, on_frame({ armed = true }))
    X.SkillsComplement()
    assert(X.ConsiderR() == BOT_ACTION_DESIRE_NONE,
        'the armed tree reached DESIRE_HIGH without retreat mode being declared. '
        .. 'Then some OTHER branch of ConsiderR is firing on this frame and '
        .. "section 3's flip cannot be attributed to " .. CAND .. '.')
end

tests['section 5: TRIPWIRE -- the ultcash branch stays silent on this frame'] = function()
    -- `J.IsDyingUnderAttack` sits directly below the retreat branch and would
    -- cash the same ult. It answers false here (its damage-prediction term is
    -- GetEstimatedDamageToTarget, which no .dem carries), and `ultcash` is itself
    -- still gated. If it ever answers true on this frame, the two levers overlap
    -- here and the attribution in section 3 needs re-arguing.
    local _, J, bot = on_frame({ armed = true })
    assert(J.IsDyingUnderAttack(bot) == false,
        'GOOD NEWS/BAD NEWS: J.IsDyingUnderAttack now fires on this frame, so the '
        .. 'ultcash branch would cash this ult without ' .. CAND .. '. Re-argue how '
        .. "much of this widening's value is already covered.")
end

return tests

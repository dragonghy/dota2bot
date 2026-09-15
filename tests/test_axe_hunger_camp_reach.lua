-- [ratchet] [hero] `axebhcamp` -- X.ConsiderW's 打野 pick is the LAST unbounded
-- ring in that function: it elects the MOST-HEALTH creep out of a ring 100
-- units wider than Battle Hunger's cast range, with no distance term anywhere
-- between the list and `return BOT_ACTION_DESIRE_HIGH`.
--
-- ===========================================================================
-- §0  WHAT IS WRONG
-- ===========================================================================
--
-- bots/BotLib/hero_axe.lua X.ConsiderW bids from eight firing points.  SEVEN
-- bound their target to the cast range the function computed on its own first
-- working line (`nCastRange = abilityW:GetCastRange() + aetherRange`):
--
--     kill loop     nInRangeEnemyList
--     先手          J.IsInRange( botTarget, bot, nCastRange )
--     团战          X.axe_IsHungerFightTargetInReach   <- `axebhreach`
--     lane harass   nInRangeEnemyList
--     retreat       nInRangeEnemyList
--     roshan        J.IsInRange( bot, botTarget, nCastRange )
--     tormentor     J.IsInRange( bot, botTarget, nCastRange )
--
-- The 打野 pick is the one left:
--
--     local neutralCreepList = bot:GetNearbyNeutralCreeps( nCastRange + 100 )
--     local targetCreep      = J.GetMostHpUnit( neutralCreepList )
--
-- ⭐ THIS FILE IS THE ROUND THE SIBLING ASKED FOR.  `axebhreach` bounded the
-- 团战 ring beside it and wrote down, twice, that it was leaving this one open
-- ON PURPOSE -- once in its own header ("a later round that bounded it should
-- say so and own it") and once as a live assertion, §5.4 of
-- tests/test_axe_battle_hunger_fight_reach.lua, whose message reads "if a later
-- round bounded it, say so there and retire this assertion rather than deleting
-- it silently."  Both have been updated in this change rather than deleted.
--
-- ===========================================================================
-- §0.1  WHY THE 100 IS NOT THE SIZE OF THE MISTAKE
-- ===========================================================================
--
-- A first-match loop over a ring 100 units too wide costs at most a 100-unit
-- walk.  This is not a first-match loop.  It is a SELECTION RULE, and it
-- selects on the one axis anti-correlated with being close: MOST HP.
--
-- Axe melees the camp he is clearing from ~128 units, so a creep out in the
-- band is not the camp he is standing in -- it is the NEXT box.  And the unit
-- J.GetMostHpUnit prefers is exactly the big one (golem / centaur khan /
-- ancient) that an untouched neighbouring camp is likelier to hold than the one
-- he has already ground down.  So the band member does not merely ADD a walk,
-- it DISPLACES the in-reach creep the same list already admitted.  That is the
-- `axebhreach` swap argument, applied to the branch that sibling declined to
-- touch.
--
-- WHAT THE WALK COSTS.  X.SkillsComplement hands the returned handle to
-- ActionQueue_UseAbilityOnEntity, and a cast order on a unit beyond cast range
-- is a MOVE order first.  The bid is BOT_ACTION_DESIRE_HIGH, so for the length
-- of that walk it outranks the farming mode that put him in the camp: he leaves
-- a camp mid-clear and arrives inside the aggro radius of a box he did not
-- choose to pull.
--
-- SIZE OF THE BAND, off the KV snapshot AND off real handles.
-- axe_battle_hunger / AbilityCastRange is `600 700 800 900`
-- (tests/mock/special_value_shapes.lua), and §1 reads the same ladder back off
-- the real ability handle on all 40 corpus Axe frames.  So the band
-- (nCastRange, nCastRange + 100] is 600->700 at rank 1 and 900->1000 at rank 4
-- -- and at rank 1 its outer edge is EXACTLY the rank-2 cast range, i.e. the
-- branch already searches at the reach Axe will not have until his next point
-- in W.
--
-- ===========================================================================
-- §0.2  WHAT THIS FILE CAN AND CANNOT BUY
-- ===========================================================================
--
-- ⛔ It CANNOT buy a domain, and the reason is TWO independent constructive
-- zeros, not one.  Both are DRIVEN in §2, not narrated, and both are one-way
-- tripwires: a corpus that grows past either turns §2 red rather than letting
-- an expired claim stay green.
--
--   (a) NO POSITIONED NEUTRALS EXIST ANYWHERE.  make_fixture.py dumps heroes
--       and structures only.  The opt-in model that synthesizes neutrals from
--       `recent_damage` stands every one of them AT THE SUBJECT'S OWN LOCATION
--       -- DISTANCE IS NOT MODELLED, the declared world assumption in
--       tests/mock/replay_fixture.lua.  So wherever a neutral can be
--       synthesized at all, this predicate answers "in reach" for it by
--       construction, and the offline band count is ZERO BY CONSTRUCTION.
--       §2.2 drives that on the one subject in this corpus where a neutral CAN
--       be synthesized; §2.1 shows no Axe frame is even that subject (0 of 40).
--   (b) THE BRANCH PREMISE IS UNASKABLE -- and "unaskable" is the correct word,
--       not "false".  J.IsFarming reads `bot:GetActiveMode() == BOT_MODE_FARM`
--       or a TEAM_NEUTRAL attack target; the loader models NEITHER (no
--       GetActiveMode at all -- the GH #577 §5 shape -- and no positioned
--       neutral, which is (a) again).  So it is constant-false by
--       construction: FALSE on all 40 Axe frames AND on all 1314 living
--       subjects of every frame in the corpus, i.e. the instrument has no
--       positive control anywhere.  (That 1314-subject sweep is a DATED
--       READING, measured 2026-09-15, not a ratchet -- it costs 84s, and §2.3b
--       says why it was replaced by a proof that covers the same subjects in
--       0.05s.)  §2.3 names the first disjunct at its source; §2.3b closes the
--       second for every subject at once.
--       ⛔ "Axe never farms in the corpus" would be a claim about Axe.  This
--       is a claim about a reader that cannot answer about anybody.
--
-- ⛔ NEITHER ZERO MAY BE REPORTED AS "the lever is dead" (GH #838's shape).
-- They are instrument readings about the corpus, not readings about the bot.
-- §2.4 asserts the denominators are NON-EMPTY so §2.1/§2.3 cannot be misread as
-- "there was nothing to look at."
--
-- ✅ It CAN buy the RING (§1): nCastRange on 40 real Axe frames, off the real
-- ability handle, which is what sizes the band.  ⚠️ A reading about the ring is
-- NOT a reading about the branch firing.
--
-- ✅ It CAN buy the DECISION (§3): the election driven on ONE real frame whose
-- cast range, mana, mana cost, cooldown and item slots are all REAL and
-- untouched, with a DECLARED stand-in camp -- because per (a) no real one
-- exists to use.
--
-- ✅ It CAN buy INERTNESS end to end (§4) on all 40 real Axe frames.  ⚠️ That
-- is inertness, not a domain: per (a)+(b) it could not have been anything else.
--
-- ⛔ NO ONE MAY REPORT A NUMBER OF BIDS THIS LEVER MOVES.  Evidence is
-- requested as iterations/queue.json `hero-92` (zero EC2, archive-only).
-- Do NOT promote on the (c) argument alone.
--
-- ===========================================================================
-- §0.3  THE ANCHOR FRAME, and exactly which operands are real
-- ===========================================================================
--
-- tests/fixtures/f_260820_043637_axe_ring_alone.lua, Axe the subject:
--
--     REAL, read off the frame and the real handles, nothing injected:
--       Battle Hunger rank 3  => GetCastRange() answers 800 off this ability's
--                                own 600/700/800/900 ladder
--       no item_aether_lens   => (blink_dagger, power_treads, quelling_blade,
--                                magic_wand, bracer) so aetherRange is really
--                                0 and nCastRange is really 800; the searched
--                                ring is really 900 and the band is (800, 900]
--       IsFullyCastable()     => really TRUE; this file injects NO cooldown
--       GetManaCost()         => really 70; GetMana() 401 of 519
--       J.GetManaAfter(70)    => really 0.638 > 0.3, the branch's mana term
--       hero level 10, 1548/1732 HP
--
--     INJECTED, and labelled everywhere it is used:
--       [I1] J.IsFarming -> true.  The branch premise.  Bot MODE is bot-VM
--            state and is in no .dem; per §0.2 (b) it is false on all 40
--            frames.  §3.7 asserts the injection was actually READ.
--       [I2] the camp itself -- a DECLARED stand-in, per §0.2 (a).  Distances
--            are chosen to straddle the real 800, and the health ordering
--            (the big one is the far one) IS the mechanism under test, so it
--            is written as data rather than assumed in prose.
--       [I3] §3.5 only: bot:GetAttackDamage().  The dump carries 0 here, which
--            makes `not J.CanKillTarget(creep, 0 * 2.88, PHYSICAL)` trivially
--            TRUE and so makes the residue in §3.5 undrivable.  Used in that
--            one case and nowhere else.
--
-- ===========================================================================
-- §0.4  REPRODUCE
-- ===========================================================================
--
--     lua5.1 tests/run_tests.lua axe_hunger_camp_reach
--     bash tools/agent/mutstand_axebhcamp.sh
--     bash tools/agent/luacheck_gate.sh
--
-- ===========================================================================
-- §0.5  DIRECTION -- three claims that hold, one residue registered
-- ===========================================================================
--
--   1. SUBSET OF CANDIDATES (§3.3).  The armed pick is always a member of the
--      list the shipped query returned; the predicate only ever removes.
--   2. NEVER FURTHER (§3.3).  Every survivor is inside nCastRange, so the armed
--      pick is never further away than the shipped pick.
--   3. NO-OP EXACTLY WHEN THE SHIPPED PICK IS ALREADY IN REACH (§3.4).  If the
--      overall max-health unit is inside nCastRange it is still the max of the
--      filtered list, so J.MostHpUnitOf returns the SAME HANDLE -- ties
--      included, because that scan keeps the first `uHp > maxHP` under
--      iteration order and the filter preserves order (ipairs in, array out).
--   4. ⚠️ RESIDUE, NOT ARGUED AWAY: ARMING CAN ADD A BID.  Unlike the 团战
--      site, this branch applies four more conjuncts AFTER the election
--      (J.IsValid, not J.IsRoshan, no `_self` modifier, not J.CanKillTarget),
--      and those are re-evaluated on a DIFFERENT creep.
--      ⭐ THE FIRST DRAFT OF THIS CLAIM NAMED THE WRONG CONJUNCT, and the
--      arithmetic said so before any reviewer did.  `not J.CanKillTarget`
--      CANNOT carry the residue: adding a bid through it needs the far pick to
--      die to a swing while the near pick survives the same swing, i.e.
--      near > s >= far > near, and the election already fixed far > near.
--      §3.5a drives that impossibility; the `_self` modifier is what actually
--      carries it, because it is not ordered by the election, and §3.5b drives
--      a camp where shipped declines and armed bids.  The added bid is a
--      Battle Hunger, inside cast range, on a clean camp creep -- the branch's
--      own stated purpose -- but a wave that reads this lever negative may
--      attribute it here.

package.path = 'tests/?.lua;' .. package.path

local rf  = require('mock.replay_fixture')
local api = require('mock.bot_api')

local SRC     = 'bots/BotLib/hero_axe.lua'
local SIBLING = 'tests/test_axe_battle_hunger_fight_reach.lua'
local LOADER  = 'tests/mock/replay_fixture.lua'

local FIXTURE_DIR = 'tests/fixtures'
local STAGED_DIR  = 'tests/frames'

local UNIT   = 'npc_dota_hero_axe'
local HUNGER = 'axe_battle_hunger'
local CAND   = 'axebhcamp'
local HELPER = 'axe_HungerCampCandidates'

local ANCHOR = FIXTURE_DIR .. '/f_260820_043637_axe_ring_alone.lua'

-- The anchor's real operands (§0.3).  Named so a frame that moves says which
-- number moved, instead of a downstream case failing for an unrelated reason.
local A_RANK       = 3
local A_CAST_RANGE = 800
local A_MANA_COST  = 70
local BAND         = 100   -- the branch's search ring, over the cast range

-- The KV ladder, from tests/mock/special_value_shapes.lua.
local CAST_RANGE_LADDER = { 600, 700, 800, 900 }

-- Corpus readings, measured 2026-09-15.  §1/§2 assert every one of them, so a
-- grown corpus turns this file red instead of letting a stale number be quoted.
local N_CORPUS_FILES = 142
local N_AXE_FRAMES   = 40
local RANK_COUNTS    = { [1] = 15, [2] = 4, [3] = 7, [4] = 14 }

-- The one corpus subject whose frame CAN synthesize a neutral (§2.2).  No Axe
-- frame can; that is §2.1.
local NEUTRAL_FIX  = FIXTURE_DIR .. '/f_260903_101254_cm_farm_stealcamp.lua'
local NEUTRAL_SUBJ = 'npc_dota_hero_luna'

local tests = {}

local function read_file(path)
    local fh = assert(io.open(path, 'r'), 'cannot open ' .. path)
    local body = fh:read('*a')
    fh:close()
    return body
end

--- Both corpus directories, enumerated -- never a hardcoded list.  An empty
--- enumerator and an empty corpus are the same integer; the asserts are the
--- only thing that tells them apart.
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
        assert(n > 0, 'corpus directory ' .. dir .. ' yielded no f_*.lua frame')
    end
    table.sort(out)
    return out
end

--- One pass over the corpus, MEMOISED per option set: every frame carrying a
--- LIVING Axe with Battle Hunger trained, plus the living-Axe count §1.2 needs.
---
--- ⚠️ The cache hands out SHARED handles, so every consumer of it must be
--- read-only.  §1 and §2 are; §3 and §4 load their own frames because they arm
--- gates and inject.  Un-memoised, the six read-only cases below re-loaded all
--- 142 frames each and the file cost 9.4s -- over the 5.5s per-test cap, i.e.
--- out of the push gate and into the set whose red the NEXT desk discovers
--- (GH #624 / #806).  The cache is what keeps it inside.
local cache = {}
local function corpus_pass(tOpts)
    local key = tOpts and 'neutrals' or 'plain'
    if cache[key] then return cache[key] end
    local out, nAlive = {}, 0
    for _, path in ipairs(corpus_paths()) do
        pcall(function()
            local J, bot = rf.load(path, UNIT, tOpts)
            if bot == nil or not bot:IsAlive() then return end
            nAlive = nAlive + 1
            local hW = bot:GetAbilityByName(HUNGER)
            if hW == nil or hW:GetLevel() < 1 then return end
            out[#out + 1] = { path = path, J = J, bot = bot, hW = hW }
        end)
    end
    cache[key] = { axe = out, alive = nAlive }
    return cache[key]
end

local function axe_frames(tOpts)
    return corpus_pass(tOpts).axe
end

--- The aether-lens term, READ OFF THE FRAME rather than assumed to be 0.
---
--- The shipped ring is `abilityW:GetCastRange() + aetherRange`, and
--- hero_axe.lua sets `aetherRange = 225` when the bot holds an aether lens
--- (:431).  A mirror that drops the term under-states its own ring by 225 and
--- reads legal casts as out of range -- GH #725 read an 861.99u cast as
--- "outside 670", and tests/test_cast_ring_mirror_discipline.lua is the census
--- that refuses a push carrying one.
---
--- ⭐ IT CAUGHT THIS FILE.  The first draft swept §2.1 with
--- `GetCastRange() + BAND`, so on any lens-carrying Axe the sweep would have
--- searched a SMALLER ring than the branch does -- and §2.1's headline is a
--- ZERO, which a too-small ring produces for free.  §1.3 now counts the lens
--- frames instead of assuming there are none.
local AETHER_BONUS = 225
local AETHER_ITEM  = 'item_aether_lens'

local function aether_range(hBot)
    for i = 0, 8 do
        local hItem = hBot:GetItemInSlot(i)
        if hItem ~= nil and hItem:GetName() == AETHER_ITEM then return AETHER_BONUS end
    end
    return 0
end

--- The ring X.ConsiderW actually computes on this frame, aether term included.
local function branch_cast_range(f)
    return f.hW:GetCastRange() + aether_range(f.bot)
end

local function consider_w_body(src)
    local from = src:find('\nfunction%s+X%.ConsiderW%s*%(')
    assert(from, 'X.ConsiderW is gone from ' .. SRC)
    local rest = src:sub(from + 1)
    local to = rest:find('\nend\n')
    assert(to, 'X.ConsiderW has no closing end in ' .. SRC)
    return rest:sub(1, to)
end

--- Install `v` as the answer to `h:k()` and drop any lazily-cached method --
--- the same two steps rf.record_actions takes.  Setting only the spec entry
--- leaves an already-materialised method in place and the injection silently
--- does not take, which reads exactly like a lever that does nothing.
local function inject(h, k, v)
    rawget(h, '__spec')[k] = v
    rawset(h, k, nil)
end

-- ------------------------------------------------------------------ [I2] ---
-- The DECLARED stand-in camp.  Per §0.2 (a) no real one exists in this repo,
-- so the geometry is chosen, and it is chosen to straddle the anchor's REAL
-- 800: the big creep sits in the band (out of reach), the small one inside it.
-- The health ordering IS the mechanism, so it is data here, not prose.

local function neutral(sName, nHealth, nDistance, bot)
    local loc = bot:GetLocation()
    return api.MakeUnit({
        GetUnitName    = sName,
        IsAncientCreep = false,
        IsNull         = false,
        IsAlive        = true,
        CanBeSeen      = true,
        GetTeam        = TEAM_NEUTRAL,
        GetLocation    = api.Vector(loc.x + nDistance, loc.y, 0),
        GetHealth      = nHealth,
        GetMaxHealth   = nHealth,
        HasModifier    = false,
    })
end

--- The shape the defect needs: the MOST-HP creep is the FAR one.
local function camp_far_is_big(bot)
    return {
        neutral('npc_dota_neutral_kobold_tunneler',  325, 210, bot),  -- in reach
        neutral('npc_dota_neutral_centaur_outrunner', 700, 430, bot),  -- in reach
        neutral('npc_dota_neutral_granite_golem',    1400, 870, bot),  -- BAND
    }
end

--- The control: the MOST-HP creep is already in reach, so the lever must be a
--- byte-for-byte no-op (claim 3).
local function camp_far_is_small(bot)
    return {
        neutral('npc_dota_neutral_kobold_tunneler',   325, 870, bot),  -- BAND
        neutral('npc_dota_neutral_granite_golem',    1400, 430, bot),  -- in reach
    }
end

--- Load the anchor, arm/disarm `axebhcamp`, and install the camp as the answer
--- to bot:GetNearbyNeutralCreeps.  [I1] J.IsFarming is wrapped rather than
--- replaced so the real one is still exercised, and the read is counted.
local function anchor(bArmed, fCamp)
    local J, bot = rf.load(ANCHOR, UNIT)
    local seen = { farming = 0 }

    J.IsSoakCandidate = function(id) return bArmed and id == CAND end

    local shippedFarming = J.IsFarming
    J.IsFarming = function(...)
        seen.farming = seen.farming + 1
        shippedFarming(...)                      -- keep the real one exercised
        return true
    end

    local tCamp = fCamp and fCamp(bot) or {}
    inject(bot, 'GetNearbyNeutralCreeps', function() return tCamp end)

    local X = rf.load_hero('axe')
    return J, bot, X, tCamp, seen
end

--- The Battle Hunger target the dispatch actually ordered, or nil.
local function hungered(log)
    for _, a in ipairs(log) do
        if a.fn:find('UseAbilityOnEntity') then
            local h = a.args[2]
            if h ~= nil and h.GetUnitName ~= nil then return h:GetUnitName() end
        end
    end
    return nil
end

-- ---------------------------------------------------------------- section 1 --
-- THE RING.  Real handles, real frames.  This is what sizes the band, and it
-- is the only corpus reading in this file that is about the ability rather
-- than about the corpus's own limits.

tests['§1.1 the corpus carries exactly the Axe frames this file was measured on'] = function()
    local nFiles = #corpus_paths()
    assert(nFiles == N_CORPUS_FILES, string.format(
        'the corpus moved: %d frames, was %d.  Re-measure §1/§2 rather than '
        .. 'editing the constant -- every zero in §2 is a claim ABOUT this '
        .. 'denominator.', nFiles, N_CORPUS_FILES))

    local tAxe = axe_frames()
    assert(#tAxe == N_AXE_FRAMES, string.format(
        'Axe is alive with Battle Hunger trained on %d frames, was %d',
        #tAxe, N_AXE_FRAMES))
end

tests['§1.2 every living Axe has Battle Hunger, because it is his first point'] = function()
    -- tAllAbilityBuildList opens {2,3,1,...} and slot 2 is Battle Hunger, so
    -- "alive" and "W trained" are the same set.  Asserted rather than assumed
    -- because §1.1's denominator is built on the second condition.
    local nAlive = corpus_pass().alive
    assert(nAlive == N_AXE_FRAMES, string.format(
        'living Axe frames %d, W-trained Axe frames %d -- these used to be the '
        .. 'same set (his first skill point is W).  If they have parted, §1.1 '
        .. 'is counting something else than it says.', nAlive, N_AXE_FRAMES))

    local body = read_file(SRC)
    assert(body:find('{2,3,1,3,3,6'), 'the Axe build order moved; §1.2 rests on W being the first point')
end

tests['§1.3 the cast range on real handles is the KV ladder, so the band is real'] = function()
    local seenRank, seenRange = {}, {}
    local nWithLens = 0
    for _, f in ipairs(axe_frames()) do
        local nRank  = f.hW:GetLevel()
        -- The ABILITY's own range is what the ladder is about; the BRANCH's ring
        -- adds the aether term, and it is read off the frame (never assumed 0).
        local nRange = branch_cast_range(f) - aether_range(f.bot)
        if aether_range(f.bot) > 0 then nWithLens = nWithLens + 1 end
        seenRank[nRank]   = (seenRank[nRank] or 0) + 1
        seenRange[nRange] = (seenRange[nRange] or 0) + 1
        assert(nRange == CAST_RANGE_LADDER[nRank], string.format(
            '%s: rank %d answered cast range %s, ladder says %d.  The band '
            .. 'this lever closes is (range, range+%d], so a range that is not '
            .. 'the ladder makes every size claim in §0.1 wrong.',
            f.path, nRank, tostring(nRange), CAST_RANGE_LADDER[nRank], BAND))
    end

    for nRank, nWant in pairs(RANK_COUNTS) do
        assert(seenRank[nRank] == nWant, string.format(
            'W rank %d appears on %s frames, was %d',
            nRank, tostring(seenRank[nRank]), nWant))
    end

    -- The sharp end of §0.1: at rank 1 the band's OUTER edge is exactly the
    -- rank-2 cast range.  Arithmetic, but it is the sentence the header makes.
    assert(CAST_RANGE_LADDER[1] + BAND == CAST_RANGE_LADDER[2], string.format(
        'rank 1 band outer edge %d is no longer the rank 2 cast range %d',
        CAST_RANGE_LADDER[1] + BAND, CAST_RANGE_LADDER[2]))

    -- COUNTED, not assumed: how many corpus Axe frames carry the aether lens.
    -- Zero today, which is why every band figure in §0.1 can be quoted straight
    -- off the ladder -- but the sweeps read the term off the frame regardless,
    -- so the day one appears the numbers stay right and this count goes red.
    assert(nWithLens == 0, string.format(
        '%d Axe frame(s) now carry %s.  The band is still correct (every ring '
        .. 'here reads the term off the frame), but §0.1 quotes the ladder '
        .. 'directly -- say "+225 on N frames" there before quoting it again.',
        nWithLens, AETHER_ITEM))
end

tests['§1.4 the anchor frame still carries the operands §0.3 calls REAL'] = function()
    local J, bot = rf.load(ANCHOR, UNIT)
    assert(bot ~= nil and bot:IsAlive(), 'the anchor no longer carries a living Axe')

    local hW = bot:GetAbilityByName(HUNGER)
    assert(hW:GetLevel() == A_RANK, 'anchor W rank moved: ' .. hW:GetLevel())
    assert(hW:GetCastRange() == A_CAST_RANGE, 'anchor cast range moved: ' .. hW:GetCastRange())
    assert(hW:GetManaCost() == A_MANA_COST, 'anchor mana cost moved: ' .. hW:GetManaCost())

    -- These two are what let §3 inject only J.IsFarming.  If either stops being
    -- real, §3 is measuring more injection than §0.3 declares.
    assert(hW:IsFullyCastable() == true,
        'the anchor used to have Battle Hunger really off cooldown; §0.3 says '
        .. 'this file injects NO cooldown, and that sentence is now false')
    assert(J.GetManaAfter(hW:GetManaCost()) > 0.3,
        'the anchor used to really pass the branch mana term')

    -- No aether lens => aetherRange is 0 => nCastRange really is 800.
    for i = 0, 8 do
        local hItem = bot:GetItemInSlot(i)
        assert(hItem == nil or hItem:GetName() ~= 'item_aether_lens',
            'the anchor gained an aether lens; nCastRange is no longer ' .. A_CAST_RANGE)
    end
end

-- ---------------------------------------------------------------- section 2 --
-- THE TWO CONSTRUCTIVE ZEROS, driven.  ⛔ Neither is a statement about the
-- bot.  §2.4 keeps them from being read as "nothing to look at."

tests['§2.1 [zero a] no Axe frame can even synthesize a neutral creep'] = function()
    local nWithNeutral, nTotal = 0, 0
    for _, f in ipairs(axe_frames({ neutrals = true })) do
        nTotal = nTotal + 1
        -- The branch's own ring, aether term included (never assumed 0): a
        -- smaller ring would manufacture this case's zero for free.
        local t = f.bot:GetNearbyNeutralCreeps(branch_cast_range(f) + BAND)
        local n = 0
        for _ in pairs(t or {}) do n = n + 1 end
        if n > 0 then nWithNeutral = nWithNeutral + 1 end
    end
    assert(nTotal == N_AXE_FRAMES, 'denominator moved: ' .. nTotal)
    assert(nWithNeutral == 0, string.format(
        '%d of %d Axe frames now yield a neutral creep.  THIS IS GOOD NEWS and '
        .. 'this assertion is a tripwire, not a requirement: the dumper or the '
        .. 'corpus has grown past §0.2 (a), so go SIZE THE BAND on those frames '
        .. 'and rewrite §0.2 -- do not relax this number.',
        nWithNeutral, nTotal))
end

tests['§2.2 [zero a] and where one CAN be synthesized, distance is not modelled'] = function()
    -- Driven on the one corpus subject that has an attributable neutral hit.
    -- This is the world assumption tests/mock/replay_fixture.lua declares:
    -- every synthesized neutral stands at the subject's own location, so EVERY
    -- radius includes it and this predicate can only ever answer "in reach".
    local J, bot = rf.load(NEUTRAL_FIX, NEUTRAL_SUBJ, { neutrals = true })
    local t = bot:GetNearbyNeutralCreeps(9999)
    local n = 0
    for _ in pairs(t or {}) do n = n + 1 end
    assert(n > 0, NEUTRAL_FIX .. ' no longer synthesizes a neutral for '
        .. NEUTRAL_SUBJ .. '; §2.2 has nothing to drive and the claim is unasserted')

    local loc = bot:GetLocation()
    for _, hCreep in ipairs(t) do
        local c = hCreep:GetLocation()
        assert(c.x == loc.x and c.y == loc.y, string.format(
            'a synthesized neutral now stands somewhere of its own (%s at '
            .. '%.1f,%.1f vs subject %.1f,%.1f).  §0.2 (a) has expired: the '
            .. 'band is measurable now, so measure it.',
            hCreep:GetUnitName(), c.x, c.y, loc.x, loc.y))
        assert(GetUnitToUnitDistance(bot, hCreep) == 0,
            'a neutral standing on the subject must be at distance 0')

        -- ⚠️ [L1] SECOND MODELLING GAP, FOUND BY THIS ASSERTION FAILING.
        -- The shipped predicate does not measure distance directly, it calls
        -- J.IsInRange -- and that helper's FIRST act is `npcTarget:CanBeSeen()`
        -- (jmz_func.lua:1431).  The loader's synthesized neutral carries
        -- GetUnitName / GetTeam / IsAlive / GetLocation and NO CanBeSeen, so
        -- J.IsInRange answers FALSE here for a reason that has nothing to do
        -- with distance -- on a unit standing at distance 0.
        -- ⛔ WHY THIS MATTERS MORE THAN THE ZERO ABOVE: a later round that
        -- tries to size the band through this model would watch the armed leg
        -- drop EVERY creep and read it as "the lever removes everything."
        -- That is a false positive in the flattering direction -- it looks
        -- like a big live domain.  §0.2 (a) is therefore not merely "distance
        -- is not modelled"; it is "this model cannot answer the question in
        -- either direction."  Driven, so the day the loader gains CanBeSeen
        -- this case goes red and says the band became measurable.
        assert(J.IsInRange(bot, hCreep, 1) == false, string.format(
            'J.IsInRange now answers TRUE for a synthesized neutral (%s).  The '
            .. 'loader gained CanBeSeen, so [L1] has expired -- re-read §0.2 '
            .. '(a) before quoting any band count taken through this model.',
            hCreep:GetUnitName()))
    end

    -- And the loader still says so in the place that owns the assumption, so
    -- the two cannot drift apart silently.
    local loader = read_file(LOADER)
    assert(loader:find('DISTANCE IS NOT MODELLED'),
        LOADER .. ' no longer declares the world assumption §0.2 (a) rests on')
end

tests['§2.3 [zero b] the branch premise is UNASKABLE, not merely false'] = function()
    -- ⭐⭐ THIS CASE WAS WRITTEN AS "J.IsFarming is false on every Axe frame"
    -- AND THAT WAS THE WRONG SENTENCE.  Looking for a positive control -- some
    -- frame, any frame, where the instrument answers TRUE -- found none, and
    -- the reason is structural rather than unlucky:
    --
    --     function J.IsFarming( bot )            jmz_func.lua:1673
    --         local mode = bot:GetActiveMode()
    --         local nTarget = J.GetProperTarget( bot )
    --         return mode == BOT_MODE_FARM
    --             or ( nTarget ~= nil and nTarget:IsAlive()
    --                  and nTarget:GetTeam() == TEAM_NEUTRAL and ... )
    --
    -- BOTH disjuncts are closed offline, and by the SAME two gaps this file
    -- already carries:
    --   * GetActiveMode is bot-VM state that no .dem carries -- the loader does
    --     not implement it at all (the GH #577 §5 shape the `axecallring` round
    --     registered for J.IsGoingOnSomeone);
    --   * the second disjunct needs a TEAM_NEUTRAL target, and §0.2 (a) is that
    --     no positioned neutral exists to be one.
    --
    -- ⛔ SO THE ZERO BELOW IS A PROPERTY OF THE INSTRUMENT, NOT OF THE BOT.
    -- "Axe never farms in the corpus" would be a claim about Axe; this is a
    -- claim about a reader that cannot answer on any subject.  A round that
    -- reported the former would be reporting the bot's behaviour from a
    -- function that is constant-false by construction.
    local nFarming, nTotal = 0, 0
    for _, f in ipairs(axe_frames()) do
        nTotal = nTotal + 1
        if f.J.IsFarming(f.bot) then nFarming = nFarming + 1 end
    end
    assert(nTotal == N_AXE_FRAMES, 'denominator moved: ' .. nTotal)
    assert(nFarming == 0, string.format(
        '%d of %d Axe frames are now farming.  Same tripwire as §2.1: the '
        .. 'premise has arrived, so drive the branch end to end on those '
        .. 'frames instead of injecting [I1].', nFarming, nTotal))

    -- The first disjunct, named at its source: the loader does not model
    -- GetActiveMode at all, so `mode == BOT_MODE_FARM` is unanswerable.
    local _, botA = rf.load(ANCHOR, UNIT)
    local spec = rawget(botA, '__spec')
    assert(spec ~= nil, 'the loader stopped exposing __spec; this check cannot be made')
    assert(spec.GetActiveMode == nil,
        'the loader now models GetActiveMode.  [zero b] has expired: '
        .. 'J.IsFarming can answer, so go find the frames where it does and '
        .. 'drive the jungle branch on them instead of injecting [I1].')
    assert(not read_file(LOADER):find('GetActiveMode'),
        LOADER .. ' now mentions GetActiveMode; re-read §2.3 before quoting it')
end

tests['§2.3b [zero b] the SECOND disjunct is closed for every subject too'] = function()
    -- The other half of J.IsFarming needs J.GetProperTarget( bot ) to be a
    -- LIVING TEAM_NEUTRAL unit.  Every handle the loader can hand back comes
    -- from `fx.units`, so if no frame carries a non-hero row, no subject on any
    -- frame can have a neutral target -- for every subject at once, and by
    -- construction rather than by sampling.
    --
    -- ⭐ THIS REPLACED AN 84-SECOND SWEEP, and the swap is the point.  The
    -- sweep drove all 1314 living subjects of all 142 frames through rf.load
    -- and J.IsFarming (measured 2026-09-15: 0 of 1314 answered true, which is
    -- how [zero b] was found).  It is a COMPLETE reading and it is also 1500x
    -- the cost of the proof below, which covers the same subjects.  A file
    -- nobody can afford to run is a file no gate runs (GH #624), so the sweep
    -- is recorded as a dated reading in §0.2 (b) and the ratchet is this.
    local nRows, nNonHero = 0, 0
    local sFirst = nil
    for _, path in ipairs(corpus_paths()) do
        local fx = dofile(path)
        for _, u in ipairs(fx.units or {}) do
            nRows = nRows + 1
            if not tostring(u.name):find('^npc_dota_hero_') then
                nNonHero = nNonHero + 1
                sFirst = sFirst or (path .. ' :: ' .. tostring(u.name))
            end
        end
    end
    assert(nRows == 1420, string.format(
        'unit rows across the corpus: %d, was 1420.  Re-measure §2 before '
        .. 'trusting any zero in it.', nRows))
    assert(nNonHero == 0, string.format(
        'the dumper now carries a NON-HERO unit row (%s), %d of %d.  Both of '
        .. '§0.2\'s zeros may have expired at once -- a neutral row can be a '
        .. 'J.IsFarming target AND a positioned band member.  Go size the band.',
        tostring(sFirst), nNonHero, nRows))
end

tests['§2.4 the denominators behind those two zeros are NOT empty'] = function()
    -- Without this, §2.1 and §2.3 read as "0 of 0" -- a reading a broken
    -- enumerator produces for free, and the shape that makes a zero look like
    -- a finding.  (The WK `wkrank0` round had to add exactly this guard.)
    local tAxe = axe_frames()
    assert(#tAxe == N_AXE_FRAMES and #tAxe > 0,
        'the Axe frame set is empty; every zero in §2 is vacuous')

    local nRanked = 0
    for _, f in ipairs(tAxe) do
        if f.hW:GetLevel() >= 2 then nRanked = nRanked + 1 end
    end
    -- The branch also needs rank >= 2.  That half of the premise DOES hold in
    -- the corpus, which is what makes J.IsFarming the binding one in §2.3.
    assert(nRanked == 25, 'Axe frames with W rank >= 2: ' .. nRanked .. ', was 25')
end

-- ---------------------------------------------------------------- section 3 --
-- THE DECISION, driven on the anchor's real geometry with the declared camp.

tests['§3.1 gate off returns the shipped table BY IDENTITY'] = function()
    local _, bot, X = anchor(false, camp_far_is_big)
    local tIn  = bot:GetNearbyNeutralCreeps(A_CAST_RANGE + BAND)
    local tOut = X.axe_HungerCampCandidates(tIn, A_CAST_RANGE)
    assert(tOut == tIn,
        'gate off must hand back the very table it was given, not a copy -- '
        .. 'identity is the strongest form of "byte-for-byte the shipped path"')
end

tests['§3.2 non-turbo returns it by identity too, even with the id armed'] = function()
    local J, bot, X = anchor(true, camp_far_is_big)
    J.IsModeTurbo = function() return false end
    local tIn  = bot:GetNearbyNeutralCreeps(A_CAST_RANGE + BAND)
    assert(X.axe_HungerCampCandidates(tIn, A_CAST_RANGE) == tIn,
        'the lever is turbo-only; a non-turbo game must see the shipped table')
end

tests['§3.3 armed, the band member is dropped and the in-reach creep elected'] = function()
    local J, bot, X, tCamp = anchor(true, camp_far_is_big)
    local nCastRange = A_CAST_RANGE

    -- The premise of the whole case: shipped elects the FAR big one.
    local hShipped = J.GetMostHpUnit(tCamp)
    assert(hShipped:GetUnitName() == 'npc_dota_neutral_granite_golem',
        'the stand-in camp no longer has the most-HP creep out in the band; '
        .. '§3.3 is not testing what it says')
    assert(not J.IsInRange(bot, hShipped, nCastRange),
        'the shipped pick is supposed to be OUT of reach on this camp')

    local tArmed = X.axe_HungerCampCandidates(tCamp, nCastRange)
    local hArmed = J.GetMostHpUnit(tArmed)

    -- claim 1: subset of candidates
    assert(#tArmed == 2 and #tCamp == 3, string.format(
        'armed candidates %d of %d', #tArmed, #tCamp))
    for _, h in ipairs(tArmed) do
        local bFound = false
        for _, g in ipairs(tCamp) do if g == h then bFound = true end end
        assert(bFound, 'armed produced a handle the shipped query never returned')
    end

    -- claim 2: never further
    assert(hArmed:GetUnitName() == 'npc_dota_neutral_centaur_outrunner',
        'armed elected ' .. hArmed:GetUnitName() .. ', wanted the in-reach big one')
    assert(J.IsInRange(bot, hArmed, nCastRange), 'the armed pick must be in reach')
    assert(hArmed ~= hShipped, 'this case exists to show the SWAP; nothing moved')
    -- The same swap, driven through the real dispatch, is §3.6.
end

tests['§3.4 armed is a no-op when the shipped pick is already in reach'] = function()
    local J, bot, X, tCamp = anchor(true, camp_far_is_small)
    local hShipped = J.GetMostHpUnit(tCamp)
    assert(J.IsInRange(bot, hShipped, A_CAST_RANGE),
        'the control camp is supposed to put the big one IN reach')

    local hArmed = J.GetMostHpUnit(X.axe_HungerCampCandidates(tCamp, A_CAST_RANGE))
    assert(hArmed == hShipped, string.format(
        'claim 3 broken: armed elected %s, shipped elected %s.  When the '
        .. 'max-health unit is in reach it is still the max of the filtered '
        .. 'list, so the SAME HANDLE must come back.',
        tostring(hArmed and hArmed:GetUnitName()),
        tostring(hShipped and hShipped:GetUnitName())))
end

tests['§3.5a [residue] the J.CanKillTarget route is arithmetically IMPOSSIBLE'] = function()
    -- ⭐ THIS CASE EXISTS BECAUSE THE FIRST DRAFT OF §0.5 CLAIM 4 NAMED THE
    -- WRONG CONJUNCT, and the arithmetic -- not a reviewer -- said so.
    --
    -- For arming to ADD a bid through `not J.CanKillTarget(creep, swing)`, the
    -- shipped FAR pick must DIE to a swing (so shipped declines) while the
    -- armed NEAR pick SURVIVES it (so armed bids).  But the far pick is only
    -- elected because it has MORE health.  Writing s for the swing:
    --
    --     far > near        (election: J.MostHpUnitOf keeps the max)
    --     far <= s          (shipped declines: the far pick is killable)
    --     near > s          (armed bids: the near pick is not)
    --  => near > s >= far > near.  Contradiction.
    --
    -- J.CanKillTarget is monotone in health at a fixed damage and damage type,
    -- and both picks are scored with the SAME swing, so no health assignment
    -- satisfies all three.  The residue is therefore narrower than claim 4
    -- first said, and §3.5b is what actually carries it.
    local J, bot, X, tCamp = anchor(true, camp_far_is_big)
    inject(bot, 'GetAttackDamage', 260)          -- [I3], §3.5a/b only
    local nSwing = 260 * 2.88

    local hShipped = J.GetMostHpUnit(tCamp)
    local hArmed   = J.GetMostHpUnit(X.axe_HungerCampCandidates(tCamp, A_CAST_RANGE))
    assert(hShipped:GetHealth() > hArmed:GetHealth(),
        'the election premise: the far pick is the one with more health')

    -- Monotonicity, driven on the two real picks rather than asserted in prose.
    assert(J.CanKillTarget(hArmed, nSwing, DAMAGE_TYPE_PHYSICAL)
            or not J.CanKillTarget(hShipped, nSwing, DAMAGE_TYPE_PHYSICAL),
        'J.CanKillTarget stopped being monotone in health: it killed the '
        .. 'HIGHER-health pick while sparing the lower one.  The impossibility '
        .. 'argument above rests on that monotonicity -- re-derive it.')
end

tests['§3.5b [residue] arming CAN add a bid, via the `_self` modifier conjunct'] = function()
    -- §0.5 claim 4, driven rather than confessed, on the conjunct that CAN
    -- carry it: `not targetCreep:HasModifier('modifier_axe_battle_hunger_self')`.
    -- Unlike health it is not ordered by the election, so the far pick can
    -- carry the debuff while the near one does not.  Shipped elects the far
    -- one, sees the modifier and declines; armed elects the near one and bids.
    local J, bot, X = anchor(true, camp_far_is_big)

    local function hungeredCreep(sName, nHealth, nDistance, bHas)
        local h = neutral(sName, nHealth, nDistance, bot)
        inject(h, 'HasModifier', function(_, s)
            return bHas and s == 'modifier_axe_battle_hunger_self' or false
        end)
        return h
    end

    local tResidue = {
        hungeredCreep('npc_dota_neutral_centaur_outrunner',  700, 430, false), -- in reach, clean
        hungeredCreep('npc_dota_neutral_granite_golem',     1400, 870, true),  -- BAND, already hungered
    }

    local hFar = J.GetMostHpUnit(tResidue)
    assert(hFar:GetUnitName() == 'npc_dota_neutral_granite_golem',
        'the residue camp must still elect the band member when unarmed')
    assert(hFar:HasModifier('modifier_axe_battle_hunger_self'),
        'the shipped pick must carry the debuff, so the shipped branch declines')

    local hNear = J.GetMostHpUnit(X.axe_HungerCampCandidates(tResidue, A_CAST_RANGE))
    assert(hNear:GetUnitName() == 'npc_dota_neutral_centaur_outrunner',
        'armed must fall through to the in-reach creep')
    assert(not hNear:HasModifier('modifier_axe_battle_hunger_self'),
        'and that creep must be clean, so armed BIDS where shipped declined')

    -- The whole point, through the real branch: desire 0 shipped, a bid armed.
    local function desire(bArmed)
        local J2, bot2, X2 = anchor(bArmed, nil)
        inject(bot2, 'GetNearbyNeutralCreeps', function()
            local t = {}
            for _, spec in ipairs({
                { 'npc_dota_neutral_centaur_outrunner',  700, 430, false },
                { 'npc_dota_neutral_granite_golem',     1400, 870, true  },
            }) do
                local h = neutral(spec[1], spec[2], spec[3], bot2)
                inject(h, 'HasModifier', function(_, s)
                    return spec[4] and s == 'modifier_axe_battle_hunger_self' or false
                end)
                t[#t + 1] = h
            end
            return t
        end)
        local _ = J2
        local d, hT = X2.ConsiderW()
        return d, hT and hT:GetUnitName() or nil
    end

    local dOff = desire(false)
    local dOn, sOn = desire(true)
    assert(dOff == BOT_ACTION_DESIRE_NONE or dOff == 0, string.format(
        'shipped should DECLINE on the residue camp, got desire %s', tostring(dOff)))
    assert(dOn == BOT_ACTION_DESIRE_HIGH and sOn == 'npc_dota_neutral_centaur_outrunner',
        string.format('armed should bid on the in-reach creep, got %s on %s',
            tostring(dOn), tostring(sOn)))
end

tests['§3.6 BRANCH LEVEL: X.ConsiderW swaps the target, and only when armed'] = function()
    -- ⚠️ READ §3.6b BEFORE QUOTING THIS.  This is the BRANCH's answer, not the
    -- hero's action.  The two are different numbers on this frame and the
    -- split is deliberate.
    local function bid(bArmed)
        local _, _, X = anchor(bArmed, camp_far_is_big)
        local d, hT, sM = X.ConsiderW()
        return d, hT and hT:GetUnitName() or nil, sM
    end

    local dOff, sOff, mOff = bid(false)
    local dOn,  sOn,  mOn  = bid(true)

    assert(dOff == BOT_ACTION_DESIRE_HIGH and mOff == 'W-打野', string.format(
        'gate off, the jungle branch should bid; got desire %s motive %s.  If '
        .. 'the motive is not W-打野 an EARLIER firing point took the bid and '
        .. 'this case is no longer about the jungle branch.',
        tostring(dOff), tostring(mOff)))
    assert(sOff == 'npc_dota_neutral_granite_golem',
        'gate off should target the far golem, got ' .. tostring(sOff))

    assert(dOn == BOT_ACTION_DESIRE_HIGH and mOn == 'W-打野',
        'armed, the branch should still bid -- this lever swaps the target, it '
        .. 'does not silence the branch')
    assert(sOn == 'npc_dota_neutral_centaur_outrunner',
        'armed should target the in-reach creep, got ' .. tostring(sOn))
end

tests['§3.6b END TO END: the swap does NOT reach the dispatch on this frame'] = function()
    -- ⭐⭐ THE SPLIT, MADE ON PURPOSE.  The branch-level reading above is 1
    -- swap; the end-to-end reading is 0, and the reason is dispatch ORDER, not
    -- the lever: X.SkillsComplement asks X.ConsiderQ first, Berserker's Call
    -- bids the same BOT_ACTION_DESIRE_HIGH (0.75) on this frame, and a tie goes
    -- to whoever was asked first.  So on the anchor the hero casts Call either
    -- way and the jungle target never becomes an order.
    --
    -- ⛔ A ROUND THAT SKIPPED THIS SPLIT WOULD REPORT THE 1 AS AN END-TO-END
    -- READING -- i.e. report a cast that does not happen.  (Same shape as the
    -- `axecallring` round's 支路层 1 / 端到端 0, where X.ConsiderR won the
    -- order instead.)  Neither number is wrong; quoting one for the other is.
    local function driven(bArmed)
        local _, bot, X = anchor(bArmed, camp_far_is_big)
        local log = rf.record_actions(bot)
        X.SkillsComplement()
        local sAbility = nil
        for _, a in ipairs(log) do
            if a.fn:find('UseAbility') then
                local h = a.args[1]
                if h ~= nil and h.GetName ~= nil then sAbility = h:GetName() end
            end
        end
        return sAbility, hungered(log)
    end

    local sAbilityOff, sTargetOff = driven(false)
    local sAbilityOn,  sTargetOn  = driven(true)

    assert(sAbilityOff == 'axe_berserkers_call' and sAbilityOn == 'axe_berserkers_call',
        string.format('the anchor used to cast Berserker\'s Call on BOTH legs '
            .. '(ConsiderQ is asked first and ties at 0.75); got %s / %s.  If '
            .. 'Battle Hunger now wins the order, this frame gained an '
            .. 'end-to-end reading -- go take it and rewrite §3.6b.',
            tostring(sAbilityOff), tostring(sAbilityOn)))
    assert(sTargetOff == nil and sTargetOn == nil,
        'Berserker\'s Call is No Target, so no UseAbilityOnEntity should appear '
        .. 'on either leg')
end

tests['§3.7 the [I1] injection was actually READ before any reading was taken'] = function()
    local _, bot, X, _, seen = anchor(true, camp_far_is_big)
    local log = rf.record_actions(bot)
    X.SkillsComplement()
    local _ = log
    assert(seen.farming > 0, string.format(
        'J.IsFarming was never called, so §3.6 did not reach the jungle branch '
        .. 'at all and its readings are about some other firing point (read %d '
        .. 'times)', seen.farming))
end

-- ---------------------------------------------------------------- section 4 --
-- INERTNESS end to end on the real corpus.  ⚠️ Per §0.2 this could not have
-- come out any other way -- it separates "inert where it should be" from DEAD
-- WIRING, and it is NOT a domain size.

tests['§4 on all 40 real Axe frames, arming changes no action'] = function()
    local nDriven, nMoved = 0, 0
    for _, path in ipairs(corpus_paths()) do
        pcall(function()
            local function drive(bArmed)
                local J, bot = rf.load(path, UNIT, { neutrals = true })
                if bot == nil or not bot:IsAlive() then return nil end
                local hW = bot:GetAbilityByName(HUNGER)
                if hW == nil or hW:GetLevel() < 1 then return nil end
                J.IsSoakCandidate = function(id) return bArmed and id == CAND end
                local X = rf.load_hero('axe')
                local log = rf.record_actions(bot)
                X.SkillsComplement()
                return hungered(log) or '<none>'
            end
            local sOff = drive(false)
            if sOff == nil then return end
            nDriven = nDriven + 1
            if drive(true) ~= sOff then nMoved = nMoved + 1 end
        end)
    end
    assert(nDriven == N_AXE_FRAMES, 'drove ' .. nDriven .. ' frames, wanted ' .. N_AXE_FRAMES)
    assert(nMoved == 0, nMoved .. ' real frames changed action when armed.  Per '
        .. '§0.2 that is impossible offline today, so either the corpus grew '
        .. '(go size the band) or the lever is reaching somewhere it should not')
end

-- ---------------------------------------------------------------- section 5 --
-- WIRING AND SHAPE.

tests['§5.1 the predicate names exactly one soak id, and it is not conjoined'] = function()
    local src  = read_file(SRC)
    local from = src:find('function%s+X%.' .. HELPER .. '%s*%(')
    assert(from, 'X.' .. HELPER .. ' is gone from ' .. SRC)
    local rest = src:sub(from)
    local body = rest:sub(1, rest:find('\nend\n'))

    local _, n = body:gsub('IsSoakCandidate%(', '')
    assert(n == 1, 'the predicate names ' .. n .. ' soak ids, must be exactly 1.  '
        .. 'Two ids conjoined inside one predicate is the pullcad trap: the day '
        .. 'either is promoted this gate freezes FALSE and the lever no-ops in '
        .. 'every wave while check_armed_wiring.py still calls it WIRED.')
    assert(body:find("IsSoakCandidate%(%s*'" .. CAND .. "'%s*%)"),
        'the id in the predicate is not ' .. CAND)
    assert(body:find('J%.IsModeTurbo%(%)'), 'the lever must be turbo-only')

    for _, sSibling in ipairs({ 'axebhreach', 'axebhrecast', 'axebhpure', 'abilanc' }) do
        assert(not body:find(sSibling),
            'sibling id ' .. sSibling .. ' must not appear inside this predicate')
    end
end

tests['§5.2 the shipped query ring is untouched; only the PICK is filtered'] = function()
    local body = consider_w_body(read_file(SRC))

    -- The header claims the lever filters the ring rather than shrinking it.
    assert(body:find('GetNearbyNeutralCreeps%(%s*nCastRange%s*%+%s*' .. BAND .. '%s*%)'),
        'the jungle QUERY no longer reads nCastRange + ' .. BAND .. '.  This '
        .. 'lever deliberately left the query alone and filters the result; if '
        .. 'a later round shrank the query, say so and retire this assertion.')

    -- ...and the pick goes through the filter.
    assert(body:find('J%.GetMostHpUnit%(%s*X%.' .. HELPER .. '%('),
        'the jungle pick no longer runs through X.' .. HELPER)

    local iQuery  = body:find('GetNearbyNeutralCreeps')
    local iFilter = body:find('X%.' .. HELPER)
    assert(iQuery < iFilter, 'the filter must sit below the query it filters')
end

tests['§5.3 the sibling `axebhreach` kept its one call site'] = function()
    local src = read_file(SRC)
    local _, nReach = src:gsub('X%.axe_IsHungerFightTargetInReach%(', '')
    assert(nReach == 2, 'the 团战 reach lever must appear exactly twice (its '
        .. 'definition and its one call site), got ' .. nReach
        .. '.  `axebhcamp` is a different lever and this round does not move it.')
end

tests['§5.4 the sibling file was told about this round, not left to rot'] = function()
    -- §5.4 of SIBLING asserted the jungle pick was UNBOUNDED, on purpose, and
    -- its own message asked a later round to "say so there and retire this
    -- assertion rather than deleting it silently."  This is that round.  The
    -- check here is that somebody did the saying -- in both places.
    local sib = read_file(SIBLING)
    assert(sib:find(CAND), SIBLING .. ' still does not mention ' .. CAND
        .. '.  Its §5.4 asked to be retired by name when a round bounded the '
        .. 'jungle pick; retiring it silently is exactly what it forbade.')

    local src = read_file(SRC)
    local iSibHeader = src:find('SUPERSEDED 2026%-09%-15 by `' .. CAND .. '`')
    assert(iSibHeader, 'the `axebhreach` header in ' .. SRC .. ' still says the '
        .. 'jungle pick is left alone, and that sentence is now false about '
        .. 'the PICK (it is still true about the QUERY -- say which)')
end

return tests

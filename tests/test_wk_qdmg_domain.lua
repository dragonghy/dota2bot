-- [hero] [ratchet] GH #311: the `wkqdmg` domain, DERIVED -- joined to the shipped
-- upgrade row instead of argued per Q rank.
--
-- WHY THIS FILE EXISTS
-- --------------------
-- `wkqdmg` (X.wk_GetBlastKillDamage, bots/BotLib/hero_skeleton_king.lua) is a
-- pure narrowing: `math.min(honest, shipped)`.  So it acts on exactly the states
-- where the honest read is SMALLER, and until GH #311 nobody had written down
-- which states those are in terms a reader can go looking in.  Both prose
-- arguments for the lever were per-Q-rank, and per Q rank the t10 talent looks
-- like it OPENS the gap.  Joined to the row the bot actually levels up from, the
-- direction reverses -- it narrows the gap from 48 to 8 -- and the lever stops
-- existing entirely eight levels earlier than the notes implied.
--
-- The cost of not having this was already paid once: the first version of
-- tools/batch_test/behavioral/wkqdmg_domain.py was written against the reversed
-- sentence, and only printing `q_lvl` over 90 real games caught it.
--
-- WHAT IS PINNED, AND WHY IN THIS ORDER
--   1. the corpus anchor: Wraith King's ability slot 1 IS Hellfire Blast.  The
--      mock answers synthetic slot names, so the fixture corpus is the only
--      offline evidence for what a slot is NAMED (the rule tests/skill_level_map
--      states and tests/test_axe_t15_payoff.lua follows).
--   2. the rank ladder, DRIVEN through the real J.Skill.GetSkillList -- never a
--      re-typed "Q is maxed by N".  Counting row entries answers a different
--      question and is off by one per talent already taken (GH #134): Q's second
--      point is row entry 12 and lands at hero level 13.
--   3. the lever's own arithmetic, driven through the real
--      X.wk_GetBlastKillDamage on a real frame.
--   4. (2) x (3) = the domain, as a narrowing-by-hero-level table.
--   5. the counterfactual that makes the domain conditional rather than absolute:
--      arming `wkbuild` moves the floor from 13 to 5.
--   6. a text ratchet on the two repaired comment blocks.
--
-- SCOPE.  Zero behaviour is asserted to change here and none does: `wkqdmg` and
-- `wkbuild` are both gated, unarmed and unpromoted, and this round edited only
-- comments in bots/.  This file measures the domain of a lever; it does not argue
-- for arming, retiring or promoting it.  Its condition (a) is INDETERMINATE and
-- blocked on GH #310, which this file does not touch.

package.path = 'tests/?.lua;' .. package.path
local skillmap = require('skill_level_map')
local rf = require('mock.replay_fixture')

local HERO_SRC  = 'bots/BotLib/hero_skeleton_king.lua'
local Q_SLOT    = 1
local Q_NAME    = 'skeleton_king_hellfire_blast'
local FRAME     = 'tests/fixtures/f_260820_181711_wk_l1trade_333.lua'

-- KV, `skeleton_king_hellfire_blast` (same source as
-- tests/test_replay_260820_wk_blast_overclaim.lua, which anchors it in full).
local Q_IMPACT  = { 80, 100, 120, 140 }   -- damage
local Q_DOT_DPS = { 20, 40, 60, 80 }      -- blast_dot_damage, PER SECOND
local Q_DOT_BASE = 2.0                    -- blast_dot_duration
local Q_DOT_T10  = 4.0                    -- ... with the t10 pick trained (+2)

local TALENT_LEVELS = { [10] = true, [15] = true, [20] = true, [25] = true }

local src = skillmap.read_file(HERO_SRC)
local talents = skillmap.talent_rows(src)

--- hero level -> Q rank, from the list the bot would actually level up from.
local function q_ladder(sTable)
    local row = skillmap.build_row(src, 1, sTable)
    local ladder = skillmap.rank_ladder('skeleton_king', row, talents)
    return ladder[Q_SLOT], row
end

--- The shipped claim and the honest read at a given Q rank / dot duration.
local function shipped_at(nRank) return (40 * (nRank - 1) + 100) * 1.68 end
local function honest_at(nRank, nDur) return Q_IMPACT[nRank] + Q_DOT_DPS[nRank] * nDur end

--- Drive the real helper on the real frame with a stated rank and dot duration.
local function armed_value(nRank, nDur)
    local J, bot = rf.load(FRAME)
    local abilityQ = bot:GetAbilityByName(Q_NAME)
    local spec = rawget(abilityQ, '__spec')
    spec.GetLevel = nRank
    spec.GetSpecialValueInt = function(_, sKey)
        if sKey == 'damage' then return Q_IMPACT[nRank] end
        if sKey == 'blast_dot_damage' then return Q_DOT_DPS[nRank] end
        return 0
    end
    spec.GetSpecialValueFloat = function(_, sKey)
        if sKey == 'blast_dot_duration' then return nDur end
        return 0
    end
    J.IsSoakCandidate = function(id) return id == 'wkqdmg' end
    local X = rf.load_hero('skeleton_king')
    return X.wk_GetBlastKillDamage(abilityQ), bot
end

--- How much the armed lever withdraws at a hero level under a given build row.
local function narrowing_at_hero_level(tQLadder, nHeroLevel)
    local nRank = 0
    for r = 1, 4 do
        if tQLadder[r] ~= nil and tQLadder[r] <= nHeroLevel then nRank = r end
    end
    if nRank == 0 then return nil end                       -- Q not learned yet
    local nDur = (nHeroLevel >= 10) and Q_DOT_T10 or Q_DOT_BASE
    local nArmed = armed_value(nRank, nDur)
    return shipped_at(nRank) - nArmed, nRank, nDur, nArmed
end

local tests = {}

-- ------------------------------------------------------- 1. the corpus anchor

tests['[hero] wkqdmg domain 1: Wraith King ability slot 1 is Hellfire Blast (corpus, not the mock)'] = function()
    local _, bot = rf.load(FRAME)
    local sName = bot:GetAbilityByName(Q_NAME):GetName()
    assert(sName == Q_NAME,
        'the frame no longer carries ' .. Q_NAME .. ' on Wraith King, got ' .. tostring(sName))

    -- The lever binds by hardcoded name, but the RANK LADDER below is keyed by
    -- sAbilityList slot, so the join between the two has to be evidence.  The
    -- fixture dumps abilities in slot order.
    local fixture = dofile(FRAME)
    local tAbil
    for _, u in pairs(fixture.units or fixture.heroes or {}) do
        if u.name == 'npc_dota_hero_skeleton_king' and u.abilities then tAbil = u.abilities end
    end
    assert(tAbil, 'the frame no longer carries a skeleton_king ability list')
    assert(tAbil[Q_SLOT] and tAbil[Q_SLOT].name == Q_NAME,
        'the corpus now dumps Wraith King slot ' .. Q_SLOT .. ' as '
        .. tostring(tAbil[Q_SLOT] and tAbil[Q_SLOT].name) .. ', not ' .. Q_NAME
        .. '.  Every level claim below is keyed to that slot.')
end

-- --------------------------------------------------------- 2. the rank ladder

tests['[hero] wkqdmg domain 2: row entry 12 is HERO LEVEL 13 -- the step both notes skipped'] = function()
    local ladder, row = q_ladder('tAllAbilityBuildList')
    assert(ladder, 'the shipped row spends no point on Q slot ' .. Q_SLOT)

    -- Row entry, read straight off the literal ...
    local nEntry
    local nSeen = 0
    for i, v in ipairs(row) do
        if v == Q_SLOT then nSeen = nSeen + 1; if nSeen == 2 then nEntry = i; break end end
    end
    assert(nEntry == 12, 'Q\'s second point is no longer row entry 12, got ' .. tostring(nEntry))

    -- ... and the hero level it lands at, DRIVEN.  These differ by one because
    -- hero level 10 is a talent slot and spends no ability point.  This is the
    -- whole reason the "opens at level 10" reading was possible.
    assert(ladder[1] == 2, 'Q\'s first point is hero level 2, got ' .. tostring(ladder[1]))
    assert(ladder[2] == 13,
        'under the shipped row Q reaches rank 2 at hero level 13, got ' .. tostring(ladder[2])
        .. '.  If this moved, the domain in hero_skeleton_king.lua moved with it.')
    assert(ladder[2] ~= nEntry,
        'row entry index and hero level must not be conflated (GH #134)')
    assert(TALENT_LEVELS[10], 'sanity: 10 is a talent level, which is why 12 -> 13')

    -- 90 real games agree (tools/batch_test/behavioral/wkqdmg_domain.py, GH #311):
    -- Q sits at rank 1 from hero level 2 through 12 and reaches 2 at 13.
    for nHeroLevel = 2, 12 do
        local nRank = 0
        for r = 1, 4 do if ladder[r] and ladder[r] <= nHeroLevel then nRank = r end end
        assert(nRank == 1,
            'hero level ' .. nHeroLevel .. ' should hold Q rank 1, got ' .. nRank)
    end
end

-- ---------------------------------------------------- 3. the lever arithmetic

tests['[hero] wkqdmg domain 3: t10 NARROWS the rank-1 gap 48 -> 8, it does not open it'] = function()
    local nBase = shipped_at(1) - armed_value(1, Q_DOT_BASE)
    local nT10  = shipped_at(1) - armed_value(1, Q_DOT_T10)

    assert(math.abs(nBase - 48) < 1e-9,
        'rank 1 without the talent withdraws 168 - 120 = 48, got ' .. nBase)
    assert(math.abs(nT10 - 8) < 1e-9,
        'rank 1 WITH the talent withdraws 168 - 160 = 8, got ' .. nT10)
    assert(nT10 < nBase,
        'GH #311: the t10 pick makes the honest read BIGGER, so it makes this '
        .. 'lever withdraw LESS.  Any note saying the gap opens at level 10 has '
        .. 'the sign backwards.')
end

tests['[hero] wkqdmg domain 3b: with the talent trained, rank 2+ is a byte-for-byte no-op'] = function()
    for nRank = 2, 4 do
        local nShipped = shipped_at(nRank)
        assert(honest_at(nRank, Q_DOT_T10) > nShipped,
            'rank ' .. nRank .. ' honest read should overtake shipped once the dot is 4s')
        assert(armed_value(nRank, Q_DOT_T10) == nShipped,
            'armed rank ' .. nRank .. ' must fall back to the shipped constant exactly, got '
            .. armed_value(nRank, Q_DOT_T10))
    end
    -- Without the talent it still narrows at every rank -- so the no-op is a
    -- statement about the TALENT plus the rank, not about the rank alone.
    for nRank = 2, 4 do
        assert(armed_value(nRank, Q_DOT_BASE) < shipped_at(nRank),
            'rank ' .. nRank .. ' at a 2s dot still narrows')
    end
end

-- ------------------------------------------------------------- 4. the domain

tests['[hero] wkqdmg domain 4: hero 2-9 withdraw 48, 10-12 withdraw 8, 13+ withdraw nothing'] = function()
    local ladder = q_ladder('tAllAbilityBuildList')

    assert(narrowing_at_hero_level(ladder, 1) == nil, 'Q is unlearned at hero level 1')
    for nHeroLevel = 2, 9 do
        local n = narrowing_at_hero_level(ladder, nHeroLevel)
        assert(math.abs(n - 48) < 1e-9,
            'hero level ' .. nHeroLevel .. ' should withdraw 48, got ' .. tostring(n))
    end
    for nHeroLevel = 10, 12 do
        local n = narrowing_at_hero_level(ladder, nHeroLevel)
        assert(math.abs(n - 8) < 1e-9,
            'hero level ' .. nHeroLevel .. ' should withdraw 8, got ' .. tostring(n))
    end
    for nHeroLevel = 13, 25 do
        local n, nRank, _, nArmed = narrowing_at_hero_level(ladder, nHeroLevel)
        assert(n == 0,
            'hero level ' .. nHeroLevel .. ' is outside this lever\'s domain and must '
            .. 'withdraw exactly 0, got ' .. tostring(n))
        assert(nArmed == shipped_at(nRank), 'and the armed return is the shipped value itself')
    end
end

-- ------------------------------------------------- 5. the wkbuild dependency

tests['[hero] wkqdmg domain 5: arming wkbuild moves the no-op floor 13 -> 10, and it is NOT a shrink to hero <=4'] = function()
    local shippedLadder = q_ladder('tAllAbilityBuildList')
    local killLadder    = q_ladder('tKillBuildList')

    assert(killLadder[2] == 5,
        'tKillBuildList takes Q\'s second point at hero level 5, got ' .. tostring(killLadder[2]))
    assert(shippedLadder[2] - killLadder[2] == 8,
        'the two rows should put Q\'s second point eight hero levels apart, got '
        .. tostring(shippedLadder[2] - killLadder[2]))

    -- GH #311 predicted from the rank ladder alone that the domain would "move
    -- forward to hero level 5".  It does not, and the reason is that the rank
    -- ladder is only half of the domain -- the dot duration is the other half.
    -- Rank 2 at a 2s dot (hero 5-9) STILL narrows, and by more than rank 1 does:
    -- 235.2 - 180 = 55.2 against 48.  What arming wkbuild actually removes is the
    -- TOP of the domain: rank 2 meets the t10 talent at hero 10 instead of 13.
    for nHeroLevel = 5, 9 do
        local n = narrowing_at_hero_level(killLadder, nHeroLevel)
        assert(math.abs(n - 55.2) < 1e-9,
            'with wkbuild armed, hero level ' .. nHeroLevel .. ' withdraws 55.2, got '
            .. tostring(n) .. ' -- this band is INSIDE the domain, not outside it')
        assert(n > narrowing_at_hero_level(shippedLadder, nHeroLevel),
            'and it withdraws MORE there than the shipped row does')
    end
    for nHeroLevel = 10, 12 do
        assert(narrowing_at_hero_level(killLadder, nHeroLevel) == 0,
            'with wkbuild armed, hero level ' .. nHeroLevel .. ' is already a no-op')
        assert(narrowing_at_hero_level(shippedLadder, nHeroLevel) > 0,
            'while under the shipped row the same level still withdraws 8')
    end

    -- So the two candidates are not independent: armed together, wkqdmg is
    -- measured on a strictly earlier and differently-weighted population than
    -- the one its own frames and its 66.7% corpus figure describe.
    local function span(ladder)
        local n = 0
        for lv = 1, 25 do
            local w = narrowing_at_hero_level(ladder, lv)
            if w ~= nil and w > 0 then n = n + 1 end
        end
        return n
    end
    assert(span(shippedLadder) == 11, 'shipped row: hero 2-12 act, got ' .. span(shippedLadder))
    assert(span(killLadder) == 8, 'kill row: hero 2-9 act, got ' .. span(killLadder))

    -- The gate really is the thing that chooses between them.
    assert(src:find('J.IsSoakCandidate%(%s*\'wkbuild\'%s*%)'),
        'hero_skeleton_king.lua no longer selects its build row on the wkbuild gate; '
        .. 'the conditional above is then not conditional on anything')
end

-- --------------------------------------------------------- 6. the text ratchet

tests['[hero] wkqdmg domain 6: the reversed wording may not come back (GH #311)'] = function()
    assert(not src:find('OPENS'),
        'hero_skeleton_king.lua says the gap OPENS again.  Under the shipped row '
        .. 'the t10 talent narrows it 48 -> 8 (section 3); see GH #311.')
    -- Scoped to the TALENT TABLE ROW, not to the whole file: prose that explains
    -- why the slow half is dead necessarily contains the words "slow duration",
    -- and a ratchet that forbids the token forbids its own correction too (the
    -- shape section 6 tripped over on the way in).
    local sRow = src:match('%[2%] special_bonus_unique_wraith_king_facet_1([^\n]*)')
    assert(sRow, 'the talent table no longer has a [2] special_bonus_..._facet_1 row')
    assert(not sRow:lower():find('slow'),
        'talent table row [2] points at the slow duration again ("' .. sRow:gsub('^%s+', '')
        .. '").  That half of the KV is DEAD (settled in the facet block of the same '
        .. 'file); the surviving half is blast_dot_duration +2, which is all of this '
        .. 'lever\'s t10 arithmetic.')
    assert(sRow:find('blast_dot_duration %+2'),
        'talent table row [2] should name the surviving half explicitly, got "'
        .. sRow:gsub('^%s+', '') .. '"')
    assert(src:find('hero level 13'),
        'the domain note should say where the lever stops, in hero levels')
end

return tests

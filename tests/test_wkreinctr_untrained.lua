-- [wkreinctr] The retreat mode is switched off for a Wraith King on the
-- strength of an ultimate he has no skill point in.
--
-- WHAT THIS FILE ASSERTS
-- ----------------------
-- J.IsWkReincarnationArmed (bots/FunLib/jmz_func.lua) is SHIPPED, and its one
-- caller -- mode_retreat_generic.lua ~:198, also SHIPPED and un-gated -- spends
-- its answer on `return BOT_MODE_DESIRE_NONE`: the WHOLE retreat mode goes to
-- zero for that frame, above the entire guard chain. "Stand and fight, the ult
-- is my safety net."
--
-- The helper decides that on two engine reads and neither is the one that
-- matters:
--
--   * `abilityR:GetCooldownTimeRemaining() > 1.0`  -- a level-0 ability is not
--     on cooldown, so this answers 0.0 for an ultimate nobody has learned;
--   * `bot:GetMana() >= 160`                        -- true for a Wraith King
--     from the first minute.
--
-- `bot:GetAbilityByName` returns a live handle for an unlearned ability, so
-- BOTH pass and the helper says ARMED. Measured on the corpus: 24 of the 36
-- live Wraith King frames answer TRUE, and 14 of those 24 -- 58% of every TRUE
-- this function produces -- sit on a Reincarnation at ability level 0. Two of
-- the 14 are at HERO level 7, which is the other thing the call site checks,
-- and which says nothing about where the skill points went.
--
-- THE TREE ALREADY KNEW, EIGHT LINES FROM THE CALL SITE. mode_retreat_generic's
-- huskar block, in the same GetDesireHelper, reads
-- `bot:GetAbilityByName('huskar_berserkers_blood')` and then asks
-- `hAbility:IsTrained()` before believing it. So does 'axeblink'. This line was
-- never brought along. 'wkreinctr' adds exactly that conjunct, gated and
-- turbo-only.
--
-- ⭐ WHAT THIS FILE IS CAREFUL ABOUT, because the honest reading has TWO
-- columns and one of them is a zero. The lever's flip set at the HELPER is 14
-- real frames. At the CALL SITE it is 0, because `J.IsInTeamFight(bot, 1200)`
-- is false on all 36 WK frames this corpus holds -- none of them has two allies
-- inside 1200. That is a fact about a corpus cut for the owner-priority-P2
-- home-TP investigation, not about the lever, and section 3 asserts BOTH
-- numbers so neither can be quoted as the other. A single-arm wave that reads
-- zero on this lever must read it as "the domain was not reached", never as
-- "tested, no effect" (GH #576).

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')

local PIN = 'tests/fixtures/f_073148_zuus_lina.lua'
local WK = 'npc_dota_hero_skeleton_king'

local tests = {}

--- Load the pinned frame and hand back a driver that answers the SHIPPED
--- helper under a supplied J.IsSoakCandidate. Nothing here re-implements the
--- decision: every answer comes out of J.IsWkReincarnationArmed itself.
local function driver()
    local J, bot = rf.load(PIN, WK)
    local function answer(fGate)
        J.IsSoakCandidate = fGate or function() return false end
        return J.IsWkReincarnationArmed(bot) and true or false
    end
    return J, bot, answer
end

local function only(sWanted)
    return function(sId) return sId == sWanted end
end

-- ==========================================================================
-- 1. The pinned frame, driven
-- ==========================================================================

tests['[frame] the pinned frame is a level-7 WK with an unlearned ultimate'] = function()
    local J, bot = driver()
    local nLv = bot:GetLevel()
    assert(nLv == 7, 'the pinned Wraith King is now hero level ' .. tostring(nLv)
        .. ', not 7 -- the whole point of this frame is that it clears the call '
        .. 'site\'s own `bot:GetLevel() >= 6` guard while the ultimate is still '
        .. 'unlearned')
    local hR = bot:GetAbilityByName('skeleton_king_reincarnation')
    assert(hR ~= nil, 'the engine no longer hands back a handle for an '
        .. 'unlearned ability -- if that is now a nil, the shipped `abilityR == '
        .. 'nil` guard already covers this case and the lever is unnecessary')
    assert(hR:GetLevel() == 0, 'the pinned Reincarnation is now at ability '
        .. 'level ' .. tostring(hR:GetLevel()) .. ', not 0')
    assert(hR:IsTrained() == false, 'IsTrained() no longer reports an unlearned '
        .. 'ability as untrained; this lever reads nothing else')
    assert(hR:GetCooldownTimeRemaining() <= 1.0,
        'the unlearned ultimate now reports a cooldown, which would mean the '
        .. 'shipped guard above already refuses this frame')
    assert(bot:GetMana() >= 160, 'the pinned WK is now below the shipped '
        .. '160-mana threshold, so the shipped read would refuse this frame for '
        .. 'a reason that has nothing to do with this lever')
end

tests['[frame] shipped says ARMED, this lever says no'] = function()
    local _, _, answer = driver()
    assert(answer(nil) == true,
        'the SHIPPED helper no longer calls an unlearned Reincarnation armed on '
        .. 'the pinned frame -- the defect this lever exists for is gone, and '
        .. 'the lever should be removed rather than kept green')
    assert(answer(only('wkreinctr')) == false,
        'armed, the lever still calls an unlearned Reincarnation armed')
end

tests['[frame] un-armed is byte-identical, and no OTHER id moves this frame'] = function()
    local _, _, answer = driver()
    -- The gate is the first conjunct, so un-armed neither J.IsModeTurbo nor the
    -- engine's IsTrained() is reached. Re-reading the shipped answer after the
    -- armed call also catches a lever that mutates state.
    assert(answer(nil) == true, 'the shipped answer moved between calls')
    -- Every other id live on this helper, and the two the sibling sweeps arm.
    -- A frame that another id can flip cannot be attributed to this one.
    for _, sOther in ipairs({ 'wkreincarnmp', 'c2', 'c4', 'stayfield', 'stayattr' }) do
        assert(answer(only(sOther)) == true,
            'arming \'' .. sOther .. '\' alone also moves this frame, so a wave '
            .. 'carrying it cannot attribute the flip to \'wkreinctr\'')
    end
    -- Arming EVERYTHING must still land on the lever's answer here: this frame
    -- is inside this lever's domain and outside every sibling's.
    assert(answer(function() return true end) == false,
        'with every id armed the pinned frame no longer reads false')
end

-- ==========================================================================
-- 2. The tree, read structurally
-- ==========================================================================

local function read_file(path)
    local f = assert(io.open(path, 'r'), path .. ' is not readable')
    local s = f:read('*a')
    f:close()
    return s
end

-- Structural facts are claims about CODE. The lever ships with a long comment
-- quoting the call site, the huskar block and both id names, so reading the raw
-- block would let the COMMENT satisfy these assertions (the §EN mistake).
local function strip_comments(s) return (s:gsub('%-%-[^\n]*', '')) end

tests['[tree] the gate is standalone, turbo-explicit and first'] = function()
    local src = strip_comments(read_file('bots/FunLib/jmz_func.lua'))
    local at = assert(src:find('function J.IsWkReincarnationArmed( bot )', 1, true),
        'J.IsWkReincarnationArmed was renamed or removed')
    local blk = src:sub(at, (src:find('\nfunction ', at + 40)) or #src)
    local a = assert(blk:find("IsSoakCandidate( 'wkreinctr' )", 1, true),
        'the wkreinctr gate is gone from J.IsWkReincarnationArmed')
    local b = assert(blk:find('IsModeTurbo()', 1, true),
        'the turbo conjunct is gone; neither this helper nor its call site asks '
        .. 'turbo above it, so it cannot be dropped as structural')
    local c = assert(blk:find('abilityR:IsTrained()', 1, true),
        'the IsTrained() read is gone')
    assert(a < b and b < c,
        'the gate is no longer the first conjunct of its condition; un-armed '
        .. 'evaluation is then no longer byte-identical to shipped')
    -- The 'pullcad' trap is TWO IDS IN ONE CONDITION. This helper holds two ids
    -- legitimately, on two SEPARATE statements -- the invariant is that they are
    -- separated by the early `return false`, not that there is only one.
    local b2 = assert(blk:find("IsSoakCandidate( 'wkreincarnmp' )", 1, true),
        'the sibling wkreincarnmp gate is gone')
    assert(a < b2, 'wkreinctr no longer precedes wkreincarnmp; the early return '
        .. 'is what makes the two independently sufficient')
    assert(blk:sub(a, b2):find('%f[%w]return%f[%W]%s+false'),
        'the two gates are no longer separated by an early `return false`; if '
        .. 'they have been merged into one condition this is the pullcad trap')
    local n = 0
    for _ in blk:gmatch('IsSoakCandidate') do n = n + 1 end
    assert(n == 2, 'this helper now names ' .. n .. ' candidate ids, not 2; a '
        .. 'third one needs its own reading of the nesting census row')
end

tests['[tree] the call site is shipped, and its two extra guards are real'] = function()
    local ret = strip_comments(read_file('bots/mode_retreat_generic.lua'))
    assert(ret:find('J.IsWkReincarnationArmed(bot)', 1, true),
        'mode_retreat_generic no longer calls this helper -- with no caller the '
        .. 'lever changes nothing and should be removed')
    assert(ret:find('bot:GetLevel() >= 6', 1, true),
        'the call site\'s hero-level guard moved; the 14-to-2 narrowing this '
        .. 'file reports is computed from it')
    assert(ret:find('J.IsInTeamFight(bot, 1200)', 1, true),
        'the call site\'s team-fight guard moved; the 2-to-0 narrowing this '
        .. 'file reports is computed from it')
    assert(ret:find('BOT_MODE_DESIRE_NONE', 1, true),
        'the call site no longer answers NONE -- the cost of a wrong ARMED was '
        .. 'the whole retreat mode, and that is what makes this worth a lever')
    -- ⭐ CONDITION (c) IS A COUNT OF SITES, NOT A PRESENCE FLAG. The argument is
    -- "this tree asks IsTrained() before believing a GetAbilityByName handle,
    -- including inside this very function"; a flag reads the same whether that
    -- happens once or thirty times, and the 'stayurn' round's M6 survivor is
    -- exactly what a presence flag costs.
    local n = 0
    for _ in ret:gmatch('IsTrained%(%)') do n = n + 1 end
    assert(n == 2, 'mode_retreat_generic now asks IsTrained() at ' .. n
        .. ' sites, not 2 -- the condition-(c) argument is that the SAME file '
        .. 'already guards a GetAbilityByName handle this way')
    assert(ret:find("bot:GetAbilityByName('huskar_berserkers_blood')", 1, true)
        and ret:find('hAbility:IsTrained()', 1, true),
        'the huskar block that pairs GetAbilityByName with IsTrained() in this '
        .. 'same function is gone; it is the nearest instance of the pattern')
end

-- ==========================================================================
-- 3. The corpus, through the subprocess sweep
-- ==========================================================================

-- Memoised: the sweep rebuilds jmz_func once per hero-frame and costs minutes.
-- Several bodies read it and a mutation stand runs the whole file a dozen
-- times; the sweep is a pure function of the tree and the tree does not change
-- inside one process.
local sweep_cache = nil
local function sweep()
    if sweep_cache ~= nil then return unpack(sweep_cache) end
    local p = assert(io.popen('lua5.1 tests/_wkreinctr_sweep.lua 2>/dev/null'))
    local s = p:read('*a')
    p:close()
    assert(s:find('\nDONE', 1, true) or s:find('^DONE'),
        'tests/_wkreinctr_sweep.lua did not reach its DONE line -- the '
        .. 'subprocess failed, and a truncated manifest must never be read as a '
        .. 'small measurement')
    local G, C, F, W, S = {}, {}, {}, {}, {}
    for line in s:gmatch('[^\n]+') do
        local k, v = line:match('^G (%S+) (%S+)$')
        if k then G[k] = tonumber(v) or v end
        local ck, cv = line:match('^C (%S+) (%-?%d+)$')
        if ck then C[ck] = tonumber(cv) end
        if line:match('^F ') then F[#F + 1] = line end
        if line:match('^W ') then W[#W + 1] = line end
        if line:match('^S ') then S[#S + 1] = line end
    end
    sweep_cache = { G, C, F, W, S }
    return G, C, F, W, S
end

tests['[corpus] the sweep drives the real corpus and lands 14 helper flips'] = function()
    local G, C, F = sweep()
    assert(C.live == 1012, 'the corpus is now ' .. tostring(C.live)
        .. ' live hero frames, not 1012 -- every number below is against a '
        .. 'different denominator')
    assert(C.fixtures == 109, 'the corpus is now ' .. tostring(C.fixtures)
        .. ' fixtures, not 109')
    assert(C.raises == 0, tostring(C.raises) .. ' frame(s) raised inside the '
        .. 'driven helper; a raise is not a FALSE')
    assert(C.arm_leak == 0, 'the sweep armed more than one id, so its flips '
        .. 'cannot be attributed to \'wkreinctr\'')
    assert(G.FN_SOAKID == 1 and G.FN_TURBO == 1 and G.FN_ISTRAINED == 1
        and G.FN_GATE_FIRST == 1 and G.FN_GATE_ORDER == 1
        and G.FN_EARLY_RETURN == 1 and G.FN_NIDS == 2,
        'the structural facts the sweep parses out of the helper moved')
    assert(G.FILES_NAMING_HELPER == 2,
        tostring(G.FILES_NAMING_HELPER) .. ' files under bots/ name this helper, '
        .. 'not 2 (its definition and its one caller) -- a second caller changes '
        .. 'what the call-site column below means')
    assert(C.wk_frames == 36, 'the corpus now holds ' .. tostring(C.wk_frames)
        .. ' live Wraith King frames, not 36')
    assert(C.ship_true == 24 and C.arm_true == 10,
        'the shipped/armed TRUE counts moved: ship=' .. tostring(C.ship_true)
        .. ' arm=' .. tostring(C.arm_true))
    assert(C.flips == 14, 'the helper flip count moved to ' .. tostring(C.flips)
        .. ', not 14')
    assert(C.ship_true - C.arm_true == C.flips,
        'the two TRUE counts and the flip count no longer reconcile')
    assert(#F == C.flips, 'the sweep emitted ' .. #F .. ' flip rows for '
        .. C.flips .. ' flips')
end

tests['[corpus] direction is fixed, through a counter proved to count'] = function()
    local _, C = sweep()
    -- This lever prepends a veto, so it can only turn TRUE into FALSE.
    assert(C.flip_false_to_true == 0, tostring(C.flip_false_to_true)
        .. ' frame(s) went FALSE -> TRUE; this lever is a veto and cannot')
    -- ⛔ AND THE ZERO IS PROVED TO BE A MEASUREMENT. The same `tally` called
    -- with the legs swapped must report the WHOLE domain on the branch that
    -- reads 0 above, so deleting either bump moves the manifest instead of
    -- leaving it byte-identical (the M14 lesson of the 'staytower' round).
    assert(C.flip_false_to_true_swapped == C.flips and C.flips_swapped == 0,
        'the swapped tally does not mirror the real one (swapped_up='
        .. tostring(C.flip_false_to_true_swapped) .. ' flips='
        .. tostring(C.flips) .. ' swapped_down=' .. tostring(C.flips_swapped)
        .. '); the zero above cannot be read as a direction check')
end

tests['[corpus] the anti-vacuum walk: every WK frame names its stop'] = function()
    local _, C, _, W = sweep()
    local nSum = C.stop_cd + C.stop_untrained + C.stop_mana + C.stop_armed
    assert(nSum == C.wk_frames, 'the stop buckets sum to ' .. nSum
        .. ' but there are ' .. C.wk_frames .. ' WK frames')
    assert(#W == C.wk_frames, 'the sweep emitted ' .. #W .. ' WK rows for '
        .. C.wk_frames .. ' frames')
    assert(C.stop_cd == 11 and C.stop_untrained == 15 and C.stop_mana == 0
        and C.stop_armed == 10,
        'the WK breakdown moved: cd=' .. C.stop_cd .. ' untrained='
        .. C.stop_untrained .. ' mana=' .. C.stop_mana .. ' armed='
        .. C.stop_armed)
    -- 15 untrained frames but only 14 flips: one untrained WK is already
    -- refused by the shipped mana term. Stated as arithmetic so "the corpus has
    -- no untrained ults" can never read the same as "it has them and something
    -- above rejects them first".
    assert(C.untrained_frames == 15 and C.untrained_frames - C.flips == 1,
        'the untrained/flip gap moved: untrained=' .. C.untrained_frames
        .. ' flips=' .. C.flips)
end

tests['[corpus] the CALL SITE column is zero, and that is a corpus fact'] = function()
    local _, C, _, _, S = sweep()
    -- ⭐ THE TWO COLUMNS. 14 at the helper; the call site's own two conjuncts
    -- cut it to 2 by hero level and then to 0 by the team-fight read. Both are
    -- asserted so neither can stand in for the other.
    assert(C.wk_lv6 == 23, 'WK frames at hero level >= 6 moved to '
        .. tostring(C.wk_lv6))
    assert(C.ship_true_untrained_lv6 == 2,
        'the level-6 narrowing moved to ' .. tostring(C.ship_true_untrained_lv6)
        .. ', not 2')
    assert(C.fight_true == 0,
        'J.IsInTeamFight(bot, 1200) now answers TRUE on ' .. tostring(C.fight_true)
        .. ' WK frame(s). It answered on none, which is why the call-site flip '
        .. 'count below is 0; if that has changed, the 0 must be re-derived '
        .. 'rather than kept')
    assert(C.site_ship_true == 0 and C.site_arm_true == 0 and C.site_flips == 0
        and #S == 0,
        'the call-site column moved off zero; re-read it before quoting the '
        .. 'helper column')
    -- ⛔ AND THE ZERO IS LABELLED. A single-arm wave reading zero on this lever
    -- is reading "the domain was not reached on this corpus", never "tested, no
    -- effect" (GH #576). The mock cannot filter GetNearbyHeroes by bot mode, so
    -- its IsInTeamFight OVER-counts attack-mode allies: the zero is read from
    -- the permissive side and the live reachable set is <= it, never more.
    assert(C.site_flips <= C.flips,
        'the call site reports more flips than the helper it calls')
end

tests['[corpus] the sibling id on this helper cannot claim these flips'] = function()
    local _, C = sweep()
    -- Two independently sufficient tests on ONE helper is the shape where
    -- arming one measures a correct ZERO wherever the other also fires (the
    -- 'staysrc'/'staytower' lesson). Measured, not argued.
    assert(C.pair_ne_arm == 1, 'the both-armed answer now differs from this '
        .. 'lever\'s single arm on ' .. tostring(C.pair_ne_arm) .. ' frame(s), '
        .. 'not 1 -- that one belongs to \'wkreincarnmp\' (it swaps the shipped '
        .. '160 for the real, higher level-1 trigger cost)')
    assert(C.pair_ne_arm_in_flipset == 0,
        tostring(C.pair_ne_arm_in_flipset) .. ' of this lever\'s own flip frames '
        .. 'are decided by the sibling instead, so a single-arm wave could not '
        .. 'attribute them')
    -- ⛔ AND THAT ZERO IS PROVED TO BE A MEASUREMENT. Its first version was a
    -- bare `if shipped and not arm then bump(...) end` asserted == 0, and the
    -- mutation stand's M15 walked straight through it: deleting the bump leaves
    -- a zero that reads exactly like a measured one (the GH #171 shape, landing
    -- on this lever's own pair column). Both halves now go through ONE bump, so
    -- the branch that must read 0 is the branch that must report the whole set
    -- on the other side, and the sum reconciles with the total.
    assert(C.pair_ne_arm_out_flipset == 1,
        'the complement of the in-flipset counter reads '
        .. tostring(C.pair_ne_arm_out_flipset) .. ', not 1; without it the zero '
        .. 'above cannot tell "measured" from "never bumped"')
    assert(C.pair_ne_arm_in_flipset + C.pair_ne_arm_out_flipset == C.pair_ne_arm,
        'the two pair buckets sum to '
        .. tostring(C.pair_ne_arm_in_flipset + C.pair_ne_arm_out_flipset)
        .. ' but pair_ne_arm is ' .. tostring(C.pair_ne_arm))
end

return tests

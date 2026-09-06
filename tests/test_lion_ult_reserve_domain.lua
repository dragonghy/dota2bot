-- [ratchet] [hero] `lionult` re-measured on the director's own revival
-- condition -- which has fired, and which the re-measurement contradicts.
--
-- BACKGROUND.  GH #73 asked for a Lion ult-mana reserve mirroring
-- X.zuus_ShouldSaveManaForUlt: hold Impale/Hex when spending one would drop
-- Lion below Finger of Death's cost.  The 2026-08-20T21:51Z pre-flight measured
-- its domain EMPTY -- 1216 frames with Finger trained and off cooldown, zero
-- below cost, zero in the post-spend band [cost, cost + spend) -- and the lever
-- was struck.  The director's 23:00Z ruling accepted that, but refused to let
-- the emptiness be recorded unconditionally, and wrote a revival condition
-- (GH #73 comment 5363066650, section 1), quoted in full because this file
-- exists to answer it:
--
--     "正确的记法是「在 Finger level 1 上域为空」,而不是「`lionult` 的域为空」。
--      Finger 的 cost 是 [200, 400, 600],本轮语料里它恒在 level 1 ... cost=400
--      那条线,对着 380 的蓝池底不是空的。复活条件:哪天 turbo 局能稳定到 hero
--      level 12+ ... 那时 lever(a) 要重量一次,不能直接引用本轮的 0/1216。"
--
-- Two things have since happened.  (1) The repository acquired its first
-- live-Lion instant above hero level 11 -- tests/frames/f_20260831_004433_cm_
-- creepreach.lua, t=1190.4, Lion at level 20 with Finger at RANK 2 -- so the
-- cost=400 line the ruling names is, for the first time, on a real frame.
-- (2) 2026-09-01 repaired the fixture world's mana meter (tests/mock/
-- replay_fixture.lua, mana_ladder): before it, `GetManaCost` answered 0 for
-- every ability on every frame, so the band [cost, cost + spend) was [0, 0) --
-- EMPTY BY CONSTRUCTION -- and `mp >= cost` was `mp >= 0`, a tautology.  The
-- predicate this file evaluates could not be evaluated at all until then.
--
-- ===========================================================================
-- THE READING
-- ===========================================================================
--
-- Every live-Lion instant in the archive, driven through the real loader with
-- the repaired meter.  Each stage is the previous stage's subset:
--
--     live-Lion instants ................................ 24
--     ... Finger trained (rank >= 1) .................... 13
--     ... and off cooldown .............................. 3
--     ... and mp >= Finger's cost ....................... 3
--     ... and mp <  cost + cheapest castable basic ...... 0   <- the domain
--
-- The binding constraint is NOT mana.  It is COOLDOWN: 10 of the 13 trained
-- instants have Finger down (observed remaining 1.2s .. 108.6s against a
-- level-1 cooldown of 110s), so the archive is dominated by post-cast frames.
-- Of the three that survive, one has no castable basic at all (both Impale and
-- Hex on cooldown) and two are far above the band.
--
-- ===========================================================================
-- WHY THE REVIVAL CONDITION DOES NOT REVIVE THE LEVER -- CLOSED FORM
-- ===========================================================================
--
-- The ruling's arithmetic is "cost 200 -> 400 while the pool bottom stays at
-- 380".  Levels move BOTH sides, and they do not move them at the same rate:
--
--   * The band's WIDTH is the cheapest basic Lion can cast.  Impale's mana
--     ladder is {90, 110, 130, 150} and Hex's is {110, 140, 170, 200}, so the
--     cheapest basic is Impale, and Impale's cost is FROZEN at 150 from rank 4
--     onward -- reached around hero level 7.  The band can never be wider than
--     150 mana, at any hero level, at any Finger rank.
--   * The pool keeps growing.  Observed max_mp runs 387 (level 1) -> 708
--     (level 8) -> 1158 (level 11) -> 1551 (level 20).
--
-- So the band's share of the pool is 150/max_mp, STRICTLY DECREASING in the
-- pool, and the target the reserve has to hit shrinks as Lion levels:
--
--     hero level  8, Finger rank 1: band [200, 350), 150/708  = 21.2% of pool
--     hero level 20, Finger rank 2: band [400, 550), 150/1551 =  9.7% of pool
--
-- Leveling makes this lever's domain SMALLER, not larger.  That is the reverse
-- of what the revival condition predicts, and it needs no further corpus: it
-- follows from Impale's ladder ending at 150 while the pool does not end.
--
-- The ruling's own quantity is the sharpest way to see it.  It reasoned that
-- 400 would bite because the pool bottom was 380.  On the frame where the cost
-- is actually 400, the pool is 1551 -- 4.08x the assumed bottom.
--
-- ===========================================================================
-- HONEST BOUNDS -- load-bearing, quote these with any number above
-- ===========================================================================
--
-- (A) n = 1 AT FINGER RANK 2.  The 380 in the ruling was a MINIMUM OVER ~500
--     FRAMES per game across 1216; the 1551 here is a minimum over ONE
--     instant, and it happens to be a full-mana one.  These are not the same
--     estimator and 1551 must never be quoted as "the rank-2 pool bottom".
--     What IS robust at n=1 is the closed-form band-width argument above,
--     which reads no frame's mana at all -- only the two ability ladders and
--     the pool, both of which are KV facts.  The DOMAIN question at rank 2 is
--     supply-starved, not answered; section 5 is the ratchet that forces a
--     re-read when the archive gains more rank-2 Lions.
-- (B) FINGER RANK 3 (cost 600) IS ENTIRELY UNMEASURED -- zero instants.
-- (C) "稳定到 hero level 12+" IS NOT ESTABLISHED.  One frame exists above
--     level 11.  The revival condition has begun to fire, not finished.
-- (D) The mana prices come from tests/mock/special_value_shapes.lua, a KV
--     snapshot of the FIVE FOCUS HEROES only.  Lion is in it.  They agree with
--     the independent datafeed read recorded in GH #73's body
--     (`lion_finger_of_death` AbilityManaCost = [200, 400, 600]) -- two
--     sources, eleven days apart, same ladder.  Section 4 asserts that
--     agreement rather than asserting either source alone.
-- (E) THE FRAME IS STAGED, NOT ADMITTED.  f_20260831_004433_cm_creepreach.lua
--     lives in tests/frames/, and this file reads it BY NAME.  Admitting it to
--     tests/fixtures/ moves census readings belonging to other levers (GH
--     #357); nothing here does that.
--
-- Zero behaviour change: no gate, no new candidate id, no bots/ edit beyond a
-- comment correction in hero_lion.lua's SkillsComplement, whose text asserted
-- a corpus fact ("None of the 6 Lion frames") that is four times out of date.

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')
local shapes = require('mock.special_value_shapes')

local UNIT       = 'npc_dota_hero_lion'
local FINGER     = 'lion_finger_of_death'
local IMPALE     = 'lion_impale'
local HEX        = 'lion_voodoo'
local FIXTURE_DIR = 'tests/fixtures'
local STAGED_DIR  = 'tests/frames'
local RANK2_FRAME = 'tests/frames/f_20260831_004433_cm_creepreach.lua'

-- The ruling's assumed pool bottom at the moment cost reaches 400.
local RULING_ASSUMED_POOL_BOTTOM = 380
local RULING_RANK2_COST          = 400

-- ---------------------------------------------------------------- enumeration

--- Every corpus file, from BOTH directories, enumerated -- never a hardcoded
--- path.  tests/frames/ was created on 2026-08-31 and a sister file's "whole
--- archive" sweep, written as a glob over tests/fixtures/ plus one literal
--- path, silently stopped being exhaustive the same day and stayed green for
--- three days (hero backlog -66).  Enumerating is what makes a third directory
--- cost an edit here instead of a silent undercount.
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
        assert(n > 0, 'corpus directory ' .. dir .. ' yielded no f_*.lua frame. '
            .. 'An empty enumerator and an empty corpus are the same integer; '
            .. 'this assertion is the only thing that tells them apart.')
    end
    table.sort(out)
    return out
end

--- Every live-Lion instant, with the loader's real answers on it.
--- Returns a list of records and the number of files scanned.
local function lion_instants()
    local rows, nFiles = {}, 0
    for _, path in ipairs(corpus_paths()) do
        nFiles = nFiles + 1
        local ok, chunk = pcall(dofile, path)
        if ok and type(chunk) == 'table' then
            local present = false
            for _, u in ipairs(chunk.units or {}) do
                if u.name == UNIT and u.alive ~= false then present = true end
            end
            if present then
                local _, bot = rf.load(path, UNIT)
                local function ask(name)
                    local h = bot:GetAbilityByName(name)
                    if h == nil then return 0, 0, 0 end
                    return h:GetLevel() or 0, h:GetCooldownTimeRemaining() or 0,
                        h:GetManaCost() or 0
                end
                local rRank, rCd, rCost = ask(FINGER)
                local qRank, qCd, qCost = ask(IMPALE)
                local wRank, wCd, wCost = ask(HEX)
                local spend
                if qRank > 0 and qCd <= 0 and qCost > 0 then spend = qCost end
                if wRank > 0 and wCd <= 0 and wCost > 0 then
                    if spend == nil or wCost < spend then spend = wCost end
                end
                rows[#rows + 1] = {
                    path = path, time = chunk.time,
                    mp = bot:GetMana() or 0, maxMp = bot:GetMaxMana() or 0,
                    rRank = rRank, rCd = rCd, rCost = rCost, spend = spend,
                }
            end
        end
    end
    return rows, nFiles
end

--- The funnel, bucketed so that the buckets are EXHAUSTIVE and disjoint --
--- section 1 asserts they re-sum to the total, which is what stops a silently
--- dropped record from reading as a smaller domain.
local function funnel()
    local rows = lion_instants()
    local t = { live = #rows, trained = 0, ready = 0, afford = 0, inWindow = 0,
                untrained = 0, onCd = 0, tooPoor = 0, noBasic = 0, above = 0,
                window = {} }
    for _, r in ipairs(rows) do
        if r.rRank < 1 then t.untrained = t.untrained + 1
        else
            t.trained = t.trained + 1
            if r.rCd > 0 then t.onCd = t.onCd + 1
            else
                t.ready = t.ready + 1
                if r.mp < r.rCost then t.tooPoor = t.tooPoor + 1
                else
                    t.afford = t.afford + 1
                    if r.spend == nil then t.noBasic = t.noBasic + 1
                    elseif r.mp < r.rCost + r.spend then
                        t.inWindow = t.inWindow + 1
                        t.window[#t.window + 1] = r
                    else t.above = t.above + 1 end
                end
            end
        end
    end
    return t, rows
end

--- One ability's mana ladder, straight out of the KV snapshot.
local function ladder(ability)
    local abils = assert(shapes.SHAPES['lion'],
        'tests/mock/special_value_shapes.lua no longer carries a lion block, so '
        .. 'every mana price in this file is the generic 0 again and every '
        .. 'reading below is measuring a tautology')
    local entry = assert(abils[ability], 'no KV block for ' .. ability)
    local mc = assert(entry['AbilityManaCost'],
        ability .. ' no longer carries AbilityManaCost')
    local steps = {}
    for tok in mc.base:gmatch('%S+') do steps[#steps + 1] = assert(tonumber(tok)) end
    assert(#steps > 0, ability .. ' has an empty mana ladder')
    return steps
end

local tests = {}

-- ------------------------------------------------------------------ section 1

tests['[hero] lionult: the funnel is exhaustive and its buckets re-sum'] = function()
    local t = funnel()
    assert(t.live > 0,
        'no live-Lion instant in the corpus at all. Every count below would be '
        .. 'zero for want of a Lion, not for want of a domain -- the two zeros '
        .. 'are the same integer and this is what separates them.')
    assert(t.untrained + t.trained == t.live,
        'trained/untrained do not re-sum to the ' .. t.live .. ' live instants')
    assert(t.onCd + t.ready == t.trained,
        'cooldown split does not re-sum to the ' .. t.trained .. ' trained instants')
    assert(t.tooPoor + t.afford == t.ready,
        'affordability split does not re-sum to the ' .. t.ready .. ' ready instants')
    assert(t.noBasic + t.inWindow + t.above == t.afford,
        'band split does not re-sum to the ' .. t.afford .. ' affordable instants')
end

tests['[hero] lionult: the domain is empty, and cooldown is what closes it'] = function()
    local t, rows = funnel()
    -- THE ZERO BELOW IS ONLY A READING IF THE METER IS CHARGING.  Found on the
    -- mutation stand: with mana_ladder regressed to nil (the pre-2026-09-01
    -- world), every cost is 0, so `mp >= cost` is a tautology, `spend` is nil
    -- on every instant, and inWindow is 0 -- for want of a PRICE, not for want
    -- of a domain.  Every other assertion in this case stayed GREEN under that
    -- mutant.  This is the guard that makes the two zeros different integers.
    local nPriced = 0
    for _, r in ipairs(rows) do if r.rCost > 0 then nPriced = nPriced + 1 end end
    assert(nPriced == t.live,
        'only ' .. nPriced .. ' of ' .. t.live .. ' live-Lion instants get a '
        .. 'real Finger price out of the loader. The mana meter has regressed '
        .. 'to the free-mana world, and the empty domain below is an artefact '
        .. 'of the price being 0, not a fact about Lion.')
    assert(t.inWindow == 0,
        t.inWindow .. ' corpus instant(s) now sit in [cost, cost + cheapest '
        .. 'basic) with Finger ready. THE DOMAIN THAT GH #73 STRUCK IS NO '
        .. 'LONGER EMPTY. Build the fixture on one of them, re-read this whole '
        .. 'file, and take the `lionult` question back to the director -- the '
        .. '2026-08-20T23:00Z ruling struck the lever ON the emptiness, so the '
        .. 'emptiness ending is exactly the event it asked to be told about.')
    -- The point of this case is not the zero; it is WHICH clause produces it.
    -- "Mana was never the binding constraint" is the claim, and it is only
    -- worth anything if the constraint that IS binding is named and counted.
    assert(t.tooPoor == 0,
        t.tooPoor .. ' instant(s) hold Finger ready but cannot afford it. Mana '
        .. 'has become a binding constraint on this hero for the first time; '
        .. 'the "not mana" half of the GH #73 verdict is the part to re-take.')
    assert(t.onCd > t.ready,
        'cooldown no longer removes more Finger instants (' .. t.onCd .. ') '
        .. 'than survive it (' .. t.ready .. '). The reading that the archive '
        .. 'is dominated by post-cast frames has stopped holding, and the '
        .. 'window-supply diagnosis in GH #73 section 2.3 rests on it.')
end

-- ------------------------------------------------------------------ section 2

-- ⚠️ 2026-09-06 (hero, GH #566): the corpus grew a late-game Lion frame --
-- tests/fixtures/f_260905_004847_lion_drain_bkb.lua, t=1266.5, Lion level 24,
-- Finger at RANK 3 -- and these two cases fired exactly as written.  They were
-- ACKNOWLEDGED, NOT RE-TAKEN: the round that added the frame was withdrawing
-- `liondrainbkb`, not re-measuring `lionult`.  So the split below is by EXACT
-- rank, which keeps every reading in this file scoped to the corpus it was
-- taken on (one rank-2 instant, cost 400), and the rank-3 case keeps its own
-- count as a live wire.  Everything below section 2 is still a pre-2026-09-06
-- reading and must not be quoted as covering rank 3.
tests['[hero] lionult: the revival condition has fired -- rank 2 exists'] = function()
    local _, rows = funnel()
    local nRank2, nAboveEleven = 0, 0
    local rank2
    for _, r in ipairs(rows) do
        if r.rRank == 2 then nRank2 = nRank2 + 1; rank2 = rank2 or r end
    end
    for _, r in ipairs(rows) do
        if r.rCost >= RULING_RANK2_COST then nAboveEleven = nAboveEleven + 1 end
    end
    assert(nRank2 >= 1,
        'no live-Lion instant carries Finger at rank >= 2 any more. The '
        .. 'revival condition of the GH #73 ruling is un-fired again and this '
        .. 'whole file is back to being a level-1 reading.')
    assert(rank2.rCost == RULING_RANK2_COST,
        'the rank-2 Finger on ' .. rank2.path .. ' prices at ' .. rank2.rCost
        .. ', not the ' .. RULING_RANK2_COST .. ' the ruling names. The '
        .. 'revival condition is about a specific number; if the number moved, '
        .. 'the condition has to be re-read before this file is quoted.')
    assert(nRank2 == 1,
        'the corpus now holds ' .. nRank2 .. ' rank-2 Finger instants (exact rank), not 1. '
        .. 'HONEST BOUND (A) -- "n = 1, so 1551 is not a pool bottom" -- was '
        .. 'the single largest limit on this reading, and it has moved. '
        .. 'Re-take the rank-2 domain question with the wider sample instead '
        .. 'of quoting the n=1 numbers below.')
end

tests['[hero] lionult: rank 3 is unmeasured, and says so'] = function()
    -- STILL UNMEASURED.  The count moved 0 -> 1 on 2026-09-06 and the wire is
    -- kept live at the new number rather than deleted: HONEST BOUND (B) is now
    -- RETIRABLE (a corpus that could measure the 600 line exists) but has NOT
    -- been retired, because nothing in this file has been re-read against that
    -- frame.  Quoting any number below as covering rank 3 is a misuse.
    local _, rows = funnel()
    local n, where = 0, {}
    for _, r in ipairs(rows) do
        if r.rRank >= 3 then n = n + 1; where[#where + 1] = r.path end
    end
    assert(n == 1,
        n .. ' rank-3 Finger instant(s) now exist (cost 600), was 1 ('
        .. table.concat(where, '; ') .. '). HONEST BOUND (B) has been retirable '
        .. 'since 2026-09-06 and is still not retired -- the 600 line has never '
        .. 'been measured, and the supply for measuring it just moved again.')
    assert(where[1] == 'tests/fixtures/f_260905_004847_lion_drain_bkb.lua',
        'the one rank-3 instant is no longer the 2026-09-06 frame, it is '
        .. tostring(where[1]) .. ' -- re-read this section before quoting it')
end

-- ------------------------------------------------------------------ section 3

tests['[hero] lionult: the band width is frozen at 150 by Impale\'s ladder'] = function()
    local impale = ladder(IMPALE)
    local hex    = ladder(HEX)
    -- The band's width is the CHEAPEST castable basic. Impale is cheaper than
    -- Hex at every rank, so the cheapest basic is Impale whenever Impale is
    -- available -- and Impale's ladder ENDS. That ending is the whole argument.
    for rank = 1, math.min(#impale, #hex) do
        assert(impale[rank] < hex[rank],
            'at rank ' .. rank .. ' Impale (' .. impale[rank] .. ') is no '
            .. 'longer cheaper than Hex (' .. hex[rank] .. '). The band width '
            .. 'is the cheapest basic; if the ordering flipped, the ceiling '
            .. 'below is Hex\'s, not Impale\'s.')
    end
    local cap = impale[#impale]
    assert(cap == 150,
        'Impale now tops out at ' .. cap .. ' mana, not 150. The closed-form '
        .. 'argument -- band width frozen while the pool grows -- is stated in '
        .. 'this number and has to be restated, not re-quoted.')
    for rank = 1, #impale do
        assert(impale[rank] <= cap,
            'Impale rank ' .. rank .. ' costs more than its own last step; the '
            .. 'ladder is no longer monotone and "the cap is the last step" is '
            .. 'no longer how to read it.')
    end
end

tests['[hero] lionult: leveling shrinks the band\'s share of the pool'] = function()
    local _, rows = funnel()
    local cap = ladder(IMPALE)[#ladder(IMPALE)]
    -- Take the widest pool and the narrowest pool actually observed and show
    -- the share moves the WRONG way for the lever. This reads no frame's
    -- current mana -- only its capacity -- so it is not an n=1 claim.
    local minPool, maxPool = math.huge, 0
    for _, r in ipairs(rows) do
        if r.maxMp > 0 then
            minPool = math.min(minPool, r.maxMp)
            maxPool = math.max(maxPool, r.maxMp)
        end
    end
    assert(maxPool > minPool,
        'every live Lion in the corpus now has the same mana capacity ('
        .. maxPool .. '), so there is no pool growth to measure the band '
        .. 'against and this case has nothing to say.')
    local shareSmall = cap / minPool
    local shareLarge = cap / maxPool
    assert(shareLarge < shareSmall,
        'the band no longer covers a smaller share of the largest pool ('
        .. string.format('%.4f', shareLarge) .. ') than of the smallest ('
        .. string.format('%.4f', shareSmall) .. '). The closed-form claim is '
        .. 'exactly this inequality.')
    assert(maxPool >= 1551,
        'the largest Lion mana pool in the corpus has fallen to ' .. maxPool
        .. '. The 1551 that makes the shrinkage visible is gone.')
    assert(shareLarge < 0.10,
        'the band is ' .. string.format('%.1f%%', shareLarge * 100) .. ' of the '
        .. 'largest pool, no longer under 10%. The "target shrinks as Lion '
        .. 'levels" reading is quoted with this number.')
end

-- ------------------------------------------------------------------ section 4

tests['[hero] lionult: the KV snapshot and GH #73\'s datafeed agree'] = function()
    -- Two independent reads of the same ladder, eleven days apart: the
    -- datafeed pull recorded in GH #73's body (2026-08-20) and this repo's KV
    -- snapshot (2026-08-31). Asserting they AGREE is strictly stronger than
    -- asserting either one, and it is the only thing that would notice a drift
    -- between them -- the CASTABLE path prices from the snapshot while every
    -- prose claim about this lever quotes the datafeed, so a drift would put
    -- the two in different worlds with neither going quiet.
    local DATAFEED = { 200, 400, 600 }   -- GH #73 body, verified 2026-08-20
    local snapshot = ladder(FINGER)
    assert(#snapshot == #DATAFEED,
        'Finger\'s KV ladder now has ' .. #snapshot .. ' steps against the '
        .. 'datafeed\'s ' .. #DATAFEED .. '. Reconcile the two before trusting '
        .. 'either.')
    for i = 1, #DATAFEED do
        assert(snapshot[i] == DATAFEED[i],
            'Finger rank ' .. i .. ': snapshot says ' .. snapshot[i]
            .. ', GH #73\'s datafeed says ' .. DATAFEED[i]
            .. '. Reconcile the two before trusting either.')
    end
end

-- ------------------------------------------------------------------ section 5

tests['[hero] lionult: the ruling\'s assumed pool bottom is off by 4x'] = function()
    local _, rows = funnel()
    local rank2
    for _, r in ipairs(rows) do if r.rRank >= 2 then rank2 = r end end
    assert(rank2 ~= nil, 'no rank-2 instant; section 2 explains what that means')
    assert(rank2.path == RANK2_FRAME,
        'the rank-2 instant is now ' .. rank2.path .. ', not the staged frame '
        .. 'this file reads by name. HONEST BOUND (E) assumed exactly one '
        .. 'named frame supplies it.')
    -- The ruling reasoned that cost 400 would bite against a pool bottom of
    -- 380. On the one frame where the cost really is 400:
    assert(rank2.maxMp > RULING_ASSUMED_POOL_BOTTOM,
        'the rank-2 pool (' .. rank2.maxMp .. ') no longer exceeds the '
        .. RULING_ASSUMED_POOL_BOTTOM .. ' the ruling assumed, so the '
        .. '"400 against 380" arithmetic may hold after all -- re-read it.')
    assert(rank2.maxMp / RULING_ASSUMED_POOL_BOTTOM > 4.0,
        'the rank-2 pool is now only '
        .. string.format('%.2f', rank2.maxMp / RULING_ASSUMED_POOL_BOTTOM)
        .. 'x the assumed bottom, no longer over 4x. The size of the gap is '
        .. 'the reading; if it closed, the revival condition is back in play.')
    assert(rank2.mp >= rank2.rCost + (rank2.spend or 0),
        'the one rank-2 instant has fallen INTO the band. That is a domain '
        .. 'frame for `lionult` at cost 400 -- the exact thing the revival '
        .. 'condition was written to catch. Stop quoting this file and go '
        .. 'build the fixture.')
end

return tests

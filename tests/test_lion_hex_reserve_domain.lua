-- [ratchet] [hero] Pre-flight for the mana reserve that hero.md backlog -95
-- named as this group's next baton -- measured BEFORE it was written, and it
-- does not get written.
--
-- ===========================================================================
-- WHAT WAS PROPOSED
-- ===========================================================================
--
-- The -95 census sorted nine dead `local nManaCost = ability:GetManaCost()`
-- bindings in the focus five into five classes, and put exactly two of them in
-- class 戊 -- "no reserve of any kind, not an ultimate, does not restore mana",
-- the only class where wiring the binding to the tree's live reserve idiom
-- points the same direction the idiom points.  Lion's Hex (X.ConsiderW, the
-- binding at hero_lion.lua) was picked as the first of the two, because Lion's
-- file holds no reserve at all (`nKeepMana = 400` was removed 2026-08-20 as a
-- proven-zero-reader), so wiring it is adding a FIRST reserve rather than a
-- second.
--
-- Direction was the whole argument, and direction is not a domain.  The
-- `lionult` precedent (tests/test_lion_ult_reserve_domain.lua, GH #73) is that
-- a Lion mana lever gets its domain measured on the archive before it is
-- written, not after it is rejected.  This file is that measurement.
--
-- ===========================================================================
-- THE READING (whole archive, real loader, repaired mana meter)
-- ===========================================================================
--
--     live-Lion instants ................................. 24
--     ... Hex trained (rank >= 1) ........................ 22
--     ... and off cooldown ............................... 11
--     ... and mp >= Hex's cost (IsFullyCastable) ......... 11
--     ... and (mp - cost)/maxMp <= 0.30 .................. 1    <- arithmetic
--     ... and ANY enemy hero within 1600 ................. 0    <- behavioural
--
-- The one arithmetic instant is f_megabundle_051728_ogre_lanefront_deep.lua:
-- Lion level 6, 176/621 mana, Hex ready at 110, Impale on cooldown (3.2s),
-- Finger rank 1 at cost 200 he cannot pay -- and ZERO enemy heroes within 1600.
-- X.ConsiderW returns BOT_ACTION_DESIRE_NONE there in the shipped tree, so the
-- reserve would turn 0 into 0.
--
-- Two sharpenings, both cheap and both load-bearing:
--
--   * THE THRESHOLD IS NOT WHAT PRODUCES THE ZERO.  The tree holds TWO live
--     reserve numbers, not one -- `J.GetManaAfter(c) > 0.3` (used in
--     X.ConsiderQ) and `J.IsAllowedToSpam`'s fKeepManaPercent = 0.39.  At 0.30
--     one instant is below the line, at 0.39 two are; at BOTH thresholds the
--     intersection with "an enemy is in range" is empty.
--   * THE NARROWED FORM IS EMPTIER THAN THE BLANKET ONE.  The defensible
--     version of this lever is not "keep 30%", it is "do not spend on Hex if
--     that starves the follow-up Impale" -- a reserve conditional on the thing
--     being reserved for.  Of the 9 affordable instants with Impale trained and
--     off cooldown, the number where paying for Hex would leave less than
--     Impale's cost is ZERO.  The better-justified lever has the emptier domain.
--
-- ===========================================================================
-- WHY THIS IS NOT A STRIKE -- read this before quoting the zero
-- ===========================================================================
--
-- (A) THE BEHAVIOURAL ZERO IS THE CORPUS'S, NOT THE LEVER'S.  X.ConsiderW
--     returns BOT_ACTION_DESIRE_NONE on ALL 11 affordable instants, including
--     the three that DO have an enemy inside 1600.  Every branch of that
--     function is gated on mode or target state -- IsGoingOnSomeone,
--     IsRetreating, IsInTeamFight, an enemy mid-cast -- and on every fixture
--     frame `J.GetProperTarget(bot)` is nil and `bot:GetActiveMode()` is 0.
--     That is GH #474 ("J.GetProperTarget is structurally nil on every fixture
--     frame") at a second, independent site.  So this archive cannot show a Hex
--     cast at all, and "the reserve changes nothing" is not something it is
--     entitled to say.  What it IS entitled to say is the thing that matters
--     operationally: THERE IS NO FRAME HERE ON WHICH THE FIXTURE COULD BE
--     WRITTEN, and this group's own discipline requires one before a behaviour
--     change ships.  The lever is blocked on frame supply, not refuted.
--
-- (B) THE `lionult` STRIKE DOES NOT TRANSFER.  That lever died by closed form:
--     its band's width is the cheapest basic, Impale's ladder ENDS at 150, the
--     pool does not end, so the band's share of the pool strictly shrinks and
--     leveling kills it.  This lever has no such ending.  Its region is
--     `mp <= 0.30 * maxMp + hexCost`, i.e. a ceiling of `0.30 + hexCost/maxMp`
--     as a fraction of the pool; Hex's ladder also ends (at 200), so the second
--     term shrinks -- but it shrinks TOWARD 0.30, not toward zero.  The region
--     converges on the scale-free "Lion below 30% mana" and never vanishes at
--     any level.  Section 4 asserts exactly that, so nobody quotes GH #73's
--     arithmetic at this lever.
--
-- (C) BOTH MARGINALS ARE TINY (1 below the line, 3 with an enemy in 1600, out
--     of 11).  This corpus was sampled for other levers entirely; nothing in it
--     was chosen for Lion's mana. n is small on both legs, which is why section
--     2's zero is written as an intersection ratchet rather than a proportion.
--
-- Zero behaviour change: no gate, no new candidate id, no bots/ edit beyond the
-- comment at the binding site recording what was measured.

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')
local shapes = require('mock.special_value_shapes')

local UNIT   = 'npc_dota_hero_lion'
local HEX    = 'lion_voodoo'
local IMPALE = 'lion_impale'
local FIXTURE_DIR = 'tests/fixtures'
local STAGED_DIR  = 'tests/frames'

-- The two live reserve thresholds in the shipped tree. 0.30 is the literal in
-- X.ConsiderQ's `J.GetManaAfter( nManaCost ) > 0.3`; 0.39 is jmz_func's
-- fKeepManaPercent, read by J.IsAllowedToSpam. Measuring at both is what stops
-- the zero from being a property of a chosen number.
local RESERVE_LO = 0.30
local RESERVE_HI = 0.39

-- Generous supply radius: SkillsComplement's own widest scan. The widest list
-- any X.ConsiderW branch consults is cast range + 300 (<= 950 even with the
-- Aether Lens bonus), so 1600 cannot undercount the enemies available to it.
local SUPPLY_RADIUS = 1600

-- ---------------------------------------------------------------- enumeration

--- Every corpus file from BOTH directories -- never a hardcoded path. The
--- sister file (test_lion_ult_reserve_domain.lua) records why: a "whole
--- archive" sweep written as one glob plus one literal path silently stopped
--- being exhaustive the day tests/frames/ was created, and stayed green.
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
local function lion_instants()
    local rows = {}
    for _, path in ipairs(corpus_paths()) do
        local ok, chunk = pcall(dofile, path)
        if ok and type(chunk) == 'table' then
            local present = false
            for _, u in ipairs(chunk.units or {}) do
                if u.name == UNIT and u.alive ~= false then present = true end
            end
            if present then
                local J, bot = rf.load(path, UNIT)
                local function ask(name)
                    local h = bot:GetAbilityByName(name)
                    if h == nil then return 0, 0, 0 end
                    return h:GetLevel() or 0, h:GetCooldownTimeRemaining() or 0,
                        h:GetManaCost() or 0
                end
                local wRank, wCd, wCost = ask(HEX)
                local qRank, qCd, qCost = ask(IMPALE)
                rows[#rows + 1] = {
                    path = path,
                    mp = bot:GetMana() or 0, maxMp = bot:GetMaxMana() or 0,
                    wRank = wRank, wCd = wCd, wCost = wCost,
                    qRank = qRank, qCd = qCd, qCost = qCost,
                    nEnemy = #J.GetNearbyHeroes(bot, SUPPLY_RADIUS, true, BOT_MODE_NONE),
                }
            end
        end
    end
    return rows
end

--- The funnel, bucketed so the buckets are EXHAUSTIVE and disjoint; section 1
--- asserts they re-sum, which is what stops a silently dropped record from
--- reading as a smaller domain.
local function funnel()
    local rows = lion_instants()
    local t = { live = #rows, untrained = 0, trained = 0, onCd = 0, ready = 0,
                tooPoor = 0, afford = 0, belowLo = 0, belowHi = 0, supplied = 0,
                domainLo = 0, domainHi = 0, qReady = 0, qStarved = 0,
                affordRows = {}, belowRows = {} }
    for _, r in ipairs(rows) do
        if r.wRank < 1 then t.untrained = t.untrained + 1
        else
            t.trained = t.trained + 1
            if r.wCd > 0 then t.onCd = t.onCd + 1
            else
                t.ready = t.ready + 1
                if r.mp < r.wCost then t.tooPoor = t.tooPoor + 1
                else
                    t.afford = t.afford + 1
                    t.affordRows[#t.affordRows + 1] = r
                    local after = (r.mp - r.wCost) / r.maxMp
                    if after <= RESERVE_LO then
                        t.belowLo = t.belowLo + 1
                        t.belowRows[#t.belowRows + 1] = r
                        if r.nEnemy > 0 then t.domainLo = t.domainLo + 1 end
                    end
                    if after <= RESERVE_HI then
                        t.belowHi = t.belowHi + 1
                        if r.nEnemy > 0 then t.domainHi = t.domainHi + 1 end
                    end
                    if r.nEnemy > 0 then t.supplied = t.supplied + 1 end
                    if r.qRank >= 1 and r.qCd <= 0 then
                        t.qReady = t.qReady + 1
                        if r.mp - r.wCost < r.qCost then
                            t.qStarved = t.qStarved + 1
                        end
                    end
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

tests['[hero] lionhexmana: the funnel is exhaustive and its buckets re-sum'] = function()
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
    assert(t.belowLo <= t.belowHi,
        'more instants sit under the 0.30 reserve line (' .. t.belowLo .. ') '
        .. 'than under the 0.39 one (' .. t.belowHi .. '). The lines are nested '
        .. 'by construction; if they are not, one of them is being read wrong.')
end

tests['[hero] lionhexmana: the mana meter is charging, so the zeros are readings'] = function()
    local t, rows = funnel()
    -- Found on the sister lever's mutation stand: with the loader's mana_ladder
    -- regressed, every GetManaCost answers 0, `mp >= cost` is a tautology and
    -- `(mp - 0)/maxMp` is just the mana fraction -- a DIFFERENT and looser
    -- predicate that would still print a small number and still look like a
    -- reading. This is the guard that separates the two.
    local nPriced = 0
    for _, r in ipairs(rows) do if r.wCost > 0 then nPriced = nPriced + 1 end end
    assert(nPriced == t.live,
        'only ' .. nPriced .. ' of ' .. t.live .. ' live-Lion instants get a '
        .. 'real Hex price out of the loader. The mana meter has regressed to '
        .. 'the free-mana world and every domain count below is an artefact of '
        .. 'the price being 0, not a fact about Lion.')
    -- ... and the enemy enumerator is alive somewhere, for the same reason.
    assert(t.supplied > 0,
        'not one affordable instant has an enemy hero within ' .. SUPPLY_RADIUS
        .. '. The supply leg cannot be distinguished from a broken enumerator, '
        .. 'and section 2 intersects against it.')
end

-- ------------------------------------------------------------------ section 2

tests['[hero] lionhexmana: the domain is empty at BOTH live reserve thresholds'] = function()
    local t = funnel()
    assert(t.domainLo == 0,
        t.domainLo .. ' affordable instant(s) now sit under the ' .. RESERVE_LO
        .. ' reserve line WITH an enemy hero in reach. THE FRAME THIS LEVER '
        .. 'NEEDED EXISTS. Build the fixture on it, re-read this whole file, '
        .. 'and take the Hex reserve back through .claude/skills/gated-fix/ -- '
        .. 'the reason it was not written is exactly this count being 0.')
    assert(t.domainHi == 0,
        t.domainHi .. ' affordable instant(s) sit under the ' .. RESERVE_HI
        .. ' line (fKeepManaPercent) with an enemy in reach, while the '
        .. RESERVE_LO .. ' line is still empty. The domain has opened at the '
        .. 'looser threshold only; that is a frame, and it is also a reason to '
        .. 'pick the threshold deliberately instead of copying X.ConsiderQ.')
    -- The point is not the zero, it is that BOTH legs are individually
    -- non-empty and their intersection is not. Naming which clause closes it is
    -- what makes the zero worth quoting.
    assert(t.belowLo > 0,
        'no affordable instant is under the reserve line any more. The '
        .. 'arithmetic leg has gone empty too, so section 2 no longer says '
        .. '"the legs miss each other" -- it says "there is no leg".')
end

tests['[hero] lionhexmana: the narrowed, better-justified form is emptier still'] = function()
    local t = funnel()
    -- "Keep 30%" reserves against nothing in particular. The version that has a
    -- reason is "do not spend on Hex if it starves the follow-up Impale" --
    -- conditional on the thing being reserved FOR actually being available.
    assert(t.qReady > 0,
        'no affordable instant has Impale trained and off cooldown, so the '
        .. 'follow-up-conditional form cannot be evaluated at all and the zero '
        .. 'below is vacuous.')
    assert(t.qStarved == 0,
        t.qStarved .. ' instant(s) would be left unable to pay for a ready '
        .. 'Impale by casting Hex. The follow-up-conditional reserve -- the one '
        .. 'with an actual justification -- has acquired a domain, and it is '
        .. 'the form to build, not the blanket percentage.')
end

-- ------------------------------------------------------------------ section 3

tests['[hero] lionhexmana: LIMIT (A) -- ConsiderW is silent on every instant'] = function()
    local t = funnel()
    -- The honest bound, coded. If this ever stops holding, the archive has
    -- gained the ability to speak about Hex at all, and section 2's zero stops
    -- being "the corpus cannot show a cast" and starts being a real reading.
    local nSpoke = 0
    for _, r in ipairs(t.affordRows) do
        local _ = rf.load(r.path, UNIT)
        local X = rf.load_hero('lion')
        pcall(X.SkillsComplement)
        local ok, desire = pcall(X.ConsiderW)
        if ok and type(desire) == 'number' and desire > 0 then
            nSpoke = nSpoke + 1
        end
    end
    assert(nSpoke == 0,
        nSpoke .. ' of ' .. #t.affordRows .. ' affordable instants now make '
        .. 'X.ConsiderW want a cast. LIMIT (A) in this file\'s header -- "the '
        .. 'behavioural zero is the corpus\'s, not the lever\'s" -- has '
        .. 'expired: there is now a frame where a reserve could actually '
        .. 'intercept something. Re-read section 2 against it.')
    assert(#t.affordRows > 0,
        'no affordable instant to drive, so the sweep above compared nothing')
end

-- ------------------------------------------------------------------ section 4

tests['[hero] lionhexmana: the lionult closed form does not transfer'] = function()
    local t, rows = funnel()
    local hex = ladder(HEX)
    local cap = hex[#hex]
    assert(cap == 200,
        'Hex now tops out at ' .. cap .. ' mana, not 200. The ceiling argument '
        .. 'below is stated in this number and has to be restated, not requoted.')
    for rank = 2, #hex do
        assert(hex[rank] > hex[rank - 1],
            'Hex rank ' .. rank .. ' is not dearer than rank ' .. (rank - 1)
            .. '; "the cap is the last step" is no longer how to read the ladder.')
    end
    local minPool, maxPool = math.huge, 0
    for _, r in ipairs(rows) do
        if r.maxMp > 0 then
            minPool = math.min(minPool, r.maxMp)
            maxPool = math.max(maxPool, r.maxMp)
        end
    end
    assert(maxPool > minPool,
        'every live Lion in the corpus now has the same mana capacity, so there '
        .. 'is no pool growth to measure the ceiling against')
    -- The region this lever can ever bite in, as a fraction of the pool.
    local ceilSmall = RESERVE_LO + cap / minPool
    local ceilLarge = RESERVE_LO + cap / maxPool
    assert(ceilLarge < ceilSmall,
        'the biting region no longer narrows as the pool grows; the second term '
        .. 'of the ceiling is supposed to be cap/maxMp')
    -- ... and this is the half that separates it from `lionult`: the shrinkage
    -- has a FLOOR, and the floor is the reserve fraction itself.
    assert(ceilLarge > RESERVE_LO,
        'the biting region has shrunk to or below the bare reserve fraction ('
        .. RESERVE_LO .. '). It converges on it from above and cannot reach it; '
        .. 'if this reads false the arithmetic is wrong somewhere.')
    assert(ceilLarge > 0.30 and ceilLarge < 0.60,
        'the ceiling at the largest observed pool is '
        .. string.format('%.4f', ceilLarge) .. ', outside the band this file '
        .. 'quotes. GH #73 struck `lionult` because ITS analogous quantity '
        .. 'tends to zero; this one tends to ' .. RESERVE_LO .. '. Do not let '
        .. 'that strike be quoted here without re-reading this number.')
    assert(t.live > 0, 'no instants, so minPool/maxPool are not from the corpus')
end

return tests

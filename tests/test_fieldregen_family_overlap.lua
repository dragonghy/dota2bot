-- The supply-side family has FIVE claimants on one `item_flask` purchase, and
-- its disjointness tests drive FOUR predicates.
--
-- WHAT THIS FILE PINS, AND WHY IT IS NOT ALREADY PINNED SOMEWHERE ELSE.
--
--   bots/item_purchase_generic.lua:776   the `fieldregen` inline block
--   bots/item_purchase_generic.lua:833   `fieldbuy` or `buyband` or `buytower` or `buyring`
--
-- The four at :833 were designed together and are disjoint BY CONSTRUCTION --
-- `buytower` inverts the tower clause, `buyring` inverts the hero ring,
-- `buyband` takes the strip above `fieldbuy`'s 0.55 ceiling -- and three of the
-- four say exactly that in their own comments ("so the three arms are disjoint
-- by construction", "so the four arms stay disjoint by construction").
-- tests/_buytower_sweep.lua and tests/_buyring_sweep.lua ASSERT it: every one of
-- `overlap_tower_buy`, `overlap_tower_hurt`, `overlap_ring_buy`,
-- `overlap_ring_hurt`, `overlap_ring_tower` must be 0.
--
-- ⭐ THAT CLAIM IS TRUE AMONG THE FOUR AND SAYS NOTHING ABOUT THE FIFTH, AND
-- NOTHING IN THE TREE SAID SO. `fieldregen` appears in NONE of the family's
-- sweeps -- not as a probe, not as an arm, not as a counter. It buys the same
-- item, from the same `ItemPurchaseThink` body, 57 lines earlier, with NO band
-- floor (`< 0.45`, open below) and NONE of the three surroundings clauses the
-- other four partition: no 1600 hero ring, no 1200 tower ring, no attribution
-- window. So on its own domain it reaches frames every one of the four arms was
-- written to own -- including the two (`buytower`, `buyring`) whose ENTIRE lever
-- is an inverted clause `fieldregen` never asks.
--
-- ⭐⭐ AND THE RELATION IS PRE-EMPTION, NOT CO-OCCURRENCE, FIXED BY LINE ORDER.
-- Both blocks share the trailing engine guards, among them
-- `not IsThereHealingInStash(bot)`. `fieldregen` runs FIRST. When it buys, the
-- salve goes to the stash (the block only runs past 2500 units from the
-- fountain), so on that frame and the ones after it the four-arm `if` at :833 is
-- refused by its own stash clause. The earlier block does not merely share the
-- frame with the later one; it consumes the purchase the later one exists to
-- make. tests/test_coarmed_attribution_register.lua carries
-- `['fieldregen > fieldbuy'] = true` as a WIDE row whose own comment says the
-- call "is not known to sit inside either branch" -- i.e. the confound was
-- recorded WITHOUT its mechanism. This file records the mechanism.
--
-- ⛔ WHAT IS ASSERTED HERE IS THE SOURCE STRUCTURE, NOT A CORPUS READING, AND
-- THE CORPUS CANNOT CLOSE IT. tests/_fieldregen_overlap_sweep.lua drives the
-- question over 110 fixtures / 1021 live turbo hero frames and reports
-- `overlap_any 0` -- and that 0 is the INSTRUMENT'S zero, not the domain's:
--   fr_pred 6 | laning 842 of 1021 (82.5%) | not_laning 179
--   arm_fieldbuy 33 | arm_buyband 20 | arm_buyring 10 | arm_buytower 8
-- `fieldregen` is by construction a POST-LANING lever (`not
-- J.IsInLaningPhase()`), while 82.5% of the corpus is laning-phase, so its full
-- readable predicate holds on SIX frames and the overlap question has almost no
-- corpus to be asked on. The four arms have no laning clause, which is why they
-- have domain here and it is why their measured mutual disjointness is not
-- evidence about this pair either way. Do not read `overlap_any 0` as "they do
-- not overlap"; the sweep prints `fr_pred` next to it so the two can never be
-- confused (the §FW.2 shape: a funnel dying on one conjunct, where "the clause
-- is false" and "the instrument is blind to this clause" look identical).
--
-- So the assertions below are SOURCE assertions, and they are the half that can
-- be checked cheaply and exactly. They run in milliseconds and carry no corpus
-- drive, deliberately: the Lua detector leg is already against its 120s budget
-- (GH #358, 86 files), and a 30-second corpus walk belongs in the `_`-prefixed
-- sweep that this header quotes, not in the fast leg.

package.path = 'tests/?.lua;' .. package.path

local BUY = 'bots/item_purchase_generic.lua'

local function read_file(path)
    local f = assert(io.open(path, 'r'), path .. ' is not readable')
    local s = f:read('*a')
    f:close()
    return s
end

-- Comments are stripped before every scan below. The `fieldregen` block ships
-- under a long prose header that names its own clauses, and the four arms'
-- comments contain the very phrase "disjoint by construction" this file is
-- about -- so an unstripped scan would let the PROSE satisfy the assertions.
-- That is the §EN mistake this family has already paid for once.
local function strip_comments(s)
    if s == nil then return nil end
    return (s:gsub('%-%-[^\n]*', ''))
end

local function line_of(src, needle)
    local at = src:find(needle, 1, true)
    if at == nil then return -1 end
    local _, n = src:sub(1, at):gsub('\n', '')
    return n + 1
end

local function block_from(src, needle)
    local at = src:find(needle, 1, true)
    if at == nil then return nil end
    local stop = src:find('\n\tend', at, true) or #src
    return strip_comments(src:sub(at, stop))
end

local tests = {}

tests['[source] the comment stripping actually happened'] = function()
    -- Asserted as its own fact rather than left to be implied by some count
    -- coming out at the expected number. It was implied once ('staybag' round,
    -- M5): an exact total was the only thing catching the "stop stripping"
    -- mutant, and relaxing that total for an unrelated and correct reason took
    -- the mutant's only detector with it.
    local src = read_file(BUY)
    local fr = block_from(src, "if J.IsModeTurbo() and J.IsSoakCandidate('fieldregen')")
    local fam = block_from(src, 'if ( J.ShouldFieldBuyRegen(bot)')
    assert(fr, 'the fieldregen block is gone')
    assert(fam, 'the four-arm block is gone')
    assert(not fr:find('--', 1, true), 'fieldregen block still carries comments')
    assert(not fam:find('--', 1, true), 'four-arm block still carries comments')
end

tests['[source] there are FIVE claimants on the flask, and the four-arm block is only four'] = function()
    local src = read_file(BUY)
    local fam = block_from(src, 'if ( J.ShouldFieldBuyRegen(bot)')
    for _, arm in ipairs({ 'J.ShouldFieldBuyRegen(bot)', 'J.ShouldFieldBuyRegenHurt(bot)',
        'J.ShouldFieldBuyRegenTower(bot)', 'J.ShouldFieldBuyRegenRing(bot)' }) do
        assert(fam:find(arm, 1, true), 'the four-arm block no longer calls ' .. arm)
    end
    -- The fifth claimant is NOT one of them, and that is the whole point: the
    -- family's disjointness sweeps drive this block's four predicates, so a
    -- claimant that is not in this block is invisible to them by construction.
    assert(not fam:find('fieldregen', 1, true),
        'fieldregen has joined the four-arm block -- if it is now one of the '
        .. 'arms, the family sweeps can see it and this file has to be re-taken')
    local frline = line_of(src, "J.IsSoakCandidate('fieldregen')")
    local famline = line_of(src, 'J.ShouldFieldBuyRegen(bot) or J.ShouldFieldBuyRegenHurt(bot)')
    assert(frline > 0 and famline > 0, 'one of the two claimants is gone')
    assert(frline < famline, 'the fieldregen block no longer runs FIRST (fieldregen at '
        .. frline .. ', family at ' .. famline .. ') -- the pre-emption '
        .. 'direction this file records is reversed, re-take it')
end

tests['[source] both claimants buy the same item, which is what makes it pre-emption'] = function()
    local src = strip_comments(read_file(BUY))
    local fr = block_from(read_file(BUY), "if J.IsModeTurbo() and J.IsSoakCandidate('fieldregen')")
    local fam = block_from(read_file(BUY), 'if ( J.ShouldFieldBuyRegen(bot)')
    assert(fr:find("ActionImmediate_PurchaseItem('item_flask')", 1, true),
        'the fieldregen block no longer buys a flask')
    assert(fam:find("ActionImmediate_PurchaseItem('item_flask')", 1, true),
        'the four-arm block no longer buys a flask')
    -- The shared guard that carries the pre-emption. If either block stops
    -- asking it, the earlier purchase stops suppressing the later block and the
    -- mechanism recorded in this header is no longer the mechanism.
    assert(fr:find('not IsThereHealingInStash(bot)', 1, true),
        'the fieldregen block dropped its stash guard')
    assert(fam:find('not IsThereHealingInStash(bot)', 1, true),
        'the four-arm block dropped its stash guard -- the earlier purchase no '
        .. 'longer suppresses it and the pre-emption reading must be re-taken')
    assert(src:find('function IsThereHealingInStash', 1, true)
        or src:find('IsThereHealingInStash', 1, true),
        'IsThereHealingInStash is gone')
end

tests['[source] fieldregen asks NONE of the three clauses the four arms partition'] = function()
    -- ⭐ THE ABSENCES ARE THE LEVER OF THIS WHOLE FILE, so they are asserted in
    -- both directions. `buytower`'s entire lever is the INVERTED tower clause
    -- and `buyring`'s is the INVERTED hero ring; `fieldregen` asks neither, so
    -- it reaches the frames those two arms exist to own. A future edit that
    -- ADDS a ring or tower clause to the block would shrink that overlap -- and
    -- this file must go red then rather than keep reporting an overlap it no
    -- longer describes.
    local fr = block_from(read_file(BUY),
        "if J.IsModeTurbo() and J.IsSoakCandidate('fieldregen')")
    assert(not fr:find('GetNearbyHeroes', 1, true),
        'the fieldregen block now reads a hero ring -- re-take the overlap')
    assert(not fr:find('GetNearbyTowers', 1, true),
        'the fieldregen block now reads a tower ring -- re-take the overlap')
    assert(not fr:find('WasRecentlyDamagedByAnyHero', 1, true),
        'the fieldregen block now reads an attribution window -- re-take it')
    -- And no floor: the band is open below, so it also underruns
    -- J.IsFieldRegenSituation's own 0.18 floor.
    assert(not fr:match('J%.GetHP%(bot%) > [%d%.]+'),
        'the fieldregen block gained an HP floor -- its band is no longer open '
        .. 'below and the overlap with the 0.18-floored arms must be re-taken')
    local hi = tonumber(fr:match('J%.GetHP%(bot%) < ([%d%.]+)'))
    assert(hi == 0.45, 'fieldregen ceiling moved from 0.45 to ' .. tostring(hi))
end

tests['[source] fieldregen is post-laning, which is why the fixture corpus cannot host the question'] = function()
    -- The bound in this file's header, pinned as a fact about the source rather
    -- than left in prose: the clause that empties the corpus is this one. If it
    -- is ever removed, `fr_pred` stops being 6 and every corpus number quoted
    -- above has to be re-taken.
    local fr = block_from(read_file(BUY),
        "if J.IsModeTurbo() and J.IsSoakCandidate('fieldregen')")
    assert(fr:find('not J.IsInLaningPhase()', 1, true),
        'the fieldregen block is no longer post-laning-only -- the corpus '
        .. 'starvation recorded in this header no longer applies, re-take it')
    -- The four arms reach their domain through J.IsFieldRegenSituation, which
    -- has NO laning clause. That asymmetry is the whole reason the two sides
    -- are measured on disjoint slices of this corpus.
    local jmz = strip_comments(read_file('bots/FunLib/jmz_func.lua'))
    local at = jmz:find('function J.IsFieldRegenSituation( bot )', 1, true)
    assert(at, 'J.IsFieldRegenSituation is gone')
    local sit = jmz:sub(at, (jmz:find('\nfunction J.', at + 10) or #jmz))
    assert(not sit:find('IsInLaningPhase', 1, true),
        'J.IsFieldRegenSituation gained a laning clause -- the two sides are no '
        .. 'longer measured on disjoint slices and this file has to be re-taken')
end

tests['[register] the confound is on the record, and it is the fieldregen row'] = function()
    -- The pair is already ACKNOWLEDGED in the co-armed register; what this file
    -- adds is its mechanism. Pinned so that retiring the row silently would
    -- take this file red rather than leave the mechanism recorded for a pair
    -- nobody counts any more.
    local reg = read_file('tests/test_coarmed_attribution_register.lua')
    assert(reg:find("['fieldregen > fieldbuy'] = true", 1, true),
        "the 'fieldregen > fieldbuy' row left the co-armed register -- if the "
        .. 'confound was retired, this file records a mechanism for a pair that '
        .. 'is no longer counted')
end

return tests

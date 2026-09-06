-- [buyband 2026-09-06, 协同组] Owner priority P2: a hurt bot in no danger must NOT
-- go home -- "血量低也尽量不要回程,买大药或其他补给". This file is about the second
-- half of that sentence, and about a gap between two numbers.
--
-- ⭐ THE FINDING, AS TWO CONSTANTS THAT DISAGREE. J.ShouldStayAndRegen is PROMOTED
-- -- live in every turbo game since the 'tphome' promote -- and its band is
-- `nHP < 0.18 or nHP > 0.75`: that is this tree's own definition of "hurt enough
-- that going home is on the table". J.IsFieldRegenSituation, which decides whether
-- the FIELD alternative is offered at all, stops at 0.55. So between 0.55 and 0.75
-- a hurt, SAFE, empty-handed bot is released to walk or TP home by the promoted
-- veto -- its only remaining clause is `bot:GetGold() < 90`, and 90 gold stops
-- nobody past the first minutes -- while the one id whose entire job is "buy the
-- salve instead" (`fieldbuy`) is structurally silent, because its situation
-- predicate says the bot is not hurt yet.
--
-- Measured, not argued (tests/_buyband_sweep.lua, 1012 live hero frames):
--   125 frames reach J.ShouldStayAndRegen's supply clause; 112 are vetoed there.
--   Those 112 split exactly three ways -- 44 carry a main-slot source ('staysrc'),
--   2 carry a backpacked salve ('staybag'), 66 carry NOTHING drinkable. The 66 are
--   not a supply-read defect at all: there is genuinely nothing to read, and P2's
--   answer for them is to buy. 29 are already inside J.IsFieldRegenSituation and
--   'fieldbuy' speaks for them today. Of the remaining 37, **18** are blocked by
--   the 0.55 ceiling AND BY NOTHING ELSE (11 by the 1600 ring, 10 by a tower --
--   those are real vetoes and this lever does not touch them).
--
-- ⭐⭐ THE REUSABLE JUDGEMENT, and it is about WHICH EDIT, not about salves.
-- Three edits reach this behaviour and two of them cannot be measured or cannot be
-- afforded:
--   (a) raise the ceiling inside J.IsFieldRegenSituation -> ONE arm moves THREE
--       families ('stayfield', 'stayfield2', 'fieldbuy'): the 'lanefix' bundle
--       shape, which measured strongly negative twice.
--   (b) pass a gated ceiling from inside J.ShouldFieldBuyRegen -> the new id sits
--       BEHIND that function's own `IsSoakCandidate('fieldbuy')` first line, so it
--       could only ever act with 'fieldbuy' also armed. Two ids on one PATH, every
--       site reading clean, and any single-arm isolation wave reading a correct
--       zero: the second form of the 'pullcad' trap (GH #542, opened by the
--       'staybag' round one day earlier).
--   (c) add an optional ceiling ARGUMENT to J.IsFieldRegenSituation -- the
--       clean-looking one. It was WRITTEN AND THEN REVERTED on 2026-09-06, and the
--       cost was MEASURED rather than guessed (the edit re-applied on a copy, the
--       eight files that parse this function run, the tree restored):
--       `function J.IsFieldRegenSituation( bot )` and `nHP < 0.18 or nHP > 0.55`
--       are read as LITERAL TEXT, and **7 of those 8 go red at once** --
--       test_healthy_walk_home_gap, test_stayfield_hp_window_reach,
--       test_stayfield2_marginal_domain, test_fightback_world_assertion,
--       test_itemtrip_wasteful_trip, test_bagsalve_backpack_source,
--       test_stayattr_global_ult. The eighth, test_stayfield_callsite_domain,
--       stays GREEN, and that is the informative half: it reads a CALL SITE, which
--       a defaulted argument leaves byte-identical. ⇒ **On a tree whose detectors
--       parse source text, a signature is a published interface: the cost of
--       touching a shared predicate is paid by whoever parses its DECLARATION, and
--       none of those seven files has anything to say about this lever.**
-- So this lever is a standalone function that REPEATS three clauses instead of
-- calling the sibling -- exactly what J.HasNearbyHeroDamager does, for exactly the
-- reason its comment gives. The duplication is not left to drift: every constant
-- in both copies is parsed below and compared, so a change to either goes red here.
--
-- WHAT IS ASSERTED. Not gate plumbing. The shipped call-site predicate pair is
-- driven on real frames with every candidate disarmed and then with exactly
-- 'buyband' armed, and the CAUSE of the changed answer is read off the frame's own
-- HP and item slots. `flips_buyband` (driven) and `hurt_domain` (an independent
-- prefix walk) must agree, and the negative controls are frames in the band that
-- an inherited clause must still refuse.
--
-- ⚠️ HONEST BOUNDS, all four stated up front:
-- (1) WHAT FLIPS IS A PURCHASE PREDICATE, NOT A TRIP HOME. The nine engine clauses
--     guarding the actual ActionImmediate_PurchaseItem (stock, gold, stash, courier
--     distance, empty slot) are not readable from a fixture and neither is the
--     trip. The wiring is asserted; the purchase is not.
-- (2) THE MEASURED SET IS THE GOLD-BLIND SUPERSET of the live one. Gold is not
--     networked into a .dem (GH #495), so `botGold >= GetItemCost('item_flask')`
--     at the call site is unmeasurable here. Direction is fixed; size is not.
-- (3) THE DOMAIN IS 20 FRAMES, as a measurement rather than an apology, and it is
--     20 rather than 18 for two named reasons that are counted, not explained:
--     1 frame sits outside J.ShouldStayAndRegen's REACH set (its chase clause is
--     the UNATTRIBUTED read that 'stayattr' exists for, and this census does not
--     arm it), and 1 carries a backpacked salve, which J.HasFieldRegenSource
--     cannot see (slot <= 5) and which the call site's own
--     `FindItemSlot('item_flask') < 0` does refuse -- the GH #123 asymmetry, on the
--     new arm exactly as it already sits on 'fieldbuy'.
-- (4) THE 'fieldcreep' VETO IS DELIBERATELY NOT COPIED. Naming another candidate's
--     id here would freeze that clause FALSE the day it is promoted (the 'pullcad'
--     trap in its first form), so while 'fieldcreep' is armed the two call-site
--     arms disagree about a bot being chewed by a camp. Measured: 0 of the 20
--     domain frames carry creep damage in the same 3-second window, so the
--     disagreement is empty on this corpus -- and `hurt_with_creep_damage` is what
--     says so the day it stops being empty.

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')
local cs = require('corpus_scale')

local SWEEP = 'lua5.1 tests/_buyband_sweep.lua 2>/dev/null'
local JMZ = 'bots/FunLib/jmz_func.lua'
local PURCHASE = 'bots/item_purchase_generic.lua'

-- The pinned frame, and it is the P2 fixture itself: f_260822_063722_lina_tp_home
-- is the frame owner priority P2 names (lina at 31.8% HP TP-ing home with the
-- nearest enemy 6,596 units away). The hero pinned HERE is the OTHER one on that
-- same frame -- drow_ranger at 63.9% HP, nothing drinkable, nobody near -- i.e. the
-- gap this lever is about is standing next to the case that motivated the family.
local FX = 'tests/fixtures/f_260822_063722_lina_tp_home.lua'
local SUBJ = 'npc_dota_hero_drow_ranger'
-- A second frame near the OTHER end of the band, pinned so the finding is not one
-- fixture wide and not one HP value wide.
local FX2 = 'tests/fixtures/f_212636_tide_ancient.lua'
local SUBJ2 = 'npc_dota_hero_lina'

-- Negative controls. Every one of these is INSIDE the new band and carrying
-- nothing, so the only thing that can refuse them is a clause this lever inherited
-- unchanged. If any of them flips, the lever is being credited with work the ring
-- and tower clauses do.
local BLOCKED = {
    { fx = 'tests/fixtures/f_071423_sky_rescue.lua',
      subj = 'npc_dota_hero_sven', hp = 0.6869, why = 'ring' },
    { fx = 'tests/fixtures/f_260820_043710_lich_defend_pos5.lua',
      subj = 'npc_dota_hero_tidehunter', hp = 0.6758, why = 'tower' },
}
-- Out of band on the HIGH side: a healthy bot must never buy a field salve.
local OOB_HIGH = { fx = 'tests/fixtures/f_045650_lion_meatgrinder.lua',
    subj = 'npc_dota_hero_axe', hp = 1.0 }
-- Out of band on the LOW side, and this one is the disjointness control rather
-- than a rejection: it is 'fieldbuy''s frame, and 'buyband' must refuse it while
-- 'fieldbuy' accepts it.
local OOB_LOW = { fx = 'tests/fixtures/f_071903_sven_idle.lua',
    subj = 'npc_dota_hero_luna', hp = 0.3512 }

local tests = {}

local M = (function()
    local p = assert(io.popen(SWEEP, 'r'))
    local raw = p:read('*a')
    p:close()
    local m = { g = {}, c = {}, flips = {}, census = {}, done = false }
    for line in raw:gmatch('[^\n]+') do
        local k, v = line:match('^G (%S+) (%S+)$')
        if k ~= nil then m.g[k] = tonumber(v) or v end
        local ck, cv = line:match('^C (%S+) (%-?%d+)$')
        if ck ~= nil then m.c[ck] = tonumber(cv) end
        local ff, fh, fp = line:match('^F (%S+) (%S+) ([%d%.]+)$')
        if ff ~= nil then
            m.flips[#m.flips + 1] = { fixture = ff, hero = fh, hp = tonumber(fp) }
        end
        local nf, nh, np = line:match('^N (%S+) (%S+) ([%d%.]+)$')
        if nf ~= nil then
            m.census[#m.census + 1] = { fixture = nf, hero = nh, hp = tonumber(np) }
        end
        if line == 'DONE' then m.done = true end
    end
    return m
end)()

local function C(key)
    local n = M.c[key]
    assert(n ~= nil, 'the sweep did not emit counter ' .. key
        .. ' -- an absent counter is not a zero')
    return n
end

local function read_file(path)
    local fh = assert(io.open(path, 'r'), 'cannot read ' .. path)
    local s = fh:read('*a')
    fh:close()
    return s
end

--- Load one fixture frame with every soak candidate disarmed, and hand back a
--- switch that arms exactly one id. Arming ONE id (not 'all') is the point: a
--- bundle answer cannot be attributed to this lever.
local function frame(path, subject, sId)
    local J, bot = rf.load(path, subject)
    local armed = false
    J.IsSoakCandidate = function(s) return armed and s == (sId or 'buyband') end
    return J, bot, function(b) armed = b end
end

--- The CALL SITE's predicate, as the call site itself spells it: the OR of the two
--- arms. Driving this rather than the new function alone is what makes "arming can
--- only add TRUEs" a statement about the shipped decision instead of about a
--- helper nobody calls.
local function site(J, bot)
    return (J.ShouldFieldBuyRegen(bot) or J.ShouldFieldBuyRegenHurt(bot)) and true
        or false
end

-- --------------------------------------------------- the tree, as source ---

tests['[source] the lever is where this file says it is'] = function()
    assert(M.done, 'the sweep subprocess did not finish (no DONE line) -- every '
        .. 'number below would be a silent zero')
    assert(M.g.SIT == 1, 'the sweep could not slice J.IsFieldRegenSituation out of '
        .. JMZ)
    assert(M.g.BUY == 1, 'the sweep could not slice J.ShouldFieldBuyRegen out of '
        .. JMZ)
    assert(M.g.HURT == 1, 'the sweep could not slice J.ShouldFieldBuyRegenHurt out '
        .. 'of ' .. JMZ)
    assert(M.g.STAY == 1, 'the sweep could not slice J.ShouldStayAndRegen out of '
        .. JMZ)
    assert(M.g.HURT_SOAKID == 1, "the 'buyband' id is no longer in "
        .. 'J.ShouldFieldBuyRegenHurt (comments are stripped before this is read)')
    -- Every [source] fact in this file is a claim about CODE, and this lever ships
    -- with a ~60-line comment naming J.IsSoakCandidate, three sibling ids, both
    -- constants and the call site while explaining them. So the stripping is
    -- asserted DIRECTLY rather than inferred from some count landing on its
    -- expected value -- the 'staybag' round's M5, where an exact id total was the
    -- only thing catching the "stop stripping" mutant and relaxing that total for
    -- an unrelated and correct reason took the mutant's only detector with it.
    assert(M.g.SIT_STRIPPED == 1 and M.g.HURT_STRIPPED == 1
        and M.g.STAY_STRIPPED == 1,
        'the sweep is parsing UNSTRIPPED source (comment markers survive in a '
        .. 'sliced block) -- every [source] assertion in this file could then be '
        .. 'satisfied by prose')
end

tests['[source] the two constants that disagree, parsed not written down'] = function()
    -- The finding itself. If either number moves, the gap this lever fills is a
    -- different gap and this file must be re-read, not re-baselined.
    assert(M.g.STAY_HP_HI == 0.75, 'J.ShouldStayAndRegen now stops calling a bot '
        .. 'hurt at ' .. tostring(M.g.STAY_HP_HI) .. ', not 0.75 -- the upper end '
        .. 'of the unowned band moved')
    assert(M.g.SIT_HP_HI == 0.55, 'J.IsFieldRegenSituation now offers the field '
        .. 'alternative up to ' .. tostring(M.g.SIT_HP_HI) .. ', not 0.55 -- the '
        .. 'lower end of the unowned band moved')
    assert(M.g.STAY_HP_HI > M.g.SIT_HP_HI, 'the band is empty or inverted: the '
        .. 'promoted veto now stops at or below where the field alternative does, '
        .. 'so there is nothing for this lever to own')
    -- ...and the lever uses THOSE two numbers, not two of its own.
    assert(M.g.HURT_FLOOR == M.g.SIT_HP_HI, "the lever's floor ("
        .. tostring(M.g.HURT_FLOOR) .. ") is no longer the sibling's ceiling ("
        .. tostring(M.g.SIT_HP_HI) .. ') -- it is a new tuned constant now, and '
        .. 'the two domains may overlap')
    assert(M.g.HURT_CEIL == M.g.STAY_HP_HI, "the lever's ceiling ("
        .. tostring(M.g.HURT_CEIL) .. ") is no longer the promoted veto's ("
        .. tostring(M.g.STAY_HP_HI) .. ') -- it is a new tuned constant now')
    assert(M.g.HURT_HP_LO == M.g.SIT_HP_LO, 'the 0.18 floor was inherited from the '
        .. 'sibling; it now reads ' .. tostring(M.g.HURT_HP_LO) .. ' against '
        .. tostring(M.g.SIT_HP_LO))
end

tests['[source] the three duplicated clauses have not drifted'] = function()
    -- The price of repeating clauses instead of calling the sibling, made
    -- checkable. Each pair is parsed from its own function body.
    assert(M.g.HURT_RING == M.g.SIT_RING, 'the empty-ring radius drifted: lever '
        .. tostring(M.g.HURT_RING) .. ' vs sibling ' .. tostring(M.g.SIT_RING))
    assert(M.g.HURT_TOWER == M.g.SIT_TOWER, 'the tower radius drifted: lever '
        .. tostring(M.g.HURT_TOWER) .. ' vs sibling ' .. tostring(M.g.SIT_TOWER))
    assert(M.g.HURT_ATTR_WINDOW == M.g.SIT_ATTR_WINDOW,
        'the damage lookback drifted: lever ' .. tostring(M.g.HURT_ATTR_WINDOW)
        .. ' vs sibling ' .. tostring(M.g.SIT_ATTR_WINDOW))
    assert(M.g.HURT_ATTR_RADIUS == M.g.SIT_ATTR_RADIUS,
        'the attribution radius drifted: lever ' .. tostring(M.g.HURT_ATTR_RADIUS)
        .. ' vs sibling ' .. tostring(M.g.SIT_ATTR_RADIUS))
    assert(M.g.SIT_RING == 1600 and M.g.SIT_TOWER == 1200
        and M.g.SIT_ATTR_RADIUS == 3000 and M.g.SIT_ATTR_WINDOW == 3,
        'the sibling situation constants themselves moved (1600/1200/3000/3.0) -- '
        .. 'equality above would then be two copies of a new number')
end

tests['[source] the shipped predicate was NOT touched -- bound (c)'] = function()
    -- The reverted signature change, asserted so it cannot come back by accident.
    -- Seven detector files parse this function's signature and band as literal
    -- text; a second argument turns all seven red at once.
    assert(M.g.SIT_CALLS_2ARG == 0, 'J.IsFieldRegenSituation is now called with a '
        .. 'second argument. That was tried on 2026-09-06 and reverted: seven '
        .. 'detector files parse its signature or its band as literal text')
    assert(M.g.SIT_CALLS_1ARG == 2, 'J.IsFieldRegenSituation now has '
        .. tostring(M.g.SIT_CALLS_1ARG) .. ' callers, not the 2 this file '
        .. 'measured (J.ShouldRegenNotGoHome, J.ShouldFieldBuyRegen)')
    assert(M.g.HURT_CALLS_SIT == 0, 'the lever now CALLS J.IsFieldRegenSituation. '
        .. 'It is written to repeat the clauses instead, and the drift guard above '
        .. 'is what pays for that; a call means the band cannot be widened without '
        .. 'one of the three rejected edits')
    assert(M.g.SIT_HAS_BUYBAND == 0, "the 'buyband' id appears inside the shared "
        .. 'predicate -- one arm would then move three families at once')
    -- ⭐ This assertion was BOUGHT BY A SURVIVING MUTANT, and the mutant was
    -- mis-aimed: M8's first anchor was a line that occurs twice in jmz_func.lua,
    -- so it inserted a SECOND gated clause into the shared predicate instead of
    -- into the lever -- and nothing in this suite was counting ids there. The
    -- hazard is the one the whole design avoids: J.IsFieldRegenSituation is read
    -- by 'stayfield', 'stayfield2' and 'fieldbuy', so every gate inside it moves
    -- three families on one arm. Exactly one belongs there today ('fieldcreep').
    assert(M.g.SIT_NIDS == 1, 'J.IsFieldRegenSituation now names '
        .. tostring(M.g.SIT_NIDS) .. ' soak ids in code, not 1. Every gate in that '
        .. "body moves THREE families on one arm ('stayfield', 'stayfield2', "
        .. "'fieldbuy') -- the 'lanefix' bundle shape. If an id was legitimately "
        .. 'added, re-read which levers it moves before re-baselining this')
end

tests["[source] one id, one condition -- the 'pullcad' invariant"] = function()
    assert(M.g.HURT_NIDS == 1, 'J.ShouldFieldBuyRegenHurt now names '
        .. tostring(M.g.HURT_NIDS) .. ' soak ids in code; expected exactly 1')
    assert(M.g.HURT_IDS_MAX_PER_COND == 1, 'two ids share one condition in this '
        .. "lever -- the 'pullcad' trap: the gate freezes FALSE the day either id "
        .. 'is promoted')
    -- Honest bound (4), from both sides: the creep veto is still the sibling's and
    -- still not copied here.
    assert(M.g.SIT_HAS_FIELDCREEP == 1, "the 'fieldcreep' veto left "
        .. 'J.IsFieldRegenSituation -- if it was PROMOTED, this lever must inherit '
        .. 'it (it can be copied safely once no id names it); re-read bound (4)')
    assert(M.g.HURT_HAS_FIELDCREEP == 0, "this lever now names 'fieldcreep', which "
        .. 'freezes that clause FALSE the day that id is promoted')
end

tests['[source] the wiring is an OR arm, not a replacement'] = function()
    assert(M.g.WIRE_HURT == 1, 'the lever is not consulted at the purchase site in '
        .. PURCHASE .. ' -- an unwired predicate ships nothing')
    assert(M.g.WIRE_BUY == 1, "the 'fieldbuy' arm disappeared from the purchase "
        .. 'site; this lever was added ALONGSIDE it, not in place of it')
    assert(M.g.WIRE_OR == 1, 'the two arms are no longer a plain OR at the purchase '
        .. 'site -- the direction argument (arming can only add TRUEs) rests on '
        .. 'that shape')
    assert(M.g.WIRE_PURCHASES_FLASK == 1, 'the guarded block no longer buys a '
        .. 'flask')
    -- One arming point in code, so the behaviour cannot ship through a second site
    -- nobody gated. Comments are stripped first: this lever's own comment names
    -- 'buyband' several times while explaining it.
    local code = (read_file(JMZ) .. read_file(PURCHASE)):gsub('%-%-[^\n]*', '')
    local _, n = code:gsub("'buyband'", '')
    assert(n == 1, "'buyband' appears " .. n .. ' times in CODE across the two '
        .. 'files that decide this purchase; expected 1')
end

-- --------------------------------------------------------- the census ------

tests['[census] the corpus, and the three-way split of what the veto refuses'] =
function()
    cs.corpus(C('fixtures'), 'buyband fixture corpus')
    cs.ratchet(C('live'), 1012, 'live hero frames')
    cs.universal(C('turbo'), C('live'), 'every corpus frame is turbo', cs.FLOOR)
    assert(C('raises') == 0, C('raises') .. ' frames raised inside a driven call '
        .. '-- a raised frame is not a measured frame')
    cs.ratchet(C('stay_reach'), 125, "frames reaching the veto's supply clause")
    cs.ratchet(C('stay_blocked'), 112, 'frames the supply clause vetoes')
    -- The split is an IDENTITY, not three independent counts: every vetoed frame
    -- carries a main-slot source, a backpacked salve, or nothing. If these stop
    -- summing, one of the three buckets is being double-counted and the "66 frames
    -- nobody owns" claim is arithmetic, not evidence.
    assert(C('blocked_main_src') + C('blocked_bag_salve') + C('blocked_nosrc')
        == C('stay_blocked'),
        string.format('the three-way split no longer sums: %d + %d + %d ~= %d',
            C('blocked_main_src'), C('blocked_bag_salve'), C('blocked_nosrc'),
            C('stay_blocked')))
    cs.ratchet(C('blocked_nosrc'), 66, 'vetoed frames carrying nothing drinkable')
end

tests['[census] 18 of those are blocked by the 0.55 ceiling and nothing else'] =
function()
    -- The domain price, and the reason this lever exists rather than some other
    -- one. The other two causes are counted in the same walk so "the ceiling is
    -- the problem" is a comparison, not an assertion.
    cs.ratchet(C('ns_hp_gt_floor'), 28, 'empty-handed vetoed frames above 0.55')
    cs.ratchet(C('ns_only_ceiling_blocks'), 18,
        'empty-handed frames blocked by the ceiling ALONE')
    cs.ratchet(C('ns_ring_busy'), 11, 'empty-handed frames blocked by the ring')
    cs.ratchet(C('ns_tower'), 10, 'empty-handed frames blocked by a tower')
    assert(C('ns_hp_le_floor') + C('ns_hp_gt_floor') == C('blocked_nosrc'),
        'the HP split of the empty-handed frames no longer sums')
    assert(#M.census >= 18, 'the sweep listed ' .. #M.census .. ' ceiling-blocked '
        .. 'frames but counted ' .. C('ns_only_ceiling_blocks'))
    -- Anti-vacuum: every listed frame really is above the ceiling and inside the
    -- promoted veto's band. A census whose rows do not satisfy its own predicate
    -- is a broken sweep, not a finding.
    for _, r in ipairs(M.census) do
        assert(r.hp > M.g.SIT_HP_HI and r.hp <= M.g.STAY_HP_HI,
            string.format('census row %s/%s at %.4f is outside the unowned band',
                r.fixture, r.hero, r.hp))
    end
end

tests['[census] the driven flip set and the prefix walk agree'] = function()
    -- Two routes to the same number: one from the call-site predicate's own return
    -- values, one from an independent walk of the clauses in the lever's order.
    -- They are computed separately and must agree; that is what makes either of
    -- them evidence.
    cs.ratchet(C('flips_buyband'), 20, "frames 'buyband' flips, armed alone")
    assert(C('flips_buyband') == C('hurt_domain'),
        string.format('the driven flip count (%d) and the prefix walk (%d) '
            .. 'disagree -- one of them is measuring something else',
            C('flips_buyband'), C('hurt_domain')))
    assert(#M.flips == C('hurt_domain'), 'the sweep listed ' .. #M.flips
        .. ' flip rows but counted ' .. C('hurt_domain'))
    -- ⭐ The single-arm visibility claim, and the whole reason for the design.
    -- A zero here means the lever is unbuyable one arm at a time (edit (b)), not
    -- that the corpus is thin -- `hurt_domain` above is what tells those apart.
    assert(C('flips_buyband') > 0, 'ZERO frames flip with only this id armed. A '
        .. 'single-arm isolation wave would read a correct zero and the behaviour '
        .. 'could not be bought one lever at a time -- which is exactly the failure '
        .. 'this design was chosen to avoid (GH #542)')
    -- Bound (3), as an identity rather than as a difference of totals nobody
    -- explains: the domain is the ceiling-blocked slice plus two named residues.
    assert(C('hurt_domain') == C('ns_only_ceiling_blocks')
        + C('hurt_outside_stay_reach') + C('hurt_with_bag_salve'),
        string.format('the domain no longer decomposes: %d ~= %d + %d + %d',
            C('hurt_domain'), C('ns_only_ceiling_blocks'),
            C('hurt_outside_stay_reach'), C('hurt_with_bag_salve')))
    assert(C('hurt_outside_stay_reach') == C('hurt_outside_by_unattr_chase'),
        'a domain frame is outside the promoted veto\'s reach set for some reason '
        .. "other than its unattributed chase read -- bound (3) names 'stayattr' "
        .. 'as the whole explanation and no longer covers it')
end

tests['[census] direction, disjointness and the arming width'] = function()
    -- Widening a call site by ORing an arm in can only ADD trues. Asserted, so a
    -- future edit that inverts a clause cannot hide behind a net-positive count.
    assert(C('flip_true_to_false') == 0, C('flip_true_to_false') .. ' frames went '
        .. 'TRUE -> FALSE when the lever was armed. The call site ORs this arm in, '
        .. 'so that is structurally impossible -- something else moved')
    -- The two arms partition by HP, so no frame can be credited to both ids.
    assert(C('overlap_buy_hurt') == 0, C('overlap_buy_hurt') .. ' frames are '
        .. "accepted by BOTH 'fieldbuy' and 'buyband'. The domains are supposed to "
        .. 'be disjoint by construction (<= 0.55 against > 0.55), so an isolation '
        .. 'wave could credit one id with the other id\'s behaviour')
    assert(C('flips_fieldbuy') > 0, "the 'fieldbuy' arm flips nothing on this "
        .. 'corpus -- the disjointness above would then be vacuous')
    -- ...and the disjointness probe PROVED it ran. A zero whose whole content is
    -- "we looked and found none" reads identically to "we stopped looking"
    -- (GH #171), so the probe's own drive count is asserted against the corpus.
    cs.universal(C('overlap_probe_runs'), C('live'),
        'the overlap probe drove every live frame', cs.FLOOR)
    assert(C('arm_leak') == 0, 'the sweep armed more than one id: a bundle answer '
        .. 'cannot be attributed to this lever')
    -- Honest bound (4): how wide the un-copied creep veto's disagreement is.
    assert(C('hurt_with_creep_damage') == 0, C('hurt_with_creep_damage')
        .. " domain frames now carry creep damage, so the 'fieldcreep' clause this "
        .. 'lever deliberately does not copy is no longer empty on this corpus. '
        .. 'Bound (4) claimed it was; re-read it rather than re-baselining')
end

-- ------------------------------------------------- the frames, driven ------

tests['[frame] the pinned frame: drow at 63.9% buys instead of walking'] = function()
    local J, bot, arm = frame(FX, SUBJ)
    local nHP = J.GetHP(bot)
    assert(math.abs(nHP - 0.6389) < 5e-4, 'the pinned frame moved: HP is '
        .. tostring(nHP) .. ', expected 0.6389')
    -- It is IN the unowned band, which is the whole reason it is pinned.
    assert(nHP > M.g.SIT_HP_HI and nHP <= M.g.STAY_HP_HI,
        'the pinned frame is no longer inside the unowned band')
    -- The promoted veto lets it go: that is the behaviour P2 forbids, and it is
    -- read off the shipped function rather than described.
    assert(J.ShouldStayAndRegen(bot) == false,
        'the promoted veto now HOLDS this bot, so nothing releases it to go home '
        .. 'and the lever has no gap to fill on this frame')
    -- Nothing to drink, so this is the supply side's frame, not a supply-read bug.
    assert(J.HasFieldRegenSource(bot) == false,
        'the pinned bot now carries something drinkable -- this frame belongs to '
        .. "'staysrc' / 'staybag', not here")
    assert(site(J, bot) == false, 'the shipped purchase predicate already fires '
        .. 'here; there would be nothing for this lever to add')
    arm(true)
    assert(site(J, bot) == true, 'armed, the purchase predicate still refuses the '
        .. 'pinned frame -- the lever does not fire on the frame that motivated it')
    arm(false)
    assert(site(J, bot) == false, 'disarming does not restore the shipped answer: '
        .. 'the gate is not the only thing deciding')
end

tests['[frame] the second frame, near the other end of the band'] = function()
    local J, bot, arm = frame(FX2, SUBJ2)
    local nHP = J.GetHP(bot)
    assert(math.abs(nHP - 0.7458) < 5e-4, 'the second frame moved: HP is '
        .. tostring(nHP))
    assert(nHP > M.g.SIT_HP_HI and nHP <= M.g.STAY_HP_HI,
        'the second frame left the unowned band')
    assert(site(J, bot) == false, 'shipped already fires on the second frame')
    arm(true)
    assert(site(J, bot) == true, 'the lever does not fire near the top of its own '
        .. 'band -- the finding is one HP value wide')
end

tests['[frame] in-band controls an inherited clause must still refuse'] = function()
    for _, ctl in ipairs(BLOCKED) do
        local J, bot, arm = frame(ctl.fx, ctl.subj)
        local nHP = J.GetHP(bot)
        assert(math.abs(nHP - ctl.hp) < 5e-4, ctl.fx .. ' moved: HP is '
            .. tostring(nHP) .. ', expected ' .. tostring(ctl.hp))
        assert(nHP > M.g.SIT_HP_HI and nHP <= M.g.STAY_HP_HI,
            ctl.fx .. ' left the band, so it is no longer a control for this lever')
        arm(true)
        assert(site(J, bot) == false, ctl.fx .. ' (' .. ctl.why .. ') now BUYS. '
            .. 'This frame is in the band and empty-handed, so the only thing that '
            .. 'was refusing it is the clause this lever inherited unchanged -- it '
            .. 'is being credited with work the ring/tower clauses do')
    end
end

tests['[frame] out of band on the high side: a healthy bot never buys'] = function()
    local J, bot, arm = frame(OOB_HIGH.fx, OOB_HIGH.subj)
    assert(math.abs(J.GetHP(bot) - OOB_HIGH.hp) < 5e-4, 'the high control moved')
    arm(true)
    assert(site(J, bot) == false, 'a bot at full HP now buys a field salve -- the '
        .. 'ceiling this lever borrowed from the promoted veto is not holding')
end

tests['[frame] out of band on the low side: that frame is fieldbuy\'s'] = function()
    -- The disjointness control, driven rather than argued from the constants.
    local J, bot = rf.load(OOB_LOW.fx, OOB_LOW.subj)
    assert(math.abs(J.GetHP(bot) - OOB_LOW.hp) < 5e-4, 'the low control moved')
    J.IsSoakCandidate = function(s) return s == 'buyband' end
    assert(J.ShouldFieldBuyRegenHurt(bot) == false,
        'this lever accepts a frame below its own floor -- the two domains overlap '
        .. 'and an isolation wave cannot tell the two ids apart')
    J.IsSoakCandidate = function(s) return s == 'fieldbuy' end
    assert(J.ShouldFieldBuyRegen(bot) == true,
        "the low control is no longer 'fieldbuy''s frame, so it proves nothing "
        .. 'about the partition')
end

tests['[frame] unarmed, the lever is inert on every frame it would flip'] =
function()
    -- Gated means gated: the shipped answer on all 20 domain frames must be
    -- unchanged with nothing armed. Driven over the listed rows rather than
    -- asserted once, because "inert" is a claim about the whole flip set.
    local nChecked = 0
    for _, r in ipairs(M.flips) do
        local J, bot = rf.load('tests/fixtures/' .. r.fixture .. '.lua', r.hero)
        J.IsSoakCandidate = function() return false end
        assert(site(J, bot) == false, r.fixture .. '/' .. r.hero
            .. ' answers TRUE with NOTHING armed -- the behaviour is shipping')
        nChecked = nChecked + 1
    end
    assert(nChecked == C('hurt_domain'), 'only ' .. nChecked .. ' of '
        .. C('hurt_domain') .. ' domain frames were re-checked unarmed')
end

return tests

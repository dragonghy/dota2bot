-- [buydeep 2026-09-08, 协同组] Owner priority P2: a hurt bot in no danger must NOT
-- go home -- "血量低也尽量不要回程,买大药或其他补给". This file is about the second
-- half of that sentence at the ONE health where the family has never been allowed
-- to say it: below its own floor.
--
-- ⭐ THE FINDING, AND IT IS THE LAST FREE CLAUSE OF ONE PREDICATE.
-- J.IsFieldRegenSituation decides whether the field alternative is offered at all,
-- and it has four clauses -- a floor, a ceiling, a ring and a tower. Three of the
-- four have now each been answered by their own standalone purchase arm, each time
-- for the same reason: the clause carries a rationale written for the HOLD side and
-- inherited by a consumer that cancels nothing ('buyband' the ceiling, 'buytower'
-- the tower, 'buyring' the ring). This is the fourth. The floor is
-- `nHP < 0.18 -> false`, and the sibling's own comment gives its reason in its own
-- words: "Hurt enough that the bot wants to leave, not so hurt that the next stray
-- creep wave kills it. BELOW THE FLOOR THE GENUINE ESCAPE RETREAT STANDS." That is
-- an argument about not cancelling a retreat bid, which is what
-- J.ShouldRegenNotGoHome's two wrappers do. A purchase cancels no bid: a bot that
-- buys a salve at 12% HP and retreats anyway arrives carrying it.
--
-- ⭐⭐ THE READING THAT SENT THIS ROUND HERE WAS WRONG, AND THE CORRECTION IS THE
-- POINT. tests/_tpdeep_sweep.lua left `stop_source 8` behind -- eight frames inside
-- the '回复状态' branch trigger, inside the deep band, that the DECISION side
-- refuses because the bot has nothing to drink -- and the charter named it as this
-- round's next candidate with an explicit warning attached: 8 says "no supply", it
-- does not say "safe". Priced first, as the charter requires: five of the eight are
-- refused by clauses this arm KEEPS (all five by the 1600 ring; three of those five
-- also carry attributed hero damage, which the prefix walk therefore never files
-- under attribution -- `stop_source_attr_any` is the order-free column that says
-- so). The branch-trigger slice of this lever's domain is **3**, not 8.
--
-- ⭐⭐⭐ THE DOMAIN, MEASURED OVER THE WHOLE CORPUS RATHER THAN THAT BRANCH -- the
-- purchase site does not care which branch is bidding. Of 1021 live turbo hero
-- frames, **29** sit below the floor, **12** of those carry nothing drinkable in a
-- main slot, and **6** of the 12 clear the ring, attribution and tower clauses this
-- arm inherits unchanged. 6 is the domain, and it is reached two independent ways
-- that must agree: a driven single-arm flip count at the call site
-- (`flips_buydeep`) and an independent prefix walk (`deep_domain`).
--
-- The bearing frame is tests/fixtures/f_181441_zuus_lowhp_limbo.lua -- the fixture
-- is named for the very detector the 'fieldregen' block cites as its acceptance
-- metric. A level-12 zuus at 214/1354 = 15.81% HP, the nearest enemy hero 2,016.8
-- units away, no enemy tower anywhere in the world, no hero damage in the last 3
-- seconds, carrying perseverance / arcane_boots / magic_wand and an EMPTY bottle.
-- Nothing drinkable: J.HasFieldRegenSource accepts a bottle only with charges, and
-- this one is item_empty_bottle. Shipped, all four existing buy arms refuse him --
-- not because he is in danger, and not because he is supplied, but because he is
-- TOO HURT for a predicate whose floor was written to protect a retreat he is not
-- making.
--
-- ⭐⭐⭐⭐ THE BOTTOM EDGE IS ABSENT ON PURPOSE, AND THAT IS ARITHMETIC.
-- J.ShouldDeepSipNotTpRecover ('tpdeep', the DECISION-side lever in this same band,
-- landed earlier the same day) carries a 0.10 bottom, and its own block gives the
-- reason: a field sip is 115 (tango) / 85 (faerie fire) / 135 (a bottle charge), so
-- below `0.18 - sip/MaxHealth` one sip can no longer lift the bot back over the
-- family's floor. A SALVE IS 400 -- 0.29 to 0.44 of max health across the 900-1400
-- level-6+ turbo range that arithmetic is built on -- so `nHP + 400/MaxHealth >=
-- 0.18` holds at every health in this band, including zero. Copying the sibling's
-- constant would have discarded HALF this arm's domain (`deep_below_tpdeep_floor`
-- is 3 of the 6). The absence is pinned STRUCTURALLY (`DEEP_NO_LOW_EDGE`) and never
-- by that count -- a domain count is what a later round re-baselines; an absent
-- clause is what it "harmonises" in without noticing.
--
-- ⭐⭐⭐⭐⭐ DISJOINTNESS IS AN INVERTED CLAUSE, NOT A BAND SPLIT. All four sibling
-- arms require `nHP >= 0.18` -- 'fieldbuy' through J.IsFieldRegenSituation, the
-- other three in their own first band statement -- and this one requires
-- `nHP < 0.18`. Every one of those four floors is parsed out of its own function
-- here, so "the five arms are disjoint" is arithmetic between five constants rather
-- than a sentence, and the four overlap columns are asserted 0 on top of it.
--
-- Honest bounds, as columns rather than promises:
--   (1) What is measured is a PURCHASE PREDICATE turning true, not a trip home
--       being cancelled and not a salve being bought: the nine engine clauses
--       guarding ActionImmediate_PurchaseItem (stock, gold, stash, courier
--       distance, empty slot) are unreadable from a fixture, and gold is not
--       networked into a .dem at all (GH #495). `WIRE_*` asserts the wiring exists;
--       nothing here asserts the purchase happens.
--   (2) One of the six domain frames carries a salve in the BACKPACK
--       (`deep_with_bag_salve`): J.HasFieldRegenSource stops at slot 5, and the
--       call site catches it with `bot:FindItemSlot` instead -- the GH #123
--       asymmetry all four siblings carry, unchanged in kind.
--   (3) The one clause of J.IsFieldRegenSituation this function deliberately does
--       NOT copy is the gated 'fieldcreep' creep-damage veto: naming another
--       candidate's id in this body would freeze the clause FALSE the day that id
--       is promoted (the pullcad trap). The width of the resulting disagreement is
--       `deep_with_creep_damage`, measured below rather than promised.

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')
local cs = require('corpus_scale')

local SWEEP = 'lua5.1 tests/_buydeep_sweep.lua 2>/dev/null'
local JMZ = 'bots/FunLib/jmz_func.lua'
local PURCHASE = 'bots/item_purchase_generic.lua'

-- The pinned frame: level-12 zuus at 15.81% HP, nearest enemy 2,016.8, empty
-- bottle. The fixture is the lowhp_limbo one by name.
local FX = 'tests/fixtures/f_181441_zuus_lowhp_limbo.lua'
local SUBJ = 'npc_dota_hero_zuus'
-- A second frame, on another fixture and BELOW the decision-side lever's 0.10
-- bottom, so the finding is neither one fixture nor one HP value wide -- and so the
-- deliberate absence of a bottom edge is pinned on a frame that needs it. A
-- level-11 centaur at 180/1875 = 9.60% HP with the nearest enemy 3,100.8 away.
local FX2 = 'tests/fixtures/f_631400_dragon_knight_snowballtarget.lua'
local SUBJ2 = 'npc_dota_hero_centaur'

-- Negative controls. Both are BELOW the floor and carrying nothing, so the only
-- thing that can refuse them is a clause this lever inherited UNCHANGED. If either
-- flips, the lever is being credited with work those clauses do.
local BLOCKED = {
    -- Inside the inherited 1600 ring: a level-4 chaos_knight at 11.80% HP with two
    -- enemies in the ring, the nearest 361.5 units off. This is a fight.
    { fx = 'tests/fixtures/f_231411_ck_zoned.lua',
      subj = 'npc_dota_hero_chaos_knight', hp = 0.1180, why = 'ring' },
    -- An ember_spirit at 14.20% HP that carries ATTRIBUTED hero damage as well --
    -- and the label is 'ring+attr', not 'attr', because this corpus has NO frame
    -- refused by attribution alone (`nosrc_attr_only == 0`, asserted in the census
    -- below). Naming it 'attr' would be a control whose stated reason is not the
    -- reason it passes, which is the failure this suite calls a matching conclusion
    -- standing in for a correct one. So it is a second, independent ring control
    -- that additionally exercises the attribution clause, and the honest statement
    -- is that the attribution clause has no dedicated control here.
    { fx = 'tests/fixtures/f_260819_181742_ss_chase_stalled.lua',
      subj = 'npc_dota_hero_ember_spirit', hp = 0.1420, why = 'ring+attr' },
}
-- The disjointness control, and it is the load-bearing one for an INVERTED clause:
-- a frame just ABOVE the floor that 'fieldbuy' owns. 'buydeep' must refuse it while
-- 'fieldbuy' still accepts it -- 0.2250, four points above the edge.
local ABOVE_FLOOR = { fx = 'tests/fixtures/f_073148_zuus_lina.lua',
    subj = 'npc_dota_hero_luna', hp = 0.2250 }

local tests = {}

local M = (function()
    local p = assert(io.popen(SWEEP, 'r'))
    local raw = p:read('*a')
    p:close()
    local m = { g = {}, c = {}, flips = {}, refused = {}, src8 = {}, done = false }
    for line in raw:gmatch('[^\n]+') do
        local k, v = line:match('^G (%S+) (%S+)$')
        if k ~= nil then m.g[k] = tonumber(v) or v end
        local ck, cv = line:match('^C (%S+) (%-?%d+)$')
        if ck ~= nil then m.c[ck] = tonumber(cv) end
        local ff, fh, fp = line:match('^F (%S+) (%S+) ([%d%.]+)$')
        if ff ~= nil then
            m.flips[#m.flips + 1] = { fixture = ff, hero = fh, hp = tonumber(fp) }
        end
        local bf, bh, bp, bw = line:match('^B (%S+) (%S+) ([%d%.]+) (%S+)$')
        if bf ~= nil then
            m.refused[#m.refused + 1] =
                { fixture = bf, hero = bh, hp = tonumber(bp), why = bw }
        end
        local sf, sh, sp, sw = line:match('^S (%S+) (%S+) ([%d%.]+) (%S+)$')
        if sf ~= nil then
            m.src8[#m.src8 + 1] =
                { fixture = sf, hero = sh, hp = tonumber(sp), why = sw }
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
    J.IsSoakCandidate = function(s) return armed and s == (sId or 'buydeep') end
    return J, bot, function(b) armed = b end
end

--- The CALL SITE's predicate, as the call site itself spells it: the OR of the
--- five arms. Driving this rather than the new function alone is what makes
--- "arming can only add TRUEs" a statement about the shipped decision instead of
--- about a helper nobody calls.
local function site(J, bot)
    return (J.ShouldFieldBuyRegen(bot) or J.ShouldFieldBuyRegenHurt(bot)
        or J.ShouldFieldBuyRegenTower(bot) or J.ShouldFieldBuyRegenRing(bot)
        or J.ShouldFieldBuyRegenDeep(bot)) and true or false
end

-- --------------------------------------------------- the tree, as source ---

tests['[source] the lever is where this file says it is'] = function()
    assert(M.done, 'the sweep subprocess did not finish (no DONE line) -- every '
        .. 'number below would be a silent zero')
    assert(M.g.SIT == 1, 'the sweep could not slice J.IsFieldRegenSituation out of '
        .. JMZ)
    assert(M.g.DEEP == 1, 'the sweep could not slice J.ShouldFieldBuyRegenDeep out '
        .. 'of ' .. JMZ)
    assert(M.g.TPDEEP == 1, 'the sweep could not slice J.ShouldDeepSipNotTpRecover '
        .. 'out of ' .. JMZ .. ' -- the bottom-edge arithmetic below is a comparison '
        .. 'against THAT lever, and it cannot be made against nothing')
    -- The stripping must have HAPPENED. This lever ships with a long comment that
    -- names its own id, both radii, the floor and every sibling, so reading the raw
    -- block would let the COMMENT satisfy the assertions below (the §EN mistake).
    assert(M.g.DEEP_STRIPPED == 1, 'comments were not stripped from the new helper '
        .. '-- every source assertion below could be satisfied by its own prose')
    assert(M.g.SIT_STRIPPED == 1, 'comments were not stripped from '
        .. 'J.IsFieldRegenSituation')
    assert(M.g.DEEP_SOAKID == 1, "the helper no longer carries the 'buydeep' gate "
        .. '-- an ungated behaviour change ships in every live game')
    assert(M.g.DEEP_TURBO == 1, 'turbo is no longer asked structurally: nothing on '
        .. 'the purchase path asks it for this arm')
    assert(M.g.DEEP_GATE_FIRST == 1, 'the gate is no longer the first thing asked '
        .. '-- unarmed, the shipped answer must short-circuit before any engine call')
end

tests['[source] the floor IS the lever, and its owner still owns it'] = function()
    -- The one moved clause, read off both bodies. If the sibling ever moves its
    -- floor, this file goes red instead of the lever quietly measuring a different
    -- band.
    assert(M.g.SIT_HP_LO == 0.18, 'J.IsFieldRegenSituation no longer floors at '
        .. '0.18 (reads ' .. tostring(M.g.SIT_HP_LO) .. ') -- this lever is the '
        .. 'inversion of THAT number and must move with it')
    assert(M.g.DEEP_FLOOR == M.g.SIT_HP_LO, string.format(
        'the lever floors at %s while the predicate it inverts floors at %s -- the '
        .. 'two are no longer the same edge, so the five arms are no longer a '
        .. 'partition', tostring(M.g.DEEP_FLOOR), tostring(M.g.SIT_HP_LO)))
    -- ⛔ THE DELIBERATE ABSENCE. There is no bottom edge, and the reason is
    -- arithmetic (a salve is 400 against a 115-135 field sip), not an oversight.
    -- Pinned structurally so a later round cannot "harmonise" the sibling's 0.10 in.
    assert(M.g.DEEP_NO_LOW_EDGE == 1, 'a LOWER edge appeared in '
        .. 'J.ShouldFieldBuyRegenDeep. There is none by construction: a salve is '
        .. '400 health, so one purchase lifts the bot back over 0.18 at every '
        .. 'health in this band, which is exactly why the decision-side sibling '
        .. 'needs a 0.10 bottom and this arm does not')
    -- ⛔ ANCHOR UNIQUENESS IS PART OF THIS DECLARATION (GH #550). The `local nHP`
    -- two-liner would be byte-identical to J.ShouldDeepSipNotTpRecover's band
    -- edge, which tools/agent/mutstand_tpdeep.sh anchors its M5 on -- so tidying
    -- this line into a local would abort a SIBLING stand for a lever this one says
    -- nothing about. Asserted here, where the change is made, rather than let the
    -- failure surface over there where it would be misattributed.
    assert(M.g.DEEP_FLOOR_INLINE == 1, 'the floor is no longer spelt inline as '
        .. '`J.GetHP( bot ) >= 0.18`. The `local nHP` form is byte-identical to '
        .. "the decision-side sibling's band edge, and mutstand_tpdeep.sh's M5 "
        .. 'anchor would become AMBIGUOUS -- aborting that stand for a change '
        .. 'that has nothing to do with it')
    assert(M.g.TPDEEP_BAND_LINE_COUNT == 1, 'the line `if nHP >= 0.18 then return '
        .. 'false end` now occurs ' .. tostring(M.g.TPDEEP_BAND_LINE_COUNT)
        .. ' times in ' .. JMZ .. '; mutstand_tpdeep.sh anchors on it and treats '
        .. 'ambiguity as a stand failure')
    assert(M.g.TPDEEP_LOW_EDGE == 0.10, 'the decision-side sibling '
        .. "J.ShouldDeepSipNotTpRecover no longer bottoms at 0.10 (reads "
        .. tostring(M.g.TPDEEP_LOW_EDGE) .. ') -- the absence asserted just above '
        .. 'is a DIFFERENCE between two levers, and the comparison needs both')
end

tests['[source] all five arms partition one band, by parsed constants'] = function()
    -- Disjointness is arithmetic between five numbers read out of five bodies, not
    -- a claim. 'fieldbuy' inherits its floor from J.IsFieldRegenSituation; the other
    -- three state their own; this one inverts it.
    for _, pair in ipairs({ { 'SIT_HP_LO', 'fieldbuy (via J.IsFieldRegenSituation)' },
        { 'HURT_HP_LO', 'buyband' }, { 'TOW_HP_LO', 'buytower' },
        { 'RING_HP_LO', 'buyring' } }) do
        assert(M.g[pair[1]] == 0.18, string.format(
            'the %s arm no longer requires nHP >= 0.18 (its floor reads %s). All '
            .. "four siblings must, or this arm's inverted floor stops making the "
            .. 'five domains disjoint by construction', pair[2],
            tostring(M.g[pair[1]])))
    end
    assert(M.g.SIT_HP_HI == 0.55, 'the sibling ceiling moved to '
        .. tostring(M.g.SIT_HP_HI) .. "; 'buyband' owns the band above it and this "
        .. 'file registers the partition it belongs to')
end

tests['[source] the copied clauses have not drifted'] = function()
    -- Three clauses are DUPLICATED from J.IsFieldRegenSituation rather than called,
    -- for the reasons the helper's own block records. Duplication that can drift is
    -- paid for where it can be seen: every constant is compared against the body
    -- that owns it.
    assert(M.g.DEEP_RING == M.g.SIT_RING, string.format(
        'the ring drifted: this lever reads %s, J.IsFieldRegenSituation reads %s',
        tostring(M.g.DEEP_RING), tostring(M.g.SIT_RING)))
    assert(M.g.DEEP_TOWER == M.g.SIT_TOWER, string.format(
        'the tower radius drifted: %s vs %s', tostring(M.g.DEEP_TOWER),
        tostring(M.g.SIT_TOWER)))
    assert(M.g.DEEP_ATTR_WINDOW == M.g.SIT_ATTR_WINDOW, string.format(
        'the attribution window drifted: %s vs %s',
        tostring(M.g.DEEP_ATTR_WINDOW), tostring(M.g.SIT_ATTR_WINDOW)))
    assert(M.g.DEEP_ATTR_RADIUS == M.g.SIT_ATTR_RADIUS, string.format(
        'the attribution radius drifted: %s vs %s',
        tostring(M.g.DEEP_ATTR_RADIUS), tostring(M.g.SIT_ATTR_RADIUS)))
    -- ...and all three are kept in their SHIPPED direction. The ONLY inverted
    -- clause is the floor; a second inversion would be a second lever.
    assert(M.g.DEEP_RING_PLAIN == 1 and M.g.SIT_RING_PLAIN == 1,
        'the ring clause is no longer the shipped `> 0 then return false` in both '
        .. "bodies -- inverting a second clause would make this two levers, and the "
        .. 'disjointness argument names only the floor')
    assert(M.g.DEEP_TOWER_PLAIN == 1 and M.g.SIT_TOWER_PLAIN == 1,
        'the tower clause is no longer the shipped form in both bodies')
    assert(M.g.DEEP_CALLS_SIT == 0, 'the lever now CALLS J.IsFieldRegenSituation -- '
        .. 'that predicate floors at 0.18, so this arm would be frozen empty')
    assert(M.g.DEEP_CALLS_DAMAGER == 0, 'the lever now routes its attribution scan '
        .. 'through J.HasNearbyHeroDamager, whose one-caller invariant '
        .. 'tests/test_stayattr_global_ult.lua asserts BY COUNT')
end

tests['[source] the shipped predicate was NOT touched'] = function()
    -- Lowering the floor inside J.IsFieldRegenSituation would move 'stayfield',
    -- 'stayfield2' and 'fieldbuy' on one arm -- the 'lanefix' bundle shape -- and
    -- unlike the ceiling or the ring it would reach the HOLD side at a health where
    -- the tree's own comment says the escape retreat is correct.
    assert(M.g.SIT_NIDS == 1, 'J.IsFieldRegenSituation now carries '
        .. tostring(M.g.SIT_NIDS) .. " soak gates; exactly one ('fieldcreep') is "
        .. 'expected. A gate there moves three families on one arm')
    assert(M.g.SIT_HAS_BUYDEEP == 0, "'buydeep' now appears inside the SHARED "
        .. 'predicate -- this lever is a separate function precisely so it does not')
    assert(M.g.SIT_HAS_FIELDCREEP == 1, "the 'fieldcreep' veto left "
        .. 'J.IsFieldRegenSituation; the bound registered below is about the '
        .. 'disagreement between that clause and this arm, and it needs the clause')
    assert(M.g.DEEP_HAS_FIELDCREEP == 0, "the lever now names 'fieldcreep'. That "
        .. 'freezes the clause FALSE the day that id is promoted -- the pullcad trap')
end

tests["[source] one id, one condition -- the 'pullcad' invariant"] = function()
    assert(M.g.DEEP_NIDS == 1, 'the helper carries ' .. tostring(M.g.DEEP_NIDS)
        .. ' soak gates; exactly 1 is expected')
    assert(M.g.DEEP_IDS_MAX_PER_COND == 1, 'a condition in the helper now names '
        .. tostring(M.g.DEEP_IDS_MAX_PER_COND) .. ' soak ids. Two ids in one '
        .. 'condition is the pullcad trap: promoting either freezes the other FALSE')
    -- One arming point in CODE, so the behaviour cannot ship through a second site
    -- nobody gated. Comments are stripped first: this lever's own comment names
    -- 'buydeep' while explaining it.
    local code = (read_file(JMZ) .. read_file(PURCHASE)):gsub('%-%-[^\n]*', '')
    local _, n = code:gsub("'buydeep'", '')
    assert(n == 1, "'buydeep' appears " .. n .. ' times in CODE across the two '
        .. 'files that decide this purchase; expected 1')
end

tests['[source] the wiring is a FIFTH OR arm, not a replacement'] = function()
    assert(M.g.WIRE_DEEP == 1, 'the lever is not consulted at the purchase site in '
        .. PURCHASE .. ' -- an unwired predicate ships nothing')
    for _, pair in ipairs({ { 'WIRE_BUY', 'fieldbuy' }, { 'WIRE_HURT', 'buyband' },
        { 'WIRE_TOW', 'buytower' }, { 'WIRE_RING', 'buyring' } }) do
        assert(M.g[pair[1]] == 1, 'the ' .. pair[2] .. ' arm disappeared from the '
            .. 'purchase site; this lever was added ALONGSIDE it, not in place of it')
    end
    assert(M.g.WIRE_OR5 == 1, 'the five arms are no longer one OR at the purchase '
        .. 'site -- the direction argument (arming can only add TRUEs) rests on '
        .. 'that shape')
    assert(M.g.WIRE_DEEP_CALLS == 1, 'the lever has '
        .. tostring(M.g.WIRE_DEEP_CALLS) .. ' call sites in ' .. PURCHASE
        .. ', not 1 -- a second site would ship the behaviour through a path this '
        .. 'file never drives')
    assert(M.g.DEEP_DEFS_IN_JMZ == 1, 'J.ShouldFieldBuyRegenDeep is referenced '
        .. tostring(M.g.DEEP_DEFS_IN_JMZ) .. ' times inside ' .. JMZ
        .. ' (definition only expected) -- an internal caller would bypass the call '
        .. 'site this file drives')
    assert(M.g.WIRE_PURCHASES_FLASK == 1, 'the guarded block no longer buys a flask')
end

-- --------------------------------------------------------- the census ------

tests['[census] the corpus, and what holds the empty-handed frames out'] = function()
    cs.corpus(C('fixtures'), 'buydeep fixture corpus')
    cs.ratchet(C('live'), 1021, 'live hero frames')
    cs.universal(C('turbo'), C('live'), 'every corpus frame is turbo', cs.FLOOR)
    assert(C('raises') == 0, C('raises') .. ' frames raised inside a driven call '
        .. '-- a raised frame is not a measured frame')
    cs.ratchet(C('below_floor'), 29, 'frames below the 0.18 floor')
    cs.ratchet(C('below_floor_nosrc'), 12,
        'below-floor frames carrying nothing drinkable')
    cs.ratchet(C('nosrc_ring_busy'), 6, 'held out by the inherited 1600 ring')
    cs.ratchet(C('nosrc_attr'), 4, 'held out by attributed hero damage')
    -- ⭐ The partition closes: the refusals and the domain must account for every
    -- empty-handed below-floor frame, or one of the three is measuring a different
    -- set. Written as a subtraction rather than as three independent pins.
    assert(C('below_floor_nosrc') - C('nosrc_ring_busy') == C('deep_domain'),
        string.format('the partition does not close: %d empty-handed frames minus '
        .. '%d refused by the ring is not the %d in the domain -- the attribution '
        .. 'or tower clause has started refusing a frame the ring does not',
        C('below_floor_nosrc'), C('nosrc_ring_busy'), C('deep_domain')))
    -- ...and the reason that subtraction is allowed to ignore attribution is a
    -- measured zero, not an assumption: on this corpus attribution refuses NOTHING
    -- the ring has not already refused. A claim whose whole content is a zero stays
    -- an equality (corpus_scale's own rule) so it goes red on a counter-example.
    assert(C('nosrc_attr_only') == 0, C('nosrc_attr_only') .. ' below-floor frames '
        .. 'are refused by ATTRIBUTION ALONE. That was 0 when this lever was '
        .. 'written, which is what let the partition above be a single subtraction '
        .. '-- re-read it before re-baselining')
    -- The tower clause is vacuous on this corpus and says so out loud: a zero here
    -- could equally mean "the mock answers {} for everybody".
    assert(C('nosrc_tower') == 0, C('nosrc_tower') .. ' below-floor empty-handed '
        .. 'frames now carry an enemy tower inside 1200; this lever inherits that '
        .. 'clause unchanged and the refusal set above no longer accounts for them')
    cs.ratchet(C('deep_with_any_tower'), 18, 'below-floor frames whose world '
        .. 'contains an enemy tower at ALL -- the anti-vacuum reading that makes '
        .. 'the zero above a statement about 1200 rather than about the mock')
end

tests['[census] the 8 that named this round, corrected'] = function()
    -- The charter named `stop_source 8` and attached the warning this test spends
    -- its assertions on: 8 says "no supply", it does not say "safe".
    cs.ratchet(C('trigger_deep_nosrc'), 8, "the '回复状态' deep-band frames with "
        .. 'nothing drinkable -- the count tests/_tpdeep_sweep.lua reported')
    assert(C('stop_source_ring') + C('stop_source_attr') + C('stop_source_tower')
        + C('stop_source_domain') == C('trigger_deep_nosrc'),
        'the prefix walk over the 8 does not partition them')
    -- ⭐ The correction itself: five of the eight are refused by clauses this arm
    -- KEEPS, so the branch-trigger slice of the domain is 3.
    cs.ratchet(C('stop_source_ring'), 5, 'of the 8, refused by the 1600 ring')
    cs.ratchet(C('stop_source_domain'), 3, 'of the 8, actually in this domain')
    assert(C('stop_source_domain') < C('trigger_deep_nosrc'), 'the 8 are now ALL '
        .. 'in the domain -- the whole point of this test is that they were not, '
        .. 'and a lever sized on the 8 would have been sized on a wrong number')
    -- ⛔ AND THE ORDER-FREE COLUMN, because the prefix bucket's zero is about the
    -- WALK, not about the corpus: three of the eight DO carry attributed damage,
    -- they are simply also inside the ring, so the walk files them under the ring.
    -- Reporting `stop_source_attr 0` without this would be the (ii)/(iii) mistake.
    assert(C('stop_source_attr') == 0, 'the prefix order changed: attribution now '
        .. 'files frames of its own, and the order-free reading below no longer '
        .. 'explains the bucket')
    cs.ratchet(C('stop_source_attr_any'), 3, 'of the 8, carrying attributed hero '
        .. 'damage regardless of walk order')
    assert(C('stop_source_attr_any') > C('stop_source_attr'), 'the order-free and '
        .. 'prefix attribution counts agree, so this column has stopped saying '
        .. 'anything the prefix bucket did not')
end

tests['[census] the domain is reached two independent ways, and they agree'] =
function()
    -- One is DRIVEN through the shipped call-site predicate with 'buydeep' armed
    -- alone; the other is an independent prefix walk with nothing armed. Agreement
    -- is what separates "the helper answers true here" from "the call site changes
    -- here", and a single number could not tell those apart.
    assert(C('flips_buydeep') == C('deep_domain'), string.format(
        'the driven flip count (%d) and the independent prefix walk (%d) disagree '
        .. '-- one of the two is measuring a different set, and the domain claim '
        .. 'rests on them being the same set', C('flips_buydeep'), C('deep_domain')))
    cs.ratchet(C('deep_domain'), 6, "this lever's domain")
    assert(#M.flips == C('flips_buydeep'), 'the sweep printed ' .. #M.flips
        .. ' flip rows for ' .. C('flips_buydeep') .. ' counted flips')
    -- ⭐ THE ARITHMETIC THE ABSENT BOTTOM EDGE COSTS, registered as a reading and
    -- never as the pin (the pin is DEEP_NO_LOW_EDGE, above): half this domain sits
    -- below the decision-side sibling's 0.10.
    cs.ratchet(C('deep_below_tpdeep_floor'), 3, "domain frames below 'tpdeep''s "
        .. '0.10 bottom -- what copying that constant would have discarded')
    assert(C('deep_below_tpdeep_floor') > 0, 'no domain frame sits below 0.10 any '
        .. 'more, so this corpus can no longer tell the absent bottom edge apart '
        .. 'from a copied one -- the structural pin is now the only thing holding it')
    -- The bearing frame is in the printed set, by name.
    local bFound = false
    for _, f in ipairs(M.flips) do
        if f.fixture == 'f_181441_zuus_lowhp_limbo' then bFound = true end
    end
    assert(bFound, 'the bearing frame f_181441_zuus_lowhp_limbo is no longer in the '
        .. 'flip set -- this file is written about that frame')
end

tests['[census] direction and disjointness are measured, not argued'] = function()
    -- The call site ORs a new arm in, so arming can only ADD trues.
    assert(C('flip_true_to_false') == 0, C('flip_true_to_false') .. ' frames had '
        .. 'the call-site predicate turn TRUE -> FALSE under arming. An OR arm '
        .. 'cannot do that: something else moved')
    assert(C('arm_leak') == 0, 'the one-id-wide stub leaked: another candidate '
        .. 'answered armed on ' .. C('arm_leak') .. ' frames, so a flip attributed '
        .. 'to this lever could belong to that one')
    -- ⭐ The probe must PROVE it ran: four overlap columns whose whole content is a
    -- zero read the same when the probe stopped driving (the GH #171 shape).
    cs.universal(C('overlap_probe_runs'), C('live'),
        'the disjointness probe ran on every live frame', cs.FLOOR)
    for _, k in ipairs({ 'overlap_deep_buy', 'overlap_deep_hurt',
        'overlap_deep_tower', 'overlap_deep_ring' }) do
        assert(C(k) == 0, k .. ' is ' .. C(k) .. ': two arms answer TRUE on the '
            .. 'same frame, so a single-arm wave can credit this lever with a '
            .. "sibling's behaviour. The five domains are supposed to be disjoint "
            .. 'by construction -- all four siblings floor at 0.18 and this one '
            .. 'ceilings there')
    end
end

tests['[census] the honest bounds, as numbers'] = function()
    -- (2) The GH #123 backpack asymmetry: J.HasFieldRegenSource stops at slot 5, so
    -- a salve already bought and stowed is invisible to it and is caught at the
    -- call site by bot:FindItemSlot instead.
    assert(C('deep_with_bag_salve') <= C('deep_domain'), 'more domain frames carry '
        .. 'a backpacked salve than there are domain frames')
    cs.ratchet(C('deep_with_bag_salve'), 1, 'domain frames with a backpacked salve '
        .. '-- refused at the call site, not by this predicate')
    -- (3) The 'fieldcreep' disagreement, measured rather than promised. A claim
    -- whose content is a zero stays an equality so a counter-example goes red.
    assert(C('deep_with_creep_damage') == 0, C('deep_with_creep_damage')
        .. " domain frames now carry creep damage in the same 3s window. While "
        .. "'fieldcreep' is armed the two arms of this call site disagree about "
        .. 'those frames; that disagreement was EMPTY on this corpus when the '
        .. 'lever was written, and this counter is what says when it stops being')
end

-- ------------------------------------------------- the pinned frames -------

tests['[frame] the bearing frame: too hurt for a floor that guards a retreat'] =
function()
    local J, bot, arm = frame(FX, SUBJ)
    assert(math.abs(J.GetHP(bot) - 0.1581) < 0.002, 'the pinned frame moved: hp is '
        .. string.format('%.4f', J.GetHP(bot)) .. ', expected ~0.1581')
    -- It is below the floor, and that is the ONLY thing wrong with it.
    assert(J.GetHP(bot) < 0.18, 'the pinned frame is no longer below the floor')
    assert(#J.GetNearbyHeroes(bot, 1600, true, BOT_MODE_NONE) == 0,
        'an enemy entered the 1600 ring on the pinned frame; the clause this lever '
        .. 'inherits unchanged would now refuse it and the frame stops being about '
        .. 'the floor')
    assert(#bot:GetNearbyTowers(1200, true) == 0, 'an enemy tower appeared inside '
        .. '1200 on the pinned frame')
    assert(not bot:WasRecentlyDamagedByAnyHero(3.0), 'the pinned bot was hit inside '
        .. '3 seconds; the frame is chosen for being quiet')
    -- Nothing drinkable -- and the bottle is EMPTY, which is why the supply clause
    -- and not the situation clause is what the shipped tree refuses him with.
    assert(not J.HasFieldRegenSource(bot), 'the pinned bot now carries something '
        .. 'drinkable; the supply side has nothing to do for a supplied bot')
    -- Shipped: all five arms refuse. Armed: only this one accepts.
    assert(site(J, bot) == false, 'the purchase site already fires on the pinned '
        .. 'frame with nothing armed -- there is no gap left for this lever')
    arm(true)
    assert(J.ShouldFieldBuyRegenDeep(bot) == true, 'the lever does NOT fire on the '
        .. 'frame it was written for')
    assert(site(J, bot) == true, 'the lever fires but the call-site predicate does '
        .. 'not -- the wiring is not reached')
end

tests['[frame] the second frame, below the decision-side bottom'] = function()
    local J, bot, arm = frame(FX2, SUBJ2)
    assert(math.abs(J.GetHP(bot) - 0.0960) < 0.002, 'the second frame moved: hp is '
        .. string.format('%.4f', J.GetHP(bot)) .. ', expected ~0.0960')
    -- ⭐ This is the frame the absent bottom edge is FOR: a copied 'tpdeep' 0.10
    -- would refuse it, and it is a level-11 hero with the nearest enemy 3,100 away.
    assert(J.GetHP(bot) < 0.10, 'the second frame is no longer below 0.10, so it '
        .. 'has stopped being the frame that distinguishes this arm from a copy of '
        .. 'the decision-side sibling')
    assert(not J.HasFieldRegenSource(bot), 'the second frame now carries something '
        .. 'drinkable')
    assert(site(J, bot) == false, 'the purchase site already fires on the second '
        .. 'frame with nothing armed')
    arm(true)
    assert(site(J, bot) == true, 'the lever does not fire on the second frame')
end

tests['[frame] the inherited clauses still refuse what they refused'] = function()
    for _, b in ipairs(BLOCKED) do
        local J, bot, arm = frame(b.fx, b.subj)
        assert(math.abs(J.GetHP(bot) - b.hp) < 0.002, b.fx .. ' moved: hp is '
            .. string.format('%.4f', J.GetHP(bot)) .. ', expected ~' .. b.hp)
        assert(J.GetHP(bot) < 0.18, b.fx .. ' is no longer below the floor, so it '
            .. 'stopped being a control for a clause this lever inherits')
        arm(true)
        assert(J.ShouldFieldBuyRegenDeep(bot) == false, b.fx .. ' (' .. b.why
            .. ') now passes the lever. That frame is refused by a clause this arm '
            .. 'inherited UNCHANGED, so a pass means the lever is being credited '
            .. 'with work that clause does')
    end
end

tests['[frame] disjointness, on a frame the sibling owns'] = function()
    -- The load-bearing control for an INVERTED clause: just ABOVE the floor,
    -- 'fieldbuy' accepts and 'buydeep' must not. Four points of HP is the whole
    -- difference between the two arms here.
    local J, bot = rf.load(ABOVE_FLOOR.fx, ABOVE_FLOOR.subj)
    assert(math.abs(J.GetHP(bot) - ABOVE_FLOOR.hp) < 0.002, ABOVE_FLOOR.fx
        .. ' moved: hp is ' .. string.format('%.4f', J.GetHP(bot)))
    assert(J.GetHP(bot) >= 0.18, 'the disjointness control fell below the floor; it '
        .. 'is chosen for sitting just above it')
    J.IsSoakCandidate = function(s) return s == 'fieldbuy' end
    assert(J.ShouldFieldBuyRegen(bot) == true, "the sibling 'fieldbuy' no longer "
        .. 'accepts the frame this control is built on')
    J.IsSoakCandidate = function(s) return s == 'buydeep' end
    assert(J.ShouldFieldBuyRegenDeep(bot) == false, "'buydeep' accepts a frame "
        .. "'fieldbuy' owns. The five arms are disjoint by an INVERTED floor, and "
        .. 'that inversion has stopped holding')
end

tests['[frame] unarmed, the purchase decision is byte-identical'] = function()
    -- The shipped tree must not move. Driven on every pinned frame in this file
    -- rather than argued from the first line of the helper.
    for _, f in ipairs({ { FX, SUBJ }, { FX2, SUBJ2 },
        { ABOVE_FLOOR.fx, ABOVE_FLOOR.subj },
        { BLOCKED[1].fx, BLOCKED[1].subj }, { BLOCKED[2].fx, BLOCKED[2].subj } }) do
        local J, bot = rf.load(f[1], f[2])
        J.IsSoakCandidate = function() return false end
        assert(J.ShouldFieldBuyRegenDeep(bot) == false, 'unarmed, the lever answers '
            .. 'TRUE on ' .. f[1] .. ' -- it would ship in every live game')
    end
end

return tests

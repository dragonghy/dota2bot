-- [buyring 2026-09-06, 协同组] Owner priority P2: a hurt bot in no danger must NOT
-- go home -- "血量低也尽量不要回程,买大药或其他补给". This file is about the second
-- half of that sentence, and about ONE CONSTANT that this family answers twice.
--
-- ⭐ THE FINDING, AS TWO RINGS FOR ONE QUESTION. "Is an enemy near enough that this
-- hurt bot must not be treated as safe" is asked on both halves of P2, over the
-- SAME health band [0.18, 0.75], and the two halves answer with different radii:
--   * the HOLD half, J.ShouldStayAndRegen -- PROMOTED, live in every turbo game --
--     measures 1200;
--   * the SUPPLY half, J.IsFieldRegenSituation and all three buy arms, measures
--     1600.
-- The 1600 is not a tuned safety margin, and the sibling's own comment says so in
-- its own words: "Nobody in the ring THE GUARDED BRANCH ITSELF MEASURES (1600)."
-- That is a statement about the retreat bid 'stayfield'/'stayfield2' cancel -- the
-- number was chosen to match what is being cancelled. The buy arms cancel nothing;
-- they add an OR arm to a purchase. So they inherited a constant whose entire
-- justification is a call site they do not have -- the SAME shape as the 'buytower'
-- arm one day earlier (a rationale written for a different consumer), applied to
-- the ring instead of the tower clause.
--
-- Measured, not argued (tests/_buyring_sweep.lua, 1012 live turbo hero frames):
--   305 frames sit inside the PROMOTED [0.18, 0.75] band and 163 of those carry
--   nothing drinkable in a main slot. Of those 163, **99** are held out by the 1600
--   ring -- the largest single refusal bucket the supply side has -- and exactly
--   **12** of the 99 have the PROMOTED 1200 ring EMPTY. 10 of those 12 also clear
--   the attribution and tower clauses, and those 10 are this lever's whole domain.
--   The other 2 are held by the tower clause and stay held: they are the 'buytower'
--   question, not this one.
-- The bearing frame is tests/fixtures/f_260822_063559_slardar_tp_forward.lua at
-- t=635.9 (10:35) -- the 063559 replay owner priority P2 names by number. A slardar
-- at 968/2104 = 46.0% HP carrying echo_sabre / power_treads / quelling_blade /
-- magic_wand / bracer (nothing drinkable at all), the nearest enemy hero a
-- tidehunter 1,565 units away who has not touched him, nobody inside the promoted
-- 1200 ring, no enemy tower inside 1200, and no hero or creep damage in the last 3
-- seconds. Shipped, all three buy arms refuse him.
--
-- ⭐⭐ THE ZERO THIS FILE REGISTERS RATHER THAN ASSUMES, because it is the reading
-- that sent this round here. The charter's named next candidate was the ATTRIBUTION
-- clause on these same arms -- "of the 28 frames held out by attributed hero damage,
-- how many are the global-ult / long-range-one-shot shape 'stayattr' proved on the
-- decision side". Priced first, as the charter requires, that candidate came out at
-- **one frame**: 25 of the 28 are ALSO inside the 1600 ring (so the ring refuses
-- them anyway), 2 more carry an enemy tower, and the single remaining frame's
-- attributed damager stands at **1,615.81 units** -- 15.81 units outside the ring,
-- which is not a global ult by any reading. Two consequences, both registered here
-- rather than in prose someone has to find: the supply arms HAVE already inherited
-- the 'stayattr' fix (all three carry the attributed scan, and the 3 frames in the
-- corpus with unattributed hero damage are already let through), and on this corpus
-- attribution refuses NONE of this lever's annulus (`nosrc_annulus_attr == 0`,
-- asserted below). The ring is doing all of the refusing.
--
-- ⭐⭐⭐ WHY THE CLAUSE IS INVERTED RATHER THAN LOWERED, and this is the reusable
-- part. Lowering 1600 to 1200 inside J.IsFieldRegenSituation would move THREE
-- families on one arm ('stayfield', 'stayfield2', 'fieldbuy') -- the 'lanefix'
-- bundle shape, and two of those are HOLD-side ids whose retreat-cancelling is
-- exactly what the 1600 was chosen for. Keeping the 1600 and requiring it to be
-- OCCUPIED makes this arm's domain disjoint from all three siblings by
-- construction rather than by measurement, and disjoint across the WHOLE band --
-- which is why this lever spans the promoted [0.18, 0.75] instead of owning a slice
-- of it. `overlap_ring_buy`, `overlap_ring_hurt` and `overlap_ring_tower` are
-- asserted 0 below with `overlap_probe_runs == live`, so that "measured and empty"
-- cannot read the same as "not measured" (GH #171).
--
-- WHAT IS ASSERTED. Not gate plumbing. The shipped call-site predicate quartet is
-- driven on real frames with every candidate disarmed and then with exactly
-- 'buyring' armed, and the CAUSE of each changed answer is read off the frame's own
-- world state. The negative controls are frames INSIDE the band carrying nothing,
-- refused by a clause this lever inherited unchanged.
--
-- WHAT IS NOT BOUGHT, stated rather than implied:
--   * a salve being purchased. The nine engine clauses at the call site (stock,
--     gold, stash, courier distance, empty slot) are unreadable from a fixture and
--     gold is not networked into a .dem at all (GH #495), so the flip set is the
--     gold-blind superset of the live one. This lever reads no gold of its own.
--   * a trip home being cancelled. This is a purchase predicate; the decision-side
--     ids ('stayfield', 'stayfield2', 'stayattr') are the ones that hold a bot.
--   * that an enemy at 1,300 units will stay there. It can walk into the promoted
--     ring a third of a second later. What this arm buys is a salve, not a promise
--     that drinking it will succeed, and the drink decision is not on this path.
--   * that every domain frame ends in a purchase. One of the ten carries a salve in
--     the BACKPACK, which J.HasFieldRegenSource cannot see (it stops at slot 5) and
--     the call site's own `bot:FindItemSlot('item_flask') < 0` does -- so that frame
--     flips the predicate and buys nothing (GH #123). Asserted as an exact 1 below.
--   * agreement with 'fieldcreep'. Like all three siblings, this lever does not copy
--     that gated creep veto (naming another id here would freeze the clause FALSE
--     the day it is promoted -- the 'pullcad' trap). The disagreement on THIS corpus
--     is 1 of the 10 domain frames, a measured number below rather than a promise.

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')
local cs = require('corpus_scale')

local SWEEP = 'lua5.1 tests/_buyring_sweep.lua 2>/dev/null'
local JMZ = 'bots/FunLib/jmz_func.lua'
local PURCHASE = 'bots/item_purchase_generic.lua'

-- The pinned frame: the 063559 replay owner priority P2 names. slardar at 46.0% HP,
-- nothing drinkable, nobody inside the PROMOTED 1200 ring, a tidehunter at 1,565.
local FX = 'tests/fixtures/f_260822_063559_slardar_tp_forward.lua'
local SUBJ = 'npc_dota_hero_slardar'
-- A second frame on another fixture and on the other side of the sibling ceiling,
-- pinned so the finding is neither one fixture nor one HP value wide.
local FX2 = 'tests/fixtures/f_260820_043124_axe_blink_kill.lua'
local SUBJ2 = 'npc_dota_hero_sniper'

-- Negative controls. Both are INSIDE the band and carrying nothing, so the only
-- thing that can refuse them is a clause this lever inherited UNCHANGED -- the
-- promoted 1200 chase ring in the first case, the tower clause in the second. If
-- either flips, the lever is being credited with work those clauses do.
local BLOCKED = {
    { fx = 'tests/fixtures/f_071423_sky_rescue.lua',
      subj = 'npc_dota_hero_sven', hp = 0.6869, why = 'chase' },
    { fx = 'tests/fixtures/f_260819_183613_storm_collapse_lost.lua',
      subj = 'npc_dota_hero_dragon_knight', hp = 0.7500, why = 'tower' },
}
-- The disjointness control, and it is the load-bearing one for an INVERTED clause:
-- a frame with an EMPTY 1600 ring that 'fieldbuy' owns. 'buyring' must refuse it
-- while 'fieldbuy' still accepts it.
local EMPTY_RING = { fx = 'tests/fixtures/f_071903_sven_idle.lua',
    subj = 'npc_dota_hero_luna', hp = 0.3512 }
-- Out of band on the HIGH side: a healthy bot must never buy a field salve.
local OOB_HIGH = { fx = 'tests/fixtures/f_045650_lion_meatgrinder.lua',
    subj = 'npc_dota_hero_axe', hp = 1.0 }

local tests = {}

local M = (function()
    local p = assert(io.popen(SWEEP, 'r'))
    local raw = p:read('*a')
    p:close()
    local m = { g = {}, c = {}, flips = {}, refused = {}, done = false }
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
    J.IsSoakCandidate = function(s) return armed and s == (sId or 'buyring') end
    return J, bot, function(b) armed = b end
end

--- The CALL SITE's predicate, as the call site itself spells it: the OR of the
--- four arms. Driving this rather than the new function alone is what makes
--- "arming can only add TRUEs" a statement about the shipped decision instead of
--- about a helper nobody calls.
local function site(J, bot)
    return (J.ShouldFieldBuyRegen(bot) or J.ShouldFieldBuyRegenHurt(bot)
        or J.ShouldFieldBuyRegenTower(bot)
        or J.ShouldFieldBuyRegenRing(bot)) and true or false
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
    assert(M.g.TOW == 1, 'the sweep could not slice J.ShouldFieldBuyRegenTower out '
        .. 'of ' .. JMZ)
    assert(M.g.RING == 1, 'the sweep could not slice J.ShouldFieldBuyRegenRing out '
        .. 'of ' .. JMZ)
    assert(M.g.STAY == 1, 'the sweep could not slice J.ShouldStayAndRegen out of '
        .. JMZ)
    assert(M.g.RING_SOAKID == 1, "the 'buyring' id is no longer in "
        .. 'J.ShouldFieldBuyRegenRing (comments are stripped before this is read)')
    assert(M.g.RING_TURBO == 1, 'the lever lost its own IsModeTurbo -- it repeats '
        .. 'the situation clauses instead of calling the predicate that asks, so '
        .. 'nothing else would keep it out of normal mode')
    -- Every [source] fact here is a claim about CODE, and this lever ships with a
    -- long comment naming J.IsSoakCandidate, three sibling ids, every constant and
    -- the call site while explaining them. So the stripping is asserted DIRECTLY
    -- rather than inferred from some count landing on its expected value (the
    -- 'staybag' round's M5).
    assert(M.g.SIT_STRIPPED == 1 and M.g.RING_STRIPPED == 1
        and M.g.STAY_STRIPPED == 1,
        'the sweep is parsing UNSTRIPPED source (comment markers survive in a '
        .. 'sliced block) -- every [source] assertion in this file could then be '
        .. 'satisfied by prose')
end

tests['[source] the two rings ARE the lever, and both owners still own them'] =
function()
    -- ⭐ The finding, as four numbers that must keep their relationship. 1200 is
    -- parsed out of the PROMOTED function; 1600 out of the shared situation
    -- predicate; this lever's two copies are parsed out of its own body. Nothing
    -- here is a literal this file made up.
    assert(M.g.RING_CHASE == M.g.STAY_RING, "the lever's chase ring ("
        .. tostring(M.g.RING_CHASE) .. ") is no longer the PROMOTED function's ("
        .. tostring(M.g.STAY_RING) .. ') -- it is a new tuned constant now, and the '
        .. 'whole condition-(c) argument was that it is not')
    assert(M.g.RING_RING == M.g.SIT_RING, "the lever's inverted ring ("
        .. tostring(M.g.RING_RING) .. ") is no longer the sibling's ("
        .. tostring(M.g.SIT_RING) .. ') -- the four arms no longer partition the '
        .. 'same boundary and disjointness is gone')
    assert(M.g.STAY_RING == 1200 and M.g.SIT_RING == 1600,
        'the two owning constants themselves moved (1200 / 1600) -- the equalities '
        .. 'above would then be two copies of a new number')
    assert(M.g.STAY_RING < M.g.SIT_RING, 'the promoted ring is no longer SMALLER '
        .. 'than the inherited one; the gap this lever is about has closed or '
        .. 'reversed, and its domain is measuring something else')
    -- ⭐⭐ The inversion, both directions. A mutant that flips it leaves every
    -- counter looking plausible while the four arms start overlapping.
    assert(M.g.RING_INVERTED == 1, 'the lever no longer requires an enemy hero '
        .. 'inside 1600 (`nRing == 0 then return false`) -- its domain now overlaps '
        .. 'all three siblings and no isolation wave can tell the arms apart')
    assert(M.g.RING_CHASE_PLAIN == 1, 'the promoted 1200 ring no longer VETOES in '
        .. 'this lever (`nChasers > 0 then return false`) -- it would then fire '
        .. 'while a hero is in contact, which is not the frame set it was priced on')
    assert(M.g.SIT_RING_PLAIN == 1 and M.g.HURT_RING_PLAIN == 1
        and M.g.TOW_RING_PLAIN == 1,
        'one of the three sibling arms no longer refuses on an enemy inside 1600 -- '
        .. 'if that clause was removed or lowered, this lever is answering a '
        .. 'question nobody is asking any more; re-read the finding')
    -- The clause this lever deliberately does NOT move: two clauses at once is two
    -- levers, and the tower one already has an arm of its own.
    assert(M.g.RING_TOWER_PLAIN == 1, 'the tower clause is no longer in its shipped '
        .. "direction in this lever -- it is now moving 'buytower''s clause too, "
        .. 'and a single-arm wave can no longer attribute either')
end

tests['[source] the band is the promoted one, parsed not written down'] = function()
    assert(M.g.RING_HP_LO == M.g.SIT_HP_LO, "the lever's floor ("
        .. tostring(M.g.RING_HP_LO) .. ") is no longer J.IsFieldRegenSituation's ("
        .. tostring(M.g.SIT_HP_LO) .. ') -- it is a new tuned constant now')
    assert(M.g.RING_HP_HI == M.g.STAY_HP_HI, "the lever's ceiling ("
        .. tostring(M.g.RING_HP_HI) .. ") is no longer the PROMOTED veto's ("
        .. tostring(M.g.STAY_HP_HI) .. ') -- it is a new tuned constant now')
    assert(M.g.SIT_HP_LO == 0.18 and M.g.STAY_HP_HI == 0.75,
        'the two owning constants themselves moved (0.18 / 0.75) -- equality above '
        .. 'would then be two copies of a new number')
    assert(M.g.RING_HP_HI > M.g.SIT_HP_HI and M.g.RING_HP_LO < M.g.SIT_HP_HI,
        'the lever no longer spans J.IsFieldRegenSituation\'s 0.55 ceiling; its '
        .. 'domain is now a band split as well as a clause inversion, and the '
        .. 'census below is measuring something else')
end

tests['[source] the copied clauses have not drifted'] = function()
    -- The price of repeating clauses instead of calling the sibling, made
    -- checkable. Each pair is parsed from its own function body.
    assert(M.g.RING_TOWER == M.g.SIT_TOWER, 'the tower radius drifted: lever '
        .. tostring(M.g.RING_TOWER) .. ' vs sibling ' .. tostring(M.g.SIT_TOWER))
    assert(M.g.RING_ATTR_WINDOW == M.g.SIT_ATTR_WINDOW,
        'the damage lookback drifted: lever ' .. tostring(M.g.RING_ATTR_WINDOW)
        .. ' vs sibling ' .. tostring(M.g.SIT_ATTR_WINDOW))
    assert(M.g.RING_ATTR_RADIUS == M.g.SIT_ATTR_RADIUS,
        'the attribution radius drifted: lever ' .. tostring(M.g.RING_ATTR_RADIUS)
        .. ' vs sibling ' .. tostring(M.g.SIT_ATTR_RADIUS))
    assert(M.g.SIT_TOWER == 1200 and M.g.SIT_ATTR_RADIUS == 3000
        and M.g.SIT_ATTR_WINDOW == 3,
        'the sibling situation constants themselves moved (1200/3000/3.0) -- '
        .. 'equality above would then be two copies of a new number')
end

tests['[source] the shipped predicate was NOT touched'] = function()
    -- The reverted signature change of the 'buyband' round, asserted here too so it
    -- cannot come back through this lever by accident.
    assert(M.g.SIT_CALLS_2ARG == 0, 'J.IsFieldRegenSituation is now called with a '
        .. 'second argument. That was tried on 2026-09-06 and reverted: seven '
        .. 'detector files parse its signature or its band as literal text')
    assert(M.g.SIT_CALLS_1ARG == 2, 'J.IsFieldRegenSituation now has '
        .. tostring(M.g.SIT_CALLS_1ARG) .. ' callers, not the 2 this file measured '
        .. '(J.ShouldRegenNotGoHome, J.ShouldFieldBuyRegen)')
    assert(M.g.RING_CALLS_SIT == 0, 'the lever now CALLS J.IsFieldRegenSituation. '
        .. 'It is written to repeat three of its clauses and INVERT the fourth; a '
        .. 'call would re-impose the very veto this lever exists to lift')
    assert(M.g.SIT_HAS_BUYRING == 0, "the 'buyring' id appears inside the shared "
        .. 'predicate -- one arm would then move three families at once')
    assert(M.g.SIT_NIDS == 1, 'J.IsFieldRegenSituation now names '
        .. tostring(M.g.SIT_NIDS) .. ' soak ids in code, not 1. Every gate in that '
        .. "body moves THREE families on one arm ('stayfield', 'stayfield2', "
        .. "'fieldbuy') -- the 'lanefix' bundle shape")
    -- ⭐ And the invariant belonging to ANOTHER lever that this one had to respect:
    -- tests/test_stayattr_global_ult.lua asserts J.HasNearbyHeroDamager has exactly
    -- one caller BY COUNT. Routing this arm's attribution scan through it would
    -- have been the tidier code and a red in that file; the duplication is
    -- deliberate and this is where that decision is recorded as a check.
    assert(M.g.RING_CALLS_DAMAGER == 0, 'this lever now calls '
        .. "J.HasNearbyHeroDamager, whose one-caller count tests/"
        .. 'test_stayattr_global_ult.lua asserts -- that file is now red for a '
        .. 'reason that has nothing to do with this lever')
end

tests["[source] one id, one condition -- the 'pullcad' invariant"] = function()
    assert(M.g.RING_NIDS == 1, 'J.ShouldFieldBuyRegenRing now names '
        .. tostring(M.g.RING_NIDS) .. ' soak ids in code; expected exactly 1')
    assert(M.g.RING_IDS_MAX_PER_COND == 1, 'two ids share one condition in this '
        .. "lever -- the 'pullcad' trap: the gate freezes FALSE the day either id "
        .. 'is promoted')
    -- Honest bound, from both sides: the creep veto is still the sibling's and
    -- still not copied here.
    assert(M.g.SIT_HAS_FIELDCREEP == 1, "the 'fieldcreep' veto left "
        .. 'J.IsFieldRegenSituation -- if it was PROMOTED, this lever must inherit '
        .. 'it (it can be copied safely once no id names it); re-read the bound')
    assert(M.g.RING_HAS_FIELDCREEP == 0, "this lever now names 'fieldcreep', which "
        .. 'freezes that clause FALSE the day that id is promoted')
end

tests['[source] the wiring is a FOURTH OR arm, not a replacement'] = function()
    assert(M.g.WIRE_RING == 1, 'the lever is not consulted at the purchase site in '
        .. PURCHASE .. ' -- an unwired predicate ships nothing')
    assert(M.g.WIRE_BUY == 1, "the 'fieldbuy' arm disappeared from the purchase "
        .. 'site; this lever was added ALONGSIDE it, not in place of it')
    assert(M.g.WIRE_HURT == 1, "the 'buyband' arm disappeared from the purchase "
        .. 'site; this lever was added ALONGSIDE it, not in place of it')
    assert(M.g.WIRE_TOW == 1, "the 'buytower' arm disappeared from the purchase "
        .. 'site; this lever was added ALONGSIDE it, not in place of it')
    assert(M.g.WIRE_OR4 == 1, 'the four arms are no longer one OR at the purchase '
        .. 'site -- the direction argument (arming can only add TRUEs) rests on '
        .. 'that shape')
    assert(M.g.WIRE_RING_CALLS == 1, 'the lever has '
        .. tostring(M.g.WIRE_RING_CALLS) .. ' call sites in ' .. PURCHASE
        .. ', not 1 -- a second site would ship the behaviour through a path this '
        .. 'file never drives')
    assert(M.g.RING_DEFS_IN_JMZ == 1, 'J.ShouldFieldBuyRegenRing is referenced '
        .. tostring(M.g.RING_DEFS_IN_JMZ) .. ' times inside ' .. JMZ
        .. ' (definition only expected) -- an internal caller would bypass the call '
        .. 'site this file drives')
    assert(M.g.WIRE_PURCHASES_FLASK == 1, 'the guarded block no longer buys a flask')
    -- One arming point in code, so the behaviour cannot ship through a second site
    -- nobody gated. Comments are stripped first: this lever's own comment names
    -- 'buyring' several times while explaining it.
    local code = (read_file(JMZ) .. read_file(PURCHASE)):gsub('%-%-[^\n]*', '')
    local _, n = code:gsub("'buyring'", '')
    assert(n == 1, "'buyring' appears " .. n .. ' times in CODE across the two '
        .. 'files that decide this purchase; expected 1')
end

-- --------------------------------------------------------- the census ------

tests['[census] the corpus, and what holds the empty-handed frames out'] = function()
    cs.corpus(C('fixtures'), 'buyring fixture corpus')
    cs.ratchet(C('live'), 1012, 'live hero frames')
    cs.universal(C('turbo'), C('live'), 'every corpus frame is turbo', cs.FLOOR)
    assert(C('raises') == 0, C('raises') .. ' frames raised inside a driven call '
        .. '-- a raised frame is not a measured frame')
    cs.ratchet(C('band_all'), 305, 'frames inside the promoted [0.18,0.75] band')
    cs.ratchet(C('band_nosrc'), 163, 'band frames carrying nothing drinkable')
    cs.ratchet(C('nosrc_ring_busy'), 99, 'held out by the inherited 1600 ring')
    cs.ratchet(C('nosrc_chase_busy'), 87, 'held out by the PROMOTED 1200 ring')
    cs.ratchet(C('nosrc_attr'), 28, 'held out by attributed hero damage')
    cs.ratchet(C('nosrc_tower'), 22, 'with an enemy tower inside 1200')
    cs.ratchet(C('nosrc_clean'), 53, 'held out by nothing (the siblings own these)')
    -- ⭐ THE GAP, and it is the whole finding as one subtraction. The two rings
    -- disagree about 12 of the 163 empty-handed band frames; that is what "the
    -- supply side inherited a hold-side constant" costs on this corpus.
    assert(C('nosrc_ring_busy') - C('nosrc_chase_busy') == C('nosrc_annulus'),
        string.format('the 1200-1600 gap is not the difference of the two rings: '
        .. '%d - %d ~= %d. One of the three is measuring a different set',
        C('nosrc_ring_busy'), C('nosrc_chase_busy'), C('nosrc_annulus')))
    cs.ratchet(C('nosrc_annulus'), 12, 'frames in the 1200-1600 gap')
    assert(C('nosrc_annulus') < C('nosrc_ring_busy'), 'every ring-refused frame is '
        .. 'now in the gap -- the promoted 1200 ring has stopped refusing anything, '
        .. 'and this lever is no longer a narrowing of the inherited one')
end

tests['[census] the zero that redirected this round, registered not assumed'] =
function()
    -- The charter's named candidate for this round was the ATTRIBUTION clause on
    -- these arms. Priced first (see the head comment), it came to ONE frame whose
    -- attributed damager stands 1,615.81 units away -- 15.81 outside the ring, not
    -- a global ult. The structural half of that reading is asserted here so the
    -- next author does not re-derive it: on this corpus attribution refuses NONE of
    -- this lever's gap, so the two levers are not competing for the same frames.
    assert(C('nosrc_annulus_attr') == 0, C('nosrc_annulus_attr') .. ' frames in the '
        .. '1200-1600 gap are ALSO refused by attributed hero damage, not the 0 '
        .. 'this file measured. The attribution clause has started biting inside '
        .. "this lever's domain, so the report's claim that the ring does all the "
        .. 'refusing is stale -- re-read it rather than re-baselining this number')
    -- ...and the two frames the tower clause keeps. They are 'buytower''s question,
    -- and this file pins the count so the two levers' domains stay legible apart.
    assert(C('nosrc_annulus_tower') == 2, C('nosrc_annulus_tower') .. ' gap frames '
        .. "carry an enemy tower inside 1200, not the 2 this file measured -- the "
        .. "boundary between this lever and 'buytower' has moved")
    assert(C('nosrc_annulus') - C('nosrc_annulus_attr') - C('nosrc_annulus_tower')
        == C('ring_domain'), string.format(
        'the gap does not decompose into the domain plus its two refusals: '
        .. '%d - %d - %d ~= %d', C('nosrc_annulus'), C('nosrc_annulus_attr'),
        C('nosrc_annulus_tower'), C('ring_domain')))
end

tests['[census] the domain is reached two independent ways, and they agree'] =
function()
    -- ⭐ THE CROSS-CHECK. `flips_buyring` comes from DRIVING the shipped call-site
    -- predicate quartet (nothing else armed); `ring_domain` comes from an
    -- independent prefix walk over the frame's own world state. Two routes to the
    -- same set: if they disagree, one of them is measuring something else and no
    -- number in this file can be trusted.
    assert(C('flips_buyring') == C('ring_domain'), string.format(
        'driven flips (%d) and the prefix walk (%d) disagree about this lever\'s '
        .. 'domain', C('flips_buyring'), C('ring_domain')))
    cs.ratchet(C('flips_buyring'), 10, 'frames this lever buys for')
    assert(C('flips_buyring') > 0, 'this lever flips NOTHING with only its own id '
        .. 'armed. That is the failure the standalone shape exists to prevent: a '
        .. 'single-arm isolation wave would read a correct zero and the id would be '
        .. 'recorded as "tested, no effect" (GH #542)')
    assert(#M.flips == C('flips_buyring'), 'the sweep listed ' .. #M.flips
        .. ' flip rows for ' .. C('flips_buyring') .. ' counted flips')
    -- The band split of the domain is an IDENTITY, not two independent counts.
    assert(C('ring_below_sit_ceiling') + C('ring_above_sit_ceiling')
        == C('ring_domain'), string.format(
        'the domain no longer splits at the sibling ceiling: %d + %d ~= %d',
        C('ring_below_sit_ceiling'), C('ring_above_sit_ceiling'), C('ring_domain')))
    -- ...and it lands on BOTH sides of 0.55, which is the measured form of "this
    -- lever is a clause inversion, not a band". If it ever falls entirely on one
    -- side, the simpler design (extend a sibling's band) becomes available and this
    -- one should be re-argued.
    assert(C('ring_below_sit_ceiling') > 0 and C('ring_above_sit_ceiling') > 0,
        'the domain now sits entirely on one side of 0.55; a band extension of an '
        .. 'existing arm would be the simpler lever and this one needs re-arguing')
end

tests['[census] direction and disjointness are measured, not argued'] = function()
    assert(C('flip_true_to_false') == 0, C('flip_true_to_false') .. ' frames turn '
        .. 'TRUE -> FALSE when the lever is armed. The call site ORs a new arm in, '
        .. 'so that is structurally impossible -- something else moved')
    assert(C('arm_leak') == 0, 'the sweep armed more than one id on ' .. C('arm_leak')
        .. ' frames, so a flip cannot be attributed to this lever')
    -- ⭐ The probe must PROVE it ran. All three overlap columns are claims whose
    -- whole content is a zero, and a probe that stopped driving prints the same zero
    -- as one that drove 1012 frames and found nothing (GH #171).
    assert(C('overlap_probe_runs') == C('live'), string.format(
        'the disjointness probe ran on %d of %d live frames -- an unrun probe '
        .. 'prints the same zero as an empty one',
        C('overlap_probe_runs'), C('live')))
    assert(C('overlap_ring_buy') == 0, C('overlap_ring_buy') .. " frames answer TRUE "
        .. "for both 'buyring' and 'fieldbuy'. The ring clause is inverted here "
        .. 'precisely so that cannot happen; an overlap means one id can be '
        .. "credited with the other's frames")
    assert(C('overlap_ring_hurt') == 0, C('overlap_ring_hurt') .. " frames answer "
        .. "TRUE for both 'buyring' and 'buyband' -- same defect, other sibling")
    assert(C('overlap_ring_tower') == 0, C('overlap_ring_tower') .. " frames answer "
        .. "TRUE for both 'buyring' and 'buytower' -- same defect, third sibling")
end

tests['[census] the honest bounds, as numbers'] = function()
    -- ⚠️ The GH #123 backpack asymmetry, and on this lever it is NOT empty: a
    -- backpacked salve is invisible to J.HasFieldRegenSource (it stops at slot 5)
    -- and is caught at the CALL SITE by `bot:FindItemSlot('item_flask') < 0`, which
    -- does see the backpack. So one of the ten domain frames flips this predicate
    -- and still buys nothing. That is not a defect -- it is the difference between
    -- "the predicate turned true" and "a salve was purchased", which this file has
    -- said from the top it cannot bridge.
    assert(C('ring_with_bag_salve') == 1, C('ring_with_bag_salve') .. ' domain '
        .. 'frames carry a backpacked salve, not the 1 this file measured. The gap '
        .. 'between the flip set and the purchase set has changed size; re-read it '
        .. 'rather than re-baselining it')
    assert(C('ring_with_bag_salve') < C('ring_domain'), 'every domain frame now '
        .. 'carries a backpacked salve -- the call-site FindItemSlot clause would '
        .. 'refuse all of them and this lever would buy nothing at all')
    -- The clause NOT copied from J.IsFieldRegenSituation is the gated 'fieldcreep'
    -- creep-damage veto (copying it would name another candidate's id and freeze
    -- this clause FALSE the day that id is promoted -- the 'pullcad' trap). So while
    -- 'fieldcreep' is armed, the arms of the call site disagree on any frame where
    -- the bot is being chewed by creeps. Pinned as an exact number so a wave that
    -- arms both ids reads the size of the disagreement off a test.
    assert(C('ring_with_creep_damage') == 1, C('ring_with_creep_damage')
        .. ' domain frames carry creep damage in the same 3s window, not the 1 this '
        .. 'file measured. That number is the width of the disagreement between '
        .. "this arm and 'fieldcreep' when both are armed; re-read it rather than "
        .. 're-baselining it')
    assert(C('ring_with_creep_damage') < C('ring_domain'), 'every domain frame now '
        .. "carries creep damage -- with 'fieldcreep' armed the two arms would "
        .. 'disagree on the WHOLE domain, and the lever should inherit that veto as '
        .. 'soon as no id names it')
end

-- ------------------------------------------------------ the pinned frames --

tests['[frame] the bearing frame: hurt, un-chased, empty-handed, poked from 1565'] =
function()
    local J, bot, arm = frame(FX, SUBJ)
    -- The world state first, so the flip below is attributed to the frame's own
    -- facts and not to a stub.
    local nHP = J.GetHP(bot)
    assert(math.abs(nHP - 0.4601) < 5e-4, 'the pinned frame moved: HP reads '
        .. string.format('%.4f', nHP) .. ', not 0.4601')
    assert(#J.GetNearbyHeroes(bot, 1200, true, BOT_MODE_NONE) == 0,
        'an enemy hero is inside the PROMOTED 1200 ring on the pinned frame -- this '
        .. 'bot is being chased and the lever must not fire; re-pin the frame')
    assert(#J.GetNearbyHeroes(bot, 1600, true, BOT_MODE_NONE) > 0,
        'no enemy hero is inside 1600 on the pinned frame, so the sibling arms would '
        .. 'accept it anyway and it says nothing about this lever')
    assert(#bot:GetNearbyTowers(1200, true) == 0, 'an enemy tower is inside 1200 on '
        .. "the pinned frame -- the tower clause refuses it and this is 'buytower''s "
        .. 'question, not this one')
    assert(bot:WasRecentlyDamagedByAnyHero(3.0) == false, 'the pinned bot took hero '
        .. 'damage in the last 3s -- the attribution clause may be what is being '
        .. 'measured, not the ring')
    assert(J.HasFieldRegenSource(bot) == false, 'the pinned bot is carrying '
        .. 'something drinkable, so the family has no purchase to make here')
    -- ...and now the decision.
    assert(site(J, bot) == false, 'the purchase site already answers TRUE with '
        .. 'NOTHING armed -- the behaviour is shipping, not gated')
    arm(true)
    assert(site(J, bot) == true, 'the lever does not fire on the very frame it is '
        .. 'pinned to')
    -- The CAUSE, isolated: the only clause standing between this frame and the
    -- sibling arms is the ring. Re-driven through all three to prove it.
    J.IsSoakCandidate = function(s) return s == 'fieldbuy' end
    assert(J.ShouldFieldBuyRegen(bot) == false, "'fieldbuy' accepts this frame too, "
        .. 'so the two arms overlap and this lever buys nothing new')
    J.IsSoakCandidate = function(s) return s == 'buyband' end
    assert(J.ShouldFieldBuyRegenHurt(bot) == false, "'buyband' accepts this frame "
        .. 'too, so the two arms overlap and this lever buys nothing new')
    J.IsSoakCandidate = function(s) return s == 'buytower' end
    assert(J.ShouldFieldBuyRegenTower(bot) == false, "'buytower' accepts this frame "
        .. 'too, so the two arms overlap and this lever buys nothing new')
    -- ⭐ And the sentence the finding is: the PROMOTED half of this same family
    -- calls this bot un-chased on this very frame, while the supply half refuses
    -- him. Read off the promoted function's own ring rather than described.
    assert(#J.GetNearbyHeroes(bot, 1200, true, BOT_MODE_NONE)
        < #J.GetNearbyHeroes(bot, 1600, true, BOT_MODE_NONE),
        'the two rings agree on the pinned frame, so it no longer demonstrates the '
        .. 'disagreement this lever is about')
end

tests['[frame] a second frame, other fixture, other side of the ceiling'] = function()
    local J, bot, arm = frame(FX2, SUBJ2)
    local nHP = J.GetHP(bot)
    assert(math.abs(nHP - 0.6460) < 5e-4, 'the second frame moved: HP reads '
        .. string.format('%.4f', nHP) .. ', not 0.6460')
    assert(nHP > 0.55, 'the second frame is no longer above the sibling ceiling, so '
        .. 'the pair no longer spans it')
    assert(#J.GetNearbyHeroes(bot, 1200, true, BOT_MODE_NONE) == 0
        and #J.GetNearbyHeroes(bot, 1600, true, BOT_MODE_NONE) > 0,
        'the second frame is no longer in the 1200-1600 gap')
    assert(site(J, bot) == false, 'shipped behaviour moved on the second frame')
    arm(true)
    assert(site(J, bot) == true, 'the lever does not fire on the second frame')
end

tests['[frame] the inherited clauses still refuse -- negative controls'] = function()
    for _, b in ipairs(BLOCKED) do
        local J, bot, arm = frame(b.fx, b.subj)
        local nHP = J.GetHP(bot)
        assert(math.abs(nHP - b.hp) < 5e-4, b.fx .. ' moved: HP reads '
            .. string.format('%.4f', nHP) .. ', not ' .. b.hp)
        assert(nHP >= 0.18 and nHP <= 0.75, 'the control is outside the band, so the '
            .. 'band refuses it and the clause under test never speaks')
        assert(J.HasFieldRegenSource(bot) == false, 'the control is carrying '
            .. 'something drinkable, so the supply clause refuses it and the clause '
            .. 'under test never speaks')
        arm(true)
        assert(site(J, bot) == false, b.fx .. '/' .. b.subj .. ' (' .. b.why
            .. ') now flips -- this lever is being credited with work the promoted '
            .. 'chase ring and the tower clause do')
    end
    -- ...and the two controls must refuse for DIFFERENT reasons, or one clause is
    -- covering for the other and only one of them is actually being controlled.
    local Jc, botc = rf.load(BLOCKED[1].fx, BLOCKED[1].subj)
    assert(#Jc.GetNearbyHeroes(botc, 1200, true, BOT_MODE_NONE) > 0,
        'the chase control has nobody inside the promoted 1200 ring; it is no '
        .. 'longer controlling the clause its row names')
    local Jt, bott = rf.load(BLOCKED[2].fx, BLOCKED[2].subj)
    assert(#bott:GetNearbyTowers(1200, true) > 0 and
        #Jt.GetNearbyHeroes(bott, 1200, true, BOT_MODE_NONE) == 0,
        'the tower control is no longer refused by the tower clause alone')
end

tests['[frame] disjointness at a frame: the sibling keeps its own'] = function()
    -- The load-bearing control for an INVERTED clause: a frame with an EMPTY 1600
    -- ring that 'fieldbuy' owns. This lever must refuse it.
    local J, bot = rf.load(EMPTY_RING.fx, EMPTY_RING.subj)
    assert(math.abs(J.GetHP(bot) - EMPTY_RING.hp) < 5e-4, 'the control moved')
    assert(#J.GetNearbyHeroes(bot, 1600, true, BOT_MODE_NONE) == 0,
        'an enemy hero is inside 1600 on the disjointness control, so it no longer '
        .. 'controls anything')
    J.IsSoakCandidate = function(s) return s == 'buyring' end
    assert(J.ShouldFieldBuyRegenRing(bot) == false, 'this lever accepts a frame with '
        .. 'an EMPTY 1600 ring -- the inversion is gone and the four domains overlap')
    J.IsSoakCandidate = function(s) return s == 'fieldbuy' end
    assert(J.ShouldFieldBuyRegen(bot) == true, "the control is no longer "
        .. "'fieldbuy''s frame, so it proves nothing about the partition")
end

tests['[frame] out of band on the high side'] = function()
    local J, bot, arm = frame(OOB_HIGH.fx, OOB_HIGH.subj)
    assert(math.abs(J.GetHP(bot) - OOB_HIGH.hp) < 5e-4, 'the high control moved')
    arm(true)
    assert(J.ShouldFieldBuyRegenRing(bot) == false, 'a healthy bot buys a field '
        .. 'salve -- the ceiling is gone')
end

tests['[frame] unarmed, the lever is inert on every frame it would flip'] = function()
    -- Gated means gated: the shipped answer on all 10 domain frames must be
    -- unchanged with nothing armed. Driven over the listed rows rather than asserted
    -- once, because "inert" is a claim about the whole flip set.
    local nChecked = 0
    for _, r in ipairs(M.flips) do
        local J, bot = rf.load('tests/fixtures/' .. r.fixture .. '.lua', r.hero)
        J.IsSoakCandidate = function() return false end
        assert(site(J, bot) == false, r.fixture .. '/' .. r.hero
            .. ' answers TRUE with NOTHING armed -- the behaviour is shipping')
        nChecked = nChecked + 1
    end
    assert(nChecked == C('ring_domain'), 'only ' .. nChecked .. ' of '
        .. C('ring_domain') .. ' domain frames were re-checked unarmed')
end

tests['[frame] armed, every domain frame flips -- and every refusal stands'] =
function()
    -- The other half of the same claim, and the one that would catch a lever that
    -- fires on the pinned frame by accident: all 10 listed frames must flip under
    -- this id ALONE, and every frame the sweep listed as refused must still be
    -- refused.
    for _, r in ipairs(M.flips) do
        local J, bot = rf.load('tests/fixtures/' .. r.fixture .. '.lua', r.hero)
        J.IsSoakCandidate = function(s) return s == 'buyring' end
        assert(site(J, bot) == true, r.fixture .. '/' .. r.hero
            .. ' is in the measured domain but does not flip when armed')
    end
    local nRefused = 0
    for _, r in ipairs(M.refused) do
        local J, bot = rf.load('tests/fixtures/' .. r.fixture .. '.lua', r.hero)
        J.IsSoakCandidate = function(s) return s == 'buyring' end
        assert(J.ShouldFieldBuyRegenRing(bot) == false, r.fixture .. '/' .. r.hero
            .. ' (refused for: ' .. r.why .. ') is accepted by this lever -- a '
            .. 'clause it inherits unchanged has stopped refusing')
        nRefused = nRefused + 1
    end
    assert(nRefused > 0, 'the sweep listed no refused frames at all, so this half of '
        .. 'the claim was never driven')
    assert(nRefused == C('band_nosrc') - C('ring_domain'), string.format(
        'the refusal list (%d) is not the complement of the domain (%d of %d '
        .. 'empty-handed band frames)', nRefused, C('ring_domain'), C('band_nosrc')))
end

return tests

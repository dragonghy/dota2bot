-- [buytower 2026-09-06, 协同组] Owner priority P2: a hurt bot in no danger must NOT
-- go home -- "血量低也尽量不要回程,买大药或其他补给". This file is about the second
-- half of that sentence, and about a clause that is doing a job it was not written
-- for.
--
-- ⭐ THE FINDING, AS A RATIONALE THAT DOES NOT TRANSFER. J.IsFieldRegenSituation
-- carries `#bot:GetNearbyTowers( 1200, true ) > 0 then return false`, and its own
-- comment says exactly why: driving mode_retreat_generic over the fixture corpus
-- showed the predicate firing on a frame whose retreat bid comes from ShouldRun's
-- 前期谨慎冲塔 clause -- a LOCAL back-off from a tower -- and "suppressing it would
-- leave the bot parked in tower range". That is an argument about CANCELLING A
-- RETREAT BID. It is a correct argument, and it is an argument about the HOLD side
-- (J.ShouldRegenNotGoHome's two wrappers), which is what cancels retreat bids.
-- The SUPPLY side cancels nothing: J.ShouldFieldBuyRegen and its 'buyband' sibling
-- only add an OR arm to a purchase. A bot that buys a salve near an enemy tower is
-- exactly as free to walk out of tower range and drink it as it was before. So on the buy arms this clause vetoes for a reason that has nothing to
-- do with buying, and the bot is left empty-handed and goes home instead.
--
-- Measured, not argued (tests/_buytower_sweep.lua, 1012 live turbo hero frames):
--   305 frames sit inside the PROMOTED [0.18, 0.75] band and 163 of those carry
--   nothing drinkable in a main slot. Of those 163, exactly **8** have an empty
--   1600 ring, no attributable hero damage, and an enemy tower inside 1200 -- the
--   tower clause is the only thing holding them out of the field-buy family. 99
--   are held out by the ring and 28 by attributed damage; those keep their vetoes
--   and this lever does not touch them.
-- The bearing frame is tests/fixtures/f_260820_102030_wk_tower_in_reach.lua at
-- t=444.5: a skeleton_king at 329/1154 = 28.5% HP carrying clarity / magic_wand /
-- gauntlets / quelling_blade / phase_boots -- nothing drinkable at all -- with the
-- nearest LIVE enemy hero 4,936 units off and the nearest enemy tower 787 units
-- away. Tower attack range is 700, so on that frame this 1200 clause is not even
-- reaching the tower's own range.
--
-- ⭐⭐ WHY THE CLAUSE IS INVERTED RATHER THAN DROPPED, and this is the reusable
-- part. Dropping it inside a shared helper would have made the three purchase arms
-- OVERLAP, and an overlapping arm is one an isolation wave cannot attribute:
-- 'fieldbuy' and 'buyband' both answer only where the 1200 ring is EMPTY, so
-- requiring it to be OCCUPIED here makes the three domains disjoint by
-- construction rather than by measurement -- and disjoint across the WHOLE HP
-- band, which is why this lever spans the promoted [0.18, 0.75] instead of owning
-- a slice of it. `overlap_tower_buy` and `overlap_tower_hurt` are asserted 0 below,
-- with `overlap_probe_runs == live` so that "measured and empty" cannot read the
-- same as "not measured" (GH #171).
--
-- ⭐⭐⭐ THE COST OF THE EDIT WAS MEASURED, NOT GUESSED -- and it came out the
-- opposite way from the 'buyband' round one day earlier. There the tempting edit
-- (an optional argument on J.IsFieldRegenSituation) turned SEVEN detector files
-- red, none of which had anything to say about that lever, and it was reverted.
-- Here the same discipline was applied to the edit that WAS made: adding a third
-- OR arm to the purchase site turned exactly THREE files red --
-- test_gated_helper_nesting_census (three new gate-inside-a-gate rows),
-- test_bagsalve_backpack_source (J.HasFieldRegenSource's caller census, 4 -> 5)
-- and test_buyband_hp_band (its WIRE_OR literal pinned the two-arm text). Every
-- one of the three is ABOUT this change and each was answered by re-reading its
-- property, not by re-baselining a number: the census rows were classified (A)/(I)/
-- (W) by hand, the caller was added to the "carries its own IsModeTurbo" list, and
-- the WIRE_OR literal became a pattern that still fails on a replacement or an
-- `and` but tolerates a further arm of the same OR. ⇒ **The test is not "how many
-- files go red", it is "does each red file have something to say about this
-- change".** Seven that do not is a re-baseline; three that do is the change being
-- reviewed by the tree.
--
-- WHAT IS ASSERTED. Not gate plumbing. The shipped call-site predicate trio is
-- driven on real frames with every candidate disarmed and then with exactly
-- 'buytower' armed, and the CAUSE of each changed answer is read off the frame's
-- own world state. The negative controls are frames INSIDE the band carrying
-- nothing, refused by a clause this lever inherited unchanged.
--
-- WHAT IS NOT BOUGHT, stated rather than implied:
--   * a salve being purchased. The nine engine clauses at the call site (stock,
--     gold, stash, courier distance, empty slot) are unreadable from a fixture and
--     gold is not networked into a .dem at all (GH #495), so the flip set is the
--     gold-blind superset of the live one.
--   * a trip home being cancelled. This is a purchase predicate; the decision-side
--     ids ('stayfield', 'stayfield2', 'stayattr') are the ones that hold a bot.
--   * anything about frames with no buildings. 43 of the corpus fixtures carry
--     none (GH #100), so on those the tower clause is unverifiable in either
--     direction -- `fixtures_with_buildings` is asserted below so this lever's
--     domain is never mistaken for the corpus.
--   * that the 8 domain frames are out of the tower's REACH. A draft of this file
--     said they were; measured off the fixture files directly (not through bots/,
--     and a one-off measurement rather than an assertion here), the eight nearest
--     enemy-tower distances are 221 / 688 / 787 / 987 / 1021 / 1039 / 1090 / 1130
--     -- so TWO of them are inside the 700 attack range. That does not undo the
--     lever (buying is instantaneous and pins the bot nowhere; it can still walk
--     out and drink), but the honest form of the bound is "the corpus contains two
--     such frames", not "the corpus cannot produce one". Tower damage itself is
--     not separable in a fixture's `recent_damage` (its `kind` is only creep or
--     hero), which is a corpus-side gap, not something assertable here.
--   * agreement with 'fieldcreep'. Like 'buyband', this lever does not copy that
--     gated creep veto (naming another id here would freeze the clause FALSE the
--     day it is promoted -- the 'pullcad' trap). Unlike 'buyband', the
--     disagreement on THIS corpus is NOT empty: 2 of the 8 domain frames took
--     creep damage in the same 3-second window, so while 'fieldcreep' is armed the
--     arms disagree on those two. That is a measured number below, not a promise.

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')
local cs = require('corpus_scale')

local SWEEP = 'lua5.1 tests/_buytower_sweep.lua 2>/dev/null'
local JMZ = 'bots/FunLib/jmz_func.lua'
local PURCHASE = 'bots/item_purchase_generic.lua'

-- The pinned frame: the fixture whose own name is about this clause. skeleton_king
-- at 28.5% HP, nothing drinkable, no enemy hero inside 1600, the nearest enemy
-- tower 787 units off.
local FX = 'tests/fixtures/f_260820_102030_wk_tower_in_reach.lua'
local SUBJ = 'npc_dota_hero_skeleton_king'
-- A second frame near the OTHER end of the band and on another fixture, pinned so
-- the finding is neither one fixture nor one HP value wide.
local FX2 = 'tests/fixtures/f_260820_043710_lich_defend_pos5.lua'
local SUBJ2 = 'npc_dota_hero_tidehunter'

-- Negative controls. Both are INSIDE the band and carrying nothing, so the only
-- thing that can refuse them is a clause this lever inherited UNCHANGED. If either
-- flips, the lever is being credited with work the ring and attribution clauses do.
local BLOCKED = {
    { fx = 'tests/fixtures/f_071423_sky_rescue.lua',
      subj = 'npc_dota_hero_sven', hp = 0.6869, why = 'ring' },
}
-- The disjointness control, and it is the load-bearing one for this lever: a frame
-- with NO enemy tower inside 1200 that 'fieldbuy' owns. 'buytower' must refuse it
-- (its inverted clause) while 'fieldbuy' still accepts it.
local NO_TOWER = { fx = 'tests/fixtures/f_071903_sven_idle.lua',
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
    J.IsSoakCandidate = function(s) return armed and s == (sId or 'buytower') end
    return J, bot, function(b) armed = b end
end

--- The CALL SITE's predicate, as the call site itself spells it: the OR of the
--- three arms. Driving this rather than the new function alone is what makes
--- "arming can only add TRUEs" a statement about the shipped decision instead of
--- about a helper nobody calls.
local function site(J, bot)
    return (J.ShouldFieldBuyRegen(bot) or J.ShouldFieldBuyRegenHurt(bot)
        or J.ShouldFieldBuyRegenTower(bot)) and true or false
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
    assert(M.g.STAY == 1, 'the sweep could not slice J.ShouldStayAndRegen out of '
        .. JMZ)
    assert(M.g.TOW_SOAKID == 1, "the 'buytower' id is no longer in "
        .. 'J.ShouldFieldBuyRegenTower (comments are stripped before this is read)')
    assert(M.g.TOW_TURBO == 1, 'the lever lost its own IsModeTurbo -- it repeats '
        .. 'the situation clauses instead of calling the predicate that asks, so '
        .. 'nothing else would keep it out of normal mode')
    -- Every [source] fact in this file is a claim about CODE, and this lever ships
    -- with a long comment naming J.IsSoakCandidate, three sibling ids, every
    -- constant and the call site while explaining them. So the stripping is
    -- asserted DIRECTLY rather than inferred from some count landing on its
    -- expected value -- the 'staybag' round's M5, where an exact id total was the
    -- only thing catching the "stop stripping" mutant and relaxing that total for
    -- an unrelated and correct reason took the mutant's only detector with it.
    assert(M.g.SIT_STRIPPED == 1 and M.g.TOW_STRIPPED == 1
        and M.g.STAY_STRIPPED == 1,
        'the sweep is parsing UNSTRIPPED source (comment markers survive in a '
        .. 'sliced block) -- every [source] assertion in this file could then be '
        .. 'satisfied by prose')
end

tests['[source] the inverted clause IS the lever'] = function()
    -- The whole disjointness argument rests on this one comparison, so both
    -- directions are read off the source rather than trusted. A mutant that
    -- un-inverts it leaves every counter looking plausible while the three arms
    -- start overlapping.
    assert(M.g.TOW_TOWER_INVERTED == 1, 'the lever no longer requires an enemy '
        .. 'tower inside 1200 (`== 0 then return false`) -- its domain now '
        .. "overlaps 'fieldbuy' and 'buyband', and no isolation wave can tell the "
        .. 'three arms apart')
    assert(M.g.SIT_TOWER_PLAIN == 1, 'J.IsFieldRegenSituation no longer refuses on '
        .. 'a tower inside 1200 -- if that clause was removed or moved, this lever '
        .. 'is answering a question nobody is asking any more; re-read the finding')
    assert(M.g.HURT_TOWER_PLAIN == 1, "the 'buyband' arm no longer refuses on a "
        .. 'tower inside 1200, so the two domains are no longer disjoint by '
        .. 'construction')
end

tests['[source] the band is the promoted one, parsed not written down'] = function()
    -- Neither bound is a new tuned constant: both are parsed out of the functions
    -- that already own them. If either moves, this lever spans a different band
    -- and this file must be re-read, not re-baselined.
    assert(M.g.TOW_HP_LO == M.g.SIT_HP_LO, "the lever's floor ("
        .. tostring(M.g.TOW_HP_LO) .. ") is no longer J.IsFieldRegenSituation's ("
        .. tostring(M.g.SIT_HP_LO) .. ') -- it is a new tuned constant now')
    assert(M.g.TOW_HP_HI == M.g.STAY_HP_HI, "the lever's ceiling ("
        .. tostring(M.g.TOW_HP_HI) .. ") is no longer the PROMOTED veto's ("
        .. tostring(M.g.STAY_HP_HI) .. ') -- it is a new tuned constant now')
    assert(M.g.SIT_HP_LO == 0.18 and M.g.STAY_HP_HI == 0.75,
        'the two owning constants themselves moved (0.18 / 0.75) -- equality '
        .. 'above would then be two copies of a new number')
    -- ...and the band deliberately CROSSES the sibling ceiling, which is only
    -- sound because the tower clause is inverted. Asserted so that a future
    -- narrowing to one side of 0.55 is a decision, not a drift.
    assert(M.g.TOW_HP_HI > M.g.SIT_HP_HI and M.g.TOW_HP_LO < M.g.SIT_HP_HI,
        'the lever no longer spans J.IsFieldRegenSituation\'s 0.55 ceiling; its '
        .. 'domain is now a band split as well as a clause inversion, and the '
        .. 'census below is measuring something else')
end

tests['[source] the copied clauses have not drifted'] = function()
    -- The price of repeating clauses instead of calling the sibling, made
    -- checkable. Each pair is parsed from its own function body.
    assert(M.g.TOW_RING == M.g.SIT_RING, 'the empty-ring radius drifted: lever '
        .. tostring(M.g.TOW_RING) .. ' vs sibling ' .. tostring(M.g.SIT_RING))
    assert(M.g.TOW_TOWER == M.g.SIT_TOWER, 'the tower radius drifted: lever '
        .. tostring(M.g.TOW_TOWER) .. ' vs sibling ' .. tostring(M.g.SIT_TOWER))
    assert(M.g.TOW_ATTR_WINDOW == M.g.SIT_ATTR_WINDOW,
        'the damage lookback drifted: lever ' .. tostring(M.g.TOW_ATTR_WINDOW)
        .. ' vs sibling ' .. tostring(M.g.SIT_ATTR_WINDOW))
    assert(M.g.TOW_ATTR_RADIUS == M.g.SIT_ATTR_RADIUS,
        'the attribution radius drifted: lever ' .. tostring(M.g.TOW_ATTR_RADIUS)
        .. ' vs sibling ' .. tostring(M.g.SIT_ATTR_RADIUS))
    assert(M.g.SIT_RING == 1600 and M.g.SIT_TOWER == 1200
        and M.g.SIT_ATTR_RADIUS == 3000 and M.g.SIT_ATTR_WINDOW == 3,
        'the sibling situation constants themselves moved (1600/1200/3000/3.0) -- '
        .. 'equality above would then be two copies of a new number')
end

tests['[source] the shipped predicate was NOT touched'] = function()
    -- The reverted signature change of the 'buyband' round, asserted here too so
    -- it cannot come back through this lever by accident.
    assert(M.g.SIT_CALLS_2ARG == 0, 'J.IsFieldRegenSituation is now called with a '
        .. 'second argument. That was tried on 2026-09-06 and reverted: seven '
        .. 'detector files parse its signature or its band as literal text')
    assert(M.g.SIT_CALLS_1ARG == 2, 'J.IsFieldRegenSituation now has '
        .. tostring(M.g.SIT_CALLS_1ARG) .. ' callers, not the 2 this file '
        .. 'measured (J.ShouldRegenNotGoHome, J.ShouldFieldBuyRegen)')
    assert(M.g.TOW_CALLS_SIT == 0, 'the lever now CALLS J.IsFieldRegenSituation. '
        .. 'It is written to repeat three of its clauses and INVERT the fourth; a '
        .. 'call would re-impose the very veto this lever exists to lift')
    assert(M.g.SIT_HAS_BUYTOWER == 0, "the 'buytower' id appears inside the shared "
        .. 'predicate -- one arm would then move three families at once')
    -- Bought by a surviving mutant in the 'stayattr' round (M8, a mis-aimed
    -- substitution that inserted a second gated clause into the SHARED predicate
    -- while nothing was counting ids there). Exactly one id belongs in that body
    -- today: 'fieldcreep'.
    assert(M.g.SIT_NIDS == 1, 'J.IsFieldRegenSituation now names '
        .. tostring(M.g.SIT_NIDS) .. ' soak ids in code, not 1. Every gate in that '
        .. "body moves THREE families on one arm ('stayfield', 'stayfield2', "
        .. "'fieldbuy') -- the 'lanefix' bundle shape")
end

tests["[source] one id, one condition -- the 'pullcad' invariant"] = function()
    assert(M.g.TOW_NIDS == 1, 'J.ShouldFieldBuyRegenTower now names '
        .. tostring(M.g.TOW_NIDS) .. ' soak ids in code; expected exactly 1')
    assert(M.g.TOW_IDS_MAX_PER_COND == 1, 'two ids share one condition in this '
        .. "lever -- the 'pullcad' trap: the gate freezes FALSE the day either id "
        .. 'is promoted')
    -- Honest bound, from both sides: the creep veto is still the sibling's and
    -- still not copied here.
    assert(M.g.SIT_HAS_FIELDCREEP == 1, "the 'fieldcreep' veto left "
        .. 'J.IsFieldRegenSituation -- if it was PROMOTED, this lever must inherit '
        .. 'it (it can be copied safely once no id names it); re-read the bound')
    assert(M.g.TOW_HAS_FIELDCREEP == 0, "this lever now names 'fieldcreep', which "
        .. 'freezes that clause FALSE the day that id is promoted')
end

tests['[source] the wiring is a THIRD OR arm, not a replacement'] = function()
    assert(M.g.WIRE_TOW == 1, 'the lever is not consulted at the purchase site in '
        .. PURCHASE .. ' -- an unwired predicate ships nothing')
    assert(M.g.WIRE_BUY == 1, "the 'fieldbuy' arm disappeared from the purchase "
        .. 'site; this lever was added ALONGSIDE it, not in place of it')
    assert(M.g.WIRE_HURT == 1, "the 'buyband' arm disappeared from the purchase "
        .. 'site; this lever was added ALONGSIDE it, not in place of it')
    assert(M.g.WIRE_OR3 == 1, 'the three arms are no longer one OR at the purchase '
        .. 'site -- the direction argument (arming can only add TRUEs) rests on '
        .. 'that shape')
    assert(M.g.WIRE_TOW_CALLS == 1, 'the lever has ' .. tostring(M.g.WIRE_TOW_CALLS)
        .. ' call sites in ' .. PURCHASE .. ', not 1 -- a second site would ship '
        .. 'the behaviour through a path this file never drives')
    assert(M.g.TOW_DEFS_IN_JMZ == 1, 'J.ShouldFieldBuyRegenTower is referenced '
        .. tostring(M.g.TOW_DEFS_IN_JMZ) .. ' times inside ' .. JMZ
        .. ' (definition only expected) -- an internal caller would bypass the '
        .. 'call site this file drives')
    assert(M.g.WIRE_PURCHASES_FLASK == 1, 'the guarded block no longer buys a '
        .. 'flask')
    -- One arming point in code, so the behaviour cannot ship through a second site
    -- nobody gated. Comments are stripped first: this lever's own comment names
    -- 'buytower' several times while explaining it.
    local code = (read_file(JMZ) .. read_file(PURCHASE)):gsub('%-%-[^\n]*', '')
    local _, n = code:gsub("'buytower'", '')
    assert(n == 1, "'buytower' appears " .. n .. ' times in CODE across the two '
        .. 'files that decide this purchase; expected 1')
end

-- --------------------------------------------------------- the census ------

tests['[census] the corpus, and what holds the empty-handed frames out'] = function()
    cs.corpus(C('fixtures'), 'buytower fixture corpus')
    cs.ratchet(C('live'), 1012, 'live hero frames')
    cs.universal(C('turbo'), C('live'), 'every corpus frame is turbo', cs.FLOOR)
    assert(C('raises') == 0, C('raises') .. ' frames raised inside a driven call '
        .. '-- a raised frame is not a measured frame')
    -- ⭐ The bound that is specific to a lever about BUILDINGS. 43 of the corpus
    -- fixtures carry none at all (GH #100), so on those frames the tower clause is
    -- not merely unsatisfied -- it is unverifiable, in both directions. Pinned so
    -- this lever's domain can never be mistaken for the corpus, and so a corpus
    -- that lost its buildings reads as a finding rather than as a shrinking lever.
    cs.ratchet(C('fixtures_with_buildings'), 66, 'fixtures carrying buildings')
    assert(C('fixtures_with_buildings') < C('fixtures'), 'every fixture now '
        .. 'carries buildings -- if that is real, the GH #100 bound this file '
        .. 'quotes is stale and should be re-read, not deleted')
    cs.ratchet(C('band_all'), 305, 'frames inside the promoted [0.18,0.75] band')
    cs.ratchet(C('band_nosrc'), 163, 'band frames carrying nothing drinkable')
    cs.ratchet(C('nosrc_ring_busy'), 99, 'held out by the 1600 ring')
    cs.ratchet(C('nosrc_attr'), 28, 'held out by attributed hero damage')
    cs.ratchet(C('nosrc_tower'), 22, 'with an enemy tower inside 1200')
    cs.ratchet(C('nosrc_clean'), 53, 'held out by nothing (the siblings own these)')
    -- The lever's domain is the tower-AND-NOTHING-ELSE slice, and it is strictly
    -- smaller than the frames that merely have a tower nearby: the other 14 are
    -- refused by the ring or the attribution clause, which this lever inherits
    -- unchanged. Written as an inequality rather than as a second literal so that
    -- the RELATION is what is pinned.
    assert(C('nosrc_tower_only') < C('nosrc_tower'), 'every frame with a tower '
        .. 'nearby is now in this lever\'s domain -- the ring and attribution '
        .. 'clauses have stopped refusing any of them, which they are what this '
        .. 'lever inherits unchanged')
    cs.ratchet(C('nosrc_tower_only'), 8, "the lever's domain")
end

tests['[census] the domain is reached two independent ways, and they agree'] =
function()
    -- ⭐ THE CROSS-CHECK. `flips_buytower` comes from DRIVING the shipped call-site
    -- predicate trio (nothing else armed); `tower_domain` comes from an
    -- independent prefix walk over the frame's own world state. Two routes to the
    -- same set: if they disagree, one of them is measuring something else and no
    -- number in this file can be trusted.
    assert(C('flips_buytower') == C('tower_domain'), string.format(
        'driven flips (%d) and the prefix walk (%d) disagree about this lever\'s '
        .. 'domain', C('flips_buytower'), C('tower_domain')))
    assert(C('tower_domain') == C('nosrc_tower_only'), string.format(
        'the domain (%d) is no longer the tower-only slice of the census (%d) -- '
        .. 'the two are the same set computed in two places, and a gap means one '
        .. 'of them grew a clause the other does not have',
        C('tower_domain'), C('nosrc_tower_only')))
    cs.ratchet(C('flips_buytower'), 8, 'frames this lever buys for')
    assert(C('flips_buytower') > 0, 'this lever flips NOTHING with only its own id '
        .. 'armed. That is the failure the standalone shape exists to prevent: a '
        .. 'single-arm isolation wave would read a correct zero and the id would '
        .. 'be recorded as "tested, no effect" (GH #542)')
    assert(#M.flips == C('flips_buytower'), 'the sweep listed ' .. #M.flips
        .. ' flip rows for ' .. C('flips_buytower') .. ' counted flips')
    -- The band split of the domain is an IDENTITY, not two independent counts.
    assert(C('tower_below_sit_ceiling') + C('tower_above_sit_ceiling')
        == C('tower_domain'), string.format(
        'the domain no longer splits at the sibling ceiling: %d + %d ~= %d',
        C('tower_below_sit_ceiling'), C('tower_above_sit_ceiling'),
        C('tower_domain')))
    -- ...and it lands on BOTH sides of 0.55, which is the measured form of "this
    -- lever is a clause inversion, not a band". If it ever falls entirely on one
    -- side, the simpler design (extend a sibling's band) becomes available and
    -- this one should be re-argued.
    assert(C('tower_below_sit_ceiling') > 0 and C('tower_above_sit_ceiling') > 0,
        'the domain now sits entirely on one side of 0.55; a band extension of an '
        .. 'existing arm would be the simpler lever and this one needs re-arguing')
end

tests['[census] direction and disjointness are measured, not argued'] = function()
    assert(C('flip_true_to_false') == 0, C('flip_true_to_false') .. ' frames turn '
        .. 'TRUE -> FALSE when the lever is armed. The call site ORs a new arm in, '
        .. 'so that is structurally impossible -- something else moved')
    assert(C('arm_leak') == 0, 'the sweep armed more than one id on '
        .. C('arm_leak') .. ' frames, so a flip cannot be attributed to this lever')
    -- ⭐ The probe must PROVE it ran. Both overlap columns are claims whose whole
    -- content is a zero, and a probe that stopped driving prints the same zero as
    -- one that drove 1012 frames and found nothing (GH #171).
    assert(C('overlap_probe_runs') == C('live'), string.format(
        'the disjointness probe ran on %d of %d live frames -- an unrun probe '
        .. 'prints the same zero as an empty one',
        C('overlap_probe_runs'), C('live')))
    assert(C('overlap_tower_buy') == 0, C('overlap_tower_buy') .. " frames answer "
        .. "TRUE for both 'buytower' and 'fieldbuy'. The tower clause is inverted "
        .. 'here precisely so that cannot happen; an overlap means one id can be '
        .. "credited with the other's frames")
    assert(C('overlap_tower_hurt') == 0, C('overlap_tower_hurt') .. " frames answer "
        .. "TRUE for both 'buytower' and 'buyband' -- same defect, other sibling")
end

tests['[census] the honest bounds, as numbers'] = function()
    -- The GH #123 backpack asymmetry, same on this arm as on both siblings: a
    -- backpacked salve is invisible to J.HasFieldRegenSource (it stops at slot 5)
    -- and is caught at the CALL SITE by `bot:FindItemSlot('item_flask') < 0`, which
    -- does see the backpack. Zero on this corpus; the counter is what says so the
    -- day it stops being zero.
    assert(C('tower_with_bag_salve') == 0, C('tower_with_bag_salve') .. ' domain '
        .. 'frames carry a backpacked salve. That is not a defect -- the call site '
        .. 'FindItemSlot clause refuses them -- but the bound is no longer empty '
        .. 'and the report that quotes it as 0 is stale')
    -- ⚠️ AND THE ONE THAT IS NOT EMPTY, which is the difference between this lever
    -- and 'buyband'. The clause NOT copied from J.IsFieldRegenSituation is the
    -- gated 'fieldcreep' creep-damage veto (copying it would name another
    -- candidate's id and freeze this clause FALSE the day that id is promoted --
    -- the 'pullcad' trap). So while 'fieldcreep' is armed, the arms of the call
    -- site disagree on any frame where the bot is being chewed by creeps -- and on
    -- THIS corpus that is 2 of the 8 domain frames, not 0 as it was for 'buyband'.
    -- Pinned as an exact number so a wave that arms both ids reads the size of the
    -- disagreement off a test rather than guessing it.
    assert(C('tower_with_creep_damage') == 2, C('tower_with_creep_damage')
        .. " domain frames carry creep damage in the same 3s window, not the 2 "
        .. "this file measured. That number is the width of the disagreement "
        .. "between this arm and 'fieldcreep' when both are armed; re-read it "
        .. 'rather than re-baselining it')
    assert(C('tower_with_creep_damage') < C('tower_domain'), 'every domain frame '
        .. "now carries creep damage -- with 'fieldcreep' armed the two arms would "
        .. 'disagree on the WHOLE domain, and the lever should inherit that veto '
        .. 'as soon as no id names it')
end

-- ------------------------------------------------------ the pinned frames --

tests['[frame] the bearing frame: hurt, alone, empty-handed, near a tower'] =
function()
    local J, bot, arm = frame(FX, SUBJ)
    -- The world state first, so the flip below is attributed to the frame's own
    -- facts and not to a stub.
    local nHP = J.GetHP(bot)
    assert(math.abs(nHP - 0.2851) < 5e-4, 'the pinned frame moved: HP reads '
        .. string.format('%.4f', nHP) .. ', not 0.2851')
    assert(#J.GetNearbyHeroes(bot, 1600, true, BOT_MODE_NONE) == 0,
        'an enemy hero is inside 1600 on the pinned frame -- the ring clause '
        .. 'refuses it and this lever is not what is being measured')
    assert(#bot:GetNearbyTowers(1200, true) > 0, 'no enemy tower is inside 1200 on '
        .. 'the pinned frame -- this is no longer a frame about the tower clause')
    assert(J.HasFieldRegenSource(bot) == false, 'the pinned bot is carrying '
        .. 'something drinkable, so the family has no purchase to make here')
    -- ...and now the decision.
    assert(site(J, bot) == false, 'the purchase site already answers TRUE with '
        .. 'NOTHING armed -- the behaviour is shipping, not gated')
    arm(true)
    assert(site(J, bot) == true, 'the lever does not fire on the very frame it is '
        .. 'pinned to')
    -- The CAUSE, isolated: the only clause standing between this frame and the
    -- sibling arm is the tower one. Re-driven through the sibling to prove it.
    J.IsSoakCandidate = function(s) return s == 'fieldbuy' end
    assert(J.ShouldFieldBuyRegen(bot) == false, "'fieldbuy' accepts this frame "
        .. 'too, so the two arms overlap and this lever buys nothing new')
    J.IsSoakCandidate = function(s) return s == 'buyband' end
    assert(J.ShouldFieldBuyRegenHurt(bot) == false, "'buyband' accepts this frame "
        .. 'too, so the two arms overlap and this lever buys nothing new')
end

tests['[frame] a second frame, other fixture, other end of the band'] = function()
    local J, bot, arm = frame(FX2, SUBJ2)
    local nHP = J.GetHP(bot)
    assert(math.abs(nHP - 0.6758) < 5e-4, 'the second frame moved: HP reads '
        .. string.format('%.4f', nHP) .. ', not 0.6758')
    assert(nHP > 0.55, 'the second frame is no longer above the sibling ceiling, '
        .. 'so the pair no longer spans it')
    assert(#bot:GetNearbyTowers(1200, true) > 0,
        'no enemy tower is inside 1200 on the second frame')
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
        assert(nHP >= 0.18 and nHP <= 0.75, 'the control is outside the band, so '
            .. 'the band refuses it and the clause under test never speaks')
        assert(J.HasFieldRegenSource(bot) == false, 'the control is carrying '
            .. 'something drinkable, so the supply clause refuses it and the '
            .. 'clause under test never speaks')
        arm(true)
        assert(site(J, bot) == false, b.fx .. '/' .. b.subj .. ' (' .. b.why
            .. ') now flips -- this lever is being credited with work the ring '
            .. 'and attribution clauses do')
    end
end

tests['[frame] disjointness at a frame: the sibling keeps its own'] = function()
    -- The load-bearing control for an INVERTED clause: a frame with no enemy tower
    -- nearby that 'fieldbuy' owns. This lever must refuse it.
    local J, bot = rf.load(NO_TOWER.fx, NO_TOWER.subj)
    assert(math.abs(J.GetHP(bot) - NO_TOWER.hp) < 5e-4, 'the control moved')
    assert(#bot:GetNearbyTowers(1200, true) == 0, 'an enemy tower is inside 1200 '
        .. 'on the disjointness control, so it no longer controls anything')
    J.IsSoakCandidate = function(s) return s == 'buytower' end
    assert(J.ShouldFieldBuyRegenTower(bot) == false, 'this lever accepts a frame '
        .. 'with no enemy tower nearby -- the inversion is gone and the three '
        .. 'domains overlap')
    J.IsSoakCandidate = function(s) return s == 'fieldbuy' end
    assert(J.ShouldFieldBuyRegen(bot) == true, "the control is no longer "
        .. "'fieldbuy''s frame, so it proves nothing about the partition")
end

tests['[frame] out of band on the high side'] = function()
    local J, bot, arm = frame(OOB_HIGH.fx, OOB_HIGH.subj)
    assert(math.abs(J.GetHP(bot) - OOB_HIGH.hp) < 5e-4, 'the high control moved')
    arm(true)
    assert(J.ShouldFieldBuyRegenTower(bot) == false, 'a healthy bot buys a field '
        .. 'salve -- the ceiling is gone')
end

tests['[frame] unarmed, the lever is inert on every frame it would flip'] =
function()
    -- Gated means gated: the shipped answer on all 8 domain frames must be
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
    assert(nChecked == C('tower_domain'), 'only ' .. nChecked .. ' of '
        .. C('tower_domain') .. ' domain frames were re-checked unarmed')
end

tests['[frame] armed, every domain frame flips -- and every refusal stands'] =
function()
    -- The other half of the same claim, and the one that would catch a lever that
    -- fires on the pinned frame by accident: all 8 listed frames must flip under
    -- this id ALONE, and every frame the sweep listed as refused must still be
    -- refused.
    for _, r in ipairs(M.flips) do
        local J, bot = rf.load('tests/fixtures/' .. r.fixture .. '.lua', r.hero)
        J.IsSoakCandidate = function(s) return s == 'buytower' end
        assert(site(J, bot) == true, r.fixture .. '/' .. r.hero
            .. ' is in the measured domain but does not flip when armed')
    end
    local nRefused = 0
    for _, r in ipairs(M.refused) do
        local J, bot = rf.load('tests/fixtures/' .. r.fixture .. '.lua', r.hero)
        J.IsSoakCandidate = function(s) return s == 'buytower' end
        assert(J.ShouldFieldBuyRegenTower(bot) == false, r.fixture .. '/' .. r.hero
            .. ' (refused for: ' .. r.why .. ') is accepted by this lever -- a '
            .. 'clause it inherits unchanged has stopped refusing')
        nRefused = nRefused + 1
    end
    assert(nRefused > 0, 'the sweep listed no refused frames at all, so this half '
        .. 'of the claim was never driven')
    assert(nRefused == C('band_nosrc') - C('tower_domain'), string.format(
        'the refusal list (%d) is not the complement of the domain (%d of %d '
        .. 'empty-handed band frames)', nRefused, C('tower_domain'),
        C('band_nosrc')))
end

return tests

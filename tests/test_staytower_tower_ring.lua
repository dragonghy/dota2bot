-- [staytower / owner priority P2, 2026-09-06] The BUILDING half of a PROMOTED
-- function's danger read.
--
-- THE FINDING, AS TWO FUNCTIONS THAT CANCEL THE SAME BID AND DISAGREE ABOUT
-- TOWERS. mode_retreat_generic's ShouldRun answers BOT_MODE_DESIRE_NONE on two
-- legs of this family:
--   * `if J.ShouldStayAndRegen(bot) then` -- PROMOTED (was soak-candidate
--     'tphome'), live in every turbo game, and sitting ABOVE the entire retreat
--     guard chain;
--   * `if J.ShouldRegenNotWalkHome(bot) then` -- gated 'stayfield2', never
--     shipped, and reaching J.IsFieldRegenSituation, which VETOES on
--     `#bot:GetNearbyTowers( 1200, true ) > 0`.
--
-- That veto was not inherited from anywhere. J.IsFieldRegenSituation's own
-- comment says it was added after driving mode_retreat_generic over the whole
-- fixture corpus, and it names the frame and the reason:
--
--   "...firing on f_260819_142047_zuus_ult_denied, where the retreat bid it
--    would have cancelled is ABSOLUTE*1.1 -- and that bid is NOT a trip home.
--    It comes from ShouldRun's 前期谨慎冲塔 clause ... a level-7 Zeus at 40% HP
--    standing 727 units from an enemy tower ... suppressing it would leave the
--    bot parked in tower range."
--
-- The PROMOTED function cancels that same bid on that same frame and has no
-- building clause at all. So the outcome the sibling's clause was written to
-- prevent is what ships today, and this file pins it on the very frame the
-- sibling's comment names: zuus, 40.5% HP, 727.46 units from an enemy tower,
-- no enemy hero inside 1200, no hero damage in the last 3 seconds.
--
-- ⭐ WHY THE MEASURED FLIP SET IS EMPTY THROUGH THE MOCK'S GOLD READ, AND WHY
-- THAT IS THE GOLD CLAUSE'S DOING RATHER THAN THIS LEVER'S. The shipped
-- function's last clause is `if not bHasRegen and bot:GetGold() < 90 then return
-- false end`. Gold is not networked into a .dem (GH #495), so GetGold() reads the
-- mock's `^Get -> 0` scalar on all 1012 live frames and the shipped predicate
-- answers TRUE on only 13 of them -- none carrying a tower. A single `flips`
-- column would be a zero produced by a clause this lever does not touch and
-- attributed to the lever (the GH #171 shape). tests/_staytower_sweep.lua
-- therefore drives the corpus TWICE, with GetGold() overridden to 0 and to 200,
-- and this file asserts BOTH columns: flips_g0 == 0 AND flips_g200 == 12. The
-- gold override is the only synthetic scalar anywhere in the measurement.
--
-- ⭐⭐ DIRECTION IS THE MIRROR OF EVERY OTHER LEVER IN THIS FUNCTION. 'staysrc',
-- 'staybottle' and 'staybag' widen a disjunct and can only ADD TRUEs; this one is
-- a veto and can only REMOVE them, so the armed TRUE set is a strict SUBSET of
-- the shipped one. `flip_false_to_true` must be 0 and is asserted, not argued.
--
-- ⚠️ WHAT THIS FILE CANNOT ASSERT, STATED RATHER THAN IMPLIED.
--   * WHICH bid then wins. Releasing a frame restores the whole guard chain below
--     the call site; the local tower back-off is the bid the sibling's comment
--     measured on the pinned frame, but on the other eleven the winner is decided
--     by clauses this sweep does not drive. The twelve frames are LISTED by the
--     sweep, not just counted, so the set is auditable rather than argued.
--   * THAT THE TOWER IS SHOOTING. 10 of the 12 sit at 700-1200, outside a tower's
--     attack range on that frame; 2 are inside 700. Both numbers are asserted
--     below rather than smoothed into one.
--   * ANYTHING ON A FIXTURE WITH NO BUILDINGS. 43 of the corpus fixtures carry
--     none at all (17th world assertion, GH #100), so on those frames the clause
--     is vacuously satisfied, not verified.

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')

local SWEEP = 'lua5.1 tests/_staytower_sweep.lua 2>/dev/null'
local JMZ = 'bots/FunLib/jmz_func.lua'

-- The pinned frame, and it is the frame the SIBLING's comment names.
local FX = 'tests/fixtures/f_260819_142047_zuus_ult_denied.lua'
local SUBJ = 'npc_dota_hero_zuus'
-- A second flip frame, on another fixture and inside the tower's attack range, so
-- the finding is neither one fixture nor one distance wide.
local FX2 = 'tests/fixtures/f_260820_163429_es_blink_init_621.lua'
local SUBJ2 = 'npc_dota_hero_jakiro'

-- Negative controls. The first two are IN BAND and shipped-TRUE with gold, so the
-- only thing that can leave them TRUE is the absence of a tower: if either flips,
-- the lever is firing outside the clause it claims to be.
local HOLD = {
    { fx = 'tests/fixtures/f_071903_sven_idle.lua',
      subj = 'npc_dota_hero_luna', hp = 0.3512 },
    -- The 063559 replay owner priority P2 itself names.
    { fx = 'tests/fixtures/f_260822_063559_slardar_tp_forward.lua',
      subj = 'npc_dota_hero_slardar', hp = 0.4601 },
}
-- Refused upstream of the lever: a hero inside the PROMOTED 1200 chase ring.
local CHASED = { fx = 'tests/fixtures/f_071423_sky_rescue.lua',
    subj = 'npc_dota_hero_sven', hp = 0.6869 }
-- Out of band on the HIGH side: a healthy bot was never being held here.
local OOB_HIGH = { fx = 'tests/fixtures/f_045650_lion_meatgrinder.lua',
    subj = 'npc_dota_hero_axe', hp = 1.0 }

local tests = {}

local M = (function()
    local p = assert(io.popen(SWEEP, 'r'))
    local raw = p:read('*a')
    p:close()
    local m = { g = {}, c = {}, flips = {}, done = false }
    for line in raw:gmatch('[^\n]+') do
        local k, v = line:match('^G (%S+) (%S+)$')
        if k ~= nil then m.g[k] = tonumber(v) or v end
        local ck, cv = line:match('^C (%S+) (%-?%d+)$')
        if ck ~= nil then m.c[ck] = tonumber(cv) end
        local ff, fh, fp, ft = line:match('^F (%S+) (%S+) ([%d%.]+) ([%d%.]+)$')
        if ff ~= nil then
            m.flips[#m.flips + 1] = { fixture = ff, hero = fh,
                hp = tonumber(fp), tower = tonumber(ft) }
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

--- One fixture frame with every soak candidate disarmed, plus a switch that arms
--- exactly THIS id. Arming one id (never 'all') is the point: a bundle answer
--- cannot be attributed to this lever.
local function frame(path, subject)
    local J, bot = rf.load(path, subject)
    local armed = false
    J.IsSoakCandidate = function(s) return armed and s == 'staytower' end
    return J, bot, function(b) armed = b end
end

--- The gold clause is the one scalar a replay does not carry (GH #495). Every
--- behavioural assertion in this file that needs the shipped predicate to be able
--- to answer TRUE drives it explicitly and says so.
local function with_gold(bot, n, fn)
    local old = bot.GetGold
    bot.GetGold = function() return n end
    local ok, err = pcall(fn)
    bot.GetGold = old
    if not ok then error(err, 0) end
end

-- --------------------------------------------------- the tree, as source ---

tests['[source] the sweep ran, and it parsed CODE rather than prose'] = function()
    assert(M.done, 'the sweep subprocess did not finish (no DONE line) -- every '
        .. 'number below would be a silent zero')
    assert(M.g.STAY_STRIPPED == 1 and M.g.SIT_STRIPPED == 1,
        'the sweep is parsing UNSTRIPPED source -- this lever ships with a comment '
        .. 'that QUOTES the sibling clause verbatim, so every [source] assertion '
        .. 'below could then be satisfied by that quotation')
    assert(M.g.STAY_HAS_STAYTOWER == 1, "the 'staytower' id is no longer in "
        .. 'J.ShouldStayAndRegen (comments are stripped before this is read)')
    assert(M.g.STAY_TURBO == 1, 'J.ShouldStayAndRegen lost its own IsModeTurbo -- '
        .. 'turbo is STRUCTURAL for this lever (the gate does not repeat it), so '
        .. 'without that line the lever would reach normal mode')
end

tests['[source] the radius is the sibling\'s, copied not chosen'] = function()
    assert(M.g.STAY_TOWER_RING == M.g.SIT_TOWER, "the lever's tower radius ("
        .. tostring(M.g.STAY_TOWER_RING) .. ") is no longer J.IsFieldRegenSituation's ("
        .. tostring(M.g.SIT_TOWER) .. ') -- it is a new tuned constant now, and the '
        .. 'whole condition-(c) argument was that it is not')
    assert(M.g.SIT_TOWER == 1200, 'the sibling constant itself moved (1200) -- the '
        .. 'equality above would then be two copies of a new number')
end

tests['[source] the gate is standalone and it is the FIRST conjunct'] = function()
    -- The 'pullcad' trap: two ids in one condition freeze FALSE the day either is
    -- promoted, while check_armed_wiring.py still calls the site WIRED.
    assert(M.g.STAY_IDS_MAX_PER_COND == 1, 'some condition in J.ShouldStayAndRegen '
        .. 'now names ' .. tostring(M.g.STAY_IDS_MAX_PER_COND) .. ' soak ids at '
        .. "once -- that is the 'pullcad' trap, and this function carries five "
        .. 'separate levers that must each stay readable alone')
    assert(M.g.STAY_NIDS >= 5, 'J.ShouldStayAndRegen lost one of its five soak ids '
        .. '(staytower / stayattr / staysrc / staybottle / staybag) -- if a sibling '
        .. "was promoted or dropped, this lever's disjointness story changed with it")
    -- Unarmed inertness is a fact about the code, not a sentence in a comment.
    assert(M.g.STAY_GATE_FIRST == 1, 'the gate is no longer the FIRST conjunct of '
        .. 'the tower condition -- unarmed, the engine call would then happen on '
        .. 'every frame of every turbo game, and "shipped behaviour is byte-'
        .. 'identical" stops being true by construction')
    -- Anchor uniqueness is part of the declaration (GH #550): the plain statement
    -- form of this clause already occurs twice elsewhere in the file.
    assert(M.g.STAY_ANCHOR_FILEWIDE == 1, 'the lever\'s anchor line occurs '
        .. tostring(M.g.STAY_ANCHOR_FILEWIDE) .. ' times in ' .. JMZ .. ' -- a '
        .. '`perl s///` without /g would then cut a different function while still '
        .. 'printing CAUGHT')
end

tests['[source] the call site the whole argument rests on is still there'] =
function()
    assert(M.g.RETREAT_CALLS_STAY == 1, 'mode_retreat_generic no longer calls '
        .. 'J.ShouldStayAndRegen exactly once (' .. tostring(M.g.RETREAT_CALLS_STAY)
        .. ') -- the finding is that THIS call cancels the same retreat bid the '
        .. 'sibling clause was written for; if the call moved, re-read it')
    assert(M.g.RETREAT_RETURNS_NONE == 1, 'that call no longer answers '
        .. 'BOT_MODE_DESIRE_NONE -- it is not cancelling the retreat bid any more '
        .. 'and this lever is about a bid that no longer exists')
end

-- ------------------------------------------------ the pinned frame, real ---

tests['[frame] the pin is the frame the sibling comment names'] = function()
    local J, bot = frame(FX, SUBJ)
    local nHP = J.GetHP(bot)
    assert(nHP > 0.40 and nHP < 0.41, string.format(
        'the pinned frame moved: hp reads %.4f, the sibling comment says ~40%%', nHP))
    assert(J.IsModeTurbo(), 'the pinned frame is no longer turbo -- the whole '
        .. 'function is turbo-only and the pin would prove nothing')
    local tw = bot:GetNearbyTowers(1200, true)
    assert(#tw == 1, 'the pinned frame no longer carries exactly one enemy tower '
        .. 'inside 1200 (' .. tostring(#tw) .. ')')
    local d = GetUnitToUnitDistance(bot, tw[1])
    assert(d > 727 and d < 728, string.format('the pinned tower distance reads '
        .. '%.2f; the sibling comment says 727', d))
    assert(#J.GetNearbyHeroes(bot, 1200, true, BOT_MODE_NONE) == 0,
        'an enemy hero is inside 1200 on the pinned frame -- the PROMOTED chase '
        .. 'ring would refuse it and the pin would be measuring that clause')
    assert(bot:WasRecentlyDamagedByAnyHero(3.0) == false,
        'the pinned frame now carries recent hero damage -- the attributed-danger '
        .. 'clause above the lever would refuse it')
end

tests['[frame] the pin flips, and only when armed'] = function()
    local J, bot, arm = frame(FX, SUBJ)
    with_gold(bot, 200, function()
        arm(false)
        assert(J.ShouldStayAndRegen(bot) == true, 'the PROMOTED veto no longer '
            .. 'holds the bot on the pinned frame with gold >= 90 -- the defect '
            .. 'this lever is about is not reproducing')
        arm(true)
        assert(J.ShouldStayAndRegen(bot) == false, 'armed, the lever does not '
            .. 'release the pinned frame -- the tower clause is not reaching it')
    end)
end

tests['[frame] the pin is INERT with the id un-armed'] = function()
    local J, bot, arm = frame(FX, SUBJ)
    with_gold(bot, 200, function()
        arm(false)
        assert(J.ShouldStayAndRegen(bot) == true,
            'un-armed the answer already changed -- the gate is not gating')
    end)
    -- And with the mock's own gold, both legs agree on FALSE: the gold clause,
    -- not this lever, is what decides that frame today.
    local J2, bot2, arm2 = frame(FX, SUBJ)
    arm2(false)
    local a = J2.ShouldStayAndRegen(bot2)
    arm2(true)
    local b = J2.ShouldStayAndRegen(bot2)
    assert(a == false and b == false, 'with GetGold() reading the mock scalar the '
        .. 'pinned frame is expected FALSE on BOTH legs (the gold clause refuses '
        .. 'it first) -- if that changed, the flips_g0 == 0 column below means '
        .. 'something else')
end

tests['[frame] a second flip frame, inside the tower attack range'] = function()
    local J, bot, arm = frame(FX2, SUBJ2)
    local tw = bot:GetNearbyTowers(1200, true)
    assert(#tw >= 1, 'the second frame lost its enemy tower')
    local d = GetUnitToUnitDistance(bot, tw[1])
    assert(d < 700, string.format('the second frame is no longer INSIDE a tower\'s '
        .. 'attack range (%.2f) -- it was pinned precisely because the pin at '
        .. '727 is not', d))
    with_gold(bot, 200, function()
        arm(false)
        assert(J.ShouldStayAndRegen(bot) == true, 'the second frame is no longer '
            .. 'held by the PROMOTED veto')
        arm(true)
        assert(J.ShouldStayAndRegen(bot) == false, 'the second frame does not flip')
    end)
end

-- --------------------------------------------------- negative controls ----

tests['[control] a held frame with NO tower must not move'] = function()
    for _, h in ipairs(HOLD) do
        local J, bot, arm = frame(h.fx, h.subj)
        local nHP = J.GetHP(bot)
        assert(math.abs(nHP - h.hp) < 0.001, string.format(
            '%s/%s moved: hp %.4f, expected %.4f', h.fx, h.subj, nHP, h.hp))
        assert(#bot:GetNearbyTowers(1200, true) == 0, h.fx .. '/' .. h.subj
            .. ' now carries an enemy tower inside 1200 -- it was chosen as the '
            .. 'control precisely because it does not')
        with_gold(bot, 200, function()
            arm(false)
            assert(J.ShouldStayAndRegen(bot) == true, h.fx .. '/' .. h.subj
                .. ' is no longer held by the PROMOTED veto -- the control has '
                .. 'stopped controlling anything')
            arm(true)
            assert(J.ShouldStayAndRegen(bot) == true, h.fx .. '/' .. h.subj
                .. ' is released by this lever with NO enemy tower inside 1200 -- '
                .. 'the lever is firing outside the clause it claims to be')
        end)
    end
end

tests['[control] frames refused upstream stay refused'] = function()
    local J, bot, arm = frame(CHASED.fx, CHASED.subj)
    assert(#J.GetNearbyHeroes(bot, 1200, true, BOT_MODE_NONE) > 0,
        'the chase control lost its chaser')
    with_gold(bot, 200, function()
        arm(false)
        assert(J.ShouldStayAndRegen(bot) == false, 'the chase control is now HELD '
            .. '-- the PROMOTED 1200 ring stopped refusing')
        arm(true)
        assert(J.ShouldStayAndRegen(bot) == false,
            'arming turned a FALSE into a TRUE; this lever is a veto')
    end)
    local J2, bot2, arm2 = frame(OOB_HIGH.fx, OOB_HIGH.subj)
    assert(J2.GetHP(bot2) > 0.75, 'the out-of-band control is no longer above 0.75')
    with_gold(bot2, 200, function()
        arm2(false)
        assert(J2.ShouldStayAndRegen(bot2) == false, 'a full-HP bot is being held')
        arm2(true)
        assert(J2.ShouldStayAndRegen(bot2) == false, 'a full-HP bot flipped')
    end)
end

-- -------------------------------------------------------- the census ------

tests['[census] the corpus was actually driven'] = function()
    assert(C('live') > 0, 'no live hero frame was driven at all')
    assert(C('probe_runs') == C('live'), string.format(
        'the probe raised on %d of %d live frames -- every counter below is then a '
        .. 'partial read printed as a whole one (GH #171)',
        C('live') - C('probe_runs'), C('live')))
    assert(C('raises') == 0, 'the sweep swallowed an error on ' .. C('raises')
        .. ' frame(s)')
    assert(C('gold_override_ok') == C('live'), 'the gold override did not take on '
        .. 'every frame -- the g200 column would then be a mix of driven and '
        .. 'undriven reads')
    assert(C('arm_leak') == 0, 'the sweep stub armed a sibling id -- the flips '
        .. 'below could be another lever\'s work')
    assert(C('turbo') == C('live'), 'the corpus is no longer all-turbo ('
        .. C('turbo') .. '/' .. C('live') .. ') -- a non-turbo frame answers FALSE '
        .. 'on the first line and would dilute every bucket')
end

tests['[census] the domain is 12, and it equals the independent prefix walk'] =
function()
    assert(C('band') == 305, 'the band bucket moved (' .. C('band')
        .. ', was 305) -- the corpus changed; re-price the lever before trusting '
        .. 'any number below')
    assert(C('prefix_ok') == 125, 'the prefix walk moved (' .. C('prefix_ok')
        .. ', was 125)')
    assert(C('stay_true_g200') == C('prefix_ok'), string.format(
        'the shipped predicate answers TRUE on %d frames but the prefix walk '
        .. 'reaches %d -- with gold driven to 200 the supply clause cannot refuse, '
        .. 'so these two must be the same set',
        C('stay_true_g200'), C('prefix_ok')))
    assert(C('flips_g200') == C('prefix_tower'), string.format(
        'the flip set (%d) is not the tower subset of the prefix walk (%d) -- the '
        .. 'lever is refusing or accepting frames its own clause does not decide',
        C('flips_g200'), C('prefix_tower')))
    assert(C('flips_g200') == 12, 'the domain is ' .. C('flips_g200')
        .. ', was 12 -- re-price before treating this lever as the same lever')
    assert(#M.flips == C('flips_g200'), string.format(
        'the sweep listed %d domain frames but counted %d -- the list is the '
        .. 'auditable half of this claim', #M.flips, C('flips_g200')))
end

tests['[census] the gold zero is the gold clause, not the lever'] = function()
    -- The whole reason this file asserts TWO columns. A single `flips` column
    -- would read 0 here and say nothing about the lever.
    assert(C('flips_g0') == 0, 'flips_g0 is ' .. C('flips_g0')
        .. ' -- with GetGold() reading the mock scalar the shipped predicate can '
        .. 'only answer TRUE where bHasFlask holds, and none of those frames '
        .. 'carries a tower; a nonzero here means one of those two facts changed')
    assert(C('stay_true_g0') == 13, 'the gold-poor TRUE set moved ('
        .. C('stay_true_g0') .. ', was 13)')
    assert(C('stay_true_g0') < C('stay_true_g200'), 'driving gold no longer widens '
        .. 'the shipped TRUE set -- the gold clause has stopped biting and the '
        .. 'two-column construction is measuring nothing')
end

tests['[census] direction: a veto can only remove TRUEs'] = function()
    assert(C('flip_false_to_true') == 0, C('flip_false_to_true') .. ' frame(s) went '
        .. 'FALSE -> TRUE under this id. It is a veto appended with `and`; a '
        .. 'nonzero here means the gate landed negated or the clause was inverted')
    -- ⭐ AND THE COUNTER ABOVE HAS TO PROVE IT CAN COUNT. Its content is entirely
    -- a zero, and direction is fixed by construction, so the statement that bumps
    -- it is never reached on this corpus -- deleting that statement leaves the
    -- same zero. The stand's M14 SURVIVED on exactly that, and per
    -- evidence-discipline rule 2 the suspect was this assertion, not the mutant.
    -- The sweep now tallies both directions through ONE function and calls it a
    -- second time with the legs SWAPPED, so the branch `flip_false_to_true` must
    -- report 0 through is the branch the swapped call reports the whole domain
    -- through.
    assert(C('dirprobe_up_g200') == C('flips_g200'), string.format(
        'the swapped direction probe reports %d where the domain is %d -- the '
        .. 'branch `flip_false_to_true` is asserted to be 0 through was not '
        .. 'executed, so that 0 is unmeasured (GH #171)',
        C('dirprobe_up_g200'), C('flips_g200')))
    assert(C('dirprobe_down_g200') == 0, 'the swapped probe reports '
        .. C('dirprobe_down_g200') .. ' in the mirror direction; the two calls are '
        .. 'no longer mirror images and neither reading means what it says')
    assert(C('dirprobe_up_g0') == 0 and C('dirprobe_down_g0') == 0,
        'the gold-poor leg reports a flip in some direction -- with GetGold() at '
        .. '0 the shipped predicate never reaches this lever')
end

tests['[census] how close the towers actually are, as two numbers'] = function()
    assert(C('domain_tower_close') + C('domain_tower_far') == C('flips_g200'),
        'the distance split does not cover the domain')
    assert(C('domain_tower_close') == 2, 'frames inside 700 moved ('
        .. C('domain_tower_close') .. ', was 2)')
    assert(C('domain_tower_far') == 10, 'frames at 700-1200 moved ('
        .. C('domain_tower_far') .. ', was 10)')
    -- Recorded, not smoothed: most of this domain is a bot in a tower's APPROACH,
    -- not under its guns. The radius is the family's own 1200, and that is the
    -- whole condition-(c) argument for it.
    assert(C('domain_tower_far') > C('domain_tower_close'),
        'the domain is now mostly INSIDE tower range, which is a different (and '
        .. 'stronger) finding than the one this file argues -- rewrite the claim')
end

tests['[replay] every listed domain frame really flips, one id armed'] = function()
    local n = 0
    for _, r in ipairs(M.flips) do
        local J, bot = rf.load('tests/fixtures/' .. r.fixture .. '.lua', r.hero)
        J.IsSoakCandidate = function(s) return s == 'staytower' end
        with_gold(bot, 200, function()
            assert(J.ShouldStayAndRegen(bot) == false, r.fixture .. '/' .. r.hero
                .. ' is in the measured domain but is still held when armed')
        end)
        local J2, bot2 = rf.load('tests/fixtures/' .. r.fixture .. '.lua', r.hero)
        J2.IsSoakCandidate = function() return false end
        with_gold(bot2, 200, function()
            assert(J2.ShouldStayAndRegen(bot2) == true, r.fixture .. '/' .. r.hero
                .. ' is in the measured domain but is NOT held un-armed -- the '
                .. 'flip is being credited to this lever and something else did it')
        end)
        assert(r.tower > 0 and r.tower <= 1200, r.fixture .. '/' .. r.hero
            .. ' is listed with a tower at ' .. tostring(r.tower)
            .. ', outside the radius the lever reads')
        n = n + 1
    end
    assert(n == 12, 'replayed ' .. n .. ' domain frames, expected 12')
end

return tests

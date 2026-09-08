-- [tpdeep / owner priority P2, 2026-09-08] The half of the '回复状态' home-TP
-- branch that its own sibling cannot reach, and the reason it cannot is a
-- measurement, not a preference.
--
-- tests/_tprecov_sweep.lua landed one day earlier with the headline
-- `stop_floor 29`: J.ShouldSipNotTpRecover copies the P2 family's shared 0.18 HP
-- floor, and that floor stops 29 of this branch's 31 corpus trigger frames.  So
-- the branch that actually fires at low HP lives almost entirely BELOW the band
-- every id in the family is allowed to speak in, and the family's decision-side
-- coverage of owner priority P2 stops at a line drawn for a different branch.
--
-- ⭐ WHY THE FLOOR IS RIGHT FOR THE FAMILY AND WRONG FOR THIS BRANCH.  The floor
-- encodes "below this, the genuine escape retreat stands", and for the 撤退
-- branches that is exactly right -- 撤退:2 ASKS for enemies AND recent hero
-- damage, so owner P2's 「危险时撤退合法」 covers it and nothing may touch it.
-- This branch proves the opposite about itself, in its own conjuncts:
-- `J.GetProperTarget(bot) == nil`, `bot:GetAttackTarget() == nil`,
-- `X.CanJuke()`, at most one enemy inside 1600 -- and, alone among the four,
-- NO `bot:WasRecentlyDamagedByAnyHero` at all.  Those are asserted below as
-- numbers off the source.  A branch that fires only when nothing is happening
-- is not an escape, so the shared floor is guarding it against a danger its own
-- trigger already excluded.
--
-- ⛔ AND THE SHARED FLOOR IS STILL NOT TOUCHED.  Lowering
-- J.IsFieldRegenSituation's 0.18 would move 'stayfield', 'stayfield2' and
-- 'fieldbuy' in one edit -- three levers on one push, the lanefix bundle
-- mistake.  This is a separate predicate with its own band, DISJOINT from the
-- sibling's by construction ('tprecov' owns [0.18, ..), 'tpdeep' owns
-- [0.10, 0.18)), and the disjointness is DRIVEN over all 1021 live frames rather
-- than argued: `overlap 0`.  That is what keeps a single-arm wave on either id
-- attributable, which is the non-independence GH #29 reordered the retreat chain
-- to fix.
--
-- ⭐⭐ WHAT THE BAND BUYS, measured: the counterfactual domain -- helper TRUE
-- *and* the branch's frame-readable conjuncts open -- is 2 frames, against the
-- sibling's 1.  And the two levers partition cleanly: the 2 trigger frames the
-- deep helper rejects as `band_high` are EXACTLY the sibling's 2 domain frames
-- (f_114311_drow_pushguard_silent viper 0.191, f_260902_154755_cm_wandbleed_
-- residue zuus 0.185), so between them the family now owns 4 of the 31 trigger
-- frames with no frame counted twice.
--
-- ⚠️ WHAT THIS FILE DOES NOT CLAIM.
--   * It does not claim either band EDGE is corpus-defensible.  Both are
--     measured to cost ZERO domain frames here (`band_low_otherwise_domain 0`,
--     `band_high_otherwise_domain 0`) -- every frame an edge stops, a later
--     clause would have stopped anyway.  So the edges are pinned STRUCTURALLY,
--     with their constants, and never by a domain count.  That is the sibling
--     stand's M6/M7 lesson applied before it could bite: a clause the corpus
--     cannot defend must not be defended by a corpus number.
--   * It does not claim the tower clause fires.  `stop_tower 0` -- no deep-band
--     frame has an enemy tower inside 1200.  The zero is a reading about 1200
--     and not about the mock: `deep_with_any_tower 18` says 18 of the 29 deep
--     frames DO see an enemy tower at some radius (the loader restores real
--     buildings from the dump).
--   * It does not drive the branch body.  `X` in ability_item_usage_generic is
--     a FILE-LOCAL table, so neither the branch nor `X.CanJuke()` is callable
--     from here; `branch_open` is an UPPER BOUND on reachability, never a claim
--     that the branch fires.  Same limit, same reason, as
--     tests/test_stayfield_callsite_domain.lua.
--   * It does not rule on (a)/(b)/(c) for 'tpdeep' and does not ask for
--     admission: owner P4.2 is a freeze, so this lands as FROZEN-HOLD.
--   * It does not re-assert the sibling's call-site invariants.  Those live in
--     tests/test_tprecov_recover_trip.lua and are name-scoped -- and
--     'J.ShouldDeepSipNotTpRecover' is not a superstring of
--     'J.ShouldSipNotTpRecover' (the 'Deep' sits between 'Should' and 'Sip'), so
--     this landing leaves that file's counts byte-identical.  Stated rather than
--     relied on: the PAIR is pinned here, so deleting either call site goes red.

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')
local cs = require('corpus_scale')

-- The pinned frame: obsidian_destroyer, level 8, 16.1% HP -- inside the branch's
-- own trigger, BELOW the family floor that made the sibling silent here, with a
-- field sip in the bag and not a single enemy hero inside 2500.
local FIXTURE = 'tests/fixtures/f_260902_154755_cm_wandbleed_residue.lua'
local HERO = 'npc_dota_hero_obsidian_destroyer'
-- The SAME fixture carries the sibling's own domain frame on a different hero at
-- 18.5% -- one loaded world, both bands, so the partition is witnessed on real
-- frames rather than only in the corpus totals.
local SIB_HERO = 'npc_dota_hero_zuus'
-- The ring control: 1200 empty (the sibling's radius would have passed) and an
-- enemy inside 2500.
local RING_FIXTURE = 'tests/fixtures/f_260819_122930_lina_landed_dead.lua'
local RING_HERO = 'npc_dota_hero_ogre_magi'
local AIUG = 'bots/ability_item_usage_generic.lua'
local JMZ = 'bots/FunLib/jmz_func.lua'

local tests = {}

-- Forward declarations: the sweep is a module local, NEVER a key of `tests`.
-- run_tests.lua iterates that table and calls every value in it.
local sweep
local sweepG

--- Load a frame and hand back a driver that answers the SHIPPED globals with the
--- gate off and then on.  Nothing here re-implements a decision: every answer
--- comes out of the shipped helper itself, from ONE loaded world and ONE bot.
local function drive(path, hero)
    local J, bot = rf.load(path or FIXTURE, hero or HERO)
    local fArmed = function() return false end
    J.IsSoakCandidate = function(sId) return fArmed(sId) and true or false end
    local function answer(f, fn)
        fArmed = f or function() return false end
        local v = (fn or J.ShouldDeepSipNotTpRecover)(bot)
        fArmed = function() return false end
        return v and true or false
    end
    return J, bot, answer
end

local function only(sWanted)
    return function(sId) return sId == sWanted end
end

-- ==========================================================================
-- 1. The frame is what the finding says it is
-- ==========================================================================

tests['[frame] the pinned frame is a DEEP, unchased bot holding a field sip'] = function()
    local J, bot = drive()
    local nHP = J.GetHP(bot)
    assert(nHP < 0.18 and nHP >= 0.10,
        'the frame no longer reads hp in [0.10, 0.18) (' ..
        string.format('%.3f', nHP) .. ') -- it has to be inside the branch\'s '
        .. 'own trigger AND below the family floor that silenced the sibling '
        .. 'here, or this file is driving a world the finding is not about')
    assert(nHP < 0.2, 'the frame fell out of the branch\'s own HP trigger')
    assert(bot:GetLevel() >= 6,
        'the frame no longer clears the branch\'s own level gate')
    assert(#J.GetNearbyHeroes(bot, 2500, true, BOT_MODE_NONE) == 0,
        'the frame no longer reads an empty 2500 ring -- that ring is the whole '
        .. 'licence for drinking instead of leaving at this HP')
    assert(not bot:WasRecentlyDamagedByAnyHero(6.0),
        'the frame now reads hero damage inside 6s; it was chosen because '
        .. 'nothing is happening to this bot')
    assert(J.HasFieldRegenSource(bot),
        'the frame no longer carries a field regen source')
    -- The flask legs must be ABSENT, for the same closed-form reason the sibling
    -- documents: the branch negates all three of them itself.
    assert(J.IsItemAvailable('item_flask') == nil,
        'the frame now carries a main-slot salve; the branch would veto on it '
        .. 'and this frame would stop witnessing anything')
    assert(not bot:HasModifier('modifier_flask_healing')
        and not bot:HasModifier('modifier_tango_heal'),
        'the frame now carries an in-flight flask/tango; same reason')
end

tests['[frame] shipped this frame is silent; armed the veto fires'] = function()
    local _, _, answer = drive()
    assert(answer(nil) == false,
        'UNARMED the helper answers TRUE -- the gate is not the first thing '
        .. 'asked, and this lever is no longer inert in shipped games')
    assert(answer(only('tpdeep')) == true,
        'armed, the lever does not fire on the one frame it was written for')
end

tests['[frame] the sibling is SILENT here, and the floor is why'] = function()
    local J, bot, answer = drive()
    -- The sibling armed on its own id: this frame is below its floor, so it can
    -- say nothing -- which is the entire reason this second lever exists.
    assert(answer(only('tprecov'), J.ShouldSipNotTpRecover) == false,
        'the sibling now answers TRUE on this frame; the two bands overlap and '
        .. 'a single-arm wave on either id is no longer attributable')
    -- ...and it is the FLOOR that silences it, not its danger or supply reads:
    -- both of those are satisfied here (asserted in the frame test above), so
    -- the only clause left standing between it and a TRUE is the 0.18 floor.
    assert(J.GetHP(bot) < 0.18,
        'the frame rose above the family floor, so the sibling\'s silence no '
        .. 'longer isolates the floor as the cause')
    assert(J.HasFieldRegenSource(bot)
        and not (bot:WasRecentlyDamagedByAnyHero(3.0)
            and J.HasNearbyHeroDamager(bot, 3000, 3.0))
        and #J.GetNearbyHeroes(bot, 1200, true, BOT_MODE_NONE) == 0
        and #bot:GetNearbyTowers(1200, true) == 0,
        'a clause of the sibling OTHER than the floor now also fails on this '
        .. 'frame, so its silence here no longer isolates the floor')
end

tests['[frame] the partition, witnessed in ONE loaded world'] = function()
    -- The same fixture carries a hero in the sibling's band. Driving both heroes
    -- from the same dump makes "the bands partition the branch" a fact about
    -- frames, not only about corpus totals.
    local J, bot, answer = drive(FIXTURE, SIB_HERO)
    local nHP = J.GetHP(bot)
    assert(nHP >= 0.18 and nHP < 0.2,
        'the sibling-band hero on this fixture no longer reads hp in '
        .. '[0.18, 0.20) (' .. string.format('%.3f', nHP) .. ')')
    assert(answer(only('tprecov'), J.ShouldSipNotTpRecover) == true,
        'the sibling no longer fires on its own band\'s frame')
    assert(answer(only('tpdeep')) == false,
        'the DEEP helper fires above 0.18 -- the bands overlap, and the two ids '
        .. 'can no longer be told apart in a wave')
end

tests['[frame] the flip belongs to THIS id, not to any armed string'] = function()
    local _, _, answer = drive()
    -- Every id this helper's callees can read, armed one at a time. None of them
    -- may reach the answer: the gate is the first conjunct.
    for _, sOther in ipairs({ 'tprecov', 'stayfield', 'stayfield2', 'fieldsip',
        'staysrc', 'staytower', 'stayattr', 'bagsalve', 'fieldcreep', 'fieldbuy',
        'buyband' }) do
        assert(answer(only(sOther)) == false,
            'arming \'' .. sOther .. '\' alone moves this call site; the flip '
            .. 'would then be attributed to the wrong id in a single-arm wave')
    end
    -- ... and an all-on stub must not be how it fires either, or the id is
    -- decorative and an inner id has quietly turned the lever off.
    assert(answer(function() return true end) == true,
        'with everything armed the helper is silent -- an inner id has turned '
        .. 'this lever off, which is the pullcad shape one level down')
    assert(answer(nil) == false, 'the shipped answer moved between calls')
end

tests['[negative control] an enemy at 1200-2500 is NOT held'] = function()
    -- The lever must be distinguishable from "disable the branch below 0.18",
    -- and this control also prices the ONE clause that is a real tightening of
    -- the sibling rather than a copy: the sibling's own 1200 ring is EMPTY here,
    -- so a helper that had copied 1200 instead of choosing 2500 would hold a bot
    -- with an enemy hero closing from inside half a tango's duration.
    local J, bot, answer = drive(RING_FIXTURE, RING_HERO)
    local nHP = J.GetHP(bot)
    assert(nHP >= 0.10 and nHP < 0.18,
        'the control frame left the deep band (' .. string.format('%.3f', nHP)
        .. '); it can no longer control for the ring clause')
    assert(J.HasFieldRegenSource(bot)
        and not bot:WasRecentlyDamagedByAnyHero(6.0),
        'the control frame now fails an EARLIER clause, so a FALSE below no '
        .. 'longer isolates the ring')
    assert(#J.GetNearbyHeroes(bot, 1200, true, BOT_MODE_NONE) == 0,
        'the control frame\'s 1200 ring is no longer empty -- it stops being a '
        .. 'control for "2500 rather than the sibling\'s 1200"')
    assert(#J.GetNearbyHeroes(bot, 2500, true, BOT_MODE_NONE) > 0,
        'the control frame\'s 2500 ring is now empty too; nothing separates the '
        .. 'two radii here any more')
    assert(answer(only('tpdeep')) == false,
        'armed, the helper holds a bot with an enemy inside 2500 -- it is '
        .. 'behaving as an off switch for the deep band, not as a narrowing')
end

-- ==========================================================================
-- 2. The source says what the finding says (read off CODE, comments stripped)
-- ==========================================================================

local function read_file(path)
    local f = assert(io.open(path, 'r'), path .. ' is not readable')
    local s = f:read('*a')
    f:close()
    return s
end

tests['[source] the branch is the QUIET one -- the licence for reaching below the floor'] = function()
    -- Counts come from the sweep, which strips comments first: this lever ships
    -- with a comment naming its sibling, both radii and the shared floor, so an
    -- unstripped read would let the COMMENT satisfy the assertion (the §EN
    -- mistake).
    local G = sweepG or select(1, sweep())
    assert(G.BRANCH_RECOVER == 1,
        'the 回复状态 branch can no longer be located by its own cast motive')
    assert(G.T1_RECENTDMG == 1 and G.T2_RECENTDMG == 1,
        'a 撤退 branch stopped requiring recent hero damage; the asymmetry that '
        .. 'makes 回复状态 "the quiet trip" no longer holds')
    assert(G.RECOVER_RECENTDMG == 0,
        'the 回复状态 branch now requires recent hero damage -- it has become an '
        .. 'escape branch, and reaching below the family floor on an escape is '
        .. 'exactly what owner P2 does NOT ask for')
    -- ...and the three positive proofs it is not a fight.
    assert(G.RECOVER_PROPERTARGET == 1 and G.RECOVER_ATTACKTARGET == 1
        and G.RECOVER_CANJUKE == 1,
        'the branch dropped one of GetProperTarget==nil / GetAttackTarget==nil / '
        .. 'CanJuke; those three are what let this band be read as "nothing is '
        .. 'happening" rather than "the bot is dying"')
end

tests['[source] the pair at the call site, and no third veto'] = function()
    local G = sweepG or select(1, sweep())
    assert(G.RECOVER_SIPVETO == 1 and G.RECOVER_DEEPVETO == 1,
        'the 回复状态 branch no longer carries exactly one of each family veto '
        .. '(sip=' .. tostring(G.RECOVER_SIPVETO) .. ' deep='
        .. tostring(G.RECOVER_DEEPVETO) .. ')')
    assert(G.RECOVER_OTHER_VETOES == 0,
        'the branch acquired J.ShouldStayAndRegen or J.ShouldRegenNotTpHome. '
        .. 'Both are EMPTY here by closed form (the branch negates all three '
        .. 'bHasFlask terms itself), so wiring one in adds a name and no domain')
    assert(G.RECOVER_NIDS == 0,
        'a candidate id appeared in the branch condition itself; the gates live '
        .. 'in the helpers so that each lever stays separately armable')
end

tests['[source] the helper is standalone, gate-first, and NOT routed through the family'] = function()
    local G = sweepG or select(1, sweep())
    assert(G.DEEP_FN == 1, 'J.ShouldDeepSipNotTpRecover is gone')
    assert(G.DEEP_NIDS == 1,
        'the helper names ' .. tostring(G.DEEP_NIDS) .. ' candidate ids; a '
        .. 'second one makes the gate a conjunction that freezes FALSE the day '
        .. 'the other is promoted (the pullcad trap) -- and the sibling id is '
        .. 'exactly the one a later round would be tempted to conjoin here')
    assert(G.DEEP_TURBO == 1 and G.DEEP_GATE_FIRST == 1,
        'the helper is no longer gate-first-then-turbo; unarmed it must reach '
        .. 'no engine call at all')
    assert(G.DEEP_USES_FIELDSIP == 0,
        'the helper now routes through J.IsFieldSipEnough. With the flask '
        .. 'excluded by the branch\'s own `itemFlask == nil` that test caps at '
        .. 'item_bottle\'s 135 and demands MaxHealth <= 540 -- empty under the '
        .. 'branch\'s `GetLevel() >= 6`, i.e. a lever that measures EMPTY on the '
        .. 'string the lab is running while reading correct in review')
    assert(G.DEEP_USES_SITUATION == 0 and G.DEEP_USES_REGENNOTGOHOME == 0,
        'the helper now routes through J.IsFieldRegenSituation -- whose 0.18 '
        .. 'floor is the very thing this lever exists to get below, so routing '
        .. 'through it makes the lever identically FALSE on its whole band')
end

tests['[source] the band edges, pinned with their constants'] = function()
    local G = sweepG or select(1, sweep())
    -- ⛔ STRUCTURAL, and deliberately so: both edges are measured below to cost
    -- ZERO domain frames on this corpus, so a corpus counter cannot see either
    -- of them move. Deleting or widening an edge has to go red HERE or nowhere.
    assert(G.DEEP_HI == 0.18,
        'the band\'s upper edge moved to ' .. tostring(G.DEEP_HI))
    assert(G.DEEP_LO == 0.10,
        'the band\'s lower edge moved to ' .. tostring(G.DEEP_LO) .. '. It is '
        .. 'the conservative end of `0.18 - sip/MaxHealth` (0.052 at 900 HP, '
        .. '0.098 at 1400) -- the HP below which one field sip can no longer '
        .. 'lift the bot back to the family floor at all')
    -- The UPPER edge is the family's floor COPIED. If the family ever moves that
    -- floor, this goes red rather than letting the two levers start overlapping.
    assert(G.DEEP_HI == G.SIB_FLOOR and G.DEEP_HI == G.SAR_FLOOR
        and G.DEEP_HI == G.SITUATION_FLOOR,
        'the band\'s upper edge (' .. tostring(G.DEEP_HI) .. ') no longer equals '
        .. 'the family floor (sibling ' .. tostring(G.SIB_FLOOR)
        .. ', ShouldStayAndRegen ' .. tostring(G.SAR_FLOOR)
        .. ', IsFieldRegenSituation ' .. tostring(G.SITUATION_FLOOR)
        .. ') -- the two bands would overlap or leave a gap')
    assert(G.DEEP_LO < G.DEEP_HI, 'the band is empty by construction')
end

tests['[source] every clause is STRICTLY tighter than the sibling'] = function()
    local G = sweepG or select(1, sweep())
    -- Arithmetic between two parsed constants, not a sentence. Reaching below a
    -- floor drawn for escapes is only defensible if the rest of the predicate is
    -- tighter than the one that stayed above it.
    assert(G.DEEP_SOURCE == 1,
        'the helper no longer asks J.HasFieldRegenSource -- it would then hold '
        .. 'an empty-handed bot at 12% HP, which is the supply side\'s domain '
        .. '(fieldbuy), not this lever\'s')
    assert(G.DEEP_RING > G.SIB_RING and G.DEEP_RING == 2500,
        'the danger ring (' .. tostring(G.DEEP_RING) .. ') is no longer wider '
        .. 'than the sibling\'s (' .. tostring(G.SIB_RING) .. '). 2500 is ~8 '
        .. 'seconds of hero movement, half of a tango\'s 16s -- "nobody can '
        .. 'reach me inside half the sip"')
    assert(G.DEEP_DMG_WINDOW > G.SIB_DMG_WINDOW and G.DEEP_DMG_WINDOW == 6,
        'the damage window (' .. tostring(G.DEEP_DMG_WINDOW) .. ') is no longer '
        .. 'longer than the sibling\'s (' .. tostring(G.SIB_DMG_WINDOW) .. ')')
    -- ⛔ THE DELIBERATE ABSENCE. The sibling reads damage the ATTRIBUTED way
    -- ('stayattr') so a global ult from across the map does not read as a hero
    -- on top of the bot. In this band that escape hatch is GIVEN UP on purpose:
    -- any hero damage inside 6s means a fight, and a fight at 12% HP is not a
    -- place to drink. Asserted so a later round cannot "harmonise" the pair.
    assert(G.SIB_ATTRIB == 1,
        'the sibling stopped reading damage the attributed way; the asymmetry '
        .. 'this assertion is about no longer exists')
    assert(G.DEEP_ATTRIB == 0,
        'the deep helper acquired J.HasNearbyHeroDamager. That WIDENS it exactly '
        .. 'where it must not widen: attribution lets a frame through when the '
        .. 'hero that hit the bot has walked off, and at 12% HP one returning '
        .. 'hero is the whole risk')
    assert(G.DEEP_TOWER == G.SIB_TOWER and G.DEEP_TOWER == 1200,
        'the tower radius (' .. tostring(G.DEEP_TOWER) .. ') no longer equals '
        .. 'the sibling\'s and J.IsFieldRegenSituation\'s 1200; it is copied, '
        .. 'not chosen')
end

tests['[source] the call site is inside the branch, above its own conjuncts'] = function()
    -- Comments STRIPPED first: the call site ships with a block comment that
    -- names its own helper, so a raw read counts the comment as a second site.
    local src = read_file(AIUG):gsub('%-%-[^\n]*', '')
    local a = assert(src:find('J.ShouldDeepSipNotTpRecover( bot )', 1, true),
        'the call site is gone from ' .. AIUG)
    local b = assert(src:find("sCastMotive = '回复状态'", a, true),
        'the call site is no longer above the 回复状态 cast motive')
    local n = 0
    for _ in src:gmatch('J%.ShouldDeepSipNotTpRecover') do n = n + 1 end
    assert(n == 1, 'J.ShouldDeepSipNotTpRecover now has ' .. n .. ' call sites '
        .. 'in ' .. AIUG .. '; one lever, one site')
    assert(b - a < 4000, 'the call site drifted far from the branch it guards')
    local jmz = read_file(JMZ):gsub('%-%-[^\n]*', '')
    local m = 0
    for _ in jmz:gmatch('function J%.ShouldDeepSipNotTpRecover') do m = m + 1 end
    assert(m == 1, 'J.ShouldDeepSipNotTpRecover is defined ' .. m .. ' times')
end

-- ==========================================================================
-- 3. The corpus (subprocess sweep)
-- ==========================================================================

-- Memoised: the sweep reloads the mock world once per hero-frame and costs
-- minutes. Several bodies read it, and a mutation stand runs the whole file a
-- dozen times -- running it per body would multiply a stand leg for no extra
-- information (the sweep is a pure function of the tree).
local sweep_cache = nil
function sweep()
    if sweep_cache ~= nil then return unpack(sweep_cache) end
    local p = assert(io.popen('lua5.1 tests/_tpdeep_sweep.lua 2>/dev/null'))
    local s = p:read('*a')
    p:close()
    assert(s:find('\nDONE', 1, true) or s:find('^DONE'),
        'tests/_tpdeep_sweep.lua did not reach its DONE line -- the subprocess '
        .. 'failed, and a truncated manifest must never be read as a small '
        .. 'measurement')
    local G, C, R = {}, {}, {}
    for line in s:gmatch('[^\n]+') do
        local k, v = line:match('^G (%S+) (%S+)$')
        if k then G[k] = tonumber(v) or v end
        local ck, cv = line:match('^C (%S+) (%-?%d+)$')
        if ck then C[ck] = tonumber(cv) end
        if line:match('^R ') then R[#R + 1] = line end
    end
    sweep_cache = { G, C, R }
    sweepG = G
    return G, C, R
end

tests['[corpus] the sweep drives the real corpus and the direction holds'] = function()
    local _, C = sweep()
    cs.ratchet(C.live, 1021, 'live hero frames')
    assert(C.raises == 0, tostring(C.raises) .. ' frame(s) raised inside the '
        .. 'driven helper; a raise is not a measurement')
    assert(C.arm_leak == 0, 'the sweep armed more than one id')
    assert(C.deep_shipped_true == 0,
        'the helper answers TRUE with no id armed on ' .. C.deep_shipped_true
        .. ' frame(s); it is not inert in shipped games')
    -- ⛔ Direction, through a counter PROVED to count: the real call must show
    -- no armed-FALSE-where-shipped-was-TRUE, and the SWAPPED call must report
    -- the whole domain, so neither bump can be deleted silently.
    assert(C.flip_false_to_true == 0,
        'arming the helper made it FALSE where shipped was TRUE on '
        .. C.flip_false_to_true .. ' frame(s) -- impossible for a gate-first '
        .. 'predicate, so the stub or the gate order is wrong')
    assert(C.flips == C.deep_armed_true and C.flips > 0,
        'the driven flip count and the armed TRUE set disagree')
    assert(C.flips_swapped == 0 and C.flip_false_to_true_swapped == C.flips,
        'the swapped tally does not mirror the real one; a zero in the real '
        .. 'call can no longer be told apart from a tally that never ran')
end

tests['[corpus] the two bands are DISJOINT over every live frame'] = function()
    local _, C = sweep()
    -- ⭐ The headline structural property, driven rather than argued. Each helper
    -- is armed on its OWN id on the SAME frame; a single frame where both answer
    -- TRUE would mean a wave on either id moves the other's reading.
    assert(C.overlap == 0,
        C.overlap .. ' frame(s) are claimed by BOTH tprecov and tpdeep. The '
        .. 'bands are supposed to partition at 0.18 -- an overlap makes a '
        .. 'single-arm A/B on either id uninterpretable')
    assert(C.sibling_armed_true > 0 and C.deep_armed_true > 0,
        'one of the two helpers is silent over the whole corpus, so `overlap 0` '
        .. 'is vacuous: it would read 0 for a helper that never fires')
end

tests['[corpus] the deep band is the 29 the floor was stopping'] = function()
    local _, C = sweep()
    assert(C.trigger == 31,
        'the 回复状态 trigger set moved to ' .. C.trigger .. ' frames')
    -- ⭐ THE JOIN WITH THE SIBLING'S HEADLINE. tests/_tprecov_sweep.lua reported
    -- `stop_floor 29`; those 29 are exactly this band's frames. If the two ever
    -- disagree, one of the two sweeps is measuring a different branch.
    assert(C.deep == 29,
        'the deep band holds ' .. C.deep .. ' of the trigger frames, not the 29 '
        .. 'that tests/_tprecov_sweep.lua measured its floor stopping')
    assert(C.deep + C.stop_band_high == C.trigger,
        'the band and the frames above it no longer partition the trigger set')
    assert(C.sibling_true_in_trigger == 2,
        'the sibling now owns ' .. C.sibling_true_in_trigger .. ' trigger '
        .. 'frames, not 2')
end

tests['[corpus] the domain is two frames, and the clause that stops the rest is named'] = function()
    local C, R
    do local _; _, C, R = sweep() end
    assert(#R == C.trigger,
        'the anti-vacuum walk emitted ' .. #R .. ' rows for ' .. C.trigger
        .. ' trigger frames; every trigger frame must get a row, in the domain '
        .. 'or not')
    -- The buckets sum to the trigger set BY COUNTING, not by subtraction.
    local nSum = C.stop_band_high + C.stop_band_low + C.stop_source
        + C.stop_damage + C.stop_ring + C.stop_tower + C.deep_true_in_trigger
    assert(nSum == C.trigger,
        'the stop buckets (' .. nSum .. ') do not partition the trigger set ('
        .. C.trigger .. ')')
    assert(C.deep_true_in_trigger == 2,
        'the helper is TRUE on ' .. C.deep_true_in_trigger
        .. ' trigger frames, not 2')
    -- ⭐ ...and BOTH also have the branch's own conjuncts open, where the
    -- sibling had 1 of 2. The domain is the INTERSECTION, not either factor.
    assert(C.domain_and_branch_open == 2,
        'the counterfactual domain moved to ' .. C.domain_and_branch_open
        .. ' frame(s). It is an INTERSECTION of the helper and the branch, not '
        .. 'either factor alone')
    assert(C.branch_open >= C.domain_and_branch_open,
        'the reachability upper bound is below the domain it bounds')
    local nPinned, nLion = 0, 0
    for _, sRow in ipairs(R) do
        if sRow:find('domain', 1, true) then
            if sRow:find('f_260902_154755_cm_wandbleed_residue', 1, true)
                and sRow:find('obsidian_destroyer', 1, true) then nPinned = 1 end
            if sRow:find('f_megabundle_051728_ogre_lanefront_deep', 1, true) then
                nLion = 1
            end
        end
    end
    assert(nPinned == 1, 'the pinned frame is no longer in the domain rows')
    assert(nLion == 1,
        'the second domain frame (lion, 11.2% HP, level 6) is gone -- the domain '
        .. 'is no longer the two frames this file reports')
end

tests['[corpus] what each band edge actually COSTS -- and it is zero'] = function()
    local _, C = sweep()
    -- ⛔ THE HONEST LIMIT, as a number. A prefix walk reports the FIRST clause
    -- that stops a frame, so `stop_band_low 12` looks like the low edge doing a
    -- lot of work. It is not: every one of those 12 fails a later clause anyway.
    -- Both edges therefore cost ZERO domain frames here, which is precisely why
    -- they are pinned structurally above and must never be argued from a domain
    -- count.
    assert(C.stop_band_low > 0,
        'no trigger frame is stopped by the low edge any more, so this test no '
        .. 'longer says anything about it')
    assert(C.band_low_otherwise_domain == 0,
        C.band_low_otherwise_domain .. ' frame(s) would be in the domain if the '
        .. 'low edge were removed. That is a REAL price and it is new -- '
        .. 're-derive the edge (it is the conservative end of '
        .. '`0.18 - sip/MaxHealth`) before re-baselining this number')
    assert(C.band_high_otherwise_domain == 0,
        C.band_high_otherwise_domain .. ' frame(s) above 0.18 would be in this '
        .. 'helper\'s domain if the upper edge were removed -- i.e. the two '
        .. 'levers would start competing for the same frames instead of '
        .. 'partitioning them')
end

tests['[corpus] the tower zero is about 1200, not about the mock'] = function()
    local _, C = sweep()
    assert(C.stop_tower == 0,
        'a deep-band frame is now stopped by the tower clause (' .. C.stop_tower
        .. '); the LIMIT this file states is out of date')
    -- ⛔ ANTI-VACUUM. Without this the zero above is indistinguishable from a
    -- mock that answers {} for every tower query -- which is exactly what the
    -- loader did before it started restoring buildings from the dump.
    assert(C.deep_with_any_tower >= 18,
        'only ' .. C.deep_with_any_tower .. ' deep-band frames see an enemy '
        .. 'tower at ANY radius. If this collapses to 0, `stop_tower 0` stops '
        .. 'being a reading about 1200 and becomes a reading about the mock')
    -- The ring, on the other hand, IS exercised: frames where the sibling's own
    -- 1200 would have passed and this helper's 2500 does not.
    assert(C.deep_ring_margin >= 7,
        'the 1200-to-2500 margin now holds ' .. C.deep_ring_margin
        .. ' deep-band frames; the choice of 2500 over the sibling\'s 1200 is '
        .. 'no longer separable on this corpus')
    assert(C.stop_ring > 0,
        'no deep frame is stopped by the ring clause any more')
end

return tests

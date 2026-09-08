-- [tprecov / owner priority P2, 2026-09-08] The '回复状态' home-TP branch of
-- X.ConsiderItemDesire["item_tpscroll"] is the fourth of four branches in that
-- one function that send a bot to the fountain, and the ONLY one carrying no
-- regen veto of any kind.
--
--   撤退:1    botHP < 0.19                      -> not J.ShouldStayAndRegen (PROMOTED)
--   撤退:2    botHP < 0.15 + 0.24*nEnemyCount   -> none, and correctly so: it
--                                                 requires enemies AND recent
--                                                 hero damage, so P2's
--                                                 "危险时撤退合法" covers it and
--                                                 nothing here touches it
--   撤退:3    botHP < 0.34 / sum < 0.43, lvl>=9 -> not J.ShouldRegenNotTpHome
--                                                 ('stayfield', gated)
--   回复状态  sum < 0.3 / botHP < 0.2, lvl>=6   -> NOTHING
--
-- The fourth is the quiet-field trip owner priority P2 names, and it says so in
-- its own conjuncts: `J.GetProperTarget(bot) == nil`, `bot:GetAttackTarget() ==
-- nil`, `X.CanJuke()`, at most one enemy inside 1600 -- and, unlike both 撤退
-- branches above it, NO `bot:WasRecentlyDamagedByAnyHero` at all.  Asserted
-- below as four numbers off the source, not as prose.
--
-- ⭐ THE CLOSED FORM THAT PICKED THE PREDICATE, and it is why this file's
-- headline assertion is about a guard that is NOT being wired in.  The obvious
-- fix is to copy 撤退:1's conjunct into this branch.  Driven over the corpus,
-- J.ShouldStayAndRegen is TRUE on 13 of 1021 live frames, exactly ONE of which
-- is inside this branch's trigger -- and on that one frame it is TRUE only via
-- `modifier_tango_heal`, which the branch ALREADY vetoes.  That is not a
-- sampling accident.  Gold is not networked into a .dem (GH #495), so
-- `bot:GetGold()` is 0 on every fixture and the only route to a TRUE is the
-- `bHasFlask` disjunction -- three terms: a main-slot item_flask,
-- 'modifier_flask_healing', 'modifier_tango_heal' -- and this branch carries
-- the negation of ALL THREE.  ⇒ at this call site the promoted veto reduces to
-- `bot:GetGold() >= 90` and nothing else, digit for digit the same closed form
-- the 2026-08-29 correction proved for 撤退:1 from the same three conjuncts.
-- Third instance of the criterion tests/test_stayfield_callsite_domain.lua
-- pinned: **a guard's domain is its predicate INTERSECTED with the rest of the
-- conjunction it was dropped into**.
--
-- ⭐⭐ SO THE ARITHMETIC PICKED J.ShouldSipNotTpRecover'S CONTENTS.  A guard
-- that can change anything here must read a supply source the branch does not
-- already negate; the branch negates the flask (item and modifier) and the
-- tango modifier, leaving a CARRIED tango / tango_single / faerie_fire /
-- charged bottle -- J.HasFieldRegenSource's set minus the flask.  And it must
-- NOT route through J.ShouldRegenNotGoHome, for two reasons this file asserts
-- rather than states: 'fieldsip' (ARMED in the current member string) requires
-- FieldRegenSipValue >= 0.25 * GetMaxHealth, which with the flask excluded caps
-- at item_bottle's 135 and so demands MaxHealth <= 540 -- impossible under this
-- branch's own `bot:GetLevel() >= 6`; and J.IsFieldRegenSituation's 0.18 floor
-- excludes 29 of this branch's 31 corpus trigger frames.
--
-- ⚠️ WHAT THIS FILE DOES NOT CLAIM.
--   * It does not claim a large domain.  The counterfactual domain -- helper
--     TRUE *and* the branch's frame-readable conjuncts open -- is ONE frame of
--     1021 (f_114311_drow_pushguard_silent, viper lvl 8 at 19.1% HP with a
--     faerie fire, nothing inside 1600, no recent damage).  The sweep emits a
--     row per trigger frame naming the clause that stopped it, so "the corpus
--     has no domain" can never read the same as "it has one this helper rejects
--     earlier".
--   * It does not drive the branch body.  `X` in ability_item_usage_generic is
--     a FILE-LOCAL table, so neither the branch nor `X.CanJuke()` is callable
--     from here.  `branch_open` evaluates the conjuncts a frame CAN answer and
--     is therefore an UPPER BOUND on reachability, never a claim that the
--     branch fires.  Same limit, same reason, as
--     tests/test_stayfield_callsite_domain.lua.
--   * It does not rule on (a)/(b)/(c) for 'tprecov' and does not ask for
--     admission: owner P4.2 is a freeze, so this lands as FROZEN-HOLD.
--   * It does not touch 撤退:2.  That branch is a genuine escape and keeping it
--     unguarded is a decision, recorded here as an assertion (its regen-veto
--     count must stay 0) so a later round cannot "tidy" it in by accident.

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')
local cs = require('corpus_scale')

local FIXTURE = 'tests/fixtures/f_114311_drow_pushguard_silent.lua'
local HERO = 'npc_dota_hero_viper'
local AIUG = 'bots/ability_item_usage_generic.lua'
local JMZ = 'bots/FunLib/jmz_func.lua'

local tests = {}

-- Forward declarations: the sweep is a module local, NEVER a key of `tests`.
-- run_tests.lua iterates that table and calls every value in it, so a helper
-- parked there would be run as a test (and a cached table parked there would be
-- CALLED). Same shape as the stale-key bugs this suite keeps finding, so it is
-- avoided by construction rather than by naming convention.
local sweep
local sweepG

--- Load the pinned frame and hand back a driver that answers the SHIPPED
--- global with the gate off and then on.  Nothing here re-implements the
--- decision: both answers come out of J.ShouldSipNotTpRecover itself, and both
--- come from ONE loaded world and ONE bot.
local function drive(path, hero)
    local J, bot = rf.load(path or FIXTURE, hero or HERO)
    local fArmed = function() return false end
    J.IsSoakCandidate = function(sId) return fArmed(sId) and true or false end
    local function answer(f)
        fArmed = f or function() return false end
        local v = J.ShouldSipNotTpRecover(bot)
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

tests['[frame] the pinned frame is a hurt, unchased bot holding a field sip'] = function()
    local J, bot = drive()
    local nHP = J.GetHP(bot)
    assert(nHP < 0.2 and nHP >= 0.18,
        'the frame no longer reads hp in [0.18, 0.20) (' ..
        string.format('%.3f', nHP) .. ') -- it has to be inside the branch\'s '
        .. 'own trigger AND above the family floor, or this file is driving a '
        .. 'world the finding is not about')
    assert(bot:GetLevel() >= 6,
        'the frame no longer clears the branch\'s own level gate')
    assert(#J.GetNearbyHeroes(bot, 1600, true, BOT_MODE_NONE) == 0,
        'the frame no longer reads an empty 1600 ring -- the branch tolerates '
        .. 'one enemy there and the helper requires zero inside 1200, so this '
        .. 'is the margin the finding rests on')
    assert(not bot:WasRecentlyDamagedByAnyHero(3.0),
        'the frame now reads recent hero damage; it was chosen because nothing '
        .. 'is happening to this bot')
    assert(J.HasFieldRegenSource(bot),
        'the frame no longer carries a field regen source')
    -- The flask legs must be ABSENT: that is what makes this frame a witness
    -- for "the branch already negates everything the promoted veto can see".
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
    assert(answer(only('tprecov')) == true,
        'armed, the lever does not fire on the one frame it was written for')
end

tests['[frame] the flip belongs to THIS id, not to any armed string'] = function()
    local _, _, answer = drive()
    -- Every id this helper's callees can read, armed one at a time. None of
    -- them may reach the answer: the gate is the first conjunct, so a
    -- single-arm wave on any of them must read this site as silent.
    for _, sOther in ipairs({ 'stayfield', 'stayfield2', 'fieldsip', 'staysrc',
        'staytower', 'stayattr', 'bagsalve', 'fieldcreep', 'fieldbuy', 'buyband' }) do
        assert(answer(only(sOther)) == false,
            'arming \'' .. sOther .. '\' alone moves this call site; the flip '
            .. 'would then be attributed to the wrong id in a single-arm wave')
    end
    -- ... and an all-on stub must not be how it fires either, or the id is
    -- decorative.
    assert(answer(function() return true end) == true,
        'with everything armed the helper is silent -- an inner id has turned '
        .. 'this lever off, which is the pullcad shape one level down')
    assert(answer(nil) == false, 'the shipped answer moved between calls')
end

tests['[frame] the guard the obvious fix would have used is silent HERE'] = function()
    local J, bot = drive()
    -- J.ShouldStayAndRegen is PROMOTED -- no stub needed, and none is used.
    assert(J.ShouldStayAndRegen(bot) == false,
        'the PROMOTED veto now answers TRUE on this frame, which would mean '
        .. 'copying 撤退:1\'s conjunct here WOULD have covered it -- re-derive '
        .. 'the closed form before editing this file')
    -- ...and the reason is its supply read, not its danger read: this frame is
    -- unchased (asserted above) and it is above the floor.
    assert(J.GetHP(bot) >= 0.18, 'the frame fell below the promoted floor, so '
        .. 'the silence above no longer isolates the supply read')
end

tests['[negative control] a chased frame is NOT held'] = function()
    -- The lever must be distinguishable from "disable the branch". A frame with
    -- an enemy on top of the bot has to stay releasable, or the veto is a
    -- switch rather than a narrowing (the lanefix lesson: only a negative
    -- control tells those two apart).
    local J, bot, answer = drive('tests/fixtures/f_231411_ck_zoned.lua',
        'npc_dota_hero_chaos_knight')
    assert(#J.GetNearbyHeroes(bot, 1200, true, BOT_MODE_NONE) > 0,
        'the control frame no longer has an enemy inside 1200; it cannot '
        .. 'control for anything')
    assert(answer(only('tprecov')) == false,
        'armed, the helper holds a bot with an enemy inside 1200 -- it is '
        .. 'behaving as an off switch for the branch, not as a narrowing')
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

tests['[source] the sibling table: three branches guarded, one was not'] = function()
    -- The counts come from the sweep, which strips comments before counting --
    -- this lever ships with a comment that NAMES J.ShouldStayAndRegen and both
    -- sibling branches, so an unstripped read would let the comment satisfy the
    -- assertion (the §EN mistake).
    local G = sweepG or select(1, sweep())
    assert(G.BRANCH_T1 == 1 and G.BRANCH_T2 == 1 and G.BRANCH_T3 == 1
        and G.BRANCH_RECOVER == 1,
        'one of the four home-TP branches can no longer be located by its own '
        .. 'cast motive; the table this finding rests on is unreadable')
    assert(G.T1_STAYANDREGEN == 1, '撤退:1 no longer carries the promoted veto')
    assert(G.T3_REGENNOTTP == 1, '撤退:3 no longer carries the stayfield veto')
    assert(G.T2_REGEN_VETOES == 0,
        '撤退:2 has acquired a regen veto. That branch is a genuine escape '
        .. '(enemies present AND recent hero damage) and owner P2 leaves it '
        .. 'alone on purpose -- this is a decision, not an oversight')
    assert(G.RECOVER_SIPVETO == 1,
        'the 回复状态 branch no longer carries J.ShouldSipNotTpRecover')
    assert(G.RECOVER_STAYANDREGEN == 0 and G.RECOVER_REGENNOTTP == 0,
        'the 回复状态 branch acquired a SECOND regen veto; one call site, one '
        .. 'lever -- and the other two are empty here by closed form anyway')
end

tests['[source] the branch is the quiet one: no recent-damage requirement'] = function()
    local G = sweepG or select(1, sweep())
    assert(G.T1_RECENTDMG == 1 and G.T2_RECENTDMG == 1,
        'a 撤退 branch stopped requiring recent hero damage; the asymmetry that '
        .. 'makes 回复状态 "the quiet trip" no longer holds')
    assert(G.RECOVER_RECENTDMG == 0,
        'the 回复状态 branch now requires recent hero damage -- it has become '
        .. 'an escape branch, and owner P2 does not ask to block escapes')
end

tests['[source] the closed form: the branch negates all three bHasFlask terms'] = function()
    local G = sweepG or select(1, sweep())
    assert(G.SAR_BHASFLASK_DISJUNCTS == 3,
        'J.ShouldStayAndRegen\'s supply disjunction now has '
        .. tostring(G.SAR_BHASFLASK_DISJUNCTS) .. ' terms, not 3 -- the closed '
        .. 'form below enumerates exactly three and is no longer exhaustive')
    assert(G.SAR_BHASFLASK_ITEM == 1 and G.SAR_BHASFLASK_FLASKMOD == 1
        and G.SAR_BHASFLASK_TANGOMOD == 1,
        'the three terms are no longer {main-slot item_flask, '
        .. 'modifier_flask_healing, modifier_tango_heal}')
    assert(G.RECOVER_FLASK_ITEM == 1 and G.RECOVER_FLASKHEAL == 1
        and G.RECOVER_TANGOHEAL == 1,
        'the 回复状态 branch no longer negates all three; the promoted veto '
        .. 'would then have a domain here and this lever is the wrong shape')
    -- The branch's veto list, counted rather than flagged: a presence flag
    -- reads the same whether the list has nine entries or one, and "this list
    -- is exhaustive and still left the carried sip out" is the whole argument.
    assert(G.RECOVER_VETO_MODS == 9,
        'the 回复状态 branch\'s modifier veto count moved to '
        .. tostring(G.RECOVER_VETO_MODS))
end

tests['[source] the helper is standalone, gate-first, and NOT routed through the family'] = function()
    local G = sweepG or select(1, sweep())
    assert(G.HELPER_FN == 1, 'J.ShouldSipNotTpRecover is gone')
    assert(G.HELPER_NIDS == 1,
        'the helper names ' .. tostring(G.HELPER_NIDS) .. ' candidate ids; a '
        .. 'second one makes the gate a conjunction that freezes FALSE the day '
        .. 'the other is promoted (the pullcad trap)')
    assert(G.RECOVER_NIDS == 0,
        'a candidate id appeared in the branch condition itself; the gate lives '
        .. 'in the helper (as it does for stayfield) so that the branch keeps '
        .. 'exactly one lever')
    assert(G.HELPER_TURBO == 1 and G.HELPER_GATE_FIRST == 1,
        'the helper is no longer gate-first-then-turbo; unarmed it must reach '
        .. 'no engine call at all')
    -- ⛔ The four narrowing clauses, pinned INDIVIDUALLY. A corpus counter
    -- cannot stand in for these: the 0.18 floor stops 29 of the 31 trigger
    -- frames BEFORE the supply and danger clauses are reached, so deleting any
    -- one of them leaves every corpus number in this file unchanged while the
    -- helper stops narrowing anything.
    assert(G.HELPER_SOURCE == 1,
        'the helper no longer asks J.HasFieldRegenSource -- it would then hold '
        .. 'an empty-handed bot in the field, which is the supply side\'s '
        .. 'domain (fieldbuy), not this lever\'s')
    assert(G.HELPER_ATTRIB == 1,
        'the helper no longer reads damage the ATTRIBUTED way; a global ult '
        .. 'from across the map would read as a hero on top of the bot, which '
        .. 'is the defect stayattr exists for')
    assert(G.HELPER_RING == 1,
        'the helper no longer requires an empty 1200 ring -- it must stay '
        .. 'strictly tighter than the branch, which tolerates one enemy at 1600')
    assert(G.HELPER_TOWER == 1,
        'the helper no longer vetoes on an enemy tower inside 1200; that is '
        .. 'the building half J.IsFieldRegenSituation already writes down')
    assert(G.HELPER_USES_FIELDSIP == 0,
        'the helper now routes through J.IsFieldSipEnough. With the flask '
        .. 'excluded by the branch\'s own `itemFlask == nil`, that test caps at '
        .. 'item_bottle\'s 135 and demands MaxHealth <= 540 -- empty under this '
        .. 'branch\'s `GetLevel() >= 6`. That is the trap '
        .. 'tests/test_stayfield_callsite_domain.lua documented')
    assert(G.HELPER_USES_SITUATION == 0 and G.HELPER_USES_REGENNOTGOHOME == 0,
        'the helper now routes through J.IsFieldRegenSituation, whose walk '
        .. 'brings the fieldsip conjunct with it')
    -- The floor is COPIED, not chosen. If the family ever moves it, this file
    -- goes red rather than letting the two silently diverge.
    assert(G.HELPER_FLOOR == G.SAR_FLOOR and G.HELPER_FLOOR == G.SITUATION_FLOOR,
        'the helper\'s HP floor (' .. tostring(G.HELPER_FLOOR) .. ') no longer '
        .. 'equals the family\'s (ShouldStayAndRegen ' .. tostring(G.SAR_FLOOR)
        .. ', IsFieldRegenSituation ' .. tostring(G.SITUATION_FLOOR) .. ')')
end

tests['[source] the call site is inside the branch, above its own conjuncts'] = function()
    -- Comments STRIPPED first: the call site ships with a block comment that
    -- names its own helper, so a raw read counts the comment as a second call
    -- site (measured -- this assertion caught exactly that on its first run).
    local src = read_file(AIUG):gsub('%-%-[^\n]*', '')
    local a = assert(src:find('J.ShouldSipNotTpRecover( bot )', 1, true),
        'the call site is gone from ' .. AIUG)
    local b = assert(src:find("sCastMotive = '回复状态'", a, true),
        'the call site is no longer above the 回复状态 cast motive')
    local n = 0
    for _ in src:gmatch('J%.ShouldSipNotTpRecover') do n = n + 1 end
    assert(n == 1, 'J.ShouldSipNotTpRecover now has ' .. n .. ' call sites in '
        .. AIUG .. '; one lever, one site')
    assert(b - a < 4000, 'the call site drifted far from the branch it guards')
    -- and the helper is defined exactly once
    local jmz = read_file(JMZ):gsub('%-%-[^\n]*', '')
    local m = 0
    for _ in jmz:gmatch('function J%.ShouldSipNotTpRecover') do m = m + 1 end
    assert(m == 1, 'J.ShouldSipNotTpRecover is defined ' .. m .. ' times')
end

-- ==========================================================================
-- 3. The corpus (subprocess sweep)
-- ==========================================================================

-- Memoised: the sweep reloads the mock world once per hero-frame and costs
-- minutes. Several bodies read it, and a mutation stand runs the whole file a
-- dozen times -- running it per body would multiply a stand leg for no extra
-- information (the sweep is a pure function of the tree, and the tree does not
-- change inside one process).
local sweep_cache = nil
function sweep()
    if sweep_cache ~= nil then return unpack(sweep_cache) end
    local p = assert(io.popen('lua5.1 tests/_tprecov_sweep.lua 2>/dev/null'))
    local s = p:read('*a')
    p:close()
    assert(s:find('\nDONE', 1, true) or s:find('^DONE'),
        'tests/_tprecov_sweep.lua did not reach its DONE line -- the subprocess '
        .. 'failed, and a truncated manifest must never be read as a small '
        .. 'measurement')
    local G, C, R, S = {}, {}, {}, {}
    for line in s:gmatch('[^\n]+') do
        local k, v = line:match('^G (%S+) (%S+)$')
        if k then G[k] = tonumber(v) or v end
        local ck, cv = line:match('^C (%S+) (%-?%d+)$')
        if ck then C[ck] = tonumber(cv) end
        if line:match('^R ') then R[#R + 1] = line end
        if line:match('^S ') then S[#S + 1] = line end
    end
    sweep_cache = { G, C, R, S }
    sweepG = G
    return G, C, R, S
end

tests['[corpus] the sweep drives the real corpus and the direction holds'] = function()
    local G, C = sweep()
    cs.ratchet(C.live, 1021, 'live hero frames')
    assert(C.raises == 0, tostring(C.raises) .. ' frame(s) raised inside the '
        .. 'driven helper; a raise is not a measurement')
    assert(C.arm_leak == 0, 'the sweep armed more than one id')
    -- ⛔ Direction, through a counter PROVED to count. The real call must show
    -- no TRUE->... wait: this helper IS the veto, so shipped is false
    -- everywhere and armed is the whole domain. `flip_false_to_true` (armed
    -- FALSE where shipped was TRUE) must be 0, and the SWAPPED call must report
    -- that same whole domain -- so neither bump can be deleted without moving
    -- the manifest.
    assert(C.helper_shipped_true == 0,
        'the helper answers TRUE with no id armed on ' .. C.helper_shipped_true
        .. ' frame(s); it is not inert in shipped games')
    assert(C.flip_false_to_true == 0,
        'arming the helper made it FALSE where shipped was TRUE on '
        .. C.flip_false_to_true .. ' frame(s) -- impossible for a gate-first '
        .. 'predicate, so the stub or the gate order is wrong')
    assert(C.flips == C.helper_armed_true and C.flips > 0,
        'the driven flip count and the armed TRUE set disagree')
    assert(C.flips_swapped == 0 and C.flip_false_to_true_swapped == C.flips,
        'the swapped tally does not mirror the real one; a zero in the real '
        .. 'call can no longer be told apart from a tally that never ran')
end

tests['[corpus] the branch trigger, and which half of it fires'] = function()
    local G, C = sweep()
    assert(C.trigger == 31,
        'the 回复状态 trigger set moved to ' .. C.trigger .. ' frames')
    -- ⭐ WHICH HALF. The trigger is `sum < 0.3 OR botHP < 0.2`. On the whole
    -- corpus the SUM half never fires on its own: 31 of 31 come through the HP
    -- half. Recorded because a later lever aimed at the mana half would be
    -- aimed at a disjunct this corpus cannot witness -- and because arithmetic
    -- makes it nearly a subset (hp in [0.2,0.3) needs mp < 0.1), i.e. this is a
    -- measurement of a nearly-empty region, not a broken parse.
    assert(C.trigger_hp_leg == 31 and C.trigger_sum_leg == 0,
        'the trigger split moved to hp=' .. C.trigger_hp_leg .. ' sum='
        .. C.trigger_sum_leg)
    assert(C.trigger_hp_leg + C.trigger_sum_leg == C.trigger,
        'the two halves no longer partition the trigger set')
    assert(C.trigger_lvl == 17,
        'the level-6 subset of the trigger moved to ' .. C.trigger_lvl)
end

tests['[corpus] the closed form, measured: the promoted veto is already blocked'] = function()
    local _, C, _, S = sweep()
    assert(C.sar_true_any == 13,
        'J.ShouldStayAndRegen\'s corpus TRUE set moved to ' .. C.sar_true_any
        .. ' frames (independently reproduced here; its own source records 13)')
    assert(C.sar_true_in_trigger == 1,
        'the promoted veto is now TRUE on ' .. C.sar_true_in_trigger
        .. ' frames inside this branch\'s trigger, not 1')
    assert(C.sar_blocked_by_branch == C.sar_true_in_trigger,
        'a frame where the promoted veto is TRUE inside the trigger is NOT '
        .. 'already blocked by one of the branch\'s own three conjuncts -- the '
        .. 'closed form has a counterexample and the choice of predicate has to '
        .. 'be re-derived')
    assert(#S == 1 and S[1]:find('branch_vetoes_tango_heal', 1, true),
        'the one blocked frame is no longer blocked by modifier_tango_heal')
end

tests['[corpus] the domain is one frame, and the clause that stops the rest is named'] = function()
    local G, C, R = sweep()
    assert(#R == C.trigger,
        'the anti-vacuum walk emitted ' .. #R .. ' rows for ' .. C.trigger
        .. ' trigger frames; every trigger frame must get a row, in the domain '
        .. 'or not')
    -- The buckets sum to the trigger set BY COUNTING, not by subtraction.
    local nSum = C.stop_floor + C.stop_source + C.stop_damage + C.stop_ring
        + C.stop_tower + C.helper_true_in_trigger
    assert(nSum == C.trigger,
        'the stop buckets (' .. nSum .. ') do not partition the trigger set ('
        .. C.trigger .. ')')
    -- ⭐ AND THE HONEST HEADLINE: the family's own 0.18 floor is what stops 29
    -- of the 31. That is a measurement of the P2 family's reach, not a defect
    -- of this lever, and it is the next lever's whole subject: the branch that
    -- actually fires at low HP lives almost entirely BELOW the band every P2 id
    -- is allowed to speak in.
    assert(C.stop_floor == 29,
        'the floor now stops ' .. C.stop_floor .. ' of the trigger frames, not '
        .. '29 -- the "the P2 family cannot reach this branch" reading moved')
    assert(C.helper_true_in_trigger == 2,
        'the helper is TRUE on ' .. C.helper_true_in_trigger
        .. ' trigger frames, not 2')
    -- ...of which only ONE also has the branch's own conjuncts open. The domain
    -- is the INTERSECTION; the other frame is the tango_heal one above, which
    -- the branch vetoes on its own.
    assert(C.domain_and_branch_open == 1,
        'the counterfactual domain moved to ' .. C.domain_and_branch_open
        .. ' frame(s). It is an INTERSECTION of the helper and the branch, not '
        .. 'either factor alone')
    assert(C.branch_open >= C.domain_and_branch_open,
        'the reachability upper bound is below the domain it bounds')
    local bPinned = false
    for _, sRow in ipairs(R) do
        if sRow:find('f_114311_drow_pushguard_silent', 1, true)
            and sRow:find(' domain', 1, true) then bPinned = true end
    end
    assert(bPinned, 'the pinned frame is no longer in the domain rows')
end

return tests

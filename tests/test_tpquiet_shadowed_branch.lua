-- [tpquiet / owner priority P2, 2026-09-08] A VETO ON A BRANCH THAT NEVER RUNS
-- IS NOT A VETO, and this is the first time this family has asked which of its
-- four home-TP branches gets there FIRST.
--
-- X.ConsiderItemDesire["item_tpscroll"] contains four branches that send a bot
-- to its own fountain, in source order, and every one of them RETURNS.  Three
-- ids from owner priority P2 sit on the LAST two of them: 'stayfield' on
-- '撤退:3', 'tprecov' and 'tpdeep' on '回复状态'.  Nothing has ever asked whether
-- '撤退:1' -- the `botHP < 0.19` branch inside the retreat block, upstream of all
-- three -- claims the frame first.  Measured over the whole fixture corpus
-- (tests/_tpquiet_sweep.lua, 1021 live hero-frames):
--
--     tpdeep_true                  2   -- the sibling's entire domain
--     tpdeep_true_in_r4            2   -- both inside its own branch trigger
--     tpdeep_true_in_r4_shadowed   1   -- ...and ONE is inside '撤退:1' too
--     both_triggers                6   -- frames where both branches are open
--
-- ⭐ SO THE SIBLING'S PUBLISHED DOMAIN IS AN OVER-COUNT, BY HALF.  Its own file
-- asserts `domain_and_branch_open == 2` and names both frames, one of which is
-- `f_megabundle_051728_ogre_lanefront_deep` lion at 11.2% HP.  That reading is
-- arithmetic and it is correct about what it measured -- it asked whether ITS
-- branch was open.  It could not ask whether an EARLIER branch would have
-- returned first, because nothing in the tree had the notion.  On that lion
-- frame '撤退:1' is open, so 'tpdeep' armed alone changes nothing there.  This is
-- the call-site reachability family (GH #606: a gate address is not
-- reachability) arriving one branch upstream of where it has been looking.
--
-- ⭐⭐ THE FIX IS THE SAME JUDGEMENT AT THE BRANCH THAT REACHES THE FRAME, NOT A
-- NEW ONE.  Every constant in J.ShouldSipNotTpQuietHome is
-- J.ShouldDeepSipNotTpRecover's constant, and that is asserted as arithmetic
-- between the two parsed functions rather than claimed in prose -- if either
-- drifts, this file goes red and the licence for the lever is gone.
--
-- ⭐⭐⭐ '撤退:1' IS THE QUIETEST OF THE FOUR AND THE LEAST GUARDED, WHICH IS THE
-- COMBINATION THAT MAKES IT WORTH A LEVER.  It requires `nEnemyCount == 0` -- an
-- EMPTY 1600 ring, where '回复状态' tolerates one -- so its own trigger proves
-- harder than any sibling's that nothing is chasing this bot.  Its only regen
-- veto is the PROMOTED J.ShouldStayAndRegen, whose band [0.18, 0.75] meets a
-- branch capped at `botHP < 0.19`: one percentage point, already pinned as
-- arithmetic in tests/test_tphome_tp_leg_counterfactual.lua.  Measured here:
-- 6 of the branch's 7 corpus trigger frames sit below 0.18, i.e. below anything
-- that guards it.
--
-- ⛔ WHAT THIS FILE DELIBERATELY DOES NOT ASSERT: `overlap == 0`.  The sibling's
-- sweep asserts it because 'tprecov' and 'tpdeep' SHARE a call site, where
-- disjoint bands are the only thing that makes a single-arm wave attributable.
-- This lever shares a call site with nobody -- it is the same predicate at an
-- EARLIER branch -- so an overlapping frame is the POINT.  `both_armed_true 2`
-- is registered rather than hidden (iron rule 4 (i-a)), and what must hold in
-- its place is that SOURCE ORDER decides: pinned structurally as
-- `T1_RETURN_BEFORE_R4`, never by a count.
--
-- ⛔ WHAT THIS FILE DOES NOT DO:
--   * It does not touch the shared 0.18 floor inside J.IsFieldRegenSituation.
--     Lowering it would move 'stayfield', 'stayfield2' and 'fieldbuy' in one
--     edit -- three levers on one push, the lanefix bundle mistake.
--   * It does not arm anything and does not ask for admission: owner P4.2 is a
--     freeze, so this lands as FROZEN-HOLD.
--   * It does not re-run the sibling's assertions.  'tpquiet' does not appear in
--     tests/test_tpdeep_recover_band.lua and J.ShouldSipNotTpQuietHome is not a
--     superstring of any name it scopes its counts to, so that file's numbers
--     are byte-identical after this landing -- verified by running it, not
--     assumed.
--   * It does not RE-BASELINE the sibling's `domain_and_branch_open 2`.  That
--     number is correct about what it measured; the correction belongs in the
--     sibling's own prose and is filed as an issue, not smuggled in here by
--     editing someone else's assertion.

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')
local cs = require('corpus_scale')

-- The pinned frame, and it is the SHADOWED one: lion, level 6, 11.2% HP, inside
-- BOTH branch triggers, with a field sip in the bag and not one enemy hero
-- inside 2500.  tests/test_tpdeep_recover_band.lua names this same frame as half
-- of the sibling's domain, which is exactly why it is the frame that shows the
-- shadow.
local FIXTURE = 'tests/fixtures/f_megabundle_051728_ogre_lanefront_deep.lua'
local HERO = 'npc_dota_hero_lion'
-- The ring control: the branch's own 1600 is empty (so the branch passes) and
-- this helper's 2500 is not.
local RING_FIXTURE = 'tests/fixtures/f_260819_122930_lina_landed_dead.lua'
local RING_HERO = 'npc_dota_hero_ogre_magi'
local AIUG = 'bots/ability_item_usage_generic.lua'
local JMZ = 'bots/FunLib/jmz_func.lua'

local tests = {}

-- Forward declaration: the sweep is a module local, NEVER a key of `tests`.
-- run_tests.lua iterates that table and calls every value in it.
local sweep

--- Load a frame and hand back a driver that answers the SHIPPED globals with the
--- gate off and then on.  Nothing here re-implements a decision: every answer
--- comes out of the shipped helper itself, from ONE loaded world and ONE bot.
local function drive(path, hero)
    local J, bot = rf.load(path or FIXTURE, hero or HERO)
    local fArmed = function() return false end
    J.IsSoakCandidate = function(sId) return fArmed(sId) and true or false end
    local function answer(f, fn)
        fArmed = f or function() return false end
        local v = (fn or J.ShouldSipNotTpQuietHome)(bot)
        fArmed = function() return false end
        return v and true or false
    end
    return J, bot, answer
end

local function only(sWanted)
    return function(sId) return sId == sWanted end
end

local function read(path)
    local f = assert(io.open(path, 'r'), path .. ' is not readable')
    local s = f:read('*a')
    f:close()
    return s
end

--- The source-order facts, computed HERE rather than read out of the sweep
--- manifest.
---
--- ⛔ THIS SEPARATION IS A STAND FINDING, NOT A STYLE CHOICE.  The first version
--- of this file asserted `G.T1_RETURN_BEFORE_R4 == 1` off the manifest, and
--- tools/agent/mutstand_tpquiet.sh's M10 -- replace the sweep's computation with
--- the literal `1` -- SURVIVED: every counter was byte-identical (source order is
--- not a count) and the assertion happily read the constant that the mutant had
--- written.  An assertion whose input is produced by the thing it is checking
--- checks nothing.  The whole lever rests on this order, so it is derived from
--- the source, in the file that asserts it, and the manifest's copy is then
--- required to AGREE with it -- which is what makes a divergence visible instead
--- of silent.
--- The return is located INSIDE the '撤退:1' branch, not merely somewhere in the
--- file: the same `return ... tpLoc ...` line ends '撤退:2' and '撤退:3' too, so a
--- whole-file `find` would still succeed after this branch's return was deleted
--- and the assertion would be satisfied by a sibling's return. The branch's own
--- extent is [its cast motive, the next branch's cast motive).
local function order_facts()
    local src = read(AIUG):gsub('%-%-[^\n]*', '')
    local at_t1_trig = src:find('if botHP < 0.19', 1, true)
    local at_r4_trig = src:find('if ( botHP + botMP < 0.3 or botHP < 0.2 )', 1, true)
    local at_t1_motive = at_t1_trig
        and src:find("sCastMotive = '撤退:1'", at_t1_trig, true)
    local at_t2_motive = src:find("sCastMotive = '撤退:2'", 1, true)
    local at_t1_ret = at_t1_motive and src:find(
        'return BOT_ACTION_DESIRE_HIGH, tpLoc, sCastType, sCastMotive',
        at_t1_motive, true)
    -- Outside the branch's extent = this branch has no return of its own.
    if at_t1_ret and at_t2_motive and at_t1_ret > at_t2_motive then
        at_t1_ret = nil
    end
    return at_t1_trig, at_t1_ret, at_r4_trig
end

-- ==========================================================================
-- 1. The frame is what the finding says it is
-- ==========================================================================

tests['[frame] the pinned frame is a deep, unchased bot holding a field sip'] = function()
    local J, bot = drive()
    local nHP = J.GetHP(bot)
    assert(nHP < 0.18 and nHP >= 0.10,
        'the frame no longer reads hp in [0.10, 0.18) ('
        .. string.format('%.3f', nHP) .. ') -- it has to sit inside the band '
        .. 'this lever borrows from its sibling, or this file is driving a '
        .. 'world the finding is not about')
    assert(nHP < 0.19,
        'the frame fell out of the \'撤退:1\' branch\'s own HP trigger')
    assert(#J.GetNearbyHeroes(bot, 1600, true, BOT_MODE_NONE) == 0,
        'the frame no longer reads an EMPTY 1600 ring -- that is the branch\'s '
        .. 'own `nEnemyCount == 0` conjunct, and it is the whole reason this '
        .. 'branch is the quietest of the four')
    assert(#J.GetNearbyHeroes(bot, 2500, true, BOT_MODE_NONE) == 0,
        'the frame no longer reads an empty 2500 ring -- that ring is the '
        .. 'licence for drinking instead of leaving at this HP')
    assert(not bot:WasRecentlyDamagedByAnyHero(6.0),
        'the frame now reads hero damage inside 6s; it was chosen because '
        .. 'nothing is happening to this bot')
    assert(J.HasFieldRegenSource(bot),
        'the frame no longer carries a field regen source')
    assert(J.IsItemAvailable('item_flask') == nil,
        'the frame now has a salve in a usable slot -- the branch\'s own '
        .. '`itemFlask == nil` conjunct would close, and the frame stops being '
        .. 'a witness for this branch')
end

tests['[frame] armed the helper fires here; unarmed it is byte-identical'] = function()
    local _, _, answer = drive()
    assert(answer(nil) == false,
        'the helper answers TRUE with NO id armed -- it is a defaults change '
        .. 'wearing a candidate\'s name')
    assert(answer(only('tpquiet')) == true,
        'the helper does not fire on its own pinned frame; a gate-plumbing '
        .. 'test would not have noticed')
    -- ⛔ ONE id wide. Arming a NEIGHBOUR must not move this answer, or a
    -- single-arm wave on either id stops being attributable.
    assert(answer(only('tpdeep')) == false,
        'arming the SIBLING moves this helper -- the two ids are not '
        .. 'independent and no per-id verdict could be read')
    assert(answer(only('tprecov')) == false,
        'arming \'tprecov\' moves this helper')
    assert(answer(only('stayfield')) == false,
        'arming \'stayfield\' moves this helper')
end

tests['[frame] the SIBLING also fires here -- and that is the finding'] = function()
    -- The overlap is not hidden (iron rule 4 (i-a)): on this exact frame BOTH
    -- helpers answer TRUE, and this frame is one the sibling's own file names as
    -- half of its domain. What keeps the pair attributable is that '撤退:1'
    -- returns before '回复状态' is evaluated -- asserted structurally in section
    -- 2, never inferred from here.
    local J, bot = rf.load(FIXTURE, HERO)
    J.IsSoakCandidate = function(sId) return sId == 'tpdeep' end
    assert(J.ShouldDeepSipNotTpRecover(bot) == true,
        'the sibling no longer fires on this frame -- then it is not the frame '
        .. 'its own domain reading counts, and the shadow finding has lost its '
        .. 'witness')
    J.IsSoakCandidate = function() return false end
    assert(J.ShouldDeepSipNotTpRecover(bot) == false,
        'the sibling answers TRUE unarmed on this frame; the comparison above '
        .. 'would then say nothing about arming')
end

tests['[frame] the ring control: 1600 empty, 2500 not, helper refuses'] = function()
    local J, bot, answer = drive(RING_FIXTURE, RING_HERO)
    assert(#J.GetNearbyHeroes(bot, 1600, true, BOT_MODE_NONE) == 0,
        'the control frame no longer passes the BRANCH\'s own 1600 ring, so it '
        .. 'no longer separates the helper\'s radius from the branch\'s')
    assert(#J.GetNearbyHeroes(bot, 2500, true, BOT_MODE_NONE) > 0,
        'the control frame no longer has an enemy in (1600, 2500]')
    assert(answer(only('tpquiet')) == false,
        'the helper fires on a frame with an enemy inside 2500 -- its ring '
        .. 'clause is the thing that makes it stricter than the branch it '
        .. 'guards, and it is not doing that')
end

-- ==========================================================================
-- 2. The structure: upstream, one call site, one id, the sibling's constants
-- ==========================================================================

tests['[structure] the guarded branch RETURNS before the sibling branch is reached'] = function()
    -- ⭐ THE PIN THE WHOLE LEVER RESTS ON, derived from the source in this file
    -- (see order_facts: reading it out of the manifest let mutant M10 through).
    -- If '撤退:1' stopped being upstream -- or stopped returning -- then "the
    -- sibling never gets there" is false, and two armed ids would race for one
    -- frame with no rule saying which acts.
    local at_t1_trig, at_t1_ret, at_r4_trig = order_facts()
    assert(at_t1_trig ~= nil,
        'the \'撤退:1\' trigger `if botHP < 0.19` is gone from the comment-'
        .. 'stripped source')
    assert(at_r4_trig ~= nil, 'the \'回复状态\' trigger is gone')
    assert(at_t1_ret ~= nil,
        'the \'撤退:1\' branch no longer contains its fountain-TP return')
    assert(at_t1_trig < at_r4_trig,
        'the \'撤退:1\' trigger is no longer ahead of the \'回复状态\' trigger in '
        .. 'the file -- "upstream" was the entire argument for this lever')
    assert(at_t1_ret < at_r4_trig,
        'the \'撤退:1\' branch no longer RETURNS before the \'回复状态\' trigger; '
        .. 'without the return the branches do not shadow each other at all')

    -- ...and the manifest's own copy must AGREE. A divergence means the sweep is
    -- describing a different tree than the one this file just read.
    local G = sweep()
    assert(G.T1_TRIGGER_BEFORE_R4 == 1 and G.T1_RETURN_BEFORE_R4 == 1,
        'the sweep manifest disagrees with the source order this file just '
        .. 'derived -- one of the two is reading a tree the other is not')
    assert(G.BRANCH_T1 == 1 and G.BRANCH_R4 == 1,
        'one of the two branches can no longer be located by its cast motive')
end

tests['[structure] one call site, in the branch it claims, no id in the condition'] = function()
    local G = sweep()
    assert(G.T1_QUIETVETO == 1,
        'the \'撤退:1\' branch carries ' .. G.T1_QUIETVETO .. ' call(s) to the '
        .. 'new helper, not exactly one -- a deleted call site is the plainest '
        .. 'way this lever becomes a dead helper that still passes review')
    assert(G.FILE_QUIETVETO == 1,
        'the file carries ' .. G.FILE_QUIETVETO .. ' call(s) to the new helper. '
        .. 'A second call site would make a per-id verdict unattributable, '
        .. 'which is the whole reason this is a separate id from \'tpdeep\'')
    assert(G.R4_QUIETVETO == 0,
        'the new helper is now also wired into the \'回复状态\' branch -- that is '
        .. 'the one-id-two-call-sites shape this lever exists to avoid')
    assert(G.T1_TPHOME_VETO == 1,
        'the promoted J.ShouldStayAndRegen veto left the branch; the "one '
        .. 'percentage point of overlap" argument is about a conjunct that is '
        .. 'no longer there')
    -- ⛔ The 'pullcad' trap: the gate lives in the helper, never in the branch
    -- condition, so promoting some other id can never freeze this one FALSE.
    assert(G.T1_NIDS == 0,
        'the branch condition now names a soak id directly; a gate written as '
        .. 'a conjunction of two ids is frozen FALSE the day either is promoted')
    assert(G.QUIET_NIDS == 1,
        'the helper names ' .. G.QUIET_NIDS .. ' soak id(s), not exactly one')
    assert(G.QUIET_TURBO == 1,
        'the helper no longer asks J.IsModeTurbo() exactly once -- nothing on '
        .. 'this call path asks it for us')
    assert(G.QUIET_GATE_FIRST == 1,
        'the gate is no longer ahead of every read in the helper: an unarmed '
        .. 'shipped game would evaluate engine scans on every call')
end

tests['[structure] the constants are the SIBLING\'s, as arithmetic between two functions'] = function()
    local G = sweep()
    assert(G.QUIET_FN == 1 and G.DEEP_FN == 1,
        'one of the two helper bodies could not be parsed')
    -- ⭐ The lever's entire licence: it re-asks an opinion the family already
    -- formed. A drift in EITHER function breaks that, so both sides are parsed.
    assert(G.QUIET_HI == G.DEEP_HI,
        'band upper edge drifted from the sibling: ' .. G.QUIET_HI .. ' vs '
        .. G.DEEP_HI .. '. This lever is only defensible as the SAME judgement '
        .. 'at an earlier branch; a different number makes it a new one')
    assert(G.QUIET_LO == G.DEEP_LO,
        'band lower edge drifted from the sibling: ' .. G.QUIET_LO .. ' vs '
        .. G.DEEP_LO)
    assert(G.QUIET_DMG_WINDOW == G.DEEP_DMG_WINDOW,
        'damage window drifted from the sibling: ' .. G.QUIET_DMG_WINDOW
        .. ' vs ' .. G.DEEP_DMG_WINDOW)
    assert(G.QUIET_RING == G.DEEP_RING,
        'ring radius drifted from the sibling: ' .. G.QUIET_RING .. ' vs '
        .. G.DEEP_RING)
    assert(G.QUIET_TOWER == G.DEEP_TOWER,
        'tower radius drifted from the sibling: ' .. G.QUIET_TOWER .. ' vs '
        .. G.DEEP_TOWER)
    -- ...and the named constants must actually be USED, or the equality above
    -- is comparing two decorations.
    assert(G.QUIET_USES_HI == 1 and G.QUIET_USES_LO == 1,
        'a band edge constant is declared but not used by the body')
    assert(G.QUIET_USES_DMG == 1,
        'the damage window constant is declared but not used by the body')
    assert(G.QUIET_USES_RING == 1 and G.QUIET_USES_TOWER == 1,
        'a radius constant is declared but not used by the body')
    assert(G.QUIET_SOURCE == 1,
        'the helper no longer asks J.HasFieldRegenSource -- without it the '
        .. 'lever holds a bot in the field with nothing to drink')
end

tests['[structure] no line of the new helper is an anchor the SIBLING\'s stand owns'] = function()
    local G = sweep()
    -- ⛔ GH #550, pinned in the file that does the thing rather than in the file
    -- that would be blamed for it. tools/agent/mutstand_tpdeep.sh anchors on the
    -- INLINE forms of these four lines and treats an AMBIGUOUS anchor as a whole
    -- -stand abort -- so a byte-identical copy here would abort the SIBLING's
    -- stand, under the SIBLING's name, for a change that is not the sibling's.
    -- That is why this helper names its constants where the sibling inlines them.
    assert(G.INLINE_BAND_HI == 1,
        'the inline `nHP >= 0.18` line now occurs ' .. G.INLINE_BAND_HI
        .. ' times in jmz_func -- mutstand_tpdeep.sh\'s BAND_HI anchor is '
        .. 'ambiguous and that stand will abort in the sibling\'s name')
    assert(G.INLINE_BAND_LO == 1,
        'the inline `nHP < 0.10` line now occurs ' .. G.INLINE_BAND_LO
        .. ' times -- mutstand_tpdeep.sh\'s BAND_LO anchor is ambiguous')
    assert(G.INLINE_DMG == 1,
        'the inline `WasRecentlyDamagedByAnyHero( 6.0 )` line now occurs '
        .. G.INLINE_DMG .. ' times -- mutstand_tpdeep.sh\'s DMG anchor is '
        .. 'ambiguous')
    assert(G.INLINE_RING == 1,
        'the inline 2500 ring line now occurs ' .. G.INLINE_RING
        .. ' times -- mutstand_tpdeep.sh\'s RING anchor is ambiguous')
end

tests['[structure] the branch is the quietest of the four, off the source'] = function()
    local G = sweep()
    -- The licence for reaching below the family's floor HERE is that this
    -- branch's own trigger demands more quiet than any sibling's.
    assert(G.T1_RING_EMPTY == 1,
        'the \'撤退:1\' branch no longer requires an EMPTY 1600 ring; it was the '
        .. 'strictest surroundings conjunct of the four and the reason this '
        .. 'branch is the one worth a deep-band lever')
    assert(G.R4_RING_LE1 == 1,
        'the \'回复状态\' branch no longer tolerates one enemy inside 1600, so '
        .. '"strictly quieter than the sibling branch" is no longer true')
    assert(G.T1_HP_TRIGGER == 0.19,
        'the branch\'s HP cap moved to ' .. G.T1_HP_TRIGGER .. '. The whole '
        .. '"one percentage point" argument is arithmetic against 0.18')
    assert(G.T1_HP_TRIGGER > G.QUIET_HI,
        'the branch cap is no longer above the band edge, so the band does not '
        .. 'sit under this branch at all')
    -- The source of the shipped guard's blindness here, as two parsed numbers.
    local sar = read(JMZ):match('function J%.ShouldStayAndRegen.-\nend\n')
    assert(sar ~= nil, 'J.ShouldStayAndRegen could not be located')
    assert(sar:find('nHP < 0.18 or nHP > 0.75', 1, true) ~= nil,
        'the promoted veto\'s band moved; the sliver arithmetic that licenses '
        .. 'this lever has to be re-derived before this file is believed')
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
    local p = assert(io.popen('lua5.1 tests/_tpquiet_sweep.lua 2>/dev/null'))
    local s = p:read('*a')
    p:close()
    assert(s:find('\nDONE', 1, true) or s:find('^DONE'),
        'tests/_tpquiet_sweep.lua did not reach its DONE line -- the subprocess '
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
    return G, C, R, S
end

tests['[corpus] the sweep drives the real corpus and the direction holds'] = function()
    local _, C = sweep()
    cs.ratchet(C.live, 1021, 'live hero frames')
    assert(C.raises == 0, tostring(C.raises) .. ' frame(s) raised inside the '
        .. 'driven helper; a raise is not a measurement')
    assert(C.arm_leak == 0, 'the sweep armed more than one id')
    assert(C.quiet_shipped_true == 0,
        'the helper answers TRUE with no id armed on ' .. C.quiet_shipped_true
        .. ' frame(s); it is not inert in shipped games')
    -- ⛔ Direction, through a counter PROVED to count: the real call must show
    -- no armed-FALSE-where-shipped-was-TRUE, and the SWAPPED call must report
    -- the whole domain, so neither bump can be deleted silently.
    assert(C.flip_false_to_true == 0,
        'arming the helper made it FALSE where shipped was TRUE on '
        .. C.flip_false_to_true .. ' frame(s) -- impossible for a gate-first '
        .. 'predicate, so the stub or the gate order is wrong')
    assert(C.flips == C.quiet_armed_true and C.flips > 0,
        'the driven flip count and the armed TRUE set disagree')
    assert(C.flips_swapped == 0 and C.flip_false_to_true_swapped == C.flips,
        'the swapped tally does not mirror the real one; a zero in the real '
        .. 'call can no longer be told apart from a tally that never ran')
end

tests['[corpus] THE SHADOW: the sibling is credited with a frame it cannot reach'] = function()
    local _, C, _, S = sweep()
    -- ⭐ The headline. Measured on the SHIPPED sibling function, never
    -- re-implemented here.
    assert(C.tpdeep_true == 2,
        'the sibling\'s corpus domain moved to ' .. C.tpdeep_true .. ' frame(s);'
        .. ' the shadow arithmetic below is stated against 2')
    assert(C.tpdeep_true_in_r4 == 2,
        'the sibling\'s domain frames inside its own branch trigger moved to '
        .. C.tpdeep_true_in_r4 .. '; that is the number its own file publishes '
        .. 'as `domain_and_branch_open`')
    assert(C.tpdeep_true_in_r4_shadowed == 1,
        'the shadowed count moved to ' .. C.tpdeep_true_in_r4_shadowed
        .. '. This is the finding: a frame the sibling is credited with, where '
        .. 'an EARLIER branch returns first')
    -- ⛔ A count alone could not be re-checked against the looseness of the two
    -- trigger upper bounds, so every shadowed frame is printed and the pinned
    -- one must be among them.
    local nSeen = 0
    for _, sRow in ipairs(S) do
        if sRow:find('f_megabundle_051728_ogre_lanefront_deep', 1, true)
            and sRow:find('lion', 1, true) then nSeen = 1 end
    end
    assert(nSeen == 1,
        'the pinned lion frame is no longer among the shadowed rows -- the '
        .. 'count above has stopped being about the frame this file drives')
    assert(C.both_triggers >= C.tpdeep_true_in_r4_shadowed,
        'more frames are shadowed than have both triggers open, which is '
        .. 'arithmetically impossible -- the bounds disagree')
end

tests['[corpus] the domain, and what the branch cap leaves unguarded'] = function()
    local _, C, R = sweep()
    -- The partition is a SUBTRACTION that must close exactly, so a bucket
    -- cannot quietly stop being reached.
    local nSum = C.stop_band_high + C.stop_band_low + C.stop_source
        + C.stop_damage + C.stop_ring + C.stop_tower + C.quiet_true_in_t1
    assert(nSum == C.t1_trigger,
        'the prefix-walk buckets sum to ' .. nSum .. ' but the branch trigger '
        .. 'holds ' .. C.t1_trigger .. ' frames -- a bucket is not being reached')
    assert(C.t1_trigger == 7,
        'the \'撤退:1\' corpus trigger moved to ' .. C.t1_trigger .. ' frames')
    -- ⭐ 6 of 7 below the band anything guards -- the reason the lever exists.
    assert(C.stop_band_high == 1,
        C.stop_band_high .. ' trigger frame(s) sit at or above 0.18. The claim '
        .. 'is that this branch fires almost entirely BELOW the band its only '
        .. '(promoted) veto can speak in, and 1-of-7 is that claim')
    assert(C.quiet_true_in_t1 == 1,
        'the counterfactual domain moved to ' .. C.quiet_true_in_t1
        .. ' frame(s). It is the INTERSECTION of the helper and the branch, '
        .. 'not either factor alone')
    assert(C.quiet_armed_true >= C.quiet_true_in_t1,
        'more frames are in the domain than the helper answers TRUE on')
    local nPinned = 0
    for _, sRow in ipairs(R) do
        if sRow:find('domain', 1, true)
            and sRow:find('f_megabundle_051728_ogre_lanefront_deep', 1, true)
            and sRow:find('lion', 1, true) then nPinned = 1 end
    end
    assert(nPinned == 1, 'the pinned frame is no longer in the domain rows')
end

tests['[corpus] what each band edge actually COSTS -- and it is zero'] = function()
    local _, C = sweep()
    -- ⛔ THE HONEST LIMIT, as a number. A prefix walk reports the FIRST clause
    -- that stops a frame, so `stop_band_low 4` looks like the low edge doing
    -- work. It is not: every one of those 4 fails a later clause anyway. Both
    -- edges therefore cost ZERO domain frames here, which is precisely why they
    -- are pinned structurally (against the sibling's own numbers, section 2) and
    -- must never be argued from a domain count.
    assert(C.stop_band_low > 0,
        'no trigger frame is stopped by the low edge any more, so this test no '
        .. 'longer says anything about it')
    assert(C.band_low_otherwise_domain == 0,
        C.band_low_otherwise_domain .. ' frame(s) would enter the domain if the '
        .. 'low edge were removed. That is a REAL price and it is new -- '
        .. 're-derive the edge from the sibling before re-baselining this')
    assert(C.band_high_otherwise_domain == 0,
        C.band_high_otherwise_domain .. ' frame(s) above 0.18 would enter this '
        .. 'helper\'s domain if the upper edge were removed -- i.e. it would '
        .. 'start eating the band the PROMOTED veto already owns on this branch')
end

tests['[corpus] the tower zero is about 1200, and the ring is exercised'] = function()
    local _, C = sweep()
    assert(C.stop_tower == 0,
        'a trigger frame is now stopped by the tower clause (' .. C.stop_tower
        .. '); the LIMIT this file states is out of date')
    -- ⛔ ANTI-VACUUM. Without this the zero above is indistinguishable from a
    -- mock that answers {} for every tower query.
    assert(C.quiet_with_any_tower >= 4,
        'only ' .. C.quiet_with_any_tower .. ' in-band trigger frames see an '
        .. 'enemy tower at ANY radius. If this collapses to 0, `stop_tower 0` '
        .. 'stops being a reading about 1200 and becomes one about the mock')
    -- The ring IS exercised: frames where the BRANCH's own 1600 passes and this
    -- helper's 2500 does not. That margin is the helper's only surroundings
    -- contribution over the branch, so a zero here would make the radius choice
    -- unmeasurable on this corpus.
    assert(C.quiet_ring_margin >= 3,
        'the 1600-to-2500 margin now holds ' .. C.quiet_ring_margin
        .. ' in-band trigger frames; the choice of 2500 over the branch\'s own '
        .. '1600 is no longer separable on this corpus')
    assert(C.stop_ring > 0,
        'no trigger frame is stopped by the ring clause any more')
end

tests['[corpus] the overlap is REGISTERED, not hidden and not faked to zero'] = function()
    local G, C = sweep()
    -- Iron rule 4 (i-a): a reading gets registered even when it is not the
    -- reading you would have preferred. Both helpers claim 2 of the same frames.
    assert(C.both_armed_true == 2,
        'the both-armed-TRUE count moved to ' .. C.both_armed_true
        .. '. This file REGISTERS the overlap rather than asserting it away; '
        .. 'if it moved, say so in the round\'s report')
    assert(C.both_armed_true_and_both_triggers == 1,
        'the frames where both helpers fire AND both branches are open moved '
        .. 'to ' .. C.both_armed_true_and_both_triggers)
    -- ...and what makes the pair still attributable is SOURCE ORDER, restated
    -- here so the overlap and its resolution live in one place. Derived, not
    -- read off the manifest -- same reason as section 2.
    local _, at_t1_ret, at_r4_trig = order_facts()
    assert(at_t1_ret ~= nil and at_r4_trig ~= nil and at_t1_ret < at_r4_trig,
        'with the source order gone, an overlapping frame has no rule deciding '
        .. 'which id acts on it, and neither id could be A/B-ed alone')
    assert(G.T1_RETURN_BEFORE_R4 == 1, 'the manifest disagrees with the source')
end

return tests

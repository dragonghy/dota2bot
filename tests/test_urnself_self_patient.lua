-- [urnself] [owner priority P2] The urn heals everyone except the one hero this
-- script always knows the health of.
--
-- THE FINDING, AS TWO ENTRIES OF THE SAME TABLE THAT DISAGREE ABOUT WHO COUNTS
-- AS A PATIENT.  X.ConsiderItemDesire["item_flask"] -- a 400-health consumable
-- -- has BOTH a self branch (`hEffectTarget = bot`) and an ally branch, with
-- three ids' worth of arbitration between them ('salveyield', 'salvepool',
-- 'salveally').  X.ConsiderItemDesire["item_urn_of_shadows"] -- the same 400
-- health over 8 seconds, self-castable -- has ONLY the ally branch.  The cause
-- is one engine call: its patient loop is `bot:GetNearbyHeroes(...)`, which does
-- not return the caller.  So a hurt, safe bot holding a charged urn never
-- presses it, at any health, ever.
--
-- ⭐ WHY IT IS OWNER PRIORITY P2 AND NOT COSMETIC.  Driving the PROMOTED
-- J.ShouldStayAndRegen over this corpus with all four of its supply levers ARMED
-- TOGETHER ('staysrc' + 'staybottle' + 'staybag' + 'bagsalve'), 65 of the 125
-- frames that reach its supply clause are still vetoed there, and 8 of those 65
-- carry an urn.  The family's regen vocabulary -- flask / tango / tango_single /
-- faerie_fire / bottle -- never contained the urn, and it could not be added
-- while this entry refuses to heal the carrier: counting it would hold a hurt
-- bot in the field next to a heal it will never press.  That is precisely the
-- argument 'bagsalve' was written on (no shipped swapper => do not count the
-- item).  This lever is the OTHER end of it -- make the heal reachable first.
--
-- WHAT THIS FILE DOES NOT CLAIM.  No supply read is widened here.
-- J.HasFieldRegenSource is untouched, no hold id changes on any frame, and the
-- urn is still not a field regen source.  Whether it should BECOME one is a
-- separate question for a separate id, and this file deliberately does not
-- answer it.
--
-- ⛔ THE DECISION IS DRIVEN, NOT SHADOWED.  Every cast column below comes from
-- running the shipped `_G.ItemUsageThink` on a real frame and reading the
-- recorded engine action.  The mirrored prefix walk in the sweep answers a
-- DIFFERENT question (how big is the domain, which conjunct binds it) and the
-- two are cross-checked against each other: `domain_selfonly` == `gain`.
--
-- Honest bounds, stated first rather than buried:
--   * TWO clauses the fixture loader cannot know are supplied to the urn handle
--     and only to it: IsTrained/IsActivated/IsFullyCastable (GH #89, the same
--     probe _itemdesire_sweep.lua runs for the TP scroll) and GetCurrentCharges,
--     which is per-frame runtime state no .dem carries.  Because of the second,
--     the corpus is driven in TWO charge columns and BOTH are asserted -- the c0
--     column reads 0 everywhere because the entry's own first line still
--     refuses, and that 0 can therefore never be read as "the lever does
--     nothing".
--   * the lever suppresses nothing.  It appends after a branch that RETURNS, so
--     arming can only turn BOT_ACTION_DESIRE_NONE into a cast; no retreat bid,
--     no other item and no ally cast can be delayed or outbid by it.
--   * arbitration between a qualifying ally and a qualifying self is NOT
--     answered here.  The 2 corpus frames where both qualify are left to the
--     ally, and the sibling precedent for that question is its own id
--     ('salveyield').
--   * 81 corpus frames carry an urn and only 6 clear the conjuncts.  The binding
--     one is the 450 missing-health floor (17 frames pass it), not the danger
--     clauses -- recorded as a number rather than smoothed over.
--
-- Mutation stand: tools/agent/mutstand_urnself.sh

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')
local cs = require('corpus_scale')

local SWEEP = 'lua5.1 tests/_urnself_sweep.lua'
local AIUG = 'bots/ability_item_usage_generic.lua'

local tests = {}

-- ------------------------------------------------------------- the sweep --

local M = (function()
    local p = assert(io.popen(SWEEP, 'r'))
    local raw = p:read('*a')
    p:close()
    local m = { g = {}, c = setmetatable({}, { __index = function() return nil end }),
                dom = {}, casts = {}, done = false }
    for line in raw:gmatch('[^\n]+') do
        local k, v = line:match('^G (%S+) (%S+)$')
        if k ~= nil then m.g[k] = tonumber(v) or v end
        local ck, cv = line:match('^C (%S+) (%-?%d+)$')
        if ck ~= nil then m.c[ck] = tonumber(cv) end
        local fix, hero, hp, miss, ally =
            line:match('^D (%S+) (%S+) ([%d%.]+) (%d+) (%d)$')
        if fix ~= nil then
            m.dom[#m.dom + 1] = { fixture = fix, hero = hero, hp = tonumber(hp),
                missing = tonumber(miss), ally = (ally == '1') }
        end
        local cfix, chero = line:match('^K c1 armed (%S+) (%S+)$')
        if cfix ~= nil then m.casts[#m.casts + 1] = { fixture = cfix, hero = chero } end
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

tests['[sweep] the subprocess ran to completion'] = function()
    assert(M.done, 'tests/_urnself_sweep.lua did not print DONE -- every count '
        .. 'below would be a partial sweep read as a finding')
    cs.corpus(C('fixtures'), 'fixture corpus')
    cs.ratchet(C('live'), 1012, 'live hero frames')
    assert(C('aiug_fail') == 0, C('aiug_fail') .. ' frames failed to load ' .. AIUG)
    assert(C('think_crash') == 0, C('think_crash') .. ' frames crashed in ItemUsageThink')
end

-- ------------------------------------------------- the defect, as source --

tests['[source] the sibling entry for the same 400 health has BOTH branches'] = function()
    assert(M.g.FLASK_HAS_SELF == 1,
        'X.ConsiderItemDesire["item_flask"] no longer assigns hEffectTarget = bot'
        .. ' -- the condition-(c) argument for this lever is gone, re-derive it')
    assert(M.g.FLASK_HAS_ALLY == 1,
        'the salve entry no longer has an ally branch -- the asymmetry this '
        .. 'lever is about no longer exists in the form measured')
    assert(M.g.FLASK_YIELD_ID == 1,
        'J.ShouldYieldSalveToAlly is gone from the salve entry -- the precedent '
        .. 'that self-vs-ally arbitration is its OWN id no longer holds, and '
        .. 'this lever leans on it to justify NOT arbitrating')
end

tests['[source] the urn entry parses, and the parse is not reading a comment'] = function()
    assert(M.g.URN_BLOCK == 1, 'the urn consider function could not be located in '
        .. AIUG .. ' -- every structural fact below measured nothing')
    assert(M.g.URN_STRIPPED == 1, 'comment stripping did not happen -- this '
        .. "lever's own comment names every id, modifier and constant asserted "
        .. 'below, so unstripped the COMMENT could satisfy them')
    -- The boundary that a comment moved once.  The unanchored needle
    -- `X.ConsiderItemDesire[` is matched by this lever's own comment (it names
    -- the salve entry), and the first run of the sweep cut the block there and
    -- reported the self branch ABSENT from a file containing it.  These three
    -- facts are exactly the ones that read 0 that time.
    assert(M.g.URN_NIDS == 1, 'expected exactly one soak id in the urn entry, got '
        .. tostring(M.g.URN_NIDS))
    assert(M.g.SELF_ASSIGNS_BOT == 1, 'the self branch does not assign '
        .. 'hEffectTarget = bot -- note the needle is newline-anchored because '
        .. '`hEffectTarget = bot` is a PREFIX of the attack branch\'s '
        .. '`hEffectTarget = botTarget`')
    assert(M.g.SELF_AFTER_ALLY_RETURN == 1,
        'the self branch is no longer after the ally branch\'s return -- the '
        .. '"fires only when no ally qualified" property is CONTROL FLOW, and '
        .. 'moving the block silently turns this lever into an arbitration change')
end

tests['[source] STANDALONE: one id per condition, never a conjunction'] = function()
    -- The 'pullcad' trap: `IsSoakCandidate('X') and IsSoakCandidate('Y')` freezes
    -- FALSE the day either id is promoted, while check_armed_wiring.py still
    -- calls it WIRED.
    assert(M.g.URN_IDS_MAX_PER_COND == 1,
        'a condition in the urn entry names ' .. tostring(M.g.URN_IDS_MAX_PER_COND)
        .. ' soak ids -- the pullcad trap')
end

tests['[source] turbo is written out here, because nothing above asks it'] = function()
    -- Unlike J.ShouldStayAndRegen, whose first line is IsModeTurbo, this
    -- function has no turbo check above the lever.  "Structural" would be false.
    assert(M.g.SELF_HAS_TURBO == 1,
        'the self branch lost its J.IsModeTurbo() -- this entry has no turbo '
        .. 'check above it, so the gate would leak into normal mode')
end

tests['[source] every conjunct is COPIED from the ally loop, not chosen'] = function()
    assert(M.g.ALLY_FOUNTAIN == 800 and M.g.SELF_FOUNTAIN == M.g.ALLY_FOUNTAIN,
        'the fountain floor diverged: ally ' .. tostring(M.g.ALLY_FOUNTAIN)
        .. ' vs self ' .. tostring(M.g.SELF_FOUNTAIN))
    assert(M.g.ALLY_DMGWIN == 3.1 and M.g.SELF_DMGWIN == M.g.ALLY_DMGWIN,
        'the damage window diverged: ally ' .. tostring(M.g.ALLY_DMGWIN)
        .. ' vs self ' .. tostring(M.g.SELF_DMGWIN))
    assert(M.g.ALLY_MISSING == 450 and M.g.SELF_MISSING == M.g.ALLY_MISSING,
        'the missing-health floor diverged: ally ' .. tostring(M.g.ALLY_MISSING)
        .. ' vs self ' .. tostring(M.g.SELF_MISSING))
    assert(M.g.ALLY_HEALMODS == 3 and M.g.SELF_HEALMODS == M.g.ALLY_HEALMODS,
        'the two halves refuse on different heal modifiers: ally '
        .. tostring(M.g.ALLY_HEALMODS) .. ' vs self ' .. tostring(M.g.SELF_HEALMODS))
    assert(M.g.SELF_ENEMY_LIST == 1,
        'the self branch no longer requires an empty hNearbyEnemyHeroList -- '
        .. 'that is the ally loop\'s own danger clause and the reason a self '
        .. 'heal here is not cast in a fight')
end

-- --------------------------------------------------------- the corpus --

tests['[domain] the corpus can answer this question at all'] = function()
    -- Anti-vacuum.  A lever measured on a corpus with no carriers is a lever
    -- measured on nothing.
    assert(C('has_urn') == 81, 'urn carriers moved to ' .. C('has_urn')
        .. ' (was 81) -- re-derive the domain before reading anything below')
    assert(C('driven_frames') == C('has_urn'),
        'the driven pass covered ' .. C('driven_frames') .. ' of ' .. C('has_urn')
        .. ' carriers')
    -- The binding conjunct, as a number.  It is the health floor, not danger.
    assert(C('self_missing_ok') == 17, 'the 450 floor now passes '
        .. C('self_missing_ok') .. ' frames (was 17)')
    assert(C('self_far_ok') == 79 and C('self_undamaged') == 71
        and C('self_no_healmod') == 79 and C('self_castable') == 81,
        'the non-binding conjuncts moved -- far ' .. C('self_far_ok')
        .. ' undamaged ' .. C('self_undamaged') .. ' no-healmod '
        .. C('self_no_healmod') .. ' castable ' .. C('self_castable'))
    assert(C('self_qualifies') == 6, 'frames where the bot itself satisfies the '
        .. 'ally loop\'s conjuncts moved to ' .. C('self_qualifies') .. ' (was 6)')
    assert(C('domain_selfonly') == 4 and C('domain_with_ally') == 2,
        'the split moved: self-only ' .. C('domain_selfonly') .. ', with-ally '
        .. C('domain_with_ally') .. ' (was 4 / 2)')
    assert(#M.dom == C('self_qualifies'),
        'the sweep listed ' .. #M.dom .. ' domain rows for ' .. C('self_qualifies')
        .. ' qualifying frames -- the set must be auditable, not counted')
    -- Every one of them is inside the band of the PROMOTED hold this family is
    -- about, which is what makes it owner priority P2's domain and not a
    -- freestanding item tweak.
    assert(C('in_stay_band') == C('self_qualifies'),
        'only ' .. C('in_stay_band') .. ' of ' .. C('self_qualifies')
        .. ' domain frames are inside J.ShouldStayAndRegen\'s 0.18-0.75 band')
end

tests['[charges] the c0 column is 0 BECAUSE of the entry\'s own first line'] = function()
    -- Not blindness, and not "the lever does nothing".  Charges are per-frame
    -- runtime state that no .dem carries, so the corpus is driven twice and the
    -- zero column is asserted as a zero rather than being the only column.
    assert(C('charges_nonzero') == 0,
        'a fixture reported a nonzero urn charge count (' .. C('charges_nonzero')
        .. ') -- the two-column construction rests on this being impossible; if '
        .. 'the dumper now carries charges, drop the honest-handle probe')
    assert(C('casts_ship_c0') == 0 and C('casts_armed_c0') == 0,
        'the zero-charge column cast the urn (' .. C('casts_ship_c0') .. '/'
        .. C('casts_armed_c0') .. ') -- the entry\'s first line must refuse')
    assert(C('casts_armed_c1') > C('casts_armed_c0'),
        'arming buys nothing in the c1 column that it does not buy in c0 -- the '
        .. 'two columns are supposed to differ, and that difference IS the lever')
end

tests['[driven] the shipped ally branch works here, so a zero would mean something'] = function()
    -- If the shipped entry cast nothing in this harness, "armed casts 4" would
    -- be unfalsifiable -- any 0 could be blamed on the harness.  It casts 3.
    assert(C('casts_ship_c1') == 3, 'the shipped urn entry cast on '
        .. C('casts_ship_c1') .. ' c1 frames (was 3) -- this is the control that '
        .. 'makes the armed column readable')
    assert(C('arm_leak') == 0, 'the arming stub answered TRUE for a sibling id '
        .. C('arm_leak') .. ' times -- flips would be credited to the wrong lever')
end

tests['[driven] armed, the urn is cast on exactly the self-only domain'] = function()
    assert(C('gain') == 4, 'arming bought ' .. C('gain') .. ' casts (was 4)')
    -- The cross-check between the two independent routes: the mirrored prefix
    -- walk and the driven end-to-end run must name the same number.
    assert(C('gain') == C('domain_selfonly'),
        'driven gain ' .. C('gain') .. ' /= mirrored self-only domain '
        .. C('domain_selfonly') .. ' -- one of the two routes is wrong')
    assert(C('casts_armed_c1') == C('casts_ship_c1') + C('gain'),
        'armed c1 casts ' .. C('casts_armed_c1') .. ' /= shipped '
        .. C('casts_ship_c1') .. ' + gain ' .. C('gain'))
    assert(#M.casts == C('gain'), 'the sweep listed ' .. #M.casts
        .. ' cast rows for ' .. C('gain') .. ' gained casts')
    -- Listed, not counted: the set is auditable.
    local seen = {}
    for _, r in ipairs(M.casts) do seen[r.fixture .. ' ' .. r.hero] = true end
    for _, want in ipairs({
        'f_045650_lion_meatgrinder npc_dota_hero_venomancer',
        'f_230952_zuus_ult_hoard npc_dota_hero_venomancer',
        'f_260819_004858_cm_centaur_far npc_dota_hero_witch_doctor',
        'f_260822_123136_lina_shoptp_434 npc_dota_hero_jakiro',
    }) do
        assert(seen[want], 'the gained-cast set no longer contains ' .. want)
    end
end

tests['[direction] arming can only ADD a cast, and the counter proves it counts'] = function()
    -- ⛔ A counter whose content is all zeros cannot tell "the direction holds"
    -- from "the tally never ran": deleting its bump leaves the manifest
    -- byte-identical.  Both directions go through ONE tally, called a second
    -- time with the legs SWAPPED, so the branch that must read 0 on the real
    -- call is the branch that must report the WHOLE domain on the swapped call.
    assert(C('loss') == 0, 'arming REMOVED ' .. C('loss') .. ' shipped casts -- '
        .. 'this lever appends after a returning branch and cannot subtract')
    assert(C('loss_swapped') == C('gain'),
        'the swapped tally reported ' .. C('loss_swapped') .. ' where the domain '
        .. 'is ' .. C('gain') .. ' -- the branch asserted to be 0 above is not '
        .. 'reachable, so that 0 was vacuous')
    assert(C('gain_swapped') == C('loss'),
        'the swapped tally reported ' .. C('gain_swapped') .. ' gains where the '
        .. 'unswapped call reported ' .. C('loss') .. ' losses')
end

-- ------------------------------------------------------- the pinned frame --

-- The pin is chosen to be in BOTH sets, and that is the point of it: it is one
-- of the 4 frames the driven column gains AND one of the 65 frames the PROMOTED
-- hold's supply clause still vetoes with all four of its levers armed.  A frame
-- in only the first set would show the lever firing without showing why anyone
-- should care; the first pin tried here was exactly that and failed this
-- assertion, because that hero was carrying a main-slot source all along.
tests['[frame] f_260822_123136 jakiro: 48% HP, 612 down, urn in hand, empty-handed to the whole family'] = function()
    local J, bot = rf.load('tests/fixtures/f_260822_123136_lina_shoptp_434.lua',
        'npc_dota_hero_jakiro')
    assert(bot ~= nil, 'the pinned frame no longer loads')

    local nMissing = bot:OriginalGetMaxHealth() - bot:OriginalGetHealth()
    assert(nMissing > 450, 'the pin is down only ' .. nMissing .. ' health, below '
        .. 'the ally loop\'s own 450 floor')
    assert(bot:DistanceFromFountain() > 800, 'the pin is inside the fountain floor')
    assert(not bot:WasRecentlyDamagedByAnyHero(3.1),
        'the pin was recently damaged by a hero -- it is not the safe case')
    assert(#J.GetNearbyHeroes(bot, 1000, true, BOT_MODE_NONE) == 0,
        'the pin has an enemy inside 1000 -- it is not the safe case')

    local bUrn = false
    for i = 0, 8 do
        local h = bot:GetItemInSlot(i)
        if h ~= nil and h:GetName() == 'item_urn_of_shadows' then bUrn = true end
    end
    assert(bUrn, 'the pin no longer carries an urn')

    -- ...and the whole supply family still calls it empty-handed, which is what
    -- sends it home.  All four supply levers of the PROMOTED hold, armed.
    J.IsSoakCandidate = function(sId)
        return sId == 'staysrc' or sId == 'staybottle' or sId == 'staybag'
            or sId == 'bagsalve'
    end
    assert(J.HasFieldRegenSource(bot) == false,
        'the pin now has a recognised field regen source -- the premise that '
        .. 'the urn is invisible to this family no longer holds here')
end

return tests

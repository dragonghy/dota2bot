-- [staysrc 2026-09-05, 协同组] Owner priority P2: a hurt bot that is in no
-- danger must NOT go home -- "买大药或其他补给,回程太费时间". J.ShouldStayAndRegen
-- is the PROMOTED guard that says "stay and heal", live in every turbo game
-- since the 'tphome' promote, and its SUPPLY read disagrees with its own
-- docstring.
--
-- ⭐ THE REUSABLE JUDGEMENT, and it is the whole reason this lever is one
-- clause wide: THE FUNCTION'S OWN DOCSTRING IS A RECORD OF THE BEHAVIOUR THAT
-- WAS APPROVED, AND THE CODE UNDER IT CAN IMPLEMENT A SUBSET WITHOUT ANYTHING
-- IN THE TREE NOTICING. Forty-seven lines above the clause, the docstring says
-- the bot may stay if it "can afford a regen consumable (gold >= 90) OR ALREADY
-- CARRIES ONE". The code implements "already carries one" as item_flask alone,
-- so a tango, a tango_single, a faerie fire or a charged bottle in a main slot
-- read as "carries nothing". That is a 28-game A/B verdict ('tphome', +51 GPM)
-- whose approved shape and whose shipped shape are two different predicates,
-- and the difference has been live in every turbo game since.
--
-- ⭐⭐ THE INVERSION IS EXACT, NOT RHETORICAL. 90 is the price of a tango. So
-- shipped, this function accepts THE MONEY TO BUY A TANGO as proof of field
-- sustain and rejects THE TANGO. It trusts a purchase it has not made over an
-- item it already holds.
--
-- ⭐⭐⭐ WHY THIS CLAUSE AND NOT THE CONSTANT NEXT TO IT -- a structural answer
-- to the charter's own next slot ("is `GetGold() < 90` still the right gate in
-- Turbo?"). It is not answerable, and not because it is hard: gold is not
-- networked into a .dem (tools/batch_test/behavioral/hometp_invfull_lag.py,
-- honest-bounds block), so `bot:GetGold()` on every replay-derived frame is
-- mock/bot_api.lua's `^Get -> 0` type assertion (GH #495). The [gold] test
-- below drives it over all 1012 live frames and reads 0 on every one. A change
-- to the 90 is therefore STRUCTURALLY UNFIXTURABLE -- charter rule 2 forbids
-- landing it. The OTHER conjunct of that same `and` is read off real item slots
-- and is where the P2 defect actually sits. ⇒ When a constant cannot be
-- measured, price the other conjunct before concluding the clause is unreachable.
--
-- WHAT IS ASSERTED. Not gate plumbing. The shipped function is driven on real
-- frames with every candidate disarmed and then with exactly 'staysrc' armed,
-- and the CAUSE of the changed answer is read off the frame's own item slots.
--
-- ⚠️ HONEST BOUNDS, all four stated up front:
-- (1) THE MEASURED FLIP SET IS THE GOLD-POOR SUPERSET of the live one. A
--     fixture cannot read gold, so every frame here is scored as if the bot had
--     less than 90; in a real game the frames with >= 90 gold were never vetoed
--     by this clause in the first place. The direction of the bound is fixed
--     (the live set is a SUBSET), which is why it is publishable, but its size
--     is unknown and is not claimed.
-- (2) The bottle leg of J.HasFieldRegenSource is VACUOUS on this corpus: 0 of
--     the 44 flips are carried by a bottle, because the mock's GetCurrentCharges
--     default is 0 and an empty bottle is dumped under a different class name
--     ('item_empty_bottle'). The pinned frame carries exactly such an empty
--     bottle, and it is NOT what flips her. Asserted as a zero, not dressed up.
-- (3) Presence is not sufficiency. This lever asks "is there something to
--     drink", which is J.HasFieldRegenSource's question; whether that drink is
--     WORTH standing still for is a different question that already has its own
--     lever ('fieldsip', J.FIELD_SIP_HEAL) on the gated side. 13 of the 44
--     flips are carried by a faerie fire -- 85 health, the row 'fieldsip' was
--     written about. This file does not claim those 13 are good holds; it
--     claims the shipped function called them "carries nothing".
-- (4) A frame is one instant. This says the decision at t is wrong; it does not
--     claim the bot that stays then survives the next ten seconds.
--
-- ⭐⭐⭐⭐ AND THE FINDING THAT OUTLIVES THIS LEVER -- see the [pair] test.
-- This function protects the forbidden trip with TWO INDEPENDENT, INDIVIDUALLY
-- SUFFICIENT vetoes: the chase clause ('stayattr', landed hours earlier) and
-- the supply clause (this one). Neither lever alone moves owner priority P2's
-- OWN pinned frame; the pair does. Over 1012 live frames, `flips_pair_only` is
-- exactly 1 and it is that frame. So "one small lever at a time" (the lanefix
-- lesson) and "the priority's pinned frame flips" are, here, mutually
-- unsatisfiable, and every single-lever isolation wave reads a CORRECT zero on
-- the one frame the priority is named after. The AND-of-vetoes structure has to
-- be measured before a wave is designed, not after it comes back empty.

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')
local cs = require('corpus_scale')

local SWEEP = 'lua5.1 tests/_staysrc_sweep.lua'
local JMZ = 'bots/FunLib/jmz_func.lua'

-- The witnessed frame. Same replay family as the 'fieldbuy' gate work that owner
-- priority P2 spawned. Lina is 434/1088 = 39.9% HP, the nearest enemy hero of
-- any kind is 6,830 units away, nobody has hit her in 3 seconds -- and she is
-- holding a tango in slot 0 and an EMPTY bottle in slot 5. Shipped: "carries
-- nothing", the gold term decides, she is released to go home. Armed: she stays
-- and eats the tango.
local FX     = 'tests/fixtures/f_260822_182012_sb_fieldbuy_gate_307.lua'
local SUBJ   = 'npc_dota_hero_lina'
-- Two same-world controls, from the SAME fixture and the same instant, so that
-- "the lever moved it" cannot be confused with "this fixture world answers
-- TRUE". Viper is 55.7% HP with no drinkable in any main slot; spirit_breaker
-- is 36.1% HP carrying a blood grenade, which is a weapon, not regen. Both stay
-- FALSE on both legs.
local CTRL1  = 'npc_dota_hero_viper'
local CTRL2  = 'npc_dota_hero_spirit_breaker'
-- Owner priority P2's own pinned fixture and hero -- the and-of-vetoes frame.
local P2FX   = 'tests/fixtures/f_260822_063722_lina_tp_home.lua'
local P2SUBJ = 'npc_dota_hero_lina'

local tests = {}

local M = (function()
    local p = assert(io.popen(SWEEP, 'r'))
    local raw = p:read('*a')
    p:close()
    local m = { g = {}, c = {}, flips = {}, inert = {}, pair = {}, done = false }
    for line in raw:gmatch('[^\n]+') do
        local k, v = line:match('^G (%S+) (%S+)$')
        if k ~= nil then m.g[k] = tonumber(v) or v end
        local ck, cv = line:match('^C (%S+) (%-?%d+)$')
        if ck ~= nil then m.c[ck] = tonumber(cv) end
        local ff, fh, fp, fi = line:match('^F (%S+) (%S+) ([%d%.]+) (%S+)$')
        if ff ~= nil then
            m.flips[#m.flips + 1] = { fixture = ff, hero = fh,
                hp = tonumber(fp), item = fi }
        end
        local nf, nh, np = line:match('^N (%S+) (%S+) ([%d%.]+)$')
        if nf ~= nil then
            m.inert[#m.inert + 1] = { fixture = nf, hero = nh, hp = tonumber(np) }
        end
        local pf, ph, pp = line:match('^P (%S+) (%S+) ([%d%.]+)$')
        if pf ~= nil then
            m.pair[#m.pair + 1] = { fixture = pf, hero = ph, hp = tonumber(pp) }
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

-- Load one fixture frame with every soak candidate disarmed, and hand back a
-- switch that arms exactly 'staysrc'. Arming ONE id (not 'all') is the point: a
-- bundle answer cannot be attributed to this lever.
local function frame(path, subject)
    local J, bot = rf.load(path, subject)
    local armed = false
    J.IsSoakCandidate = function(sId) return armed and sId == 'staysrc' end
    return J, bot, function(b) armed = b end
end

local function main_slot_names(bot)
    local t = {}
    for i = 0, 5 do
        local hItem = bot:GetItemInSlot(i)
        t[#t + 1] = (hItem ~= nil) and hItem:GetName() or '-'
    end
    return t
end

local function has_main(bot, sName)
    for _, n in ipairs(main_slot_names(bot)) do
        if n == sName then return true end
    end
    return false
end

local function nearest_enemy(J, bot)
    local best = -1
    for _, h in pairs(J.GetNearbyHeroes(bot, 100000, true, BOT_MODE_NONE) or {}) do
        if J.IsValidHero(h) then
            local d = GetUnitToUnitDistance(bot, h)
            if best < 0 or d < best then best = d end
        end
    end
    return best
end

-- --------------------------------------------------- the tree, as source ---

tests['[source] the lever is where this file says it is'] = function()
    assert(M.done, 'the sweep subprocess did not finish (no DONE line) -- every '
        .. 'count below would be a partial read')
    assert(M.g.STAY == 1, 'the sweep could not slice J.ShouldStayAndRegen out of '
        .. JMZ)
    assert(M.g.SRC == 1, 'the sweep could not slice J.HasFieldRegenSource out of '
        .. JMZ .. ' -- this whole file is stale')
    assert(M.g.STAY_SOAKID == 1, "the 'staysrc' id is no longer in "
        .. 'J.ShouldStayAndRegen -- the lever left the tree')
    assert(M.g.STAY_CALLS_SRC == 1, 'J.ShouldStayAndRegen no longer calls '
        .. 'J.HasFieldRegenSource -- the widening is gone')
    -- The pullcad trap, as an assertion instead of prose: two ids CONJOINED IN
    -- ONE CONDITION freeze that condition FALSE the day either is promoted,
    -- while check_armed_wiring.py still calls it WIRED. This function carries
    -- two ids on two SEPARATE clauses, which is a different (and here
    -- load-bearing) thing -- see the [pair] test.
    assert(M.g.STAY_IDS_MAX_PER_COND == 1, 'some single condition in '
        .. 'J.ShouldStayAndRegen names ' .. tostring(M.g.STAY_IDS_MAX_PER_COND)
        .. ' soak ids; at most 1 is allowed (two conjoined ids = the pullcad trap)')
    -- [staybottle 2026-09-05] This read `== 2` until the supply clause gained a
    -- THIRD independent lever (the bottle's in-flight modifier). The number is a
    -- PROXY for "this function's levers are separate clauses, not a
    -- conjunction"; the assertion that actually carries that meaning is
    -- STAY_IDS_MAX_PER_COND above, and it is unchanged. Loosened to a floor
    -- rather than re-pinned to 3, so a fourth sibling lever does not turn this
    -- file red for a reason that has nothing to do with 'staysrc'.
    assert(M.g.STAY_NIDS >= 2, 'J.ShouldStayAndRegen names '
        .. tostring(M.g.STAY_NIDS) .. " soak ids; expected at least 2 "
        .. "('stayattr' on the chase clause, 'staysrc' on the supply clause). "
        .. 'If this dropped to 1 the [pair] finding below is about a tree that '
        .. 'no longer exists')
    -- The nesting this lever creates, pinned so that the (A) classification in
    -- tests/test_gated_helper_nesting_census.lua stays readable: the callee
    -- carries exactly one gate of its own, 'bagsalve'.
    assert(M.g.SRC_NIDS == 1, 'J.HasFieldRegenSource names '
        .. tostring(M.g.SRC_NIDS) .. " soak ids; expected 1 ('bagsalve'). The "
        .. 'census row that calls this nesting additive-only needs re-reading')
end

tests['[source] the asymmetry, as two parsed numbers'] = function()
    -- The finding is 1 vs 5, and both halves are read off comment-stripped
    -- source so the shipped comment cannot satisfy the check it is about.
    assert(M.g.STAY_SHIPPED_ITEMS == 1, "the shipped supply read names "
        .. tostring(M.g.STAY_SHIPPED_ITEMS) .. ' consumable item names; expected '
        .. '1 (item_flask). If it grew, the defect this file measures was fixed '
        .. 'somewhere else and this lever needs re-deriving')
    assert(M.g.SRC_ITEMS == 5, 'J.HasFieldRegenSource names '
        .. tostring(M.g.SRC_ITEMS) .. ' consumable item names; expected 5')
    -- The docstring is a COMMENT and is read as one, on purpose: it is the
    -- record of the approved behaviour, and deleting the sentence must turn
    -- this finding red rather than dissolve it.
    assert(M.g.DOC_CARRIES == 1, 'the docstring phrase "or already carries one" '
        .. 'is gone from ' .. JMZ .. ' -- the mismatch this lever is named after '
        .. 'can no longer be read off the tree')
end

tests['[source] the constants are the tree\'s, not this file\'s memory'] = function()
    assert(M.g.STAY_GOLD == 90, 'the supply gold threshold is '
        .. tostring(M.g.STAY_GOLD) .. ', expected 90 (the tango price the '
        .. 'inversion above is stated in terms of)')
    assert(M.g.STAY_RING == 1200, 'the untouched proximity ring is '
        .. tostring(M.g.STAY_RING) .. ', expected 1200')
    assert(M.g.STAY_HP_LO == 0.18 and M.g.STAY_HP_HI == 0.75,
        'the HP band moved: ' .. tostring(M.g.STAY_HP_LO) .. '..'
        .. tostring(M.g.STAY_HP_HI))
    assert(M.g.STAY_CHASE_WINDOW == 3, 'the chase window is '
        .. tostring(M.g.STAY_CHASE_WINDOW) .. ', expected 3.0 -- the sweep '
        .. 'reproduces the prefix walk with it')
end

-- --------------------------------------------------------- the frame ------

tests['[frame] shipped sends a safe, tango-carrying lina home'] = function()
    local J, bot, arm = frame(FX, SUBJ)
    local nHP = J.GetHP(bot)
    assert(nHP > 0.18 and nHP < 0.75, 'lina is at ' .. string.format('%.4f', nHP)
        .. ' HP, outside the guard\'s own band -- this frame stopped being about '
        .. 'this clause')
    -- She is in NO danger, which is what makes this the trip P2 forbids.
    assert(not bot:WasRecentlyDamagedByAnyHero(3.0),
        'someone hit lina within 3s on this frame -- the chase clause, not the '
        .. 'supply clause, would own this decision')
    local nNear = nearest_enemy(J, bot)
    assert(nNear > 1200, 'the nearest enemy is ' .. string.format('%.0f', nNear)
        .. ' units away, inside the shipped 1200 ring -- a different clause vetoes')
    assert(nNear > 6000, 'the nearest enemy is only '
        .. string.format('%.0f', nNear) .. ' units away; this frame was pinned '
        .. 'because nobody is anywhere near her')
    arm(false)
    assert(J.ShouldStayAndRegen(bot) == false,
        'shipped already keeps lina in the field on this frame -- there is '
        .. 'nothing for this lever to fix here')
end

tests['[frame] and it is the TANGO she is holding that shipped cannot see'] = function()
    local J, bot = frame(FX, SUBJ)
    local slots = main_slot_names(bot)
    assert(has_main(bot, 'item_tango'), 'lina no longer carries a tango in a '
        .. 'main slot (' .. table.concat(slots, ',') .. ') -- the cause this '
        .. 'file names is not on the frame')
    -- The shipped read's ONLY item name, absent -- which is why it answers
    -- "carries nothing" while she is holding regen.
    assert(not has_main(bot, 'item_flask'), 'lina carries a salve in a main '
        .. 'slot, so the SHIPPED read already sees supply and this frame cannot '
        .. 'witness the gap')
    -- Honest bound (2), on the frame: the bottle in slot 5 is an EMPTY one and
    -- is not what carries the flip.
    assert(has_main(bot, 'item_empty_bottle'), 'the empty bottle left slot 5 -- '
        .. 'the vacuous-bottle bound below is no longer witnessed here')
    assert(not has_main(bot, 'item_bottle'), 'a CHARGED bottle appeared on this '
        .. 'frame; the flip would no longer be attributable to the tango alone')
    -- Drive the sibling directly: it is the predicate the lever borrows.
    assert(J.HasFieldRegenSource(bot) == true, 'J.HasFieldRegenSource answers '
        .. 'FALSE on a frame with a tango in a main slot -- the sibling this '
        .. 'lever leans on has changed')
end

tests['[frame] armed, she stays -- and it is this lever that did it'] = function()
    local J, bot, arm = frame(FX, SUBJ)
    arm(false)
    local shipped = J.ShouldStayAndRegen(bot)
    arm(true)
    local armed = J.ShouldStayAndRegen(bot)
    assert(shipped == false and armed == true,
        'the guard did not flip on the pinned frame: shipped=' .. tostring(shipped)
        .. ' armed=' .. tostring(armed))
    -- Attribution, not coincidence: with the tango removed from the frame, the
    -- armed leg must fall back to the shipped answer. Nothing else about the
    -- world changes.
    local hSlot0 = bot:GetItemInSlot(0)
    assert(hSlot0 ~= nil and hSlot0:GetName() == 'item_tango',
        'slot 0 is not the tango any more; the removal below would prove nothing')
    local J2, bot2, arm2 = frame(FX, SUBJ)
    local old = bot2.GetItemInSlot
    bot2.GetItemInSlot = function(self, i)
        if i == 0 then return nil end
        return old(self, i)
    end
    arm2(true)
    assert(J2.ShouldStayAndRegen(bot2) == false,
        'the armed guard still holds lina after her only regen source is taken '
        .. 'off the frame -- the flip is not attributable to the tango')
end

tests['[control] same world, same instant, no regen: nothing moves'] = function()
    for _, sHero in ipairs({ CTRL1, CTRL2 }) do
        local J, bot, arm = frame(FX, sHero)
        assert(J.HasFieldRegenSource(bot) == false, sHero
            .. ' carries a field regen source after all ('
            .. table.concat(main_slot_names(bot), ',')
            .. ') -- it cannot serve as the negative control')
        arm(false)
        local shipped = J.ShouldStayAndRegen(bot)
        arm(true)
        local armed = J.ShouldStayAndRegen(bot)
        assert(shipped == false and armed == false, sHero
            .. ' moved: shipped=' .. tostring(shipped) .. ' armed='
            .. tostring(armed) .. ' -- the flip on lina would then be a property '
            .. 'of this fixture world, not of the item she is holding')
    end
end

-- --------------------------------------------------------- the census -----

tests['[census] the domain price of the lever'] = function()
    cs.corpus(C('fixtures'), 'fixture corpus')
    cs.ratchet(C('live'), 1012, 'live hero frames')
    -- Turbo is structural: the guard's first line asks, and the fixture world
    -- answers yes everywhere, so no frame is lost to it.
    assert(C('turbo') == C('live'), 'only ' .. C('turbo') .. ' of ' .. C('live')
        .. ' live frames are turbo -- the guard exits on line 1 for the rest '
        .. 'and the census below is not measuring this clause')
    assert(C('raises') == 0 and C('pair_raises') == 0,
        'the shipped guard raised on ' .. (C('raises') + C('pair_raises'))
        .. ' frames; a raised frame is not a measured FALSE')
    -- The clause is REACHED on 125 frames and vetoes on 112 of them: at this
    -- point in the function the supply read is not a corner, it is the dominant
    -- remaining veto. That is what makes a one-name read of it expensive.
    cs.ratchet(C('supply_tested'), 125, 'frames that reach the supply clause')
    cs.ratchet(C('blocked_supply'), 112, 'frames the supply clause vetoes')
    -- Exclusive partition, counted out rather than inferred by subtraction, so
    -- that "the lever is inert here" and "the situation is rare" stay different
    -- claims.
    assert(C('blocked_with_src') + C('blocked_no_src') == C('blocked_supply'),
        'the supply-veto partition does not sum: ' .. C('blocked_with_src')
        .. ' + ' .. C('blocked_no_src') .. ' ~= ' .. C('blocked_supply'))
    cs.ratchet(C('blocked_with_src'), 44, 'vetoed frames that DO carry regen')
    cs.ratchet(C('blocked_no_src'), 68, 'vetoed frames carrying nothing (inert)')
    -- Two independent routes to one number: the driven return value and the
    -- bucketed prefix walk. Agreement is the anti-drift leg; a shadow that had
    -- drifted away from the tree would show up here as a mismatch.
    assert(C('flips') == C('blocked_with_src'), 'the driven flip count ('
        .. C('flips') .. ') and the bucketed one (' .. C('blocked_with_src')
        .. ') disagree -- one of the two routes has drifted off the tree')
    -- Direction, by construction: widening bHasRegen can only remove vetoes.
    assert(C('flip_true_to_false') == 0, C('flip_true_to_false')
        .. ' frames turned TRUE -> FALSE under arming; the lever is supposed to '
        .. 'be additive by construction')
    -- One id wide. 'bagsalve' is named explicitly because it is the id nested
    -- inside the callee: if the stub ever armed it, the flip set would silently
    -- gain backpack salves and the attribution would be wrong without failing.
    assert(C('arm_leak') == 0, 'the sweep stub armed ' .. C('arm_leak')
        .. ' frames worth of OTHER ids -- the flips are not attributable to '
        .. "'staysrc' alone")
end

tests['[gold] the other conjunct cannot be measured, and that is measured'] = function()
    -- The load-bearing zero behind honest bound (1). Gold is not networked into
    -- a .dem, so no fixture carries it and the mock answers the `^Get -> 0`
    -- scalar; the day that stops being true, this goes red and the bound gets
    -- re-derived instead of quietly staying in a report.
    assert(C('gold_nonzero') == 0, C('gold_nonzero') .. ' live frames report a '
        .. 'non-zero GetGold(). The corpus can now read gold -- honest bound (1) '
        .. '("the measured flip set is the GOLD-POOR SUPERSET") must be '
        .. 're-derived, and the charter slot "is `GetGold() < 90` right in '
        .. 'Turbo?" may finally be answerable')
    assert(C('gold_zero') == C('live'), 'only ' .. C('gold_zero') .. ' of '
        .. C('live') .. ' frames were probed for gold')
end

tests['[census] the bottle leg is vacuous on this corpus'] = function()
    -- Honest bound (2) as a number: no flip anywhere is carried by a bottle.
    local n = { }
    for _, r in ipairs(M.flips) do n[r.item] = (n[r.item] or 0) + 1 end
    assert((n['item_bottle'] or 0) == 0, (n['item_bottle'] or 0)
        .. ' flips are carried by a charged bottle; the vacuous-bottle bound is '
        .. 'no longer honest')
    assert((n['item_flask'] or 0) == 0, 'a flip is carried by item_flask, which '
        .. 'the SHIPPED read already sees -- the two reads have stopped being '
        .. 'nested and the direction argument needs re-checking')
    -- And the three legs that DO carry it, so bound (3) names real rows.
    assert((n['item_tango'] or 0) >= 1 and (n['item_faerie_fire'] or 0) >= 1,
        'the flip set no longer contains both a tango row and a faerie-fire row; '
        .. 'honest bound (3) is about rows that are not there any more')
end

-- ------------------------------------------------ the and-of-vetoes -------

tests['[pair] neither lever alone moves P2\'s own pinned frame'] = function()
    local J, bot = rf.load(P2FX, P2SUBJ)
    local function drive(t)
        J.IsSoakCandidate = function(sId) return t[sId] == true end
        return J.ShouldStayAndRegen(bot)
    end
    local nHP = J.GetHP(bot)
    assert(nHP > 0.18 and nHP < 0.75, 'the P2 frame is at '
        .. string.format('%.4f', nHP) .. ' HP, outside the guard\'s band')
    -- She IS recently damaged (a zuus global from ~10,400 units) and she IS
    -- carrying regen (a faerie fire) -- so both vetoes are live on one frame.
    assert(bot:WasRecentlyDamagedByAnyHero(3.0),
        'nobody hit lina within 3s on the P2 frame -- the chase veto is not live '
        .. 'here and this is no longer an and-of-vetoes witness')
    assert(J.HasFieldRegenSource(bot) == true,
        'lina carries no field regen source on the P2 frame -- the supply veto '
        .. 'is not the one this lever would remove')
    assert(drive({}) == false, 'shipped already keeps her in the field')
    assert(drive({ stayattr = true }) == false,
        "'stayattr' alone now flips the P2 frame -- the pair finding is stale")
    assert(drive({ staysrc = true }) == false,
        "'staysrc' alone now flips the P2 frame -- the pair finding is stale")
    assert(drive({ stayattr = true, staysrc = true }) == true,
        'the PAIR does not flip the P2 frame either -- a third veto is in the '
        .. 'way and the wave guidance in this file is wrong')
    J.IsSoakCandidate = function() return false end
end

tests['[pair] and it is exactly one frame in the corpus -- that one'] = function()
    -- The number that decides whether an (a)-evidence wave for P2 may arm these
    -- one at a time. It may not: the only frame in 1012 that requires the pair
    -- is the frame the priority is named after.
    cs.ratchet(C('flips_pair_only'), 1, 'frames that only the PAIR flips')
    assert(#M.pair >= 1, 'the sweep emitted no P row while the counter is '
        .. C('flips_pair_only'))
    local hit = false
    for _, r in ipairs(M.pair) do
        if r.fixture == 'f_260822_063722_lina_tp_home'
            and r.hero == P2SUBJ then hit = true end
    end
    assert(hit, "the pair-only frame is no longer owner priority P2's pinned "
        .. 'frame -- the wave guidance in this file was argued from that '
        .. 'coincidence and must be re-argued')
    -- Each lever is independently non-trivial, so this is not "one lever with
    -- two names": 'stayattr' flips 1 frame alone, 'staysrc' flips 44 alone.
    assert(C('flips_attr') >= 1 and C('flips') >= 1,
        'one of the two levers no longer flips anything on its own; they are no '
        .. 'longer two independent vetoes')
    -- Sanity on the arithmetic of the four drives: arming both cannot answer
    -- TRUE on fewer frames than arming either.
    assert(C('both_true') >= C('arm_true') and C('both_true') >= C('attr_true'),
        'the pair answers TRUE on fewer frames (' .. C('both_true')
        .. ') than a single lever -- the two clauses are interfering, which '
        .. 'contradicts the independence this file asserts')
end

return tests

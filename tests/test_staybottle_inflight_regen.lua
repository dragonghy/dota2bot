-- [staybottle 2026-09-05, 协同组] Owner priority P2: a hurt bot that is in no
-- danger must NOT go home -- "血量低也尽量不要回程,买大药或其他补给". The PROMOTED
-- guard that says "stay and heal" is J.ShouldStayAndRegen (live in every turbo
-- game since the 'tphome' promote), and its supply read has one member missing.
--
-- ⭐ THE REUSABLE JUDGEMENT, and it generalises well past this lever:
-- A CONSUMABLE IS AT ITS LEAST VISIBLE IN THE INVENTORY EXACTLY WHILE IT IS
-- WORKING. The instant a bottle is drunk the engine renames the item to
-- 'item_empty_bottle' (CDOTA_Item_EmptyBottle) and drops its charges to 0, so
-- BOTH ways this tree asks "is there something to drink" answer NO while a
-- ~135-health sip is arriving: the shipped name test (item_flask only) and
-- J.HasFieldRegenSource's bottle leg, which requires GetCurrentCharges() > 0.
-- The moment of maximum supply is read as empty-handed. ⇒ A supply predicate
-- must read BOTH the stock and the in-flight effect; one that reads only stock
-- inverts, systematically, for the whole duration of the effect.
--
-- ⭐⭐ AND THE TREE ALREADY KNEW. Two of the three disjuncts of the shipped
-- supply read are IN-FLIGHT modifiers ('modifier_flask_healing',
-- 'modifier_tango_heal') -- so this line's own author accepted "it is being
-- drunk right now" as proof of field sustain, for two of the four consumables
-- the family recognises. The bottle's modifier is in neither this line nor the
-- 'staysrc' widening under it, while the tpscroll '撤退:3' branch
-- (ability_item_usage_generic ~5666) lists it among the modifiers that refuse a
-- home TP. Same shape as 'stayattr' (the attributed chase read) and 'staysrc'
-- (the item-slot supply read) before it: the question was answered correctly
-- elsewhere in the tree and this shipped line was never brought along. Both G
-- facts are parsed off the source below, not restated.
--
-- ⭐⭐⭐ THIS ROUND DISCHARGES ITS SIBLING'S REGISTERED GAP. Honest bound (2) of
-- tests/test_staysrc_field_supply.lua says the bottle leg of
-- J.HasFieldRegenSource is VACUOUS on this corpus -- 0 of its 44 flips carried
-- by a bottle -- and names the empty bottle on the P2 frame as something that
-- is NOT what flips her. `src_true_via_bottle` below re-measures that zero from
-- this side, and this lever is the form in which a bottle CAN be seen: the
-- modifier is in the dump, the charge count never will be.
--
-- WHAT IS ASSERTED. Not gate plumbing. The shipped function is driven on real
-- frames with every candidate disarmed and then with exactly 'staybottle'
-- armed, and the CAUSE of the changed answer is read off the frame's own
-- modifier list and item slots.
--
-- ⚠️ HONEST BOUNDS, all four stated up front:
-- (1) THE DOMAIN IS ONE FRAME, and that is a measurement, not an apology: 3 of
--     1012 live hero frames carry the modifier and 2 of them are above the
--     function's own 0.75 HP ceiling, so exactly one frame is inside the
--     domain. The anti-vacuum column (`mod_carriers` / `mod_out_of_band`) keeps
--     "the corpus has no bottles" and "the corpus has bottles the band rejects"
--     from ever reading the same.
-- (2) WHAT THE BID CASE MEASURES IS THE VETO FIRING, NOT A TRIP PREVENTED. On
--     the pinned frame mode_retreat_generic already bids NEGATIVE (-0.4721), so
--     arming moves the bid to BOT_MODE_DESIRE_NONE (0) -- numerically UP, and
--     in neither case is this mode asking to go home. The trip this defect
--     actually enables is the item-layer one, and that is structurally
--     unreachable on a fixture (GH #89: GetActiveMode is bot-VM state absent
--     from every .dem, so `nMode == BOT_MODE_RETREAT` is false everywhere).
--     Asserted as numbers below rather than footnoted.
-- (3) THE MEASURED FLIP SET IS THE GOLD-POOR SUPERSET of the live one. A
--     fixture cannot read gold (GH #495), so every frame is scored as if the
--     bot had less than 90; in a real game the frames with >= 90 gold were
--     never vetoed by this clause at all. The direction is fixed; the size is
--     unknown and is not claimed.
-- (4) A frame is one instant, and a sip has a tail. This says the decision at t
--     is wrong; it does not claim the remaining sip is always enough to stay
--     for -- that magnitude question belongs to 'fieldsip' on the gated family,
--     and a bottle sip is the LARGEST of the four sources it prices.

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')
local cs = require('corpus_scale')

local SWEEP = 'lua5.1 tests/_staybottle_sweep.lua 2>/dev/null'
local JMZ   = 'bots/FunLib/jmz_func.lua'
local RETREAT = 'bots/mode_retreat_generic.lua'
local MOD   = 'modifier_bottle_regeneration'

-- The pinned frame: zuus 360/911 = 39.5% HP, holding an item_empty_bottle with
-- 2.5s of sip left, nearest enemy 1,727 units off, nobody having touched him.
local FX    = 'tests/fixtures/f_260820_102645_cm_es_reach.lua'
local SUBJ  = 'npc_dota_hero_zuus'
-- The two carriers OUTSIDE the band -- the negative controls that keep the
-- lever from being credited with the band's work.
local OOB = {
    { fx = 'tests/fixtures/f_260819_222526_jakiro_defend_fresh.lua',
      subj = 'npc_dota_hero_nevermore', hp = 1.0 },
    { fx = 'tests/fixtures/f_260820_182906_lion_drain_survived.lua',
      subj = 'npc_dota_hero_lina', hp = 0.8048 },
}

local SHIPPED_BID = -0.4721206757224
local ARMED_BID   = 0.0

local tests = {}

local M = (function()
    local p = assert(io.popen(SWEEP, 'r'))
    local raw = p:read('*a')
    p:close()
    local m = { g = {}, c = {}, flips = {}, carriers = {}, done = false }
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
        local bf, bh, bp, bb = line:match('^B (%S+) (%S+) ([%d%.]+) (%d)$')
        if bf ~= nil then
            m.carriers[#m.carriers + 1] = { fixture = bf, hero = bh,
                hp = tonumber(bp), in_band = (bb == '1') }
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

local function near(a, b, eps)
    return math.abs(a - b) <= (eps or 1e-9)
end

--- Load one fixture frame with every soak candidate disarmed, and hand back a
--- switch that arms exactly one id. Arming ONE id (not 'all') is the point: a
--- bundle answer cannot be attributed to this lever.
local function frame(path, subject, sId)
    local J, bot = rf.load(path, subject)
    local armed = false
    J.IsSoakCandidate = function(s) return armed and s == (sId or 'staybottle') end
    return J, bot, function(b) armed = b end
end

-- --------------------------------------------------- the tree, as source ---

tests['[source] the lever is where this file says it is'] = function()
    assert(M.done, 'the sweep subprocess did not finish (no DONE line) -- every '
        .. 'number below would be a silent zero')
    assert(M.g.STAY == 1, 'the sweep could not slice J.ShouldStayAndRegen out of '
        .. JMZ)
    assert(M.g.SRC == 1, 'the sweep could not slice J.HasFieldRegenSource out of '
        .. JMZ)
    assert(M.g.STAY_SOAKID == 1, "the 'staybottle' id is no longer in "
        .. 'J.ShouldStayAndRegen (comments are stripped before this is read)')
    assert(M.g.STAY_READS_MOD == 1,
        'the lever no longer reads ' .. MOD)
end

tests['[source] one id per condition -- the pullcad trap, not the id count'] = function()
    -- A CONJUNCTION of ids in one condition freezes FALSE the day either is
    -- promoted, while check_armed_wiring.py still calls the site WIRED. Three
    -- INDEPENDENT ids in one function is not that shape; a single condition
    -- naming two of them would be.
    assert(M.g.STAY_IDS_MAX_PER_COND == 1, 'some single condition in '
        .. 'J.ShouldStayAndRegen names ' .. tostring(M.g.STAY_IDS_MAX_PER_COND)
        .. ' soak ids -- that is the pullcad trap')
    -- [staybag 2026-09-05] This read `== 3` for three hours. The total is a
    -- PROXY for the trap and the trap's actual shape is the line above it; a
    -- fourth INDEPENDENT lever ('staybag', its own `if`, sharing no condition
    -- with any other) turned it red on a tree that has no trap on it. Exactly
    -- the recurrence tests/test_stayattr_global_ult.lua:155 already wrote down
    -- when 'staysrc' did it to `== 1`, and this file laid the same trap again on
    -- the same day. The floor still refuses a deletion that makes the function
    -- id-free.
    assert(M.g.STAY_NIDS >= 3, 'J.ShouldStayAndRegen names '
        .. tostring(M.g.STAY_NIDS) .. " soak ids; expected at least 3 ('stayattr'"
        .. " on the chase clause, 'staysrc' and 'staybottle' on the supply "
        .. 'clause)')
end

tests['[source] appended, never inserted -- the sibling must be untouched'] = function()
    -- With this id un-armed the 'staysrc' evaluation has to be byte-identical,
    -- and that is only true while this block sits AFTER it. Position is read
    -- inside the comment-stripped function body, so prose naming either id
    -- cannot move it.
    assert(M.g.STAY_ORDER_OK == 1,
        "the 'staybottle' block no longer sits after the 'staysrc' block")
end

tests['[source] the shipped read already accepts TWO in-flight modifiers'] = function()
    -- This is the whole argument for the third, so it is parsed, not asserted
    -- from memory: the shipped supply expression names two HasModifier reads
    -- and neither of them is the bottle's.
    assert(M.g.STAY_SHIPPED_MODS == 2, 'the shipped supply read names '
        .. tostring(M.g.STAY_SHIPPED_MODS) .. ' in-flight modifiers; expected 2 '
        .. '(flask_healing, tango_heal). If this grew, the finding changed.')
    assert(M.g.STAY_SHIPPED_HAS_BOTTLE_MOD == 0,
        'the shipped supply read now names the bottle modifier itself -- this '
        .. 'lever would be a no-op and must be re-read, not re-run')
end

tests['[source] the sibling presence test can only see a CHARGED bottle'] = function()
    assert(M.g.SRC_BOTTLE_NEEDS_CHARGES == 1,
        'J.HasFieldRegenSource no longer gates its bottle leg on charges -- the '
        .. 'blindness this lever is about would be gone')
    -- The corroborating site, read off the live item file (a real condition
    -- there, not a comment): the tree refuses a home TP while this modifier is
    -- up, 130 lines of decision away from the function that ignores it.
    assert(M.g.TP3_LISTS_BOTTLE_MOD == 1,
        'ability_item_usage_generic no longer names ' .. MOD
        .. ' -- the "the tree already knew" half of this finding is gone')
end

tests['[source] the constants this lever does NOT touch'] = function()
    assert(M.g.STAY_HP_LO == 0.18 and M.g.STAY_HP_HI == 0.75,
        'the HP band moved: ' .. tostring(M.g.STAY_HP_LO) .. '..'
        .. tostring(M.g.STAY_HP_HI) .. ' -- the two out-of-band controls below '
        .. 'are scored against it')
    assert(M.g.STAY_RING == 1200, 'the untouched proximity ring is '
        .. tostring(M.g.STAY_RING) .. ', expected 1200')
    assert(M.g.STAY_CHASE_WINDOW == 3, 'the chase window is '
        .. tostring(M.g.STAY_CHASE_WINDOW) .. ', expected 3.0')
end

-- ------------------------------------------------------- the domain price ---

tests['[domain] the corpus, and what reaches the supply clause'] = function()
    -- [GH #538, 2026-09-05] These two were written as equalities against the
    -- corpus size the day this file landed (`== 109` / `== 1012`), which is the
    -- GH #106 / #127 defect: the next fixture turns them red without anything
    -- this file measures having moved. Both are sums over an append-only corpus,
    -- so the honest pins are the floor and the ratchet -- a count that FALLS is
    -- still the behaviour change these lines were written to catch. The sibling
    -- file (test_staysrc_field_supply.lua:339) already did it this way.
    cs.corpus(C('fixtures'), 'fixture corpus')
    cs.ratchet(C('live'), 1012, 'live hero frames')
    assert(C('turbo') == C('live'),
        'some live frame is not turbo, which the first line of the function '
        .. 'would have vetoed before anything this file measures')
    assert(C('raises') == 0, C('raises') .. ' frames raised inside the drive')
    assert(C('supply_tested') == 125, 'frames reaching the supply clause: '
        .. C('supply_tested') .. ' (the sibling lever measured 125 on the same '
        .. 'corpus through its own prefix walk)')
    assert(C('blocked_supply') == 112, 'frames the supply clause vetoes: '
        .. C('blocked_supply'))
    assert(C('blocked_with_mod') + C('blocked_no_mod') == C('blocked_supply'),
        'the two-bin split of the vetoed frames does not sum -- counted, not '
        .. 'subtracted, so this is an arithmetic invariant')
end

tests['[domain] one frame, and the two carriers the band rejects'] = function()
    assert(C('mod_carriers') == 3, 'live frames carrying ' .. MOD .. ': '
        .. C('mod_carriers'))
    assert(C('mod_out_of_band') == 2, 'carriers above the HP ceiling: '
        .. C('mod_out_of_band') .. ' -- this is the ANTI-VACUUM column: it is '
        .. 'what keeps "the corpus has no bottles" from reading the same as '
        .. '"the corpus has bottles the band rejects"')
    assert(C('blocked_with_mod') == 1, 'frames inside the domain: '
        .. C('blocked_with_mod'))
    assert(#M.flips == 1 and M.flips[1].hero == SUBJ,
        'the single flip row is not the pinned frame')
    assert(M.flips[1].item == 'item_empty_bottle',
        'the flip frame carries ' .. M.flips[1].item .. ', not the empty bottle '
        .. 'that makes this finding structural')
    assert(#M.carriers == 3, 'carrier rows emitted: ' .. #M.carriers)
end

tests['[domain] two independent routes to the same number'] = function()
    -- `flips` comes from the function's own return value across two drives;
    -- `blocked_with_mod` comes from the prefix walk. A drift in either shows up
    -- as a red instead of as agreement.
    assert(C('flips') == C('blocked_with_mod'), 'driven flips ' .. C('flips')
        .. ' vs bucketed ' .. C('blocked_with_mod'))
    assert(C('arm_true') - C('ship_true') == C('flips'),
        'the TRUE count moved by ' .. (C('arm_true') - C('ship_true'))
        .. ' while ' .. C('flips') .. ' frames flipped')
    assert(C('ship_true') == 13 and C('arm_true') == 14,
        'shipped/armed TRUE totals moved: ' .. C('ship_true') .. '/'
        .. C('arm_true'))
end

tests['[domain] direction is fixed by construction, and measured anyway'] = function()
    assert(C('flip_true_to_false') == 0, C('flip_true_to_false')
        .. ' frames turned TRUE -> FALSE; widening bHasRegen can only REMOVE '
        .. 'vetoes, so this is a contradiction, not a regression')
end

tests['[domain] the arming is exactly one id wide'] = function()
    assert(C('arm_leak') == 0, "the sweep's armed stub also answered TRUE for "
        .. "'staysrc'/'bagsalve'/'stayattr' on " .. C('arm_leak') .. ' frames -- '
        .. 'the flips would not be attributable to this lever')
end

tests['[domain] the gold term is unmeasurable, and that is measured'] = function()
    assert(C('gold_nonzero') == 0, C('gold_nonzero') .. ' frames carry real '
        .. 'gold. Honest bound (3) -- the gold-poor superset -- holds only '
        .. 'while this is 0; re-derive the bound, do not edit this line')
    assert(C('gold_zero') == C('live'), 'gold buckets do not partition')
end

tests['[domain] the bottle leg of the sibling is vacuous, re-measured'] = function()
    -- Honest bound (2) of tests/test_staysrc_field_supply.lua, re-driven from
    -- this side. If a fixture ever carries a charged bottle this goes red and
    -- the "only the modifier can see a bottle" claim gets re-read.
    assert(C('src_true_via_bottle') == 0,
        'J.HasFieldRegenSource now answers TRUE through its bottle leg on '
        .. C('src_true_via_bottle') .. ' frames')
end

tests['[domain] this lever and its sibling are DISJOINT -- the GH #532 question'] = function()
    -- GH #532: the same function's other two levers move owner P2's pinned
    -- frame only as a PAIR, so a single-arm isolation wave reads a correct zero
    -- there. That is a property of those two clauses, not of this function, and
    -- it is measured here rather than assumed either way: 'staysrc' alone flips
    -- 44 frames, this lever flips 1, and the overlap is 0. A single-arm wave
    -- CAN see this lever.
    assert(C('flips_staysrc') == 44, "'staysrc' alone flips "
        .. C('flips_staysrc') .. ' frames; the sibling file measured 44')
    assert(C('flips_both_levers') == 0, C('flips_both_levers')
        .. ' frames are flipped by BOTH levers -- the domains are no longer '
        .. 'disjoint and the wave design in the report has to change')
end

-- ------------------------------------------------------------- the frame ---

tests['[frame] zuus is hurt, unchased, and mid-sip'] = function()
    local J, bot = frame(FX, SUBJ)
    assert(near(J.GetHP(bot), 0.3952, 0.0005), 'HP moved: ' .. J.GetHP(bot))
    assert(bot:HasModifier(MOD) == true, 'the sip is not on this frame any more')
    assert(bot:WasRecentlyDamagedByAnyHero(3.0) == false,
        'a hero touched him -- the chase clause would veto before the supply '
        .. 'clause is ever reached')
    assert(#J.GetNearbyHeroes(bot, 1200, true, BOT_MODE_NONE) == 0,
        'someone is inside the 1200 ring')
end

tests['[frame] and BOTH inventory reads call him empty-handed'] = function()
    local J, bot = frame(FX, SUBJ)
    local names = {}
    for i = 0, 8 do
        local it = bot:GetItemInSlot(i)
        names[#names + 1] = (it ~= nil) and it:GetName() or '-'
    end
    local sInv = table.concat(names, ' ')
    assert(sInv:find('item_empty_bottle', 1, true),
        'the bottle is no longer dumped under the empty class name: ' .. sInv)
    assert(not sInv:find('item_flask', 1, true), 'a salve appeared: ' .. sInv)
    assert(not sInv:find('item_tango', 1, true), 'a tango appeared: ' .. sInv)
    assert(bot:HasModifier('modifier_flask_healing') == false, 'no salve ticking')
    assert(bot:HasModifier('modifier_tango_heal') == false, 'no tango ticking')
    -- The two stock reads, driven: the shipped one is inside the function and
    -- is covered by the flip below; this is the sibling widening's own answer.
    assert(J.HasFieldRegenSource(bot) == false,
        'the sibling presence test now sees this bottle -- then this lever is '
        .. 'not the only way to see it and the finding is smaller')
end

tests['[frame] shipped FALSE -> armed TRUE, and the sibling alone does not'] = function()
    local J, bot, arm = frame(FX, SUBJ)
    assert(J.ShouldStayAndRegen(bot) == false, 'shipped: the promoted guard is '
        .. 'silent on a bot two seconds into a bottle sip')
    arm(true)
    assert(J.ShouldStayAndRegen(bot) == true, 'armed: it holds him')
    arm(false)
    -- Disjointness AT THE PINNED FRAME, not only in aggregate: the sibling
    -- lever cannot buy this frame, so an isolation wave that arms 'staysrc'
    -- alone would read a correct zero here.
    local J2, bot2, arm2 = frame(FX, SUBJ, 'staysrc')
    arm2(true)
    assert(J2.ShouldStayAndRegen(bot2) == false,
        "'staysrc' armed alone flips this frame -- the domains overlap after "
        .. 'all and the report claim has to change')
end

tests['[control] the two carriers above the HP ceiling do not move'] = function()
    for _, t in ipairs(OOB) do
        local J, bot, arm = frame(t.fx, t.subj)
        assert(near(J.GetHP(bot), t.hp, 0.0005),
            t.subj .. ' HP moved: ' .. J.GetHP(bot))
        assert(bot:HasModifier(MOD) == true,
            t.subj .. ' no longer carries the modifier -- this control would '
            .. 'then be vacuous rather than negative')
        assert(J.ShouldStayAndRegen(bot) == false, t.subj .. ' shipped')
        arm(true)
        assert(J.ShouldStayAndRegen(bot) == false, t.subj
            .. ' moved: the HP ceiling above the supply clause must still veto '
            .. 'a healthy bot carrying a bottle')
    end
end

-- --------------------------------------------------------------- the bid ---

local DESIRE = {
    BOT_MODE_DESIRE_NONE     = 0.0,
    BOT_MODE_DESIRE_VERYLOW  = 0.1,
    BOT_MODE_DESIRE_LOW      = 0.25,
    BOT_MODE_DESIRE_MODERATE = 0.5,
    BOT_MODE_DESIRE_HIGH     = 0.75,
    BOT_MODE_DESIRE_VERYHIGH = 0.9,
    BOT_MODE_DESIRE_ABSOLUTE = 1.0,
}

--- Install a fixture world for a bid-level drive. The mock resolves unknown
--- ALL_CAPS globals to sentinel integers, so a desire comparison without the
--- table above is a comparison of garbage (test_set.md §F). GetLaneFrontLocation
--- and the defend-ping stamp are DECLARED inputs (GH #61 / GH #91).
local function world(sArmed)
    local J, bot = rf.load(FX, SUBJ)
    for k, v in pairs(DESIRE) do _G[k] = v end
    GetPushLaneDesire = function() return 0 end     -- luacheck: ignore
    GetDefendLaneDesire = function() return 0 end   -- luacheck: ignore
    GetLaneFrontLocation = function() return Vector(0, 0, 0) end -- luacheck: ignore
    J.Utils['GameStates'] = J.Utils['GameStates'] or {}
    J.Utils['GameStates']['defendPings'] = { pingedTime = -1000 }
    J.IsSoakCandidate = function(sId) return sArmed ~= nil and sId == sArmed end
    return J, bot
end

local function bid(sArmed)
    world(sArmed)
    GetDesire, Think = nil, nil -- luacheck: ignore
    local ok, err = pcall(dofile, RETREAT)
    assert(ok, 'could not load ' .. RETREAT .. ': ' .. tostring(err))
    assert(type(GetDesire) == 'function', RETREAT .. ' exposes no GetDesire')
    local ok2, d = pcall(GetDesire)
    GetDesire, Think = nil, nil -- luacheck: ignore
    assert(ok2, RETREAT .. ' crashed on this frame: ' .. tostring(d))
    assert(type(d) == 'number', RETREAT .. ' returned a non-number')
    return d
end

tests['[bid] the walk leg: -0.4721 shipped -> 0 armed, and what that is NOT'] = function()
    -- Honest bound (2), as numbers. The shipped bid is NEGATIVE, so this mode
    -- was not asking to go home on this frame either way, and arming moves the
    -- bid UP to BOT_MODE_DESIRE_NONE via the guard's early return. What is
    -- measured here is that the guard now FIRES at a real call site on a real
    -- frame -- not a bot turned around. The leg where this defect actually
    -- sends a bot home is the item layer, unreachable on a fixture (GH #89).
    local d0 = bid(nil)
    assert(near(d0, SHIPPED_BID, 1e-9),
        'the shipped retreat bid on this frame moved: ' .. tostring(d0))
    local d1 = bid('staybottle')
    assert(near(d1, ARMED_BID, 1e-9),
        'armed retreat bid: ' .. tostring(d1) .. ', expected the guard early '
        .. 'return (BOT_MODE_DESIRE_NONE)')
    assert(d1 > d0, 'the sign of the change is the whole bound: arming raises '
        .. 'this bid, it does not remove a positive one')
end

tests['[bid] GH #89 still holds -- the item layer is why this is the weak leg'] = function()
    -- Asserted rather than footnoted, so the day the mode-state gap closes this
    -- file goes red and the claim gets upgraded instead of quietly standing.
    local _, bot = world(nil)
    assert(bot:GetActiveMode() ~= BOT_MODE_RETREAT,
        'a fixture now reports an active mode -- the tpscroll branch may be '
        .. 'drivable, which is where this lever would actually stop a trip')
end

-- ------------------------------------------------------------- wiring ------

tests['[wiring] the gate is real and the comment claims only what exists'] = function()
    local src = read_file(JMZ)
    local body = src:match('function J%.ShouldStayAndRegen%(.-\nend')
    assert(body, 'could not locate J.ShouldStayAndRegen')
    assert(body:find("J%.IsSoakCandidate%( 'staybottle' %)"),
        "the lever is not gated on 'staybottle'")
    assert(body:find(MOD, 1, true), 'the lever no longer reads ' .. MOD)
    -- One call site for the id, so the behaviour cannot ship through a second
    -- one that nobody gated.
    local _, n = src:gsub("IsSoakCandidate%( 'staybottle' %)", '')
    assert(n == 1, "'staybottle' appears in " .. n
        .. ' conditions in this file; expected exactly 1')
    -- [staybag 2026-09-05] Comments are stripped before this count. What the
    -- assertion means is "one ARMING POINT", and a raw text count does not say
    -- that: a sibling lever landing next door mentioned this id in its own
    -- explanation and this line went red on a tree with exactly one arming
    -- point -- the third time in one day that a count over raw source stood in
    -- for a structural claim in this family (GH #538 was the first, the
    -- STAY_NIDS floor the second).
    local repo = (src .. read_file(RETREAT)
        .. read_file('bots/ability_item_usage_generic.lua')):gsub('%-%-[^\n]*', '')
    local _, m = repo:gsub("'staybottle'", '')
    assert(m == 1, "'staybottle' appears " .. m
        .. ' times in CODE across the three files that decide the trip home; '
        .. 'expected 1')
end

return tests

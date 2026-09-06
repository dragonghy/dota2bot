-- [stayurn 2026-09-06, 协同组] Owner priority P2: a hurt bot that is in no
-- danger must NOT go home -- "血量低也尽量不要回程,买大药或其他补给". The PROMOTED
-- guard that says "stay and heal" is J.ShouldStayAndRegen (live in every turbo
-- game since the 'tphome' promote), and its supply read is missing the one
-- member of this family's vocabulary that does not live in the patient's own
-- inventory.
--
-- ⭐ THE REUSABLE JUDGEMENT, and it is the one this whole family of levers had
-- not yet run into:
-- A SUPPLY PREDICATE BUILT OUT OF SLOT READS CANNOT SEE A HEAL THAT ARRIVES FROM
-- SOMEONE ELSE'S INVENTORY, AND NO WIDENING OF IT EVER WILL.
-- Four levers now widen this clause and all four read slots -- shipped
-- `bHasFlask` asks J.IsItemAvailable (slots 0-5), 'staysrc' asks
-- J.HasFieldRegenSource (`for i = 0, 5`), 'staybag' and 'bagsalve' extend the
-- same question to the backpack. An urn heal is CAST BY AN ALLY: the item is in
-- one hero's inventory and the 400 health lands on another's. Measured, not
-- argued: of the 2 corpus frames in this lever's domain, ONE holds neither an
-- urn nor a spirit vessel in any of its nine slots (`flip_no_urn_item` below).
-- The modifier is the only read that reaches it.
--
-- ⭐⭐ AND THE TREE ALREADY KNEW -- in three separate places, parsed below rather
-- than restated. `modifier_item_urn_heal` appears as "this hero is healing, do
-- not send it home" in: the tpscroll '撤退:3' branch (ability_item_usage_generic
-- ~5663, the SAME branch 'staybottle' cited, where it sits between
-- flask_healing and bottle_regeneration); mode_roam_generic's
-- ShouldWaitInBaseToHeal gate (~1599); and FunLib/aba_buff.lua's
-- `hero_is_healing` list, which is exactly the five (flask_healing,
-- clarity_potion, item_urn_heal, item_spirit_vessel_heal,
-- bottle_regeneration). The PROMOTED guard names two of those five as shipped
-- and a third only once 'staybottle' is armed. Same shape as 'stayattr',
-- 'staysrc' and 'staybottle' before it: the question was answered correctly
-- elsewhere in the tree and this shipped line was never brought along.
--
-- ⭐⭐⭐ WHY THIS LEVER AND NOT THE ONE NEXT TO IT. The obvious sibling move --
-- adding item_urn_of_shadows to J.HasFieldRegenSource's vocabulary -- was priced
-- in the same work unit and REFUSED: 4 of the 8 urn CARRIERS among the vetoed
-- frames satisfy the self-cast domain, but counting a carried urn as field
-- sustain is only honest once the bot will actually press it, and today that
-- needs 'urnself' armed at a DIFFERENT site -- the GH #542 shape, where every
-- site reads clean and no single-arm wave can buy the behaviour. An urn heal
-- ALREADY TICKING needs no cast path at all: the button has been pressed, by
-- someone else. `SRC_NAMES_URN_ITEM` below pins that refusal as a parsed zero,
-- so the day someone lands the carrier widening this file goes red and the
-- pair-dependency argument gets re-read instead of quietly lapsing.
--
-- WHAT IS ASSERTED. Not gate plumbing. The shipped function is driven on real
-- frames with every candidate disarmed and then with exactly 'stayurn' armed,
-- and the CAUSE of the changed answer is read off the frame's own modifier list
-- and item slots.
--
-- ⚠️ HONEST BOUNDS, all four stated up front:
-- (1) THE DOMAIN IS TWO FRAMES, and that is a measurement, not an apology: 4 of
--     1012 live hero frames carry the modifier, all four are INSIDE the HP band,
--     one is stopped by the untouched 1200 ring and one already passes the
--     shipped supply read (it holds a salve). The carrier rows carry their own
--     stop reason, so "the corpus has no urn heals" can never read the same as
--     "the corpus has urn heals this function rejects three clauses earlier".
-- (2) THE SPIRIT VESSEL IS DELIBERATELY NOT IN THIS LEVER. It is the urn's own
--     upgrade and the fifth member of that word list, and 0 of 1012 live frames
--     carry its heal modifier -- so including it would widen the domain by an
--     unpriced amount. `vessel_carriers` measures that zero and
--     `STAY_READS_VESSEL` pins the exclusion; it is the next question, not this
--     lever's.
-- (3) THE MEASURED FLIP SET IS THE GOLD-POOR SUPERSET of the live one. A fixture
--     cannot read gold (GH #495), so every frame is scored as if the bot had
--     less than 90; in a real game the frames with >= 90 gold were never vetoed
--     by this clause at all. The direction is fixed; the size is not claimed.
-- (4) A frame is one instant and a heal has a tail. This says the decision at t
--     is wrong; it does not claim the remaining tick is always enough to stay
--     for -- that magnitude question belongs to 'fieldsip' on the gated family,
--     and the urn's 400 health is the largest single amount any member of this
--     vocabulary delivers, so it is the member least exposed to it.

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')
local cs = require('corpus_scale')

local SWEEP = 'lua5.1 tests/_stayurn_sweep.lua 2>/dev/null'
local JMZ = 'bots/FunLib/jmz_func.lua'
local RETREAT = 'bots/mode_retreat_generic.lua'
local ITEMFILE = 'bots/ability_item_usage_generic.lua'
local MOD = 'modifier_item_urn_heal'
local VESSEL = 'modifier_item_spirit_vessel_heal'

-- The pinned frame, and it is pinned for the STRUCTURAL reason rather than for
-- being first: jakiro at 61.8% HP with 626 health missing, an urn heal ticking
-- on him, and NOT ONE of his nine slots holding an urn or a spirit vessel. An
-- ally pressed it.
local FX = 'tests/fixtures/f_260820_163429_es_blink_init_621.lua'
local SUBJ = 'npc_dota_hero_jakiro'
-- The other domain frame: same modifier, but this one is its own carrier, so it
-- is the control that keeps "the modifier read" from being credited only where a
-- slot read is impossible.
local FX2 = 'tests/fixtures/f_212636_tide_ancient.lua'
local SUBJ2 = 'npc_dota_hero_zuus'
-- The two carriers the function rejects BEFORE the supply clause -- the negative
-- controls that keep this lever from being credited with the earlier clauses'
-- work.
local OOD = {
    { fx = 'tests/fixtures/f_260819_223607_drow_defend_bail.lua',
      subj = 'npc_dota_hero_lich', hp = 0.2800, why = 'the 1200 ring' },
    { fx = 'tests/fixtures/f_260902_154755_cm_wandbleed_residue.lua',
      subj = 'npc_dota_hero_bristleback', hp = 0.4349,
      why = 'the shipped supply read already passes it' },
}

-- Measured, to 17 digits, on the pinned frame.
local SHIPPED_BID = 0.20598228813998432
local ARMED_BID = 0.0

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
        local ff, fh, fp, fm, fc = line:match('^F (%S+) (%S+) ([%d%.]+) (%d+) (%d)$')
        if ff ~= nil then
            m.flips[#m.flips + 1] = { fixture = ff, hero = fh, hp = tonumber(fp),
                missing = tonumber(fm), carries = (fc == '1') }
        end
        local bf, bh, bp, bs = line:match('^B (%S+) (%S+) ([%d%.]+) (%S+)$')
        if bf ~= nil then
            m.carriers[#m.carriers + 1] = { fixture = bf, hero = bh,
                hp = tonumber(bp), stop = bs }
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
    J.IsSoakCandidate = function(s) return armed and s == (sId or 'stayurn') end
    return J, bot, function(b) armed = b end
end

--- Every item name in the nine slots, as one string. Used for the claim that
--- carries the whole finding: the pinned frame's patient owns no urn.
local function inventory(bot)
    local names = {}
    for i = 0, 8 do
        local it = bot:GetItemInSlot(i)
        names[#names + 1] = (it ~= nil) and it:GetName() or '-'
    end
    return table.concat(names, ' ')
end

-- --------------------------------------------------- the tree, as source ---

tests['[source] the lever is where this file says it is'] = function()
    assert(M.done, 'the sweep subprocess did not finish (no DONE line) -- every '
        .. 'number below would be a silent zero')
    assert(M.g.STAY == 1, 'the sweep could not slice J.ShouldStayAndRegen out of '
        .. JMZ)
    assert(M.g.SRC == 1, 'the sweep could not slice J.HasFieldRegenSource out of '
        .. JMZ)
    assert(M.g.STAY_SOAKID == 1, "the 'stayurn' id is no longer in "
        .. 'J.ShouldStayAndRegen (comments are stripped before this is read)')
    assert(M.g.STAY_READS_MOD == 1, 'the lever no longer reads ' .. MOD)
end

tests['[source] one id per condition -- the pullcad trap, not the id count'] = function()
    -- A CONJUNCTION of ids in one condition freezes FALSE the day either is
    -- promoted, while check_armed_wiring.py still calls the site WIRED. Five
    -- INDEPENDENT ids in one function is not that shape; a single condition
    -- naming two of them would be.
    assert(M.g.STAY_IDS_MAX_PER_COND == 1, 'some single condition in '
        .. 'J.ShouldStayAndRegen names ' .. tostring(M.g.STAY_IDS_MAX_PER_COND)
        .. ' soak ids -- that is the pullcad trap')
    -- A FLOOR, never an equality. Three separate rounds turned an equality here
    -- red by landing a lever that has no trap on it (test_stayattr_global_ult
    -- :155 wrote it down the first time, test_staybottle_inflight_regen:170 the
    -- second). The floor still refuses a deletion that makes the function
    -- id-free.
    assert(M.g.STAY_NIDS >= 4, 'J.ShouldStayAndRegen names '
        .. tostring(M.g.STAY_NIDS) .. ' soak ids; expected at least 4')
end

tests['[source] appended, never inserted -- three siblings and the gold line'] = function()
    -- With this id un-armed all three sibling widenings must evaluate
    -- byte-identically, which is only true while this block sits AFTER every one
    -- of them; and it must sit BEFORE the gold fallback, or the veto it is meant
    -- to remove has already fired. Positions are read inside the comment-stripped
    -- function body, so prose naming any id cannot move them.
    assert(M.g.STAY_ORDER_OK == 1,
        "the 'stayurn' block no longer sits after 'staysrc'/'staybottle'/"
        .. "'staybag' and before the GetGold fallback")
end

tests['[source] the shipped read already accepts TWO in-flight modifiers'] = function()
    -- This is the whole argument for the fourth, so it is parsed, not asserted
    -- from memory: the shipped supply expression names two HasModifier reads and
    -- neither of them is the urn's.
    assert(M.g.STAY_SHIPPED_MODS == 2, 'the shipped supply read names '
        .. tostring(M.g.STAY_SHIPPED_MODS) .. ' in-flight modifiers; expected 2 '
        .. '(flask_healing, tango_heal). If this grew, the finding changed.')
    assert(M.g.STAY_SHIPPED_HAS_URN_MOD == 0,
        'the shipped supply read now names the urn modifier itself -- this lever '
        .. 'would be a no-op and must be re-read, not re-run')
end

tests['[source] the tree already knew, in three other places'] = function()
    -- ⛔ COUNTED, NOT FOUND. This was a presence flag until the mutation stand's
    -- anchor check answered `occurs 5 time(s)`: the item layer refuses a
    -- heal-or-go-home action on this modifier at FIVE sites (the tpscroll
    -- '撤退:3' branch among them, and two of the five are byte-identical for
    -- five lines). A presence flag cannot go red when one of them is deleted --
    -- the M6 mutant did exactly that and SURVIVED. Five live refusals in the
    -- item layer, zero in the PROMOTED guard, is the finding.
    assert(M.g.ITEM_URN_MOD_SITES == 5, ITEMFILE .. ' refuses on ' .. MOD
        .. ' at ' .. tostring(M.g.ITEM_URN_MOD_SITES) .. ' sites; expected 5. '
        .. 'If the item layer stopped treating an urn heal as "this hero is '
        .. 'healing", condition (c) for this lever has to be re-argued, not '
        .. 're-baselined')
    assert(M.g.TP3_LISTS_URN_MOD == 1, ITEMFILE .. " no longer refuses a home TP "
        .. 'while ' .. MOD .. ' is up -- the strongest corroborating site is gone')
    assert(M.g.ROAM_LISTS_URN_MOD == 1, 'bots/mode_roam_generic.lua no longer '
        .. 'names ' .. MOD .. ' in its wait-in-base gate')
    assert(M.g.BUFF_HEALING_HAS_URN == 1,
        "FunLib/aba_buff.lua's hero_is_healing list no longer contains " .. MOD)
    assert(M.g.BUFF_HEALING_N == 5, 'the hero_is_healing list has '
        .. tostring(M.g.BUFF_HEALING_N) .. ' members; expected 5. The finding is '
        .. '"the promoted guard knows 2 of 5" -- if the list moved, re-count it')
end

tests['[source] the carrier widening this round REFUSED, pinned as a zero'] = function()
    -- The GH #542 argument in the lever's comment is only true while
    -- J.HasFieldRegenSource does not name the urn ITEM. If a later round lands
    -- that widening, this goes red and the pair-dependency claim is re-read
    -- rather than quietly lapsing.
    assert(M.g.SRC_NAMES_URN_ITEM == 0,
        'J.HasFieldRegenSource now names item_urn_of_shadows -- the "no cast '
        .. 'path, so this lever is standalone where the carrier widening would '
        .. 'not be" argument has to be re-read')
    -- Honest bound (2), as a parsed fact rather than a promise.
    assert(M.g.STAY_READS_VESSEL == 0,
        'the lever now also reads ' .. VESSEL .. ' -- honest bound (2) said that '
        .. 'was 0 corpus frames of unpriced widening; re-derive it, do not edit '
        .. 'this line')
end

tests['[source] the constants this lever does NOT touch'] = function()
    assert(M.g.STAY_HP_LO == 0.18 and M.g.STAY_HP_HI == 0.75,
        'the HP band moved: ' .. tostring(M.g.STAY_HP_LO) .. '..'
        .. tostring(M.g.STAY_HP_HI) .. ' -- the controls below are scored '
        .. 'against it')
    assert(M.g.STAY_RING == 1200, 'the untouched proximity ring is '
        .. tostring(M.g.STAY_RING) .. ', expected 1200')
    assert(M.g.STAY_CHASE_WINDOW == 3, 'the chase window is '
        .. tostring(M.g.STAY_CHASE_WINDOW) .. ', expected 3.0')
end

-- ------------------------------------------------------- the domain price ---

tests['[domain] the corpus, and what reaches the supply clause'] = function()
    cs.corpus(C('fixtures'), 'fixture corpus')
    cs.ratchet(C('live'), 1012, 'live hero frames')
    assert(C('turbo') == C('live'),
        'some live frame is not turbo, which the first line of the function '
        .. 'would have vetoed before anything this file measures')
    assert(C('raises') == 0, C('raises') .. ' frames raised inside the drive')
    assert(C('supply_tested') == 125, 'frames reaching the supply clause: '
        .. C('supply_tested') .. ' (both sibling levers measured 125 on the same '
        .. 'corpus through their own prefix walks)')
    assert(C('blocked_supply') == 112, 'frames the supply clause vetoes: '
        .. C('blocked_supply'))
    assert(C('blocked_with_mod') + C('blocked_no_mod') == C('blocked_supply'),
        'the two-bin split of the vetoed frames does not sum -- counted, not '
        .. 'subtracted, so this is an arithmetic invariant')
end

tests['[domain] two frames, and where the other two carriers stop'] = function()
    -- The ANTI-VACUUM column, and it is a row per carrier with its own stop
    -- reason rather than a single count: "the corpus has no urn heals" and "the
    -- corpus has urn heals rejected three clauses earlier" must not read alike.
    assert(C('mod_carriers') == 4, 'live frames carrying ' .. MOD .. ': '
        .. C('mod_carriers'))
    assert(#M.carriers == 4, 'carrier rows emitted: ' .. #M.carriers)
    local seen = {}
    for _, r in ipairs(M.carriers) do seen[r.stop] = (seen[r.stop] or 0) + 1 end
    assert(C('mod_out_of_band') == 0 and (seen.band or 0) == 0,
        'a carrier is now outside the 0.18-0.75 band: ' .. C('mod_out_of_band'))
    assert(C('mod_chase_stopped') == 0 and (seen.chase or 0) == 0,
        C('mod_chase_stopped') .. ' carriers are stopped by the chase clause')
    assert(C('mod_ring_stopped') == 1 and (seen.ring or 0) == 1,
        'carriers stopped by the untouched 1200 ring: ' .. C('mod_ring_stopped'))
    assert(C('mod_passes_shipped') == 1 and (seen.shipped_ok or 0) == 1,
        'carriers the shipped supply read already passes: '
        .. C('mod_passes_shipped'))
    assert(C('blocked_with_mod') == 2 and (seen.domain or 0) == 2,
        'frames inside the domain: ' .. C('blocked_with_mod'))
    assert(C('mod_out_of_band') + C('mod_chase_stopped') + C('mod_ring_stopped')
        + C('mod_passes_shipped') + C('blocked_with_mod') == C('mod_carriers'),
        'the carrier buckets do not partition -- each is counted, not '
        .. 'subtracted, so this is an arithmetic invariant')
end

tests['[domain] one of the two frames owns no urn -- the structural column'] = function()
    -- The claim no slot read can ever satisfy, as a number. If this ever reads
    -- 0, this lever is reachable by widening J.HasFieldRegenSource after all and
    -- the argument for a separate id has to be re-made.
    assert(C('flip_no_urn_item') == 1, C('flip_no_urn_item') .. ' of the '
        .. C('flips') .. ' domain frames hold neither an urn nor a spirit vessel '
        .. 'in any of their nine slots; expected 1')
    assert(#M.flips == 2, 'flip rows emitted: ' .. #M.flips)
    local nCarry, nNot = 0, 0
    for _, r in ipairs(M.flips) do
        if r.carries then nCarry = nCarry + 1 else nNot = nNot + 1 end
    end
    assert(nCarry == 1 and nNot == 1, 'the domain split by carriage is '
        .. nCarry .. '/' .. nNot .. '; expected one of each -- the lever must be '
        .. 'credited on both, or it is only an alias for a slot read')
end

tests['[domain] the spirit vessel is absent from the corpus, measured'] = function()
    assert(C('vessel_carriers') == 0, C('vessel_carriers') .. ' live frames '
        .. 'carry ' .. VESSEL .. '. Honest bound (2) -- the exclusion is unpriced '
        .. 'rather than wrong -- holds only while this is 0')
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
    assert(C('ship_true') == 13 and C('arm_true') == 15,
        'shipped/armed TRUE totals moved: ' .. C('ship_true') .. '/'
        .. C('arm_true'))
end

tests['[domain] the direction counter is proved to COUNT, not only to read 0'] = function()
    -- The M14 lesson of the 'staytower' round: a counter whose content is all
    -- zeros cannot distinguish "the direction holds" from "the tally never ran",
    -- and deleting its bump leaves the manifest byte-identical. Both directions
    -- go through one tally() and it is called again with the legs swapped, so
    -- the branch that must read 0 here is the branch that must report the whole
    -- domain there.
    assert(C('flip_true_to_false') == 0, C('flip_true_to_false')
        .. ' frames turned TRUE -> FALSE; widening bHasRegen can only REMOVE '
        .. 'vetoes, so this is a contradiction, not a regression')
    assert(C('flip_true_to_false_swapped') == C('flips'),
        'the swapped call reports ' .. C('flip_true_to_false_swapped')
        .. ' where the real call reports ' .. C('flips') .. ' -- the branch that '
        .. 'must read 0 above is therefore NOT proved to be able to count')
    assert(C('flips_swapped') == C('flip_true_to_false'),
        'the swapped legs do not mirror: ' .. C('flips_swapped') .. ' vs '
        .. C('flip_true_to_false'))
end

tests['[domain] the arming is exactly one id wide'] = function()
    assert(C('arm_leak') == 0, "the sweep's armed stub also answered TRUE for a "
        .. 'sibling widening on ' .. C('arm_leak') .. ' frames -- the flips would '
        .. 'not be attributable to this lever')
end

tests['[domain] the gold term is unmeasurable, and that is measured'] = function()
    assert(C('gold_nonzero') == 0, C('gold_nonzero') .. ' frames carry real '
        .. 'gold. Honest bound (3) -- the gold-poor superset -- holds only while '
        .. 'this is 0; re-derive the bound, do not edit this line')
    assert(C('gold_zero') == C('live'), 'gold buckets do not partition')
end

tests['[domain] disjoint from the sibling -- the GH #532 question'] = function()
    -- GH #532: two levers on this same function move owner P2's pinned frame
    -- only as a PAIR, so a single-arm isolation wave reads a correct zero there.
    -- That is a property of those clauses, not of this function, and it is
    -- measured here rather than assumed either way.
    assert(C('flips_staysrc') == 44, "'staysrc' alone flips "
        .. C('flips_staysrc') .. ' frames; the sibling files measured 44')
    assert(C('flips_both_levers') == 0, C('flips_both_levers')
        .. ' frames are flipped by BOTH levers -- the domains are no longer '
        .. 'disjoint and the wave design in the report has to change')
end

-- ------------------------------------------------------------- the frame ---

tests['[frame] jakiro is hurt, unchased, and being healed by someone else'] = function()
    local J, bot = frame(FX, SUBJ)
    assert(near(J.GetHP(bot), 0.6181, 0.0005), 'HP moved: ' .. J.GetHP(bot))
    assert(bot:HasModifier(MOD) == true, 'the urn heal is not on this frame any '
        .. 'more -- the pin is gone, not the finding')
    assert(bot:OriginalGetMaxHealth() - bot:OriginalGetHealth() > 450,
        'the missing health fell below the amount an urn delivers')
    assert(bot:WasRecentlyDamagedByAnyHero(3.0) == false,
        'a hero touched him -- the chase clause would veto before the supply '
        .. 'clause is ever reached')
    assert(#J.GetNearbyHeroes(bot, 1200, true, BOT_MODE_NONE) == 0,
        'someone is inside the 1200 ring')
end

tests['[frame] and the urn is in NOBODY\'S slot that this bot can read'] = function()
    local _, bot = frame(FX, SUBJ)
    local sInv = inventory(bot)
    assert(not sInv:find('item_urn_of_shadows', 1, true),
        'the patient now carries the urn himself: ' .. sInv .. ' -- this frame '
        .. 'was pinned BECAUSE the item is in an ally inventory')
    assert(not sInv:find('item_spirit_vessel', 1, true),
        'a spirit vessel appeared: ' .. sInv)
end

tests['[frame] every slot read in the family calls him empty-handed'] = function()
    local J, bot = frame(FX, SUBJ)
    local sInv = inventory(bot)
    assert(not sInv:find('item_flask', 1, true), 'a salve appeared: ' .. sInv)
    assert(not sInv:find('item_tango', 1, true), 'a tango appeared: ' .. sInv)
    assert(bot:HasModifier('modifier_flask_healing') == false, 'no salve ticking')
    assert(bot:HasModifier('modifier_tango_heal') == false, 'no tango ticking')
    assert(bot:HasModifier('modifier_bottle_regeneration') == false,
        'a bottle sip is in flight -- then the sibling lever also sees this '
        .. 'frame and the domain claim has to change')
    -- The widest slot read this family has, driven: it still answers FALSE.
    assert(J.HasFieldRegenSource(bot) == false,
        'the sibling presence test now sees something on this frame -- then this '
        .. 'lever is not the only way to see it and the finding is smaller')
end

tests['[frame] shipped FALSE -> armed TRUE, and the sibling alone does not'] = function()
    local J, bot, arm = frame(FX, SUBJ)
    assert(J.ShouldStayAndRegen(bot) == false, 'shipped: the promoted guard is '
        .. 'silent on a bot with 400 health arriving from an ally urn')
    arm(true)
    assert(J.ShouldStayAndRegen(bot) == true, 'armed: it holds him')
    arm(false)
    -- Disjointness AT THE PINNED FRAME, not only in aggregate: an isolation wave
    -- that arms 'staysrc' alone must read a correct zero here.
    local J2, bot2, arm2 = frame(FX, SUBJ, 'staysrc')
    arm2(true)
    assert(J2.ShouldStayAndRegen(bot2) == false,
        "'staysrc' armed alone flips this frame -- the domains overlap after all "
        .. 'and the report claim has to change')
end

tests['[frame] the other domain frame IS its own carrier, and also flips'] = function()
    -- The control against the opposite over-claim: this lever is not only about
    -- ally-cast urns. zuus holds the urn he is being healed by, and the whole
    -- slot-reading family still calls him empty-handed, because none of them
    -- reads the urn as a regen source at all.
    local J, bot, arm = frame(FX2, SUBJ2)
    assert(near(J.GetHP(bot), 0.6581, 0.0005), 'HP moved: ' .. J.GetHP(bot))
    assert(bot:HasModifier(MOD) == true, 'the urn heal left this frame')
    assert(inventory(bot):find('item_urn_of_shadows', 1, true),
        'zuus no longer carries the urn -- this control is meant to be the '
        .. 'CARRIER half of the domain')
    assert(J.HasFieldRegenSource(bot) == false,
        'the slot read now sees this frame')
    assert(J.ShouldStayAndRegen(bot) == false, 'shipped')
    arm(true)
    assert(J.ShouldStayAndRegen(bot) == true, 'armed')
end

tests['[control] the two carriers stopped by earlier clauses do not move'] = function()
    for _, t in ipairs(OOD) do
        local J, bot, arm = frame(t.fx, t.subj)
        assert(near(J.GetHP(bot), t.hp, 0.0005),
            t.subj .. ' HP moved: ' .. J.GetHP(bot))
        assert(bot:HasModifier(MOD) == true, t.subj .. ' no longer carries the '
            .. 'modifier -- this control would then be vacuous rather than '
            .. 'negative')
        local before = J.ShouldStayAndRegen(bot)
        arm(true)
        assert(J.ShouldStayAndRegen(bot) == before, t.subj .. ' moved, and '
            .. t.why .. ' is supposed to decide it, not this lever')
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

tests['[bid] a POSITIVE retreat bid is removed, not merely a negative one'] = function()
    -- Where this lever is stronger than its sibling, and it is a sign rather
    -- than a size: 'staybottle' could only show its guard firing on a frame
    -- whose shipped retreat bid was already NEGATIVE (-0.4721), so arming moved
    -- the bid UP to NONE and no trip was actually cancelled. Here the shipped
    -- bid is POSITIVE -- mode_retreat_generic is asking to leave -- and arming
    -- takes it to BOT_MODE_DESIRE_NONE through the guard's early return. That is
    -- a trip suppressed at a real call site on a real frame.
    local d0 = bid(nil)
    assert(near(d0, SHIPPED_BID, 1e-9),
        'the shipped retreat bid on this frame moved: ' .. tostring(d0))
    assert(d0 > 0, 'the shipped bid is no longer positive (' .. tostring(d0)
        .. ') -- the claim above is about the SIGN, so re-read it')
    local d1 = bid('stayurn')
    assert(near(d1, ARMED_BID, 1e-9),
        'armed retreat bid: ' .. tostring(d1) .. ', expected the guard early '
        .. 'return (BOT_MODE_DESIRE_NONE)')
    assert(d1 < d0, 'arming must LOWER this bid; it moved ' .. tostring(d0)
        .. ' -> ' .. tostring(d1))
end

tests['[bid] GH #89 still holds -- the item layer is the other, unreachable leg'] = function()
    -- Asserted rather than footnoted, so the day the mode-state gap closes this
    -- file goes red and the claim gets upgraded instead of quietly standing.
    local _, bot = world(nil)
    assert(bot:GetActiveMode() ~= BOT_MODE_RETREAT,
        'a fixture now reports an active mode -- the tpscroll branch may be '
        .. 'drivable, which is the other leg where this defect sends a bot home')
end

-- ------------------------------------------------------------- wiring ------

tests['[wiring] the gate is real and the comment claims only what exists'] = function()
    local src = read_file(JMZ)
    local body = src:match('function J%.ShouldStayAndRegen%(.-\nend')
    assert(body, 'could not locate J.ShouldStayAndRegen')
    assert(body:find("J%.IsSoakCandidate%( 'stayurn' %)"),
        "the lever is not gated on 'stayurn'")
    assert(body:find(MOD, 1, true), 'the lever no longer reads ' .. MOD)
    -- One ARMING POINT, counted over CODE. A raw text count does not say that:
    -- a sibling lever landing next door mentions this id in its own explanation
    -- and would turn a raw count red on a tree with exactly one arming point
    -- (GH #538 and the two recurrences after it).
    local repo = (src .. read_file(RETREAT) .. read_file(ITEMFILE))
        :gsub('%-%-[^\n]*', '')
    local _, m = repo:gsub("'stayurn'", '')
    assert(m == 1, "'stayurn' appears " .. m
        .. ' times in CODE across the three files that decide the trip home; '
        .. 'expected 1')
end

return tests

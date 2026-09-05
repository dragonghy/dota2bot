-- [staybag 2026-09-05, 协同组] Owner priority P2: a hurt bot in no danger must
-- NOT go home -- "血量低也尽量不要回程,买大药或其他补给". The PROMOTED guard that
-- says "stay and heal" is J.ShouldStayAndRegen (live in every turbo game since
-- the 'tphome' promote), and every stock read on that path stops at slot 5.
--
-- ⭐ THE REUSABLE JUDGEMENT, and it is about GATES, not about salves.
-- THE `pullcad` TRAP HAS A SECOND FORM THAT NO GREP FINDS: two ids on one PATH.
-- The known form is two ids in one condition (`IsSoakCandidate('X') and
-- IsSoakCandidate('Y')`), which freezes FALSE the day either is promoted and
-- which reviewers and check_armed_wiring.py look for. The form measured here is
-- the same conjunction spread over a CALL: reaching a backpacked salve from
-- J.ShouldStayAndRegen requires 'staysrc' (to get J.HasFieldRegenSource called
-- at all) AND 'bagsalve' (to make its backpack block run). Each SITE names
-- exactly one id, every reviewer's rule reads clean, the nesting census pins the
-- pair as SAFE -- and it is safe, in the sense that census asks about. It is
-- simply not BUYABLE: an isolation wave that arms one id at a time reads a
-- correct zero for both. ⇒ "additive-and-safe" and "single-arm-visible" are two
-- different properties, and only the second decides whether a wave can measure
-- the behaviour.
--
-- Measured, not argued (tests/_staybag_sweep.lua, 1012 live hero frames):
--   'staysrc' alone flips 44 frames. 'bagsalve' alone flips 0 -- its gate is
--   never reached. The PAIR flips 46. The 2 frames the pair adds are exactly the
--   2 frames this standalone one-id lever buys (`pair_gain` == `flips` == 2,
--   `pair_gain_not_flips` == 0), and the overlap with 'staysrc' is 0.
--
-- ⭐⭐ WHY EXACTLY ONE ITEM WIDE. `TrySwapInvItemForFlask()`
-- (mode_team_roam_generic.lua:1889) is SHIPPED and UNGATED and swaps a
-- backpacked flask into a main slot; there is no such swapper for tango /
-- tango_single / faerie_fire / bottle, so counting those would hold a bot next
-- to something it cannot drink. Both halves are parsed off the tree below (the
-- swapper's existence, its zero soak ids, and the absence of the other three),
-- not restated from the sibling's comment.
--
-- WHAT IS ASSERTED. Not gate plumbing. The shipped function is driven on real
-- frames with every candidate disarmed and then with exactly 'staybag' armed,
-- and the CAUSE of the changed answer is read off the frame's own item slots.
--
-- ⚠️ HONEST BOUNDS, all four stated up front:
-- (1) THE DOMAIN IS TWO FRAMES, as a measurement rather than an apology: 15 of
--     1012 live hero frames carry a backpacked salve, 11 are outside the
--     function's own 0.18-0.75 HP band, and 2 of the remaining 4 are vetoed by
--     the chase clause or the 1200 ring BEFORE the supply clause is reached.
--     Those 2 are negative controls below, not losses. The anti-vacuum columns
--     (`bag_carriers` / `bag_out_of_band`) keep "the corpus has no backpacked
--     salves" from ever reading the same as "the band rejects them".
-- (2) WHAT THE BID CASE MEASURES IS THE VETO FIRING, NOT A TRIP PREVENTED. On
--     the pinned frame mode_retreat_generic already bids NEGATIVE (-0.0615), so
--     arming moves the bid to BOT_MODE_DESIRE_NONE (0) -- numerically UP, and in
--     neither case is this mode asking to go home. The leg where this defect
--     actually sends a bot home is the item layer (ability_item_usage_generic
--     :5576), structurally unreachable on a fixture (GH #89: GetActiveMode is
--     bot-VM state absent from every .dem). Asserted as numbers below rather
--     than footnoted.
-- (3) THE MEASURED FLIP SET IS THE GOLD-POOR SUPERSET of the live one. A fixture
--     cannot read gold (GH #495), so every frame is scored as if the bot had
--     less than 90; in a real game the frames with >= 90 gold were never vetoed
--     by this clause at all. The direction is fixed; the size is not claimed.
-- (4) THE SWAP DOES NOT ALWAYS WIN. The replay desk's residual STUCK rate is
--     11.0% of 591 field purchases (205 games, 2026-08-23; its BOT_MODE_WARD
--     clause is the standing suspect), so this can hold a bot next to a salve it
--     will not drink for as long as that block lasts. Bounded by clauses this
--     change does not touch: the 0.18 HP floor where the genuine escape retreat
--     takes over, the 1200 ring, and the chase clause.

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')
local cs = require('corpus_scale')

local SWEEP = 'lua5.1 tests/_staybag_sweep.lua 2>/dev/null'
local JMZ   = 'bots/FunLib/jmz_func.lua'
local RETREAT = 'bots/mode_retreat_generic.lua'
local ITEMS = 'bots/ability_item_usage_generic.lua'

-- The pinned frame: spirit_breaker 499/1378 = 36.2% HP, a salve in backpack slot
-- 6 with all six main slots full of non-consumables, nearest enemy 1,307 units
-- off (outside the 1200 ring) and nobody having touched him for 3 seconds.
local FX    = 'tests/fixtures/f_260822_182012_sb_backpack_rescue_372.lua'
local SUBJ  = 'npc_dota_hero_spirit_breaker'
-- The second frame in the domain, pinned so the finding is not one fixture wide.
local FX2   = 'tests/fixtures/f_260822_063559_slardar_tp_forward.lua'
local SUBJ2 = 'npc_dota_hero_lion'
-- IN-BAND carriers that an EARLIER clause vetoes. These are the controls that
-- keep this lever from being credited with work the chase clause and the 1200
-- ring do: both carry a backpacked salve, both are inside the HP band, and
-- arming must not move either.
local BLOCKED = {
    { fx = 'tests/fixtures/f_225947_wk_trade_kite.lua',
      subj = 'npc_dota_hero_sniper', hp = 0.7478, why = 'ring' },
    { fx = 'tests/fixtures/f_260820_103216_cm_es_aftershock.lua',
      subj = 'npc_dota_hero_crystal_maiden', hp = 0.2631, why = 'chase' },
}
-- OUT-OF-BAND carriers, one on each side of the band -- so "the HP band still
-- decides" is a negative control at both ends, not just at the ceiling.
local OOB = {
    { fx = 'tests/fixtures/f_181544_storm_escape_tp.lua',
      subj = 'npc_dota_hero_jakiro', hp = 1.0 },
    { fx = 'tests/fixtures/f_260820_043524_wd_defend_alone.lua',
      subj = 'npc_dota_hero_crystal_maiden', hp = 0.0490 },
}

local SHIPPED_BID = -0.061504606043553
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
        local ff, fh, fp = line:match('^F (%S+) (%S+) ([%d%.]+)$')
        if ff ~= nil then
            m.flips[#m.flips + 1] = { fixture = ff, hero = fh, hp = tonumber(fp) }
        end
        local bf, bh, bp, bb, bm =
            line:match('^B (%S+) (%S+) ([%d%.]+) (%d) (%d)$')
        if bf ~= nil then
            m.carriers[#m.carriers + 1] = { fixture = bf, hero = bh,
                hp = tonumber(bp), in_band = (bb == '1'),
                main_src = (bm == '1') }
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
    J.IsSoakCandidate = function(s) return armed and s == (sId or 'staybag') end
    return J, bot, function(b) armed = b end
end

--- Load a frame with an arbitrary SET of ids armed -- the two-id path.
local function frame_set(path, subject, ids)
    local J, bot = rf.load(path, subject)
    J.IsSoakCandidate = function(s) return ids[s] == true end
    return J, bot
end

-- --------------------------------------------------- the tree, as source ---

tests['[source] the lever is where this file says it is'] = function()
    assert(M.done, 'the sweep subprocess did not finish (no DONE line) -- every '
        .. 'number below would be a silent zero')
    assert(M.g.STAY == 1, 'the sweep could not slice J.ShouldStayAndRegen out of '
        .. JMZ)
    assert(M.g.SRC == 1, 'the sweep could not slice J.HasFieldRegenSource out of '
        .. JMZ)
    assert(M.g.AVAIL == 1, 'the sweep could not slice J.IsItemAvailable out of '
        .. JMZ)
    assert(M.g.STAY_SOAKID == 1, "the 'staybag' id is no longer in "
        .. 'J.ShouldStayAndRegen (comments are stripped before this is read)')
    -- Every [source] fact below is a claim about CODE, and this lever ships with
    -- a ~50-line comment naming J.IsSoakCandidate, both sibling ids, the item
    -- name and the slot numbers while explaining them. So the stripping is
    -- asserted DIRECTLY, not inferred from some count landing on its expected
    -- value: the exact `STAY_NIDS == 4` used to be the only thing catching the
    -- "stop stripping" mutant, and relaxing that total to a floor (correctly --
    -- an id total is a ratchet trap, not an invariant) turned that mutant from
    -- CAUGHT to SURVIVED with nothing else changed.
    assert(M.g.STAY_STRIPPED == 1 and M.g.SRC_STRIPPED == 1,
        'the sweep is parsing UNSTRIPPED source (comment markers survive in the '
        .. 'sliced block) -- every [source] assertion in this file could then be '
        .. 'satisfied by prose')
end

tests['[source] every shipped stock read on this path stops at slot 5'] = function()
    -- The defect itself, parsed rather than described. Both readers the promoted
    -- function can reach are main-slot-only; if either ever grows to 8 this
    -- lever is redundant and must be re-read, not re-run.
    assert(M.g.AVAIL_MAX_SLOT == 5, 'J.IsItemAvailable now accepts slot '
        .. tostring(M.g.AVAIL_MAX_SLOT) .. ' -- the shipped read is no longer '
        .. 'main-slot-only and this lever may be a no-op')
    assert(M.g.SRC_MAIN_LOOP_HI == 5, "J.HasFieldRegenSource's main loop now "
        .. 'runs to ' .. tostring(M.g.SRC_MAIN_LOOP_HI))
    assert(M.g.STAY_SHIPPED_USES_AVAIL == 1, 'the shipped supply read no longer '
        .. 'goes through J.IsItemAvailable')
    -- Bounded by the next STATEMENT, not by a blank line: stripping comments
    -- turns this lever's own comment block into blank lines, so a `.-\n\n` span
    -- would swallow the lever and report the shipped side as already reading the
    -- backpack (the M15 self-injury of the 'staybottle' round).
    assert(M.g.STAY_SHIPPED_SLOTREADS == 0, 'the shipped supply expression now '
        .. 'reads item slots directly (' .. tostring(M.g.STAY_SHIPPED_SLOTREADS)
        .. ' reads) -- re-read the finding')
end

tests['[source] the two-id path exists, which is why this one is standalone'] = function()
    assert(M.g.SRC_HAS_BAGSALVE == 1, "J.HasFieldRegenSource no longer carries "
        .. "its 'bagsalve' block -- the conjunction this lever routes around is "
        .. 'gone and the argument for a separate id has to be re-made')
end

tests['[source] one id per condition -- the pullcad trap, not the id count'] = function()
    -- A CONJUNCTION of ids in one condition freezes FALSE the day either is
    -- promoted, while check_armed_wiring.py still calls the site WIRED. Four
    -- INDEPENDENT ids in one function is not that shape; a single condition
    -- naming two of them would be.
    assert(M.g.STAY_IDS_MAX_PER_COND == 1, 'some single condition in '
        .. 'J.ShouldStayAndRegen names ' .. tostring(M.g.STAY_IDS_MAX_PER_COND)
        .. ' soak ids -- that is the pullcad trap')
    -- A FLOOR, not an equality, and the reason is two days old: this same total
    -- was pinned `== 1` and then `== 3` by the two previous levers on this
    -- function, and each time the NEXT independent lever turned it red on a tree
    -- with no trap on it (tests/test_stayattr_global_ult.lua:155 wrote the
    -- lesson down; the 'staybottle' file laid it again the same day). The total
    -- is a PROXY; the invariant is the line above. The floor still refuses a
    -- deletion that makes the function id-free.
    assert(M.g.STAY_NIDS >= 4, 'J.ShouldStayAndRegen names '
        .. tostring(M.g.STAY_NIDS) .. " soak ids; expected at least 4 ('stayattr'"
        .. " on the chase clause, 'staysrc' / 'staybottle' / 'staybag' on the "
        .. 'supply clause)')
end

tests['[source] appended, never inserted -- both siblings must be untouched'] = function()
    assert(M.g.STAY_ORDER_OK == 1, "the 'staybag' block no longer sits after "
        .. "both the 'staysrc' and 'staybottle' blocks -- un-armed, their "
        .. 'evaluation is only byte-identical while it does')
end

tests['[source] the swapper is what makes a backpacked salve drinkable'] = function()
    -- The whole justification for widening by exactly one item, parsed off the
    -- tree: a shipped, UNGATED swapper for the flask and none for the other
    -- three consumables this lever deliberately does not count.
    assert(M.g.SWAP_EXISTS == 1, 'TrySwapInvItemForFlask is gone from '
        .. 'mode_team_roam_generic.lua -- a backpacked salve is then no more '
        .. 'drinkable than a backpacked tango and this lever must be withdrawn')
    assert(M.g.SWAP_READS_BACKPACK == 1, 'the swapper no longer tests '
        .. 'ITEM_SLOT_TYPE_BACKPACK')
    assert(M.g.SWAP_NIDS == 0, 'the swapper now carries '
        .. tostring(M.g.SWAP_NIDS) .. ' soak id(s) -- it is no longer SHIPPED '
        .. 'behaviour, so this lever would rest on another gate')
    assert(M.g.SWAP_TANGO == 0 and M.g.SWAP_BOTTLE == 0,
        'a swapper for tango/bottle appeared -- the "one item wide" argument '
        .. 'changed and the widening can be re-read')
end

tests['[source] the constants this lever does NOT touch'] = function()
    assert(M.g.STAY_HP_LO == 0.18 and M.g.STAY_HP_HI == 0.75,
        'the HP band moved: ' .. tostring(M.g.STAY_HP_LO) .. '..'
        .. tostring(M.g.STAY_HP_HI) .. ' -- the out-of-band controls below are '
        .. 'scored against it')
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
    cs.ratchet(C('supply_tested'), 125, 'frames that reach the supply clause')
    cs.ratchet(C('blocked_supply'), 112, 'frames the supply clause vetoes')
    assert(C('blocked_with_bag') + C('blocked_no_bag') == C('blocked_supply'),
        'the two-bin split of the vetoed frames does not sum -- counted, not '
        .. 'subtracted, so this is an arithmetic invariant')
end

tests['[domain] two frames, and the eleven the band rejects'] = function()
    cs.ratchet(C('bag_carriers'), 15, 'live frames carrying a backpacked salve')
    cs.ratchet(C('bag_out_of_band'), 11, 'carriers outside the HP band')
    -- The ANTI-VACUUM column: without it, "the corpus has no backpacked salves"
    -- and "the band rejects the ones it has" would read the same.
    assert(C('bag_carriers') > C('bag_out_of_band'),
        'every carrier in the corpus is out of band -- the domain is empty and '
        .. 'the flip count below is measuring nothing')
    -- The ROOT of the disjointness claim, and it is a property of the corpus,
    -- not of the lever: not one backpacked-salve frame also carries a main-slot
    -- source, so 'staysrc' cannot already be flipping any of them.
    assert(C('bag_with_main_src') == 0, C('bag_with_main_src')
        .. ' backpack-salve frames also carry a main-slot regen source -- the '
        .. "disjointness from 'staysrc' is no longer structural and the wave "
        .. 'design has to change')
    cs.ratchet(C('blocked_with_bag'), 2, 'frames inside the domain')
    assert(#M.flips == C('blocked_with_bag'), 'flip rows emitted: ' .. #M.flips)
    local seen = {}
    for _, f in ipairs(M.flips) do seen[f.hero] = f.fixture end
    assert(seen[SUBJ] ~= nil, 'the pinned frame is not in the flip set')
    assert(seen[SUBJ2] ~= nil, 'the second domain frame is not in the flip set')
    cs.ratchet(#M.carriers, 15, 'carrier rows emitted')
end

tests['[domain] two independent routes to the same number'] = function()
    -- `flips` comes from the function's own return value across two drives;
    -- `blocked_with_bag` comes from the prefix walk. A drift in either shows up
    -- as a red instead of as agreement.
    assert(C('flips') == C('blocked_with_bag'), 'driven flips ' .. C('flips')
        .. ' vs bucketed ' .. C('blocked_with_bag'))
    assert(C('arm_true') - C('ship_true') == C('flips'),
        'the TRUE count moved by ' .. (C('arm_true') - C('ship_true'))
        .. ' while ' .. C('flips') .. ' frames flipped')
    cs.ratchet(C('ship_true'), 13, 'shipped TRUE frames')
    cs.ratchet(C('arm_true'), 15, 'armed TRUE frames')
end

tests['[domain] direction is fixed by construction, and measured anyway'] = function()
    assert(C('flip_true_to_false') == 0, C('flip_true_to_false')
        .. ' frames turned TRUE -> FALSE; widening bHasRegen can only REMOVE '
        .. 'vetoes, so this is a contradiction, not a regression')
end

tests['[domain] the arming is exactly one id wide'] = function()
    assert(C('arm_leak') == 0, "the sweep's armed stub also answered TRUE for "
        .. "'staysrc'/'bagsalve'/'staybottle'/'stayattr' on " .. C('arm_leak')
        .. ' frames -- the flips would not be attributable to this lever')
end

tests['[domain] the gold term is unmeasurable, and that is measured'] = function()
    assert(C('gold_nonzero') == 0, C('gold_nonzero') .. ' frames carry real '
        .. 'gold. Honest bound (3) -- the gold-poor superset -- holds only '
        .. 'while this is 0; re-derive the bound, do not edit this line')
    assert(C('gold_zero') == C('live'), 'gold buckets do not partition')
end

tests['[domain] ⭐ the two-id path: safe, and unbuyable one arm at a time'] = function()
    -- THE FINDING. A backpacked salve is already reachable from this function
    -- through 'staysrc' AND 'bagsalve' together. Each site names one id, so the
    -- pullcad grep and the nesting census both read clean -- and no single-arm
    -- isolation wave can see the behaviour at all.
    cs.ratchet(C('flips_staysrc'), 44, "frames 'staysrc' alone flips")
    assert(C('flips_bagsalve') == 0, "'bagsalve' armed ALONE flips "
        .. C('flips_bagsalve') .. ' frames; expected 0 -- its gate sits behind '
        .. "'staysrc''s short-circuit and is never reached, which is the whole "
        .. 'shape of this finding')
    cs.ratchet(C('flips_pair'), 46, 'frames the PAIR flips')
    assert(C('flips_pair') > C('flips_staysrc'),
        'the pair no longer buys anything the better single arm does not -- '
        .. 'then the two-id path is not load-bearing and this lever is only a '
        .. 'convenience')
    -- ...and what the pair adds is exactly what this ONE id buys. Two ids, one
    -- call apart, replaced by one id at one site with the same measured effect.
    assert(C('pair_gain') == C('flips'), 'the pair adds ' .. C('pair_gain')
        .. ' frames over its better single arm while this lever flips '
        .. C('flips') .. ' -- they are supposed to be the same frames')
    assert(C('pair_gain_not_flips') == 0, C('pair_gain_not_flips')
        .. ' frames are bought by the two-id path but NOT by this lever -- the '
        .. 'replacement is not equivalent and the difference has to be read')
    assert(C('flips_both_levers') == 0, C('flips_both_levers')
        .. " frames are flipped by BOTH this lever and 'staysrc' -- the domains "
        .. 'overlap and a single-arm wave could double-count them')
end

-- ------------------------------------------------------------- the frame ---

tests['[frame] the bot is hurt, unchased, and carrying a salve it cannot reach'] = function()
    local J, bot = frame(FX, SUBJ)
    assert(near(J.GetHP(bot), 0.3621, 0.0005), 'HP moved: ' .. J.GetHP(bot))
    assert(bot:WasRecentlyDamagedByAnyHero(3.0) == false,
        'a hero touched him -- the chase clause would veto before the supply '
        .. 'clause is ever reached')
    assert(#J.GetNearbyHeroes(bot, 1200, true, BOT_MODE_NONE) == 0,
        'someone is inside the 1200 ring')
    local main, bag = {}, {}
    for i = 0, 5 do
        local it = bot:GetItemInSlot(i)
        main[#main + 1] = (it ~= nil) and it:GetName() or '-'
    end
    for i = 6, 8 do
        local it = bot:GetItemInSlot(i)
        bag[#bag + 1] = (it ~= nil) and it:GetName() or '-'
    end
    local sMain, sBag = table.concat(main, ' '), table.concat(bag, ' ')
    assert(sBag:find('item_flask', 1, true), 'the backpacked salve is gone: '
        .. sBag)
    assert(not sMain:find('item_flask', 1, true), 'a salve reached a main slot: '
        .. sMain)
    assert(not sMain:find('item_tango', 1, true), 'a tango appeared: ' .. sMain)
    assert(not sMain:find('item_faerie_fire', 1, true),
        'a faerie fire appeared: ' .. sMain)
end

tests['[frame] and BOTH shipped stock reads call him empty-handed'] = function()
    local J, bot = frame(FX, SUBJ)
    -- The sibling widening's own answer, driven: with only 'staysrc' available
    -- the tree still says "carries nothing", because its backpack block is
    -- behind a second id.
    assert(J.HasFieldRegenSource(bot) == false,
        'the sibling presence test now sees this salve un-armed -- then this '
        .. 'lever is not the only one-id way to see it')
    local J2, bot2 = frame_set(FX, SUBJ, { bagsalve = true })
    assert(J2.HasFieldRegenSource(bot2) == true,
        "armed 'bagsalve' the sibling DOES see it -- if this is false the "
        .. 'backpack block moved and this whole finding has to be re-read')
end

tests['[frame] shipped FALSE -> armed TRUE, on both domain frames'] = function()
    for _, t in ipairs({ { FX, SUBJ }, { FX2, SUBJ2 } }) do
        local J, bot, arm = frame(t[1], t[2])
        assert(J.ShouldStayAndRegen(bot) == false, t[2]
            .. ' shipped: the promoted guard is silent on a hurt, unchased bot '
            .. 'with a salve in the bag')
        arm(true)
        assert(J.ShouldStayAndRegen(bot) == true, t[2] .. ' armed: it holds him')
    end
end

tests['[frame] ⭐ neither sibling id can buy this frame alone; the pair can'] = function()
    -- The finding AT THE PINNED FRAME, not only in aggregate.
    local J1, b1 = frame_set(FX, SUBJ, { staysrc = true })
    assert(J1.ShouldStayAndRegen(b1) == false,
        "'staysrc' armed alone flips this frame -- then a single-arm wave could "
        .. 'already see the behaviour and this lever is unnecessary')
    local J2, b2 = frame_set(FX, SUBJ, { bagsalve = true })
    assert(J2.ShouldStayAndRegen(b2) == false,
        "'bagsalve' armed alone flips this frame -- its gate would have to be "
        .. "reachable without 'staysrc', which is not how the call is written")
    local J3, b3 = frame_set(FX, SUBJ, { staysrc = true, bagsalve = true })
    assert(J3.ShouldStayAndRegen(b3) == true,
        'the PAIR does not flip this frame -- then the two-id path this lever '
        .. 'replaces does not exist and the argument has to be re-made')
end

tests['[control] in-band carriers an EARLIER clause vetoes do not move'] = function()
    for _, t in ipairs(BLOCKED) do
        local J, bot, arm = frame(t.fx, t.subj)
        assert(near(J.GetHP(bot), t.hp, 0.0005),
            t.subj .. ' HP moved: ' .. J.GetHP(bot))
        -- Vacuity guard: these controls are only negative while they really do
        -- carry the item this lever reads.
        local bag = false
        for i = 6, 8 do
            local it = bot:GetItemInSlot(i)
            if it ~= nil and it:GetName() == 'item_flask' then bag = true end
        end
        assert(bag, t.subj .. ' no longer carries a backpacked salve -- this '
            .. 'control would then be vacuous rather than negative')
        local bVeto = (t.why == 'ring')
            and (#J.GetNearbyHeroes(bot, 1200, true, BOT_MODE_NONE) > 0)
            or bot:WasRecentlyDamagedByAnyHero(3.0)
        assert(bVeto, t.subj .. ': the ' .. t.why .. ' clause no longer vetoes '
            .. 'this frame, so it is not the control this file thinks it is')
        assert(J.ShouldStayAndRegen(bot) == false, t.subj .. ' shipped')
        arm(true)
        assert(J.ShouldStayAndRegen(bot) == false, t.subj
            .. ' moved: a clause ABOVE the supply read must still veto, and '
            .. 'this lever must not reach past its own clause')
    end
end

tests['[control] carriers on both sides of the HP band do not move'] = function()
    for _, t in ipairs(OOB) do
        local J, bot, arm = frame(t.fx, t.subj)
        assert(near(J.GetHP(bot), t.hp, 0.0005),
            t.subj .. ' HP moved: ' .. J.GetHP(bot))
        assert(J.ShouldStayAndRegen(bot) == false, t.subj .. ' shipped')
        arm(true)
        assert(J.ShouldStayAndRegen(bot) == false, t.subj
            .. ' moved: the HP band above the supply clause must still veto a '
            .. 'healthy bot AND leave the genuine escape retreat below 0.18')
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

tests['[bid] the walk leg: -0.0615 shipped -> 0 armed, and what that is NOT'] = function()
    -- Honest bound (2), as numbers. The shipped bid is NEGATIVE, so this mode
    -- was not asking to go home on this frame either way, and arming moves it UP
    -- to BOT_MODE_DESIRE_NONE via the guard's early return. What is measured is
    -- that the guard now FIRES at a real call site on a real frame -- not a bot
    -- turned around.
    local d0 = bid(nil)
    assert(near(d0, SHIPPED_BID, 1e-9),
        'the shipped retreat bid on this frame moved: ' .. tostring(d0))
    local d1 = bid('staybag')
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
    assert(body:find("J%.IsSoakCandidate%( 'staybag' %)"),
        "the lever is not gated on 'staybag'")
    -- One call site for the id, so the behaviour cannot ship through a second
    -- one that nobody gated.
    local _, n = src:gsub("IsSoakCandidate%( 'staybag' %)", '')
    assert(n == 1, "'staybag' appears in " .. n
        .. ' conditions in this file; expected exactly 1')
    -- Comments are STRIPPED before this count, and that is not tidiness. The
    -- sibling file wrote the same assertion over raw source; this lever's own
    -- comment names 'staybottle' once while explaining where it sits, and that
    -- turned the sibling red on a tree with exactly one arming point for it. The
    -- claim is "one ARMING POINT", so it is counted in code.
    local repo = (src .. read_file(RETREAT)
        .. read_file(ITEMS)):gsub('%-%-[^\n]*', '')
    local _, m = repo:gsub("'staybag'", '')
    assert(m == 1, "'staybag' appears " .. m
        .. ' times in CODE across the three files that decide the trip home; '
        .. 'expected 1')
end

return tests

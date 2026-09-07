-- [waitclar / owner priority P2] The base trip that fires on MANA, and the one
-- veto list in this function that has no entries.
--
-- WHAT THIS FILE ASSERTS
-- ----------------------
-- ConsiderWaitInBaseToHeal (bots/mode_roam_generic.lua) is SHIPPED and ungated:
-- it decides whether a bot TPs to its own base. Its condition is one `or` with
-- two legs, and the legs disagree about supply by ten to zero:
--
--   * the HP leg   -- trigger `J.GetHP(bot) < 0.25` -- refuses the trip on TEN
--     modifiers meaning "already recovering, or must not be moved", among them
--     oracle_purifying_flames, warlock_fatal_bonds, item_satanic_unholy, the
--     urn and the spirit vessel. Two of the ten are not consumables at all,
--     which is exactly what makes the list read as EXHAUSTIVE rather than short.
--   * the MANA leg -- trigger `J.GetMP(bot) < 0.25` -- refuses on NONE.
--
-- So a bot that has already drunk a clarity -- mana arriving, in the field,
-- paid for, and drunk by ITSELF through a shipped ungated branch -- still reads
-- as "needs to go to base for mana" and TPs. 'waitclar' adds exactly one veto
-- to the second leg, gated and turbo-only.
--
-- ⭐ THE FRAME. tests/fixtures/f_260819_222559_od_eclipse_solo.lua, medusa:
-- hp = 1.000 (FULL health), mp = 0.149, 'modifier_clarity_potion' ticking. The
-- shipped function answers TRUE on it -- a full-health hero being sent home.
-- Every conjunct on the path is the frame's own; nothing is manipulated.
--
-- ⭐⭐ WHY THIS IS NOT THE OPINION THAT WAS REFUSED THE SAME ROUND. "Does mana
-- regen count as field sustain" was priced and REJECTED on J.ShouldStayAndRegen
-- (report 2026-09-06T22:xxZ): that function's entire domain is an HP band
-- (0.18-0.75), so counting a mana consumable there would hold a HURT bot in the
-- field with no health arriving -- a genuinely new claim. Here the quantity the
-- veto is about and the quantity the trigger reads are THE SAME QUANTITY. The
-- asymmetry is asserted below as two numbers off the source (ten vetoes on the
-- HP leg, zero ungated ones on the mana leg), not as prose.
--
-- ⚠️ WHAT THIS FILE DOES NOT CLAIM. It does not claim the corpus is large: the
-- domain is ONE frame of 1012 and the sweep emits a row per clarity carrier
-- naming the clause that stopped it, so a reader can see the other eleven. It
-- does not claim the mana all arrives (a clarity breaks on hero damage -- the
-- magnitude question 'fieldsip' owns on the other family). It does not touch
-- the HP leg, whose own missing 'modifier_bottle_regeneration' is a separate
-- finding with a separate (empty, on this corpus) domain.

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')
local cs = require('corpus_scale')

local FIXTURE = 'tests/fixtures/f_260819_222559_od_eclipse_solo.lua'
local HERO = 'npc_dota_hero_medusa'
local ROAMFILE = 'bots/mode_roam_generic.lua'
local CLAR = 'modifier_clarity_potion'

local tests = {}

--- Load the pinned frame and hand back a driver that answers the SHIPPED
--- global with the gate off and then on. Nothing here re-implements the
--- decision: both answers come out of ConsiderWaitInBaseToHeal itself.
local function drive()
    local J, bot = rf.load(FIXTURE, HERO)
    local fArmed = function() return false end
    J.IsSoakCandidate = function(sId) return fArmed(sId) and true or false end
    dofile(ROAMFILE)
    GetDesire()
    --- `f` decides which ids read as armed for THIS call, so every answer comes
    --- from one loaded world and one bot. Re-loading the fixture per call would
    --- leave the mode file's upvalues bound to a previous bot -- which is
    --- exactly how the first version of this file produced a false red.
    local function answer(f)
        fArmed = f or function() return false end
        local v = ConsiderWaitInBaseToHeal()
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

tests['[frame] the pinned frame is a FULL-health hero with a ticking clarity'] = function()
    local J, bot = drive()
    local nHP, nMP = J.GetHP(bot), J.GetMP(bot)
    assert(math.abs(nHP - 1.000) < 0.001,
        'the frame no longer reads hp 1.000 (' .. string.format('%.3f', nHP)
        .. ') -- the whole point of this frame is that the bot is NOT hurt')
    assert(nMP < 0.25, 'the frame no longer reads mp below the mana leg\'s own '
        .. 'trigger (' .. string.format('%.3f', nMP) .. ')')
    assert(bot:HasModifier(CLAR),
        'the frame no longer carries ' .. CLAR .. ' -- without it this file is '
        .. 'driving a world the finding is not about')
end

tests['[frame] shipped, this frame is sent home; armed, it is not'] = function()
    local _, _, answer = drive()
    assert(answer(nil) == true,
        'the SHIPPED function no longer sends this frame to base -- the defect '
        .. 'this lever removes is gone, or the path changed; re-derive before '
        .. 'editing this file')
    assert(answer(only('waitclar')) == false,
        'armed, the lever does not cancel the trip on the one frame it was '
        .. 'written for')
end

tests['[frame] the flip belongs to THIS id, not to any armed string'] = function()
    local _, _, answer = drive()
    -- The gate names exactly one id. A lever that moved on some OTHER armed
    -- string would be crediting itself with a sibling's flip -- the M8 survivor
    -- of the 'stayattr' round, and the shape GH #576 is about.
    for _, sOther in ipairs({ 'c2', 'stayfield', 'stayurn', 'itemtrip', 'staysrc' }) do
        assert(answer(only(sOther)) == true,
            "arming '" .. sOther .. "' alone cancels this trip; the flip this "
            .. "file attributes to 'waitclar' is not this lever's")
    end
    -- ...and with every id in the tree armed it is still cancelled, i.e. no
    -- sibling on this path re-enables the trip the lever stops.
    assert(answer(function() return true end) == false,
        'with every id armed the trip is taken again')
    assert(answer(nil) == true, 'the shipped answer moved between calls')
end

tests["[frame] ⛔ 'c4' suppresses the same trip, and that is registered here"] = function()
    local _, _, answer = drive()
    -- ⭐ FOUND BY THIS FILE, ON ITS OWN LEVER, THE ROUND IT LANDED -- and the
    -- honest thing to do with it is assert it, not exclude it from the loop
    -- above. GH #576's shape is "an id reads zero because ANOTHER id already
    -- decided the frame", and here is a live instance on a brand-new lever:
    -- this function's OUTER guard opens with `not J.IsInLaningPhase()`, and 'c4'
    -- EXTENDS the laning phase. So on this frame 'c4' armed alone cancels the
    -- same trip 'waitclar' cancels, by a completely different clause.
    --
    -- What that does and does not cost:
    --   * it does NOT make 'waitclar' unreadable by a single-arm wave -- armed
    --     alone it flips this frame, and 'c2' (the other id in the same helper)
    --     does not;
    --   * it DOES mean a member string containing BOTH cannot attribute this
    --     frame to either. If 'c4' is armed in the same wave, this lever's
    --     domain is dominated on every frame where the laning extension
    --     reaches, and the correct reading of a zero there is "not reached",
    --     not "no effect".
    -- Pinned so that a later change to J.IsInLaningPhase's 'c4' block, or to
    -- this function's outer guard, has to come back and re-read this note.
    assert(answer(only('c4')) == false,
        "arming 'c4' alone no longer suppresses this trip -- the domination "
        .. 'this file records has gone away (good news, but the handoff note '
        .. 'and the census row that cite it are now stale)')
    -- ...and the two are NOT the same lever: with 'c4' armed the trip is
    -- suppressed through the laning guard whether or not the bot is drinking,
    -- which is why they cannot be read as one.
    assert(answer(function(s) return s == 'c4' or s == 'waitclar' end) == false,
        'the pair no longer suppresses the trip')
end

-- ==========================================================================
-- 2. The asymmetry the condition-(c) argument rests on -- off the source
-- ==========================================================================

local function read_file(path)
    local f = assert(io.open(path, 'r'), path .. ' is not readable')
    local s = f:read('*a')
    f:close()
    return s
end

local function roam_block()
    local src = read_file(ROAMFILE)
    local at = assert(src:find('function ConsiderWaitInBaseToHeal()', 1, true),
        'ConsiderWaitInBaseToHeal is gone from ' .. ROAMFILE)
    local stop = src:find('\nfunction ', at + 40) or #src
    -- Comments stripped: this lever ships with a long comment naming both legs
    -- and the modifier, and the COMMENT must not be able to satisfy an
    -- assertion about the CODE (the §EN mistake).
    return (src:sub(at, stop):gsub('%-%-[^\n]*', ''))
end

tests['[source] the HP leg vetoes on ten modifiers and the mana leg on one, gated'] = function()
    local blk = roam_block()
    local hp = assert(blk:match("J%.GetHP%(bot%) < 0%.25(.-)or %(%(%("),
        'the HP leg no longer parses -- re-derive the counts before trusting '
        .. 'this file')
    local n = 0
    for _ in hp:gmatch('HasModifier') do n = n + 1 end
    -- COUNTED, not flagged. A presence flag reads the same whether that list
    -- has ten entries or one, and "the list is exhaustive" is the argument.
    assert(n == 10, 'the HP leg\'s veto list is now ' .. n .. ' modifiers, not '
        .. '10 -- the asymmetry this lever is argued from has changed size')
    assert(hp:find(CLAR, 1, true) == nil,
        'the HP leg now names the clarity; that leg is triggered by HEALTH and '
        .. 'a clarity restores none, so this lever\'s argument no longer holds')

    local mana = assert(blk:match('or %(%(%(J%.IsCore.-\n%s*then'),
        'the mana leg no longer parses')
    local m, g = 0, 0
    for _ in mana:gmatch('HasModifier') do m = m + 1 end
    for _ in mana:gmatch('IsSoakCandidate') do g = g + 1 end
    -- Shipped this leg had ZERO supply vetoes. Armed it has exactly one, and it
    -- is gated -- so both numbers being 1 is the statement "the only supply
    -- veto on this leg is this candidate".
    assert(m == 1 and g == 1,
        'the mana leg now carries ' .. m .. ' modifier veto(s) behind ' .. g
        .. ' gate(s); it was 0 shipped and this lever adds exactly 1 gated one')
end

tests['[source] the gate is the first conjunct, so un-armed nothing else runs'] = function()
    local blk = roam_block()
    local a = assert(blk:find("IsSoakCandidate('waitclar')", 1, true))
    local b = assert(blk:find('IsModeTurbo()', 1, true),
        'turbo is NOT structural on this path -- nothing above asks -- so the '
        .. 'lever must ask it itself')
    local c = assert(blk:find(CLAR, 1, true))
    assert(a < b and b < c,
        'the gate is no longer the first conjunct of its own condition; '
        .. 'un-armed the engine call below it would now be evaluated')
    -- The 'pullcad' trap is TWO IDS IN ONE CONDITION. One id, one site.
    local n = 0
    for _ in blk:gmatch('IsSoakCandidate') do n = n + 1 end
    assert(n == 1, 'this function now names ' .. n .. ' candidate ids; a second '
        .. 'one in the same condition would freeze FALSE the day either is '
        .. 'promoted')
end

tests['[source] the tree already refuses to act on a ticking clarity elsewhere'] = function()
    local itemsrc = read_file('bots/ability_item_usage_generic.lua')
    local needle = 'not bot:HasModifier( "' .. CLAR .. '" )'
    local n, at = 0, 1
    while true do
        local i = itemsrc:find(needle, at, true)
        if i == nil then break end
        n = n + 1
        at = i + 1
    end
    -- COUNTED rather than flagged, for the reason the 'stayurn' round's M6
    -- mutant proved: deleting one of several sites leaves a presence flag green.
    -- Three sites: the two home-TP branches ('撤退:3' and '回复状态') plus the
    -- self-drink desire that refuses to re-drink.
    assert(n == 3, 'the item layer now refuses on a ticking clarity at ' .. n
        .. ' site(s), not 3 -- the condition-(c) argument rests on this count')
    -- ⛔ THE CAST PATH, and the assertion that had to be rewritten before it
    -- meant anything. The first version was a presence flag on the bare string
    -- `J.GetMP( bot ) < 0.4`, and the mutation stand's M11 -- which breaks the
    -- self-drink by moving that constant to 0.0 -- SURVIVED it. The reason is
    -- the same class as the needle-uniqueness lesson (GH #550), one level up:
    -- that string occurs TWICE in this file (line ~1879, a different block, and
    -- line ~1905, the clarity self-drink), so the flag stayed green while the
    -- site the argument rests on was destroyed. Per evidence discipline rule 2
    -- the ASSERTION was the defect, not the mutant.
    -- Fixed by scoping to the block, and the multiplicity is pinned so the next
    -- reader is told rather than left to rediscover it. The block is cut at a
    -- LINE-ANCHORED `X.ConsiderItemDesire[`, because a comment inside a block
    -- can name another entry of the same table (the 'urnself' round's M15).
    local n40, at40 = 0, 1
    while true do
        local i = itemsrc:find('J.GetMP( bot ) < 0.4', at40, true)
        if i == nil then break end
        n40 = n40 + 1
        at40 = i + 1
    end
    assert(n40 == 2, 'the bare self-drink string now occurs ' .. n40
        .. ' time(s), not 2; the scoping below was written because it is not '
        .. 'unique, and that reasoning has to be re-read')
    local clarAt = assert(itemsrc:find('\nX.ConsiderItemDesire["item_clarity"]', 1, true),
        'X.ConsiderItemDesire["item_clarity"] is gone')
    local clarEnd = itemsrc:find('\nX.ConsiderItemDesire[', clarAt + 40, true) or #itemsrc
    local clarBlk = itemsrc:sub(clarAt, clarEnd)
    assert(clarBlk:find('J.GetMP( bot ) < 0.4', 1, true) ~= nil,
        'the ungated self-drink branch INSIDE X.ConsiderItemDesire["item_clarity"] '
        .. 'is gone; without it this lever would be holding a bot next to mana '
        .. 'it never presses -- which is exactly the reason the urn widening was '
        .. 'refused, and it would apply here too')
    assert(clarBlk:find('IsSoakCandidate', 1, true) == nil,
        'the self-drink is now gated; "the bot presses this button itself" is '
        .. 'the load-bearing half of this lever\'s condition-(c) argument and it '
        .. 'only holds while that branch is UNGATED')
    local healing = read_file('bots/FunLib/aba_buff.lua'):match('hero_is_healing = {(.-)}')
    assert(healing ~= nil and healing:find(CLAR, 1, true) ~= nil,
        'aba_buff no longer lists the clarity among the recovering modifiers')
end

-- ==========================================================================
-- 3. The corpus, through the subprocess sweep
-- ==========================================================================

-- Memoised: the sweep re-dofiles mode_roam_generic once per hero-frame and
-- costs minutes. Three test bodies read it, and a mutation stand runs the whole
-- file a dozen times -- running it per body would turn a 4-minute stand leg into
-- a 12-minute one for no extra information (the sweep is a pure function of the
-- tree, and the tree does not change inside one process).
local sweep_cache = nil
local function sweep()
    if sweep_cache ~= nil then return unpack(sweep_cache) end
    local p = assert(io.popen('lua5.1 tests/_waitclar_sweep.lua 2>/dev/null'))
    local s = p:read('*a')
    p:close()
    assert(s:find('\nDONE', 1, true) or s:find('^DONE'),
        'tests/_waitclar_sweep.lua did not reach its DONE line -- the '
        .. 'subprocess failed, and a truncated manifest must never be read as '
        .. 'a small measurement')
    local G, C, F, B = {}, {}, {}, {}
    for line in s:gmatch('[^\n]+') do
        local k, v = line:match('^G (%S+) (%S+)$')
        if k then G[k] = tonumber(v) or v end
        local ck, cv = line:match('^C (%S+) (%-?%d+)$')
        if ck then C[ck] = tonumber(cv) end
        if line:match('^F ') then F[#F + 1] = line end
        if line:match('^B ') then B[#B + 1] = line end
    end
    sweep_cache = { G, C, F, B }
    return G, C, F, B
end

tests['[corpus] the sweep drives the real corpus and lands one flip'] = function()
    local G, C, F, B = sweep()
    -- ⛔ THE DENOMINATOR GOES THROUGH corpus_scale (GH #106 / #127). This was
    -- `== 1012` and is the same defect the detector caught one file over -- it
    -- simply could not see this one, because its rule is "a literal equal to
    -- TODAY'S FIXTURE COUNT" and 1012 is a FRAME count. Same defect, different
    -- denominator, no detector: hence the repair by hand here.
    cs.ratchet(C.live, 1012, 'live hero frames')
    assert(C.raises == 0, tostring(C.raises) .. ' frame(s) raised inside the '
        .. 'driven function; a raise is not a measurement')
    assert(C.arm_leak == 0, 'the sweep armed more than one id')
    assert(G.ROAM_SOAKID == 1 and G.ROAM_TURBO == 1 and G.ROAM_GATE_FIRST == 1)
    assert(G.HP_LEG_VETOES == 10 and G.MANA_LEG_MODS == 1 and G.MANA_LEG_GATED == 1)
    assert(G.ITEM_CLARITY_VETO_SITES == 3 and G.ITEM_SELF_DRINKS_CLARITY == 1
        and G.BUFF_HEALING_HAS_CLARITY == 1)

    -- ⭐ THE LEG SPLIT. A finding about the mana leg is worth nothing if the
    -- corpus only reaches the HP leg. 5 of the 6 shipped TRUEs come through the
    -- mana leg, so the leg this lever edits is the leg that fires.
    assert(C.ship_true == 6, 'shipped TRUEs moved to ' .. tostring(C.ship_true))
    assert(C.wait_mana_leg == 5 and C.wait_hp_leg == 1,
        'the leg split moved to mana=' .. tostring(C.wait_mana_leg) .. ' hp='
        .. tostring(C.wait_hp_leg))
    assert(C.wait_mana_leg + C.wait_hp_leg == C.ship_true,
        'the two legs no longer partition the shipped TRUE set')

    assert(C.flips == 1 and C.arm_true == 5,
        'flips=' .. tostring(C.flips) .. ' arm_true=' .. tostring(C.arm_true))
    assert(#F == 1 and F[1]:find('f_260819_222559_od_eclipse_solo', 1, true)
        and F[1]:find('npc_dota_hero_medusa', 1, true),
        'the flip is no longer the pinned medusa frame: ' .. table.concat(F, ' | '))
end

tests['[corpus] direction holds, through a counter proved to count'] = function()
    local _, C = sweep()
    -- This lever appends a veto: it can only turn TRUE into FALSE.
    assert(C.flip_false_to_true == 0,
        tostring(C.flip_false_to_true) .. ' frame(s) went the WRONG way -- a '
        .. 'veto cannot send a bot home that was not already going')
    -- ...and the same tally called with the legs exchanged puts the WHOLE
    -- domain into the branch that must read 0 on the real call, so a deleted
    -- bump moves the manifest instead of leaving it byte-identical.
    assert(C.flip_false_to_true_swapped == C.flips and C.flips_swapped == 0,
        'the swapped tally reads ' .. tostring(C.flip_false_to_true_swapped)
        .. '/' .. tostring(C.flips_swapped) .. ' -- the zero above is no longer '
        .. 'proved to be a counter that can count')
end

tests['[corpus] every clarity carrier is accounted for, by counting'] = function()
    local _, C, _, B = sweep()
    assert(C.clar_carriers == 12, 'clarity carriers moved to '
        .. tostring(C.clar_carriers))
    -- The five buckets SUM to the carrier count -- counted, never derived by
    -- subtraction. "The corpus has no clarities" and "it has clarities this
    -- function rejects earlier" can therefore never be the same reading.
    local nSum = C.clar_stop_outer + C.clar_stop_mp + C.clar_stop_hp_leg
        + C.blocked_domain
    assert(nSum == C.clar_carriers, 'the carrier buckets sum to ' .. nSum
        .. ' but there are ' .. C.clar_carriers .. ' carriers')
    assert(#B == C.clar_carriers, 'the sweep emitted ' .. #B .. ' carrier rows '
        .. 'for ' .. C.clar_carriers .. ' carriers')
    assert(C.clar_stop_mp == 9 and C.clar_stop_outer == 2
        and C.clar_stop_hp_leg == 0 and C.blocked_domain == 1,
        'the carrier breakdown moved: mp=' .. C.clar_stop_mp .. ' outer='
        .. C.clar_stop_outer .. ' hp_leg=' .. C.clar_stop_hp_leg .. ' domain='
        .. C.blocked_domain)
    -- The two independent paths to the same number: `flips` comes from the
    -- driven function's own return value, `blocked_domain` from the carrier
    -- walk. They must agree.
    assert(C.blocked_domain == C.flips,
        'the driven flip count (' .. C.flips .. ') and the bucketed domain ('
        .. C.blocked_domain .. ') disagree')
end

return tests

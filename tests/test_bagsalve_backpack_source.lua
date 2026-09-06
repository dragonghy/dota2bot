-- [bagsalve / owner priority P2, GH #123] The holding predicate reads six
-- slots while the purchase gate reads nine, and BOTH consumers of that answer
-- are wrong on the same frame because of it.
--
-- The asymmetry, and why it is a defect on both sides at once. `fieldbuy` buys
-- a salve through `Item.GetEmptyInventoryAmount` (slots 0..8); the courier can
-- deliver it into the backpack; `J.HasFieldRegenSource` reads slots 0..5 and
-- answers FALSE. That single FALSE is consumed twice on the same frame:
--   * the hold ids (stayfield / stayfield2) see "nothing to drink" and let the
--     bot go home -- the exact behaviour owner priority P2 forbids;
--   * `fieldbuy` sees the same and buys a SECOND salve on top of the one
--     already in the bag.
-- GH #123 proposed closing the asymmetry from the purchase end (nine slots ->
-- six). That was measured on 2026-08-22 and REJECTED: it silences the id on
-- 46.4% of its own domain, and on every one of those frames the shipped
-- rescuer would have worked (tests/test_fieldbuy_backpack_rescuer.lua). This
-- file is the same asymmetry closed from the other end, which gives nothing up.
--
-- ⭐ WHY EXACTLY ONE ITEM. `TrySwapInvItemForFlask()`
-- (bots/mode_team_roam_generic.lua) is un-gated, runs off GetDesire for every
-- live hero on every frame, and moves a backpacked item_flask into a main slot.
-- There is NO shipped swapper for tango / tango_single / faerie_fire / bottle.
-- So a backpacked salve is at most one 6.2s poll from being drinkable, and a
-- backpacked tango is not drinkable at all. 55 live frames in the corpus carry
-- one of those four in the backpack with no main-slot heal, and this widening
-- must leave every one of them FALSE -- that is the invariant zero in the BAG
-- line of tests/_fieldbuy_supply_sweep.lua, and one of those 55 is pinned
-- below as a real-frame negative control INSIDE the situation domain.
--
-- ⭐ AND THE CALL SITE SELECTS FOR IT. `stayfield`'s only wiring is the
-- tpscroll '撤退:3' branch, whose own conjunction carries `itemFlask == nil`
-- with `itemFlask = J.IsItemAvailable("item_flask")` -- and J.IsItemAvailable
-- returns a handle only for slots 0..5. So the branch this id vetoes fires
-- ONLY for bots with no salve in a main slot, which is precisely the population
-- whose salve may be sitting in the backpack. Both halves of that are asserted
-- off the source below rather than restated.
--
-- Honest bounds, stated first:
--   * DOMAIN, both numbers, never subtracted (charter 0DOM). Predicate frame
--     domain: 13 of 966 live frames (1.3%) change J.HasFieldRegenSource when
--     this id is armed. BEHAVIOURAL domain in this corpus: ZERO -- no frame is
--     simultaneously inside J.IsFieldRegenSituation and carrying a backpacked
--     salve (BAG sit_flip=0), so nothing downstream moves on any of the 966.
--     The population this lever is for lives in the batch dumps, not here: the
--     replay desk measured 166 backpack landings over 205 games on 2026-08-23,
--     26.9% of field purchases, with an 11.0% residual STUCK rate. The
--     end-to-end case below therefore MODELS the courier delivery onto a real
--     situation frame, exactly as the rejection file did, and says so.
--   * the 2026-08-22 rejection file states "no frame in the corpus carries a
--     flask in a backpack slot". That is FALSE as of today's 104-fixture
--     corpus: 13 frames do, spread across all three backpack slots (6:2, 7:6,
--     8:5). The predicate-level cases below are pure real frames because of it,
--     and the stale claim is corrected in that file.
--   * the rescuer's own swap-victim read (GetMainInvLessValItemSlot ~= -1)
--     holds on 966/966 live frames. That is a ONE-DIRECTIONAL read (charter
--     0DIR): the corpus cannot show it false, so it is REPORTED as the
--     reachability leg of the argument and deliberately NOT added as a clause
--     -- a conjunct that is TRUE on every measurable frame buys nothing and
--     hides its own failure mode.
--   * what blocks the rescuer in the 11.0% residual is not readable here. Its
--     BOT_MODE_WARD clause is the standing suspect and the replay desk's
--     2026-08-23 attempt to test it came back UNTESTABLE. This file does not
--     claim the residual is zero; it claims a backpacked salve is worth more
--     than nothing, which is what the six-slot read currently scores it at.

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')

-- Real frame, real backpack salve (slot 6, from the dump): spirit_breaker at
-- 36.2% HP with all six main slots full. Also the negative control for the
-- situation guard -- one enemy hero is inside 1600, so this frame must stay
-- OUT of the domain however the source question is answered.
local R1_FIX  = 'tests/fixtures/f_260822_182012_sb_backpack_rescue_372.lua'
local R1_HERO = 'npc_dota_hero_spirit_breaker'

-- Real frame, real backpack salve in the FAR slot (8), so a mutation that
-- narrows the new loop's range is caught by a real frame and not by a model.
local R2_FIX  = 'tests/fixtures/f_181544_storm_escape_tp.lua'
local R2_HERO = 'npc_dota_hero_jakiro'

-- The family's Frame B: viper, inside J.IsFieldRegenSituation, dry, six main
-- slots full, and carrying a real item_faerie_fire in backpack slot 6. It is
-- BOTH the negative control (a backpacked heal with no shipped swapper, in the
-- live domain, must not flip) and the frame the modelled delivery lands on.
local B_FIX   = 'tests/fixtures/f_260820_043637_axe_ring_alone.lua'
local B_HERO  = 'npc_dota_hero_viper'

local JMZ      = 'bots/FunLib/jmz_func.lua'
local ROAM     = 'bots/mode_team_roam_generic.lua'
local ABILITY  = 'bots/ability_item_usage_generic.lua'

local tests = {}

local function read_file(path)
    local f = assert(io.open(path, 'r'))
    local s = f:read('*a')
    f:close()
    return s
end

--- Line comments removed, so a CALL-SITE census counts call sites.
-- Added 2026-08-29 ('fieldsip' round): the census below was a raw text count,
-- so a comment that QUOTES the call form -- e.g. one saying "this used to read
-- `not J.HasFieldRegenSource( bot )`" -- read as a third call site and turned
-- the file red with no call site added. That is the same shape as the pure
-- comment lines that moved a line-number pin on 08-29T04:20Z: a check whose
-- pattern reaches text its claim does not cover. This STRENGTHENS the census
-- (a comment can no longer trip it OR satisfy it); the mutation below proves a
-- real third call site is still caught.
-- Deliberately line comments only: this file has no --[[ block ]] comments and
-- a general Lua comment stripper would have to understand long-bracket levels
-- and strings, i.e. more machinery than the claim needs.
local function strip_comments(src)
    local out = {}
    for line in (src .. '\n'):gmatch('([^\n]*)\n') do
        out[#out + 1] = line:gsub('%-%-.*$', '')
    end
    return table.concat(out, '\n')
end

--- Load a frame with `armed` (a string id, a set-like table, or nil) armed.
local function world(fix, hero, armed)
    local J, bot = rf.load(fix, hero)
    if type(armed) == 'table' then
        J.IsSoakCandidate = function(id) return armed[id] == true end
    else
        J.IsSoakCandidate = function(id) return armed ~= nil and id == armed end
    end
    return J, bot
end

--- Declaration: model the courier delivering a salve into backpack slot
--- `nSlot`. Only the handle is modelled; every clause downstream reads the real
--- frame. Same surface the 2026-08-22 rejection file models at, on the same
--- frame, so the two files cannot drift apart.
local function deliver_flask(bot, nSlot)
    local real_get = bot.GetItemInSlot
    local hFlask = { GetName = function() return 'item_flask' end }
    bot.GetItemInSlot = function(self, i)
        if i == nSlot then return hFlask end
        return real_get(self, i)
    end
end

-- ---------------------------------------------------------------- premises --

tests['[premise] R1 carries a REAL backpacked salve and a full main inventory'] = function()
    local J, bot = world(R1_FIX, R1_HERO, nil)
    local h = bot:GetItemInSlot(6)
    assert(h ~= nil and h:GetName() == 'item_flask',
        'slot 6 is no longer a salve on the pinned frame; re-pin')
    for i = 0, 5 do
        assert(bot:GetItemInSlot(i) ~= nil, 'main slot ' .. i .. ' went empty')
    end
    local nHP = J.GetHP(bot)
    assert(nHP > 0.18 and nHP < 0.55,
        'the frame left the HP band, so the situation clauses stop being the '
        .. 'thing under test here: ' .. nHP)
end

tests['[premise] R2 carries a REAL backpacked salve in the far slot (8)'] = function()
    local _, bot = world(R2_FIX, R2_HERO, nil)
    local h = bot:GetItemInSlot(8)
    assert(h ~= nil and h:GetName() == 'item_flask',
        'slot 8 is no longer a salve on the pinned frame; re-pin')
end

tests['[premise] Frame B is in the domain, dry, and holds a REAL backpacked faerie_fire'] = function()
    local J, bot = world(B_FIX, B_HERO, nil)
    assert(J.IsFieldRegenSituation(bot) == true, 'Frame B left the situation')
    assert(J.HasFieldRegenSource(bot) == false, 'Frame B is no longer dry')
    local h = bot:GetItemInSlot(6)
    assert(h ~= nil and h:GetName() == 'item_faerie_fire',
        'backpack slot 6 is no longer a faerie_fire; the negative control moved')
    assert(bot:GetItemInSlot(7) == nil,
        'backpack slot 7 is occupied; the modelled delivery needs it free')
end

-- ------------------------------------------------------- the predicate flip --

tests['armed, a REAL backpacked salve is a regen source (slot 6)'] = function()
    local Joff, boff = world(R1_FIX, R1_HERO, nil)
    assert(Joff.HasFieldRegenSource(boff) == false,
        'the shipped six-slot read already sees the backpack')
    local Jon, bon = world(R1_FIX, R1_HERO, 'bagsalve')
    assert(Jon.HasFieldRegenSource(bon) == true,
        'armed, the backpacked salve is still invisible')
end

tests['armed, a REAL backpacked salve is a regen source (slot 8)'] = function()
    local Joff, boff = world(R2_FIX, R2_HERO, nil)
    assert(Joff.HasFieldRegenSource(boff) == false, 'shipped read moved')
    local Jon, bon = world(R2_FIX, R2_HERO, 'bagsalve')
    assert(Jon.HasFieldRegenSource(bon) == true,
        'the far backpack slot is outside the new loop s range')
end

-- ------------------------------------------------------- negative controls --

tests['armed, a REAL backpacked faerie_fire is NOT a regen source'] = function()
    -- The load-bearing negative: this frame is INSIDE the situation domain, so
    -- a widening that took the whole heal list would move behaviour here -- and
    -- there is no shipped swapper that could ever make that faerie_fire
    -- drinkable. 55 live frames have this shape; the sweep's other_flip=0 is
    -- the same assertion at corpus scale.
    local J, bot = world(B_FIX, B_HERO, 'bagsalve')
    assert(J.HasFieldRegenSource(bot) == false,
        'the widening took more than the salve')
    assert(J.ShouldRegenNotGoHome(bot) == false,
        'and it moved the hold decision on a frame with nothing drinkable')
end

tests['armed, the situation guard is NOT weakened by the widening'] = function()
    -- R1 has a real backpacked salve AND one enemy hero inside 1600. The
    -- predicate flips; the decision must not.
    local J, bot = world(R1_FIX, R1_HERO, { bagsalve = true, stayfield = true,
                                            stayfield2 = true })
    assert(J.HasFieldRegenSource(bot) == true, 'the premise of this test moved')
    assert(#J.GetNearbyHeroes(bot, 1600, true, BOT_MODE_NONE) > 0,
        'the ring emptied; this is no longer the negative control')
    assert(J.IsFieldRegenSituation(bot) == false, 'the situation opened up')
    assert(J.ShouldRegenNotTpHome(bot) == false,
        'the widening let a bot with an enemy on it hold in the field')
    assert(J.ShouldRegenNotWalkHome(bot) == false, 'same, on the walk leg')
end

-- ------------------------------------------------------------- the gate --

tests['gate: nothing armed, the widening is a byte-for-byte no-op'] = function()
    for _, s in ipairs({ { R1_FIX, R1_HERO }, { R2_FIX, R2_HERO },
                         { B_FIX, B_HERO } }) do
        local J, bot = world(s[1], s[2], nil)
        assert(J.HasFieldRegenSource(bot) == false,
            'ungated fire on ' .. s[2])
    end
end

tests['gate: arming a SIBLING id does not arm this one'] = function()
    for _, other in ipairs({ 'stayfield', 'stayfield2', 'fieldbuy',
                             'fieldregen', 'fieldcreep', 'itemtrip' }) do
        local J, bot = world(R1_FIX, R1_HERO, other)
        assert(J.HasFieldRegenSource(bot) == false,
            other .. ' armed this id')
    end
end

-- ----------------------------------------------- the modelled end-to-end --

tests['[modelled delivery] armed, the hold half fires on a real domain frame'] = function()
    -- Frame B is the one real frame in the corpus that is inside the situation
    -- AND has backpack room; the salve landing in slot 7 is the modelled half.
    local J, bot = world(B_FIX, B_HERO, { bagsalve = true, stayfield = true,
                                          stayfield2 = true })
    assert(J.ShouldRegenNotTpHome(bot) == false,
        'the TP half already fires before the delivery; the model is not the cause')
    deliver_flask(bot, 7)
    assert(J.HasFieldRegenSource(bot) == true, 'the delivered salve is invisible')
    assert(J.ShouldRegenNotGoHome(bot) == true, 'the core predicate did not flip')
    assert(J.ShouldRegenNotTpHome(bot) == true, 'the TP half did not flip')
    assert(J.ShouldRegenNotWalkHome(bot) == true, 'the walk half did not flip')
end

tests['[modelled delivery] armed, the supply half stops double-buying'] = function()
    local J, bot = world(B_FIX, B_HERO, { bagsalve = true, fieldbuy = true })
    assert(J.ShouldFieldBuyRegen(bot) == true,
        'Frame B must want a salve before the delivery, or nothing is at stake')
    deliver_flask(bot, 7)
    assert(J.ShouldFieldBuyRegen(bot) == false,
        'the id still buys a second salve on top of the one in the bag')
end

tests['[modelled delivery] without this id armed, the delivery changes nothing'] = function()
    local J, bot = world(B_FIX, B_HERO, { stayfield = true, stayfield2 = true,
                                          fieldbuy = true })
    deliver_flask(bot, 7)
    assert(J.HasFieldRegenSource(bot) == false, 'unarmed, the backpack is read')
    assert(J.ShouldRegenNotTpHome(bot) == false, 'unarmed hold fired')
    assert(J.ShouldFieldBuyRegen(bot) == true, 'unarmed supply half moved')
end

tests['the partition survives the widening'] = function()
    -- The two decision-side halves must stay disjoint on every frame: same
    -- situation, opposite answers to "is there a heal in the bag". A widening
    -- that broke that would make a per-id A/B meaningless.
    local J, bot = world(B_FIX, B_HERO, { bagsalve = true, stayfield = true,
                                          fieldbuy = true })
    deliver_flask(bot, 7)
    assert(J.IsFieldRegenSituation(bot) == true, 'the situation moved')
    assert(J.ShouldRegenNotTpHome(bot) == true and
           J.ShouldFieldBuyRegen(bot) == false,
        'both halves answered the same way')
end

-- --------------------------------------------------- [reverse] source facts --

tests['[reverse] the shipped rescuer exists for the salve and for nothing else'] = function()
    local src = read_file(ROAM)
    assert(src:find('function TrySwapInvItemForFlask()', 1, true),
        'the salve rescuer is gone; this whole widening loses its argument')
    assert(src:find("FindItemSlot('item_flask')", 1, true),
        'the rescuer no longer looks for a salve')
    -- The absence is the load-bearing half. If a tango swapper ever lands, the
    -- one-item restriction above should be revisited -- deliberately, here.
    for _, sName in ipairs({ 'item_tango', 'item_tango_single',
                             'item_faerie_fire', 'item_bottle' }) do
        assert(not src:find("FindItemSlot('" .. sName .. "')", 1, true),
            'a swapper for ' .. sName .. ' landed; re-open the one-item choice')
    end
end

tests['[reverse] the rescuer is un-gated and runs off GetDesire'] = function()
    local src = read_file(ROAM)
    local body = src:match('function TrySwapInvItemForFlask%(%)(.-)\nend\n')
    assert(body, 'could not slice the rescuer')
    assert(not body:find('IsSoakCandidate', 1, true),
        'the rescuer grew a gate; the reachability argument no longer holds')
    assert(src:find('function ItemOpsDesire()', 1, true)
        and src:match('function ItemOpsDesire%(%).-TrySwapInvItemForFlask%(%)'),
        'the rescuer left ItemOpsDesire')
end

tests['[reverse] turbo is structural: both callers ask the situation first'] = function()
    local src = read_file(JMZ)
    -- Deliberately no IsModeTurbo() inside J.HasFieldRegenSource. The claim
    -- that makes that safe is the CALL ORDER, so the call order is what gets
    -- asserted -- charter 0ARM/0p: an unstated premise is the one that rots.
    local hold = src:match('function J%.ShouldRegenNotGoHome%( bot %)(.-)\nend\n')
    local buy  = src:match('function J%.ShouldFieldBuyRegen%( bot %)(.-)\nend\n')
    assert(hold and buy, 'could not slice the two consumers')
    for _, pair in ipairs({ { hold, 'ShouldRegenNotGoHome' },
                            { buy, 'ShouldFieldBuyRegen' } }) do
        local iSit = pair[1]:find('IsFieldRegenSituation', 1, true)
        local iSrc = pair[1]:find('HasFieldRegenSource', 1, true)
        assert(iSit and iSrc and iSit < iSrc,
            pair[2] .. ' no longer asks the situation before the source; '
            .. 'J.HasFieldRegenSource needs its own IsModeTurbo now')
    end
    local situation = src:match('function J%.IsFieldRegenSituation%( bot %)(.-)\nend\n')
    assert(situation and situation:find('IsModeTurbo', 1, true),
        'the turbo clause left the situation predicate')
    -- And nothing else calls the helper, so those two orders are the whole
    -- surface. Count the call sites off the source rather than trusting memory.
    local code = strip_comments(src)
    local function count(hay)
        local nMentions, nDefs = 0, 0
        for _ in hay:gmatch('J%.HasFieldRegenSource%(') do nMentions = nMentions + 1 end
        for _ in hay:gmatch('function J%.HasFieldRegenSource%(') do nDefs = nDefs + 1 end
        return nMentions - nDefs, nDefs
    end
    local nCalls, nDefs = count(code)
    assert(nDefs == 1, 'J.HasFieldRegenSource is defined ' .. nDefs .. ' times')
    -- ⭐ THIS USED TO PIN `nCalls == 2`, AND THE PIN WAS RED ON TRUNK BEFORE
    -- ANYONE NOTICED. 'staysrc' added a third call site on 2026-09-05 (inside
    -- J.ShouldStayAndRegen) and 'buyband' a fourth on 2026-09-06; the count was
    -- never updated, so a guard whose whole job is "a new caller may not inherit
    -- turbo" spent a day saying only "the number changed". A COUNT IS NOT THE
    -- PROPERTY: what has to hold is that every caller reaches turbo before the
    -- call, and there are exactly two legitimate ways to do that. So the property
    -- is asserted per caller and the count is kept only as an anti-vacuum floor,
    -- which is what makes a genuinely NEW caller still trip this.
    --   * via the situation predicate (ShouldRegenNotGoHome, ShouldFieldBuyRegen)
    --     -- asserted by the call-order loop above;
    --   * via its own IsModeTurbo before the call (ShouldStayAndRegen, whose
    --     first line it is; ShouldFieldBuyRegenHurt and ShouldFieldBuyRegenTower,
    --     whose second line it is).
    -- [buytower 20260906] The fifth caller joined the SECOND list, and it joined
    -- it by being read rather than by the count being raised: it repeats the
    -- situation predicate's clauses instead of calling it (so the first list
    -- cannot cover it) and carries its own IsModeTurbo on line two (so the loop
    -- below is what actually holds the property for it).
    for _, name in ipairs({ 'ShouldStayAndRegen', 'ShouldFieldBuyRegenHurt',
        'ShouldFieldBuyRegenTower' }) do
        local body = code:match('function J%.' .. name .. '%( bot %)(.-)\nend\n')
        assert(body, 'could not slice J.' .. name
            .. ', which calls J.HasFieldRegenSource without going through the '
            .. 'situation predicate')
        local iTurbo = body:find('IsModeTurbo', 1, true)
        local iSrc = body:find('HasFieldRegenSource', 1, true)
        assert(iTurbo and iSrc and iTurbo < iSrc, 'J.' .. name .. ' reaches '
            .. 'J.HasFieldRegenSource without asking IsModeTurbo first -- that '
            .. 'helper has no turbo clause of its own, so this ships the '
            .. 'behaviour into normal mode')
    end
    assert(nCalls == 5,
        'J.HasFieldRegenSource has ' .. nCalls .. ' call sites, not 5. Every '
        .. 'caller must reach turbo before calling it, either by asking '
        .. 'J.IsFieldRegenSituation first or by its own IsModeTurbo; add the new '
        .. 'one to one of the two lists above rather than only raising this number')
    -- The stripper must not have blunted the census: one more real call site
    -- still trips it, and a comment quoting the call form still does not. Stated
    -- against `nCalls` rather than against a literal, so these two keep working
    -- the next time a caller is legitimately added -- re-baselining the line
    -- above used to mean silently re-baselining these as well.
    assert(count(strip_comments(src .. '\nJ.HasFieldRegenSource( bot )\n'))
        == nCalls + 1, 'the census stopped seeing a real call site')
    assert(count(strip_comments(src .. '\n-- see J.HasFieldRegenSource( bot ) above\n'))
        == nCalls, 'a comment can still masquerade as a call site')
end

tests['[reverse] the guarded branch selects for exactly this population'] = function()
    local src = read_file(ABILITY)
    -- '撤退:3' -- the only branch `stayfield` is wired into -- fires only when
    -- the bot has NO salve in a main slot. J.IsItemAvailable reads 0..5, so
    -- "no salve" there means "no salve I can drink", which is the frame where a
    -- backpacked one is worth seeing.
    local branch = src:match('(if %( botHP < 0%.34 or botHP %+ botMP < 0%.43 %).-\n\t\tthen)')
    assert(branch, 'could not slice the 撤退:3 branch')
    assert(branch:find('J.ShouldRegenNotTpHome( bot )', 1, true),
        'the stayfield veto left the branch')
    assert(branch:find('itemFlask == nil', 1, true),
        'the branch no longer selects for "no salve in a main slot"')
    assert(src:find('local itemFlask = J.IsItemAvailable( "item_flask" )', 1, true),
        'itemFlask is no longer read through J.IsItemAvailable')
    local avail = read_file(JMZ):match('function J%.IsItemAvailable%( sItemName %)(.-)\nend\n')
    assert(avail and avail:find('slot >= 0', 1, true)
        and avail:find('slot <= 5', 1, true),
        'J.IsItemAvailable no longer restricts to the six main slots')
end

tests['[reverse] the widening is one item wide and gated, read off the source'] = function()
    local body = read_file(JMZ):match(
        'function J%.HasFieldRegenSource%( bot %)(.-)\nend\n')
    assert(body, 'could not slice J.HasFieldRegenSource')
    local block = body:match("IsSoakCandidate%( 'bagsalve' %)(.*)")
    assert(block, 'the bagsalve gate left the helper')
    assert(block:find('for i = 6, 8 do', 1, true),
        'the widening no longer reads exactly the three backpack slots')
    for _, sName in ipairs({ 'item_tango', 'item_tango_single',
                             'item_faerie_fire', 'item_bottle' }) do
        assert(not block:find(sName, 1, true),
            block and (sName .. ' entered the backpack leg'))
    end
end

return tests

-- [owner priority P2] `stayfield` and `stayfield2` wrap the IDENTICAL predicate
-- (J.ShouldRegenNotGoHome) at two call sites, and their own source says so:
-- "same core predicate, two independent call sites ... meant to be armed
-- together". This file measures what each wrapper can actually change AT ITS
-- OWN SITE on the armed string the lab is currently running, and the two
-- answers are not the same size. One of them is EMPTY.
--
-- THE ARITHMETIC
-- --------------
-- Both wrappers delegate to
--
--     J.ShouldRegenNotGoHome = IsFieldRegenSituation
--                          AND HasFieldRegenSource
--                          AND IsFieldSipEnough                 (jmz_func)
--
-- and `fieldsip` -- ADMITTED to the member string on 2026-08-29 (test_set §CG)
-- and armed in W27/W28 -- turns that last conjunct into a MAGNITUDE test:
--
--     FieldRegenSipValue( bot ) >= 0.25 * bot:GetMaxHealth()
--
-- FieldRegenSipValue is a max over J.FIELD_SIP_HEAL, and the largest entry by a
-- factor of ~3 is item_flask (400; the next is item_bottle at 135).
--
-- Now read the TP call site. `stayfield` is wired into the '撤退:3' branch of
-- ability_item_usage_generic, and that branch carries its own conjunct
--
--     and itemFlask == nil        -- itemFlask = J.IsItemAvailable("item_flask")
--
-- and J.IsItemAvailable is MAIN-SLOTS-ONLY (`slot >= 0 and slot <= 5`). So on
-- every frame where this veto can change the outcome, slots 0-5 carry no salve
-- -- which is exactly the range FieldRegenSipValue reads by default. The best
-- sip reachable there is therefore the largest NON-flask entry, 135, and
--
--     135 >= 0.25 * H   <=>   H <= 540.
--
-- The same branch also carries `bot:GetLevel() >= 9`. ⇒ **with `fieldsip`
-- armed and `bagsalve` unarmed -- the string the lab ran in W27/W28 -- the
-- counterfactual domain of `stayfield` at its only call site is EMPTY**, and
-- that is a closed form, not an estimate: no sampling, no corpus, no p-value.
--
-- ⭐ THE REUSABLE CRITERION, and it is NOT the one this family already has.
-- test_tphome_tp_leg_counterfactual pinned "a guard's domain is its predicate
-- INTERSECTED with the rest of the conjunction it was dropped into" -- an
-- intersection between the guard and ITS OWN call site, computable from two
-- files. This is the next one out: **a third id, admitted later, in another
-- file, with its own separate ruling, can empty that intersection without
-- touching either of them.** `fieldsip` is not a conjunct of the '撤退:3'
-- branch and does not name `stayfield` anywhere; it moves a threshold inside a
-- helper two calls down, and the branch's own unrelated-looking `itemFlask ==
-- nil` is what converts that move into a zero. Nothing turns red, both ids keep
-- their membership, the arm string still lists them, `check_armed_wiring.py`
-- still calls the call site WIRED (it checks that a call site exists, not that
-- the predicate can be true there), and the replay desk goes on spending rounds
-- trying to buy a condition (a) that the tree has already made unbuyable.
-- Same shape as the `pullcad` trap (a promoted id freezes a gate that names
-- it), one level further out: **here the two ids never mention each other**.
--
-- THE SECOND HALF, and it is the useful one. The WALK call site
-- (mode_retreat_generic, `stayfield2`) carries NO flask conjunct anywhere
-- between the mode entry and the call -- asserted below, not assumed -- so a
-- main-slot salve is reachable there and the ceiling is 400/0.25 = 1600 max
-- health instead of 540. **The two wrappers of one predicate do not have one
-- domain; on the current string one of them has none.** So the (a) evidence for
-- this family can only come off the WALK leg, and the read has to be banded on
-- "carries a MAIN-SLOT salve" -- items are a column the dumper already emits.
--
-- AND THE THIRD: `bagsalve` stops being a rider. Its own admission note says a
-- lone arm is "byte-for-byte a no-op" because both consumers of the predicate
-- it widens are gated. At the TP site under `fieldsip` that is inverted: the
-- backpack leg is the ONLY leg the branch's `itemFlask == nil` does not kill
-- (IsItemAvailable stops at slot 5, so a salve in slot 6-8 leaves the conjunct
-- TRUE), which makes `bagsalve` the sole enabler of `stayfield` above 540 max
-- health rather than a free passenger. Driven below on a REAL backpacked-salve
-- frame, not modelled.
--
-- WHAT THIS FILE DOES NOT CLAIM
-- -----------------------------
--   * It does not say `fieldsip` is wrong, and does not re-open its (a). Moving
--     that frame from the hold side to the supply side is its stated design.
--     What is new is the SIDE EFFECT on two other ids' measurability, which no
--     ruling registered.
--   * It does not say `stayfield` / `stayfield2` should leave or stay in the
--     member string, and it does not rule on their (a). Conditions (a)/(b)/(c)
--     are not this file's to answer; an emptiness proof is not a verdict.
--   * Zero behaviour change, zero new gate ids: every assertion here reads the
--     shipped tree or drives a real frame.
--   * The last step of the emptiness -- "a level-9 hero has more than 540 max
--     health" -- is NOT in the tree. It is measured on the fixture corpus and
--     declared as a [limit] below, exceptions named.

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')

local tests = {}

local JMZ    = 'bots/FunLib/jmz_func.lua'
local ITEMS  = 'bots/ability_item_usage_generic.lua'
local RETMOD = 'bots/mode_retreat_generic.lua'

-- Owner priority P2's own pinned frame: Lina, level 9, 1088 max health, 31.8%
-- HP, nearest enemy 6,596 units away, a faerie fire in slot 0 and an EMPTY
-- bottle in slot 5. It is the right subject twice over -- it is the frame both
-- decision-side ids were written for, and it carries no main-slot salve, which
-- is the branch conjunct the whole reduction turns on.
local LINA = 'tests/fixtures/f_260822_063722_lina_tp_home.lua'

-- A REAL frame with a REAL salve in the backpack (slot 6) and none in the main
-- slots -- the only inventory shape where the branch's `itemFlask == nil` and
-- `bagsalve`'s widening are simultaneously live. Modelled deliveries are used
-- elsewhere in this family; this leg does not need one.
local SB     = 'tests/fixtures/f_260822_182012_sb_backpack_rescue_372.lua'
local SB_HERO = 'npc_dota_hero_spirit_breaker'

local function read(path)
    local f = assert(io.open(path, 'r'), 'cannot read ' .. path)
    local s = f:read('*a')
    f:close()
    return s
end

--- Line comments only, same restriction (and same reason) as
--- test_bagsalve_backpack_source: this tree has no long-bracket comments, and a
--- general stripper would need more machinery than any claim here.
local function strip_comments(src)
    local out = {}
    for line in (src .. '\n'):gmatch('([^\n]*)\n') do
        out[#out + 1] = line:gsub('%-%-.*$', '')
    end
    return table.concat(out, '\n')
end

local function count(src, needle)
    local n, i = 0, 1
    while true do
        local a = src:find(needle, i, true)
        if a == nil then return n end
        n, i = n + 1, a + 1
    end
end

--- The body of a named function, from its `function` line to the first line
--- that is exactly `end` at column 1.
local function fn_body(src, sName)
    local i = assert(src:find('function ' .. sName .. '%('),
        'no such function in the source: ' .. sName)
    local j = assert(src:find('\nend\n', i, true),
        'unterminated function body: ' .. sName)
    return src:sub(i, j + 4)
end

--- The condition text of the '撤退:3' branch: from its marker comment to the
--- fountain assignment that ends it. The marker is asserted UNIQUE first --
--- an anchor that matches twice silently widens the span and makes every
--- assertion below read a different piece of the file than it names.
local function tp3_condition(src)
    assert(count(src, '第三种情况') == 1,
        "the '撤退:3' marker comment is no longer unique in " .. ITEMS
        .. ' -- re-anchor this file before trusting any span below')
    local i = src:find('第三种情况', 1, true)
    local j = assert(src:find('tpLoc = J.GetTeamFountain()', i, true),
        'the branch no longer ends in a fountain TP')
    return src:sub(i, j)
end

--- Load a frame with turbo forced on and an explicit armed SET, so every
--- reading below names the string it was taken on rather than inheriting one.
local function world(fix, hero, armed)
    local J, bot = rf.load(fix, hero)
    J.IsModeTurbo = function() return true end
    J.IsSoakCandidate = function(id) return (armed or {})[id] == true end
    return J, bot
end

--- Declaration: model an item handle appearing in one slot. Only the handle is
--- modelled; every clause downstream reads the real frame. Same surface (and
--- same shape) as test_bagsalve_backpack_source's deliver_flask, so the two
--- files cannot drift apart about what "a delivery" means.
local function deliver(bot, nSlot, sName, nCharges)
    local real_get = bot.GetItemInSlot
    local h = {
        GetName = function() return sName end,
        GetCurrentCharges = function() return nCharges or 0 end,
    }
    bot.GetItemInSlot = function(self, i)
        if i == nSlot then return h end
        return real_get(self, i)
    end
end

--============================================================================
-- [source] The constants and the structure this arithmetic is done on.
--============================================================================

tests['[ratchet][source] both wrappers delegate to one predicate, one call site each'] = function()
    local jmz  = read(JMZ)
    local tp   = fn_body(jmz, 'J.ShouldRegenNotTpHome')
    local walk = fn_body(jmz, 'J.ShouldRegenNotWalkHome')
    assert(tp:find("J.IsSoakCandidate( 'stayfield' )", 1, true) ~= nil,
        'the TP wrapper no longer gates on stayfield')
    assert(walk:find("J.IsSoakCandidate( 'stayfield2' )", 1, true) ~= nil,
        'the walk wrapper no longer gates on stayfield2')
    for _, body in ipairs({ tp, walk }) do
        assert(body:find('J.ShouldRegenNotGoHome( bot )', 1, true) ~= nil,
            'a wrapper stopped delegating to the shared predicate -- the '
            .. '"identical predicate, two sites" premise is gone')
    end
    -- Uniqueness of the two call sites. Everything below attributes a domain to
    -- ONE site per id; a second call site would make that attribution false
    -- without changing a single line this file reads.
    local aiug = strip_comments(read(ITEMS))
    local ret  = strip_comments(read(RETMOD))
    assert(count(aiug, 'J.ShouldRegenNotTpHome(') == 1,
        'stayfield gained or lost a call site in ' .. ITEMS)
    assert(count(ret, 'J.ShouldRegenNotWalkHome(') == 1,
        'stayfield2 gained or lost a call site in ' .. RETMOD)
    assert(count(strip_comments(read(JMZ)), 'J.ShouldRegenNotGoHome(') == 3,
        'the shared predicate is called somewhere new (expected: its own '
        .. 'definition plus the two wrappers)')
end

tests['[ratchet][source] the shared predicate is the three-conjunct chain'] = function()
    local body = fn_body(read(JMZ), 'J.ShouldRegenNotGoHome')
    assert(body:find('J.IsFieldRegenSituation( bot )', 1, true) ~= nil,
        'the situation conjunct is gone')
    assert(body:find('J.HasFieldRegenSource( bot )', 1, true) ~= nil,
        'the presence conjunct is gone')
    assert(body:find('J.IsFieldSipEnough( bot )', 1, true) ~= nil,
        'the magnitude conjunct is gone -- this whole file is arithmetic on it')
end

tests['[ratchet][source] the TP site caps the flask and floors the level'] = function()
    local cond = tp3_condition(read(ITEMS))
    assert(cond:find('not J.ShouldRegenNotTpHome( bot )', 1, true) ~= nil,
        "the stayfield veto is no longer a conjunct of '撤退:3'")
    assert(cond:find('itemFlask == nil', 1, true) ~= nil,
        'the flask conjunct is gone -- it is what empties the sip range here')
    assert(cond:find('bot:GetLevel() >= 9', 1, true) ~= nil,
        'the level floor is gone -- it is the other half of the emptiness')
    assert(cond:find('botHP < 0.34 or botHP + botMP < 0.43', 1, true) ~= nil,
        'the HP gate moved; the band claim in the header no longer holds')
end

tests['[ratchet][source] itemFlask is main-slots-only, and that is load-bearing'] = function()
    local aiug = read(ITEMS)
    assert(aiug:find('local itemFlask = J.IsItemAvailable( "item_flask" )', 1, true) ~= nil,
        'itemFlask is no longer bound from J.IsItemAvailable("item_flask")')
    local acc = fn_body(read(JMZ), 'J.IsItemAvailable')
    assert(acc:find('slot >= 0 and slot <= 5', 1, true) ~= nil,
        'J.IsItemAvailable stopped being main-slots-only -- the backpack leg '
        .. 'of the reduction (and the bagsalve reading) both change')
end

tests['[ratchet][source] the sip reader and the presence reader agree on slots'] = function()
    local jmz = read(JMZ)
    local src = fn_body(jmz, 'J.HasFieldRegenSource')
    local val = fn_body(jmz, 'J.FieldRegenSipValue')
    for _, body in ipairs({ src, val }) do
        assert(body:find('for i = 0, 5 do', 1, true) ~= nil,
            'the main-slot range moved')
        assert(body:find("J.IsSoakCandidate( 'bagsalve' )", 1, true) ~= nil,
            'the backpack widening is no longer gated on bagsalve')
        assert(body:find('for i = 6, 8 do', 1, true) ~= nil,
            'the backpack range moved')
        assert(body:find("'item_flask'", 1, true) ~= nil,
            'the backpack leg no longer admits the salve')
    end
    -- The backpack leg is flask-only in BOTH readers. If it ever admitted a
    -- second item, "the branch kills every main-slot source but the backpack
    -- salve" stops being the whole story.
    for _, sName in ipairs({ 'item_tango', 'item_tango_single',
                             'item_faerie_fire', 'item_bottle' }) do
        local i = assert(src:find('for i = 6, 8 do', 1, true))
        assert(src:find(sName, i, true) == nil,
            'the backpack leg started admitting ' .. sName)
    end
end

tests['[ratchet][source] the magnitude test, its gate and its table'] = function()
    local jmz = read(JMZ)
    local body = fn_body(jmz, 'J.IsFieldSipEnough')
    assert(body:find("if not J.IsSoakCandidate( 'fieldsip' ) then return true end", 1, true) ~= nil,
        'the fieldsip gate moved -- unarmed this conjunct must be the literal true')
    assert(body:find('J.FIELD_SIP_MIN_FRACTION * nMax', 1, true) ~= nil,
        'the magnitude comparison is no longer a fraction of max health')
    assert(jmz:find('J.FIELD_SIP_MIN_FRACTION = 0.25', 1, true) ~= nil,
        'the fraction moved; every ceiling below is 1/fraction times a heal')
end

tests['[ratchet][source] the WALK site carries no flask conjunct above the call'] = function()
    local ret = read(RETMOD)
    local i = assert(ret:find('function GetDesireHelper()', 1, true),
        'the retreat bid function was renamed')
    local j = assert(ret:find('J.ShouldRegenNotWalkHome(bot)', i, true),
        'the stayfield2 call left GetDesireHelper')
    local above = strip_comments(ret:sub(i, j))
    for _, tok in ipairs({ 'item_flask', 'itemFlask', 'IsItemAvailable' }) do
        assert(above:find(tok, 1, true) == nil,
            'the walk leg grew a flask conjunct above the call (' .. tok
            .. ') -- its ceiling is no longer 400/0.25 and the asymmetry '
            .. 'this file measures has changed')
    end
    -- The promoted veto sits ABOVE it and returns the SAME value, so the walk
    -- wrapper's marginal domain excludes every frame ShouldStayAndRegen already
    -- takes. Order is the whole content of that sentence: assert it.
    local a = assert(above:find('J.ShouldStayAndRegen(bot)', 1, true),
        'the promoted veto left the leg above the call')
    assert(a < #above, 'ordering assertion degenerated')
    assert(above:find('BOT_MODE_DESIRE_NONE', a, true) ~= nil,
        'the promoted veto no longer returns NONE, so it no longer absorbs '
        .. 'the frames stayfield2 would have taken')
end

--============================================================================
-- [arith] The closed form. Every ceiling is DERIVED from the shipped table, so
-- editing a heal value re-derives the bound instead of leaving prose behind.
--============================================================================

--- Load the real table and fraction out of the shipped tree.
local function sip_table()
    local J = rf.load(LINA)
    return J.FIELD_SIP_HEAL, J.FIELD_SIP_MIN_FRACTION
end

tests['[ratchet][arith] the TP site ceiling is 540 max health'] = function()
    local T, frac = sip_table()
    -- Reachable at the TP site with bagsalve unarmed: the six main slots, minus
    -- every salve (the branch's own `itemFlask == nil` forbids one there).
    local best = 0
    for name, heal in pairs(T) do
        if name ~= 'item_flask' and heal > best then best = heal end
    end
    assert(best == 135, 'the largest non-flask sip moved: ' .. best)
    local ceiling = best / frac
    assert(ceiling == 540, 'the TP-site ceiling moved: ' .. ceiling)
    -- The inequality itself, both sides of the knife edge.
    assert(best >= frac * ceiling, 'a bot at exactly the ceiling must pass')
    assert(not (best >= frac * (ceiling + 1)), 'one health above must fail')
end

tests['[ratchet][arith] bagsalve reopens the same site to 1600'] = function()
    local T, frac = sip_table()
    assert(T.item_flask == 400, 'the salve heal moved: ' .. tostring(T.item_flask))
    assert(T.item_flask / frac == 1600, 'the salve ceiling moved')
    -- The factor is what makes bagsalve the sole enabler rather than a rider.
    assert(T.item_flask / 135 > 2.9,
        'the salve stopped being ~3x the best non-flask sip; the "sole '
        .. 'enabler" reading rests on that gap')
end

tests['[ratchet][arith] the two wrappers of one predicate have different ceilings'] = function()
    local T, frac = sip_table()
    local tp_site   = 135 / frac            -- salve unreachable (itemFlask == nil)
    local walk_site = T.item_flask / frac   -- no flask conjunct above the call
    assert(walk_site == 1600 and tp_site == 540,
        'ceilings moved: ' .. walk_site .. ' / ' .. tp_site)
    assert(walk_site > tp_site,
        'the asymmetry inverted -- the whole "read the (a) off the walk leg" '
        .. 'recommendation depends on which site is wider')
end

--============================================================================
-- [drive] The same arithmetic on real frames, through the real helpers.
--============================================================================

-- The member string the lab actually ran in W27/W28 (test_set line 2), reduced
-- to the ids this file's predicate can see. `bagsalve` is NOT in it.
local W28 = { stayfield = true, stayfield2 = true, fieldbuy = true, fieldsip = true }

tests['[ratchet][drive] on P2 pinned frame the armed string silences BOTH ids'] = function()
    local J, bot = world(LINA, nil, W28)
    assert(bot:GetLevel() == 9, 'the pinned frame left level 9')
    assert(bot:GetMaxHealth() == 1088, 'the pinned frame max health moved')
    assert(J.IsFieldRegenSituation(bot) == true,
        'the pinned frame left the situation -- re-pin before reading below')
    assert(J.HasFieldRegenSource(bot) == true,
        'the faerie fire left slot 0; presence is what fieldsip overrides here')
    assert(J.FieldRegenSipValue(bot) == 85, 'the reachable sip moved')
    -- 85 < 0.25 * 1088 = 272.
    assert(J.ShouldRegenNotGoHome(bot) == false,
        'the shared predicate no longer refuses the pinned frame under fieldsip')
    assert(J.ShouldRegenNotTpHome(bot) == false, 'stayfield speaks again')
    assert(J.ShouldRegenNotWalkHome(bot) == false, 'stayfield2 speaks again')
end

tests['[ratchet][drive] a charged bottle does not rescue the TP site'] = function()
    local J, bot = world(LINA, nil, W28)
    -- The frame carries item_empty_bottle in slot 5; give it charges, i.e. the
    -- best sip the TP site can ever reach with no main-slot salve.
    deliver(bot, 5, 'item_bottle', 3)
    assert(J.FieldRegenSipValue(bot) == 135, 'the bottle leg stopped being 135')
    assert(J.ShouldRegenNotGoHome(bot) == false,
        '135 must still lose to 0.25 * 1088 = 272 -- if this passes, the '
        .. 'emptiness is not about the frame, it is about the arithmetic')
end

tests['[ratchet][drive] a MAIN-slot salve flips the predicate and kills the branch'] = function()
    local J, bot = world(LINA, nil, W28)
    deliver(bot, 5, 'item_flask')
    assert(J.FieldRegenSipValue(bot) == 400, 'the salve is not being read')
    assert(J.ShouldRegenNotGoHome(bot) == true,
        '400 >= 0.25 * 1088 -- the hold predicate must pass here')
    -- ...and on that exact frame the branch it guards is already dead by its
    -- OWN conjunct. The hold and the guarded branch are mutually exclusive on
    -- the salve, which is why a successful fieldbuy delivery into a main slot
    -- can never be credited to stayfield.
    assert(J.IsItemAvailable('item_flask') ~= nil,
        'the branch conjunct `itemFlask == nil` is somehow still satisfied '
        .. 'with a salve in slot 5 -- the exclusion is gone')
end

tests['[ratchet][drive] on a REAL backpacked salve, bagsalve is the sole enabler'] = function()
    -- What is driven here is the pair of conjuncts the TP site's own
    -- `itemFlask == nil` acts on -- presence and magnitude. The situation
    -- conjunct is NOT satisfiable on any backpacked-salve frame this corpus
    -- carries; that is measured and asserted in its own [limit] below, so this
    -- test drives what it can reach and claims nothing past it.
    local Joff, boff = world(SB, SB_HERO, W28)
    assert(boff:GetItemInSlot(6):GetName() == 'item_flask',
        'slot 6 is no longer a real salve on this frame; re-pin')
    assert(Joff.IsItemAvailable('item_flask') == nil,
        'the branch conjunct `itemFlask == nil` must hold: the salve is in the '
        .. 'backpack and IsItemAvailable stops at slot 5')
    assert(Joff.HasFieldRegenSource(boff) == false, 'the main slots are dry')
    assert(Joff.FieldRegenSipValue(boff) == 0, 'nothing drinkable is reachable')

    -- With bagsalve: the one leg the branch conjunct does NOT kill.
    local armed = {}
    for k, v in pairs(W28) do armed[k] = v end
    armed.bagsalve = true
    local Jon, bon = world(SB, SB_HERO, armed)
    assert(Jon.IsItemAvailable('item_flask') == nil,
        'arming bagsalve must not change the branch conjunct -- the two read '
        .. 'DIFFERENT slot ranges, and that is the whole mechanism')
    assert(Jon.HasFieldRegenSource(bon) == true, 'the backpack leg is not read')
    assert(Jon.FieldRegenSipValue(bon) == 400, 'the backpack salve is not read')
    assert(bon:GetMaxHealth() == 1378, 'the frame max health moved')
    -- 400 >= 0.25 * 1378 = 344.5
    assert(Jon.IsFieldSipEnough(bon) == true,
        'bagsalve no longer carries this frame over the magnitude bar -- it is '
        .. 'the ONLY leg that can, at the TP site, so the "sole enabler" '
        .. 'reading is gone')
end

--============================================================================
-- [control] What the emptiness is actually caused by. Without these the file
-- would read as "stayfield never fires", which is false and is not the claim.
--============================================================================

tests['[control] unarmed fieldsip, the same pinned frame holds'] = function()
    local J, bot = world(LINA, nil, { stayfield = true, stayfield2 = true })
    assert(J.IsFieldSipEnough(bot) == true,
        'unarmed, the magnitude conjunct must be the literal true')
    assert(J.ShouldRegenNotGoHome(bot) == true,
        'without fieldsip the 85-health faerie fire buys the hold -- if this '
        .. 'fails, the emptiness above is not attributable to fieldsip')
    assert(J.ShouldRegenNotTpHome(bot) == true, 'stayfield must speak here')
    assert(J.ShouldRegenNotWalkHome(bot) == true, 'stayfield2 must speak here')
end

tests['[control] the two mechanisms are independent'] = function()
    -- bagsalve alone, no fieldsip: the SB frame's presence answer flips with
    -- the magnitude test switched off entirely, so the backpack leg is not
    -- doing its work through fieldsip, and the two readings above are not one
    -- reading counted twice.
    local J, bot = world(SB, SB_HERO, { stayfield = true, stayfield2 = true, bagsalve = true })
    assert(J.IsFieldSipEnough(bot) == true,
        'unarmed fieldsip must be the literal true here')
    assert(J.HasFieldRegenSource(bot) == true, 'the backpack leg is not read')
end

tests['[control] the emptiness is not "the predicate is always false"'] = function()
    -- Same armed string as W28, a main-slot salve, and a bot small enough that
    -- even the non-flask ceiling would pass. The predicate is perfectly capable
    -- of answering TRUE under fieldsip; what is empty is the INTERSECTION with
    -- the TP branch, not the predicate.
    local J, bot = world(LINA, nil, W28)
    deliver(bot, 5, 'item_bottle', 3)
    local spec = rawget(bot, '__spec')
    spec.GetMaxHealth = 540
    rawset(bot, 'GetMaxHealth', nil)
    assert(J.ShouldRegenNotGoHome(bot) == true,
        'at exactly the derived ceiling the predicate must pass -- otherwise '
        .. 'the 540 in this file is not the number the tree computes')
end

--============================================================================
-- [limit] Written as assertions, so the day an operand arrives this file fails
-- and gets upgraded instead of quietly keeping an inference.
--============================================================================

tests['[limit] "level 9 implies more than 540 max health" is NOT in the tree'] = function()
    -- The tree contains no hero table, so the last step of the emptiness is an
    -- external operand. Measured here on the corpus instead of asserted from
    -- game knowledge: of the live hero rows at level >= 9, how many could sit
    -- under the derived ceiling at all?
    local f = assert(io.popen('ls tests/fixtures/*.lua'))
    local n9, nlow, names = 0, 0, {}
    for path in f:lines() do
        local ok, fx = pcall(dofile, path)
        if ok and type(fx) == 'table' and fx.units then
            for _, u in ipairs(fx.units) do
                if u.alive and u.level and u.max_hp and u.level >= 9 then
                    n9 = n9 + 1
                    if u.max_hp <= 540 then
                        nlow = nlow + 1
                        names[u.name] = true
                    end
                end
            end
        end
    end
    f:close()
    assert(n9 >= 300, 'the corpus shrank below the census this reading was '
        .. 'taken on (' .. n9 .. ' rows); re-measure before trusting it')
    -- 4 of 318 on 2026-08-30, and all four are ONE hero -- a reading the
    -- harness desk should look at (a level-11 hero at 230/450 max health is
    -- not a hero, it is a dump artifact), not a counterexample to the
    -- arithmetic. Named rather than rounded away.
    assert(nlow <= 6, 'rows under the ceiling grew to ' .. nlow
        .. ' -- the emptiness step needs re-deriving, not re-asserting')
    local distinct = 0
    for _ in pairs(names) do distinct = distinct + 1 end
    assert(distinct <= 1, 'the sub-ceiling rows are no longer one hero ('
        .. distinct .. ') -- they stop looking like a dump artifact')
end

tests['[limit] the retreat block is not reachable on a fixture'] = function()
    local _, bot = world(LINA, nil, W28)
    -- GH #89 (13th world assertion): the whole '撤退:N' block is behind
    -- `nMode == BOT_MODE_RETREAT`, and GetActiveMode is bot-VM state no .dem
    -- carries. So the branch side of every claim here is attributed on SOURCE
    -- and the predicate side is driven on the FRAME. The final tpscroll desire
    -- is not asserted and is not claimed.
    assert(bot:GetActiveMode() ~= BOT_MODE_RETREAT,
        'the retreat mode became reachable on a fixture -- delete this limit '
        .. 'and drive the branch end to end instead of attributing it')
end

tests['[limit] the corpus cannot drive the bagsalve leg end to end'] = function()
    -- The backpack widening needs a frame that is BOTH in the situation and
    -- carrying a salve only in the backpack. Measured over the whole corpus:
    -- 14 such inventory rows, and the situation holds on none of them (they are
    -- at full health, or someone is inside the 1600 ring). So the bagsalve
    -- reading above stops at presence + magnitude, by corpus and not by choice,
    -- and its end-to-end (a) has to come off a batch corpus.
    local f = assert(io.popen('ls tests/fixtures/*.lua'))
    local rows, in_situation = 0, 0
    for path in f:lines() do
        local ok, fx = pcall(dofile, path)
        if ok and type(fx) == 'table' and fx.units then
            for _, u in ipairs(fx.units) do
                if u.alive and type(u.items) == 'table' then
                    local bag, main = false, false
                    for i = 1, 9 do
                        if u.items[i] == 'flask' then
                            if i <= 6 then main = true else bag = true end
                        end
                    end
                    if bag and not main then
                        rows = rows + 1
                        local J, bot = world(path, u.name, { bagsalve = true })
                        if J.IsFieldRegenSituation(bot) then
                            in_situation = in_situation + 1
                        end
                    end
                end
            end
        end
    end
    f:close()
    assert(rows >= 10, 'the backpack-salve population shrank to ' .. rows
        .. ' rows; re-measure before quoting this limit')
    assert(in_situation == 0, in_situation .. ' backpacked-salve frame(s) now '
        .. 'satisfy the situation -- delete this limit and drive '
        .. 'J.ShouldRegenNotGoHome end to end on one of them instead')
end

tests['[limit] this file rules on nobody'] = function()
    -- An emptiness proof is not a verdict. Asserted so a later reader cannot
    -- quote this file as one: nothing here reads a membership file, a promote
    -- record, or a condition (a)/(b)/(c) result -- only the shipped tree and
    -- the fixture corpus.
    local body = strip_comments(read('tests/test_stayfield_callsite_domain.lua'))
    -- Split so the needle is not itself a match. A self-scanning assertion that
    -- fires on its own literal reads as a finding and is not one.
    local BOOKKEEPING = 'iter' .. 'ations/'
    assert(body:find(BOOKKEEPING, 1, true) == nil,
        'this file started reading the lab bookkeeping -- it is an arithmetic '
        .. 'ratchet, not a ruling')
    for _, path in ipairs({ JMZ, ITEMS, RETMOD, LINA, SB }) do
        assert(body:find(path, 1, true) ~= nil,
            'a subject path left this file: ' .. path)
    end
end

return tests

-- [owner priority P2] `tphome` (J.ShouldStayAndRegen) is PROMOTED -- live in
-- every turbo game -- and it has TWO call sites. This file measures what the
-- conjunct can actually change at each of them, and the two answers are not
-- remotely the same size.
--
-- THE ARITHMETIC
-- --------------
-- The helper's own band is
--
--     if nHP < 0.18 or nHP > 0.75 then return false end        (jmz_func)
--
-- and the tpscroll leg wires it into the '撤退:1' branch, whose FIRST conjunct is
--
--     if botHP < 0.19
--         and not J.ShouldStayAndRegen( bot )                  (ability_item_usage_generic)
--
-- A guard placed inside a conjunction can only change an outcome on the frames
-- where every OTHER conjunct already holds. Here that intersects a 57pp band
-- with a 19pp one and leaves **[0.18, 0.19) -- one percentage point of HP**.
-- The other call site (mode_retreat_generic, the walk leg) carries no HP cap at
-- all between the mode entry and the call, so there the full band is live.
--
-- ⭐ THE REUSABLE CRITERION. A guard's domain is not the domain of its own
-- predicate; it is that domain INTERSECTED with the rest of the conjunction it
-- was dropped into. When the branch's own threshold sits one hundredth above
-- the guard's own floor, the guard is very nearly a no-op AT THAT SITE while
-- reading -- in its own source and in the call site's comment -- like the
-- mechanism. The failure direction is the expensive one: nothing turns red, the
-- id keeps its promote verdict, and the leg goes on being described as guarded,
-- so nobody looks for the id that is actually missing there. That is not
-- hypothetical here: `stayfield` was opened later for '撤退:3' *because* it
-- "carries no regen veto at all", and '撤退:1' was passed over as the one that
-- has one.
--
-- THE SECOND REDUCTION, and it is the sharper half. On the frames where this
-- conjunct can change the outcome, the branch's other conjuncts are all true --
-- and three of them negate, one by one, every disjunct of the helper's own
-- regen test:
--
--     helper:  bHasFlask = J.IsItemAvailable('item_flask') ~= nil
--                       or bot:HasModifier('modifier_flask_healing')
--                       or bot:HasModifier('modifier_tango_heal')
--     branch:  itemFlask == nil                    -- itemFlask = J.IsItemAvailable("item_flask")
--          and not bot:HasModifier("modifier_tango_heal")
--          and not bot:HasModifier("modifier_flask_healing")
--
-- The first pair is the SAME accessor with the SAME argument on the SAME frame.
-- So on every frame in the counterfactual set `bHasFlask` is false, and the
-- helper's last line degenerates to `bot:GetGold() >= 90`. Read the helper
-- alone and it looks like "carries a heal OR can buy one"; read it at this call
-- site and it is a pure gold test. That degeneration is not visible in the
-- helper's source -- only at the call site.
--
-- WHAT THIS FILE DOES NOT CLAIM
-- -----------------------------
--   * It does not say the promote verdict for `tphome` (GH #2: +51 GPM /
--     +54 XPM / -0.32 deaths over 28 games) was wrong. It says the verdict
--     cannot have been bought at this call site, because this call site can
--     move at most a 1pp HP sliver -- so the measured effect belongs to the
--     walk leg. Attribution, not correctness.
--   * It does not touch shipped behaviour. Zero gate ids, zero action changes.
--   * It cannot drive X.ConsiderItemDesire["item_tpscroll"] end to end: GH #89
--     (13th world assertion) -- GetActiveMode is bot-VM state absent from every
--     .dem, so `nMode == BOT_MODE_RETREAT` is false on every fixture. Asserted
--     below rather than footnoted, so the day that gap closes this file fails
--     and gets upgraded instead of quietly keeping an inference.
--   * The damage window is a DECLARED input: the subject frame answers TRUE to
--     WasRecentlyDamagedByAnyHero(3.0) (a global ult), which the helper vetoes
--     on. The counterfactual set needs damage in (3, 8], and the fixture corpus
--     carries no frame in it. Declared, and the declaration is itself asserted.

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')

local tests = {}

-- The frame owner priority P2 pins: Lina at 31.8% HP, nearest enemy 6,596u,
-- ~10,000u from her own fountain, on her way into a 20.3s fountain trip. It is
-- the right subject here for a reason that is not sentiment: it is a REAL frame
-- of the exact situation both call sites exist to arbitrate, and it carries no
-- flask in a usable slot -- which is the branch conjunct the second reduction
-- turns on.
local LINA = 'tests/fixtures/f_260822_063722_lina_tp_home.lua'

local JMZ    = 'bots/FunLib/jmz_func.lua'
local ITEMS  = 'bots/ability_item_usage_generic.lua'
local RETMOD = 'bots/mode_retreat_generic.lua'

local function read(path)
    local f = assert(io.open(path, 'r'), 'cannot read ' .. path)
    local s = f:read('*a')
    f:close()
    return s
end

--- The body of a named function, from its `function` line to the first line
--- that is exactly `end` at column 1.
local function fn_body(src, sName)
    local i = src:find('function ' .. sName .. '%(', 1)
    if i == nil then i = src:find('function ' .. sName .. ' *%( *bot *%)', 1) end
    assert(i ~= nil, 'no such function in the source: ' .. sName)
    local j = src:find('\nend\n', i, true)
    assert(j ~= nil, 'unterminated function body: ' .. sName)
    return src:sub(i, j + 4)
end

--- Load the subject with turbo forced on and every soak id disarmed.
--- J.ShouldStayAndRegen carries no gate of its own (it is promoted), so an
--- armed id could only reach this file through some other helper; disarming
--- everything keeps that door shut and makes the reading unambiguous.
local function subject()
    local J, bot = rf.load(LINA)
    J.IsModeTurbo = function() return true end
    J.IsSoakCandidate = function() return false end
    return J, bot
end

--- J.GetHP reads OriginalGetHealth for an own-team unit (jmz_func:3720), so a
--- setter that moves only GetHealth would leave the helper reading the real
--- frame and every band assertion below would pass without measuring anything.
local function set_hp(bot, f)
    local spec = rawget(bot, '__spec')
    spec.GetHealth = math.floor(bot:GetMaxHealth() * f + 0.5)
    spec.OriginalGetHealth = spec.GetHealth
    rawset(bot, 'GetHealth', nil)
    rawset(bot, 'OriginalGetHealth', nil)
end

local function set_gold(bot, n)
    local spec = rawget(bot, '__spec')
    spec.GetGold = n
    rawset(bot, 'GetGold', nil)
end

--- Declare the counterfactual damage window: hit by a hero between 3 and 8
--- seconds ago. That is the only window in which the branch's own damage
--- clause (8.0) is true while the helper's (3.0) is false, i.e. the only
--- window where both can hold at once.
local function declare_damage_window(bot)
    local spec = rawget(bot, '__spec')
    spec.WasRecentlyDamagedByAnyHero = function(_, t) return t > 3.0 end
    rawset(bot, 'WasRecentlyDamagedByAnyHero', nil)
end

--============================================================================
-- The two constants, read off the shipped source.
--============================================================================

tests['[ratchet][source] the helper floors at 0.18 and ceilings at 0.75'] = function()
    local body = fn_body(read(JMZ), 'J.ShouldStayAndRegen')
    assert(body:find('nHP < 0.18 or nHP > 0.75', 1, true) ~= nil,
        'the band literals moved; this whole file is arithmetic on them:\n' .. body)
    -- The three other clauses, pinned so a rewrite that changes what the guard
    -- asks cannot leave the arithmetic below describing a helper that is gone.
    assert(body:find('WasRecentlyDamagedByAnyHero( 3.0 )', 1, true) ~= nil,
        'the 3.0s danger read is gone')
    assert(body:find('J.GetNearbyHeroes( bot, 1200, true, BOT_MODE_NONE )', 1, true) ~= nil,
        'the 1200 ring is gone')
    assert(body:find('bot:GetGold() < 90', 1, true) ~= nil,
        'the 90-gold affordability clause is gone')
end

tests['[ratchet][source] the tpscroll site caps the same quantity at 0.19'] = function()
    local src = read(ITEMS)
    local i = src:find('第一种情况', 1, true)
    assert(i ~= nil, "the '撤退:1' retreat branch lost its marker comment")
    local j = src:find('tpLoc = J.GetTeamFountain()', i, true)
    assert(j ~= nil, 'the branch no longer ends in a fountain TP')
    local cond = src:sub(i, j)
    assert(cond:find('botHP < 0.19', 1, true) ~= nil,
        "'撤退:1' no longer caps at 0.19:\n" .. cond)
    assert(cond:find('not J.ShouldStayAndRegen( bot )', 1, true) ~= nil,
        'the promoted veto is no longer a conjunct of this branch')
    -- The three conjuncts that make the second reduction go through.
    assert(cond:find('itemFlask == nil', 1, true) ~= nil, 'the flask conjunct is gone')
    assert(cond:find('not bot:HasModifier( "modifier_tango_heal" )', 1, true) ~= nil,
        'the tango_heal conjunct is gone')
    assert(cond:find('not bot:HasModifier( "modifier_flask_healing" )', 1, true) ~= nil,
        'the flask_healing conjunct is gone')
    assert(cond:find('bot:WasRecentlyDamagedByAnyHero( 8.0 )', 1, true) ~= nil,
        'the 8.0s damage clause is gone -- the (3,8] window claim rests on it')
end

tests['[ratchet][source] itemFlask is the SAME accessor the helper asks'] = function()
    local src = read(ITEMS)
    assert(src:find('local itemFlask = J.IsItemAvailable( "item_flask" )', 1, true) ~= nil,
        'itemFlask is no longer bound from J.IsItemAvailable("item_flask")')
    local body = fn_body(read(JMZ), 'J.ShouldStayAndRegen')
    assert(body:find("J.IsItemAvailable( 'item_flask' ) ~= nil", 1, true) ~= nil,
        'the helper no longer reads the same accessor -- the reduction is off')
    -- And the accessor really is main-slots-only, which is why "no flask" on
    -- this branch means "no flask the helper can see" too, and not merely
    -- "no flask in the six usable slots but maybe one in the backpack".
    local acc = fn_body(read(JMZ), 'J.IsItemAvailable')
    assert(acc:find('slot >= 0 and slot <= 5', 1, true) ~= nil,
        'J.IsItemAvailable stopped being main-slots-only')
end

tests['[ratchet][arith] the intersection at the tpscroll site is 1pp wide'] = function()
    local FLOOR, CEIL, CAP = 0.18, 0.75, 0.19
    local nOwn = CEIL - FLOOR
    local nHere = CAP - FLOOR
    assert(nHere > 0, 'if the cap ever drops to or below the floor the conjunct '
        .. 'becomes DEAD, not merely narrow -- that is a different finding')
    assert(nHere <= 0.02, string.format(
        'the sliver grew to %.3f; re-read the call site before trusting this file', nHere))
    assert(nOwn / nHere >= 20, string.format(
        'the helper band is only %.1fx the sliver', nOwn / nHere))
end

tests['[ratchet][source] the walk leg carries no HP cap above its call'] = function()
    local src = read(RETMOD)
    local i = src:find('botHP          = J.GetHP(bot)', 1, true)
    assert(i ~= nil, 'the retreat mode no longer caches botHP where it did')
    local j = src:find('if J.ShouldStayAndRegen(bot) then', i, true)
    assert(j ~= nil, 'the walk-leg call site moved')
    local slice = src:sub(i, j)
    -- Exactly one botHP comparison stands between the cache and the call, and
    -- it is the pre-horn block (DotaTime() < 0), which cannot clip the band in
    -- a running game. Anything else appearing here is a new cap and turns this
    -- file red on purpose.
    local nCmp, nPreHorn = 0, 0
    for line in slice:gmatch('[^\n]+') do
        if line:find('botHP%s*[<>]') then
            nCmp = nCmp + 1
            if line:find('DotaTime() < 0', 1, true) then nPreHorn = nPreHorn + 1 end
        end
    end
    assert(nCmp == 1 and nPreHorn == 1, string.format(
        'expected exactly one pre-horn botHP comparison above the call, saw %d (%d pre-horn)',
        nCmp, nPreHorn))
end

--============================================================================
-- The frame, and what the helper does on it.
--============================================================================

tests['[world] the subject frame is the P2 frame, and it vetoes on damage'] = function()
    local J, bot = subject()
    assert(bot:GetUnitName() == 'npc_dota_hero_lina', 'subject is Lina')
    local nHP = bot:GetHealth() / bot:GetMaxHealth()
    assert(math.abs(nHP - 0.318) < 0.005, string.format(
        'the frame moved: 31.8%% expected, saw %.3f', nHP))
    -- The helper is FALSE here, and not because of the band: 0.318 is inside
    -- [0.18, 0.75]. It is the unattributed 3.0s damage read (a Zeus ult from
    -- 7,533u), which is the blind spot `stayfield` was opened for.
    assert(bot:WasRecentlyDamagedByAnyHero(3.0) == true,
        'the frame no longer carries the global-ult damage read')
    assert(J.ShouldStayAndRegen(bot) == false,
        'the promoted veto stands down on this frame -- that is GH #111 §2.4')
end

tests['[world] no flask the helper can see, and no heal modifier'] = function()
    local _, bot = subject()
    for i = 0, 5 do
        local it = bot:GetItemInSlot(i)
        assert(it == nil or it:GetName() ~= 'item_flask',
            'the frame grew a main-slot flask; the reduction below needs none')
    end
    assert(bot:HasModifier('modifier_flask_healing') == false, 'no salve running')
    assert(bot:HasModifier('modifier_tango_heal') == false, 'no tango running')
end

tests['[reduce] in the counterfactual set the veto is a pure gold test'] = function()
    local J, bot = subject()
    declare_damage_window(bot)
    set_hp(bot, 0.185)              -- inside the 1pp sliver
    set_gold(bot, 89)
    assert(J.ShouldStayAndRegen(bot) == false,
        '89 gold and nothing drinkable: the helper cannot answer TRUE')
    set_gold(bot, 90)
    assert(J.ShouldStayAndRegen(bot) == true,
        '90 gold is the ONLY thing that moved -- at this call site the "carries '
        .. 'a heal OR can buy one" disjunction has no first half')
end

tests['[axis] the sliver has both edges, measured on the real frame'] = function()
    local J, bot = subject()
    declare_damage_window(bot)
    set_gold(bot, 90)
    set_hp(bot, 0.175)
    assert(J.ShouldStayAndRegen(bot) == false, 'below the floor: genuine escape stands')
    set_hp(bot, 0.185)
    assert(J.ShouldStayAndRegen(bot) == true, 'inside the sliver: the veto bites')
    set_hp(bot, 0.195)
    assert(J.ShouldStayAndRegen(bot) == true,
        'the HELPER is still true here -- and the BRANCH is already out of reach, '
        .. 'which is the whole point: past 0.19 the conjunct guards nothing')
end

tests['[axis] grid: the helper band is ~57pp, its reach at this site ~1pp'] = function()
    local J, bot = subject()
    declare_damage_window(bot)
    set_gold(bot, 90)
    local nHelper, nHere, nMin, nMax = 0, 0, nil, nil
    for k = 20, 160 do             -- HP 0.100 .. 0.800 in 0.005 steps
        local f = k / 200
        set_hp(bot, f)
        if J.ShouldStayAndRegen(bot) then
            nHelper = nHelper + 1
            if f < 0.19 then       -- the branch's own cap
                nHere = nHere + 1
                nMin = nMin or f
                nMax = f
            end
        end
    end
    assert(nHelper >= 100, 'the helper band collapsed: ' .. nHelper .. ' grid points')
    assert(nHere >= 1 and nHere <= 4, string.format(
        'the reachable set at this site is %d grid points, expected 1..4', nHere))
    assert(nMin ~= nil and nMin >= 0.18 and nMax ~= nil and nMax < 0.19, string.format(
        'reachable set [%s, %s] is not [0.18, 0.19)', tostring(nMin), tostring(nMax)))
    assert(nHelper / nHere >= 20, string.format(
        'ratio collapsed to %.1fx -- the finding is that it is large', nHelper / nHere))
end

--============================================================================
-- Controls. Without these an "always true" or "always false" helper passes.
--============================================================================

tests['[control] non-turbo: the helper is false everywhere on the grid'] = function()
    local J, bot = subject()
    J.IsModeTurbo = function() return false end
    declare_damage_window(bot)
    set_gold(bot, 9999)
    for k = 20, 160 do
        set_hp(bot, k / 200)
        assert(J.ShouldStayAndRegen(bot) == false,
            'turbo-only: normal-mode games must see shipped behaviour at ' .. (k / 200))
    end
end

tests['[control] damage inside 3.0s kills the TRUE at every HP'] = function()
    local J, bot = subject()
    set_gold(bot, 9999)            -- the real frame's 3.0s read is already TRUE
    for k = 30, 150 do
        set_hp(bot, k / 200)
        assert(J.ShouldStayAndRegen(bot) == false,
            'unattributed recent damage vetoes at ' .. (k / 200))
    end
end

--============================================================================
-- Limits, written as assertions.
--============================================================================

tests['[limit] the consider function is not reachable on a fixture'] = function()
    local _, bot = subject()
    -- GH #89 (13th world assertion). The whole retreat block is behind
    -- `nMode == BOT_MODE_RETREAT`, and GetActiveMode is bot-VM state that no
    -- .dem carries. So the branch attribution above is done on the SOURCE and
    -- the helper is driven on the FRAME; the final tpscroll desire is not
    -- asserted and is not claimed.
    assert(bot:GetActiveMode() ~= BOT_MODE_RETREAT,
        'the retreat mode became reachable on a fixture -- delete this limit and '
        .. 'drive the branch end to end instead of attributing it')
end

tests['[limit] the (3,8] damage window is declared, not photographed'] = function()
    local _, bot = subject()
    -- Every clause above that needs "hit 3-8 seconds ago" runs on the declared
    -- stub, because the real frame answers TRUE at 3.0. If the corpus ever
    -- grows a frame in the window, this assertion is the reminder to use it.
    assert(bot:WasRecentlyDamagedByAnyHero(3.0) == true
        and bot:WasRecentlyDamagedByAnyHero(8.0) == true,
        'the subject frame is INSIDE the 3s window on both reads, which is why '
        .. 'the counterfactual window has to be declared')
end

return tests

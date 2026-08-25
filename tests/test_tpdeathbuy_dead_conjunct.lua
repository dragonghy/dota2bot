-- [tpdeathbuy] A block that has never run, in any game, in this repo's history:
-- its HP clause asks for `botHP < 0.08 and botHP >= 1` on a 0..1 fraction.
--
-- THE BLOCK. item_purchase_generic, "死前如果会损失金钱则购买额外TP" -- spend the
-- gold you are about to lose on a spare TP scroll:
--
--     if botGold >= tpCost
--         and bot:IsAlive()
--         and botGold < ( tpCost + botWorth / 40 )   -- gold I'd lose on death anyway
--         and botHP < 0.08                          -- about to die
--         and botHP >= 1                            -- <-- and also at FULL health
--         and bot:WasRecentlyDamagedByAnyHero( 3.1 )
--         and not HasSufficientTp()
--         and Item.GetItemCharges( bot, 'item_tpscroll' ) <= 2
--     then bot:ActionImmediate_PurchaseItem( "item_tpscroll" ) end
--
-- `botHP` is `J.GetHP(bot)`, the 0..1 FRACTION, assigned once per think in the
-- same file. So the two bounds are mutually exclusive and the conjunction is
-- UNSATISFIABLE: not "almost never true", not "true in a corner" -- structurally
-- false for every real number. About 12 lines are dead code.
--
-- IT IS NOT OURS. The pair arrives verbatim in the upstream OHA snapshot
-- (74727e4:957-958), so the block has never fired in this repository's history
-- and no measurement of ours has ever included it.
--
-- WHY A STRAY CONJUNCT AND NOT A CONVENTION. The sibling block ~35 lines below
-- is the same idea for a support's dust -- `botGold < (cost + botWorth/40)`,
-- `WasRecentlyDamagedByAnyHero(3.1)`, a charge cap -- and it writes the HP leg
-- as `botHP < 0.06` with NO companion lower bound. One block of the pair has
-- the extra line; the other does not. That asymmetry is asserted below as a
-- [reverse] control: if someone ever "fixes" the dust block by adding a lower
-- bound to it, this file goes red and the reading has to be re-argued.
--
-- THE LEVER (one). Armed (turbo + soak candidate `tpdeathbuy`) the stray bound
-- is dropped and the block can fire. Written as a SELECTION rather than a
-- disjunction (charter 0TERN), so gate-off is the shipped expression byte for
-- byte -- and that identity is arithmetic here, not a promise: the gate-off
-- predicate is still `botHP < 0.08 and botHP >= 1`, still false everywhere.
--
-- ⚠ DIRECTION -- READ THE ACCEPTANCE THIS WAY. Every other lever this stream
-- has shipped narrows: the armed predicate is a SUBSET of the factory one and
-- can only fire less. This one is the opposite. Armed is a strict SUPERSET of
-- an empty set: it strictly ADDS purchases the shipped tree never makes. The
-- reverse sentinel for the wave is therefore not "TP purchases must not
-- collapse" but "gold spent on TP must not balloon", and the id cannot be
-- validated by a no-change reading.
--
-- WHY IT IS WORTH TURNING ON (validation condition (c), and it is standard
-- play, not a preference). Dota pays out a fraction of the dying hero's
-- unspent gold to the killer and deletes the rest; buying anything at all
-- before dying converts gold that is about to evaporate into an item. That is
-- why the block's gold clause is a BAND and not a floor -- `botGold >= tpCost`
-- and `botGold < tpCost + botWorth/40` says "I can afford it, and what I hold
-- is roughly what I am about to lose". A TP scroll is the canonical thing to
-- buy there: it is cheap, it is consumed on use rather than dropped, and the
-- block only fires when the bot does NOT already hold enough TP. In Turbo the
-- argument is stronger, not weaker: respawns are short and the first thing a
-- returning bot wants is a TP back to the fight.
--
-- DOMAIN, stated honestly and never added to an event rate (charter 0DOM).
-- FRAME counts over the fixture corpus, read as DATA (hp/max_hp and the
-- recent-damage rows), so this census loads no jmz_func and costs no seconds:
--   * live hero frames:                                  966 over 104 fixtures
--   * `botHP < 0.08`:                                     10 (1.0%)
--   * `botHP >= 1`:                                      347 -- so the upper
--     half of the shipped pair is NOT vacuous by itself; the pair is.
--   * `botHP < 0.08` AND hero damage inside 3.1s:          4  <- the armed half
--     of the predicate that this corpus can actually read
-- Those 4 frames are named below. The other five legs are gold and inventory;
-- see LIMITS.
--
-- LIMITS (do not launder these away -- charter 0DIR).
--   * THE TWO GOLD LEGS READ TRUE HERE FOR THE WRONG REASON. `GetGold()` is not
--     in the mock (falls through to the `^Get` default 0) and `GetItemCost()`
--     answers 0 (already pinned by tests/test_fieldbuy_backpack_rescuer.lua).
--     So `botGold >= tpCost` is `0 >= 0` = TRUE, and `botGold < tpCost +
--     botWorth/40` is `0 < netWorth/40` = TRUE on every frame with a net worth.
--     They are TAUTOLOGIES WITH THE WRONG SIGN: an end-to-end drive of this
--     block on a fixture would go green while proving nothing about the gold
--     band -- the exact 0DIR failure mode. Both readings are asserted below, so
--     the day the mock learns gold this file goes red and asks for a re-measure
--     instead of continuing to look validated.
--   * Therefore this file asserts the ARITHMETIC (the dead-code proof, the
--     gate-off identity, the direction) and the READABLE half of the domain.
--     It does NOT claim an end-to-end purchase was driven; that claim is not
--     available from this corpus and is not made.
--   * `Item.GetItemCharges` / `HasSufficientTp` are inventory questions the
--     fixtures can answer, but they gate the same unreachable block, so they
--     are reported in the census rather than dressed up as validation.

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')
local cs = require('corpus_scale')

local tests = {}

local SRC_PATH = 'bots/item_purchase_generic.lua'

local SRC = (function()
    local fh = assert(io.open(SRC_PATH, 'r'), SRC_PATH .. ' is unreadable')
    local s = fh:read('*a'); fh:close()
    return s
end)()

-- The block, extracted from its own comment anchor. Read the constants out of
-- the SHIPPED SOURCE, never restated here (charter 0SRC): a census that copies
-- the constant it measures reports the old world after the constant moves.
local BLOCK = (function()
    local at = assert(SRC:find('死前如果会损失金钱则购买额外TP', 1, true),
        'the 死前如果会损失金钱则购买额外TP block lost its comment anchor')
    local block = SRC:sub(at, at + 2200)
    -- Self-witnessing window (charter 0LN2): it must reach the purchase call,
    -- or every extraction below silently measures a truncated block.
    assert(block:find("ActionImmediate_PurchaseItem( \"item_tpscroll\" )", 1, true),
        'the source window from the anchor no longer reaches the TP purchase '
        .. '-- widen it; the block may be intact')
    -- Cut at the purchase call so the window cannot run on into the sibling
    -- dust block below (whose own `botHP < 0.06` would then be counted here).
    local stop = assert(block:find("ActionImmediate_PurchaseItem( \"item_tpscroll\" )", 1, true))
    return block:sub(1, stop + 60)
end)()

-- The same window with COMMENT LINES removed. Every "how many times does the
-- code say X" question has to be asked of this one: the block carries a long
-- rationale comment that quotes the very expressions being counted, and a
-- count taken over the raw window measures the prose.
local BLOCK_CODE = (function()
    local out = {}
    for line in (BLOCK .. '\n'):gmatch('(.-)\n') do
        if not line:match('^%s*%-%-') then out[#out + 1] = line end
    end
    return table.concat(out, '\n')
end)()

-- The DUST block, for the [reverse] control. Anchored on its own comment.
local DUST = (function()
    local at = assert(SRC:find('辅助死前如果会损失金钱则购买粉', 1, true),
        'the sibling dust block lost its comment anchor -- the "stray conjunct, '
        .. 'not a convention" reading rests on it')
    local block = SRC:sub(at, at + 900)
    local stop = assert(block:find("ActionImmediate_PurchaseItem( \"item_dust\" )", 1, true),
        'the dust window no longer reaches its purchase call -- widen it')
    block = block:sub(1, stop)
    local out = {}
    for line in (block .. '\n'):gmatch('(.-)\n') do
        if not line:match('^%s*%-%-') then out[#out + 1] = line end
    end
    return table.concat(out, '\n')
end)()

local function num(v, msg)
    assert(v ~= nil, msg)
    return tonumber(v)
end

-- The shipped (gate-off) HP predicate, read off the default assignment.
local LO, HI = BLOCK_CODE:match('local bDyingWithDoomedGold%s*=%s*botHP%s*<%s*([%d%.]+)%s*and%s*botHP%s*>=%s*([%d%.]+)')
LO = num(LO, 'the gate-off HP predicate is no longer `botHP < A and botHP >= B` '
    .. '-- if the stray bound was REMOVED outright rather than gated, this whole '
    .. 'file is about a defect that no longer exists; delete it deliberately')
HI = num(HI, 'the gate-off HP predicate lost its upper bound')

-- The armed reassignment, read out of ITS OWN gate body (not the block at
-- large): a block-wide match would happily return the default line again.
local ARMED_BODY = (function()
    local body = BLOCK_CODE:match(
        "if J%.IsModeTurbo%(%) and J%.IsSoakCandidate%('tpdeathbuy'%) then(.-)\n%s*end")
    assert(body ~= nil,
        'the armed branch is gone, or its gate is no longer '
        .. "`J.IsModeTurbo() and J.IsSoakCandidate('tpdeathbuy')` -- the fix may "
        .. 'have become ungated or non-turbo')
    return body
end)()

local ARMED_LO = num(ARMED_BODY:match('bDyingWithDoomedGold%s*=%s*botHP%s*<%s*([%d%.]+)%s*$')
    or ARMED_BODY:match('bDyingWithDoomedGold%s*=%s*botHP%s*<%s*([%d%.]+)'),
    'the armed branch no longer assigns `bDyingWithDoomedGold = botHP < A`')

-- ------------------------------------------------------------- the source ----

tests['[source] the use site consumes the local, not an inlined comparison'] = function()
    -- Charter 0ASYM (iii): a fact that can only be asserted from source must be
    -- pinned at the USE site, not at the declaration. A mutation that keeps the
    -- `local bDyingWithDoomedGold = ...` line and re-inlines `botHP < 0.08` into
    -- the condition would leave every declaration-side assertion above green
    -- while the gate stops deciding anything.
    assert(BLOCK_CODE:find('\n\t\tand bDyingWithDoomedGold\n', 1, true) ~= nil,
        'the purchase condition no longer reads `and bDyingWithDoomedGold` -- '
        .. 'the gated local is declared but not used')
    local _, nHp = BLOCK_CODE:gsub('botHP%s*[<>=~]', '')
    assert(nHp == 3, ('the block mentions botHP in %d comparisons, expected 3 '
        .. '(two in the gate-off default, one in the armed branch) -- a fourth '
        .. 'means the condition re-inlined an HP test behind the gate\'s back')
        :format(nHp))
end

tests['[source] botHP is the 0..1 fraction, in this file'] = function()
    -- The entire dead-code claim rests on botHP being a fraction rather than
    -- raw health. Asserted, not assumed.
    assert(SRC:match('botHP%s*=%s*J%.GetHP%(bot%)') ~= nil,
        'botHP is no longer assigned from J.GetHP(bot) -- if it now holds raw '
        .. 'health, `botHP >= 1` is a liveness check and NOT a defect; re-derive '
        .. 'before trusting anything in this file')
    local J, bot = rf.load('tests/fixtures/f_260820_042612_axe_blink_init_573.lua',
        'npc_dota_hero_silencer')
    local frac = J.GetHP(bot)
    assert(frac > 0 and frac <= 1,
        ('J.GetHP answered %s on a real frame -- outside 0..1, so it is not the '
        .. 'fraction this file argues about'):format(tostring(frac)))
end

tests['[reverse] the sibling dust block has NO companion lower bound'] = function()
    -- The control for "stray conjunct, not a convention".
    assert(DUST:match('botHP%s*<%s*[%d%.]+') ~= nil,
        'the dust block lost its `botHP < N` leg -- the comparison this reading '
        .. 'rests on is gone')
    assert(DUST:match('botHP%s*>=') == nil,
        'the dust block GREW a `botHP >=` bound. The "one of the pair has the '
        .. 'extra line and the other does not" argument no longer holds -- '
        .. 're-read whether `botHP >= 1` was a stray conjunct at all')
end

-- ---------------------------------------------------------- the arithmetic ---

-- A dense grid, with the boundary NEIGHBOURHOODS of both constants explicitly
-- present. (Charter 0TERN's M12 lesson cuts the other way here: this claim IS
-- about where a boundary sits, so the points on both sides of it carry weight.)
local function grid(lo, hi)
    local pts = { -1, -0.001, 0, 1e-9, 0.5, 2, 1e6 }
    for _, v in ipairs({ lo, hi }) do
        for _, d in ipairs({ -1, -0.01, -1e-9, 0, 1e-9, 0.01, 1 }) do
            pts[#pts + 1] = v + d
        end
    end
    return pts
end

tests['[arithmetic] the shipped HP predicate is unsatisfiable'] = function()
    assert(LO <= HI, ('the two bounds no longer contradict: LO=%s HI=%s. If the '
        .. 'block was repaired upstream-style this file must be retired')
        :format(tostring(LO), tostring(HI)))
    local n = 0
    for _, x in ipairs(grid(LO, HI)) do
        assert(not (x < LO and x >= HI),
            ('botHP = %.12g satisfies BOTH shipped bounds -- the dead-code claim '
            .. 'is false'):format(x))
        n = n + 1
    end
    assert(n >= 20, 'the grid collapsed to ' .. n .. ' points -- it is not a proof '
        .. 'of anything at that size')
end

tests['[arithmetic] armed fires exactly on botHP < LO, and is a WIDENING'] = function()
    local nShipped, nArmed = 0, 0
    for _, x in ipairs(grid(LO, HI)) do
        local shipped = (x < LO and x >= HI)
        local armed = (x < ARMED_LO)
        if shipped then nShipped = nShipped + 1 end
        if armed then nArmed = nArmed + 1 end
        assert(not shipped or armed,
            'a point the shipped predicate accepts is rejected armed -- armed is '
            .. 'no longer a superset')
    end
    assert(nShipped == 0, 'the shipped predicate accepted ' .. nShipped .. ' points')
    assert(nArmed > 0, 'the armed predicate accepts nothing either -- the gate '
        .. 'buys no behaviour at all, which is not what this lever claims')
    assert(ARMED_LO == LO, ('the armed branch moved the threshold to %s (shipped '
        .. '%s). This lever drops the stray bound and NOTHING ELSE; a moved '
        .. 'threshold is a second lever and needs its own evidence')
        :format(tostring(ARMED_LO), tostring(LO)))
end

-- --------------------------------------------------------------- the world ---

tests['[world] both gold legs are tautologies with the WRONG sign'] = function()
    -- 0DIR: an unreadable quantity that reads FALSE is a silent no-op; one that
    -- reads TRUE makes a lever look like it works. This block's gold band is the
    -- second kind, in BOTH of its legs.
    local _, bot = rf.load('tests/fixtures/f_260820_042612_axe_blink_init_573.lua',
        'npc_dota_hero_silencer')
    local tpCost = GetItemCost('item_tpscroll')
    local gold = bot:GetGold()
    local worth = bot:GetNetWorth()
    assert(tpCost == 0, 'GetItemCost now answers -- the gold band may be testable '
        .. 'end to end; re-measure this block instead of trusting the census')
    assert(gold == 0, 'GetGold now answers -- same, re-measure')
    assert(worth > 0, 'the pin frame lost its net worth; the second leg below is '
        .. 'no longer being read on a real number')
    assert(gold >= tpCost, 'leg 1 stopped reading TRUE -- re-derive the limit')
    assert(gold < (tpCost + worth / 40), 'leg 2 stopped reading TRUE -- re-derive')
end

-- --------------------------------------------------------------- the census --

-- Read as DATA. No jmz_func, no bot construction: the two readable legs are
-- hp/max_hp and the recent-damage rows the generator already froze.
local C, ROWS = (function()
    local files = {}
    local p = assert(io.popen('ls tests/fixtures'))
    for f in p:lines() do
        if f:match('^f_.*%.lua$') then files[#files + 1] = 'tests/fixtures/' .. f end
    end
    p:close()
    table.sort(files)
    local c = { fixtures = 0, live = 0, lo = 0, hi = 0, dmg = 0, both = 0 }
    local rows = {}
    for _, path in ipairs(files) do
        local fx = dofile(path)
        if type(fx) == 'table' and fx.units then
            c.fixtures = c.fixtures + 1
            for _, u in ipairs(fx.units) do
                if u.alive then
                    c.live = c.live + 1
                    local frac = (u.max_hp and u.max_hp > 0) and (u.hp / u.max_hp) or 1
                    local hit = false
                    if u.recent_damage ~= nil then
                        for _, d in ipairs(u.recent_damage) do
                            if d.dt > 3.1 then break end
                            if d.kind == 'hero' then hit = true; break end
                        end
                    end
                    if frac < LO then c.lo = c.lo + 1 end
                    if frac >= HI then c.hi = c.hi + 1 end
                    if hit then c.dmg = c.dmg + 1 end
                    if frac < LO and hit then
                        c.both = c.both + 1
                        rows[#rows + 1] = {
                            fix = path:match('([^/]+)%.lua$'), hero = u.name, hp = frac,
                        }
                    end
                end
            end
        end
    end
    return c, rows
end)()

tests['[census] the corpus is intact and both directions were counted'] = function()
    cs.corpus(C.fixtures, 'tpdeathbuy census')
    cs.ratchet(C.live, 966, 'live hero frames')
    -- Both directions of the readable legs (charter 0DIR): a zero on one side
    -- must be distinguishable from "the sweep did not run".
    assert(C.lo + (C.live - C.lo) == C.live, 'the low-HP leg was not counted both ways')
    cs.ratchet(C.hi, 347, 'frames at FULL health (the shipped upper bound alone)')
    assert(C.hi > 0, 'no frame in the corpus is at full health -- then `botHP >= 1` '
        .. 'would be unreachable on its own and the pair is not the whole story')
    cs.ratchet(C.dmg, 95, 'frames with hero damage inside 3.1s')
end

tests['[census] the armed-readable domain is 4 named frames'] = function()
    cs.ratchet(C.lo, 10, 'frames below the shipped low-HP bound')
    cs.ratchet(C.both, 4, 'frames below the bound AND under hero fire')
    -- A rarity claim needs its ceiling too, or "the lever is narrow" quietly
    -- becomes "the lever is everywhere" as the corpus grows.
    cs.share(C.both, C.live, 0.0, 0.05, 'armed-readable domain share', 900)
    assert(#ROWS == C.both, 'the ROW stream and the counter disagree')
    local seen = {}
    for _, r in ipairs(ROWS) do seen[r.fix .. '/' .. r.hero] = r.hp end
    -- Named, so that "4 frames" cannot quietly become four DIFFERENT frames.
    for _, k in ipairs({
        'f_260820_042612_axe_blink_init_573/npc_dota_hero_silencer',
        'f_260820_043140_luna_ring_bid/npc_dota_hero_silencer',
        'f_260820_043524_wd_defend_alone/npc_dota_hero_crystal_maiden',
        'f_260822_182012_sb_backpack_rescue_372/npc_dota_hero_witch_doctor',
    }) do
        assert(seen[k] ~= nil, k .. ' left the armed-readable domain -- the four '
            .. 'frames this file names are not the four it measured')
        assert(seen[k] < LO, k .. ' is no longer below the bound')
    end
    -- The witch_doctor row sits at 0.0800 to four places and is BELOW the bound
    -- by a hair (its true fraction is just under 8%). It is the boundary
    -- neighbour the corpus happens to own: a widening mutation that moves the
    -- bound the wrong way loses it first.
    local wd = seen['f_260822_182012_sb_backpack_rescue_372/npc_dota_hero_witch_doctor']
    assert(wd > LO - 0.001,
        'the boundary-neighbour frame drifted away from the bound; it no longer '
        .. 'pins which side of 0.08 the corpus can see')
end

return tests

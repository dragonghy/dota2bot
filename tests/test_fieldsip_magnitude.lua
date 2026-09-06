-- [ratchet] [fieldsip / owner priority P2] MAGNITUDE, not presence.
--
-- The finding this file pins:
--
--   J.HasFieldRegenSource is a PRESENCE test, and its answer is consumed with
--   OPPOSITE polarity by two ids on the same frame -- stayfield/stayfield2
--   hold the bot in the field BECAUSE there is something to drink, fieldbuy
--   buys a salve BECAUSE there is not. So ONE 85-health faerie fire both
--   justifies the hold and blocks the resupply, and nothing asks whether 85
--   was worth standing still for. On owner P2's OWN pinned evidence frame
--   (f_260822_063722_lina_tp_home) that is exactly what happens: Lina at
--   346/1088 HP is held on 85 health = 7.8% of her bar, while the salve the
--   owner's rule names ("买大药") is the thing fieldbuy is prevented from
--   buying by the same 85.
--
-- The lever is ONE gated conjunct read by BOTH consumers, so the partition
-- they form over the situation is preserved by construction -- this is the
-- 'campvoid' lesson (GH #265: "when a fix takes entries out of a table, every
-- predicate asking whether that table is empty must filter by the same rule")
-- applied before the fact instead of after a deadlock.
--
-- Honest bounds, stated first rather than buried:
--   * gated => NOT live. Condition (a) is bought on zero frames.
--   * the release is one-directional in the SOURCE, and the census below
--     measures it on the corpus; what it does NOT show is that the released
--     bot then gets its salve. That needs gold, stock and a shop/courier, none
--     of which a fixture carries. The chain closing is a CLAIM, asserted only
--     as far as "fieldbuy now owns the frame".
--   * the bottle leg of J.FieldRegenSipValue can never answer on a fixture --
--     the mock's GetCurrentCharges default is 0 -- exactly as it cannot for
--     J.HasFieldRegenSource. Declared, not hidden.
--   * the corpus gap that makes the constant non-load-bearing is a fact about
--     107 fixtures, not about Dota. If a future fixture lands inside it, the
--     [axis] plateau assertion fails and the constant gets re-derived.

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')
local cs = require('corpus_scale')

local JMZ = 'bots/FunLib/jmz_func.lua'
local GATE = 'fieldsip'

-- Owner P2's pinned frame: faerie fire only, empty bottle, 346/1088.
local P2_FIX, P2_HERO = 'tests/fixtures/f_260822_063722_lina_tp_home.lua', 'npc_dota_hero_lina'
-- The two salve carriers in the corpus -- the negative controls, and the only
-- rows on the far side of the gap.
local S1_FIX, S1_HERO = 'tests/fixtures/f_071859_qop_salve.lua', 'npc_dota_hero_queen_of_pain'
local S2_FIX, S2_HERO = 'tests/fixtures/f_260819_222559_od_eclipse_pair.lua', 'npc_dota_hero_juggernaut'
-- A tango carrier on a big bar: 115/1353 = 8.5%, the item the shipped guard
-- J.ShouldStayAndRegen itself accepts.
local T_FIX, T_HERO = 'tests/fixtures/f_260820_103216_cm_es_aftershock.lua', 'npc_dota_hero_jakiro'

local tests = {}

local function read_file(path)
    local f = assert(io.open(path, 'r'))
    local s = f:read('*a')
    f:close()
    return s
end

--- Install a fixture world with the given soak ids armed.
local function world(fix, hero, ...)
    local armed = {}
    for _, id in ipairs({ ... }) do armed[id] = true end
    local J, bot = rf.load(fix, hero)
    J.IsSoakCandidate = function(id) return armed[id] == true end
    return J, bot
end

-- ------------------------------------------------------ the subject frame --

tests['[subject] owner P2 own frame: the hold is bought with 7.8% of the bar'] = function()
    local J, bot = world(P2_FIX, P2_HERO)
    -- The defect made visible rather than asserted: every shipped clause that
    -- the hold rests on is satisfied...
    assert(J.IsFieldRegenSituation(bot) == true, 'the situation holds on this frame')
    assert(J.HasFieldRegenSource(bot) == true, 'and the presence test says yes')
    assert(J.ShouldRegenNotGoHome(bot) == true, 'unarmed: the core decision is STAY')
    -- ...and this is what that yes is worth.
    local sip = J.FieldRegenSipValue(bot)
    local mx = bot:GetMaxHealth()
    assert(sip == 85, 'the only accepted source is the faerie fire (85), got ' .. sip)
    assert(mx == 1088, 'Lina bar is 1088 on this frame, got ' .. tostring(mx))
    -- 85/1088 = 0.0781. Asserted as an inequality band so a loader change that
    -- moves the bar by a point does not turn this red for the wrong reason.
    assert(sip < 0.09 * mx and sip > 0.07 * mx,
        'the sip is 7-9% of the bar, got ' .. (sip / mx))
end

tests['[subject] armed: the hold releases and fieldbuy takes the frame'] = function()
    local J, bot = world(P2_FIX, P2_HERO, GATE)
    assert(J.IsFieldSipEnough(bot) == false, 'armed: 7.8% is not enough to stay for')
    assert(J.ShouldRegenNotGoHome(bot) == false, 'armed: no longer STAY')

    -- Both gated wrappers move with the core predicate, each asked with its
    -- own id -- the bundle a wave would run.
    local J2, bot2 = world(P2_FIX, P2_HERO, 'stayfield')
    assert(J2.ShouldRegenNotTpHome(bot2) == true,
        'stayfield alone: STAY (the behaviour under test)')
    local J3, bot3 = world(P2_FIX, P2_HERO, 'stayfield', GATE)
    assert(J3.ShouldRegenNotTpHome(bot3) == false, 'stayfield + fieldsip: released')
    local J4, bot4 = world(P2_FIX, P2_HERO, 'stayfield2', GATE)
    assert(J4.ShouldRegenNotWalkHome(bot4) == false, 'the walk half moves with it')

    -- The other side of the partition, which is the whole point: the frame is
    -- not dropped, it changes owner.
    local J5, bot5 = world(P2_FIX, P2_HERO, 'fieldbuy')
    assert(J5.ShouldFieldBuyRegen(bot5) == false,
        'unarmed fieldsip: the faerie fire blocks the salve purchase')
    local J6, bot6 = world(P2_FIX, P2_HERO, 'fieldbuy', GATE)
    assert(J6.ShouldFieldBuyRegen(bot6) == true,
        'armed: the frame moves to the supply side instead of being dropped')
end

-- ------------------------------------------------------ negative controls --

tests['[control] a salve is held -- on both salve frames in the corpus'] = function()
    for _, f in ipairs({ { S1_FIX, S1_HERO, 869 }, { S2_FIX, S2_HERO, 1111 } }) do
        local J, bot = world(f[1], f[2], GATE)
        assert(J.IsFieldRegenSituation(bot) == true, f[2] .. ': situation holds')
        assert(J.FieldRegenSipValue(bot) == 400, f[2] .. ': a salve is 400')
        assert(bot:GetMaxHealth() == f[3],
            f[2] .. ': bar moved, ' .. tostring(bot:GetMaxHealth()))
        assert(J.IsFieldSipEnough(bot) == true, f[2] .. ': armed, a salve is enough')
        assert(J.ShouldRegenNotGoHome(bot) == true, f[2] .. ': armed, still STAY')
        local J2, bot2 = world(f[1], f[2], 'fieldbuy', GATE)
        assert(J2.ShouldFieldBuyRegen(bot2) == false,
            f[2] .. ': and it does not buy a second salve')
    end
end

tests['[control] a tango on a big bar releases -- the item the shipped guard accepts'] = function()
    -- J.ShouldStayAndRegen (promoted, live) accepts a tango as "regen", with no
    -- magnitude either. 115/1353 = 8.5%.
    local J, bot = world(T_FIX, T_HERO, GATE)
    assert(J.FieldRegenSipValue(bot) == 115, 'a tango charge is 115')
    assert(bot:GetMaxHealth() == 1353, 'bar 1353')
    assert(J.IsFieldSipEnough(bot) == false, 'armed: 8.5% is not enough')
end

tests['[control] unarmed and wrong-id: nothing moves anywhere'] = function()
    for _, f in ipairs({ { P2_FIX, P2_HERO }, { S1_FIX, S1_HERO }, { T_FIX, T_HERO } }) do
        local J0, b0 = world(f[1], f[2])
        local J1, b1 = world(f[1], f[2], 'notanid')
        local J2, b2 = world(f[1], f[2], 'stayfield')
        assert(J0.IsFieldSipEnough(b0) == true, 'unarmed is true')
        assert(J1.IsFieldSipEnough(b1) == true, 'a nonsense id arms nothing')
        assert(J2.IsFieldSipEnough(b2) == true, 'an unrelated family id arms nothing')
        assert(J0.ShouldRegenNotGoHome(b0) == J1.ShouldRegenNotGoHome(b1),
            'and the shipped decision is unchanged by either')
    end
end

tests['[control] turbo is structural: the situation gates the whole family'] = function()
    -- J.IsFieldSipEnough carries no IsModeTurbo of its own on purpose -- both
    -- consumers ask J.IsFieldRegenSituation (whose first line IS IsModeTurbo)
    -- BEFORE they ask this one. That call order is load-bearing, so it is
    -- asserted off the source rather than restated as a redundant clause.
    local src = read_file(JMZ)
    for _, fn in ipairs({ 'ShouldRegenNotGoHome', 'ShouldFieldBuyRegen' }) do
        local body = src:match('function J%.' .. fn .. '%(.-\nend')
        assert(body, 'could not locate J.' .. fn)
        local iSit = body:find('IsFieldRegenSituation', 1, true)
        local iSip = body:find('IsFieldSipEnough', 1, true)
        assert(iSit and iSip and iSit < iSip,
            fn .. ' must ask the situation before it asks the magnitude')
    end
    local sit = src:match('function J%.IsFieldRegenSituation%(.-\nend')
    assert(sit:find('IsModeTurbo', 1, true) < sit:find('GetHP', 1, true),
        'the situation must still lead with IsModeTurbo')
    local sip = src:match('function J%.IsFieldSipEnough%(.-\nend')
    assert(not sip:find('IsModeTurbo', 1, true),
        'a redundant IsModeTurbo here would state the call order is not load-bearing')
end

-- ------------------------------------------------------------------ gates --

tests['[gate] one id, asked once, and inert as a literal true'] = function()
    local src = read_file(JMZ)
    local sip = src:match('function J%.IsFieldSipEnough%(.-\nend')
    assert(sip, 'could not locate J.IsFieldSipEnough')
    local ids = {}
    for id in sip:gmatch("J%.IsSoakCandidate%(%s*'([%w_]+)'%s*%)") do
        ids[#ids + 1] = id
    end
    assert(#ids == 1 and ids[1] == GATE,
        "exactly one gate, named '" .. GATE .. "', may live here")
    local _, n = sip:gsub('J%.IsSoakCandidate%(', '')
    assert(n == 1, 'and it may be asked exactly once, found ' .. n)
    -- The pullcad trap (AGENTS.md: promoting an id silently kills any gate that
    -- names it): this predicate must not conjoin with another candidate id.
    for _, other in ipairs({ 'stayfield', 'stayfield2', 'fieldbuy', 'fieldcreep', 'bagsalve' }) do
        assert(not sip:find(other, 1, true),
            'fieldsip must not name ' .. other .. ' inside its own gate')
    end
    -- Structural inertness: the first thing the unarmed path does is return
    -- true, so both consumers reduce to their shipped expressions.
    assert(sip:find("if not J%.IsSoakCandidate%(%s*'" .. GATE .. "'%s*%) then return true end"),
        'the unarmed path must be a literal `return true` on its own line')
end

tests['[reduce] unarmed, the buy side is byte-for-byte the shipped expression'] = function()
    -- The shipped line was `return not J.HasFieldRegenSource( bot )`. The new
    -- one is `not ( A and B )` with B ≡ true unarmed. Asserted as an identity
    -- over the whole corpus by the census (partition counters), and here at
    -- the source level so a future edit that reorders the conjunction is seen.
    local src = read_file(JMZ)
    local buy = src:match('function J%.ShouldFieldBuyRegen%(.-\nend')
    assert(buy:find('not ( J.HasFieldRegenSource( bot ) and J.IsFieldSipEnough( bot ) )', 1, true),
        'the buy side must negate exactly the conjunction the hold side asserts')
    local hold = src:match('function J%.ShouldRegenNotGoHome%(.-\nend')
    assert(hold:find('J.HasFieldRegenSource( bot )', 1, true)
        and hold:find('J.IsFieldSipEnough( bot )', 1, true),
        'the hold side must assert both halves of that same conjunction')
end

tests['[source] the value table, and why bagsalve cannot fight it'] = function()
    local J = rf.load(P2_FIX, P2_HERO)
    -- The five accepted sources and their per-single-use health. Pinned so a
    -- patch that changes a consumable moves this file, not the reading.
    local want = { item_flask = 400, item_tango = 115, item_tango_single = 115,
        item_faerie_fire = 85, item_bottle = 135 }
    local n = 0
    for k, v in pairs(J.FIELD_SIP_HEAL) do
        assert(want[k] == v, 'unexpected heal value for ' .. k .. ': ' .. tostring(v))
        n = n + 1
    end
    assert(n == 5, 'the table must carry exactly the five accepted sources, got ' .. n)
    -- The source comment claims bagsalve can never admit a frame this lever
    -- would then call too small, BECAUSE flask is the table's maximum. That is
    -- the assertion, not the prose.
    for k, v in pairs(J.FIELD_SIP_HEAL) do
        assert(v <= want.item_flask, k .. ' outranks a salve; the bagsalve argument breaks')
    end
    -- The two helpers must agree about which items count: same names, same
    -- slot range, same bottle-charge test.
    local src = read_file(JMZ)
    local has = src:match('function J%.HasFieldRegenSource%(.-\nend')
    local val = src:match('function J%.FieldRegenSipValue%(.-\nend')
    for k in pairs(want) do
        assert(has:find(k, 1, true), 'HasFieldRegenSource lost ' .. k)
    end
    for _, fn in ipairs({ has, val }) do
        assert(fn:find('for i = 0, 5 do', 1, true), 'the usable-slot range drifted')
        assert(fn:find('GetCurrentCharges', 1, true), 'the bottle-charge test drifted')
    end
end

tests['[boundary] exactly at the threshold the bot STAYS (pins >= against >)'] = function()
    -- No corpus row lands on the threshold -- the nearest are 0.156 and 0.360 --
    -- so the corpus cannot tell `>=` from `>`. That mutation survived the whole
    -- battery until this case existed, and it is the one edit a reader would
    -- call a typo. The bar is DERIVED from the two shipped constants so this
    -- stays a boundary if either moves.
    local J = rf.load(P2_FIX, P2_HERO)
    J.IsSoakCandidate = function(id) return id == GATE end
    local heal = J.FIELD_SIP_HEAL.item_flask
    local exact = heal / J.FIELD_SIP_MIN_FRACTION
    assert(J.FIELD_SIP_MIN_FRACTION * exact == heal,
        'the constants no longer reconstruct an exact boundary in binary '
        .. 'floating point; this case must be rebuilt, not deleted')

    local function fake(nMax)
        return {
            GetMaxHealth = function() return nMax end,
            GetItemInSlot = function(_, i)
                if i ~= 0 then return nil end
                return { GetName = function() return 'item_flask' end,
                         GetCurrentCharges = function() return 0 end }
            end,
        }
    end
    assert(J.FieldRegenSipValue(fake(exact)) == heal, 'the fake carries one salve')
    assert(J.IsFieldSipEnough(fake(exact)) == true,
        'a sip worth exactly the threshold is enough -- the test is >=, not >')
    assert(J.IsFieldSipEnough(fake(exact + 1)) == false,
        'and one point of extra bar is not')
    assert(J.IsFieldSipEnough(fake(exact - 1)) == true, 'one point less is')
end

tests['[control] an unreadable bar cannot silently release a bot'] = function()
    -- GetMaxHealth returning nil or 0 is a failure to READ, not a measurement
    -- of "no bar". A magnitude test that answered false there would release
    -- every hold on the first engine hiccup, i.e. exactly the direction that
    -- undoes owner P2. It answers true (inert) instead.
    local J = rf.load(P2_FIX, P2_HERO)
    J.IsSoakCandidate = function(id) return id == GATE end
    for _, v in ipairs({ 0, -1 }) do
        assert(J.IsFieldSipEnough({ GetMaxHealth = function() return v end,
            GetItemInSlot = function() return nil end }) == true,
            'a bar of ' .. v .. ' must be inert, not a release')
    end
    assert(J.IsFieldSipEnough({ GetMaxHealth = function() return nil end,
        GetItemInSlot = function() return nil end }) == true,
        'an unreadable bar must be inert, not a release')
end

-- ------------------------------------------------------------- the census --

local function sweep()
    local p = assert(io.popen('lua5.1 tests/_fieldsip_sweep.lua 2>/dev/null'))
    local text = p:read('*a')
    p:close()
    assert(text:find('\nDONE\n') or text:find('^DONE\n'),
        'the corpus sweep subprocess did not finish (no DONE line)')
    local c, rows, grid = {}, {}, {}
    for line in text:gmatch('[^\n]+') do
        local k, v = line:match('^C ([%w_]+) (%-?%d+)$')
        if k then c[k] = tonumber(v) end
        local t, r = line:match('^GRID (%d+) (%d+)$')
        if t then grid[tonumber(t)] = tonumber(r) end
        local f, h, hp, mx, sip, frac =
            line:match('^ROW (%S+) (%S+) ([%d%.]+) (%d+) (%d+) (%d+)$')
        if f then
            rows[#rows + 1] = { fix = f, hero = h, hp = tonumber(hp),
                mx = tonumber(mx), sip = tonumber(sip), frac = tonumber(frac) / 10000 }
        end
    end
    return c, rows, grid
end

local SWEEP_C, SWEEP_ROWS, SWEEP_GRID = sweep()

tests['census: the corpus the numbers are quoted from'] = function()
    cs.corpus(SWEEP_C.fixtures, 'fieldsip corpus')
    cs.ratchet(SWEEP_C.live, 993, 'live hero frames')
    cs.ratchet(SWEEP_C.situation, 54, 'situation frames')
    cs.ratchet(SWEEP_C.with_source, 23, 'situation frames carrying a source')
    assert(SWEEP_C.situation == SWEEP_C.with_source + SWEEP_C.dry,
        'the situation must split exactly into carrying and dry: '
        .. SWEEP_C.situation .. ' vs ' .. SWEEP_C.with_source .. '+' .. SWEEP_C.dry)
    assert(#SWEEP_ROWS == SWEEP_C.with_source,
        'every carrying frame must produce a row, got ' .. #SWEEP_ROWS)
end

tests['census: the partition survives, and the move is one-directional'] = function()
    -- These five counters are the load-bearing ones. Each is a state the
    -- design says is impossible; a non-zero is a real defect, not a drift.
    -- The sweep zero-initialises them, so a MISSING key means the assertion
    -- never ran and must not read as a pass.
    for _, k in ipairs({ 'IMPOSSIBLE_partition_unarmed', 'IMPOSSIBLE_partition_armed',
        'IMPOSSIBLE_hold_widened', 'IMPOSSIBLE_buy_narrowed',
        'IMPOSSIBLE_source_without_value' }) do
        assert(SWEEP_C[k] ~= nil, 'the sweep did not report ' .. k .. ' at all')
    end
    assert(SWEEP_C.IMPOSSIBLE_partition_unarmed == 0,
        'hold and buy agreed on a frame with fieldsip unarmed')
    assert(SWEEP_C.IMPOSSIBLE_partition_armed == 0,
        'hold and buy agreed on a frame with fieldsip armed -- the partition broke')
    assert(SWEEP_C.IMPOSSIBLE_hold_widened == 0,
        'armed turned a hold ON; this lever may only narrow')
    assert(SWEEP_C.IMPOSSIBLE_buy_narrowed == 0,
        'armed turned a buy OFF; this lever may only widen the supply side')
    assert(SWEEP_C.IMPOSSIBLE_source_without_value == 0,
        'a frame the presence test accepts had no sip value -- the two helpers drifted')
    -- And the two halves of the move are the same frames, which is what
    -- "changes owner" means.
    assert(SWEEP_C.released == SWEEP_C.now_buys,
        'released ' .. SWEEP_C.released .. ' but now_buys ' .. SWEEP_C.now_buys)
    cs.ratchet(SWEEP_C.released, 21, 'frames the lever moves')
    -- The domain is not empty and not everything: a lever that moved 0 or all
    -- 23 would be a no-op or a rename of HasFieldRegenSource.
    assert(SWEEP_C.released > 0 and SWEEP_C.released < SWEEP_C.with_source,
        'the lever must move some but not all carrying frames')
end

tests['[axis] the constant is not load-bearing -- the corpus has an empty gap'] = function()
    local J = rf.load(P2_FIX, P2_HERO)
    local k = J.FIELD_SIP_MIN_FRACTION
    assert(k == 0.25, 'the shipped constant moved: ' .. tostring(k))

    -- Find the plateau containing the shipped constant, off the grid rather
    -- than off this file's memory of where it is.
    local at = SWEEP_GRID[math.floor(k * 1000 + 0.5)]
    assert(at ~= nil, 'the grid does not cover the shipped constant')
    local lo, hi = math.floor(k * 1000 + 0.5), math.floor(k * 1000 + 0.5)
    while SWEEP_GRID[lo - 5] == at do lo = lo - 5 end
    while SWEEP_GRID[hi + 5] == at do hi = hi + 5 end
    -- The measured gap: 0.160 .. 0.360, i.e. every threshold in it releases
    -- the same 21 rows. The claim is the WIDTH, not the endpoints -- a gap
    -- more than twice as wide as it is far from either edge is what makes the
    -- exact value uninteresting.
    assert(hi >= lo * 2,
        'the plateau is no longer a 2x gap: ' .. lo .. '..' .. hi .. ' (x1000)')
    assert(k * 1000 > lo and k * 1000 < hi,
        'the shipped constant sits on an edge of its plateau, not inside it')
    -- Both margins matter: a constant hugging either end is one fixture away
    -- from meaning something different.
    assert(k * 1000 - lo >= 50 and hi - k * 1000 >= 50,
        'the shipped constant is within 0.05 of a plateau edge: '
        .. lo .. '..' .. hi)
    assert(at == SWEEP_C.released,
        'the grid and the live drive disagree about how many frames move')
end

tests['[limit] what this file does not buy'] = function()
    -- (1) the released bot getting its salve. FieldBuy is a purchase decision
    -- gated on gold, stock and a shop/courier -- none of which a fixture
    -- carries. What is asserted is only that the frame changes owner.
    -- Sliced by "the `if` whose condition MENTIONS the predicate", not by the
    -- condition's exact text. Written as `if J.ShouldFieldBuyRegen(bot)` it went
    -- red on 2026-09-06 when 'buyband' added a second arm and the condition
    -- became `if ( J.ShouldFieldBuyRegen(bot) or J.ShouldFieldBuyRegenHurt(bot) )`
    -- -- the block still carried every precondition this assertion is about, and
    -- the assertion was reporting on a nil slice. A slice pattern that pins the
    -- WHOLE condition is a pin on every future arm of it.
    local buy = read_file('bots/item_purchase_generic.lua')
        :match('\n\tif [^\n]-J%.ShouldFieldBuyRegen%(bot%).-\n\tend')
    assert(buy, 'could not slice the ShouldFieldBuyRegen purchase block -- the '
        .. 'call site moved or its shape changed; re-read it rather than '
        .. 'loosening this')
    assert(buy:find('botGold >= GetItemCost', 1, true)
        and buy:find('GetItemStockCount', 1, true),
        'the purchase site still carries preconditions this corpus cannot drive')
    -- (2) the bottle leg. GetCurrentCharges defaults to 0 in the mock, so no
    -- fixture row can ever be a bottle -- same declared blindness the presence
    -- test has. If a loader change makes it drivable, this fails and the
    -- limitation should be replaced by a real drive, not relaxed.
    local bottles = 0
    for _, r in ipairs(SWEEP_ROWS) do
        if r.sip == 135 then bottles = bottles + 1 end
    end
    assert(bottles == 0,
        'the bottle leg became drivable on ' .. bottles .. ' rows -- upgrade this test')
end

return tests

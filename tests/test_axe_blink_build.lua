-- [hero, backlog #5] Axe's turbo purchase order: Blink Dagger first big item.
--
-- WHY (measured, not assumed). Four turbo soak games were dumped frame by frame
-- (behav-dump -interval 0.5/1.0 on the .dem files of
-- soak/spot_20260819_121044_1_main, games 20260819_121916 / _122445 / _123032 /
-- _123546, slot1). In 4 of 4, Axe NEVER held a Blink Dagger at any frame of the
-- game -- the item that delivers his entire kit (blink -> Berserker's Call ->
-- Counter Helix -> Culling Blade reset). The shipped pos_3 order buries it
-- behind item_tank_outfit, Crimson Guard and Blade Mail; his final net worth in
-- those games was 4228 / 5556 / 7834 / 8586, nowhere near that prefix, because
-- turbo games end at minute 11.
--
-- Same games, from Axe's own measured gold curve: the frame his boots completed
-- (the last component of item_tank_outfit) and his net worth there, and the
-- frame his net worth would first cover that plus blink's 2250:
--
--     game            ends    boots done   nw     blink would land
--     20260819_121916  658s      272s     2696          558.5s
--     20260819_122445  723s      291s     2672          479.4s
--     20260819_123032  660s      292s     2834          584.5s
--     20260819_123546  658s      432s     2650          never (final nw 4228)
--
-- So the reorder is not merely "better in theory": in 3 of 4 games it converts
-- "no blink, ever" into a blink with 100-240s of a decisive turbo game left.
--
-- Honest bounds:
--   * Blink's 2250 gold is the ONE number here that does not come from the
--     replays -- it is the shop price (out-of-frame anchor, same class as the
--     GetManaCost anchors in the wkreincarnmp / axeblink tests). Everything
--     else (net worth per frame, item lists per frame, boots timing, game
--     length) is read straight off the .dem.
--   * Net worth is not spendable gold at that instant; it also counts what is
--     already in the bag. The projection below is therefore an approximation of
--     the purchase moment, accurate to the extent the bot spends promptly --
--     which it does, since the list is bought in order.
--   * Whether a blink Axe who skipped the Vanguard/Crimson stack is actually
--     BETTER is an emergent question these tests cannot answer (see the lanefix
--     lesson). That is what the gate and the batch A/B are for. This file only
--     pins that the order changes exactly as intended and stays inert offline.

package.path = 'tests/?.lua;' .. package.path
local api = require('mock.bot_api')

local SIDE_PATH = 'bots/Customize/soak_side.lua'   -- gitignored, farm-only
local CAND = 'axebuyblink'
local BLINK_COST = 2250                            -- out-of-frame anchor (shop)

local tests = {}

-- The shipped orders, transcribed byte-for-byte from bots/BotLib/hero_axe.lua.
-- Any drift between these and the file is a real failure, not a chore: the
-- gate-off path must remain the shipped default exactly.
local SHIPPED_POS1 = {
    'item_sven_outfit',
    'item_blade_mail',
    'item_blink',
    'item_aghanims_shard',
    'item_black_king_bar',
    'item_ultimate_scepter',
    'item_travel_boots',
    'item_overwhelming_blink',
    'item_abyssal_blade',
    'item_ultimate_scepter_2',
    'item_moon_shard',
    'item_heart',
    'item_travel_boots_2',
}

local SHIPPED_POS3 = {
    'item_tank_outfit',
    'item_crimson_guard',
    'item_blade_mail',
    'item_blink',
    'item_aghanims_shard',
    'item_black_king_bar',
    'item_heavens_halberd',
    'item_travel_boots',
    'item_assault',
    'item_ultimate_scepter_2',
    'item_moon_shard',
    'item_heart',
    'item_overwhelming_blink',
    'item_travel_boots_2',
}

-- Measured per-game facts (see the table in the header). `final_nw` and
-- `nw_at_boots` are read off the dumped frames; nothing here is estimated.
local GAMES = {
    { name = '20260819_121916', nw_at_boots = 2696, final_nw = 7834, blink_at = 558.5 },
    { name = '20260819_122445', nw_at_boots = 2672, final_nw = 8586, blink_at = 479.4 },
    { name = '20260819_123032', nw_at_boots = 2834, final_nw = 5556, blink_at = 584.5 },
    { name = '20260819_123546', nw_at_boots = 2650, final_nw = 4228, blink_at = nil },
}

local function load_axe(bTurbo, nRole)
    api.reset_modules()
    local bot = api.MakeHero('npc_dota_hero_axe', { CanBeSeen = true })
    bot.assignedRole = nRole or 3
    api.install({ bot = bot })
    -- Both teams must agree: J.IsSoakCandidateSide compares GetTeam() against
    -- TEAM_RADIANT, while Role.GetPosition compares GetTeam() against
    -- bot:GetTeam() and hands back a hardcoded 3 for anyone it reads as an
    -- enemy. Setting only one of them silently pins every role to pos_3.
    GetTeam = function() return TEAM_RADIANT end
    bot.GetTeam = function() return TEAM_RADIANT end
    if bTurbo == false then
        GetGameMode = function() return 1 end
    else
        GetGameMode = function() return GAMEMODE_TURBO end
    end
    return dofile('bots/BotLib/hero_axe.lua')
end

-- Arm a soak candidate by writing the (gitignored) side file, as the other
-- gate tests do. sId defaults to the candidate under test.
local function with_candidate(sId, fn)
    local f = assert(io.open(SIDE_PATH, 'w'))
    f:write("return { side = 'radiant', cand = '" .. sId .. "' }\n")
    f:close()
    local ok, err = pcall(fn)
    os.remove(SIDE_PATH)
    if not ok then error(err, 0) end
end

local function assert_same_list(tGot, tWant, sWhat)
    assert(type(tGot) == 'table', sWhat .. ': buy list is not a table')
    assert(#tGot == #tWant,
        sWhat .. ': expected ' .. #tWant .. ' entries, got ' .. #tGot)
    for i = 1, #tWant do
        assert(tGot[i] == tWant[i],
            sWhat .. ': entry ' .. i .. ' is ' .. tostring(tGot[i])
            .. ', expected ' .. tostring(tWant[i]))
    end
end

local function index_of(tList, sItem)
    for i, s in ipairs(tList) do
        if s == sItem then return i end
    end
    return nil
end

-- Multiset equality: the reorder must add nothing and drop nothing.
local function assert_permutation(tGot, tWant, sWhat)
    assert(#tGot == #tWant,
        sWhat .. ': length changed (' .. #tGot .. ' vs ' .. #tWant .. ')')
    local count = {}
    for _, s in ipairs(tWant) do count[s] = (count[s] or 0) + 1 end
    for _, s in ipairs(tGot) do count[s] = (count[s] or 0) - 1 end
    for s, n in pairs(count) do
        assert(n == 0, sWhat .. ': item ' .. s .. ' count differs by ' .. -n)
    end
end

-- Everything except blink keeps its relative order.
local function assert_order_preserved_except_blink(tGot, tWant, sWhat)
    local a, b = {}, {}
    for _, s in ipairs(tGot) do if s ~= 'item_blink' then a[#a + 1] = s end end
    for _, s in ipairs(tWant) do if s ~= 'item_blink' then b[#b + 1] = s end end
    assert_same_list(a, b, sWhat .. ' (non-blink subsequence)')
end

tests['gate off: pos_3 is the shipped order byte for byte'] = function()
    local X = load_axe(true, 3)   -- turbo, but no soak_side file exists
    assert_same_list(X.sBuyList, SHIPPED_POS3, 'pos_3 gate off')
end

tests['gate off: pos_1 is the shipped order byte for byte'] = function()
    local X = load_axe(true, 1)
    assert_same_list(X.sBuyList, SHIPPED_POS1, 'pos_1 gate off')
end

tests['armed in NORMAL mode leaves the shipped order (turbo-only)'] = function()
    with_candidate(CAND, function()
        local X = load_axe(false, 3)
        assert_same_list(X.sBuyList, SHIPPED_POS3, 'pos_3 armed but normal mode')
    end)
end

tests['a different armed candidate leaves the shipped order'] = function()
    with_candidate('wkbuild', function()
        local X = load_axe(true, 3)
        assert_same_list(X.sBuyList, SHIPPED_POS3, 'pos_3 with another candidate armed')
    end)
end

tests['armed in turbo: pos_3 buys blink straight after the starting outfit'] = function()
    with_candidate(CAND, function()
        local X = load_axe(true, 3)
        assert(X.sBuyList[1] == 'item_tank_outfit',
            'the starting-items bundle must stay first (it carries the boots), got '
            .. tostring(X.sBuyList[1]))
        assert(X.sBuyList[2] == 'item_blink',
            'blink must be the first big item, got ' .. tostring(X.sBuyList[2]))
        -- the two items it jumped over are still in the list, just later
        assert(index_of(X.sBuyList, 'item_crimson_guard') > 2, 'crimson guard must survive, after blink')
        assert(index_of(X.sBuyList, 'item_blade_mail') > 2, 'blade mail must survive, after blink')
        assert_permutation(X.sBuyList, SHIPPED_POS3, 'pos_3 armed')
        assert_order_preserved_except_blink(X.sBuyList, SHIPPED_POS3, 'pos_3 armed')
    end)
end

tests['armed in turbo: pos_1 buys blink straight after the starting outfit'] = function()
    with_candidate(CAND, function()
        local X = load_axe(true, 1)
        assert(X.sBuyList[1] == 'item_sven_outfit',
            'the starting-items bundle must stay first, got ' .. tostring(X.sBuyList[1]))
        assert(X.sBuyList[2] == 'item_blink',
            'blink must be the first big item, got ' .. tostring(X.sBuyList[2]))
        assert_permutation(X.sBuyList, SHIPPED_POS1, 'pos_1 armed')
        assert_order_preserved_except_blink(X.sBuyList, SHIPPED_POS1, 'pos_1 armed')
    end)
end

-- pos_2 aliases pos_1 and pos_4/pos_5 alias pos_3 in the shipped file; the
-- reorder must land on the aliases too, or an Axe assigned pos_4 (which the
-- role assigner does do) would silently keep the old order.
tests['armed in turbo: the aliased positions follow their base list'] = function()
    with_candidate(CAND, function()
        for _, nRole in ipairs({ 2 }) do
            local X = load_axe(true, nRole)
            assert(X.sBuyList[2] == 'item_blink',
                'pos_' .. nRole .. ' (aliases pos_1) must get the reorder')
            assert_permutation(X.sBuyList, SHIPPED_POS1, 'pos_' .. nRole .. ' armed')
        end
        for _, nRole in ipairs({ 4, 5 }) do
            local X = load_axe(true, nRole)
            assert(X.sBuyList[2] == 'item_blink',
                'pos_' .. nRole .. ' (aliases pos_3) must get the reorder')
            assert_permutation(X.sBuyList, SHIPPED_POS3, 'pos_' .. nRole .. ' armed')
        end
    end)
end

tests['gate off: the aliased positions stay on the shipped order'] = function()
    local X2 = load_axe(true, 2)
    assert_same_list(X2.sBuyList, SHIPPED_POS1, 'pos_2 gate off')
    local X4 = load_axe(true, 4)
    assert_same_list(X4.sBuyList, SHIPPED_POS3, 'pos_4 gate off')
end

-- The reachability arithmetic that motivates the change, evaluated against the
-- list actually under test rather than a copy of it: if anything ever gets
-- inserted between the outfit and blink, the gold needed goes up and this
-- fails, forcing whoever did it to redo the measurement.
tests['armed order makes blink reachable on the measured gold curves'] = function()
    with_candidate(CAND, function()
        local X = load_axe(true, 3)
        local nBefore = index_of(X.sBuyList, 'item_blink') - 1
        assert(nBefore == 1,
            'the measured projection assumes ONLY the starting outfit precedes blink; '
            .. nBefore .. ' items do -- re-measure before changing this')

        local nReached = 0
        for _, g in ipairs(GAMES) do
            local bAffordable = (g.nw_at_boots + BLINK_COST) <= g.final_nw
            assert(bAffordable == (g.blink_at ~= nil),
                g.name .. ': affordability (' .. g.nw_at_boots .. '+' .. BLINK_COST
                .. ' vs final ' .. g.final_nw .. ') disagrees with the measured landing frame')
            if bAffordable then nReached = nReached + 1 end
        end
        assert(nReached == 3,
            'expected blink to become reachable in 3 of the 4 measured games, got ' .. nReached)
    end)
end

-- The shipped prefix is what the measurement says it is: three items before
-- blink, two of them big. This is the fact the change is aimed at, so pin it.
tests['shipped pos_3 puts two big items ahead of blink'] = function()
    local X = load_axe(true, 3)
    assert(index_of(X.sBuyList, 'item_blink') == 4,
        'shipped pos_3 blink index moved; the motivating measurement is stale')
    assert(index_of(X.sBuyList, 'item_crimson_guard') == 2, 'shipped pos_3 crimson guard index moved')
    assert(index_of(X.sBuyList, 'item_blade_mail') == 3, 'shipped pos_3 blade mail index moved')
end

return tests

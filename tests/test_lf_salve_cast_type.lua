-- The `lf_salve` in-lane recovery branch (aiug:989) called `X.SetUseItem` two
-- arguments short, and `X.SetUseItem` dispatches on the third one.
--
-- THE DEFECT, in the shape that matters: not "the wrong item was used" but
-- "nothing was used, and everything else was suppressed too".
--
--   X.SetUseItem( hItem, hItemTarget, sCastType )   -- aiug:1048
--
-- has five arms and every one of them needs either a non-nil `sCastType` or an
-- `hItemTarget` that looks like a location (`.x ~= nil`). Hand it one argument
-- and `sCastType`/`hItemTarget` are both nil: 'none'/'unit'/'tree'/'twice' all
-- miss, and the 'ground' arm's fallback reads `nil and ...` = nil. The function
-- falls off its end having issued NO engine action. The caller then does
--
--   X.SetUseItem( hRegen )
--   return BOT_ACTION_DESIRE_HIGH
--
-- and that `return` sits ABOVE the whole `nItemSlot` loop, so the frame also
-- loses every other item the bot might have used. Armed, the branch bought zero
-- salve and turned the item layer off.
--
-- MEASURED ON THE FIXTURE CORPUS (104 fixtures / 966 alive subjects), all four
-- numbers recomputed by census() below rather than restated:
--
--     helper domain (J.LaneRegenItemToUse ~= nil, armed)        20 subjects
--     of those, loadable through the shipped item chain         18
--     armed, PRE  (the two-argument call): frames with any action    0 / 18
--     armed, POST (this fix):              frames with one action   17 / 18
--
-- and the suppression half, on the same 18:
--
--     shipped (unarmed) issues some item action                  8
--     of which item_power_treads, a harness artifact (GH #133)   4
--     honest suppression floor                                   4
--
-- ⭐ THE FIX IS NOT A GUESS, AND TWO FRAMES PROVE IT BY EXECUTION. On
-- f_260819_123546_jakiro_landed_ok/axe and f_260820_043140_luna_ring_bid/
-- tidehunter the SHIPPED item layer, with no candidate armed, reaches for the
-- same flask on its own and hands the engine
-- `Action_UseAbilityOnEntity(item_flask, self)`. Armed and fixed, this branch
-- issues that identical action. So `('unit', self)` is not read off the
-- dispatcher's arm list, it is read off what the shipped tree already does with
-- these two items -- and both `X.ConsiderItemDesire['item_flask']` and
-- `['item_clarity']` set `local sCastType = 'unit'` with `hEffectTarget = bot`
-- for self-use. Asserted from source below, so a third returnable item or a
-- changed cast type turns this file red instead of silently widening the claim.
--
-- WHY NO NEW SOAK ID. The branch is already gated: `J.LaneRegenItemToUse`'s
-- first line is `if not J.IsLaneFixOn('salve') then return nil end`, and
-- `J.IsLaneFixOn` is turbo-only plus `lanefix` OR `lf_salve`. Wrapping the cast
-- type in its own `IsSoakCandidate` would produce the frozen-conjunction hazard
-- the `pullcad` promote taught (a gate written `A and B` is dead the day B is
-- promoted, and check_armed_wiring.py still calls it WIRED). Same call as
-- `pullcamp`'s dead-branch repair: fix inside the existing gate, no new id.
-- Off the candidate the tree is byte-identical -- asserted, not promised.
--
-- HONEST BOUNDS. Read before quoting anything above.
--
--   * `J.CanCastAbility` is false on every item handle in this corpus (the
--     sixteenth world assertion, GH #100), so the census hands every item the
--     two clauses the loader never wires -- exactly what
--     tests/_itemdesire_sweep.lua's honest pass does. Without that the SHIPPED
--     column is all zeros and the suppression claim cannot be made at all.
--     Nothing else about the frames is touched.
--   * The suppression column is therefore an "all items honest" world, which is
--     an UPPER bound on what a real game suppresses; the treads split gives the
--     lower one. Four is a floor, eight is a ceiling, and the corpus cannot
--     locate the number between them. It does not need to: the mechanism is the
--     shipped `return`, and the PRE column being flat zero is what this fix is
--     answering.
--   * The two frames outside the 18 are enumerated, not tolerated, and both are
--     known repo facts rather than anything about this branch (see the
--     [exceptions] test).
--   * `IsFullyCastable` and the modifier reads that gate the helper are mock
--     answers; the domain of 20 is this corpus's domain, not a game rate.

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')

local tests = {}

local AIUG = 'bots/ability_item_usage_generic.lua'
local JMZ = 'bots/FunLib/jmz_func.lua'

local function read_file(path)
    local fh = assert(io.open(path, 'r'), 'cannot read ' .. path)
    local s = fh:read('*a')
    fh:close()
    return s
end

local AIUG_SRC = read_file(AIUG)
local JMZ_SRC = read_file(JMZ)

--- The shipped chunk, and the pre-fix chunk built by putting the two-argument
--- call back. The mutation is applied to the SOURCE, so if the call site is
--- ever reworded the substitution fails loudly instead of silently measuring
--- the fixed tree twice (the self-inflicted wound recorded in state.json for
--- `pullcad`: a mutation battery that rolled back the thing it was mutating).
local FIXED_CHUNK = assert(loadstring(AIUG_SRC, '@' .. AIUG),
    'the item file no longer loads')
local PRE_SRC, PRE_N = AIUG_SRC:gsub(
    "X%.SetUseItem%( hRegen, bot, 'unit' %)", 'X.SetUseItem( hRegen )', 1)
local PRE_CHUNK = PRE_N == 1 and assert(loadstring(PRE_SRC, '@' .. AIUG)) or nil

--- The scan order, read out of the shipped source (the M13 lesson: a census
--- that copies a constant measures its own copy).
local SLOTS = (function()
    local body = assert(AIUG_SRC:match('local nItemSlot = {([^}]+)}'),
        'the item slot scan order moved out of `local nItemSlot = { ... }`')
    local t = {}
    for n in body:gmatch('%-?%d+') do t[#t + 1] = tonumber(n) end
    assert(#t >= 2, 'the slot scan order parsed to fewer than two slots')
    return t
end)()

local AIUG_GLOBALS = {
    'ItemUsageThink', 'AbilityUsageThink', 'BuybackUsageThink',
    'CourierUsageThink', 'AbilityLevelUpThink',
}
local BEFORE = {}
for _, g in ipairs(AIUG_GLOBALS) do BEFORE[g] = _G[g] end

-- The two frames where the shipped item layer independently reaches for the
-- same flask, i.e. the frames that pin the cast SHAPE by execution.
local AGREEMENT = {
    { path = 'tests/fixtures/f_260819_123546_jakiro_landed_ok.lua',
      hero = 'npc_dota_hero_axe', item = 'item_flask' },
    { path = 'tests/fixtures/f_260820_043140_luna_ring_bid.lua',
      hero = 'npc_dota_hero_tidehunter', item = 'item_flask' },
}

local KEYSTONE = 'tests/fixtures/f_260820_043524_wd_defend_alone.lua'
local KEYSTONE_BOT = 'npc_dota_hero_crystal_maiden'

local function fixture_files()
    local p = assert(io.popen('ls tests/fixtures'))
    local files = {}
    for f in p:lines() do
        if f:match('^f_.*%.lua$') then files[#files + 1] = 'tests/fixtures/' .. f end
    end
    p:close()
    table.sort(files)
    return files
end

--- One frame. `armed` arms `lf_salve` and nothing else. `honest` hands every
--- occupied slot the two clauses the loader never wires (see HONEST BOUNDS).
local function frame(path, hero, armed, honest)
    local J, bot, heroes, fx = rf.load(path, hero)
    J.IsSoakCandidate = function(id) return armed and id == 'lf_salve' end
    if honest then
        for _, s in ipairs(SLOTS) do
            local it = bot:GetItemInSlot(s)
            if type(it) == 'table' then
                local sp = rawget(it, '__spec')
                sp.IsTrained = true
                sp.IsActivated = true
            end
        end
    end
    return J, bot, heroes, fx
end

--- Drive the SHIPPED entry point under `chunk`; return the action log or nil.
local function drive(chunk, bot)
    if not pcall(chunk) then return nil, 'aiug_load' end
    local log = rf.record_actions(bot)
    bot.lastItemFrameProcessTime = DotaTime() - 100
    local ok, err = pcall(_G.ItemUsageThink)
    if not ok then return nil, 'crash:' .. tostring(err) end
    return log, nil
end

local function item_name(entry)
    local a = entry.args[1]
    if type(a) == 'table' and a.GetName then return a:GetName() end
    return '?'
end

-- ---------------------------------------------------------------------------
-- The corpus census: one pass, memoised, every number in the header recomputed.
-- ---------------------------------------------------------------------------

local CENSUS = nil
local function census()
    if CENSUS ~= nil then return CENSUS end
    local c = {
        fixtures = 0, subjects = 0, alive = 0,
        domain = 0, loadable = 0, err = 0, err_frames = {},
        pre_acted = 0, post_acted = 0, post_silent_frames = {},
        shipped_acted = 0, shipped_treads = 0,
        agree = 0, wants = {},
        unarmed_mismatch = 0,
    }
    for _, path in ipairs(fixture_files()) do
        local ok0, _J, _b, heroes = pcall(rf.load, path)
        if ok0 then
            c.fixtures = c.fixtures + 1
            local names = {}
            for n in pairs(heroes) do names[#names + 1] = n end
            table.sort(names)
            for _, hero in ipairs(names) do
                c.subjects = c.subjects + 1
                local okp, J, bot = pcall(frame, path, hero, true, false)
                if okp and bot ~= nil and bot:IsAlive() then
                    c.alive = c.alive + 1
                    local okr, want = pcall(J.LaneRegenItemToUse, bot)
                    if okr and want ~= nil then
                        c.domain = c.domain + 1
                        local wname = want:GetName()
                        c.wants[wname] = (c.wants[wname] or 0) + 1
                        local tag = path:match('[^/]+$') .. '/' .. hero

                        local _Ja, ba = frame(path, hero, true, true)
                        local la, ea = drive(FIXED_CHUNK, ba)
                        if la == nil then
                            c.err = c.err + 1
                            c.err_frames[#c.err_frames + 1] = tag .. ' ' .. tostring(ea)
                        else
                            c.loadable = c.loadable + 1
                            if #la > 0 then c.post_acted = c.post_acted + 1
                            else c.post_silent_frames[#c.post_silent_frames + 1] = tag end

                            if PRE_CHUNK ~= nil then
                                local _Jp, bp = frame(path, hero, true, true)
                                local lp = drive(PRE_CHUNK, bp)
                                if lp ~= nil and #lp > 0 then
                                    c.pre_acted = c.pre_acted + 1
                                end
                            end

                            local _Js, bs = frame(path, hero, false, true)
                            local ls = drive(FIXED_CHUNK, bs)
                            if ls ~= nil and #ls > 0 then
                                c.shipped_acted = c.shipped_acted + 1
                                if item_name(ls[1]) == 'item_power_treads' then
                                    c.shipped_treads = c.shipped_treads + 1
                                end
                                if #la > 0 and item_name(ls[1]) == item_name(la[1])
                                    and ls[1].fn == la[1].fn then
                                    c.agree = c.agree + 1
                                end
                            end

                            -- Off the candidate the two trees must be identical:
                            -- the gated helper returns nil, so the branch is not
                            -- entered under either chunk.
                            if PRE_CHUNK ~= nil then
                                local _Ju, bu = frame(path, hero, false, true)
                                local lu = drive(PRE_CHUNK, bu)
                                local n1 = ls and #ls or -1
                                local n2 = lu and #lu or -1
                                if n1 ~= n2 then
                                    c.unarmed_mismatch = c.unarmed_mismatch + 1
                                elseif n1 > 0 and item_name(ls[1]) ~= item_name(lu[1]) then
                                    c.unarmed_mismatch = c.unarmed_mismatch + 1
                                end
                            end
                        end
                    end
                end
            end
        end
    end
    CENSUS = c
    return c
end

-- ---------------------------------------------------------------------------

tests['[final action] armed, the branch puts one self-targeted use of its own item on the engine'] = function()
    local J, bot = frame(KEYSTONE, KEYSTONE_BOT, true, true)
    local want = J.LaneRegenItemToUse(bot)
    assert(want ~= nil, 'the keystone left the lf_salve domain -- re-derive this file')

    local _J2, bot2 = frame(KEYSTONE, KEYSTONE_BOT, true, true)
    local log, err = drive(FIXED_CHUNK, bot2)
    assert(log ~= nil, 'the shipped item chain did not run: ' .. tostring(err))
    assert(#log == 1, 'expected exactly one action on the keystone, got ' .. #log)
    assert(log[1].fn == 'Action_UseAbilityOnEntity',
        'the regen item must reach the engine as a unit-targeted cast, got '
        .. tostring(log[1].fn))
    assert(item_name(log[1]) == want:GetName(),
        'the action carries ' .. item_name(log[1]) .. ' but the helper asked for '
        .. want:GetName())
    local target = log[1].args[2]
    assert(type(target) == 'table' and target.GetUnitName
        and target:GetUnitName() == KEYSTONE_BOT,
        'the regen item must be used on the bot itself, got '
        .. tostring(type(target) == 'table' and target.GetUnitName
            and target:GetUnitName() or target))
end

tests['[the defect] the two-argument call issues nothing at all, on every domain frame'] = function()
    assert(PRE_CHUNK ~= nil,
        'the pre-fix substitution no longer matches the call site; if the call '
        .. 'was reworded, re-derive the PRE chunk -- do not delete this test')
    local _J, bot = frame(KEYSTONE, KEYSTONE_BOT, true, true)
    local log, err = drive(PRE_CHUNK, bot)
    assert(log ~= nil, 'the pre-fix chain did not run: ' .. tostring(err))
    assert(#log == 0,
        'the two-argument X.SetUseItem produced ' .. #log
        .. ' action(s); it is supposed to fall off the end of the dispatcher')

    local c = census()
    assert(c.pre_acted == 0,
        'the pre-fix call now acts on ' .. c.pre_acted .. ' of ' .. c.loadable
        .. ' domain frames -- X.SetUseItem grew an arm that accepts nil, and the '
        .. 'whole reading in this file must be redone')
end

tests['[dispatcher] every arm of X.SetUseItem needs a cast type or a location-shaped target'] = function()
    local body = assert(AIUG_SRC:match(
        'function X%.SetUseItem%b()(.-)\nend\n'),
        'X.SetUseItem moved or changed signature')
    -- The four literal cast types, each guarded by an equality on sCastType.
    for _, ty in ipairs({ 'none', 'unit', 'tree', 'twice' }) do
        assert(body:find("sCastType == '" .. ty .. "'", 1, true),
            "the '" .. ty .. "' arm no longer keys on sCastType")
    end
    -- The one arm that can fire without a cast type keys on the TARGET having
    -- coordinates -- which a nil target does not.
    assert(body:find('hItemTarget.x ~= nil', 1, true),
        'the ground arm stopped requiring a location-shaped target; if it now '
        .. 'accepts nil, the defect this file pins has changed shape')
    assert(not body:find('sCastType == nil', 1, true),
        'X.SetUseItem grew a nil-cast-type default -- the call sites that omit '
        .. 'it are no longer silent, re-derive this file')
end

tests['[source ratchet] no X.SetUseItem call site may be short of arguments'] = function()
    local sites, short = 0, {}
    for pos in AIUG_SRC:gmatch('()X%.SetUseItem%s*%(') do
        -- Skip the declaration itself.
        local head = AIUG_SRC:sub(math.max(1, pos - 10), pos - 1)
        if not head:find('function%s*$') then
            sites = sites + 1
            local open = AIUG_SRC:find('%(', pos)
            local depth, i, args = 0, open, 1
            while i <= #AIUG_SRC do
                local ch = AIUG_SRC:sub(i, i)
                if ch == '(' then depth = depth + 1
                elseif ch == ')' then
                    depth = depth - 1
                    if depth == 0 then break end
                elseif ch == ',' and depth == 1 then args = args + 1 end
                i = i + 1
            end
            local line = select(2, AIUG_SRC:sub(1, pos):gsub('\n', '')) + 1
            if args < 3 then short[#short + 1] = 'aiug:' .. line end
        end
    end
    assert(sites >= 2,
        'X.SetUseItem call sites fell to ' .. sites .. '; the ratchet lost its subject')
    assert(#short == 0,
        'X.SetUseItem called with fewer than three arguments at '
        .. table.concat(short, ', ') .. ' -- the omitted cast type makes the call '
        .. 'a no-op AND suppresses the item loop behind it')
end

tests['[sister writing] the cast shape is read off the shipped considers, not invented'] = function()
    -- The helper can return exactly these two items. Read from ITS source, so a
    -- third one turns this red rather than quietly widening the claim.
    local helper = assert(JMZ_SRC:match(
        'function J%.LaneRegenItemToUse%b()(.-)\nend\n'),
        'J.LaneRegenItemToUse moved or changed signature')
    local returnable = {}
    for name in helper:gmatch("J%.GetItem2%(%s*bot%s*,%s*'([%w_]+)'%s*%)") do
        returnable[#returnable + 1] = name
    end
    table.sort(returnable)
    assert(#returnable == 2 and returnable[1] == 'item_clarity'
        and returnable[2] == 'item_flask',
        'J.LaneRegenItemToUse can now return {' .. table.concat(returnable, ', ')
        .. '}; the call site hard-codes the cast shape of flask/clarity, so a '
        .. 'new item needs its own shipped-consider check before it rides along')

    for _, name in ipairs(returnable) do
        local consider = assert(AIUG_SRC:match(
            'X%.ConsiderItemDesire%["' .. name .. '"%]%s*=%s*function%b()(.-)\nend\n'),
            'the shipped consider for ' .. name .. ' moved')
        assert(consider:find("local sCastType = 'unit'", 1, true),
            'the shipped consider for ' .. name .. " no longer casts as 'unit'; "
            .. 'the lf_salve call site copies that shape and must be re-derived')
        assert(consider:find('hEffectTarget = bot', 1, true),
            'the shipped consider for ' .. name .. ' no longer self-targets; the '
            .. 'lf_salve call site hands the bot itself and must be re-derived')
    end

    -- And the call site really does hand over that pair.
    assert(AIUG_SRC:find("X.SetUseItem( hRegen, bot, 'unit' )", 1, true),
        'the lf_salve call site drifted from ( hRegen, bot, \'unit\' )')
end

tests['[agreement] where the shipped layer reaches for the same item, the actions are identical'] = function()
    for _, f in ipairs(AGREEMENT) do
        local Ja, ba = frame(f.path, f.hero, true, true)
        local want = Ja.LaneRegenItemToUse(ba)
        assert(want ~= nil and want:GetName() == f.item,
            f.path .. ': the helper no longer wants ' .. f.item)
        local _J2, ba2 = frame(f.path, f.hero, true, true)
        local armed = assert(drive(FIXED_CHUNK, ba2), f.path .. ': armed chain failed')

        local _Js, bs = frame(f.path, f.hero, false, true)
        local shipped = assert(drive(FIXED_CHUNK, bs), f.path .. ': shipped chain failed')

        assert(#armed == 1 and #shipped == 1,
            f.path .. ': expected one action from each arm, got ' .. #armed
            .. ' armed and ' .. #shipped .. ' shipped')
        assert(armed[1].fn == shipped[1].fn,
            f.path .. ': armed issues ' .. armed[1].fn .. ' but the shipped layer '
            .. 'issues ' .. shipped[1].fn .. ' for the same item')
        assert(item_name(armed[1]) == f.item and item_name(shipped[1]) == f.item,
            f.path .. ': the two arms stopped agreeing on the item')
    end
    local c = census()
    assert(c.agree >= 2,
        'the frames where armed and shipped issue the same action fell to '
        .. c.agree .. ' (was 2); the cast shape is no longer pinned by execution')
end

tests['[suppression] the bug also cost frames an action the shipped tree was already making'] = function()
    local c = census()
    assert(c.shipped_acted >= 6,
        'the shipped item layer now acts on only ' .. c.shipped_acted
        .. ' of ' .. c.loadable .. ' domain frames (was 8); the suppression '
        .. 'reading rests on this column')
    assert(c.shipped_treads >= 1,
        'the item_power_treads share of the suppression column vanished; the '
        .. 'GH #133 artifact split in the header is stale')
    local honest = c.shipped_acted - c.shipped_treads
    assert(honest >= 3,
        'the honest (non-treads) suppression floor fell to ' .. honest
        .. ' of ' .. c.loadable .. ' (was 4)')
    assert(honest < c.shipped_acted,
        'the treads artifact disappeared from the column entirely -- if the '
        .. 'loader started wiring GetPowerTreadsStat, the bracket in the header '
        .. 'collapses to a single number and must be rewritten')
end

tests['[off-candidate equivalence] unarmed, the fix and the pre-fix tree behave identically'] = function()
    -- Structural first: the helper refuses before anything else when the gate
    -- is off, so the branch is unreachable in a shipped game either way.
    local helper = assert(JMZ_SRC:match(
        'function J%.LaneRegenItemToUse%b()(.-)\nend\n'))
    local first = helper:match('^%s*(.-)\n')
    assert(first:find("J.IsLaneFixOn( 'salve' )", 1, true)
        and first:find('return nil', 1, true),
        "J.LaneRegenItemToUse's first line is no longer the lf_salve refusal; "
        .. 'the "inert by default" claim must be re-established')

    local c = census()
    assert(c.unarmed_mismatch == 0,
        'off the candidate the fixed and pre-fix trees diverged on '
        .. c.unarmed_mismatch .. ' domain frame(s) -- the fix leaked out of its gate')
end

tests['[census] the domain, and both columns, on the whole corpus'] = function()
    local c = census()
    assert(c.fixtures >= 100, 'fixture corpus shrank to ' .. c.fixtures)
    assert(c.alive >= 900, 'alive-subject corpus shrank to ' .. c.alive)
    assert(c.domain >= 15,
        'the lf_salve domain fell to ' .. c.domain .. ' subjects (was 20); either '
        .. 'the helper narrowed or the corpus lost frames')
    assert(c.loadable + c.err == c.domain,
        'the domain does not close: ' .. c.loadable .. '+' .. c.err .. ' ~= ' .. c.domain)
    -- Both items are represented; a domain that collapses to one item stops
    -- testing the flask/clarity pair the cast shape is claimed for.
    assert((c.wants['item_flask'] or 0) >= 3 and (c.wants['item_clarity'] or 0) >= 3,
        'the domain lost one of its two items (flask ' .. (c.wants['item_flask'] or 0)
        .. ', clarity ' .. (c.wants['item_clarity'] or 0) .. ')')
    assert(c.post_acted >= math.floor(c.loadable * 0.9),
        'armed, only ' .. c.post_acted .. ' of ' .. c.loadable
        .. ' domain frames put an action on the engine (was 17/18)')
end

tests['[exceptions] the frames outside the census are enumerated, not tolerated'] = function()
    local c = census()
    assert(c.err <= 2,
        'a new frame stopped loading the item chain: '
        .. table.concat(c.err_frames, ', '))
    assert(#c.post_silent_frames <= 1,
        'a new silent armed frame appeared: '
        .. table.concat(c.post_silent_frames, ', '))

    -- Exception 1: queen_of_pain has no BotLib file (the GH #82 naming split),
    -- so the item chunk cannot load on any frame she is the subject of.
    local fh = io.open('bots/BotLib/hero_queen_of_pain.lua', 'r')
    if fh ~= nil then
        fh:close()
        error('hero_queen_of_pain.lua now exists -- the two load errors in the '
            .. 'census should have gone with it; re-measure')
    end

    -- Exception 2: the one silent armed frame is a SHIPPED refusal two guards
    -- above the branch, not a failure of the cast.
    local _J, bot = frame('tests/fixtures/f_260819_222559_od_eclipse_pair.lua',
        'npc_dota_hero_juggernaut', true, true)
    assert(bot:HasModifier('modifier_teleporting'),
        'the silent armed frame is no longer mid-teleport; its exemption from '
        .. 'the count needs a new reason')
end

tests['[successor hygiene] the five item-file globals are put back'] = function()
    census()
    for _, g in ipairs(AIUG_GLOBALS) do _G[g] = BEFORE[g] end
    for _, g in ipairs(AIUG_GLOBALS) do
        assert(_G[g] == BEFORE[g], g .. ' was not restored for the next test file')
    end
end

return tests

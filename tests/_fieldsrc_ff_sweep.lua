-- Heavy corpus sweep for tests/test_fieldsrc_ff_premise.lua, run as a
-- SUBPROCESS (the backlog 0q rule: a full-corpus drive that rebuilds jmz_func
-- once per hero-frame must not run on run_tests.lua's long-lived heap). The
-- leading underscore keeps run_tests.lua from globbing it.
--
-- WHAT IS MEASURED. J.HasFieldRegenSource says of itself that it counts "only
-- consumables whose presence in the slot already proves they are usable". This
-- sweep asks that question of ONE leg -- item_faerie_fire -- by reading the
-- gates of the only shipped code that can eat one, and evaluating them on the
-- frames where the presence test accepts a faerie fire and NOTHING else.
--
-- The consumer's constants are PARSED OUT OF THE SHIPPED SOURCE, never
-- hardcoded (the M13 lesson): a mutation of `10 * 60`, of the slot index, of
-- the `~=`/`==` operator or of the absolute-90 retreat floor must move this
-- census, or the census is not measuring the shipped tree.
--
-- Manifest grammar (one record per line, space-separated):
--   G <name> <value>        a constant parsed out of the shipped consumer
--   C <key> <n>             a counter bucket
--   FF <fixture> <hero> <health> <maxhp> <hp10000> <t10> <miss> <df> <sip_enough>
--       one live hero frame in the field-regen situation where the presence
--       test's ONLY accepted source is a faerie fire
--   DONE
-- The test treats absence of the final DONE line as a failed subprocess.

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')

local out = io.stdout
local AIUG = 'bots/ability_item_usage_generic.lua'

local function read_file(path)
    local f = assert(io.open(path, 'r'), path .. ' is not readable')
    local s = f:read('*a')
    f:close()
    return s
end

-- The faerie-fire consider function, sliced out by its own key so a constant
-- of the same shape elsewhere in this 8,500-line file cannot be picked up by
-- mistake.
local function faerie_block(src)
    local at = src:find('X.ConsiderItemDesire["item_faerie_fire"] = function', 1, true)
    if at == nil then return nil end
    local stop = src:find('X.ConsiderItemDesire[', at + 10, true) or #src
    return src:sub(at, stop)
end

local blk = faerie_block(read_file(AIUG))
local G = {}
if blk == nil then
    G.PARSE = 'MISSING_FUNCTION'
else
    -- Branch 0: the function's own floor -- below it every branch is dead.
    G.FOUNTAIN_FLOOR = tonumber(blk:match('bot:DistanceFromFountain%(%) < (%d+) then return'))
    -- Branch 1 (撤退): an ABSOLUTE health floor, not a fraction.
    G.RETREAT_HEALTH = tonumber(blk:match('bot:OriginalGetHealth%(%) < (%d+)'))
    -- Branch 2 (攻击): the only numeric gate a fixture can evaluate. Its
    -- companion clause reads botTarget, which is structurally nil on every
    -- fixture frame (GH #474) -- declared to the test, not silently skipped.
    G.ATTACK_HP = tonumber(blk:match('J.GetHP%( bot %) < ([%d%.]+)'))
    -- Branch 3 (自己吃): the only branch that can eat a faerie fire without a
    -- hero on the bot. Operator captured so an inversion moves the census
    -- instead of merely failing to parse.
    local a, b = blk:match('DotaTime%(%) > (%d+) %* (%d+)')
    if a ~= nil then G.SELF_TIME = tonumber(a) * tonumber(b) end
    local slot, op = blk:match('bot:GetItemInSlot%( (%d+) %) (.-)= nil')
    if slot ~= nil then
        G.SELF_SLOT = tonumber(slot)
        G.SELF_SLOT_OP = (op == '~') and 'occupied' or 'empty'
    end
    G.SELF_MISSING = tonumber(blk:match('bot:GetMaxHealth%(%) %- bot:OriginalGetHealth%(%) > (%d+)'))
end

for _, k in ipairs({ 'FOUNTAIN_FLOOR', 'RETREAT_HEALTH', 'ATTACK_HP', 'SELF_TIME',
                     'SELF_SLOT', 'SELF_SLOT_OP', 'SELF_MISSING', 'PARSE' }) do
    out:write(string.format('G %s %s\n', k, tostring(G[k])))
end

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

local c = setmetatable({}, { __index = function() return 0 end })
local function bump(k, n) rawset(c, k, c[k] + (n or 1)) end

-- Zero-initialised so an absent key and a measured zero are never the same
-- thing to the parser (the GH #171 shape: "the assertion never ran" must not
-- read as "the assertion passed").
for _, k in ipairs({ 'ff_sole', 'ff_sole_eatable', 'ff_sole_selftime_open',
    'ff_sole_selfslot_open', 'ff_sole_selfmiss_open', 'ff_sole_far',
    'ff_sole_retreat_open', 'ff_sole_attack_hp_open', 'ff_sole_sip_masked',
    'ff_sole_sip_enough', 'any_slot_occupied', 'any_after_selftime',
    'src_after_selftime', 'with_source', 'situation', 'live', 'fixtures',
    'IMPOSSIBLE_sole_without_source' }) do
    rawset(c, k, 0)
end

local ACCEPTED_OTHER = {
    item_flask = true, item_tango = true, item_tango_single = true,
}

for _, path in ipairs(fixture_files()) do
    local fx = dofile(path)
    if type(fx) == 'table' and fx.units and fx.time then
        bump('fixtures')
        for _, u in ipairs(fx.units) do
            if u.alive then
                local ok, J, bot = pcall(rf.load, path, u.name)
                if ok and bot ~= nil then
                    bump('live')
                    -- Corpus capability: the two reads the 自己吃 branch makes
                    -- are exercised SOMEWHERE in this corpus, so a zero on the
                    -- subject frames is a measurement and not a blind spot.
                    if G.SELF_SLOT ~= nil
                        and type(bot:GetItemInSlot(G.SELF_SLOT)) == 'table' then
                        bump('any_slot_occupied')
                    end
                    if G.SELF_TIME ~= nil and DotaTime() > G.SELF_TIME then
                        bump('any_after_selftime')
                    end

                    J.IsSoakCandidate = function() return false end
                    if J.IsFieldRegenSituation(bot) then
                        bump('situation')
                        local bSrc = J.HasFieldRegenSource(bot)
                        if bSrc then
                            bump('with_source')
                            if G.SELF_TIME ~= nil and DotaTime() > G.SELF_TIME then
                                bump('src_after_selftime')
                            end
                        end

                        local bFF, nOther = false, 0
                        for s = 0, 5 do
                            local hItem = bot:GetItemInSlot(s)
                            if type(hItem) == 'table' then
                                local sName = hItem:GetName()
                                if sName == 'item_faerie_fire' then
                                    bFF = true
                                elseif ACCEPTED_OTHER[sName] then
                                    nOther = nOther + 1
                                elseif sName == 'item_bottle' then
                                    local ch = hItem.GetCurrentCharges
                                        and tonumber(hItem:GetCurrentCharges()) or 0
                                    if (ch or 0) > 0 then nOther = nOther + 1 end
                                end
                            end
                        end

                        if bFF and nOther == 0 then
                            bump('ff_sole')
                            -- A frame the sole-source classification accepts
                            -- MUST be one the presence test accepts: the two
                            -- read the same slots and the same bottle-charge
                            -- test. A hit here is a real drift, not a nuance.
                            if not bSrc then bump('IMPOSSIBLE_sole_without_source') end

                            local nHealth = bot.OriginalGetHealth and bot:OriginalGetHealth()
                                or bot:GetHealth()
                            local nMax = bot:GetMaxHealth() or 0
                            local nMiss = nMax - nHealth
                            local nDist = bot:DistanceFromFountain() or 0

                            local bFar = G.FOUNTAIN_FLOOR ~= nil and nDist >= G.FOUNTAIN_FLOOR
                            local bTime = G.SELF_TIME ~= nil and DotaTime() > G.SELF_TIME
                            local bSlot = false
                            if G.SELF_SLOT ~= nil then
                                local bOcc = type(bot:GetItemInSlot(G.SELF_SLOT)) == 'table'
                                -- Written as an if, NOT as `cond and bOcc or
                                -- not bOcc`: that idiom returns the WRONG
                                -- branch whenever the middle term is false,
                                -- and it did -- the first run of this sweep
                                -- reported all 7 slot reads OPEN on frames
                                -- where slot 6 is empty.
                                if G.SELF_SLOT_OP == 'occupied' then
                                    bSlot = bOcc
                                else
                                    bSlot = not bOcc
                                end
                            end
                            local bMiss = G.SELF_MISSING ~= nil and nMiss > G.SELF_MISSING
                            local bRetreat = G.RETREAT_HEALTH ~= nil and nHealth < G.RETREAT_HEALTH
                            local bAttackHp = G.ATTACK_HP ~= nil and nMax > 0
                                and (nHealth / nMax) < G.ATTACK_HP

                            if bFar then bump('ff_sole_far') end
                            if bTime then bump('ff_sole_selftime_open') end
                            if bSlot then bump('ff_sole_selfslot_open') end
                            if bMiss then bump('ff_sole_selfmiss_open') end
                            if bRetreat then bump('ff_sole_retreat_open') end
                            if bAttackHp then bump('ff_sole_attack_hp_open') end
                            if bFar and bTime and bSlot and bMiss then
                                bump('ff_sole_eatable')
                            end

                            J.IsSoakCandidate = function(id) return id == 'fieldsip' end
                            local bEnough = J.IsFieldSipEnough(bot)
                            J.IsSoakCandidate = function() return false end
                            if bEnough then bump('ff_sole_sip_enough')
                            else bump('ff_sole_sip_masked') end

                            out:write(string.format('FF %s %s %d %d %d %d %d %d %s\n',
                                path:match('[^/]+$'), u.name, nHealth, nMax,
                                math.floor((nMax > 0 and nHealth / nMax or 0) * 10000 + 0.5),
                                math.floor(DotaTime() * 10 + 0.5),
                                nMiss, nDist, tostring(bEnough)))
                        end
                    end
                end
            end
        end
    end
end

local keys = {}
for k in pairs(c) do keys[#keys + 1] = k end
table.sort(keys)
for _, k in ipairs(keys) do out:write(string.format('C %s %d\n', k, c[k])) end
out:write('DONE\n')

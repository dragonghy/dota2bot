-- Heavy corpus sweep for tests/test_blind_a_wandlimbo_tpdead.lua, run as a
-- SUBPROCESS for the same reason as its siblings: a full-corpus drive that
-- rebuilds jmz_func once per hero-frame must not run on run_tests.lua's
-- long-lived heap.  The leading underscore keeps run_tests.lua from globbing it.
--
-- WHAT IS MEASURED.  Two armed soak candidates whose condition (a) -- "the
-- replay desk confirms the change actually fires and behaves correctly" --
-- cannot be bought from ANY instrument this lab owns.  Both were ruled on
-- 2026-09-08 (test_set.md §GC).  This file drives the two readings that the
-- ruling rests on, so neither is read off the source alone.
--
-- ⭐ THE SHAPE BOTH HALVES SHARE, and it is the reason they are one file: in
-- each case the wall was ALREADY WRITTEN DOWN IN THE TREE before the id was
-- armed, and the id was armed anyway.  A wall that is documented but not
-- instrumented stops nobody.
--
-- ------------------------------------------------------------------------
-- HALF 1 -- `wandlimbo`: the instrument answers 0, and 0 reads as "never fires"
-- ------------------------------------------------------------------------
--
-- J.ShouldDrinkWandInLimbo's FIRST conjunct is `hItem:GetCurrentCharges() < 6`.
-- Item charges are per-frame runtime state, and they are absent from BOTH ends
-- of this lab's evidence chain:
--
--   * tests/mock/replay_fixture.lua builds every inventory handle with
--     api.MakeAbility(name, { IsFullyCastable = true }).  GetCurrentCharges is
--     not among the served keys, so it falls through bot_api.lua's `^Get -> 0`
--     catch-all.  replay_fixture.lua's own header lists AbilityCharges under
--     "STILL REFUSED, deliberately".
--   * tools/batch_test/behavioral/dumper/main.go emits `Items []string` -- item
--     NAMES only.  The string "charge" does not occur in that file at all, so a
--     behavioural detector built on the .dem cannot reconstruct the clause
--     either.  G.DUMPER_CHARGE_MENTIONS parses that, rather than asserting it.
--
-- ⛔ SO THE DOMAIN READS ZERO FOR THE INSTRUMENT'S REASON, NOT THE WORLD'S, AND
-- ZERO IS THE ANSWER THAT KILLS THE ID.  This is the §GB.2 shape stated in the
-- charter three weeks after this id was armed: a wall hands back not a blank
-- but a number that looks ordinary and points at exactly one verdict.  `wl_full`
-- below is that zero.  `wl_nocharge` is the same predicate with the charge
-- conjunct removed -- the domain the zero is hiding -- and the two together are
-- the whole argument.  Neither number alone says anything.
--
-- ⭐⭐ THE WALL WAS DECLARED IN THIS SAME FILE, ~5,800 LINES ABOVE THE HELPER.
-- J.HasFieldRegenSource's comment (jmz_func.lua, the `stayfield` note) says both
-- halves in its own prose: "a fixture can never answer TRUE through the bottle
-- leg -- the mock's GetCurrentCharges default is 0. Declared, not hidden." and,
-- about the wand specifically, "its charge count -- the thing that decides
-- whether it heals at all -- is not in the dump."  That note then declines to
-- count the wand FOR THAT REASON and hands it to "its own lever ('wandbleed')".
-- `wandlimbo` was armed on 2026-08-19 with a charge count as its first conjunct.
-- G.STAYFIELD_DECLARES_* parse those two sentences, so the day somebody rewrites
-- the note this file goes red instead of quoting prose that is no longer there.
--
-- ------------------------------------------------------------------------
-- HALF 2 -- `tpdead`: armed alone it is a byte-for-byte no-op
-- ------------------------------------------------------------------------
--
-- The `tpdead` clause is an inline `if` in the body of
-- J.GetTpCommitDefendDesire, whose SECOND line is
-- `if not J.IsSoakCandidate('tpcommit') then return nil end`.  Its only writer
-- (bot.tpRespondAlly, ability_item_usage_generic.lua) is ungated but inert --
-- that file's own comment says "only J.GetTpCommitDefendDesire reads it, and
-- only with the 'tpdead' candidate armed".  So a wave that arms `tpdead` alone
-- measures nothing, and a wave that arms it WITH `tpcommit` measures a net
-- (pin creation + release) that §GA.1 established cannot be decomposed even in
-- sign.
--
-- This is the identical structure §GA.1 measured for `tpdying` -- the clause two
-- lines ABOVE this one, in the same function, retired from the armed set on
-- 2026-09-08 for exactly this reason.  `tpdead` is named verbatim in that
-- ruling ("两个释放(`tpdying`/`tpdead`)") and stayed armed.
--
-- ⭐⭐⭐ THE CONTROL FAILED, AND THAT IS THIS HALF'S REAL FINDING.  The drive
-- below arms `tpdead` alone and counts non-nil returns (`td_armed_alone_nonnil`,
-- 0), then arms `tpcommit` alone as the CONTROL (`tc_alone_nonnil`) -- which
-- must be > 0 or the first zero means nothing (the GH #171 shape).  It is 0 too.
--
-- The cause is measured, not guessed: `td_state_present` counts frames where
-- `bot.tpRespondUntil ~= nil`, the state J.GetTpCommitDefendDesire requires on
-- its FIFTH line (`if bot.tpRespondLoc == nil or bot.tpRespondUntil == nil then
-- return nil end`).  That state is written only by the response-TP branches of
-- ability_item_usage_generic.lua during a live game; a fixture-loaded bot has
-- never taken a TP, so it is nil on every frame in the corpus.
--
-- ⛔ SO THE ZEROS IN THIS HALF ARE NOT EVIDENCE ABOUT `tpdead`, AND ARE NOT USED
-- AS ANY.  What they establish is a THIRD blindness, which is worth more than
-- the reading they were meant to buy: J.GetTpCommitDefendDesire is
-- fixture-unreachable, so `tpdead`'s condition (a) cannot be bought from the
-- corpus path EITHER -- independently of the arming argument.  §GA.1 established
-- that the wave path cannot decompose it.  Both paths, for two different
-- reasons.  The reachability claim itself rests on the G-facts below (parsed
-- line order + the writer's own declared inertness), which are source readings
-- and are labelled as such.
--
-- ⛔ WHAT THIS FILE CANNOT MEASURE, STATED RATHER THAN IMPLIED.
--   1. It cannot show `wandlimbo` WOULD fire in a real game.  `wl_nocharge` is a
--      strict SUPERSET of the true domain -- it drops a real conjunct -- so it
--      is a ceiling on the hidden domain, never an estimate of it.
--   2. It cannot show the wand in those frames actually HAD >=6 charges.  That
--      is the whole point: nothing in this lab can.
--   3. Half 2's zero is about REACHABILITY, not about whether the `tpdead`
--      release is a good idea.  An unreachable lever and a bad lever look the
--      same in a verdict table; only the first one is fixed by an instrument.
--
-- Manifest grammar (one record per line, space-separated):
--   G <name> <value>    a constant / structural fact parsed out of the tree
--   C <key> <n>         a counter bucket
--   O <fixture> <hero> <hp_frac> <fountain_dist>
--       one live frame in `wl_nocharge` -- the hidden domain, listed rather than
--       only counted, so "the zero is the instrument's" is a readable set.
--   DONE
-- Absence of the final DONE line is a failed subprocess.

local out = io.stdout
package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')

local JMZ = 'bots/FunLib/jmz_func.lua'
local ITEMUSE = 'bots/ability_item_usage_generic.lua'
local DUMPER = 'tools/batch_test/behavioral/dumper/main.go'
local FIXLOADER = 'tests/mock/replay_fixture.lua'

local function read_file(path)
    local f = assert(io.open(path, 'r'), path .. ' is not readable')
    local s = f:read('*a')
    f:close()
    return s
end

local function strip_comments(s)
    if s == nil then return nil end
    return (s:gsub('%-%-[^\n]*', ''))
end

local function line_of(src, needle)
    local at = src:find(needle, 1, true)
    if at == nil then return -1 end
    local _, n = src:sub(1, at):gsub('\n', '')
    return n + 1
end

local G = {}
local jmzsrc = read_file(JMZ)
local usesrc = read_file(ITEMUSE)

-- ---------------------------------------------------------------- half 1 G
-- The helper body, comments stripped so the long prose above it cannot satisfy
-- a single assertion below (the §EN mistake this house already paid for once).
local wlblock = nil
do
    local at = jmzsrc:find('function J.ShouldDrinkWandInLimbo( bot, hItem )', 1, true)
    if at then
        local stop = jmzsrc:find('\nend', at, true) or #jmzsrc
        wlblock = strip_comments(jmzsrc:sub(at, stop))
    end
end
G.WL_BLOCK = wlblock and 1 or 0
G.WL_STRIPPED = (wlblock and not wlblock:find('--', 1, true)) and 1 or 0

-- ⭐ THE DRIFT GUARD.  Every clause re-expressed in the drive below is parsed
-- back out of the helper.  A literal that stops matching means the helper moved
-- and this sweep is measuring a predicate the tree no longer contains.
G.WL_CHARGES = wlblock and tonumber(wlblock:match('nCharges < (%d+)')) or -1
G.WL_HP = wlblock and tonumber(wlblock:match('GetMaxHealth%(%) %* ([%d%.]+)')) or -1
G.WL_RING = wlblock and tonumber(wlblock:match('GetNearbyHeroes%( bot, (%d+)')) or -1
G.WL_FOUNTAIN = wlblock and tonumber(
    wlblock:match('GetDistanceFromAllyFountain%( bot %) <= (%d+)')) or -1
G.WL_HEAL = wlblock and tonumber(wlblock:match('nCharges %* (%d+)')) or -1
-- The charge read is the FIRST conjunct after the two gates.  Its position is
-- load-bearing: it is what makes the instrument's 0 short-circuit everything
-- else, so a reordering that put it last would change what wl_full's zero means.
G.WL_CHARGE_LINE = line_of(jmzsrc, 'local nCharges = hItem:GetCurrentCharges()')
G.WL_HP_LINE = line_of(jmzsrc, 'if bot:GetHealth() > bot:GetMaxHealth() * 0.25 then return false end')
G.WL_CHARGE_FIRST = (G.WL_CHARGE_LINE > 0 and G.WL_HP_LINE > 0
    and G.WL_CHARGE_LINE < G.WL_HP_LINE) and 1 or 0

-- ⭐⭐ The declaration that already existed.  Both sentences, parsed.
G.STAYFIELD_DECLARES_MOCK = jmzsrc:find(
    "GetCurrentCharges default is 0. Declared, not hidden.", 1, true) and 1 or 0
G.STAYFIELD_DECLARES_DUMP = jmzsrc:find(
    "decides whether it heals at all -- is not in the dump.", 1, true) and 1 or 0

-- The two ends of the evidence chain, parsed rather than asserted.
do
    local dsrc = read_file(DUMPER)
    local n = 0
    for _ in dsrc:lower():gmatch('charge') do n = n + 1 end
    G.DUMPER_CHARGE_MENTIONS = n
    G.DUMPER_ITEMS_NAMES_ONLY = dsrc:find('Items     []string', 1, true) and 1 or 0
end
do
    local fsrc = read_file(FIXLOADER)
    G.FIXLOADER_REFUSES_CHARGES = fsrc:find(
        'STILL REFUSED, deliberately: ChannelTime, Duration, Charges.', 1, true) and 1 or 0
    G.FIXLOADER_SERVES_CHARGES =
        fsrc:find('GetCurrentCharges =', 1, true) and 1 or 0
end

-- ---------------------------------------------------------------- half 2 G
G.TPFN_LINE = line_of(jmzsrc, 'function J.GetTpCommitDefendDesire( bot, nLane )')
G.TPCOMMIT_GATE_LINE = -1
G.TPDEAD_CLAUSE_LINE = line_of(jmzsrc, "if J.IsSoakCandidate( 'tpdead' )")
G.TPDYING_CLAUSE_LINE = line_of(jmzsrc, "if J.IsSoakCandidate( 'tpdying' )")
do
    -- The tpcommit gate is found INSIDE the function, not by first occurrence in
    -- the file: the id is named in several unrelated comments.
    local at = jmzsrc:find('function J.GetTpCommitDefendDesire( bot, nLane )', 1, true)
    if at then
        local rel = jmzsrc:find("if not J.IsSoakCandidate( 'tpcommit' ) then return nil end",
            at, true)
        if rel then
            local _, n = jmzsrc:sub(1, rel):gsub('\n', '')
            G.TPCOMMIT_GATE_LINE = n + 1
        end
    end
end
-- The whole reachability argument is a statement about ORDER: the gate returns
-- before either release clause can be reached.
G.TPDEAD_INSIDE_GATE = (G.TPCOMMIT_GATE_LINE > 0 and G.TPDEAD_CLAUSE_LINE > 0
    and G.TPCOMMIT_GATE_LINE < G.TPDEAD_CLAUSE_LINE) and 1 or 0
G.TPDYING_INSIDE_GATE = (G.TPCOMMIT_GATE_LINE > 0 and G.TPDYING_CLAUSE_LINE > 0
    and G.TPCOMMIT_GATE_LINE < G.TPDYING_CLAUSE_LINE) and 1 or 0
-- `tpdead`'s clause is INLINE, not a call to a separately gated helper.  That
-- distinction is the GH #622 reading: tests/test_gated_helper_nesting_census.lua
-- censuses helper-in-helper conjunctions, and this conjunction has no helper.
G.TPDEAD_IS_INLINE = (jmzsrc:find(
    "if J.IsSoakCandidate( 'tpdead' )\n\tand bot.tpRespondAlly ~= nil", 1, true)) and 1 or 0
-- The writer is ungated (it runs in every game) but inert, and the file says so.
G.TPDEAD_WRITER_UNGATED = usesrc:find('bot.tpRespondAlly = hRescueAlly', 1, true) and 1 or 0
G.TPDEAD_WRITER_DECLARED_INERT = usesrc:find(
    "only J.GetTpCommitDefendDesire reads it, and only with", 1, true) and 1 or 0
G.TPDEAD_READ_SITES = 0
for _ in jmzsrc:gmatch('bot%.tpRespondAlly') do
    G.TPDEAD_READ_SITES = G.TPDEAD_READ_SITES + 1
end

-- ------------------------------------------------------------------- drive
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
-- Zero-initialised so "the bucket was never reached" and "the bucket measured
-- zero" are never the same thing to the parser (the GH #171 shape).  Every
-- claim in the ruling rests on telling those two apart.
for _, k in ipairs({ 'fixtures', 'live', 'turbo',
    'has_wand', 'charges_read', 'charges_nonzero',
    'wl_full', 'wl_nocharge', 'wl_err',
    'td_probe_runs', 'td_armed_alone_nonnil', 'tc_alone_nonnil', 'td_err',
    'td_state_present', 'arm_leak' }) do
    bump(k, 0)
end

local hidden = {}
local WAND = { 'item_magic_wand', 'item_magic_stick' }

for _, path in ipairs(fixture_files()) do
    local fx = dofile(path)
    if type(fx) == 'table' and fx.units and fx.time then
        bump('fixtures')
        for _, u in ipairs(fx.units) do
            if u.alive then
                local ok, J, bot = pcall(rf.load, path, u.name)
                if ok and bot ~= nil then
                    bump('live')
                    local sArmed = nil
                    J.IsSoakCandidate = function(sId)
                        return sArmed ~= nil and sId == sArmed
                    end

                    if J.IsModeTurbo() then
                        bump('turbo')

                        -- ---------------------------------------- half 1
                        local hWand = nil
                        for _, nm in ipairs(WAND) do
                            local slot = bot:FindItemSlot(nm)
                            if slot ~= nil and slot >= 0 and slot <= 5 then
                                hWand = bot:GetItemInSlot(slot)
                                break
                            end
                        end
                        if hWand ~= nil then
                            bump('has_wand')
                            bump('charges_read')
                            local nC = tonumber(hWand:GetCurrentCharges()) or -1
                            if nC > 0 then bump('charges_nonzero') end

                            sArmed = 'wandlimbo'
                            -- The arming must be ONE id wide: a stub arming a
                            -- sibling would let it move the answer while the
                            -- frame is still attributed here (the M8 survivor of
                            -- the 'stayattr' round).
                            for _, other in ipairs({ 'wandbleed', 'wandbleed2',
                                'stayfield', 'fieldsip', 'bagsalve' }) do
                                if J.IsSoakCandidate(other) then bump('arm_leak') end
                            end
                            local okwl, bWL = pcall(function()
                                return J.ShouldDrinkWandInLimbo(bot, hWand)
                            end)
                            if not okwl then bump('wl_err') end
                            if okwl and bWL then bump('wl_full') end

                            -- The same predicate with the charge conjunct
                            -- REMOVED.  Re-expressed here, which is why every
                            -- literal above is drift-guarded: this is the only
                            -- number that can say the zero above is the
                            -- instrument's.
                            local oknc, bNC = pcall(function()
                                return bot:GetHealth() <= bot:GetMaxHealth() * G.WL_HP
                                    and #J.GetNearbyHeroes(bot, G.WL_RING, true, BOT_MODE_NONE) == 0
                                    and J.GetDistanceFromAllyFountain(bot) > G.WL_FOUNTAIN
                                    -- the no-overheal clause at the sweep's own
                                    -- charge floor: without a real charge count
                                    -- the best available stand-in is the minimum
                                    -- the helper would accept.
                                    and (bot:GetMaxHealth() - bot:GetHealth())
                                        >= G.WL_CHARGES * G.WL_HEAL
                            end)
                            if not oknc then bump('wl_err') end
                            if oknc and bNC then
                                bump('wl_nocharge')
                                hidden[#hidden + 1] = string.format(
                                    'O %s %s %.4f %.1f',
                                    path:match('([^/]+)%.lua$'), u.name,
                                    J.GetHP(bot), J.GetDistanceFromAllyFountain(bot))
                            end
                            sArmed = nil
                        end

                        -- ---------------------------------------- half 2
                        -- The gate this drive actually dies on, counted before
                        -- anything is armed: without it the two zeros below have
                        -- no explanation and could be read as a result.
                        if bot.tpRespondUntil ~= nil and bot.tpRespondLoc ~= nil then
                            bump('td_state_present')
                        end
                        for _, probe in ipairs({ 'tpdead', 'tpcommit' }) do
                            sArmed = probe
                            bump('td_probe_runs')
                            for _, other in ipairs({ 'tpdead', 'tpcommit', 'tpdying',
                                'teambrain' }) do
                                if other ~= probe and J.IsSoakCandidate(other) then
                                    bump('arm_leak')
                                end
                            end
                            -- Every lane, because the function's tail binds to a
                            -- lane front and a single lane could miss the frame.
                            for _, lane in ipairs({ LANE_TOP, LANE_MID, LANE_BOT }) do
                                local oktd, vTd = pcall(function()
                                    return J.GetTpCommitDefendDesire(bot, lane)
                                end)
                                if not oktd then
                                    bump('td_err')
                                elseif vTd ~= nil then
                                    if probe == 'tpdead' then
                                        bump('td_armed_alone_nonnil')
                                    else
                                        bump('tc_alone_nonnil')
                                    end
                                end
                            end
                            sArmed = nil
                        end
                    end
                end
            end
        end
    end
end

local gk = {}
for k in pairs(G) do gk[#gk + 1] = k end
table.sort(gk)
for _, k in ipairs(gk) do out:write(string.format('G %s %s\n', k, tostring(G[k]))) end

local ck = {}
for k in pairs(c) do ck[#ck + 1] = k end
table.sort(ck)
for _, k in ipairs(ck) do out:write(string.format('C %s %d\n', k, c[k])) end

for _, line in ipairs(hidden) do out:write(line .. '\n') end
out:write('DONE\n')

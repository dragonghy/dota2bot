-- Heavy corpus sweep for tests/test_wkreinctr_untrained.lua, run as a
-- SUBPROCESS (a full-corpus drive that rebuilds jmz_func once per hero-frame
-- must not run on run_tests.lua's long-lived heap).  The leading underscore
-- keeps run_tests.lua from globbing it (it globs `^test_.*%.lua$`).
--
-- WHAT IS MEASURED.  J.IsWkReincarnationArmed (bots/FunLib/jmz_func.lua) is
-- SHIPPED and its single call site -- mode_retreat_generic.lua ~:198, also
-- SHIPPED and un-gated -- answers BOT_MODE_DESIRE_NONE, i.e. it suppresses the
-- WHOLE retreat mode for a Wraith King in a team fight.  The helper decides
-- that on two engine reads: a cooldown, and 160 mana.  Neither of them asks
-- whether the ultimate has a skill point in it, and an unlearned ability is a
-- level-0 handle whose cooldown reads 0.0 -- so an untrained Reincarnation
-- reads ARMED.  'wkreinctr' adds `not abilityR:IsTrained()` as a veto.
--
-- ⭐⭐ TWO COLUMNS, AND THE SECOND ONE IS A ZERO THAT MUST NOT BE READ AS "no
-- effect".  The HELPER column is what this lever changes; the CALL SITE column
-- is what the corpus can reach.  They differ by two conjuncts that belong to
-- the call site, not to the lever (`GetLevel() >= 6` and `J.IsInTeamFight(bot,
-- 1200)`), and the second of them is FALSE on every WK frame this corpus holds
-- -- a geometric fact about a corpus cut for the P2 home-TP investigation, not
-- a statement about the lever.  Both columns are emitted and both are asserted,
-- so neither can stand in for the other (the §FP.5 lesson: a structural zero
-- and a measured no-effect are the same row in a ruling table unless the sweep
-- separates them).
--
-- ⭐ THE ANTI-VACUUM WALK.  Every WK frame gets a `W` row carrying the clause
-- that decided it, in the domain or not, so "the corpus has no untrained ults"
-- and "it has them and something above rejects them first" can never read the
-- same.  The buckets are counted, never subtracted, and their sum is asserted
-- equal to the frame count downstream.
--
-- ⛔ DIRECTION GOES THROUGH A COUNTER THAT IS PROVED TO COUNT.  This lever
-- prepends a veto, so it can only turn TRUE into FALSE and `flip_false_to_true`
-- must be 0 over the whole corpus.  A counter whose content is all zeros cannot
-- tell "the direction holds" from "the tally never ran" -- deleting its bump
-- would leave the manifest byte-identical (the M14 lesson of the 'staytower'
-- round).  So both directions go through ONE `tally(a, b, sDown, sUp)` and it
-- is called a SECOND time with the legs SWAPPED: the branch that must read 0 on
-- the real call is the branch that must report the WHOLE domain on the swapped
-- call.
--
-- ⭐ THE PAIR COLUMN.  This helper now carries TWO ids on two different
-- clauses ('wkreincarnmp' on the mana threshold, 'wkreinctr' on the trained
-- test).  Two independently sufficient tests on one helper is the shape where
-- arming one measures a correct ZERO wherever the other also fires (the
-- 'staysrc'/'staytower' lesson).  `pair_ne_arm` counts the frames where arming
-- BOTH differs from arming THIS ONE alone, and `pair_ne_arm_in_flipset` says
-- how many of those sit inside this lever's own flip set -- the second must be
-- 0 or a single-arm wave could not attribute the flips.  Both halves are bumped
-- through ONE call so the 0 is proved to be a measurement (see the block that
-- does it: the first version was a bare `if ... then bump() end` asserted == 0,
-- and the stand's M15 walked straight through it).
--
-- ⚠️ ANCHORS ARE COUNTED AND FRONTIER-ANCHORED (GH #550/#555, third form).  A
-- structural fact parsed with `if(.-)then` splits on the `if` INSIDE
-- `HasModifier`, and nothing goes red -- the number is just wrong.  Every
-- keyword read below is `%f[%w]`-anchored and asserted against a declared
-- count, never eyeballed.
--
-- Manifest grammar (one record per line, space-separated):
--   G <name> <value>    a constant / structural fact parsed out of the tree
--   C <key> <n>         a counter bucket
--   W <fixture> <hero_level> <ability_level> <trained> <cd> <mana> <ship> <arm> <fight> <stop>
--       one live Wraith King frame, with the clause that decided it:
--       cd | untrained | mana | armed  (armed = shipped says TRUE, trained)
--   F <fixture> <hero_level> <mana>
--       one live frame where the HELPER flips true -> false
--   S <fixture> <hero_level>
--       one live frame where the CALL SITE's guard chain flips true -> false
--   DONE
-- Absence of the final DONE line is a failed subprocess.

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')

local out = io.stdout
local JMZFILE = 'bots/FunLib/jmz_func.lua'
local RETFILE = 'bots/mode_retreat_generic.lua'
local WK = 'npc_dota_hero_skeleton_king'

local function read_file(path)
    local f = assert(io.open(path, 'r'), path .. ' is not readable')
    local s = f:read('*a')
    f:close()
    return s
end

local function block(src, header, stopPat)
    local at = src:find(header, 1, true)
    if at == nil then return nil end
    local stop = src:find(stopPat, at + #header) or #src
    return src:sub(at, stop)
end

-- Structural facts are claims about CODE.  This lever ships with a long comment
-- quoting the call site, the huskar block and both id names, so reading the raw
-- block would let the COMMENT satisfy the assertions (the §EN mistake).
local function strip_comments(s)
    if s == nil then return nil end
    return (s:gsub('%-%-[^\n]*', ''))
end

local G = {}
local jmz = read_file(JMZFILE)
local fn = strip_comments(block(jmz, 'function J.IsWkReincarnationArmed( bot )', '\nfunction '))
G.FN = fn and 1 or 0
G.FN_SOAKID = (fn and fn:find("J.IsSoakCandidate( 'wkreinctr' )", 1, true)) and 1 or 0
G.FN_TURBO = (fn and fn:find('J.IsModeTurbo()', 1, true)) and 1 or 0
G.FN_ISTRAINED = (fn and fn:find('abilityR:IsTrained()', 1, true)) and 1 or 0
-- The 'pullcad' trap is TWO IDS IN ONE CONDITION.  The helper legitimately
-- holds two ids on two SEPARATE clauses, so the invariant is the maximum per
-- condition, not the total.  Read by splitting on `then` at a statement
-- boundary would re-run the GH #550 mistake, so the two conditions are located
-- by their own gate calls and each is scanned for a second IsSoakCandidate.
G.FN_NIDS = 0
if fn then for _ in fn:gmatch('IsSoakCandidate') do G.FN_NIDS = G.FN_NIDS + 1 end end
do
    local a = fn and fn:find("IsSoakCandidate( 'wkreinctr' )", 1, true)
    local b = fn and fn:find("IsSoakCandidate( 'wkreincarnmp' )", 1, true)
    -- The two gates must be in DIFFERENT statements, and the new one must come
    -- first (it returns before the mana clause is reached, which is what makes
    -- each independently sufficient).
    G.FN_GATE_ORDER = (a and b and a < b) and 1 or 0
    -- Between the two gate calls there must be a `return false` -- the early
    -- exit.  Frontier-anchored so `return` inside an identifier cannot match.
    local between = (a and b) and fn:sub(a, b) or ''
    G.FN_EARLY_RETURN = between:find('%f[%w]return%f[%W]%s+false') and 1 or 0
end
-- ⛔ THE GATE MUST BE THE FIRST CONJUNCT of its condition.  That is what makes
-- the un-armed evaluation byte-identical -- neither J.IsModeTurbo nor the
-- engine's IsTrained() is reached.  Read as an ORDER inside the stripped block.
do
    local g = fn and fn:find("IsSoakCandidate( 'wkreinctr' )", 1, true)
    local t = fn and fn:find('IsModeTurbo()', 1, true)
    local i = fn and fn:find('abilityR:IsTrained()', 1, true)
    G.FN_GATE_FIRST = (g and t and i and g < t and t < i) and 1 or 0
end
-- ⭐ THE CONDITION-(c) EVIDENCE IS A COUNT OF SITES, NOT A PRESENCE FLAG.  The
-- argument is "the tree asks IsTrained() before believing a GetAbilityByName
-- handle, including eight lines from this call site"; a flag reads the same
-- whether that happens once or thirty times, and the 'stayurn' round's M6
-- survivor is exactly what a presence flag costs.  Counted in the retreat mode
-- file (the call site's own file) and tree-wide.
local ret = strip_comments(read_file(RETFILE))
local nRetTrained = 0
for _ in ret:gmatch('IsTrained%(%)') do nRetTrained = nRetTrained + 1 end
G.RETREAT_ISTRAINED_SITES = nRetTrained
G.RETREAT_CALLS_HELPER =
    ret:find('J.IsWkReincarnationArmed(bot)', 1, true) and 1 or 0
G.RETREAT_LEVEL_GUARD =
    ret:find('bot:GetLevel() >= 6', 1, true) and 1 or 0
G.RETREAT_FIGHT_GUARD =
    ret:find('J.IsInTeamFight(bot, 1200)', 1, true) and 1 or 0
-- The helper has exactly ONE caller in bots/; a second one would change what
-- the call-site column means, so it is counted rather than assumed.
local nCallers = 0
do
    local p = assert(io.popen(
        "grep -rl 'IsWkReincarnationArmed' bots/ 2>/dev/null | wc -l"))
    nCallers = tonumber(p:read('*a')) or -1
    p:close()
end
-- jmz_func.lua (the definition) plus mode_retreat_generic.lua (the caller).
G.FILES_NAMING_HELPER = nCallers

local gk = {}
for k in pairs(G) do gk[#gk + 1] = k end
table.sort(gk)
for _, k in ipairs(gk) do out:write(string.format('G %s %s\n', k, tostring(G[k]))) end

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
local function bump(k) rawset(c, k, c[k] + 1) end
-- Zero-initialised so "the bucket was never reached" and "the bucket measured
-- zero" are never the same thing to the parser (the GH #171 shape).
for _, k in ipairs({ 'fixtures', 'live', 'wk_frames', 'raises',
    'ship_true', 'arm_true', 'flips', 'flip_false_to_true',
    'flips_swapped', 'flip_false_to_true_swapped',
    'stop_cd', 'stop_untrained', 'stop_mana', 'stop_armed',
    'untrained_frames', 'wk_lv6', 'ship_true_untrained_lv6',
    'site_ship_true', 'site_arm_true', 'site_flips', 'fight_true',
    'pair_ne_arm', 'pair_ne_arm_in_flipset', 'pair_ne_arm_out_flipset',
    'arm_leak' }) do
    rawset(c, k, 0)
end

--- ONE tally for both directions, called twice with the legs swapped.
local function tally(a, b, sDown, sUp)
    if a and not b then bump(sDown) end
    if b and not a then bump(sUp) end
end

for _, path in ipairs(fixture_files()) do
    local fx = dofile(path)
    if type(fx) == 'table' and fx.units and fx.time then
        bump('fixtures')
        for _, u in ipairs(fx.units) do
            if u.alive then
                local ok, J, bot = pcall(rf.load, path, u.name)
                if ok and bot ~= nil then
                    bump('live')
                    if u.name == WK then
                        bump('wk_frames')
                        local armed, both = false, false
                        J.IsSoakCandidate = function(sId)
                            if both then return sId == 'wkreinctr' or sId == 'wkreincarnmp' end
                            return armed and sId == 'wkreinctr'
                        end
                        local sFx = path:match('([^/]+)%.lua$')
                        local hR = bot:GetAbilityByName('skeleton_king_reincarnation')
                        local nLv = bot:GetLevel()
                        local nAbLv = (hR ~= nil and hR:GetLevel()) or -1
                        local bTrained = (hR ~= nil and hR:IsTrained()) and true or false
                        local nCd = (hR ~= nil and hR:GetCooldownTimeRemaining()) or -1
                        local nMana = bot:GetMana()
                        if not bTrained then bump('untrained_frames') end
                        if nLv >= 6 then bump('wk_lv6') end

                        local ok1, shipped = pcall(J.IsWkReincarnationArmed, bot)
                        armed = true
                        -- The arming must be ONE id wide.  A stub arming them
                        -- all would let another live id move this answer while
                        -- the flip is still attributed here (the M8 survivor of
                        -- the 'stayattr' round).  Asserted 0 downstream.
                        if J.IsSoakCandidate('wkreincarnmp')
                            or J.IsSoakCandidate('c2') or J.IsSoakCandidate('stayfield') then
                            bump('arm_leak')
                        end
                        local ok2, arm = pcall(J.IsWkReincarnationArmed, bot)
                        armed, both = false, true
                        local ok3, pair = pcall(J.IsWkReincarnationArmed, bot)
                        both = false

                        if not (ok1 and ok2 and ok3) then
                            bump('raises')
                        else
                            shipped = shipped and true or false
                            arm = arm and true or false
                            pair = pair and true or false
                            -- Two independently sufficient tests on one helper.
                            -- `pair_ne_arm` is the honest total: frames where
                            -- arming BOTH lands somewhere arming THIS ONE alone
                            -- does not -- those belong to the sibling
                            -- ('wkreincarnmp' swaps the 160 for the real, higher
                            -- level-1 cost), and their existence is why this is
                            -- measured instead of argued.  The load-bearing one
                            -- is the SECOND: inside this lever's own flip set
                            -- the pair must agree with the single arm, or a
                            -- single-arm wave could not attribute the flip.
                            --
                            -- ⛔ AND THE IN-FLIPSET COUNTER IS PROVED TO COUNT.
                            -- Its first version was `if shipped and not arm
                            -- then bump(...) end`, asserted == 0 downstream --
                            -- and the mutation stand's M15 SURVIVED, because
                            -- deleting that bump leaves a zero that reads
                            -- exactly like a measured one (the GH #171 shape,
                            -- landing on this file's own pair column). Both
                            -- halves now go through ONE bump, so the branch
                            -- that must read 0 is the branch that must report
                            -- the whole set on the other side, and their sum is
                            -- asserted against `pair_ne_arm`.
                            if pair ~= arm then
                                bump('pair_ne_arm')
                                bump((shipped and not arm)
                                    and 'pair_ne_arm_in_flipset'
                                    or 'pair_ne_arm_out_flipset')
                            end

                            if shipped then bump('ship_true') end
                            if arm then bump('arm_true') end
                            tally(shipped, arm, 'flips', 'flip_false_to_true')
                            -- Legs EXCHANGED, same `tally`: the counter that
                            -- must read 0 on the real call is the one that must
                            -- report the WHOLE domain here (the M14 lesson).
                            tally(arm, shipped, 'flips_swapped', 'flip_false_to_true_swapped')
                            if shipped and not arm then
                                out:write(string.format('F %s %d %.0f\n', sFx, nLv, nMana))
                            end
                            if shipped and not bTrained and nLv >= 6 then
                                bump('ship_true_untrained_lv6')
                            end

                            -- THE CALL SITE column: mode_retreat_generic ~:198.
                            -- Its two extra conjuncts are evaluated here from
                            -- the same frame, never re-implemented from a copy
                            -- of the helper.
                            local bFight = J.IsInTeamFight(bot, 1200) and true or false
                            if bFight then bump('fight_true') end
                            local siteShip = bFight and nLv >= 6 and shipped
                            local siteArm = bFight and nLv >= 6 and arm
                            if siteShip then bump('site_ship_true') end
                            if siteArm then bump('site_arm_true') end
                            if siteShip and not siteArm then
                                bump('site_flips')
                                out:write(string.format('S %s %d\n', sFx, nLv))
                            end

                            -- The anti-vacuum walk: every WK frame names the
                            -- clause that decided it.  Counted, never
                            -- subtracted; the four buckets sum to wk_frames.
                            local sStop
                            if nCd > 1.0 then sStop = 'stop_cd'
                            elseif not bTrained then sStop = 'stop_untrained'
                            elseif nMana < 160 then sStop = 'stop_mana'
                            else sStop = 'stop_armed' end
                            bump(sStop)
                            out:write(string.format('W %s %d %d %s %.1f %.0f %s %s %s %s\n',
                                sFx, nLv, nAbLv, tostring(bTrained), nCd, nMana,
                                tostring(shipped), tostring(arm), tostring(bFight), sStop))
                        end
                    end
                end
            end
        end
    end
end

local ck = {}
for k in pairs(c) do ck[#ck + 1] = k end
table.sort(ck)
for _, k in ipairs(ck) do out:write(string.format('C %s %d\n', k, c[k])) end
out:write('DONE\n')

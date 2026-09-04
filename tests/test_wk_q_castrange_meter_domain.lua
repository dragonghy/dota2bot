-- [ratchet] [hero] Wraith King's ConsiderQ, frame by frame over the whole
-- archive: the fifth meter zero, and what it does to the `wkqdmg` domain that
-- GH #390 asked to have re-registered.
--
-- WHY THIS FILE EXISTS (hero 2026-09-01, claiming GH #390).  The replay group
-- verified `wkqdmg` on W34 and landed INDETERMINATE: the arithmetic is right on
-- a real frame (shipped claims 168, the blast alone did 120, the target lived),
-- but the decision cell that can carry a verdict -- `band_pair` on the baseline
-- leg -- read 0/97, with the nearest baseline cast missing the band by 63.6
-- ehp.  Its recommendation 2 was "ask a branch-REACH question instead", and its
-- recommendation 3 was "the registered domain is the ARITHMETIC domain (Q rank
-- 1); the DECISION domain is a different set three orders of magnitude smaller".
--
-- Both are answered here, and the answer to the first one is not the one the
-- issue expected: this repository could not have asked the reach question off
-- its fixture archive at all, because the ring the branch searches has been
-- 330 units wide instead of 855 on every frame ever driven through it.
--
-- ===========================================================================
-- 1.  THE FIFTH METER ZERO: `GetCastRange` is on no spec, so the generic `^Get`
--     default answers 0 -- on 36 of 36 live-WK instants in the archive.
-- ===========================================================================
--
-- Same family as GetActualIncomingDamage (hero 2026-08-29), GetAbilityDamage
-- (GH #175), GetManaCost (hero 2026-09-01) and GetAOERadius (GH #386).  One
-- thing makes this one different from all four, and it is the reason it is
-- worth a file: THE ANSWER IS ALREADY IN THE REPOSITORY.  GetAOERadius has no
-- KV key to read (#386 §"honest bound").  `AbilityCastRange` does --
-- tests/mock/special_value_shapes.lua carries it for 14 of the 21 focus-five
-- abilities, and for Wraithfire Blast it reads 525, three lines above the
-- AbilityManaCost ladder that the 2026-09-01 repair wired up.  The meter was
-- not missing its data; it was missing its wire.
--
-- Blast radius: 433 GetCastRange call sites across 150 files under bots/ (§2).
-- That is 62x the GetAOERadius census and it is not a WK problem -- it is every
-- range-gated branch on every hero, which is why nothing is repaired here.
--
-- ===========================================================================
-- 2.  WHAT THE ZERO DOES TO ConsiderQ -- CLOSED FORM, NO CORPUS
-- ===========================================================================
--
-- `nCastRange = abilityQ:GetCastRange()` feeds four rings in this function.
-- With the true 525 against the measured 0:
--
--     the search ring, nEnemysHerosInBonus  = nCastRange + 330 ...  855 -> 330
--     the tight ring,  nEnemysHerosInRange  = nCastRange +  43 ...  568 ->  43
--     the kill-confirm gate, dist <= nCastRange + 80 ..............  605 ->  80
--     the ranged-solo widening, nCastRange + 350 .................  875 -> 350
--
-- A 43-unit ring is smaller than the hero's own collision box.  Every
-- fixture-driven statement of the form "this frame does not reach ConsiderQ's
-- branch N" that this repository has ever made was taken through those rings,
-- and the failure direction is the dangerous one: it UNDERSTATES reach, the
-- same direction as the GetAOERadius zero and the opposite of the mana one.
--
-- ===========================================================================
-- 3.  THE CORPUS ZERO WAS VACUOUS ON 16 OF 18 FRAMES
-- ===========================================================================
--
-- 36 live-WK instants across tests/fixtures/ + tests/frames/.  Q is untrained
-- on 5, on cooldown on 9 and mana-parked on 4, so 18 reach the body.  On those
-- 18, under the meter zero, the kill-confirm loop is entered ZERO times: not
-- one frame put an enemy hero inside 330 units.  Feed the KV 525 back and 2 of
-- the 18 enter the loop and reach the kill check itself.
--
--     enters the loop     under the meter zero .... 0/18
--                         with 525 fed back ....... 2/18
--
-- So the archive holds exactly TWO frames that can say anything at all about
-- whether the kill claim is too high, and both of them answer "this target was
-- not killable by either claim".  Before this measurement no frame in the
-- archive could tell "the claim is wrong" apart from "there was nobody to
-- check".  ⇒ **A fixture-archive zero must not be quoted as independent
-- corroboration of the replay group's 0/97.**  It is not a second reading; it
-- is a reading that was never able to disagree.
--
-- ===========================================================================
-- 4.  WHY COUNTING CASTS CANNOT MEASURE THIS LEVER -- CLOSED FORM
-- ===========================================================================
--
-- The kill-confirm branch is firing point 2 of TEN in this function, and all
-- ten return the SAME constant, BOT_ACTION_DESIRE_HIGH.  They differ only in
-- the target they hand back.  So suppressing point 2 on a frame can only lower
-- the cast count if all EIGHT downstream points also decline on that same
-- frame; otherwise the cast still happens, on whatever target the first
-- surviving point picks.
--
-- That is the closed form behind GH #390's own frame: at t=243.4 the armed leg
-- cast anyway (phase-boots chase), which the issue read as "the two legs are
-- indistinguishable on this frame".  They are indistinguishable on ALL frames
-- where any downstream point fires -- by construction, not by luck.  The armed
-- leg casting MORE than baseline (108 vs 97) is consistent with the lever
-- having no effect on cast count at all, because cast count is not an
-- observable of this lever.
--
-- ⇒ THE RE-REGISTERED DOMAIN asked for by GH #390 rec 3:
--       ehp0 in (armed claim, shipped claim]      (the band -- unchanged)
--   AND the target is inside nCastRange + 80      (the gate, NOT the ring)
--   AND no downstream firing point returns the same target on that frame.
-- The third conjunct is new and it is what makes the domain a MARGINAL one.
-- The observable is TARGET IDENTITY, never cast count.
--
-- ===========================================================================
-- 5.  THE TRAP FOR WHOEVER WIRES THE METER: ABSENT IS NOT ZERO
-- ===========================================================================
--
-- 7 of the 21 focus-five priced abilities carry no AbilityCastRange at all
-- (Berserker's Call, Heavenly Jump, Lightning Hands, Thundergod's Wrath, Bone
-- Guard, Reincarnation, Freezing Field) -- every one of them genuinely
-- rangeless.  But the snapshot ALSO holds a literal `0` (zuus_cloud) and a
-- literal `-1` (crystal_maiden_crystal_clone, the engine's unlimited-range
-- convention).  A repair that maps "no key" to 0 makes the absent seven
-- indistinguishable from Nimbus, whose real answer IS 0; and a naive
-- `dist <= range` against -1 is constant false, not constant true.  Whoever
-- takes it has to answer nil for absent and handle -1 explicitly.
--
-- ===========================================================================
-- WHAT THIS FILE DOES NOT CLAIM
-- ===========================================================================
--   (A) It does not repair the meter.  433 call sites is a tree-wide change
--       with its own round and its own census; opened as an issue instead.
--   (B) The 2 reachable frames are n=2 and neither fires, so this file says
--       NOTHING about how often the kill-confirm branch fires in a real game.
--       The unbiased reading of that is still the replay group's 205 casts.
--   (C) 525 is the KV snapshot's number, not an engine reading.  The engine
--       may add facet/talent/item cast range on top; §6 pins the snapshot
--       value, not the engine's.
--   (D) No behaviour changes here.  `wkqdmg` stays gated and unarmed.

package.path = 'tests/?.lua;' .. package.path
local rf     = require('mock.replay_fixture')
local shapes = require('mock.special_value_shapes')

local UNIT = 'npc_dota_hero_skeleton_king'
local Q    = 'skeleton_king_hellfire_blast'
local SRC  = 'hero_skeleton_king.lua'

local FIXTURE_DIR = 'tests/fixtures'
local STAGED_DIR  = 'tests/frames'

-- Source line numbers inside X.ConsiderQ, RESOLVED FROM THE FILE, never typed.
-- Hardcoding them is how a line-coverage reading goes quietly wrong: adding a
-- comment block above the function (this round added 37 lines) shifts every
-- number, and a probe pointed at the wrong lines does not fail -- it reports
-- zeros, which is the same integer as "the branch was not reached".
local function resolve_lines()
    local n, inQ, L = 0, false, {}
    local prev_is_kill_gate = false
    for line in assert(io.open('bots/BotLib/' .. SRC)):lines() do
        n = n + 1
        if line:match('^function X%.ConsiderQ%(%)') then inQ = true
        elseif inQ then
            if L.BAIL == nil and line:match('return BOT_ACTION_DESIRE_NONE') then
                L.BAIL = n
            elseif L.LOOPBODY == nil and line:match('^%s*if J%.IsValid%( npcEnemy %)') then
                L.LOOPBODY = n
            elseif line:match('GetUnitToUnitDistance%( bot, npcEnemy %) <= nCastRange %+ 80') then
                L.DISTGATE = n
            elseif prev_is_kill_gate and line:match('return BOT_ACTION_DESIRE_HIGH') then
                L.KILLFIRE = n
            elseif line:match('^%s*return 0%s*$') then
                L.FALLTHRU = n
                break
            end
            prev_is_kill_gate = line:match('X%.wk_GetBlastKillDamage') ~= nil
                or (prev_is_kill_gate and line:match('^%s*then%s*$') ~= nil)
        end
    end
    for _, k in ipairs({ 'BAIL', 'LOOPBODY', 'DISTGATE', 'KILLFIRE', 'FALLTHRU' }) do
        assert(L[k] ~= nil, 'could not resolve the ' .. k .. ' line of X.ConsiderQ '
            .. 'out of ' .. SRC .. '. Every coverage number in this file would '
            .. 'silently become a zero; fix the anchor rather than the number.')
    end
    assert(L.BAIL < L.LOOPBODY and L.LOOPBODY < L.DISTGATE
        and L.DISTGATE < L.KILLFIRE and L.KILLFIRE < L.FALLTHRU,
        'the resolved lines are out of order -- an anchor matched the wrong site')
    return L
end

local L          = resolve_lines()
local L_BAIL     = L.BAIL      -- return BOT_ACTION_DESIRE_NONE
local L_LOOPBODY = L.LOOPBODY  -- first line inside the kill/interrupt loop
local L_DISTGATE = L.DISTGATE  -- dist <= nCastRange + 80
local L_KILLFIRE = L.KILLFIRE  -- the kill-confirm return -- the wkqdmg firing point
local L_FALLTHRU = L.FALLTHRU  -- the final `return 0`

local KV_CAST_RANGE = 525

-- ---------------------------------------------------------------- enumeration

--- Every corpus file from BOTH directories, never a hardcoded list.
local function corpus_paths()
    local out = {}
    for _, dir in ipairs({ FIXTURE_DIR, STAGED_DIR }) do
        local n = 0
        local p = assert(io.popen('ls ' .. dir .. ' 2>/dev/null'))
        for name in p:lines() do
            if name:match('^f_.*%.lua$') then
                out[#out + 1] = dir .. '/' .. name
                n = n + 1
            end
        end
        p:close()
        assert(n > 0, 'corpus directory ' .. dir .. ' yielded no f_*.lua frame. '
            .. 'An empty enumerator and an empty corpus are the same integer; '
            .. 'this assertion is what tells them apart.')
    end
    table.sort(out)
    return out
end

--- Is Wraith King alive on this frame?
local function wk_alive(path)
    local ok, chunk = pcall(dofile, path)
    if not ok or type(chunk) ~= 'table' then return false end
    for _, u in ipairs(chunk.units or {}) do
        if u.name == UNIT and u.alive ~= false then return true end
    end
    return false
end

--- Drive X.ConsiderQ on one frame and report which source lines it touched.
--- `nRange`, when given, supplies the cast range the mock does not carry.
local function drive(path, armed, nRange)
    local J, bot = rf.load(path, UNIT)
    J.IsSoakCandidate = function(id) return armed and id == 'wkqdmg' end
    J.IsModeTurbo     = function() return true end

    local h = bot:GetAbilityByName(Q)
    local nRaw = h and h:GetCastRange() or nil
    if nRange ~= nil and h ~= nil then
        rawget(h, '__spec').GetCastRange = nRange
    end

    -- SkillsComplement fills this file's upvalues before any Consider runs;
    -- calling a Consider without it is what crashed the Lion sweep 2026-09-01.
    local X = rf.load_hero('skeleton_king')
    pcall(function() X.SkillsComplement() end)

    local seen, last = {}, nil
    debug.sethook(function(_, line)
        local info = debug.getinfo(2, 'S')
        if info and info.short_src and info.short_src:find(SRC, 1, true) then
            seen[line] = true
            last = line
        end
    end, 'l')
    local ok, nDesire, hTarget = pcall(function() return X.ConsiderQ() end)
    debug.sethook()

    assert(ok, 'X.ConsiderQ raised on ' .. path .. ': ' .. tostring(nDesire))
    return { desire = nDesire, target = hTarget, last = last, seen = seen,
             raw_range = nRaw, bot = bot, ability = h }
end

--- The whole sweep, computed once and shared by the sections below.
local sweep_cache = nil
local function sweep()
    if sweep_cache then return sweep_cache end
    local t = {
        files = 0, live = 0, raw_ranges = {},
        untrained = 0, cooldown = 0, mana = 0, savemana = 0, body = 0,
        loop_zero = 0, loop_fed = 0, gate_fed = 0, fire_fed = 0,
        flips = {}, body_paths = {},
    }
    for _, path in ipairs(corpus_paths()) do
        t.files = t.files + 1
        if wk_alive(path) then
            t.live = t.live + 1
            local z = drive(path, false, nil)
            local key = tostring(z.raw_range)
            t.raw_ranges[key] = (t.raw_ranges[key] or 0) + 1

            if z.last == L_BAIL then
                local h    = z.ability
                local rank = h and h:GetLevel() or 0
                local cd   = h and h:GetCooldownTimeRemaining() or 0
                local cost = h and h:GetManaCost() or 0
                local mp   = z.bot:GetMana() or 0
                if rank <= 0 then t.untrained = t.untrained + 1
                elseif cd > 0 then t.cooldown = t.cooldown + 1
                elseif mp < cost then t.mana = t.mana + 1
                else t.savemana = t.savemana + 1 end
            else
                t.body = t.body + 1
                t.body_paths[#t.body_paths + 1] = path
                if z.seen[L_LOOPBODY] then t.loop_zero = t.loop_zero + 1 end

                local f = drive(path, false, KV_CAST_RANGE)
                local a = drive(path, true,  KV_CAST_RANGE)
                if f.seen[L_LOOPBODY] then t.loop_fed = t.loop_fed + 1 end
                if f.seen[L_DISTGATE] then t.gate_fed = t.gate_fed + 1 end
                if f.seen[L_KILLFIRE] then t.fire_fed = t.fire_fed + 1 end
                if z.last ~= f.last or f.last ~= a.last
                    or f.desire ~= a.desire or f.target ~= a.target then
                    t.flips[#t.flips + 1] = path
                end
            end
        end
    end
    sweep_cache = t
    return t
end

--- Count GetCastRange occurrences under bots/, code lines apart from comment
--- lines.  A bare grep -c counts this file's own prose; the 2026-09-01 CM round
--- shipped that error and its own test caught it.
local function census()
    local code, comment, files = 0, 0, {}
-- Farm-only files are skipped: `bots/Customize/` holds two gitignored,
-- TRANSIENT switch files that every gate test in this suite creates and
-- deletes, so listing one and then reading it is a race whose red names a
-- file this test has no business reading (GH #365 §2 / #438; hero backlog
-- -79 measured the population at 18 walks in 18 files).  The rule lives in
-- tests/lua_source_scan.lua and is referenced, never copied -- the path
-- literal is load-bearing text and a second copy is the defect.
    local p = assert(io.popen("find bots -name '*.lua' "
        .. require('lua_source_scan').FARM_ONLY_FIND_CLAUSE .. ' 2>/dev/null'))
    for path in p:lines() do
        local fh = io.open(path)
        if fh then
            for line in fh:lines() do
                if line:find('GetCastRange', 1, true) then
                    if line:match('^%s*%-%-') then comment = comment + 1
                    else
                        code = code + 1
                        files[path] = true
                    end
                end
            end
            fh:close()
        end
    end
    p:close()
    local nfiles = 0
    for _ in pairs(files) do nfiles = nfiles + 1 end
    return code, comment, nfiles
end

local tests = {}

-- ===========================================================================
tests['1. GetCastRange answers 0 on every live-WK instant, and the KV knows 525'] = function()
    -- GUARD FIRST: every number below is a claim about a MISSING wire, and the
    -- world where the KV snapshot lost the key produces the same 0.  Refuse to
    -- report the zero until the answer is demonstrably sitting in the tree.
    local kv = shapes.SHAPES['skeleton_king']
        and shapes.SHAPES['skeleton_king'][Q]
        and shapes.SHAPES['skeleton_king'][Q]['AbilityCastRange']
    assert(kv ~= nil and kv.base ~= nil,
        'the KV snapshot no longer carries AbilityCastRange for ' .. Q .. '. '
        .. 'Without it "the meter answers 0 while the answer is in the tree" is '
        .. 'not the claim this file is making, and the zero below would be an '
        .. 'ordinary missing datum instead of an unwired one.')
    assert(tonumber(kv.base) == KV_CAST_RANGE,
        'AbilityCastRange moved from ' .. KV_CAST_RANGE .. ' to ' .. tostring(kv.base)
        .. ' -- re-anchor this file rather than keeping the old number.')

    local t = sweep()
    assert(t.live > 0, 'no living Wraith King in the corpus at all -- an empty '
        .. 'sweep and a zero reading are the same integer')

    -- RE-ANCHORED 2026-09-04 (hero).  THE REPAIR THIS FILE ASKED FOR LANDED.
    -- The assertion here used to be `t.raw_ranges['0'] == t.live` with the text
    -- "If the mock now specs it, this file has been overtaken by the repair it
    -- asked for -- retire the zero and re-measure §3."  That is what happened:
    -- tests/mock/replay_fixture.lua now serves GetCastRange out of
    -- tests/mock/special_value_shapes.lua (tests/test_fixture_kv_getters.lua),
    -- and the meter answers 525.  The zero is ARCHIVED below rather than
    -- deleted -- every number in §3 and §5 was taken under it.
    --
    -- ARCHIVED READING (2026-08-31, the world this file was written in):
    --     GetCastRange() == 0 on 36 of 36 live-WK instants.
    --
    -- The residue is 3 instants, and it is structural, not a leftover: those
    -- three fixtures are v1 dumps that carry NO `abilities` array at all
    -- (f_073148_zuus_lina, f_080225_wk_lane, f_080225_wk_revive), so
    -- GetAbilityByName hands back a bare handle the loader never specced.  A
    -- re-dump of those three is what closes it; nothing here can.
    local ARCHIVED_ZERO_ON_ALL = 36
    local NO_ABILITY_ARRAY     = 3
    local nFed  = t.raw_ranges[tostring(KV_CAST_RANGE)] or 0
    local nZero = t.raw_ranges['0'] or 0
    assert(nFed + nZero == t.live,
        'the meter now answers something other than ' .. KV_CAST_RANGE .. ' or 0 on '
        .. tostring(t.live - nFed - nZero) .. ' instants -- report the distribution '
        .. 'before quoting any number below')
    assert(nZero == NO_ABILITY_ARRAY,
        'instants still reading 0 moved from ' .. NO_ABILITY_ARRAY .. ' to ' .. nZero
        .. '. Fewer means those v1 fixtures were re-dumped (good -- record it); '
        .. 'more means the loader stopped serving the KV, and §5 is back in the '
        .. 'world this file was written in.')
    assert(nFed == t.live - NO_ABILITY_ARRAY,
        'instants reading the KV ' .. KV_CAST_RANGE .. ': ' .. nFed)
    assert(t.live == ARCHIVED_ZERO_ON_ALL, 'live-WK instant count moved from '
        .. ARCHIVED_ZERO_ON_ALL .. ' to ' .. t.live
        .. ' -- re-read the sections below before quoting their numbers')
end

-- ===========================================================================
tests['2. the census: 433 code call sites over 150 files, prose counted apart'] = function()
    local code, comment, nfiles = census()
    assert(comment > 0, 'the code/comment split found no comment line mentioning '
        .. 'GetCastRange anywhere under bots/, which means the split is not '
        .. 'actually splitting -- the exact shape the CM round shipped on '
        .. '2026-09-01 with a bare grep -c')
    assert(code == 433, 'GetCastRange code call sites moved from 433 to ' .. code)
    assert(nfiles == 150, 'files carrying a GetCastRange call moved from 150 to ' .. nfiles)
    -- The scale claim this file leans on, held against GH #386's census.
    assert(code > 7 * 50, 'the "62x the GetAOERadius census" sentence in the '
        .. 'header no longer holds at this call-site count')
end

-- ===========================================================================
tests['3. the ring arithmetic the zero produces -- closed form'] = function()
    -- Derived from the source, never re-typed: pull the three ring offsets out
    -- of hero_skeleton_king.lua so an edit to them fails here.
    local src = assert(io.open('bots/BotLib/' .. SRC)):read('*a')
    assert(src:find('nCastRange + 330', 1, true), 'the search ring offset (+330) is gone')
    assert(src:find('nCastRange + 43', 1, true),  'the tight ring offset (+43) is gone')
    assert(src:find('nCastRange + 80', 1, true),  'the kill-confirm gate offset (+80) is gone')
    assert(src:find('nCastRange + 350', 1, true), 'the ranged-solo widening (+350) is gone')

    local true_rings = { 330 + KV_CAST_RANGE, 43 + KV_CAST_RANGE,
                         80 + KV_CAST_RANGE, 350 + KV_CAST_RANGE }
    local zero_rings = { 330, 43, 80, 350 }
    assert(true_rings[1] == 855 and true_rings[2] == 568
        and true_rings[3] == 605 and true_rings[4] == 875,
        'the header\'s ring table is stale')
    assert(zero_rings[2] < 100, 'the "smaller than a collision box" sentence needs '
        .. 'the tight ring to actually be tiny')
end

-- ===========================================================================
tests['4. the castable funnel over the archive, buckets exhaustive'] = function()
    local t = sweep()
    local accounted = t.untrained + t.cooldown + t.mana + t.savemana + t.body
    assert(accounted == t.live, 'the buckets do not re-sum: ' .. accounted
        .. ' accounted for out of ' .. t.live .. ' live instants')
    assert(t.untrained == 5, 'untrained bucket moved from 5 to ' .. t.untrained)
    assert(t.cooldown  == 9, 'cooldown bucket moved from 9 to '  .. t.cooldown)
    assert(t.savemana  == 4, 'ShouldSaveMana bucket moved from 4 to ' .. t.savemana)
    assert(t.mana      == 0, 'mana bucket moved from 0 to ' .. t.mana)
    assert(t.body      == 18, 'body bucket moved from 18 to ' .. t.body)
end

-- ===========================================================================
-- RE-ANCHORED 2026-09-04 (hero), same repair as §1.  `loop_zero` is no longer a
-- SEPARATE world: the loader serves the cast range, so the "meter zero" drive
-- and the "fed back" drive now see the same 525 on every body frame that has an
-- ability array, and the two readings have CONVERGED rather than one of them
-- regressing.  The old assertion `loop_fed > loop_zero` was the file's guard
-- against "feeding the range changed nothing"; it cannot be evaluated any more,
-- because there is nothing left to feed.  What replaces it is the archived pair
-- plus the convergence, so a loader that stopped serving the KV shows up here as
-- loop_zero falling back to 0.
--
-- ARCHIVED READING (2026-08-31, under the meter zero):
--     loop entered on 0 of 18 body frames; with 525 fed back, 2.
--     That difference is the whole "the corpus zero was vacuous" claim, and it
--     is what §3's "understates reach" rests on. It is history now, not a
--     live measurement -- do not re-derive it from a green run of this file.
local ARCHIVED_LOOP_UNDER_ZERO = 0

tests['5. the corpus zero was vacuous on 16 of 18 frames (archived; the worlds have converged)'] = function()
    local t = sweep()
    assert(t.loop_fed == 2, 'with ' .. KV_CAST_RANGE .. ' fed back the loop is '
        .. 'entered on ' .. t.loop_fed .. ' body frames; the header says 2')
    assert(t.gate_fed == 2, 'the distance gate was evaluated on ' .. t.gate_fed
        .. ' frames; the header says 2')
    -- The honest half: reaching the check is not firing it.
    assert(t.fire_fed == 0, 'the kill-confirm branch FIRED on ' .. t.fire_fed
        .. ' frames with the range fed back. The header says 0 and rests on it; '
        .. 'a firing frame is a real finding and must be written up, not asserted away.')
    assert(t.loop_zero == t.loop_fed,
        'the unfed drive entered the loop on ' .. t.loop_zero .. ' body frames '
        .. 'against ' .. t.loop_fed .. ' fed -- they must agree now that the '
        .. 'loader serves GetCastRange. A drop back toward '
        .. ARCHIVED_LOOP_UNDER_ZERO .. ' means the meter went blind again.')
    assert(ARCHIVED_LOOP_UNDER_ZERO < t.loop_fed,
        'the archived pair no longer shows the vacuity this file was written '
        .. 'about; §3 needs re-deriving, not this line relaxing')
end

-- ===========================================================================
tests['6. no decision flips: the archive cannot separate the two legs'] = function()
    local t = sweep()
    assert(#t.flips == 0, 'a frame separated {meter zero, fed shipped, fed armed}: '
        .. table.concat(t.flips, ', ') .. '. That is the frame GH #390 asked for -- '
        .. 'write it up rather than letting this assertion carry it.')
    assert(t.body == #t.body_paths and t.body > 0,
        'the flip check ran over an empty set, which is not the same reading as '
        .. '"no flip"')
end

-- ===========================================================================
tests['7. ten firing points, one desire constant -- read off the source'] = function()
    local src  = assert(io.open('bots/BotLib/' .. SRC)):read('*a')
    local body = src:match('function X%.ConsiderQ%(%)(.-)\nend\n')
    assert(body ~= nil and #body > 0, 'X.ConsiderQ no longer parses out of the file')

    local high, other = 0, {}
    for line in body:gmatch('[^\n]+') do
        if not line:match('^%s*%-%-') then
            local ret = line:match('^%s*return%s+(.+)$')
            if ret then
                if ret:match('^BOT_ACTION_DESIRE_HIGH') then high = high + 1
                else other[#other + 1] = ret end
            end
        end
    end
    assert(high == 10, 'ConsiderQ now has ' .. high .. ' HIGH firing points, not 10 '
        .. '-- §4\'s "eight downstream" arithmetic is stated in terms of this count')
    assert(#other == 2, 'expected exactly two non-HIGH returns (the castable bail '
        .. 'and the final 0); found ' .. #other)
    -- The load-bearing half: every firing point bids the SAME constant, so the
    -- lever cannot move desire, only target.
    assert(other[1]:match('BOT_ACTION_DESIRE_NONE') and other[2]:match('^0'),
        'the two non-HIGH returns are no longer {NONE, 0}: ' .. table.concat(other, ' | '))

    -- And the wkqdmg firing point is the SECOND of the ten, which is what makes
    -- the eight downstream points able to absorb its suppression.
    local before = src:sub(1, src:find('X.wk_GetBlastKillDamage( abilityQ )', 1, true))
    local q_body = before:match('function X%.ConsiderQ%(%)(.*)$')
    local n_before = 0
    for line in q_body:gmatch('[^\n]+') do
        if not line:match('^%s*%-%-') and line:match('^%s*return%s+BOT_ACTION_DESIRE_HIGH') then
            n_before = n_before + 1
        end
    end
    assert(n_before == 1, 'the wkqdmg firing point is no longer the 2nd of the ten '
        .. '(' .. n_before .. ' HIGH returns precede it); §4 is stated for the 2nd')
end

-- ===========================================================================
tests['8. absent is not zero: the trap for whoever wires the meter'] = function()
    local priced, ranged, absent, zero, negative = 0, 0, {}, {}, {}
    for _, abilities in pairs(shapes.SHAPES) do
        for name, keys in pairs(abilities) do
            if keys['AbilityManaCost'] then
                priced = priced + 1
                local cr = keys['AbilityCastRange']
                if cr == nil or cr.base == nil then
                    absent[#absent + 1] = name
                else
                    ranged = ranged + 1
                    local first = tonumber((tostring(cr.base):match('^(%-?%d+)')))
                    if first == 0 then zero[#zero + 1] = name
                    elseif first and first < 0 then negative[#negative + 1] = name end
                end
            end
        end
    end
    assert(priced == 21, 'the priced focus-five ability count moved from 21 to ' .. priced)
    assert(ranged == 14, 'abilities carrying AbilityCastRange moved from 14 to ' .. ranged)
    assert(#absent == 7, 'abilities with no AbilityCastRange moved from 7 to ' .. #absent)
    -- These two are the trap itself: a repair that maps absent -> 0 erases the
    -- difference between the seven rangeless abilities and Nimbus.
    assert(#zero == 1, 'expected exactly one ability whose real cast range IS 0 '
        .. '(zuus_cloud); found ' .. #zero)
    assert(#negative == 1, 'expected exactly one -1 (the engine\'s unlimited-range '
        .. 'convention, crystal_maiden_crystal_clone); found ' .. #negative)
end

return tests

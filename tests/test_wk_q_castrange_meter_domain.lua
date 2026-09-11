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
-- ⚠️ [hero 2026-09-11] AND FOR TEN DAYS THIS FILE COULD NOT MEASURE THAT
-- OBSERVABLE.  Section 6 compared the two legs' targets across two separate
-- `rf.load` calls, so the comparison answered "is there a target" rather than
-- "is it the same target" -- see the note above section 6.  A file may declare
-- an observable in its header and still have no instrument for it; the header
-- sentence above is what made the gap findable, so it stays exactly as written.
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

--- Drive X.ConsiderQ SEVERAL TIMES ON ONE LOADED WORLD, once per leg, and hand
--- back the readings side by side.
---
--- [hero 2026-09-11, GH #390] THIS EXISTS BECAUSE `drive()` CANNOT COMPARE
--- TARGETS, AND SECTION 4 OF THE HEADER SAYS TARGET IDENTITY IS THE OBSERVABLE.
--- Every `drive()` call does its own `rf.load`, which builds its own unit
--- handles; two loads of the SAME frame on the SAME leg therefore hand back
--- two different tables for the same hero.  `f.target ~= a.target` was thus
--- TRUE on every frame where ConsiderQ returns any target at all, and FALSE
--- only where both legs returned nil -- it measured "is there a target", never
--- "did the legs pick different ones".  The direction is the dangerous one: it
--- reads positive for a lever that does nothing, so section 6 stood red
--- claiming it had found the frame GH #390 asked for, and named three.  The
--- control below is the whole repair: on one load, the same leg driven twice
--- returns the SAME table, so an inequality is now a decision.
local function drive_legs(path)
    local J, bot = rf.load(path, UNIT)
    J.IsModeTurbo = function() return true end

    local h = bot:GetAbilityByName(Q)
    local nRaw = h and h:GetCastRange() or nil

    local X = rf.load_hero('skeleton_king')
    pcall(function() X.SkillsComplement() end)

    local function run(armed)
        J.IsSoakCandidate = function(id) return armed and id == 'wkqdmg' end
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
        return { desire = nDesire, target = hTarget, last = last, seen = seen }
    end

    -- The meter's own answer first, then the same world with the KV fed back.
    --
    -- ⚠️ THE FEED IS VESTIGIAL AND IS KEPT ON PURPOSE.  This round's mutation
    -- stand deleted the assignment below and the file stayed GREEN -- because
    -- the loader already serves GetCastRange out of the KV snapshot, so on all
    -- 48 instants carrying an `abilities` array it writes 525 over 525, and the
    -- other 3 have no handle to write to.  That is not an unpinned assertion:
    -- section 1 asserts exactly that split (`nFed == t.live - 3`), so the
    -- no-op-ness is measured there rather than here.  Kept because it is what
    -- makes `zero` and `ship` two NAMED worlds; if the loader ever stops
    -- serving the KV, section 1 goes red first and this line starts mattering
    -- again.
    local zero = run(false)
    if h ~= nil then rawget(h, '__spec').GetCastRange = KV_CAST_RANGE end
    local ship  = run(false)
    local armed = run(true)
    -- The control: a second shipped run must be byte-identical to the first.
    -- If this ever fails, `ship` vs `armed` is measuring the harness again.
    local ctrl  = run(false)

    return { zero = zero, ship = ship, armed = armed, ctrl = ctrl,
             raw_range = nRaw }
end

--- The whole sweep, computed once and shared by the sections below.
local sweep_cache = nil
local function sweep()
    if sweep_cache then return sweep_cache end
    local t = {
        files = 0, live = 0, raw_ranges = {},
        untrained = 0, cooldown = 0, mana = 0, savemana = 0, body = 0,
        loop_zero = 0, loop_fed = 0, gate_fed = 0, fire_fed = 0,
        flips = {}, body_paths = {}, ctrl_breaks = {},
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

                -- Both legs off ONE load, so `target` is comparable at all.
                local w = drive_legs(path)
                local f, a = w.ship, w.armed
                if f.seen[L_LOOPBODY] then t.loop_fed = t.loop_fed + 1 end
                if f.seen[L_DISTGATE] then t.gate_fed = t.gate_fed + 1 end
                if f.seen[L_KILLFIRE] then t.fire_fed = t.fire_fed + 1 end

                -- The control before the reading (see `drive_legs`): a repeat
                -- of the SHIPPED leg on this same world must be identical.  A
                -- break here means the flip line below is measuring the
                -- harness, and no flip it reports can be believed.
                if f.last ~= w.ctrl.last or f.desire ~= w.ctrl.desire
                    or f.target ~= w.ctrl.target then
                    t.ctrl_breaks[#t.ctrl_breaks + 1] = path
                end

                if w.zero.last ~= f.last or f.last ~= a.last
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
    -- 2026-09-06 (hero, GH #566): 36 -> 37 live-WK instants.  This file's sweep
    -- enumerates tests/frames/ as well as the corpus (the staging contract: a
    -- staged frame is invisible to the CORPUS globs, not to a scan that reads
    -- the tree), so it sees f_260905_004847_lion_drain_bkb.lua -- a live
    -- skeleton_king at level 26 with Q trained and off cooldown.  It lands in
    -- the BODY bucket (section 4, 18 -> 19).  The KV/zero split is unchanged, so
    -- section 1's finding holds as measured; the per-bucket numbers moved by
    -- exactly that one instant and were NOT otherwise re-derived.
    -- 2026-09-09 (hero, GH #659): 37 -> 38.  Same mechanism, different bucket.
    -- f_260908_094909_cm_cmqreach_transit.lua carries a live level-20
    -- skeleton_king whose `skeleton_king_hellfire_blast` is TRAINED (rank 3) but
    -- reads `cd = 1.4` on the frame, so it lands in the COOLDOWN bucket
    -- (section 4, 9 -> 10) and not in the body.  Worth naming because it is the
    -- direction that does NOT help §5: a cooldown instant never reaches the ring
    -- arithmetic, so the "0 of 18 body frames" archived reading gains no sample
    -- from this frame.  The KV/zero split is again unchanged (the frame is a
    -- current dump and carries a full `abilities` array, so it reads 525).
    -- 2026-09-11 (hero, GH #390): 38 -> 51.  Thirteen instants, all from the
    -- two frame batches staged under tests/frames/ since the last anchor, and
    -- the split across buckets is the load-bearing half (section 4 moved with
    -- it, section 5 did not move the way the count suggests):
    --     +4 COOLDOWN  f_260909_215227_zeus_{bolt_wk_434,exec_wk_615,
    --                  ult_1008,ult_396} -- Q trained, cd > 0 on the frame
    --     +1 SAVEMANA  f_260909_215227_zeus_jump_283
    --     +8 BODY      f_260909_215040_wk_blast_* (six) plus
    --                  f_260909_215227_zeus_{arc_od_79,exec_od_1467}
    -- The six wk_blast frames are the first in this archive dumped AT a
    -- Wraithfire Blast instant, which is why they are also the frames that
    -- moved section 5's loop count.  The KV/zero split is unchanged: all
    -- thirteen are current dumps carrying a full `abilities` array.
    local ARCHIVED_ZERO_ON_ALL = 51
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
    -- 9 -> 10 on 2026-09-09 (hero, GH #659): the staged transit frame's level-20
    -- Wraith King has Q trained at rank 3 with cd 1.4 remaining.  Re-taken, not
    -- bumped: the body bucket did NOT move with it (19), which is the whole
    -- reason this bucket is read separately -- see section 1's note.
    -- 10 -> 14 on 2026-09-11 (hero, GH #390): the four f_260909_215227_zeus_*
    -- frames whose Wraith King is trained but on cooldown.  Same mechanism as
    -- the #659 note above, four instants at once; section 1 carries the split.
    assert(t.cooldown  == 14, 'cooldown bucket moved from 14 to ' .. t.cooldown)
    assert(t.savemana  == 5, 'ShouldSaveMana bucket moved from 5 to ' .. t.savemana)
    assert(t.mana      == 0, 'mana bucket moved from 0 to ' .. t.mana)
    assert(t.body      == 27, 'body bucket moved from 27 to ' .. t.body)
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
    -- 2 -> 9 on 2026-09-11 (hero, GH #390).  Seven of the eight body frames
    -- added this round enter the loop: the six f_260909_215040_wk_blast_*
    -- frames plus f_260909_215227_zeus_arc_od_79.  That is not a coincidence of
    -- corpus growth -- the wk_blast batch was dumped AT blast instants, so an
    -- enemy inside the 855 search ring is the precondition the batch selects
    -- for.  What it does NOT move is `fire_fed`, still 0; see section 6.
    assert(t.loop_fed == 9, 'with ' .. KV_CAST_RANGE .. ' fed back the loop is '
        .. 'entered on ' .. t.loop_fed .. ' body frames; the header says 9')
    assert(t.gate_fed == 9, 'the distance gate was evaluated on ' .. t.gate_fed
        .. ' frames; the header says 9')
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
-- [hero 2026-09-11, GH #390] WHAT THIS SECTION CLAIMED BEFORE, AND WHY IT WAS
-- NOT A FINDING.  From 2026-09-09 to 2026-09-11 this assertion stood RED naming
-- three frames -- f_260909_215040_wk_blast_{lion_480,sb_1052,sb_661} -- and its
-- own text said they were "the frame GH #390 asked for".  They were not.  Each
-- leg was driven through its own `rf.load`, so `f.target ~= a.target` compared
-- two tables built by two different loads and was true whenever a target
-- existed at all.  The three named frames are exactly the three body frames on
-- which ConsiderQ returns a non-nil target (all three at desire 0.75 from the
-- teamfight branch at a line the `wkqdmg` lever cannot reach); the other 24 body
-- frames "agreed" only because nil == nil.
--
-- The lesson is not "compare by name instead".  It is that a detector whose
-- positive reading is produced by the harness cannot be believed in EITHER
-- direction -- had the lever really moved a target, this line would have
-- reported the same red for the wrong reason, and the write-up would have been
-- wrong in the expensive direction.  The control assertion below is therefore
-- the load-bearing one, and it runs FIRST.
tests['6. no decision flips: the archive cannot separate the two legs'] = function()
    local t = sweep()
    -- CONTROL FIRST.  The shipped leg driven twice on one world must land on
    -- the same line, desire and target table.  If this is red, nothing about
    -- the flip count below means anything.
    assert(#t.ctrl_breaks == 0, 'the SHIPPED leg driven twice on the same loaded '
        .. 'world disagreed with itself on: ' .. table.concat(t.ctrl_breaks, ', ')
        .. '. Until that is explained, the flip reading is measuring the harness, '
        .. 'which is the defect this control was added for.')
    assert(#t.flips == 0, 'a frame separated {meter zero, fed shipped, fed armed}: '
        .. table.concat(t.flips, ', ') .. '. The control above passed, so this is '
        .. 'a decision and not a load -- that is the frame GH #390 asked for, and '
        .. 'it must be written up rather than left in this message.')
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
-- 9.  GH #390 RECOMMENDATION 2, ASKED OFF THE ARCHIVE: WHERE DOES THE BRANCH
--     ACTUALLY STOP?
-- ===========================================================================
--
-- The issue's recommendation 2 was "stop waiting for a band_pair and ask a
-- branch-REACH question instead -- a low count is not evidence that the domain
-- is small".  Sections 5 and 6 answer the coarse half (the loop is entered on
-- 9 body frames, the branch fires on 0), but "reached the line" is not
-- "passed the range test": the gate is
--
--     GetUnitToUnitDistance(...) <= nCastRange + 80
--         and J.CanKillTarget( npcEnemy, X.wk_GetBlastKillDamage( abilityQ ), ... )
--
-- and Lua short-circuits, so wk_GetBlastKillDamage is called ONLY on the pairs
-- that already passed the range test.  Counting its calls therefore splits the
-- two ways the branch can decline, which is the split the issue asked for.
--
-- READING (2026-09-11, both legs, per (frame, enemy) pair):
--     reached the range test .......... 9 body frames
--     PASSED it, claim computed ....... 12 pairs
--     claim cleared, branch fires ..... 0 pairs, on EITHER leg
--
-- So the branch is not starved of range -- it is starved of CLAIM.  Twelve
-- times the enemy was inside 605 units and the kill claim still lost, which is
-- the opposite of what "the ring has been 330 wide" (section 3) would predict
-- and is why that section's "understates reach" wording is about the ring, not
-- about this gate.
--
-- AND THE MARGIN IS NOT WIDE.  The tightest pair in the archive is Spirit
-- Breaker at 172 raw hp on f_260909_215040_wk_blast_sb_661 against a SHIPPED
-- claim of 168.0 -- a miss by 4 raw hp, before magic resistance is applied.
-- ⚠️ That number is NOT comparable to the issue's "nearest baseline cast missed
-- the band by 63.6 ehp": the issue measured casts that really happened in 12
-- games, this measures every (frame, enemy) pair the branch evaluates in a
-- 51-instant archive, and it is raw hp rather than ehp.  Two different
-- populations; what they agree on is the only thing quoted as a conclusion --
-- the separation is 0, on every pair either of them has seen.
local function reach_census()
    local n_pairs, n_fire, tightest, tight_at = 0, 0, nil, nil
    for _, path in ipairs(corpus_paths()) do
        if wk_alive(path) then
            for _, armed in ipairs({ false, true }) do
                local J, bot = rf.load(path, UNIT)
                J.IsSoakCandidate = function(id) return armed and id == 'wkqdmg' end
                J.IsModeTurbo     = function() return true end
                local h = bot:GetAbilityByName(Q)
                if h ~= nil then rawget(h, '__spec').GetCastRange = KV_CAST_RANGE end

                local X = rf.load_hero('skeleton_king')
                pcall(function() X.SkillsComplement() end)

                local real_kill = J.CanKillTarget
                J.CanKillTarget = function(hTarget, nDamage, nType)
                    local bKill = real_kill(hTarget, nDamage, nType)
                    if not armed then n_pairs = n_pairs + 1 end
                    if bKill then n_fire = n_fire + 1 end
                    local nHp = 0
                    pcall(function() nHp = hTarget:GetHealth() end)
                    -- Margin on the SHIPPED leg only: it is the wider claim, so
                    -- it is the leg that gets closest to firing.
                    if not armed and nDamage ~= nil and nHp > 0 then
                        local nMiss = nHp - nDamage
                        if tightest == nil or nMiss < tightest then
                            tightest, tight_at = nMiss, path
                        end
                    end
                    return bKill
                end

                pcall(function() X.ConsiderQ() end)
            end
        end
    end
    return n_pairs, n_fire, tightest, tight_at
end

tests['9. the branch reaches and loses on the CLAIM, not on the range (GH #390 rec 2)'] = function()
    local n_pairs, n_fire, tightest, tight_at = reach_census()

    -- THE FIRING CHECK RUNS FIRST, AND THE ORDER IS NOT COSMETIC.  Found by the
    -- mutation stand for this round (M2: widen the shipped claim 1.68 -> 16.8).
    -- The branch RETURNS on the pair that clears, so a firing world evaluates
    -- FEWER pairs, not more -- the count fell 12 -> 7.  With the reach bound
    -- first, the one event this file exists to catch reported itself as "the
    -- branch stopped being reached", which is the opposite diagnosis and would
    -- have sent the next reader to section 5.  Same shape as section 6's
    -- control-before-reading: whichever assertion can MISNAME the finding has
    -- to speak after the one that names it correctly.
    --
    -- A firing pair is the (a) evidence GH #390 has been waiting for since
    -- 2026-09-01 -- it must leave this file as a write-up, never as a relaxed
    -- assertion.
    assert(n_fire == 0, 'the kill-confirm claim CLEARED on ' .. n_fire
        .. ' (frame, enemy) pairs. That is a separating frame for wkqdmg and the '
        .. 'thing GH #390 asked for: write it up, do not adjust this line.')

    -- Direction-safe: the reading is "the branch is reached", so a corpus that
    -- grows may only add pairs.  A drop to 0 is the vacuous world in which
    -- every number in this section is the same integer as "never measured".
    assert(n_pairs >= 12, 'the kill claim was computed on ' .. n_pairs
        .. ' (frame, enemy) pairs on the shipped leg; it was 12 on 2026-09-11 and '
        .. 'this section reads as a REACH claim, so fewer means the branch stopped '
        .. 'being reached and section 5 must be re-derived, not this bound lowered')

    -- The margin, pinned loosely and in the safe direction: it is quoted in the
    -- header and on the issue, so a corpus that brings it much closer is news.
    assert(tightest ~= nil, 'no margin was recorded, which means CanKillTarget was '
        .. 'never reached -- see the pair count above')
    assert(tightest <= 4, 'the tightest shipped-leg miss widened from 4 raw hp to '
        .. tightest .. ' (' .. tostring(tight_at) .. '); the header quotes 4')
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

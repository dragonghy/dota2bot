-- [ratchet] `towerCreepMode` is `roamstale`'s unreset sibling, and its consumer
-- SHADOWS the branch that won the auction.
--
-- THE FAMILY. `roamstale` is PROMOTED (stable-v1, live in every Turbo game). It
-- exists because mode_team_roam_generic writes a unit handle in GetDesireHelper
-- and consumes it in Think, and Think is called only for the mode that WINS the
-- auction -- so a handle written on frame N is still in force on frame N+1 even
-- when nothing on frame N+1 justifies it. Its fix is one line at the top of
-- GetDesireHelper: `if J.IsModeTurbo() then hTargetCreep = nil end`.
--
-- THE SIBLING. The same file keeps a SECOND pair of exactly that shape --
-- `towerCreepMode` / `towerCreep` -- which that line does not touch, and which
-- is worse in one specific way. `hTargetCreep`'s consumer is the FIRST branch of
-- Think; `towerCreepMode`'s consumer sits ABOVE the two sites that serve every
-- early-return branch of GetDesireHelper (ConsiderHelpWhenCoreIsTargeted 0.98,
-- ConsiderHelpAlly 0.98, punish-dive 0.98, punish-over-chase 0.98, lane-kill
-- 0.92, l5-combo 0.92, CarryFindTarget, SupportFindTarget) and it `return`s. So
-- a stale flag there does not mis-aim the collapse -- it CANCELS it: the bid
-- says "help the core being focused", and the frame executes "keep hitting the
-- tower creep".
--
-- WHY THE RESET CANNOT COVER THOSE FRAMES, in one sentence: the only reset
-- inside GetDesireHelper lives BELOW 16 `return` statements, so every frame that
-- takes one of them leaves the flag exactly as the previous frame left it, while
-- OnEnd() -- the other reset -- fires only when the mode STOPS winning, which is
-- the one case where Think is not called anyway.
--
-- WHAT THIS FILE IS NOT. It does not claim the defect fires in play. The
-- companion tests/test_towercreep_stale_domain.lua measures the corpus and the
-- answer there is that the SETTER is unreachable on all 993 live-hero frames --
-- for three unwired engine values, not for a game reason. That is why no gate
-- ships with this reading: a `towerstale` candidate could not be driven on a
-- real frame today, and gate-plumbing is not local validation (charter step 4).
--
-- NOT TAGGED INTO THE FAST LEG BY ACCIDENT: this half is the cheap half. The
-- 51s corpus half is deliberately in the OTHER file, untagged, because GH #358
-- has the selfcheck's Lua leg at 133.3s already and this reading is not worth
-- +38% on every stream's every trigger.

package.path = 'tests/?.lua;' .. package.path

local SRC = 'bots/mode_team_roam_generic.lua'

local tests = {}

--- Every line of the shipped mode file, 1-indexed. Read from the tree, never
--- copied into this file: charter 0SRC ("constants come from the source").
local function lines()
    local f = assert(io.open(SRC, 'r'), 'cannot open ' .. SRC)
    local out = {}
    for l in f:lines() do out[#out + 1] = l end
    f:close()
    return out
end

--- 1-indexed line numbers whose text contains `needle` (plain find).
local function hits(L, needle)
    local out = {}
    for i, l in ipairs(L) do
        if l:find(needle, 1, true) then out[#out + 1] = i end
    end
    return out
end

--- The line number of the single line matching a Lua pattern, or nil.
local function only(L, pat)
    local found
    for i, l in ipairs(L) do
        if l:match(pat) then
            if found then return nil, 'more than one line matches ' .. pat end
            found = i
        end
    end
    return found
end

tests['[source] towerCreepMode has exactly five occurrences, in five distinct roles'] = function()
    local L = lines()
    local occ = hits(L, 'towerCreepMode')
    assert(#occ == 5,
        'expected 5 lines mentioning towerCreepMode, got ' .. #occ ..
        ' -- the shape this file reasons about moved; re-read before editing')

    local decl  = only(L, 'local%s+towerCreepMode,%s*towerCreep%s*=')
    local clr1  = only(L, 'towerTime,%s*towerCreepMode%s*=%s*0,%s*false')
    local set   = only(L, '^%s*towerCreepMode%s*=%s*true%s*$')
    local clr2  = only(L, '^%s*towerCreepMode%s*=%s*false%s*$')
    local read  = only(L, '^%s*if%s+towerCreepMode%s+then%s*$')
    assert(decl and clr1 and set and clr2 and read,
        'one of the five roles (decl/clear-in-desire/set/clear-in-OnEnd/read) is gone')

    local seen = { [decl] = true, [clr1] = true, [set] = true, [clr2] = true, [read] = true }
    for _, i in ipairs(occ) do
        assert(seen[i], 'line ' .. i .. ' mentions towerCreepMode in an UNCLASSIFIED role')
    end
end

tests['[source] the only reset inside GetDesireHelper sits below 16 returns'] = function()
    local L = lines()
    local helper = only(L, '^function GetDesireHelper%(%)%s*$')
    local onend  = only(L, '^function OnEnd%(%)%s*$')
    local clr1   = only(L, 'towerTime,%s*towerCreepMode%s*=%s*0,%s*false')
    assert(helper and onend and clr1, 'GetDesireHelper / OnEnd / the reset moved')
    assert(helper < clr1 and clr1 < onend, 'the reset is not inside GetDesireHelper any more')

    local n = 0
    for i = helper, clr1 - 1 do
        if L[i]:match('^%s*return%s') or L[i]:match('^%s*return$') then n = n + 1 end
    end
    -- The count is the whole claim: each of these is a frame on which the reset
    -- is not executed and the flag keeps last frame's value. Pinned so that a
    -- future branch added above it cannot quietly widen the exposure.
    assert(n == 16,
        'expected 16 return statements above the reset, got ' .. n ..
        ' -- the number of frames that skip the reset changed')

    -- [limit, and it is asserted rather than written down] the counter above
    -- only sees a `return` that OPENS its line, so an inline `if X then return Y
    -- end` would be invisible to it. That blind spot is EMPTY on this tree and
    -- this is what proves it: exactly one further line in the range carries a
    -- `return` SUBSTRING -- 'return', 'returning', '`return`s' -- and all three
    -- are comments (the roamstale note's own prose). The substring is used on
    -- purpose: it is stricter than a word match, so no inline return can hide. A
    -- mutation that added an inline return survived this file before this
    -- assertion existed -- recorded so the survivor is not relearned.
    local extra = 0
    for i = helper, clr1 - 1 do
        local l = L[i]
        if l:find('return') and not (l:match('^%s*return%s') or l:match('^%s*return$')) then
            extra = extra + 1
            assert(l:match('^%s*%-%-'),
                'line ' .. i .. ' carries a return the 16-count cannot see: ' .. l)
        end
    end
    assert(extra == 3, 'expected exactly three commented `return`s in the range, got ' .. extra)
end

tests['[source] the SAME contract is written above the sibling and applied once'] = function()
    -- The finding in one assertion: the roamstale note at the top of
    -- GetDesireHelper spells out this exact mechanism -- a handle written low,
    -- never reset, read FIRST by Think and returned on, so the collapse the
    -- desire was computed from is never touched -- and names the branches it
    -- happens on. It then fixes ONE of the two handles the reasoning covers.
    local L = lines()
    local helper = only(L, '^function GetDesireHelper%(%)%s*$')
    local reset  = only(L, '^%s*hTargetCreep%s*=%s*nil%s*$')
    assert(helper and reset, 'the roamstale note or its reset moved')

    local note = table.concat(L, '\n', helper, reset)
    for _, phrase in ipairs({ 'ConsiderHelpWhenCoreIsTargeted', 'ConsiderHelpAlly',
                              'punish-dive', 'punish-over-chase', 'l1trade', 'l5combo',
                              'never reset' }) do
        assert(note:find(phrase, 1, true),
            'the roamstale note no longer states "' .. phrase .. '"; the'
            .. ' "same contract, applied once" claim rests on it')
    end
    assert(not note:find('towerCreepMode', 1, true),
        'the note now covers towerCreepMode too -- re-read this whole file')

    -- And the asymmetry that makes "just copy the promoted line" WRONG: the
    -- still-holding branch returns without re-affirming the flag, so clearing it
    -- at the top of the helper -- roamstale's own placement -- would turn a
    -- LIVE tower-creep attack off, which roamstale's safety argument ("it can
    -- only ever REMOVE a stale attack, never add one") does not cover.
    local hold = only(L, 'if%s+towerTime%s*~=%s*0%s+and')
    local set  = only(L, '^%s*towerCreepMode%s*=%s*true%s*$')
    assert(hold and set and hold < set,
        'the still-holding branch moved below the setter')
    for i = hold, set - 1 do
        assert(not L[i]:match('^%s*towerCreepMode%s*=%s*true'),
            'the still-holding branch now re-affirms the flag; the copy-roamstale'
            .. ' fix became safe and this assertion is stale')
    end
end

tests['[source] OnEnd is the other reset, and it only fires when Think will not'] = function()
    local L = lines()
    local onend = only(L, '^function OnEnd%(%)%s*$')
    local clr2  = only(L, '^%s*towerCreepMode%s*=%s*false%s*$')
    local think = only(L, '^function Think%(%)%s*$')
    assert(onend and clr2 and think, 'OnEnd / its reset / Think moved')
    assert(onend < clr2 and clr2 < think, 'the second reset left OnEnd')
end

tests['[source] the consumer SHADOWS both roamreach sites and returns'] = function()
    local L = lines()
    local read = only(L, '^%s*if%s+towerCreepMode%s+then%s*$')
    local chase = hits(L, '_roamreach_BoundedChase(targetUnit)')
    assert(read, 'the consumer moved')
    assert(#chase == 2, 'expected the two roamreach delivery sites, got ' .. #chase)
    for _, i in ipairs(chase) do
        assert(read < i,
            'the towerCreepMode consumer is no longer ABOVE the delivery site at line ' .. i)
    end

    -- The block is two statements: the continuous order and a bare return. The
    -- `return` is what turns "wrong target" into "the winning branch never runs".
    assert(L[read + 1]:find('Action_AttackUnit(towerCreep, false)', 1, true),
        'line ' .. (read + 1) .. ' is no longer the continuous tower-creep order')
    assert(L[read + 2]:match('^%s*return%s*$'),
        'the consumer no longer returns -- re-derive the shadowing claim')
end

tests['[source] roamstale resets the sibling handle and says nothing about this one'] = function()
    local L = lines()
    local helper = only(L, '^function GetDesireHelper%(%)%s*$')
    local reset  = only(L, '^%s*hTargetCreep%s*=%s*nil%s*$')
    assert(helper and reset, 'the roamstale reset moved')
    assert(reset > helper, 'the roamstale reset left GetDesireHelper')

    -- It is guarded by turbo and nothing else: PROMOTED, no candidate gate.
    -- (tests/test_gate_claim_consistency.lua owns the general form of this
    -- claim; it is asserted here because the asymmetry IS the finding.)
    assert(L[reset - 1]:find('J.IsModeTurbo()', 1, true),
        'the roamstale reset is no longer the turbo-only line above ' .. reset)
    assert(not L[reset - 1]:find('IsSoakCandidate', 1, true),
        'the roamstale reset grew a candidate gate -- it is recorded as PROMOTED')

    local clr1 = only(L, 'towerTime,%s*towerCreepMode%s*=%s*0,%s*false')
    assert(reset < clr1,
        'the sibling reset is no longer above the tower block; re-derive the asymmetry')
    for i = reset - 2, reset + 2 do
        if L[i] then
            assert(not L[i]:find('towerCreepMode', 1, true),
                'the roamstale reset now also clears towerCreepMode -- this finding is FIXED,'
                .. ' retire this file instead of editing it')
        end
    end
end

tests['[source] towerTime and towerCreepMode are written only as a pair'] = function()
    -- The invariant the (unshipped) fix would lean on: `towerTime ~= 0` and
    -- `towerCreepMode` are the same bit. It is what makes re-affirming the flag
    -- inside the still-holding branch a provable no-op rather than a behaviour
    -- change -- recorded here so a future writer does not have to re-derive it,
    -- and so that breaking it turns this file red.
    local L = lines()
    local occ = hits(L, 'towerTime')
    local roles = {
        '^local%s+towerTime,%s*towerCreepTime%s*=%s*0,%s*0%s*$', -- decl
        'if%s+towerTime%s*~=%s*0%s+and',                          -- the read
        'towerTime,%s*towerCreepMode%s*=%s*0,%s*false',           -- paired clear
        'if%s+towerTime%s*==%s*0%s+then',                         -- the set guard
        '^%s*towerTime%s*=%s*DotaTime%(%)%s*$',                   -- paired set
        '^%s*towerTime%s*=%s*0%s*$',                              -- OnEnd
    }
    assert(#occ == 6, 'expected 6 lines mentioning towerTime, got ' .. #occ)
    for k, pat in ipairs(roles) do
        local i = only(L, pat)
        assert(i, 'towerTime role ' .. k .. ' (' .. pat .. ') is gone')
    end

    -- Paired: the set of towerTime is immediately followed by the set of the
    -- flag, and the clear writes both in one statement.
    local set = only(L, '^%s*towerTime%s*=%s*DotaTime%(%)%s*$')
    assert(L[set + 1]:match('^%s*towerCreepMode%s*=%s*true%s*$'),
        'towerTime is set without the flag -- the invariant this file records is broken')
end

return tests

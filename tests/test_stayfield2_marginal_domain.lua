-- [owner priority P2] What can `stayfield2` actually change, and in which
-- DIRECTION -- both answered off the shipped tree, on this repo's own corpus,
-- with no wave and no AWS.
--
-- WHY THIS FILE EXISTS. Two published strategy findings put the family's
-- condition (a) on the WALK leg and told the replay desk to measure it there:
-- GH #338 (the TP leg is empty under `fieldsip`) and GH #342 (`hp>0.55` is
-- unreachable at the TP call site). GH #342 §3 then characterised the walk leg
-- by scanning the source between `function GetDesireHelper()` and the
-- `J.ShouldRegenNotWalkHome(bot)` call for the TOKEN `botHP`, found one
-- comparison in a human-only ladder, and concluded "走路腿上两条边都是活的"
-- -- both HP edges are live there.
--
-- ⭐ THE MAIN CLAIM, and it is a correction to our own §3: a token scan cannot
-- see a clause that lives behind a call. One statement above the `stayfield2`
-- call sits
--
--     if J.ShouldStayAndRegen(bot) then return BOT_MODE_DESIRE_NONE end
--
-- which is PROMOTED (was 'tphome'), ungated, live in every turbo game -- and
-- which carries an HP band of its own, read with the SAME J.GetHP. Line it up
-- against the gated predicate's own clauses:
--
--     S = J.ShouldRegenNotGoHome        T = J.ShouldStayAndRegen
--     S1 IsModeTurbo                 == T1 IsModeTurbo
--     S2 hp in [0.18, 0.55]          =>  T2 hp in [0.18, 0.75]
--     S3 #heroes(1600) == 0          =>  T4 #heroes(1200) == 0
--     S4 ATTRIBUTED hero damage      ?   T3 any hero damage in 3s
--     S5 no tower within 1200        ==  T6 no tower within 1200
--                                        (gated 'staytower', 2026-09-06; before
--                                         that date T had no tower clause at all,
--                                         and this row said so. Gated or not, S5
--                                         IS T6, so `S and not T6` is empty and
--                                         the closed form below is unchanged --
--                                         asserted, not asserted-by-comment.)
--     H  HasFieldRegenSource         ?   T5 main-slot salve / heal buff / 90g
--
-- Three of T's five clauses are IMPLIED by S. So
--
--     ⭐ margin( stayfield2 ) = S and not T = S and ( ¬T3 or ¬T5 )
--
-- and that is a closed form: the HP band and the proximity ring -- the two
-- things every reading of this family has been banded on -- can NEVER be the
-- reason a frame is in `stayfield2`'s marginal domain. Widening the 0.55
-- ceiling changes nothing until it passes 0.75, and even then only inside
-- ¬T3 ∨ ¬T5. The replay desk's (a) read on the walk leg has to be filtered to
-- that band or it is measuring frames a shipped guard already took.
--
-- ⭐⭐ AND THE DIRECTION IS NOT WHAT THE GUARD'S NAME SAYS. mode_retreat_generic
-- ends `return Min(nDesire, 1.0)` -- clamped ABOVE, never below -- while two
-- subtractions inside it (-0.25 "nobody around and no tower", -0.75 "laning
-- phase, unhurt, untargeted") can carry the sum under zero. Every guard above
-- that arithmetic which early-outs with the constant BOT_MODE_DESIRE_NONE
-- (0.0) therefore RAISES the mode's bid on any frame whose natural bid is
-- negative. On this corpus that is most of `stayfield2`'s own marginal domain,
-- and the same arithmetic applies verbatim to the PROMOTED, shipped
-- J.ShouldStayAndRegen line one statement above it.
--
-- REUSABLE CRITERION (the next one out from GH #342 §4):
--
--   > A call-site domain audit must evaluate the guards above the call, not
--   > grep for the syntactic form of their clauses. And a guard that suppresses
--   > by RETURNING A CONSTANT is only a suppression where the quantity it
--   > replaces is known to be above that constant.
--
-- GH #319 shrank a guard's domain; GH #342 shrank the measurement's
-- denominator; this shrinks the denominator AGAIN (to ¬T3 ∨ ¬T5) and then
-- questions the SIGN of what is left.
--
-- WHAT THIS FILE DOES NOT CLAIM
--   * It does not rule on `stayfield2`'s membership, and does not answer (a),
--     (b) or (c). An implication is not a verdict.
--   * It does not say the promoted `tphome` line is wrong. It says the sign of
--     its effect on a negative-bid frame is the opposite of its name, which is
--     a fact about the arithmetic, not a ruling.
--   * Zero behaviour change, zero new gate ids: every assertion reads the
--     shipped tree or drives a real frame.
--   * The engine's tie-break among modes bidding <= 0 is NOT in this repo, so
--     "raises the bid" is arithmetic here, not a claim about what the bot then
--     does. Declared as a [limit].

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')

local tests = {}

local JMZ    = 'bots/FunLib/jmz_func.lua'
local RETMOD = 'bots/mode_retreat_generic.lua'

-- Owner priority P2's own pinned frame.
local LINA = 'tests/fixtures/f_260822_063722_lina_tp_home.lua'

-- Corpus readings, recorded as named constants so a moved number names itself
-- in the failure message instead of appearing as a bare literal in a compare.
-- 铁律 4(ii): these are integer counts over a small range, so they are reported
-- as counts with their denominators, never as a median.
-- 2026-09-03 (replay-check): re-measured on the corpus grown by
-- f_260902_154755_cm_wandbleed_residue.lua (GH #437's frame, landed under the
-- director's ruling in owed_executions.json). The four numbers that moved are
-- the ones the new fixture adds to directly -- 1003+9 live frames, one more S
-- frame, and that S frame is ABSORBED, not marginal: it is its zuus at 18.5% HP
-- with S=1 T=1 supply=1. MARGIN and every MARGIN_* / SIGN_MARGIN_* count below
-- are unchanged, i.e. what stayfield2 OWNS did not move -- which is the reading
-- this file exists for, and it is now stated over a larger denominator.
local LIVE_FRAMES     = 1012  -- live hero frames, every hero of every fixture
local S_FIRES         = 24    -- J.ShouldRegenNotGoHome true
local ABSORBED        = 5     -- ... and J.ShouldStayAndRegen already true
local MARGIN          = 19    -- ... and NOT already true: what stayfield2 owns
local MARGIN_DMG_ONLY = 0     -- of MARGIN: only T3 (unattributed damage) failed
local MARGIN_SUPPLY   = 18    -- of MARGIN: only T5 (supply) failed
local MARGIN_BOTH     = 1     -- of MARGIN: both failed
local T_ONLY_HP_BAND  = 6     -- T true with hp in (0.55, 0.75] -- S cannot speak
local BAG_FRAMES      = 15    -- frames carrying a backpacked salve
local SIGN_SUBSAMPLE  = 109   -- fixture.self on every fixture (declared slice)
local SIGN_NATURAL_NEG = 56   -- ... whose natural retreat bid is NEGATIVE
local SIGN_MARGIN_NEG = 14    -- of MARGIN: the guard RAISES the bid
local SIGN_MARGIN_POS = 5     -- of MARGIN: the guard LOWERS the bid

local function read(path)
    local f = assert(io.open(path, 'r'), 'cannot read ' .. path)
    local s = f:read('*a')
    f:close()
    return s
end

--- Comments MASKED, not stripped: replaced by an equal run of spaces so byte
--- offsets stay aligned with the original. GH #342 §6.1 is why -- that round
--- stripped comments, deleted the anchor it was about to search for (the
--- anchor was itself a comment), and turned ten arithmetic cases red on a
--- healthy tree. Line comments only: this tree has no long-bracket comments.
local function mask_comments(src)
    local out = {}
    for line in (src .. '\n'):gmatch('([^\n]*)\n') do
        local i = line:find('%-%-')
        if i then
            out[#out + 1] = line:sub(1, i - 1) .. string.rep(' ', #line - i + 1)
        else
            out[#out + 1] = line
        end
    end
    return table.concat(out, '\n')
end

--- The body of one `function J.<name>(` ... matching `\nend`, comments masked.
local function fn_body(src, name)
    local masked = mask_comments(src)
    local i = assert(masked:find('function ' .. name .. '( bot )', 1, true)
        or masked:find('function ' .. name .. '(', 1, true),
        name .. ' was renamed or its signature changed')
    local j = assert(masked:find('\nend', i, true), name .. ' has no terminator')
    return masked:sub(i, j)
end

--============================================================================
-- [source] The shape the whole closed form rests on. Each of these is a
-- separate way the implication can stop being true, so each is its own case.
--============================================================================

tests['[ratchet][source] the shipped veto is the LAST statement before the stayfield2 call'] = function()
    local ret = mask_comments(read(RETMOD))
    local i = assert(ret:find('function GetDesireHelper()', 1, true),
        'the retreat bid function was renamed')
    local call = assert(ret:find('J.ShouldRegenNotWalkHome(bot)', i, true),
        'the stayfield2 call left GetDesireHelper')
    local veto = assert(ret:find('J.ShouldStayAndRegen(bot)', i, true),
        'the shipped veto left the leg above the call')
    assert(veto < call, 'the shipped veto no longer precedes the stayfield2 call')
    -- Nothing executable between them. If a third guard is ever inserted here
    -- the marginal domain gains a term and every count below is stale.
    -- The slice starts AT the veto's call expression (i.e. just past its own
    -- `if`) and ends at the guarded call's, so a clean leg contains exactly one
    -- `end` (the veto block's) and exactly one `if` (the guarded call's). A
    -- third guard inserted here shows up as either count going to two.
    local between = ret:sub(veto, call)
    local _, nEnds = between:gsub('%f[%w]end%f[%W]', '')
    assert(nEnds == 1, 'more than the veto block sits between them: ' .. between)
    assert(between:find('BOT_MODE_DESIRE_NONE', 1, true) ~= nil,
        'the shipped veto no longer returns NONE, so it no longer absorbs '
        .. 'the frames stayfield2 would have taken')
    local _, nIfs = between:gsub('%f[%w]if%f[%W]', '')
    assert(nIfs == 1, 'a third conditional appeared between veto and call: ' .. between)
end

tests['[ratchet][source] both HP bands read the SAME function, so they compare without conversion'] = function()
    local jmz = read(JMZ)
    local s = fn_body(jmz, 'J.IsFieldRegenSituation')
    local t = fn_body(jmz, 'J.ShouldStayAndRegen')
    for _, body in ipairs({ s, t }) do
        assert(body:find('local nHP = J.GetHP( bot )', 1, true) ~= nil,
            'one of the two helpers stopped reading J.GetHP -- the two HP bands '
            .. 'are no longer the same quantity and the implication is void')
    end
    -- And neither reads the raw engine ratio behind the other's back.
    assert(s:find('GetHealth()', 1, true) == nil, 'S grew a second HP source')
    assert(t:find('GetHealth()', 1, true) == nil, 'T grew a second HP source')
end

tests['[ratchet][source] the four HP constants are parsed, not written down'] = function()
    local jmz = read(JMZ)
    local sLo, sHi = fn_body(jmz, 'J.IsFieldRegenSituation')
        :match('nHP < ([%d%.]+) or nHP > ([%d%.]+)')
    local tLo, tHi = fn_body(jmz, 'J.ShouldStayAndRegen')
        :match('nHP < ([%d%.]+) or nHP > ([%d%.]+)')
    assert(sLo and tLo, 'an HP band changed shape and can no longer be parsed')
    assert(tonumber(sLo) == 0.18 and tonumber(sHi) == 0.55,
        'the S band moved: ' .. sLo .. '..' .. sHi)
    assert(tonumber(tLo) == 0.18 and tonumber(tHi) == 0.75,
        'the T band moved: ' .. tLo .. '..' .. tHi)
    -- [arith] The implication itself, derived from what was parsed.
    assert(tonumber(sLo) >= tonumber(tLo) and tonumber(sHi) <= tonumber(tHi),
        'S is no longer inside T on HP -- the HP band can now put a frame in '
        .. 'the margin and every count in this file is stale')
    assert(tonumber(sHi) < tonumber(tHi),
        'the bands now share their ceiling; the (0.55, 0.75] gap T owns alone '
        .. 'has closed')
end

tests['[ratchet][source] the two rings are 1600 (S) and 1200 (T), in that order'] = function()
    local jmz = read(JMZ)
    local sR = fn_body(jmz, 'J.IsFieldRegenSituation')
        :match('GetNearbyHeroes%( bot, (%d+), true, BOT_MODE_NONE %)')
    local tR = fn_body(jmz, 'J.ShouldStayAndRegen')
        :match('GetNearbyHeroes%( bot, (%d+), true, BOT_MODE_NONE %)')
    assert(sR and tR, 'a proximity clause changed shape')
    assert(tonumber(sR) == 1600 and tonumber(tR) == 1200,
        'a ring moved: S=' .. sR .. ' T=' .. tR)
    assert(tonumber(sR) >= tonumber(tR),
        'S no longer measures the wider ring -- the proximity implication is '
        .. 'void and the ring can now put a frame in the margin')
end

tests['[ratchet][source] T has exactly five clauses, and exactly two are unimplied'] = function()
    local t = fn_body(read(JMZ), 'J.ShouldStayAndRegen')
    -- Every `return false` guard in T, counted. The closed form is about the
    -- SHIPPED five; a sixth is only harmless if it is gated AND implied by S, and
    -- both halves of that are asserted in the case below rather than assumed
    -- here. Re-derived 2026-09-06 when the sixth arrived ('staytower'): the count
    -- was raised only after the closed form was re-checked, never to make a red
    -- go away.
    local _, nReturns = t:gsub('return false', '')
    -- The gated sixth, matched as a WHOLE BLOCK so "gated" is read off the block
    -- that owns the veto rather than inferred from an id appearing somewhere in
    -- the function (this function names five ids).
    local sT6 = "if J.IsSoakCandidate( 'staytower' )\n"
        .. '\tand #bot:GetNearbyTowers( 1200, true ) > 0\n'
        .. '\tthen\n\t\treturn false\n\tend'
    local nGatedReturns = t:find(sT6, 1, true) and 1 or 0
    assert(nReturns - nGatedReturns == 5, 'J.ShouldStayAndRegen no longer has five '
        .. 'UNGATED vetoes (' .. (nReturns - nGatedReturns) .. ' of ' .. nReturns
        .. ' total) -- re-derive the margin before trusting any count')
    -- The two that S does not imply, named off the source so a rename is a red.
    assert(t:find('bot:WasRecentlyDamagedByAnyHero( 3.0 )', 1, true) ~= nil,
        'T3 (unattributed hero damage) left T')
    assert(t:find("J.IsItemAvailable( 'item_flask' )", 1, true) ~= nil,
        'T5 lost its main-slot salve leg')
    assert(t:find('bot:GetGold() < 90', 1, true) ~= nil, 'T5 lost its gold leg')
    -- S's own damage clause is ATTRIBUTED -- that asymmetry is the whole of T3.
    local s = fn_body(read(JMZ), 'J.IsFieldRegenSituation')
    assert(s:find('bot:WasRecentlyDamagedByHero( hEnemy, 3.0 )', 1, true) ~= nil,
        'S stopped attributing its damage read; T3 is no longer an asymmetry')
    -- ... and the RADIUS of that attribution sweep is the size of the
    -- asymmetry, so it is pinned too. Added because the mutation stand caught
    -- this file NOT pinning it: shrinking 3000 to 300 left all 18 cases green.
    -- Per evidence-discipline rule 2 the suspect is the assertion, not the
    -- mutation -- and the reason the corpus agreed with the broken rule is
    -- recorded as a [limit] below, because it will still agree tomorrow.
    local sweepR = s:match('J%.GetNearbyHeroes%( bot, (%d+), true, BOT_MODE_NONE %)[^\n]*\n[^\n]*\n%s*for')
        or s:match('hEnemyList = J%.GetNearbyHeroes%( bot, (%d+),')
    assert(sweepR, 'S4 attribution sweep changed shape and can no longer be parsed')
    assert(tonumber(sweepR) == 3000,
        'the attribution sweep radius moved from 3000 to ' .. sweepR
        .. ' -- that IS the size of the S4-vs-T3 asymmetry, so the margin '
        .. 'this file computes has changed')
    -- Strictly wider than the ring S already requires empty: inside 1600 there
    -- is nobody at all, so the sweep only ever finds heroes in [1600, 3000).
    local sRing = s:match('#J%.GetNearbyHeroes%( bot, (%d+), true, BOT_MODE_NONE %) > 0')
    assert(tonumber(sweepR) > tonumber(sRing),
        'the attribution sweep is no longer wider than the empty ring, so it '
        .. 'can never find anyone and S4 has collapsed into "damage vetoes"')
end

tests['[ratchet][source] the gated sixth veto is S5, so the closed form survives arming'] = function()
    -- [staytower, 2026-09-06] The table at the top of this file has always had a
    -- row reading `S5 no tower within 1200 | (T has no tower clause)`. That row is
    -- now a gated lever rather than a hole, and the only thing this file has to
    -- establish is that it does NOT move the closed form.
    --
    -- The arithmetic, in full, because a count alone would not show it:
    --   margin  = S ∧ ¬T                     (definition)
    --   T'      = T ∧ T6                     (arming appends one veto)
    --   margin' = S ∧ ¬T' = S ∧ (¬T ∨ ¬T6)
    --           = (S ∧ ¬T) ∨ (S ∧ ¬T6)
    -- and S ∧ ¬T6 is EMPTY because S5 IS T6 -- the same predicate, the same
    -- radius, read out of both bodies below rather than restated here. So
    -- margin' = margin, and every count in this file stands with the id armed.
    local jmz = read(JMZ)
    local t = fn_body(jmz, 'J.ShouldStayAndRegen')
    local s = fn_body(jmz, 'J.IsFieldRegenSituation')
    local tTow = t:match('#bot:GetNearbyTowers%( (%d+), true %) > 0')
    local sTow = s:match('#bot:GetNearbyTowers%( (%d+), true %) > 0')
    assert(sTow, 'S5 changed shape and can no longer be parsed -- the closed form '
        .. 'above rests on it')
    assert(tTow, "T's gated tower veto changed shape and can no longer be parsed")
    assert(tonumber(tTow) == tonumber(sTow), 'the tower radii diverged: T6='
        .. tTow .. ' S5=' .. sTow .. ' -- S no longer implies T6, so `S ∧ ¬T6` is '
        .. 'not empty and the margin this file computes has GROWN')
    assert(tonumber(sTow) == 1200, 'the owning constant itself moved to ' .. sTow
        .. ' -- the equality above would then be two copies of a new number')
    -- And it must stay GATED: ungated it would be a shipped behaviour change,
    -- which this file's "zero behaviour change" premise does not survive.
    assert(t:find("J.IsSoakCandidate( 'staytower' )", 1, true) ~= nil,
        'the tower veto in T is no longer gated on staytower -- if its gate was '
        .. 'removed, this file\'s S-implies-T3/T4 table and its whole '
        .. '"zero behaviour change" framing need re-reading first')
end

tests['[ratchet][source] IsItemAvailable stops at slot 5, so a backpacked salve leaves T5 false'] = function()
    local jmz = mask_comments(read(JMZ))
    local i = assert(jmz:find('function J.IsItemAvailable( sItemName )', 1, true))
    local body = jmz:sub(i, assert(jmz:find('\nend', i, true)))
    assert(body:find('slot >= 0 and slot <= 5', 1, true) ~= nil,
        'IsItemAvailable changed its slot range -- bagsalve is no longer able '
        .. 'to create margin at this call site')
    -- ... while HasFieldRegenSource, armed, reaches 6..8.
    local h = fn_body(jmz, 'J.HasFieldRegenSource')
    assert(h:find("J.IsSoakCandidate( 'bagsalve' )", 1, true) ~= nil,
        'the bagsalve widening left HasFieldRegenSource')
    assert(h:find('for i = 6, 8 do', 1, true) ~= nil,
        'the backpack range moved')
end

--============================================================================
-- ⭐ [source][arith] The sign. This is the half that changes what the guard
-- MEANS, and it is four lines of the shipped file.
--============================================================================

tests['[ratchet][source] the retreat bid is clamped ABOVE only, and two clauses push it down'] = function()
    local ret = mask_comments(read(RETMOD))
    assert(ret:find('return Min(nDesire, 1.0)', 1, true) ~= nil,
        'the retreat bid stopped ending in an upper-only clamp -- if a lower '
        .. 'clamp appeared, the sign finding in this file is obsolete (good) '
        .. 'and every SIGN count below must be re-read')
    -- No Max(..., 0) anywhere on the way out.
    assert(ret:find('Max(nDesire', 1, true) == nil,
        'a lower clamp on nDesire appeared; re-derive the sign claim')
    -- The two subtractions that can carry the sum under zero, parsed.
    local subs = {}
    for v in ret:gmatch('nDesire = nDesire %- ([%d%.]+)') do subs[#subs + 1] = v end
    assert(#subs >= 2, 'the negative contributions to nDesire changed shape')
    local total = 0
    for _, v in ipairs(subs) do total = total + tonumber(v) end
    assert(total >= 1.0, 'the negative contributions no longer sum past 1.0 ('
        .. total .. '), so a natural bid can no longer be driven below zero '
        .. 'by them alone')
    -- And the guard replaces that signed quantity with a CONSTANT.
    local i = assert(ret:find('J.ShouldRegenNotWalkHome(bot)', 1, true))
    local blk = ret:sub(i, i + 120)
    assert(blk:find('BOT_MODE_DESIRE_NONE', 1, true) ~= nil,
        'the stayfield2 guard stopped returning the constant')
end

--============================================================================
-- [drive] The real frame. Owner priority P2's own pinned instant, driven
-- through the shipped helpers -- no modelling of any operand.
--============================================================================

tests['[ratchet][drive] on P2 own frame the margin is real, and it is T3+T5 that make it'] = function()
    GAMEMODE_TURBO = nil -- luacheck: ignore
    local J, bot = rf.load(LINA)
    GAMEMODE_TURBO = 23                    -- luacheck: ignore
    GetGameMode = function() return 23 end -- luacheck: ignore
    J.IsSoakCandidate = function(id) return id == 'stayfield2' end

    assert(J.ShouldRegenNotGoHome(bot) == true, 'S must hold on the pinned frame')
    assert(J.ShouldStayAndRegen(bot) == false,
        'T must NOT hold -- otherwise the shipped guard already took this '
        .. 'frame and stayfield2 was written for nothing')
    -- Which clause of T failed. Both, on this frame, and the file says so
    -- rather than leaving the reader to infer it from the conjunction.
    assert(bot:WasRecentlyDamagedByAnyHero(3.0) == true,
        'T3: the global ult 2.6s earlier must still be in the 3s window')
    assert(J.IsItemAvailable('item_flask') == nil, 'T5: no main-slot salve')
    assert(bot:GetGold() < 90, 'T5: and under the gold floor')
    -- ... while S's ATTRIBUTED read survives the same damage, which is the
    -- entire asymmetry T3 names.
    assert(J.IsFieldRegenSituation(bot) == true,
        'S4 must tolerate the unattributed damage T3 rejects')

    GAMEMODE_TURBO = nil                               -- luacheck: ignore
    GetGameMode = function() return GAMEMODE_TURBO end -- luacheck: ignore
end

tests['[ratchet][control] the HP band alone cannot create margin, driven both sides of 0.55'] = function()
    GAMEMODE_TURBO = nil -- luacheck: ignore
    local J, bot = rf.load(LINA)
    GAMEMODE_TURBO = 23                    -- luacheck: ignore
    GetGameMode = function() return 23 end -- luacheck: ignore
    J.IsSoakCandidate = function(id) return id == 'stayfield2' end

    -- Model ONE operand -- J.GetHP -- and leave every other clause on the real
    -- frame. Sweeping it across the S ceiling shows the shape the closed form
    -- predicts: S switches off at 0.55 while T (had its other clauses held)
    -- would still be on up to 0.75, i.e. the gap is T's alone.
    local realHP = J.GetHP
    local hp
    J.GetHP = function() return hp end
    local seen = {}
    for _, v in ipairs({ 0.54, 0.56, 0.74, 0.76 }) do
        hp = v
        seen[#seen + 1] = J.IsFieldRegenSituation(bot) and 1 or 0
    end
    J.GetHP = realHP
    assert(seen[1] == 1 and seen[2] == 0 and seen[3] == 0 and seen[4] == 0,
        'the S ceiling stopped deciding at 0.55: ' .. table.concat(seen, ','))
    -- The control that makes the line above mean something: the probe really
    -- is load-bearing (a value inside the band flips it back on).
    J.GetHP = function() return 0.30 end
    assert(J.IsFieldRegenSituation(bot) == true, 'the HP probe is inert')
    J.GetHP = realHP

    GAMEMODE_TURBO = nil                               -- luacheck: ignore
    GetGameMode = function() return GAMEMODE_TURBO end -- luacheck: ignore
end

--============================================================================
-- [recorded] The corpus census. Run in its own process
-- (tests/_stayfield2_margin_sweep.lua) for the reason recorded in charter 0q.
--============================================================================

local sweep_cache
local function sweep()
    if sweep_cache then return sweep_cache end
    local p = assert(io.popen('lua5.1 tests/_stayfield2_margin_sweep.lua 2>/dev/null'))
    local out = p:read('*a')
    p:close()
    assert(out and out ~= '', 'the sweep produced nothing')
    sweep_cache = out
    return out
end

tests['[recorded] the margin is SMALLER than the predicate: 5 of 24 S frames are already absorbed'] = function()
    local out = sweep()
    local nF, nS, nT, nST, nM =
        out:match('COUNT frames=(%d+) S=(%d+) T=(%d+) ST=(%d+) margin=(%d+)')
    assert(nF, 'the sweep did not report a COUNT line: ' .. out)
    assert(tonumber(nF) == LIVE_FRAMES, 'the live-frame denominator moved: ' .. nF)
    assert(tonumber(nS) == S_FIRES, 'S fires moved from ' .. S_FIRES .. ': ' .. out)
    assert(tonumber(nST) == ABSORBED, 'the absorbed count moved from ' .. ABSORBED .. ': ' .. out)
    assert(tonumber(nM) == MARGIN, 'the margin moved from ' .. MARGIN .. ': ' .. out)
    assert(tonumber(nS) - tonumber(nST) == tonumber(nM), 'the 2x2 does not close')
    assert(tonumber(nT) >= tonumber(nST), 'T cannot be smaller than S and T')
end

tests['[recorded] the margin is made of the SUPPLY clause, not the danger clause'] = function()
    local out = sweep()
    local d, s, b, n = out:match('CLAUSE dmg=(%d+) supply=(%d+) both=(%d+) neither=(%d+)')
    assert(d, 'the sweep did not report a CLAUSE line: ' .. out)
    -- ⭐ The design rationale written at the top of J.IsFieldRegenSituation
    -- names the ATTRIBUTED-danger asymmetry (reason 2, the global ult) as why
    -- the helper exists. On this corpus that clause contributes NO margin frame
    -- on its own: every margin frame is a supply-clause frame.
    assert(tonumber(d) == MARGIN_DMG_ONLY, 'the danger clause alone now makes '
        .. 'margin (' .. d .. ') -- the "supply is the whole margin" reading is stale')
    assert(tonumber(s) == MARGIN_SUPPLY,
        'the supply-only margin moved from ' .. MARGIN_SUPPLY .. ': ' .. out)
    assert(tonumber(b) == MARGIN_BOTH,
        'the both-clauses margin moved from ' .. MARGIN_BOTH .. ': ' .. out)
    local _, _, _, nST = out:match('COUNT frames=(%d+) S=(%d+) T=(%d+) ST=(%d+)')
    assert(tonumber(n) == tonumber(nST),
        '"neither clause failed" must be exactly the absorbed set')
end

tests['[recorded] the two implications are measured, not assumed'] = function()
    local out = sweep()
    local above, band = out:match('HPBAND s_above55=(%d+) t_in_55_75=(%d+)')
    assert(above, 'the sweep did not report an HPBAND line: ' .. out)
    assert(tonumber(above) == 0, 'an S frame appeared above 0.55: ' .. out)
    -- The gap is not empty -- 6 real frames sit where only the promoted guard
    -- can speak. That is what makes the correction to GH #342 §3 load-bearing
    -- rather than pedantic.
    assert(tonumber(band) == T_ONLY_HP_BAND,
        'the T-only HP band moved from ' .. T_ONLY_HP_BAND .. ': ' .. out)
    local chk, bad = out:match('RING mono_checked=(%d+) mono_violations=(%d+)')
    assert(chk, 'the sweep did not report a RING line: ' .. out)
    assert(tonumber(chk) == LIVE_FRAMES, 'the ring check lost frames: ' .. out)
    assert(tonumber(bad) == 0,
        'GetNearbyHeroes stopped being monotone in its radius -- the '
        .. '1600 => 1200 implication is void: ' .. out)
end

tests['[recorded] bagsalve creates no margin HERE, and that is a corpus fact not a proof'] = function()
    local out = sweep()
    local bag, wo, wi = out:match(
        'BAGSALVE bag_frames=(%d+) margin_without=(%d+) margin_with=(%d+)')
    assert(bag, 'the sweep did not report a BAGSALVE line: ' .. out)
    -- The closed form says a backpacked salve CAN create margin here: it makes
    -- HasFieldRegenSource true while IsItemAvailable (slots 0-5) stays nil, so
    -- T5 can still fail. The corpus says no such frame ALSO clears the rest of
    -- S. Both are recorded; neither replaces the other.
    assert(tonumber(bag) == BAG_FRAMES,
        'the backpacked-salve population moved from ' .. BAG_FRAMES .. ': ' .. out)
    assert(tonumber(wo) == tonumber(wi),
        'a corpus frame now gains margin from bagsalve at the WALK site -- '
        .. 'that is new and belongs in the family ruling: ' .. out)
end

--============================================================================
-- ⭐⭐ [recorded] THE SIGN. On this corpus the guard's marginal domain and the
-- set of frames whose bid it MOVES coincide exactly -- and on most of them the
-- move is UPWARD, because the quantity replaced by the constant 0.0 is
-- negative. This is the half a "does it fire?" reading cannot see.
--============================================================================

tests['[recorded] the margin is exactly the set of frames whose bid moves'] = function()
    local out = sweep()
    local sf, mv, mm, ma =
        out:match('BID s_frames=(%d+) moved=(%d+) moved_in_margin=(%d+) moved_in_absorbed=(%d+)')
    assert(sf, 'the sweep did not report a BID line: ' .. out)
    assert(tonumber(ma) == 0,
        'a frame the shipped guard already absorbed now moves when stayfield2 '
        .. 'is armed -- the absorption is no longer total: ' .. out)
    assert(tonumber(mm) == MARGIN and tonumber(mv) == MARGIN,
        'the bid-moving set moved from ' .. MARGIN .. ': ' .. out)
    assert(tonumber(sf) == S_FIRES, 'the S denominator moved: ' .. out)
    local nM = out:match('COUNT frames=%d+ S=%d+ T=%d+ ST=%d+ margin=(%d+)')
    assert(tonumber(mm) == tonumber(nM),
        'margin and bid-moving set stopped coinciding -- one of them is now '
        .. 'the wrong number to quote for this id: ' .. out)
end

tests['[recorded] most of that movement is the bid going UP, not down'] = function()
    local out = sweep()
    local sub, neg, zero, pos, mneg, mpos = out:match(
        'SIGN subsample=(%d+) natural_neg=(%d+) natural_zero=(%d+) natural_pos=(%d+) '
        .. 'margin_neg=(%d+) margin_pos=(%d+)')
    assert(sub, 'the sweep did not report a SIGN line: ' .. out)
    assert(tonumber(neg) + tonumber(zero) + tonumber(pos) == tonumber(sub),
        'the sign census does not partition its subsample: ' .. out)
    assert(tonumber(sub) == SIGN_SUBSAMPLE,
        'the declared subsample changed size from ' .. SIGN_SUBSAMPLE
        .. ' -- it is fixture.self on every fixture, fixed by the corpus: ' .. out)
    -- ⭐ The load-bearing pair. Both are recorded as exact numbers because the
    -- claim is a RATIO, and a ratio quoted without its two counts is the shape
    -- 铁律 4(ii) forbids.
    assert(tonumber(mneg) == SIGN_MARGIN_NEG,
        'the count of margin frames where the guard RAISES the bid moved from '
        .. SIGN_MARGIN_NEG .. ': ' .. out)
    assert(tonumber(mpos) == SIGN_MARGIN_POS,
        'the count of margin frames where the guard LOWERS the bid moved from '
        .. SIGN_MARGIN_POS .. ': ' .. out)
    assert(tonumber(mneg) + tonumber(mpos) == MARGIN,
        'the signed split does not add up to the margin: ' .. out)
    -- The population shape on the declared subsample: this is not a quirk of
    -- the 19, a negative natural bid is ORDINARY in this mode -- which is what
    -- makes the constant-return shape a general hazard rather than a curiosity.
    assert(tonumber(neg) == SIGN_NATURAL_NEG,
        'the negative-natural-bid count moved from ' .. SIGN_NATURAL_NEG
        .. ' -- every "this guard suppresses" sentence about this file has to '
        .. 'be re-read: ' .. out)
    assert(tonumber(neg) > tonumber(pos),
        'negative natural bids stopped being the majority of the subsample; '
        .. 'the generality of the sign hazard is no longer supported: ' .. out)
end

--============================================================================
-- [limit] Honest bounds. Each is a thing a reader could otherwise take from
-- this file and should not.
--============================================================================

tests['[limit] the corpus is biased, so these are shapes and floors, not rates'] = function()
    -- The fixtures were cut to pin OTHER decisions. 1012 live hero frames is a
    -- large denominator but not a random sample of turbo play, so nothing here
    -- is a frequency for a real game. What IS transportable is the closed form
    -- (source-parsed) and the SIGN of the effect, neither of which depends on
    -- how the frames were chosen.
    local out = sweep()
    assert(out:find('COUNT frames=' .. LIVE_FRAMES, 1, true) ~= nil,
        'the denominator changed; re-read this limit before quoting a rate')
end

tests['[limit] the corpus cannot discriminate the attribution radius, only the source can'] = function()
    -- The 3000 in S4 is pinned by SOURCE above, and that is the only way it can
    -- be pinned here: on every S frame in this corpus the nearest enemy hero is
    -- far outside 3000 anyway (owner P2's own frame has it at 6,596), so the
    -- sweep finds nobody whatever its radius. The corpus AGREES with a broken
    -- 300 -- measured, not supposed: the mutation stand ran that mutant and all
    -- 18 cases stayed green until the source pin was added. The dangerous
    -- direction is the quiet one, so it is written down rather than inferred.
    local out = sweep()
    local d = out:match('CLAUSE dmg=(%d+)')
    assert(tonumber(d) == MARGIN_DMG_ONLY,
        'the damage clause started making margin on its own; the corpus may '
        .. 'now discriminate the sweep radius and this limit is stale: ' .. out)
end

tests['[limit] "raises the bid" is arithmetic, not a claim about what the bot does'] = function()
    -- The engine picks the highest-bidding mode. What it does when every mode
    -- bids <= 0 is NOT in this repository, so a move from -0.77 to 0.0 is
    -- proven to change the NUMBER and is not proven to change the ACTION. The
    -- one thing it does rule out is the opposite reading -- that the guard can
    -- only ever lower this mode's bid -- and that reading is what the guard's
    -- name and comment both invite.
    local ret = read(RETMOD)
    assert(ret:find('GetHighestExecuteDesire', 1, true) == nil,
        'the mode file now reads the arbitration itself; the limit above may '
        .. 'be resolvable in-repo')
end

tests['[limit] this file rules on nobody'] = function()
    -- Neither `stayfield`, `stayfield2` nor the promoted `tphome` line is
    -- admitted, returned or re-ranked here, and no condition (a)/(b)/(c) is
    -- answered. Same guard, and same reason, as the sibling files: the
    -- distinction between a derivation and a verdict is only durable if
    -- something fails when it is blurred. Each needle is split so the list
    -- itself is not a match.
    local body = mask_comments(read('tests/test_stayfield2_marginal_domain.lua'))
    for _, halves in ipairs({ { 'prom', 'ote' }, { 'INDETER', 'MINATE' },
                              { 'WOR', 'KING' }, { 'SIL', 'ENT' } }) do
        local word = halves[1] .. halves[2]
        assert(body:find(word, 1, true) == nil,
            'a verdict vocabulary word entered the executable part of this '
            .. 'file: ' .. word)
    end
end

return tests

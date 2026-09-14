-- [owner priority P2 / charter 0NEXT11] What is left of `stayfield2`'s marginal
-- domain ON THE STRING THE WAVES ACTUALLY FLY -- answered off the shipped tree,
-- on this repo's own corpus, with no wave and no AWS.
--
-- WHY THIS FILE EXISTS, and the whole of it is one word: WHICH STRING.
--
-- tests/test_stayfield2_marginal_domain.lua derived and measured the closed form
--
--     margin( stayfield2 ) = S and not T = S and ( not T3 or not T5 )
--
-- with S = J.ShouldRegenNotGoHome (the gated predicate) and T =
-- J.ShouldStayAndRegen (the promoted absorber sitting one statement above the
-- call). That reading is correct and this file reproduces it digit-for-digit.
-- But it was taken in a world where the ONLY armed id was `stayfield2` itself,
-- and `S` is not a fixed predicate: it has a SECOND soak id inside it.
--
--     function J.ShouldRegenNotGoHome( bot )
--         if not J.IsFieldRegenSituation( bot ) then return false end
--         if not J.HasFieldRegenSource( bot ) then return false end
--         if not J.IsFieldSipEnough( bot ) then return false end   -- 'fieldsip'
--         return true
--     end
--
-- Unarmed, J.IsFieldSipEnough is the literal `true` and S is the three-clause
-- predicate the closed form was derived from. ARMED -- and it IS armed, it has
-- been in the member string since 2026-09-08 -- it adds a MAGNITUDE test: the
-- drinkable in the bag must be worth at least J.FIELD_SIP_MIN_FRACTION of max
-- HP. So S gets strictly harder, and `stayfield2`'s domain can only shrink.
--
-- ⭐ THE READING. On today's 26-id member string, 22 of S's 24 corpus frames are
-- taken by that magnitude clause, and the 2 survivors are BOTH already absorbed
-- by the promoted veto. `stayfield2` is armed, wired, and its live marginal
-- domain on this corpus is EXACTLY ZERO: there is no frame on which arming it
-- can change what the retreat mode bids.
--
-- ⭐⭐ THIS IS THE `pullcad` SHAPE, AND IT IS BEING SAID BEFORE THE WAVE, NOT
-- AFTER. AGENTS.md records `pullcad`: promoting an id silently froze a gate that
-- named it, the lever no-opped in every wave, `check_armed_wiring.py` still
-- called it WIRED (it checks that a call site exists, not that the predicate can
-- be true), and the verdict read back "tested, no effect" with nothing raising a
-- hand. What is here is the DUAL and it evades the same reader for the same
-- reason: nothing is frozen false -- `fieldsip` is armed, so the 开工自检 inverse
-- gate census prints `fieldsip under 'stayfield2'` and then `no armed id hangs
-- under an unarmed gate -- OK`. Every automatic reader we own is satisfied. What
-- none of them asks is the size of the domain that survives BOTH arms.
--
--     ⇒ REUSABLE CRITERION. "Is this id wired?" and "can this id change a frame
--       on the string it is flying under?" are different questions, and the
--       wiring census answers only the first. Two ids that are individually
--       reachable can compose to an empty domain, and the composition is
--       invisible from either id's own gate.
--
-- ⛔ THE ERROR SHAPE (charter 0NEXT10 / GH #277): a rate measured on the wrong
-- population. There the wrong population was the corpus -- a whole-corpus pass
-- rate standing in for a domain-conditional one. Here it is the WORLD -- a
-- single-id arm standing in for the live member string. Same defect, different
-- axis, and neither is visible from the reading itself.
--
-- ⚠️ WHAT THIS FILE DOES NOT SAY. It does not say `fieldsip` is wrong. The
-- 2026-09-08 pricing (tests/test_fieldsip_atom_pricing.lua) measured the SAME 22
-- frames as a TRANSFER from the hold side to the supply side (`fieldbuy`), and
-- tests/test_fieldsip_transfer_receiving_site.lua closed the receiving-site half
-- of it on 2026-09-14. Both of those readings stand. What was never read is the
-- consequence for the DONOR: after that transfer the hold side has two frames
-- left and the promoted veto already owns both. A transfer can be entirely
-- correct and still empty the id it was taken from -- and "the transfer is
-- correct" is not an answer to "what is left".
--
-- ⛔ NO LEVER IS LANDED HERE, and that is the reading's own conclusion, not a
-- budget. Narrowing an empty domain moves nothing; charter 0NEXT11 names outcome
-- (b) -- frequency evidence plus a reading handed to the director -- as the
-- legitimate product when the live domain is zero, and the `lanefix` bill
-- (gpm -74.5 / -88.7) is what paying for a lever with no evidence costs.
--
-- Usage: lua5.1 tests/run_tests.lua stayfield2_live_domain
-- ⚠️ NOT `lua5.1 tests/test_stayfield2_live_domain.lua` -- run directly, a test
-- file returns its table without calling anything and exits 0 having executed
-- zero bodies (run_tests.lua header, GH #200). The runner is the only entry
-- point that can tell a pass from a no-op.
-- [detector][ratchet]

package.path = 'tests/?.lua;' .. package.path

local tests = {}

local JMZ = 'bots/FunLib/jmz_func.lua'
local cs = require('corpus_scale')

-- ⭐ THE READING, taken 2026-09-14 on the 26-id member string.
--
-- Every count below is a SUM OVER FIXTURES, so the corpus-scale doctrine
-- applies: counts that can only grow under append are FLOORS (cs.ratchet), and
-- the claims whose entire content is a ZERO stay equalities -- those are exactly
-- the assertions this file's conclusion is argued from, and they must go red the
-- moment the corpus grows a counter-example. That is the point of them.
local SOLO_S      = 24   -- FLOOR: J.ShouldRegenNotGoHome true, `stayfield2` alone
local SOLO_MARGIN = 19   -- FLOOR: ... and J.ShouldStayAndRegen false
local LIVE_S      = 2    -- FLOOR: the same predicate on the live member string
local LIVE_MARGIN = 0    -- ⭐ EQUALITY, and it is the finding: an empty domain
local S_LOST      = 22   -- FLOOR: S frames the live string takes away
local WHYS_OTHER  = 0    -- EQUALITY: none of the loss is anything but `fieldsip`
local T_GAINED    = 0    -- EQUALITY: no armed id makes the absorber fire more

local function read(path)
    local f = assert(io.open(path, 'r'))
    local s = f:read('*a')
    f:close()
    return s
end

--- Strip comments so a source ratchet cannot be satisfied by prose that merely
--- describes the code it is supposed to be reading.
local function mask_comments(src)
    local out = {}
    for line in (src .. '\n'):gmatch('([^\n]*)\n') do
        out[#out + 1] = line:gsub('%-%-.*$', '')
    end
    return table.concat(out, '\n')
end

local function fn_body(src, name)
    -- `name` is given PLAIN (`J.ShouldRegenNotGoHome`); the escaping happens
    -- here, once. Passing a pre-escaped name double-escapes the dot into `%%.`
    -- and the find silently matches nothing -- a source ratchet that cannot
    -- locate its subject fails loudly here rather than passing vacuously.
    local pat = 'function%s+' .. name:gsub('%.', '%%.') .. '%s*%b()'
    local i = src:find(pat)
    assert(i, 'function ' .. name .. ' not found in ' .. JMZ)
    local j = src:find('\nend', i, true)
    assert(j, 'function ' .. name .. ' has no terminating end')
    return src:sub(i, j)
end

-- ---------------------------------------------------------------------------
-- The live member string. Read through the SAME parser the 开工自检 uses
-- (tools/agent/stale_waits.py: armed_ids), never re-typed here: a test that
-- carries its own copy of the arm string is a test that can agree with itself
-- while disagreeing with the waves.
-- ---------------------------------------------------------------------------
local armed_cache
local function armed()
    if armed_cache then return armed_cache end
    local cmd = "python3 -c \"import sys; sys.path.insert(0,'tools/agent'); "
        .. "from stale_waits import armed_ids; print(','.join(sorted(armed_ids())))\" 2>/dev/null"
    local p = assert(io.popen(cmd))
    local out = p:read('*a')
    p:close()
    out = (out or ''):gsub('%s+$', '')
    assert(out ~= '', 'could not read the armed member string from test_set.md')
    armed_cache = out
    return out
end

local function armed_has(id)
    for a in armed():gmatch('[^,]+') do
        if a == id then return true end
    end
    return false
end

-- ---------------------------------------------------------------------------
-- Source ratchets: the MECHANISM the reading is attributed to, parsed off the
-- shipped tree rather than written down here.
-- ---------------------------------------------------------------------------

tests['[ratchet][source] `fieldsip` is a clause of S, so arming it narrows stayfield2'] = function()
    local src = mask_comments(read(JMZ))
    local body = fn_body(src, 'J.ShouldRegenNotGoHome')
    assert(body:find('J.IsFieldSipEnough', 1, true),
        'J.ShouldRegenNotGoHome no longer calls J.IsFieldSipEnough -- the '
        .. 'mechanism this whole file attributes its reading to is gone, and '
        .. 'the reading has to be re-taken, not re-based')
    local sip = fn_body(src, 'J.IsFieldSipEnough')
    assert(sip:find("IsSoakCandidate%(%s*'fieldsip'%s*%)"),
        "J.IsFieldSipEnough is no longer gated on 'fieldsip'")
    -- ... and it is an EARLY-RETURN gate returning `true`, which is what makes
    -- the unarmed reading the three-clause one. A gate that returned false
    -- unarmed would invert the whole comparison in this file.
    assert(sip:find("IsSoakCandidate%(%s*'fieldsip'%s*%)%s*then%s*return%s+true"),
        'the fieldsip gate stopped being a `return true` early-out; unarmed S '
        .. 'is no longer the three-clause predicate the solo reading assumes')
end

tests['[ratchet][source] stayfield2 is the walk-leg wrapper and delegates to S'] = function()
    local src = mask_comments(read(JMZ))
    local body = fn_body(src, 'J.ShouldRegenNotWalkHome')
    assert(body:find("IsSoakCandidate%(%s*'stayfield2'%s*%)"),
        'J.ShouldRegenNotWalkHome is no longer gated on stayfield2')
    assert(body:find('J.ShouldRegenNotGoHome', 1, true),
        'J.ShouldRegenNotWalkHome no longer delegates to J.ShouldRegenNotGoHome, '
        .. 'so S is not its predicate and this reading is about the wrong thing')
end

tests['[ratchet][precondition] both ids are armed TODAY, or this reading is stale'] = function()
    -- The reading is a statement about a specific member string. If either id
    -- leaves it, the statement is not wrong -- it is about a world that no
    -- longer exists, and the honest response is to re-run the sweep, not to
    -- edit a number. Going red here is that instruction.
    assert(armed_has('stayfield2'),
        'stayfield2 left the member string; re-run tests/_stayfield2_livedomain_sweep.lua')
    assert(armed_has('fieldsip'),
        'fieldsip left the member string -- the narrowing mechanism is no longer '
        .. 'live and stayfield2 gets its 19-frame margin back; re-run the sweep')
end

-- ---------------------------------------------------------------------------
-- The sweep. Run in its OWN process via io.popen (charter 0q): driving the
-- whole corpus through shipped files inside the suite's own process makes the
-- cost depend on where the caller lands in the alphabet.
-- ---------------------------------------------------------------------------

local sweep_cache
local function sweep()
    if sweep_cache then return sweep_cache end
    local cmd = "lua5.1 tests/_stayfield2_livedomain_sweep.lua '" .. armed() .. "' 2>/dev/null"
    local p = assert(io.popen(cmd))
    local out = p:read('*a')
    p:close()
    assert(out and out ~= '', 'the sweep produced nothing')
    sweep_cache = out
    return out
end

local function line(out, key, pat)
    local v = out:match(key .. '%s+' .. pat)
    assert(v, 'the sweep did not report a ' .. key .. ' line: ' .. out)
    return v
end

tests['[recorded] the solo world reproduces the sibling file, so the difference is the WORLD'] = function()
    -- Not decoration. If the solo reading had moved too, the live reading would
    -- be explained by the corpus or by a behaviour change, and the claim of
    -- this file -- that arming is what emptied the domain -- would be unearned.
    local out = sweep()
    local s = tonumber(line(out, 'SOLO', 'frames=%d+ S=(%d+)'))
    local m = tonumber(line(out, 'SOLO', 'frames=%d+ S=%d+ T=%d+ margin=(%d+)'))
    cs.ratchet(s, SOLO_S, 'solo S (tests/test_stayfield2_marginal_domain.lua reads 24)')
    cs.ratchet(m, SOLO_MARGIN, 'solo margin (the sibling file reads 19)')
    local frames = tonumber(line(out, 'SOLO', 'frames=(%d+)'))
    cs.corpus(frames, 'live hero frames')
end

tests['[recorded] ⭐ on the live member string the marginal domain is EXACTLY zero'] = function()
    local out = sweep()
    local m = tonumber(line(out, 'LIVE', 'frames=%d+ S=%d+ T=%d+ margin=(%d+)'))
    assert(m == LIVE_MARGIN,
        'the live marginal domain of stayfield2 is no longer empty: ' .. m
        .. ' frame(s). That is a REAL CHANGE and the id may now have something '
        .. 'to do -- re-read before touching this number')
    -- The denominators, so the zero cannot be a vacuous one.
    local frames = tonumber(line(out, 'LIVE', 'frames=(%d+)'))
    cs.corpus(frames, 'live hero frames (LIVE leg)')
    local s = tonumber(line(out, 'LIVE', 'frames=%d+ S=(%d+)'))
    cs.ratchet(s, LIVE_S, 'live S frames')
    assert(s > 0,
        'S fires on no frame at all, so the zero margin says nothing about the '
        .. 'absorber and this file is measuring an empty corpus')
end

tests['[recorded] the emptying is ALL `fieldsip`, and none of it is the absorber'] = function()
    local out = sweep()
    local lost = tonumber(line(out, 'DELTA', 's_lost=(%d+)'))
    local gained = tonumber(line(out, 'DELTA', 's_lost=%d+ t_gained=(%d+)'))
    cs.ratchet(lost, S_LOST, 'S frames lost to the live string')
    assert(gained == T_GAINED,
        'the shipped ungated absorber now fires on ' .. gained .. ' frame(s) it '
        .. 'did not fire on in the solo world, so some armed id is moving T as '
        .. 'well and the attribution below is no longer exclusive')

    local sip = tonumber(line(out, 'WHYS', 'sip_killed=(%d+)'))
    local other = tonumber(line(out, 'WHYS', 'sip_killed=%d+ other=(%d+)'))
    assert(other == WHYS_OTHER,
        other .. ' of the lost S frames were taken by something OTHER than the '
        .. 'magnitude clause; the single-mechanism claim in this file is no '
        .. 'longer true and the reading has to name the second mechanism')
    assert(sip == lost,
        'attribution lost frames: ' .. sip .. ' attributed of ' .. lost .. ' lost')
end

tests['[recorded] every surviving S frame is already absorbed -- that is WHY the domain is empty'] = function()
    -- The zero above is a subtraction; this is the same fact read forwards, off
    -- the per-frame lines. A zero margin could in principle come from S firing
    -- nowhere; it does not -- S still fires, and the promoted veto owns every
    -- frame it fires on.
    local out = sweep()
    local nLive, nAbsorbed = 0, 0
    for f, hero, lS, lT in out:gmatch('FRAME (%S+) (%S+) solo_S=%d+ solo_T=%d+ live_S=(%d+) live_T=(%d+)') do
        if lS == '1' then
            nLive = nLive + 1
            if lT == '1' then nAbsorbed = nAbsorbed + 1
            else
                error('live S frame NOT absorbed: ' .. f .. ' ' .. hero
                    .. ' -- stayfield2 owns this frame and the domain is not empty')
            end
        end
    end
    assert(nLive > 0, 'no FRAME line carries live_S=1; the forward read is vacuous')
    assert(nAbsorbed == nLive, 'internal: counted ' .. nAbsorbed .. ' of ' .. nLive)
    local s = tonumber(line(out, 'LIVE', 'frames=%d+ S=(%d+)'))
    assert(nLive == s,
        'the per-frame lines and the LIVE counter disagree: ' .. nLive
        .. ' vs ' .. s .. ' -- one of the two is not counting what it says')
end

tests['[limit] this file rules on nobody'] = function()
    -- No id is admitted, returned, re-ranked or judged here, and no condition
    -- (a)/(b)/(c) is answered: an empty live domain is a READING handed to the
    -- director, not a verdict on `stayfield2`. Same guard, and same reason, as
    -- tests/test_stayfield2_marginal_domain.lua. Each needle is split so the
    -- list itself is not a match.
    local body = mask_comments(read('tests/test_stayfield2_live_domain.lua'))
    for _, halves in ipairs({ { 'prom', 'ote' }, { 'INDETER', 'MINATE' },
                              { 'WOR', 'KING' }, { 'SIL', 'ENT' } }) do
        local word = halves[1] .. halves[2]
        assert(body:find(word, 1, true) == nil,
            'a verdict vocabulary word entered the executable part of this '
            .. 'file: ' .. word)
    end
end

return tests

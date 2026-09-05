-- [ratchet] [mockscalar 2026-09-04, 协同组] The domain pricing for the WHOLE
-- `^Get -> 0` family, of which GH #492 priced exactly one member.
--
-- THE SUBJECT. tests/mock/bot_api.lua answers an unknown CamelCase method by
-- prefix: `^Is/Has/Can/Was` -> false, `^GetNearby` -> {}, then a catch-all
-- `^Get` -> 0. That last line is not a default, it is a TYPE CLAIM about every
-- engine getter the mock has not been told about. Measured on real fixture
-- units: shipped code under bots/ calls 197 distinct `Get*` names, and 166 of
-- them are answered by that catch-all on all 1012 live frames. The claim is
-- therefore load-bearing for most of the fixture route, not a corner of it.
--
-- ⭐ THE FINDING (reusable, larger than this subject).
-- A MOCK DEFAULT CAN BE REPAIRED INTO A CENSOR, because two defaults in the
-- same file cancel and the repair order between them is load-bearing.
--
-- Four shipped helpers in jmz_func.lua all do the same three lines:
--   `local nAbility = <unit>:GetCurrentActiveAbility()`
--   `if nAbility ~= nil then nAbility:GetBehavior() ...`
-- The catch-all answers 0; `0 ~= nil` is TRUE in Lua, so the nil guard passes
-- and the next line indexes a number. Today that never happens: `^Is -> false`
-- defaults (IsCastingAbility / IsUsingAbility / IsFacingLocation) stand in
-- front of every one of them, so all four answer cleanly. Lift those -- the
-- repair this mock's own history says is routine (HasModifier and the whole
-- WasRecentlyDamagedBy* family were repaired exactly that way, each with a
-- comment in replay_fixture.lua saying the old default "states a world
-- assumption nobody declared") -- and every one of them goes to ZERO answers.
-- Not one frame survives, in any of the four.
--
-- Per GH #492 a two-bucket sweep scores a raise as a measured "no" and deletes
-- those frames from its own denominator without saying so. So repairing the
-- `^Is` half FIRST does not surface new readings; it silently removes frames
-- from every census that drives these helpers. Repairing the `^Get` half first
-- cannot do that. ⇒ THE TWO REPAIRS ARE ORDERED, `^Get` BEFORE `^Is`.
-- That ordering constraint is the deliverable of this file, and it is what
-- turns the director's pending #492 ruling from "stub one method" into "stub
-- the roster, and stub it before touching the other prefix rule".
--
-- ⭐⭐ AND THE ROSTER IS NOT ONE NAME. Six shipped helpers consume such a zero;
-- driven on all 1012 live frames, in-domain / raise-today / raise-once-lifted:
--   J.CanEnemyInterruptTpChannel    257 |  257 |  257   (never answers today)
--   J.GetUltLoc                     503 |  503 |  503   (never answers today)
--   J.IsWillBeCastUnitTargetSpell   503 |    0 |  503   (masked)
--   J.IsWillBeCastPointSpell        503 |    0 |  503   (masked)
--   J.DidEnemyCastAbility           430 |    0 |  430   (masked)
--   J.IsCastingUltimateAbility     1012 |    0 | 1012   (masked)
-- After the `^Is` repair the "answers" column is ZERO on all six. The first row
-- reproduces #492's reading from a second, independent instrument (a
-- cross-check, not a second finding). The second is NEW and is the same shape
-- #492 called its sharpest edge: a SHIPPED, UNGATED helper that has never once
-- answered its own question on this corpus. J.GetUltLoc is live code --
-- bots/BotLib/hero_shredder.lua:524 calls it -- and its very first line,
-- `local v = target:GetVelocity()`, is handed the catch-all 0 and read as `v.x`.
-- The last row is the loudest: J.IsCastingUltimateAbility is in domain on EVERY
-- live frame, so that one repair alone converts 1012 clean answers into 1012
-- raises in a single step.
--
-- ⭐⭐⭐ WHY THE NON-SCALAR HALF IS DECIDED FROM bots/ AND NOT FROM THE API DOC.
-- docs/BOT_API_REFERENCE.md carries the director's provenance banner (GH #241):
-- a row there may describe intent but may NOT refute shipped code. So none of
-- the three names above is classified from a documented return type. Each is
-- classified from how the SHIPPED TREE ITSELF consumes the value -- `v.x` on
-- the result of GetVelocity, `:GetBehavior()` on the result of
-- GetCurrentActiveAbility, a location argument for GetExtrapolatedLocation.
-- Those consumption sites are asserted below as source facts, so a rewrite of
-- any of them turns this file red and the pricing gets re-read rather than
-- inherited.
--
-- ⇒ NOTHING IS REPAIRED HERE, deliberately, and no id is opened. The defect is
-- in the harness, not in bots/: in the real engine all three getters return
-- non-scalars, so there is no shipped behaviour to gate and no frame on which a
-- fixture could witness a change. Repairing the mock is a harness-wide move
-- that shifts readings for every helper that touches these names (the standing
-- example: tests/test_itemdesire_world_assertion.lua pins
-- `type(other:GetExtrapolatedLocation(0.5)) ~= 'table'` with a count of 178
-- resting on it), and backlog 0MOCKHOLE puts the mock with the director. This
-- file is the ratchet that prices the move and makes the day it happens visible.

package.path = 'tests/?.lua;' .. package.path
local cs = require('corpus_scale')

local SWEEP = 'lua5.1 tests/_mockscalar_sweep.lua'
local JMZ = 'bots/FunLib/jmz_func.lua'

local tests = {}

local function read_file(path)
    local f = assert(io.open(path, 'r'), path .. ' is not readable')
    local s = f:read('*a')
    f:close()
    return s
end

local M = (function()
    local p = assert(io.popen(SWEEP, 'r'))
    local raw = p:read('*a')
    p:close()
    local m = { c = {}, n = {}, r = {}, done = false }
    for line in raw:gmatch('[^\n]+') do
        local ck, cv = line:match('^C (%S+) (%-?%d+)$')
        if ck ~= nil then m.c[ck] = tonumber(cv) end
        local nn, a, b, d, e = line:match('^N (%S+) (%d+) (%d+) (%d+) (%S+)$')
        if nn ~= nil then
            m.n[nn] = { scalar0 = tonumber(a), other = tonumber(b),
                        raised = tonumber(d), exempt = (e == 'exempt') }
        end
        local rn, o1, r1, a1, o2, r2, a2 =
            line:match('^R (%S+) (%d+) (%d+) (%d+) (%d+) (%d+) (%d+)$')
        if rn ~= nil then
            m.r[rn] = { out_s = tonumber(o1), raise_s = tonumber(r1),
                        ans_s = tonumber(a1), out_l = tonumber(o2),
                        raise_l = tonumber(r2), ans_l = tonumber(a2) }
        end
        if line == 'DONE' then m.done = true end
    end
    return m
end)()

local function C(key)
    local n = M.c[key]
    assert(n ~= nil, 'the sweep did not emit counter ' .. key
        .. ' -- an absent counter is not a zero')
    return n
end

local function R(name)
    local r = M.r[name]
    assert(r ~= nil, 'the sweep did not emit a carrier row for ' .. name
        .. ' -- an absent row is not a clean carrier')
    return r
end

tests['[sweep] the subprocess ran to completion'] = function()
    assert(M.done, 'tests/_mockscalar_sweep.lua did not print DONE -- every '
        .. 'count below would be a partial sweep read as a finding')
    cs.corpus(C('fixtures'), 'fixture corpus')
    cs.ratchet(C('live'), 1012, 'live hero frames')
    cs.ratchet(C('probes'), 199364, 'getter probes on real units')
end

-- ------------------------------------------- the size of the type claim ----

tests['[census] the catch-all answers most of the shipped getter surface'] = function()
    -- Not a bug count -- a CEILING, and the reason this pricing was worth
    -- taking at all. `^Get -> 0` is not a rare fallback on this corpus; it is
    -- how most of the getter surface answers.
    cs.ratchet(C('candidates'), 197, 'distinct Get* names shipped code calls')
    assert(C('names_scalar0_always') > 0, 'no shipped getter is answered by the '
        .. 'catch-all any more -- the whole pricing below is stale, re-take it')
    -- 166 -> 165 on 2026-09-05 (director, GH #492), and the single name that
    -- left is GetExtrapolatedLocation: the fixture mock now answers it from the
    -- frame. `cs.ratchet` is deliberately one-directional and would refuse a
    -- fall, which is correct -- a fall means somebody acted on this file -- so
    -- the new floor is registered here by hand, with the reason, rather than by
    -- relaxing the ratchet.
    cs.ratchet(C('names_scalar0_always'), 165,
        'names the catch-all answers on EVERY live frame')
    assert(C('names_scalar0_any') >= C('names_scalar0_always'),
        'always-0 cannot exceed ever-0; the sweep is miscounting')
    -- The mock already steers five names away from the catch-all. Pinned so a
    -- sixth exception (i.e. somebody acting on this file) is a deliberate,
    -- visible act and never drift.
    assert(C('exempt') == 5, 'the mock now special-cases ' .. C('exempt')
        .. ' of the shipped getters away from `^Get -> 0`, not 5. If a name was '
        .. 'stubbed, say which in the report and re-take every count here')
    for _, name in ipairs({ 'GetLocation', 'GetIncomingTrackingProjectiles',
        'GetActualIncomingDamage' }) do
        assert(M.n[name] ~= nil and M.n[name].exempt,
            name .. ' is no longer parsed out of bot_api.lua as an exception '
            .. '-- the exempt roster this census subtracts is wrong')
    end
end

-- ------------------------- the non-scalar half, decided from bots/ only ----

tests['[source] the shipped tree itself proves the three returns non-scalar'] = function()
    -- docs/BOT_API_REFERENCE.md may not refute shipped code (GH #241), so the
    -- classification is taken from the consumption, in the tree, verbatim.
    local jmz = read_file(JMZ)
    -- GetVelocity -> Vector: divided, scaled, and indexed .x/.y two lines later.
    assert(jmz:find('local v = target:GetVelocity()', 1, true) ~= nil,
        'J.GetUltLoc no longer opens on target:GetVelocity() -- re-read the pricing')
    assert(jmz:find('local a = v.x * v.x + v.y * v.y - s * s', 1, true) ~= nil,
        'the .x/.y read of that value is gone -- GetVelocity may no longer be '
        .. 'proven non-scalar by the tree; re-price before trusting the row below')
    -- GetCurrentActiveAbility -> handle: nil-guarded, then method-called.
    local _, nGuard = jmz:gsub('local nAbility = %w+:GetCurrentActiveAbility%(%)', '')
    assert(nGuard == 4, 'expected the 4 shipped GetCurrentActiveAbility sites in '
        .. JMZ .. ', found ' .. nGuard .. ' -- the carrier roster moved. All four '
        .. 'read `local nAbility = <unit>:GetCurrentActiveAbility()` and then '
        .. '`if nAbility ~= nil`, and `0 ~= nil` is TRUE in Lua, so at none of '
        .. 'them is that nil guard a guard against the catch-all default')
    local _, nUse = jmz:gsub('nAbility:%w+%(%)', '')
    assert(nUse >= nGuard, 'the shipped tree method-calls that handle only '
        .. nUse .. ' time(s) across ' .. nGuard .. ' sites -- '
        .. 'GetCurrentActiveAbility may no longer be proven non-scalar here; '
        .. 're-price before trusting the carrier rows below')
    -- GetExtrapolatedLocation -> Vector: handed to a location-to-location helper.
    local _, nExt = jmz:gsub('J.GetLocationToLocationDistance%( vBotLoc, hEnemy:GetExtrapolatedLocation%( 0.5 %) %)', '')
    assert(nExt == 2, 'expected 2 shipped extrapolation sites in ' .. JMZ
        .. ', found ' .. nExt .. ' -- GH #492 rests on them')
    -- The one live caller that makes J.GetUltLoc shipped code and not dead code.
    local shr = read_file('bots/BotLib/hero_shredder.lua')
    assert(shr:find('J.GetUltLoc(bot, botTarget, nManaCost, nCastRange, nSpeed)',
        1, true) ~= nil, 'nothing calls J.GetUltLoc any more -- it became dead '
        .. 'code, which changes what its 503/503 raise means; re-read the pricing')
end

tests['[census] TWO of the three names are still answered by the catch-all'] = function()
    -- The static half above says "the tree needs a non-scalar here". This says
    -- "the mock hands it a scalar there". Neither alone is the finding.
    --
    -- ⭐ 2026-09-05 (director, GH #492): the roster is 3 names and ONE of them
    -- was repaired -- GetExtrapolatedLocation, in tests/mock/replay_fixture.lua
    -- (not in bot_api.lua, so `exempt` stays 5 and this file's exempt pin still
    -- holds). It is moved to its own leg below with its measured post-repair
    -- row. GetVelocity and GetCurrentActiveAbility are untouched and keep the
    -- pricing exactly as it was, which is the point of splitting rather than
    -- widening: this leg still says "a pure catch-all name", and it is still
    -- true of everything it names.
    --
    -- ⚠️ THE ORDERING CONSTRAINT IN THE FILE HEADER IS UNSPENT. `^Get` before
    -- `^Is` was the constraint, and only one `^Get` name has been repaired, so
    -- the `^Is` half must still wait -- for GetVelocity's sake, not for
    -- GetExtrapolatedLocation's. Repairing `^Is` today would take
    -- J.GetUltLoc's 503 in-domain frames from "raises" to "raises", but
    -- IsWillBeCast*/DidEnemyCastAbility/IsCastingUltimateAbility would go from
    -- 1436 clean answers to 1436 raises, and the two-bucket readers downstream
    -- would score every one of them as a measured "no".
    for _, name in ipairs({ 'GetVelocity', 'GetCurrentActiveAbility' }) do
        local row = M.n[name]
        assert(row ~= nil, name .. ' is no longer called by shipped code -- it '
            .. 'dropped out of the parsed candidate list; re-read the pricing')
        assert(not row.exempt, name .. ' is now special-cased in bot_api.lua. '
            .. 'That is the repair this file prices: re-take every count here '
            .. 'and say so in test_set.md before lowering anything')
        assert(row.other == 0 and row.raised == 0, name .. ' is now answered '
            .. 'from the frame on some units (' .. row.other .. ' other, '
            .. row.raised .. ' raise) -- it is no longer a pure catch-all name')
        assert(row.scalar0 == C('live'), name .. ' answers the catch-all 0 on '
            .. row.scalar0 .. ' of ' .. C('live') .. ' live frames, not all')
    end
end

tests['[census] the third name was repaired, and answers on every live frame'] = function()
    -- GH #492, executed by the director 2026-09-05. Measured here by the same
    -- sweep that used to price it as a catch-all name, so the two readings are
    -- comparable line for line (same corpus, same tree, the mock the only diff):
    --     scalar0  1012 -> 0     other  0 -> 1012     raised  0 -> 0
    local row = M.n['GetExtrapolatedLocation']
    assert(row ~= nil, 'GetExtrapolatedLocation dropped out of the shipped '
        .. 'candidate list -- nothing under bots/ extrapolates any more, and '
        .. 'the repair below has no consumer; re-read the pricing')
    assert(not row.exempt, 'GetExtrapolatedLocation is now special-cased in '
        .. 'bot_api.lua as well as in replay_fixture.lua. Two answers for one '
        .. 'name is how they drift; pick one and re-take every count here')
    assert(row.scalar0 == 0, 'GetExtrapolatedLocation still answers the '
        .. 'catch-all 0 on ' .. row.scalar0 .. ' frame(s) -- some unit kind the '
        .. 'fixture builds is not covered by the repair, so the censoring '
        .. 'survives on exactly those frames')
    assert(row.raised == 0, 'the repaired name now RAISES on ' .. row.raised
        .. ' frame(s)')
    assert(row.other == C('live'), 'GetExtrapolatedLocation answers from the '
        .. 'frame on ' .. row.other .. ' of ' .. C('live') .. ' live frames, '
        .. 'not all of them')
end

-- ------------------------------ carriers that never answer their question --

tests['[census] ONE shipped carrier has never answered on this corpus'] = function()
    -- ⭐ RE-PRICED 2026-09-05 (director, GH #492). This leg registered TWO
    -- carriers that had never once answered their own question on a real frame.
    -- One of them has been repaired and the other has not, and keeping them in
    -- one loop would have made the surviving finding look half-fixed when it is
    -- untouched. So they are split by WHY, not by count:
    --   J.CanEnemyInterruptTpChannel  raised because the fixture mock had no
    --     GetExtrapolatedLocation. Repaired on this commit; 257 in-domain
    --     frames, 0 raises, 257 answers. Priced in the leg below.
    --   J.GetUltLoc                   raises because the mock has no
    --     GetVelocity, and `local v = target:GetVelocity()` then reads `v.x`.
    --     UNTOUCHED: still 503 in-domain, 503 raises, 0 answers. Shipped,
    --     ungated (hero_shredder.lua calls it), and mute on every frame it can
    --     reach. That is now the whole of this finding.
    local r = R('GetUltLoc')
    assert(r.raise_s > 0, 'J.GetUltLoc no longer raises on any in-domain frame. '
        .. 'The mock was repaired, or the helper was: either way this pricing '
        .. 'is stale, re-take it -- and if GetVelocity was stubbed, the `^Get` '
        .. 'roster is now empty and the `^Is` half of the ordering constraint '
        .. 'in this file header is unblocked')
    assert(r.ans_s == 0, 'J.GetUltLoc answered on ' .. r.ans_s
        .. ' in-domain frame(s). It became witnessable: PRICE IT AGAIN, a '
        .. 'fix in it may have become landable with a real-frame fixture')
    assert(r.raise_s + r.ans_s > 0, 'J.GetUltLoc has an empty domain '
        .. 'on this corpus -- then "never answers" is vacuous, re-read')
    assert(C('carriers_never_answer') == 1, 'the sweep counts '
        .. C('carriers_never_answer') .. ' never-answering carriers, this file '
        .. 'names 1 -- one of the two lists moved without the other')
    cs.ratchet(r.raise_s, 503,
        'in-domain frames where J.GetUltLoc raises on target:GetVelocity()')
end

tests['[census] and the repaired carrier answers on all 257, from here too'] = function()
    -- The #492 reading, reproduced by a second instrument built for a different
    -- question. A cross-check, not a second finding: if this and
    -- tests/test_midsupmirror_checkability.lua diverge, one of the two censuses
    -- is measuring itself. Both are driven off the same 109-fixture corpus:
    --     raise_s  257 -> 0        ans_s  0 -> 257        out_s  755 -> 755
    local r = R('CanEnemyInterruptTpChannel')
    assert(r.raise_s == 0, 'the interrupt guard raises on ' .. r.raise_s
        .. ' in-domain frame(s) again -- the mock lost the repair, and the '
        .. 'two-bucket readers downstream are silently censoring once more')
    cs.ratchet(r.ans_s, 257, 'in-domain frames where the interrupt guard answers')
    assert(r.out_s == C('live') - r.ans_s - r.raise_s,
        'the interrupt guard rows do not sum to the live frames -- the '
        .. 'three-valued split is leaking')
end

-- --------------------------------------------- the ordering constraint ----

tests['[census] two more carriers are MASKED, so the repair order matters'] = function()
    local names = { 'IsWillBeCastUnitTargetSpell', 'IsWillBeCastPointSpell',
        'DidEnemyCastAbility', 'IsCastingUltimateAbility' }
    local n = 0
    for _, name in ipairs(names) do
        local r = R(name)
        -- Today: clean, on every frame it can reach.
        assert(r.raise_s == 0, 'J.' .. name .. ' already raises on '
            .. r.raise_s .. ' frame(s) today -- it is no longer MASKED but '
            .. 'openly broken, which is a different (louder) finding; re-read')
        assert(r.ans_s > 0, 'J.' .. name .. ' has no in-domain frame to answer '
            .. 'on -- then the masking claim below is vacuous, re-read')
        -- With the three `^Is -> false` gates lifted: not one frame survives.
        -- Asserted as ans_l == 0, not merely raise_l > 0: "masked" must not be
        -- satisfiable by a single frame flipping.
        assert(r.ans_l == 0, 'J.' .. name .. ' still answers on ' .. r.ans_l
            .. ' frame(s) with the `^Is` gates lifted. The masking is now '
            .. 'PARTIAL, so the repair order is no longer forced by this row: '
            .. 're-read the pricing before quoting the ordering constraint')
        assert(r.raise_l == r.ans_s, 'lifting the gates turned ' .. r.raise_l
            .. ' frames into raises but ' .. r.ans_s .. ' answered before -- '
            .. 'the two legs are not being driven over the same domain')
        assert(r.out_l == r.out_s, 'the domain itself moved between the two '
            .. 'legs; the lifted leg is not a comparison any more')
        n = n + 1
    end
    assert(C('carriers_masked') == n, 'the sweep counts ' .. C('carriers_masked')
        .. ' masked carriers, this file names ' .. n)
    cs.ratchet(R('IsWillBeCastUnitTargetSpell').raise_l, 503,
        'frames that would raise once the `^Is` gates are repaired')
    cs.ratchet(R('DidEnemyCastAbility').raise_l, 430,
        'DidEnemyCastAbility frames that would raise after the same repair')
    -- The loudest row in the file: this carrier is in domain on EVERY live
    -- frame (its own gate is the subject's CanBeSeen, which the frame answers),
    -- so the repair takes 1012 clean answers to 1012 raises in one step.
    assert(R('IsCastingUltimateAbility').out_s == 0,
        'J.IsCastingUltimateAbility is no longer in domain on every live frame ('
        .. R('IsCastingUltimateAbility').out_s .. ' out) -- re-read the pricing')
    cs.ratchet(R('IsCastingUltimateAbility').raise_l, 1012,
        'frames that would raise inside the ultimate check after the repair')
end

tests['[premise] the mask is the `^Is` default, not the corpus'] = function()
    -- Two of the masked carriers scan with the same radius and share the same
    -- three gates, so their domains must coincide exactly. If they ever differ,
    -- something other than the gates is deciding which frames get through and
    -- the one-line story above is wrong.
    local a = R('IsWillBeCastUnitTargetSpell')
    local b = R('IsWillBeCastPointSpell')
    assert(a.out_s == b.out_s and a.ans_s == b.ans_s and a.raise_l == b.raise_l,
        'the two masked carriers no longer see the same domain ('
        .. a.ans_s .. ' vs ' .. b.ans_s .. ' in-domain answers) -- something '
        .. 'besides the shared `^Is` gates is filtering frames; re-read')
    -- And the gate names this file blames are the ones the tree actually reads.
    local jmz = read_file(JMZ)
    for _, gate in ipairs({ 'IsCastingAbility', 'IsUsingAbility',
        'IsFacingLocation' }) do
        assert(jmz:find('npcEnemy:' .. gate, 1, true) ~= nil,
            'the shipped carriers no longer gate on ' .. gate
            .. ' -- tests/_mockscalar_sweep.lua lifts a gate that is not there, '
            .. 'so its lifted leg is measuring something else')
    end
end

return tests

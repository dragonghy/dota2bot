-- [ratchet] GH #304 -- the scope ruling for `blinkflee`, pinned.
--
-- GH #304 reported that X.ConsiderItemDesire['item_blink'] has four branches
-- that blink toward the bot's own ancient and only one of them (the retreat
-- leg) is gated by `blinkflee`; it asked strategy to pick option (A) put the
-- same guard on the `J.IsProjectileIncoming(bot, 1200)` branch under a new id,
-- or option (B) rule the projectile dodge a legitimate use and say so in the
-- helper's comment.
--
-- Ruled (B). This file is the ruling's tripwire: it pins the two source facts
-- the ruling rests on and the corpus arithmetic that decided it, so a later
-- round cannot quietly gate that branch without coming back through here.
--
-- Why (B), in one line of arithmetic: `and not J.ShouldHoldBlinkFlee(bot)`
-- permits the blink exactly when `hp < 0.70 OR WasRecentlyDamagedByAnyHero(2.0)`.
-- Both disjuncts look BACKWARD. The branch they would gate is triggered by a
-- dodgeable enemy spell still in FLIGHT -- damage that has not landed -- so on
-- a first-strike frame the backward window is empty *because* the threat is
-- still incoming, and the guard fires against precisely the case the branch
-- exists for. Section 3 puts a number on that half of the corpus.
--
-- ⭐ The second finding, and the reason (A) could not simply be written as
-- suggested: `J.ShouldHoldBlinkFlee` carries `J.IsSoakCandidate('blinkflee')`
-- in its own body. A helper with a gate inside it IS a conjunction, so putting
-- it at a new site under a new id `blinkproj` makes the new lever
-- `blinkproj AND blinkflee` -- an isolation wave arming only `blinkproj`
-- measures a no-op, and check_armed_wiring.py still calls it WIRED (it checks
-- that a call site exists, not that the predicate can be true). This is the
-- `pullcad` family (AGENTS.md), but pullcad's discriminator -- "grep the id
-- for appearances in OTHER gates' conditions" -- is BLIND to it: the second id
-- appears nowhere in the new gate's text, only inside the callee's body, and
-- the damage lands on the isolation wave rather than on a promote. The cheap
-- discriminator is in section 2: for every helper used as a guard, grep the
-- CALLEE's body for IsSoakCandidate. In this tree that set is 50+ helpers and
-- the pattern is already realized once -- `J.ShouldFieldBuyRegen` ('fieldbuy')
-- calls `J.IsFieldSipEnough` ('fieldsip') -- where it is safe only because the
-- inner helper's unarmed value is `true`, the neutral element of the
-- conjunction it sits in. `ShouldHoldBlinkFlee`'s unarmed value is `false`
-- under a `not`, which is neutral for the SHIPPED tree (that is why (A) would
-- be inert) but not for the new id.
--
-- Honest boundaries, stated once:
--   * zero behaviour change and zero new gate id -- `bots/` carries a comment
--     only, `game/` is untouched;
--   * section 3 reads the fixture corpus, not Dota. It is 431 live hero frames
--     drawn from the 47 fixtures that carry a real backward damage window
--     (`recent_window = 6.0`); the other 60 fixtures cannot answer
--     WasRecentlyDamagedByAnyHero at all and are excluded, not counted as calm;
--   * the joint frame the ruling is really about (backward-quiet AND a
--     projectile inbound) is NOT in the corpus and cannot be: the dump carries
--     no projectile stream, so J.IsProjectileIncoming is false on all 993 live
--     hero frames. Section 3's `[limit]` asserts that zero rather than leaving
--     it implied. GH #305 asks the harness for the stream; until it lands, the
--     selection effect argued above is a claim, not a measurement.

package.path = 'tests/?.lua;' .. package.path

-- Every count in section 3 is a SUM OVER FIXTURES, so it may only rise as the
-- corpus grows. They go through tests/corpus_scale.lua rather than being pinned
-- with `==` (GH #106 / GH #127: eighteen assertions across seven files went red
-- at once for a single landed fixture, and none of the eighteen was about what
-- its test measures). The claims whose whole content is a ZERO stay equalities,
-- which is exactly what that module says to do: they are already growth-immune
-- and they are what several verdicts here are argued from.
local cs = require('corpus_scale')

local tests = {}

-- ---------------------------------------------------------------------------
-- helpers

local function read(path)
    local f = assert(io.open(path, 'r'), 'cannot open ' .. path)
    local s = f:read('*a')
    f:close()
    return s
end

-- Strip Lua line comments. Last round (GH #300) a pure-comment line that
-- merely QUOTED a call expression was counted by a sibling census as a third
-- call site, turning a zero-call-site change red; and the round before that,
-- 14 comment lines shifted two line pins. A source census that counts code
-- must look at code.
local function strip_comments(src)
    local out = {}
    for line in (src .. '\n'):gmatch('([^\n]*)\n') do
        out[#out + 1] = line:gsub('%-%-.*$', '')
    end
    return table.concat(out, '\n')
end

local function count(hay, needle)
    local n, at = 0, 1
    while true do
        local s = hay:find(needle, at, true)
        if s == nil then return n end
        n = n + 1
        at = s + 1
    end
end

local JMZ = read('bots/FunLib/jmz_func.lua')
local GEN = read('bots/ability_item_usage_generic.lua')
local JMZ_CODE = strip_comments(JMZ)
local GEN_CODE = strip_comments(GEN)

local function blink_branch()
    local b = GEN_CODE:match('X%.ConsiderItemDesire%["item_blink"%].-\n end')
        or GEN_CODE:match('X%.ConsiderItemDesire%["item_blink"%].-\nend')
        or GEN_CODE:match("X%.ConsiderItemDesire%['item_blink'%].-\n end")
        or GEN_CODE:match("X%.ConsiderItemDesire%['item_blink'%].-\nend")
    assert(b, 'could not locate the item_blink consider function')
    return b
end

-- ---------------------------------------------------------------------------
-- 1. the source facts the ruling is about

tests['[source] the projectile branch is still ungated, and lands homeward'] = function()
    local branch = blink_branch()
    local proj = branch:match('J%.IsProjectileIncoming%( *bot, *1200 *%).-\n')
    assert(proj, 'the IsProjectileIncoming(bot, 1200) branch is gone -- if it '
        .. 'was removed or rewritten, GH #304 option (B) has to be re-read')

    -- The whole branch body, from its trigger to its HIGH return.
    local body = branch:match('(J%.IsProjectileIncoming%( *bot, *1200 *%).-BOT_ACTION_DESIRE_HIGH[^\n]*)')
    assert(body, 'could not read the projectile branch through to its return')
    assert(body:find('GetAncient', 1, true),
        'the projectile branch no longer lands toward our own ancient')
    assert(body:find('1199', 1, true),
        'the projectile branch no longer uses the 1199 landing distance')
    -- Option (B) IS the absence of a guard here. If anyone adds one, this test
    -- is the place the ruling gets revisited.
    assert(not body:find('IsSoakCandidate', 1, true)
        and not body:find('ShouldHold', 1, true),
        'the projectile branch has acquired a gate -- GH #304 was ruled (B) '
        .. '(dodge is a legitimate blink use); reopen the ruling before gating it')
end

tests['[source] blinkflee has exactly one call site, on the retreat leg'] = function()
    -- Scope of the ruling: one leg, not the consider function.
    local n = 0
    for _, path in ipairs({ 'bots/ability_item_usage_generic.lua' }) do
        n = n + count(strip_comments(read(path)), 'J.ShouldHoldBlinkFlee(')
    end
    assert(n == 1, 'expected exactly 1 call site of J.ShouldHoldBlinkFlee, saw ' .. n)

    local branch = blink_branch()
    local retreat_at = branch:find('J.IsRetreating(bot)', 1, true)
    local guard_at = branch:find('ShouldHoldBlinkFlee', 1, true)
    local proj_at = branch:find('J.IsProjectileIncoming', 1, true)
    assert(retreat_at and guard_at and proj_at, 'the three anchors must all exist')
    assert(retreat_at < guard_at and guard_at < proj_at,
        'the guard must sit in the retreat branch, ABOVE the projectile branch '
        .. '-- the projectile branch is reached only when the retreat branch did not return')
end

tests['[source] the projectile branch is a dodge, not a leg'] = function()
    -- The load-bearing half of reason (1) in the ruling: the trigger requires
    -- a dodgeable, non-attack, enemy projectile. A tower shot or an auto
    -- attack cannot arm it, so it is not the "burned as a leg" shape GH #71
    -- legislated against.
    local fn = JMZ_CODE:match('function J%.IsProjectileIncoming.-\nend')
    assert(fn, 'J.IsProjectileIncoming is gone')
    assert(fn:find('p.is_dodgeable', 1, true), 'the dodgeable clause is gone')
    assert(fn:find('not p.is_attack', 1, true), 'the not-an-attack clause is gone')
    assert(fn:find("p.caster:GetTeam() ~= GetTeam()", 1, true),
        'the enemy-caster clause is gone -- an ally projectile would arm the branch')
end

tests['[source] the ruling is written where the next reader will look'] = function()
    -- Option (B)'s deliverable per GH #304: the helper's comment must say the
    -- scope out loud, because it previously read as if it covered "blink burned
    -- as a leg" in general.
    local head = JMZ:match('(.-)function J%.ShouldHoldBlinkFlee')
    assert(head, 'J.ShouldHoldBlinkFlee is gone')
    head = head:sub(-4000)
    assert(head:find('#304', 1, true), 'the scope ruling must cite GH #304')
    assert(head:find('IsProjectileIncoming', 1, true),
        'the comment must name the branch it deliberately does not cover')
    assert(head:find('#305', 1, true),
        'the comment must name the harness gap that keeps the joint frame unbuyable')
end

-- ---------------------------------------------------------------------------
-- 2. the hidden-gate class -- why (A) could not be written as suggested

local function helpers_with_own_gate(src_code)
    -- Walk top-level `function J.Name(` .. `\nend` blocks and report those
    -- whose BODY contains an IsSoakCandidate call. Comment-stripped, so a
    -- comment quoting the call cannot manufacture a member.
    local found, order = {}, {}
    for name, body in src_code:gmatch('\nfunction (J%.[%w_]+)%s*%(.-%)(.-)\nend\n') do
        if body:find('IsSoakCandidate', 1, true) and found[name] == nil then
            found[name] = true
            order[#order + 1] = name
        end
    end
    return found, order
end

tests['[census] the hidden-gate class is large, and blinkflee is in it'] = function()
    local found, order = helpers_with_own_gate('\n' .. JMZ_CODE .. '\n')
    -- A LOWER bound, not an equality: GH #273's lesson is that an `eq` on a
    -- quantity whose own definition is "goes up when we add a gated helper"
    -- turns compliant work red, while staying blind to a parser that silently
    -- drops members. The floor is what the argument needs.
    assert(#order >= 40, 'expected at least 40 helpers carrying their own gate, '
        .. 'saw ' .. #order .. ' -- if this collapsed, the parser broke, not the tree')
    assert(found['J.ShouldHoldBlinkFlee'],
        'J.ShouldHoldBlinkFlee must carry its own gate -- the whole (A) analysis '
        .. 'rests on it; if the gate moved out, GH #304 (A) becomes writable')
    assert(found['J.IsFieldSipEnough'],
        'J.IsFieldSipEnough must carry its own gate -- it is the realized instance')
end

tests['[census] the realized instance: fieldbuy calls the fieldsip-gated helper'] = function()
    -- Existence proof that the hazard is not hypothetical, plus the property
    -- that makes THAT instance safe: the inner helper's unarmed value is the
    -- neutral element of the conjunction it sits in.
    local buy = JMZ_CODE:match('function J%.ShouldFieldBuyRegen.-\nend')
    assert(buy, 'J.ShouldFieldBuyRegen is gone')
    assert(buy:find("J.IsSoakCandidate( 'fieldbuy' )", 1, true),
        'ShouldFieldBuyRegen must still be gated by fieldbuy')
    assert(buy:find('J.IsFieldSipEnough(', 1, true),
        'ShouldFieldBuyRegen must still call the fieldsip-gated helper')

    local sip = JMZ_CODE:match('function J%.IsFieldSipEnough.-\nend')
    assert(sip, 'J.IsFieldSipEnough is gone')
    -- Unarmed it must be the LITERAL true, on the first line that can return:
    -- that is exactly what keeps `fieldbuy` alone byte-identical to shipped.
    local first = sip:match("IsSoakCandidate%( 'fieldsip' %) then return (%a+) end")
    assert(first == 'true', "IsFieldSipEnough's unarmed value must be the literal "
        .. 'true (the neutral element of `A and IsFieldSipEnough`), saw '
        .. tostring(first))

    -- And the contrast that decided GH #304: blinkflee's unarmed value is
    -- false, neutral under the `not` at its shipped call site -- which is why
    -- an option-(A) site under a new id would be inert until BOTH are armed.
    local flee = JMZ_CODE:match('function J%.ShouldHoldBlinkFlee.-\nend')
    assert(flee, 'J.ShouldHoldBlinkFlee is gone')
    local unarmed = flee:match("IsSoakCandidate%( 'blinkflee' %) then return (%a+) end")
    assert(unarmed == 'false', "ShouldHoldBlinkFlee's unarmed value must be false, saw "
        .. tostring(unarmed))
end

-- ---------------------------------------------------------------------------
-- 3. the corpus arithmetic (subprocess sweep -- see tests/_blinkproj_sweep.lua)

local manifest
local function sweep()
    if manifest ~= nil then return manifest end
    local p = assert(io.popen('lua5.1 tests/_blinkproj_sweep.lua 2>/dev/null'))
    local raw = p:read('*a')
    p:close()
    assert(raw:find('\nDONE\n') or raw:find('^DONE\n'),
        'the sweep subprocess did not finish (no DONE line) -- a partial '
        .. 'manifest must never be read as a measured zero')
    local m = { c = setmetatable({}, { __index = function() return nil end }), grid = {} }
    for line in raw:gmatch('([^\n]+)') do
        local k, v = line:match('^C (%S+) (%-?%d+)$')
        if k then m.c[k] = tonumber(v) end
        local t, n = line:match('^GRID (%d+) (%d+)$')
        if t then m.grid[tonumber(t)] = tonumber(n) end
    end
    manifest = m
    return m
end

tests['[census] the denominator, declared'] = function()
    local m = sweep()
    cs.corpus(m.c.fixtures, 'blinkproj sweep corpus')
    cs.ratchet(m.c.live, 993, 'live hero frames')
    -- The population the damage clause can actually be read on.
    cs.ratchet(m.c.fixtures_v2, 47, 'fixtures carrying a backward damage window')
    cs.ratchet(m.c.v2_live, 431, 'v2 live hero frames')
    -- A hero whose history the generator refused to reconstruct reads calm for
    -- the wrong reason; those are excluded. This one stays an EQUALITY: its
    -- whole content is a zero, it is growth-immune, and every v2_* reading
    -- below is argued from "nothing was silently counted as calm".
    assert(m.c.v2_ambiguous == 0, 'ambiguous rows appeared: ' .. tostring(m.c.v2_ambiguous))
    assert(m.c.v2_live + m.c.v2_ambiguous <= m.c.live, 'v2 subset must be a subset')
end

tests['[census] the hold policy IS the two clauses, on real frames'] = function()
    local m = sweep()
    -- Everything below reasons about `hp >= 0.70 and not damaged(2.0)`. These
    -- counters are zero-initialised in the sweep, so an absent key cannot pass
    -- as a measured zero (the GH #171 shape).
    assert(m.c.IMPOSSIBLE_hold_without_hp == 0, 'hold fired under 70% HP')
    assert(m.c.IMPOSSIBLE_hold_with_damage == 0, 'hold fired with fresh hero damage')
    assert(m.c.IMPOSSIBLE_hold_not_quiet == 0,
        'hold and the reconstructed conjunction disagreed -- the helper drifted '
        .. 'away from the two clauses this ruling reasons about')
    assert(m.c.v2_hold == m.c.v2_quiet, 'hold and quiet must be the same set')
end

tests['[gate] unarmed, the helper is inert on every frame in the corpus'] = function()
    local m = sweep()
    assert(m.c.unarmed_hold == 0, 'the unarmed helper held a blink somewhere')
    assert(m.c.IMPOSSIBLE_unarmed_hold == 0, 'the unarmed helper held on a v2 frame')
end

tests['[magnitude] option (A) would hold the dagger on most of the corpus'] = function()
    local m = sweep()
    cs.ratchet(m.c.v2_hold, 275, 'the suppression domain option (A) would impose')
    -- 275/431 = 63.8%, reported as a share of a declared denominator rather
    -- than as a median of a small-valued integer count (铁律 4(ii)).
    cs.share(m.c.v2_hold, m.c.v2_live, 0.60, 0.68,
        'share of live hero frames option (A) would hold the dagger on', 400)
    -- Both disjuncts of the permitting side are backward-looking, and the
    -- damage half is the smaller one: 80/431 = 18.6% of frames had been hit by
    -- a hero inside 2.0s at all, so 81.4% of the corpus is backward-quiet.
    cs.ratchet(m.c.v2_dmg2, 80, 'frames hit by a hero inside 2.0s')
    cs.share(m.c.v2_dmg2, m.c.v2_live, 0.14, 0.24, 'recently-damaged share', 400)
    cs.ratchet(m.c.v2_hp_ge70, 314, 'frames at or above the 0.70 HP floor')
    -- Structural, not a remembered difference: the permitted side is exactly
    -- the complement of the held side. Growth-invariant, so it stays an
    -- equality.
    assert(m.c.v2_hold + (m.c.v2_live - m.c.v2_hold) == m.c.v2_live,
        'the permitted side must be the complement of the held side')
    assert(m.c.v2_hold < m.c.v2_hp_ge70,
        'the damage clause must remove something from the healthy population, '
        .. 'otherwise it is doing no work and the [axis] reading is vacuous')
end

tests['[axis] the suppression is not an artifact of the 0.70 constant'] = function()
    local m = sweep()
    -- Sweep the HP clause across its whole plausible range with the damage
    -- clause left alone. If the reading collapsed at some threshold, (A) could
    -- be rescued by moving the number; it does not.
    local lo, hi
    for t = 100, 1000, 25 do
        local n = m.grid[t]
        assert(n ~= nil, 'grid point missing at ' .. t)
        if lo == nil or n < lo then lo = n end
        if hi == nil or n > hi then hi = n end
    end
    cs.ratchet(lo, 174, 'the floor of the suppression domain across the HP grid')
    cs.ratchet(hi, 348, 'the ceiling of the suppression domain across the HP grid')
    -- Even at hp >= 1.00 -- a bot at literally full health -- 40% of the corpus
    -- is still held, because the damage window is doing the work.
    cs.ratchet(m.grid[1000], 174, 'the full-health point of the grid')
    assert(lo / m.c.v2_live > 0.35,
        'the floor of the suppression domain dropped below a third of the corpus; '
        .. 'if that happens the "not an artifact of 0.70" argument needs re-reading')
end

tests['[boundary] how far the damage window can move before the reading does'] = function()
    local m = sweep()
    -- Registered because the first mutation battery recorded a false survivor
    -- here: a `2.0 -> 5.0` patch applied by first-occurrence string replace
    -- landed on a DIFFERENT helper 2400 lines up (that exact line appears many
    -- times in jmz_func), so "the mutation survived" was really "the mutation
    -- was never applied". The reading below is what the corpus actually says.
    cs.ratchet(m.c.v2_dmg5, 112, 'frames hit by a hero inside 5.0s')
    cs.ratchet(m.c.v2_dmg_between_2_and_5, 32,
        'frames whose freshest hero damage is aged (2.0, 5.0]')
    -- So the window IS load-bearing, and by a measurable amount: widening it
    -- to 5.0 shrinks the suppression domain from 275 to 261.
    cs.ratchet(m.c.v2_quiet5, 261, 'the suppression domain under a 5.0 window')
    assert(m.c.v2_quiet5 < m.c.v2_quiet,
        'widening the damage window must SHRINK the suppression domain; if these '
        .. 'became equal the corpus can no longer pin the 2.0 constant and the '
        .. '[source] pin is the only thing holding it')
    -- Even at the widest window tried, the ruling's conclusion is unchanged:
    -- most of the corpus is still in the backward-quiet half.
    assert(m.c.v2_quiet5 / m.c.v2_live > 0.55,
        'widening the window to 5.0 dropped the suppression domain below 55% -- '
        .. 'the "(A) inverts the guard" argument needs re-reading at that point')
end

tests['[source] the two shipped constants the ruling reasons about'] = function()
    -- Pinned at the source, inside the helper body, because the corpus alone
    -- cannot: see [boundary]. Anchored to the function so the pin cannot drift
    -- onto one of the ~20 other `WasRecentlyDamagedByAnyHero( 2.0 )` lines in
    -- this file -- the exact drift that produced the false survivor above.
    local body = JMZ_CODE:match('function J%.ShouldHoldBlinkFlee.-\nend')
    assert(body, 'J.ShouldHoldBlinkFlee is gone')
    assert(body:find('/ nMax < 0.70 then return false end', 1, true),
        'the 0.70 HP floor moved -- every percentage in the GH #304 ruling is '
        .. 'computed against it')
    assert(body:find('WasRecentlyDamagedByAnyHero( 2.0 )', 1, true),
        'the 2.0 backward damage window moved -- it is the load-bearing half '
        .. 'of the ruling (see [axis]); update the ruling, do not just re-pin')
end

tests['[limit] the joint frame is not in the corpus and cannot be'] = function()
    local m = sweep()
    -- The frame the ruling is really about is "backward-quiet AND a dodgeable
    -- enemy spell inbound". The dump carries no projectile stream, so the mock
    -- answers {} at every call site and the trigger is false everywhere. This
    -- is asserted, not left implied: it is the reason no fixture can settle
    -- GH #304 either way today, and the reason GH #305 exists.
    assert(m.c.proj_incoming == 0,
        'a fixture frame reported an incoming projectile -- if the dumper '
        .. 'started emitting them (GH #305), the joint frame is now pinnable '
        .. 'and GH #304 can be settled on evidence instead of arithmetic')
end

return tests

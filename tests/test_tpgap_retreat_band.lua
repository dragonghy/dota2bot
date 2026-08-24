-- [GH #159] soak candidate 'tpgap' -- the RETREAT-branch TP band that neither
-- promoted guard covers, pinned on real frames.
--
-- THE HOLE (replay-check, W4 208 games then independently replicated on W7's
-- 207 games): ~12.5% of all TP presses happen with an enemy hero already inside
-- its own attack reach, and those die inside the channel window at 15.6-17.2%
-- against a 3.9% base -- a ~4x lift.  The mechanism is not a broken guard, it
-- is two guards whose domains do not meet:
--
--     tpsafe  J.ShouldWalkNotTp               -- runs on retreat, first
--                                                predicate is "enemy within 350"
--     tpsafe2 J.ShouldNotStartInterruptibleTp -- scans 700, but its only call
--                                                site is scoped nMode ~= RETREAT
--
-- => in retreat, a nearest enemy in (350, 700] is refused by neither.  W7 puts
-- 58.6% of the on-face presses (790 of 1348) in exactly that band, at a 15.7%
-- fatality rate against 2.3% for presses with nobody near.
--
-- WHAT THIS FILE IS FOR.  The obvious fix -- issue #159 §6's first option,
-- "let the retreat branch run the 700 veto too" -- is REFUTED here by a real
-- frame with ground truth, and the refutation is the load-bearing test in this
-- file, not the new guard.  On f_260819_222030_jugg_tp_start the juggernaut
-- presses a retreat TP with Lich 477u away (squarely in the gap band) and
-- J.CanEnemyInterruptTpChannel answers TRUE -- yet the fixture's observed block
-- says the channel COMPLETED and he lived another 105.9 seconds.  Aligning the
-- radii would have refused that escape.  A retreat TP is a LAST RESORT: every
-- press it wrongly refuses is paid for in a life.
--
-- So 'tpgap' refuses a strict subset instead: only the presses where standing
-- still is ALREADY lethal -- the visible band enemies' estimated damage over the
-- ~3s channel already covers current health, so the channel cannot save us and
-- only guarantees we are stationary while it fails.
--
-- DECLARED, NOT MEASURED (both directions asserted below so a harness upgrade
-- turns them red instead of silently changing what these tests mean):
--   * attack ranges -- GetAttackRange answers the mock default 150 on every
--     fixture hero (GH #145), so the reach leg is dead inside 300u, strictly
--     BELOW the band.  The juggernaut test declares Lich's real 500.
--   * extrapolation -- the dumper captures no velocities.  Declared stationary,
--     which is conservative: it switches OFF the "closing the gap" leg, so any
--     TRUE left comes from reach alone.
--   * the channel window -- the mock's GetEstimatedDamageToTarget is
--     duration-INSENSITIVE (it replays observed burst whatever you ask for), so
--     the shipped 3.0s narrowing is NOT locally measurable.  Asserted as such.

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')

local tests = {}

-- The pin: lion at 43% hp with Lich 676u out -- in the band, out of tpsafe's
-- reach -- and Lich's observed burst (436) already covers her 354 health.
local F_LION = 'tests/fixtures/f_222428_lion_lich_burst.lua'
-- The counterexample that rules out simply aligning the two radii.
local F_JUGG = 'tests/fixtures/f_260819_222030_jugg_tp_start.lua'
-- tpsafe's own turf: an enemy inside 350, and lethal burst on top.
local F_ONFACE = 'tests/fixtures/f_260819_183409_lion_drain_focused.lua'

local LICH_ATTACK_RANGE = 500   -- real ranged value; the mock answers 150

--- Load a fixture with (turbo, gate) freely armed, extrapolation declared
--- stationary on every hero.
local function load_fx(path, opts)
    opts = opts or {}
    local J, bot, heroes, fx = rf.load(path)
    J.IsModeTurbo = function() return opts.turbo ~= false end
    J.IsSoakCandidate = function(id)
        return opts.armed == true and id == 'tpgap'
    end
    for _, h in pairs(heroes) do
        local sp = rawget(h, '__spec')
        if sp ~= nil then sp.GetExtrapolatedLocation = h:GetLocation() end
    end
    return J, bot, heroes, fx
end

local function dist(a, b)
    local la, lb = a:GetLocation(), b:GetLocation()
    return math.sqrt((la.x - lb.x) ^ 2 + (la.y - lb.y) ^ 2)
end

-- ---------------------------------------------------------------------------
-- 1. The frame the guard exists for.
-- ---------------------------------------------------------------------------

tests['the pinned frame really is in the gap: nearest enemy 676u, nobody inside 350'] = function()
    local J, bot, heroes = load_fx(F_LION, { armed = true })
    local nLich = dist(bot, heroes['npc_dota_hero_lich'])
    assert(nLich > 350 and nLich < 700,
        ('the pin is only interesting inside (350,700]; Lich reads %.0f'):format(nLich))
    assert(#(J.GetNearbyHeroes(bot, 350, true, BOT_MODE_NONE) or {}) == 0,
        'if anything were inside 350 this frame would belong to tpsafe, not here')
    assert(#(J.GetNearbyHeroes(bot, 700, true, BOT_MODE_NONE) or {}) == 1,
        'exactly one enemy in the band -- Axe sits at ~741u, outside it')
end

tests['armed: standing still is lethal here, so the retreat TP is refused'] = function()
    local J, bot = load_fx(F_LION, { armed = true })
    assert(J.ShouldNotTpUnderLethalPressure(bot) == true,
        'lion 354/823 with a band burst of 436 on her: a 3s channel cannot finish')
end

tests['the lethality is ground truth, not an invented number'] = function()
    local _, bot, _, fx = load_fx(F_LION, { armed = true })
    assert(fx.observed.burst['npc_dota_hero_lich'] >= bot:GetHealth(),
        'the mock replays what Lich ACTUALLY dealt; that is what crosses the bar')
    -- HONEST BOUNDARY, stated so nobody reads more out of this pin than it
    -- holds: this fixture's observed window is 8.0s and the hero died at +6.9s,
    -- i.e. AFTER a ~3s channel would have landed.  The corpus therefore proves
    -- the predicate FIRES on a real lethal-pressure frame; it does NOT prove
    -- this particular press would have died mid-channel.  The frames that can
    -- prove that (W7 drow_ranger t=281.3, dead 2.5s into the channel) are not
    -- in tests/fixtures yet -- requested from replay-check in the report.
    assert(fx.window > 3.0 and fx.observed.died_after > 3.0,
        'if a future fixture makes this window <= the channel, re-read the pin')
end

-- ---------------------------------------------------------------------------
-- 2. The counterexample: why "just align the two radii" is the wrong fix.
-- ---------------------------------------------------------------------------

tests['juggernaut frame: the 700 veto WOULD fire on it (Lich 477u, real range)'] = function()
    local J, bot, heroes = load_fx(F_JUGG, { armed = true })
    local hLich = heroes['npc_dota_hero_lich']
    local nLich = dist(bot, hLich)
    assert(nLich > 350 and nLich < 700,
        ('the counterexample must sit in the same band; Lich reads %.0f'):format(nLich))
    -- Without the declaration the reach leg is dead (GH #145) -- assert the
    -- mock world first, so this test cannot quietly become a tautology.
    assert(hLich:GetAttackRange() == 150,
        'GH #145 moved: fixtures now answer real attack ranges, re-read this file')
    assert(J.CanEnemyInterruptTpChannel(bot) == false,
        'with the mock 150 the reach leg cannot reach 477u -- nothing is proved yet')
    rawget(hLich, '__spec').GetAttackRange = LICH_ATTACK_RANGE
    assert(J.CanEnemyInterruptTpChannel(bot) == true,
        'with Lich at its real 500 range the promoted 700 veto DOES fire here')
end

tests['...and ground truth says that TP was correct: channel completed, +105.9s alive'] = function()
    local _, _, _, fx = load_fx(F_JUGG, { armed = true })
    assert(fx.observed.died_after > 100,
        'the juggernaut survived nearly two more minutes after this press -- '
        .. 'refusing it would have cost the escape, not saved it')
end

tests['tpgap does NOT fire on the juggernaut frame (the whole point of the narrowing)'] = function()
    local J, bot, heroes = load_fx(F_JUGG, { armed = true })
    rawget(heroes['npc_dota_hero_lich'], '__spec').GetAttackRange = LICH_ATTACK_RANGE
    assert(J.ShouldNotTpUnderLethalPressure(bot) == false,
        'band burst 93 against 733 health: the channel finishes, so let it TP')
end

tests['the hero who did most of the damage was OUTSIDE the band, and it still completed'] = function()
    local J, bot, heroes, fx = load_fx(F_JUGG, { armed = true })
    local hViper = heroes['npc_dota_hero_viper']
    assert(dist(bot, hViper) > 700,
        'Viper is outside the scan -- a 700-radius guard never sees the hero '
        .. 'that dealt 473 of the damage in this window')
    assert(fx.observed.burst['npc_dota_hero_viper'] > 400,
        'and it dealt the bulk of it')
    assert(J.ShouldNotTpUnderLethalPressure(bot) == false,
        'the guard reads only what it can see; on this frame that is correct')
end

-- ---------------------------------------------------------------------------
-- 3. tpsafe's band is untouched -- this guard never re-decides its presses.
-- ---------------------------------------------------------------------------

tests['on-face frame: lethal burst AND an enemy inside 350 -> still silent'] = function()
    local J, bot = load_fx(F_ONFACE, { armed = true })
    assert(#(J.GetNearbyHeroes(bot, 350, true, BOT_MODE_NONE) or {}) > 0,
        'this frame must have an enemy inside 350 or it proves nothing')
    assert(J.ShouldNotTpUnderLethalPressure(bot) == false,
        'tpsafe owns <=350 with its own deliberate last-resort fall-throughs; '
        .. 'tpgap must not second-guess a press tpsafe already ruled on')
end

-- ---------------------------------------------------------------------------
-- 4. Every clause is load-bearing (world mutations, applied and reverted).
-- ---------------------------------------------------------------------------

tests['M1 gate closed -> byte-identical to shipped behaviour'] = function()
    local J, bot = load_fx(F_LION, { armed = false })
    assert(J.ShouldNotTpUnderLethalPressure(bot) == false,
        "unarmed the candidate must be a no-op on its own pinned frame")
end

tests['M2 normal mode -> silent even armed'] = function()
    local J, bot = load_fx(F_LION, { armed = true, turbo = false })
    assert(J.ShouldNotTpUnderLethalPressure(bot) == false, 'turbo-only')
end

tests['M3 move the band enemy out of the scan -> nothing to refuse'] = function()
    local J, bot, heroes = load_fx(F_LION, { armed = true })
    local sp = rawget(heroes['npc_dota_hero_lich'], '__spec')
    sp.GetLocation = { x = 90000, y = 90000, z = 0 }
    sp.GetExtrapolatedLocation = { x = 90000, y = 90000, z = 0 }
    rawset(heroes['npc_dota_hero_lich'], 'GetLocation', nil)
    assert(J.ShouldNotTpUnderLethalPressure(bot) == false,
        'with the band empty the press is the ordinary safe one')
end

tests['M4 walk the band enemy INSIDE 350 -> handed back to tpsafe'] = function()
    local J, bot, heroes = load_fx(F_LION, { armed = true })
    local vBot = bot:GetLocation()
    local sp = rawget(heroes['npc_dota_hero_lich'], '__spec')
    sp.GetLocation = { x = vBot.x + 200, y = vBot.y, z = vBot.z }
    sp.GetExtrapolatedLocation = { x = vBot.x + 200, y = vBot.y, z = vBot.z }
    rawset(heroes['npc_dota_hero_lich'], 'GetLocation', nil)
    assert(J.ShouldNotTpUnderLethalPressure(bot) == false,
        'closer is NOT more refused here -- the on-face band is tpsafe\'s')
end

tests['M5 the burst bar is a real bar, pinned on BOTH sides'] = function()
    local J, bot, heroes = load_fx(F_LION, { armed = true })
    local sp = rawget(heroes['npc_dota_hero_lich'], '__spec')
    local nHealth = bot:GetHealth()
    sp.GetEstimatedDamageToTarget = function() return nHealth - 1 end
    assert(J.ShouldNotTpUnderLethalPressure(bot) == false,
        'one point short of lethal must let the TP go')
    sp.GetEstimatedDamageToTarget = function() return nHealth end
    assert(J.ShouldNotTpUnderLethalPressure(bot) == true,
        'exactly lethal must refuse -- the comparison is >=, and a mutation to '
        .. '> would slip through without this pair')
end

tests['M6 rooted -> walking is not available, so let it channel'] = function()
    local J, bot = load_fx(F_LION, { armed = true })
    rawget(bot, '__spec').IsRooted = true
    assert(J.ShouldNotTpUnderLethalPressure(bot) == false,
        'a rooted bot cannot walk out; the channel is the only thing left')
end

tests['M7 too slow to outrun -> let it channel'] = function()
    local J, bot = load_fx(F_LION, { armed = true })
    rawget(bot, '__spec').GetCurrentMovementSpeed = 200
    assert(J.ShouldNotTpUnderLethalPressure(bot) == false,
        'below the movement floor tpsafe already prefers the channel; so do we')
end

tests['M8 dead subject -> silent (the guard is asked before liveness elsewhere)'] = function()
    local J, bot = load_fx(F_LION, { armed = true })
    rawget(bot, '__spec').IsAlive = false
    assert(J.ShouldNotTpUnderLethalPressure(bot) == false, 'no decision to make')
end

-- ---------------------------------------------------------------------------
-- 5. Wiring: gated, turbo-only, and reachable from the retreat branch only.
-- ---------------------------------------------------------------------------

local function read(path)
    local fh = assert(io.open(path, 'r'))
    local s = fh:read('*a'); fh:close()
    return s
end

tests['the helper is gated on tpgap and turbo, in that order'] = function()
    local src = read('bots/FunLib/jmz_func.lua')
    local at = assert(src:find('function J.ShouldNotTpUnderLethalPressure', 1, true))
    local body = src:sub(at, at + 1600)
    assert(body:find('J%.IsModeTurbo%(%)'), 'turbo-only')
    assert(body:find("J%.IsSoakCandidate%( 'tpgap' %)"), "gated on 'tpgap'")
    assert(body:find('nChannelSeconds%s*=%s*3%.0'),
        'the window must be the channel, not the shared 5s helper -- widening '
        .. 'it back to 5 is what refuses the juggernaut escape')
    -- Declaring the local is not enough: the local has to be the one that is
    -- PASSED.  A mutation that leaves `nChannelSeconds = 3.0` sitting there
    -- and hands the call a literal 5 is invisible to every frame in this file
    -- (the mock's burst is duration-blind, see the last test), so the source is
    -- the only place it can be caught.
    assert(body:find('GetEstimatedDamageToTarget%(%s*true,%s*bot,%s*nChannelSeconds,'),
        'the channel window is declared but not passed -- the call must read '
        .. 'nChannelSeconds, not a literal duration')
    assert(not body:find('J%.GetTotalEstimatedDamageToTarget'),
        'the shared helper hardcodes 5s; using it here re-introduces the bug '
        .. 'the juggernaut frame documents')
end

tests['the only call site sits inside the RETREAT branch, next to tpsafe'] = function()
    local src = read('bots/ability_item_usage_generic.lua')
    local _, n = src:gsub('J%.ShouldNotTpUnderLethalPressure', '')
    assert(n == 1, ('exactly one call site expected, found %d'):format(n))
    local at = assert(src:find('J.ShouldNotTpUnderLethalPressure', 1, true))
    local before = src:sub(math.max(1, at - 1800), at)
    assert(before:find('J.ShouldWalkNotTp', 1, true),
        'the call must sit after tpsafe in the same retreat block -- the two '
        .. 'guards are meant to read as one contiguous domain')
    assert(before:find('nMode == BOT_MODE_RETREAT', 1, true),
        'and inside the retreat branch, which is the half tpsafe2 never sees')
    -- The complementary half of the same fact: tpsafe2 is still scoped OUT of
    -- retreat.  If someone ever drops that scoping, this guard becomes a
    -- second opinion on the same press and this file needs re-reading.
    assert(src:find('nMode ~= BOT_MODE_RETREAT', 1, true),
        'tpsafe2 is no longer scoped to non-retreat modes -- the gap this '
        .. 'candidate exists for may have closed some other way')
end

-- ---------------------------------------------------------------------------
-- 6. Corpus census (subprocess, ~32s) -- the size of the domain, and the
--    harness fact that makes a reach-based fix locally unfalsifiable.
-- ---------------------------------------------------------------------------

local function sweep()
    local p = assert(io.popen('lua5.1 tests/_tpgap_band_sweep.lua 2>/dev/null'))
    local c, done = {}, false
    for line in p:lines() do
        local k, v = line:match('^C (%S+) (%-?%d+)$')
        if k ~= nil then c[k] = tonumber(v) end
        if line == 'DONE' then done = true end
    end
    p:close()
    assert(done, 'tests/_tpgap_band_sweep.lua did not finish -- read its error')
    return c
end

tests['census: the uncovered band is 161 of 966 live hero-frames'] = function()
    local c = sweep()
    assert(c.src_onface == 350 and c.src_band == 700,
        'the sweep reads both radii out of the shipped helper; they moved')
    assert(c.live == 966 and c.fixtures == 104,
        ('corpus moved (%d frames / %d fixtures) -- re-measure the counts below')
            :format(c.live or -1, c.fixtures or -1))
    assert(c.gap == 161,
        ('gap band was 161/966 (16.7%%), now %d -- a fix here is not a corner '
         .. 'case, and the blast radius moved'):format(c.gap or -1))
    assert(c.onface == 96, 'tpsafe\'s own band was 96/966')
    assert(c.gap + c.onface + c.band_clear == c.live,
        'the three domains must partition the corpus, or one of them is '
        .. 'silently double-counting')
end

tests['census: the fall-throughs are inert on this corpus, and that is a fact not a claim'] = function()
    local c = sweep()
    assert(c.gap_slow == 0 and c.gap_rooted == 0,
        'no band frame is rooted or slowed, so M6/M7 are DECLARED counterfactuals '
        .. '-- if a future fixture supplies a real one, pin it instead')
    assert(c.gap_mobile == c.gap and c.gap_free == c.gap, 'both directions counted')
end

tests['census: with mock ranges the 700 veto fires on 0/161 -- GH #145, stated as an assertion'] = function()
    local c = sweep()
    assert(c.gap_mock_range_150 == c.gap,
        'every band frame answers the mock default 150; GH #145 moved')
    assert(c.gap_core_true_mockrange == 0,
        'reach = 150 + 150 = 300 cannot reach into (350,700], so ANY reach-based '
        .. 'fix is structurally unfalsifiable on this corpus without declaring '
        .. 'ranges -- which is exactly why the juggernaut test declares one')
    assert(c.gap_core_false_mockrange == c.gap, 'both directions counted')
end

tests['world assertion: the mock burst is duration-blind, so the 3s window is NOT measured here'] = function()
    local _, bot, heroes = load_fx(F_LION, { armed = true })
    local hLich = heroes['npc_dota_hero_lich']
    local a = hLich:GetEstimatedDamageToTarget(true, bot, 3.0, 0)
    local b = hLich:GetEstimatedDamageToTarget(true, bot, 5.0, 0)
    assert(a == b and a > 0,
        'the fixture replays one observed number whatever duration you ask for. '
        .. 'The shipped 3.0 is therefore a source-level fact (asserted in §5), '
        .. 'not something these frames can confirm. When the mock learns to '
        .. 'window the ground truth, this assertion goes red -- and the pinned '
        .. 'lion frame should then be re-read at 3s, where 436 over 8s may well '
        .. 'not clear 354.')
end

return tests

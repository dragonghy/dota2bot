-- [pullzone / GH #143] The creep-pull DISADVANTAGED gate has two disjuncts, and
-- on this corpus NEITHER of them measures what its comment says.
--
-- WHAT THIS FILE PINS
--   1. the shipped defect, argued from source and not from a preference:
--      the "an enemy laner is ZONING us" disjunct sits AFTER SAFE-1b, which
--      bails whenever a hero has damaged us inside 2.0 s. So the shipped code
--      asserts "I am being zoned" exactly on the frames where nobody has
--      touched us -- and what is left of the disjunct ("an enemy hero is within
--      1000 and we are not locally stronger") is a description of an ORDINARY
--      LANING FRAME.
--   2. the gated repair 'pullzone': being zoned has to have left a mark (hero
--      damage inside 6.0 s). With SAFE-1b in front of it the armed semantics are
--      "a laner was hitting me 2-6 s ago and right now I have a window" -- the
--      human 勾线 timing.
--   3. TWO new world assertions, both inside this same gate (below).
--
-- HONEST BOUNDS, STATED FIRST RATHER THAN BURIED
--   * the END-TO-END predicate J.ShouldCreepPullLane is STRUCTURALLY
--     UNREACHABLE on this corpus: it needs `GetNearbyLaneCreeps(900, true)`
--     non-empty and the fixture generator writes NO creeps (declared in
--     tests/mock/replay_fixture.lua for UNIT_LIST_ALL). The census below
--     measures 0 of 966 -- so this file asserts the extracted PURE predicate on
--     real frames and asserts the WIRING structurally, and says so rather than
--     dressing a call-site drive up as end-to-end evidence.
--   * 562 of the 966 live hero frames are v1 fixtures with no recent_damage at
--     all. There the damage readers are not installed and the armed clause
--     answers false for the WRONG reason (UNASKABLE, not calm). Those 240
--     narrowed frames are counted APART from the 46 askable ones and are never
--     pooled into a rate.
--
-- WORLD ASSERTION 22 (new): GetLaneFrontAmount answers the SAME mock constant
--   for both teams on 966/966 frames (front_tied == live). So the sibling
--   disjunct `bWavePushedToUs` -- the one whose comment claims to read lane
--   state -- is structurally FALSE here, not "false because lanes are even".
--   Any future clause about which half the wave is on is unverifiable locally
--   until the mock answers per-team.
--
-- WORLD ASSERTION 23 (new, the 0DIR shape): J.WeAreStronger(bot, 1200) reads
--   FALSE on 966/966 frames -- ourPowerRaw and enemyPower both sum to 0 because
--   GetOffensivePower / GetRawOffensivePower / GetAttackDamage / GetAttackSpeed
--   all fall through to the mock's generic `Get* -> 0` default, and `0 > 0` is
--   false. The dangerous half is the NEGATION the shipped code actually uses:
--   `not J.WeAreStronger(...)` is TRUE 966/966, so on this corpus the zoned
--   disjunct collapses to "an enemy hero is nearby" and nothing else. A census
--   that only reported the negation would have read as "the strength check
--   agrees with us on every frame".
--
-- THE FRAMES. The load-bearing pair is the SAME HERO in the SAME MATCH at two
-- moments, which is what makes it a measurement and not a pick:
--   A  ss_chase_stalled  / shadow_shaman   1 enemy, 57 hero damage 2-6 s ago,
--                                          none inside 2 s -> armed KEEPS it
--                                          (and SAFE-1b would let it through)
--   B  ss_chase_start    / shadow_shaman   1 enemy, ZERO hero damage in 6 s
--                                          -> armed NARROWS it away
--   A2 lion_drain_midchannel / drow_ranger 1 enemy, 203 damage in the ring
--   B2 lion_drain_jungle / viper           1 enemy, dry -- second narrowed frame
--                                          in a different match
--   C  ck_rescue_trade / lina              a v1 frame: armed answers false, and
--                                          this file says out loud that it is
--                                          UNASKABLE rather than calm
--   D  jak_rescue_axe / jakiro             no enemy within 1000 -> false on both
--                                          sides of the gate, the disjunct's own
--                                          floor

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')
local cs = require('corpus_scale')

local JMZ = 'bots/FunLib/jmz_func.lua'
local GATE = 'pullzone'

local A_FIX, A_HERO = 'tests/fixtures/f_260819_181742_ss_chase_stalled.lua', 'npc_dota_hero_shadow_shaman'
local B_FIX, B_HERO = 'tests/fixtures/f_260819_181742_ss_chase_start.lua', 'npc_dota_hero_shadow_shaman'
local A2_FIX, A2_HERO = 'tests/fixtures/f_260819_182855_lion_drain_midchannel.lua', 'npc_dota_hero_drow_ranger'
local B2_FIX, B2_HERO = 'tests/fixtures/f_260819_182855_lion_drain_jungle.lua', 'npc_dota_hero_viper'
local C_FIX, C_HERO = 'tests/fixtures/f_013254_ck_rescue_trade.lua', 'npc_dota_hero_lina'
local D_FIX, D_HERO = 'tests/fixtures/f_011405_jak_rescue_axe.lua', 'npc_dota_hero_jakiro'

local tests = {}

local function read_file(path)
    local f = assert(io.open(path, 'r'))
    local s = f:read('*a')
    f:close()
    return s
end

local SRC = read_file(JMZ)

-- Counting an identifier over raw source counts the PROSE too: this family's
-- headers name their own helper and their own gate id, so the "exactly one call
-- site" claims below would be counting comments (they did, first cut: 4 and 3).
-- Executable lines only.
local function code_only(s)
    local out = {}
    for line in (s .. '\n'):gmatch('([^\n]*)\n') do
        if not line:match('^%s*%-%-') then out[#out + 1] = line end
    end
    return table.concat(out, '\n')
end

-- Function bodies, extracted by NAME rather than matched over the whole file
-- (backlog 0SRC: `match` over a 9000-line file hands back some other function's
-- constant, and the reader cannot tell).
local function fn_body(name)
    local at = assert(SRC:find('function J.' .. name .. '(', 1, true),
        'J.' .. name .. ' moved or was renamed')
    local stop = SRC:find('\nend\n', at, true)
    return SRC:sub(at, stop or (at + 6000))
end

local ZONE_BODY = fn_body('IsLaneZonedByEnemy')
local PULL_BODY = fn_body('ShouldCreepPullLane')

local function load_at(path, hero, armed)
    local J, bot = rf.load(path, hero)
    J.IsSoakCandidate = function(id) return armed and id == GATE or false end
    return J, bot
end

local function enemies(J, bot)
    return J.GetNearbyHeroes(bot, 1000, true, BOT_MODE_NONE) or {}
end

-- ------------------------------------------------------------- the source --

tests['source: the zoned disjunct exists once, as a pure predicate'] = function()
    assert(SRC:find('function J.IsLaneZonedByEnemy( bot, tEnemyHeroes )', 1, true),
        'J.IsLaneZonedByEnemy is gone or its signature changed')
    -- The old inline expression must not survive anywhere: two copies of a
    -- disjunct is how one of them silently stops being narrowed (backlog 0PAIR).
    assert(not SRC:find('#tEnemyHeroes >= 1 ) and not J.WeAreStronger', 1, true),
        'the zoned disjunct is inlined again somewhere -- the helper is now a second copy')
    local n = 0
    for _ in code_only(SRC):gmatch('J%.IsLaneZonedByEnemy') do n = n + 1 end
    assert(n == 2, 'expected exactly one definition and one call site, saw ' .. n)
    assert(PULL_BODY:find('J.IsLaneZonedByEnemy( bot, tEnemyHeroes )', 1, true),
        'J.ShouldCreepPullLane no longer reaches the disjunct through the helper')
end

tests['source: the gate id appears exactly once under bots/'] = function()
    local all = code_only(SRC)
        .. code_only(read_file('bots/mode_roam_generic.lua'))
        .. code_only(read_file('bots/mode_laning_generic.lua'))
    local n = 0
    for _ in all:gmatch("'" .. GATE .. "'") do n = n + 1 end
    assert(n == 1, 'the ' .. GATE .. ' id appears ' .. n .. ' times, expected exactly 1')
    assert(ZONE_BODY:find("J.IsSoakCandidate( '" .. GATE .. "' )", 1, true),
        'the gate moved out of the helper')
end

tests['source: turbo is inherited structurally, not restated'] = function()
    -- The helper is deliberately NOT turbo-gated: its one caller opens with it.
    -- Asserting BOTH halves is the point -- "the helper has no turbo check" on
    -- its own is indistinguishable from having forgotten one.
    assert(not ZONE_BODY:find('IsModeTurbo', 1, true),
        'the helper now checks turbo itself -- either that is a redundant check '
        .. 'or the caller stopped doing it; say which')
    local turbo_at = PULL_BODY:find('if not J.IsModeTurbo() then return nil end', 1, true)
    local call_at = PULL_BODY:find('J.IsLaneZonedByEnemy', 1, true)
    assert(turbo_at and call_at and turbo_at < call_at,
        'the caller no longer establishes turbo before reaching the disjunct')
end

tests['source: the two lookbacks are ordered so the armed window is non-empty'] = function()
    local harass = tonumber(ZONE_BODY:match('WasRecentlyDamagedByAnyHero%(%s*([%d%.]+)%s*%)'))
    local safe1b = tonumber(PULL_BODY:match(
        'if bot:WasRecentlyDamagedByAnyHero%(%s*([%d%.]+)%s*%) then return nil end'))
    assert(harass and safe1b, 'one of the two lookbacks stopped being a literal')
    -- SAFE-1b bails on anything inside its own window, so a harass lookback at
    -- or below it admits NOTHING end-to-end: the clause would read as a very
    -- strict narrowing while actually being a switch that turns creeppull off.
    assert(harass > safe1b, string.format(
        'the harass lookback %.1f is not wider than SAFE-1b %.1f -- armed, the '
        .. 'pull could never fire at all', harass, safe1b))
    -- And it must be inside what the corpus can answer, or the loader clamps it
    -- and every number in this file silently describes a shorter window.
    local fx = dofile(A_FIX)
    assert(fx.recent_window and harass <= fx.recent_window, string.format(
        'the harass lookback %.1f exceeds the fixture window %.1f -- the loader '
        .. 'clamps it, so it is unmeasurable rather than merely bold',
        harass, fx.recent_window or -1))
end

-- ------------------------------------------------------- the real frames --

tests['A: harassed 2-6 s ago, calm right now -> armed KEEPS the pull open'] = function()
    local J, bot = load_at(A_FIX, A_HERO, false)
    local te = enemies(J, bot)
    assert(#te == 1, 'frame A no longer has exactly one enemy in range, saw ' .. #te)
    assert(J.IsLaneZonedByEnemy(bot, te), 'frame A is not zoned unarmed')
    assert(not bot:WasRecentlyDamagedByAnyHero(2.0),
        'frame A is inside SAFE-1b -- it can no longer speak for the ring')
    assert(bot:WasRecentlyDamagedByAnyHero(6.0), 'frame A lost its harass history')

    local J2, bot2 = load_at(A_FIX, A_HERO, true)
    assert(J2.IsLaneZonedByEnemy(bot2, enemies(J2, bot2)),
        'ARMED dropped frame A -- the repair is eating the case it exists to keep')
end

tests['B: same hero, same match, no harass at all -> armed NARROWS it away'] = function()
    local J, bot = load_at(B_FIX, B_HERO, false)
    local te = enemies(J, bot)
    assert(#te == 1, 'frame B no longer has exactly one enemy in range, saw ' .. #te)
    assert(J.IsLaneZonedByEnemy(bot, te),
        'frame B is not zoned unarmed -- the shipped defect it demonstrates is gone')
    assert(not bot:WasRecentlyDamagedByAnyHero(6.0),
        'frame B picked up hero damage -- it is no longer the dry half of the pair')

    local J2, bot2 = load_at(B_FIX, B_HERO, true)
    assert(not J2.IsLaneZonedByEnemy(bot2, enemies(J2, bot2)),
        'ARMED still calls frame B zoned -- the clause is not biting')
end

tests['A2/B2: the same split reproduces in a different match'] = function()
    local J, bot = load_at(A2_FIX, A2_HERO, true)
    assert(J.IsLaneZonedByEnemy(bot, enemies(J, bot)),
        'A2 (203 hero damage in the ring) was dropped by the armed clause')

    local J2, bot2 = load_at(B2_FIX, B2_HERO, false)
    assert(J2.IsLaneZonedByEnemy(bot2, enemies(J2, bot2)), 'B2 is not zoned unarmed')
    local J3, bot3 = load_at(B2_FIX, B2_HERO, true)
    assert(not J3.IsLaneZonedByEnemy(bot3, enemies(J3, bot3)),
        'B2 survived the armed clause')
end

tests['C: a v1 frame answers false for the WRONG reason -- declared, not counted'] = function()
    local fx = dofile(C_FIX)
    assert(fx.recent_window == nil,
        'C is a v2 fixture now -- it can no longer stand for the unaskable half')
    local J, bot = load_at(C_FIX, C_HERO, false)
    local te = enemies(J, bot)
    assert(#te == 1, 'frame C no longer has exactly one enemy in range')
    assert(J.IsLaneZonedByEnemy(bot, te), 'frame C is not zoned unarmed')

    local J2, bot2 = load_at(C_FIX, C_HERO, true)
    assert(not J2.IsLaneZonedByEnemy(bot2, enemies(J2, bot2)),
        'the armed clause did not narrow C')
    -- ...and the reason is the missing history, not a calm frame. This is the
    -- assertion that stops the 240 v1 narrowings from being read as a result.
    assert(not bot2:WasRecentlyDamagedByAnyHero(6.0), 'unexpected: v1 answered true')
    assert(bot2.__spec == nil or bot2.__spec.WasRecentlyDamagedByAnyHero == nil,
        'the loader installed damage readers on a v1 fixture -- C is askable now '
        .. 'and this case is measuring something else')
end

tests['D: no enemy nearby -> false on both sides (the disjunct floor)'] = function()
    local J, bot = load_at(D_FIX, D_HERO, false)
    assert(#enemies(J, bot) == 0, 'frame D grew an enemy in range')
    assert(not J.IsLaneZonedByEnemy(bot, enemies(J, bot)), 'D is zoned with no enemy')
    local J2, bot2 = load_at(D_FIX, D_HERO, true)
    assert(not J2.IsLaneZonedByEnemy(bot2, enemies(J2, bot2)), 'D is zoned armed')
end

tests['guards: nil bot / nil list / empty list are all false, both ways'] = function()
    local J, bot = load_at(A_FIX, A_HERO, false)
    for _, armed in ipairs({ false, true }) do
        J.IsSoakCandidate = function(id) return armed and id == GATE or false end
        assert(not J.IsLaneZonedByEnemy(nil, { bot }), 'nil bot answered true')
        assert(not J.IsLaneZonedByEnemy(bot, nil), 'nil list answered true')
        assert(not J.IsLaneZonedByEnemy(bot, {}), 'empty list answered true')
    end
end

-- ------------------------------------------------------------- the census --

local function sweep()
    local p = assert(io.popen('lua5.1 tests/_creeppull_zone_sweep.lua 2>/dev/null'))
    local text = p:read('*a')
    p:close()
    assert(text:find('\nDONE\n') or text:find('^DONE\n'),
        'the corpus sweep subprocess did not finish (no DONE line)')
    local c, rows = {}, {}
    for line in text:gmatch('[^\n]+') do
        local k, v = line:match('^C ([%w_]+) (%-?%d+)$')
        if k then c[k] = tonumber(v) end
        local f, h, ne, d2, d6 = line:match('^ZROW (%S+) (%S+) (%d+) (%d+) (%d+)$')
        if f then
            rows[#rows + 1] = { fix = f, hero = h, n = tonumber(ne),
                d2 = tonumber(d2), d6 = tonumber(d6) }
        end
    end
    return c, rows
end

local SWEEP_C, SWEEP_ROWS = sweep()

tests['census: the corpus the numbers are quoted from'] = function()
    cs.corpus(SWEEP_C.fixtures, 'pullzone corpus')
    cs.ratchet(SWEEP_C.live, 966, 'live hero frames')
    assert(SWEEP_C.live_v1 + SWEEP_C.live_v2 == SWEEP_C.live, 'the v1/v2 split does not partition')
    -- constants, read out of the source by the sweep: facts about bots/, so
    -- equalities, not ratchets.
    assert(SWEEP_C.harass_x10 == 60, 'the harass lookback is no longer 6.0')
    assert(SWEEP_C.safe1b_x10 == 20, 'SAFE-1b is no longer 2.0')
    assert(SWEEP_C.radius == 1200 and SWEEP_C.near == 1000,
        'the two radii moved; re-read the domain before quoting it')
    assert(SWEEP_C.CLAMPED_window == 0,
        'a fixture window is now shorter than the harass lookback -- the census '
        .. 'is measuring a clamped window and every rate below is wrong')
end

tests['census: the end-to-end predicate is UNREACHABLE here, and where'] = function()
    -- The claim whose whole content is a zero stays an equality (corpus_scale's
    -- own rule): the moment one fixture carries a lane creep this must go red,
    -- because then the end-to-end drive becomes possible and this file's
    -- "structurally unreachable" disclaimer stops being true.
    assert(SWEEP_C.lanecreeps == 0, string.format(
        'a fixture now answers GetNearbyLaneCreeps (%d frames) -- J.ShouldCreepPullLane '
        .. 'can be driven end to end; stop quoting the pure-predicate bound',
        SWEEP_C.lanecreeps))
    -- the prefix clauses that DO pass, so the reader can see the creeps are the
    -- only thing missing rather than assuming it.
    cs.ratchet(SWEEP_C.laning, 824, 'laning-phase frames')
    cs.ratchet(SWEEP_C.core, 804, 'core frames')
    cs.ratchet(SWEEP_C.hp_ok, 804, 'healthy frames')
end

tests['census: WORLD ASSERTION 22 -- lane front is tied on every frame'] = function()
    assert(SWEEP_C.front_readable == SWEEP_C.live,
        'GetLaneFrontAmount stopped answering on some frames')
    assert(SWEEP_C.front_tied == SWEEP_C.live, string.format(
        'the lane front is no longer tied on every frame (%d of %d) -- the mock '
        .. 'answers per-team now, so bWavePushedToUs became measurable and this '
        .. 'file must re-take the domain instead of declaring it unreadable',
        SWEEP_C.front_tied, SWEEP_C.live))
    assert(SWEEP_C.front_pushed_to_us == 0,
        'a frame reports the wave shoved onto our half; see above')
end

tests['census: WORLD ASSERTION 23 -- WeAreStronger is false on every frame'] = function()
    -- Both directions, per backlog 0DIR: `n/n` is an alarm whichever way it
    -- points, and here the TRUE side is the one the shipped code reads.
    assert(SWEEP_C.stronger == 0, string.format(
        'J.WeAreStronger answered true on %d frames -- it reads real power now, '
        .. 'so the zoned disjunct no longer collapses to "an enemy is nearby" '
        .. 'and the 39.1%% domain below must be re-measured', SWEEP_C.stronger))
    assert(SWEEP_C.zoned_off == SWEEP_C.enemy_near, string.format(
        'zoned(unarmed) %d != enemies-nearby %d -- the strength half started '
        .. 'discriminating; re-read world assertion 23',
        SWEEP_C.zoned_off, SWEEP_C.enemy_near))
end

tests['census: the domain, split by what the corpus can answer'] = function()
    cs.ratchet(SWEEP_C.zoned_off, 378, 'zoned frames (unarmed)')
    assert(SWEEP_C.zoned_off_v1 + SWEEP_C.zoned_off_v2 == SWEEP_C.zoned_off,
        'the zoned v1/v2 split does not partition')
    assert(SWEEP_C.narrowed_askable + SWEEP_C.narrowed_unaskable == SWEEP_C.narrowed,
        'the narrowed askable/unaskable split does not partition')
    assert(SWEEP_C.zoned_on + SWEEP_C.narrowed == SWEEP_C.zoned_off,
        'armed kept + narrowed does not add up to unarmed')
    -- The clause is subtract-only. A frame it TURNS ON cannot exist.
    assert(SWEEP_C.IMPOSSIBLE_widened == 0,
        'the armed clause ADMITTED a frame the unarmed one refused')
    -- The only rate this file is willing to quote: over the askable frames.
    local askable = SWEEP_C.zoned_off_v2
    assert(askable >= 100, 'the askable domain collapsed to ' .. askable)
    local share = SWEEP_C.narrowed_askable / askable
    assert(share > 0.20 and share < 0.60, string.format(
        'the askable narrowing share moved to %.1f%% (was 33.3%%: 46 of 138) -- '
        .. 'a lever that narrows almost nothing or almost everything is a '
        .. 'different lever, re-read it before shipping', share * 100))
end

tests['census: the ring is what the armed clause is actually for'] = function()
    -- End to end, SAFE-1b drops every frame with damage inside 2.0 s, so the
    -- frames the armed clause DECIDES are the ring (2-6 s) plus the dry ones.
    -- Quoting the whole zoned domain here would over-state the lever by ~2x --
    -- this is the 0DOM discipline applied to its own repair.
    local ring, dry, hot = 0, 0, 0
    for _, r in ipairs(SWEEP_ROWS) do
        if r.d2 > 0 then hot = hot + 1
        elseif r.d6 > 0 then ring = ring + 1
        else dry = dry + 1 end
    end
    assert(hot + ring + dry == #SWEEP_ROWS, 'the ZROW split does not partition')
    cs.ratchet(ring, 25, 'ring frames (harassed 2-6 s ago)')
    cs.ratchet(dry, 46, 'dry frames (no harass in 6 s)')
    assert(dry == SWEEP_C.narrowed_askable,
        'the dry rows and the narrowed-askable counter disagree -- one of the '
        .. 'two is not measuring what it says')
    -- The end-to-end domain: of the frames SAFE-1b lets through, this share is
    -- what the lever removes.
    local decided = ring + dry
    assert(decided >= 50, 'the decided domain collapsed to ' .. decided)
    local share = dry / decided
    assert(share > 0.40 and share < 0.85, string.format(
        'the post-SAFE-1b narrowing share moved to %.1f%% (was 64.8%%: 46 of 71)',
        share * 100))
end

return tests

-- [fieldcreep / GH #119, owner priority P2's family] The field-regen situation
-- predicate reads heroes and towers and NOTHING ELSE, so its own top comment --
-- "a hurt bot with nobody anywhere near it" -- can be true on a frame where a
-- camp is chewing the bot. The replay desk filed three frames from 283 games;
-- this file pins the same defect on real frames from this repository's own
-- corpus and asserts the gated repair, at BOTH ends: the predicate and the
-- wrapper decision it feeds.
--
-- The five frames the clause bites on, and what each is for:
--   A  lion_drain_jungle / lion           25.0% HP, 109 creep damage in 3s,
--                                         HAS a heal -> the wrapper flips
--   B  od_eclipse_pair / juggernaut       49.6% HP, 132 in 3s, HAS a heal ->
--                                         second hero, second wave, same flip
--   (three more with no heal, which is the SUPPLY half -- 'fieldbuy')
-- and the two negative controls, which is where the teeth are:
--   N1 wd_defend_token / juggernaut       creep damage exists but at dt=4.3,
--                                         OUTSIDE the 3.0 lookback -> no veto.
--                                         This is what pins the constant: move
--                                         3.0 to 5.0 and this case fails.
--   N2 lina_tp_home / lina                hero-kind damage only -> no veto.
--                                         This frame is owner P2's OWN pinned
--                                         evidence frame, so it doubles as the
--                                         regression guard for the thing this
--                                         family exists to fix.
--
-- Honest bounds, stated first rather than buried:
--   * 34 of the 50 situation frames are v1 fixtures carrying no recent_damage
--     at all. On those the loader does not install the damage readers, so the
--     clause is UNASKABLE, not false-for-a-good-reason. The domain measured
--     here is over the 16 askable frames, and 5/16 is a floor on the real
--     rate, not an estimate of it.
--   * of the 16 askable, 9 genuinely carry no damage history (v2 fixture,
--     nothing hit that hero inside the 6s window) -- those are correctly
--     false, and they are counted separately from the 34.
--   * this file asserts what the SITUATION and the two wrappers answer. It
--     does not assert a bid: the item-use layer is dark on a fixture (GH #100)
--     and the retreat-mode end of this family was already pinned by the
--     'stayfield2' round.

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')

local JMZ = 'bots/FunLib/jmz_func.lua'
local GATE = 'fieldcreep'

local A_FIX, A_HERO = 'tests/fixtures/f_260819_182855_lion_drain_jungle.lua', 'npc_dota_hero_lion'
local B_FIX, B_HERO = 'tests/fixtures/f_260819_222559_od_eclipse_pair.lua', 'npc_dota_hero_juggernaut'
local N1_FIX, N1_HERO = 'tests/fixtures/f_260820_043140_wd_defend_token.lua', 'npc_dota_hero_juggernaut'
local N2_FIX, N2_HERO = 'tests/fixtures/f_260822_063722_lina_tp_home.lua', 'npc_dota_hero_lina'

local tests = {}

local function read_file(path)
    local f = assert(io.open(path, 'r'))
    local s = f:read('*a')
    f:close()
    return s
end

--- Install a fixture world with `armed` (a soak id, or nil for none) armed.
local function world(fix, hero, armed)
    local J, bot = rf.load(fix, hero)
    J.IsSoakCandidate = function(id) return armed ~= nil and id == armed end
    return J, bot
end

-- ---------------------------------------------------------------- frame A --

tests['frame A: the defect -- lion is in the situation while a camp hits him'] = function()
    local J, bot = world(A_FIX, A_HERO, nil)
    assert(J.IsFieldRegenSituation(bot) == true,
        'shipped default: the situation holds on this frame')
    -- What the shipped clauses each answered, so the defect is visible rather
    -- than asserted: every danger read above is satisfied...
    assert(#J.GetNearbyHeroes(bot, 1600, true, BOT_MODE_NONE) == 0,
        'the 1600 hero ring is empty')
    assert(bot:WasRecentlyDamagedByAnyHero(3.0) == false,
        'no hero has hit him')
    assert(#bot:GetNearbyTowers(1200, true) == 0, 'no enemy tower in reach')
    -- ...and yet something has been hitting him for the whole lookback.
    assert(bot:WasRecentlyDamagedByCreep(3.0) == true,
        'ground truth: a creep damaged him inside the lookback')
    assert(J.GetHP(bot) < 0.26, 'and he is at a quarter health while it happens')
end

tests['frame A: armed, the situation is vetoed'] = function()
    local J, bot = world(A_FIX, A_HERO, GATE)
    assert(J.IsFieldRegenSituation(bot) == false,
        'armed: the creep clause vetoes the situation')
end

tests['frame A: armed, the FINAL wrapper decision flips (stayfield / stayfield2)'] = function()
    -- The end of the chain, not just the predicate: this bot HAS a heal, so
    -- unarmed the decision-side wrappers say "stay in the field" while a camp
    -- out-damages the drink.
    local J, bot = world(A_FIX, A_HERO, nil)
    assert(J.HasFieldRegenSource(bot) == true, 'he is carrying something to drink')
    assert(J.ShouldRegenNotGoHome(bot) == true, 'unarmed: the core decision is STAY')

    -- Both gated wrappers need their own id armed too, so each is asked with
    -- its own id AND the new one -- the bundle a wave would run.
    local J2, bot2 = rf.load(A_FIX, A_HERO)
    J2.IsSoakCandidate = function(id) return id == 'stayfield' end
    assert(J2.ShouldRegenNotTpHome(bot2) == true,
        'stayfield alone: STAY (this is the behaviour under test)')

    local J3, bot3 = rf.load(A_FIX, A_HERO)
    J3.IsSoakCandidate = function(id) return id == 'stayfield' or id == GATE end
    assert(J3.ShouldRegenNotTpHome(bot3) == false,
        'stayfield + fieldcreep: no longer STAY')

    local J4, bot4 = rf.load(A_FIX, A_HERO)
    J4.IsSoakCandidate = function(id) return id == 'stayfield2' or id == GATE end
    assert(J4.ShouldRegenNotWalkHome(bot4) == false,
        'the walk half moves with it -- same core predicate')
end

tests['frame A: the creep damage inside the lookback out-paces every drink'] = function()
    -- Condition (c) measured on the frame rather than argued: what hit him in
    -- the 3s the clause reads, against what the four accepted sources deliver
    -- in the same 3s (tango 21, faerie_fire 85 once, flask ~92, bottle ~135).
    local fx = dofile(A_FIX)
    local total, hits, biggest = 0, 0, 0
    for _, u in ipairs(fx.units) do
        if u.name == A_HERO then
            for _, d in ipairs(u.recent_damage or {}) do
                if d.kind == 'creep' and d.dt <= 3.0 then
                    total = total + d.value
                    hits = hits + 1
                    if d.value > biggest then biggest = d.value end
                end
            end
        end
    end
    assert(hits == 3 and total == 109,
        'expected 3 creep hits totalling 109, got ' .. hits .. '/' .. total)
    assert(biggest >= 25,
        'and they are in the heavy tail (camp contact), biggest ' .. biggest)
end

-- ---------------------------------------------------------------- frame B --

tests['frame B: second hero, second wave -- juggernaut, same flip'] = function()
    local J, bot = world(B_FIX, B_HERO, nil)
    assert(J.IsFieldRegenSituation(bot) == true, 'unarmed: situation holds')
    assert(J.ShouldRegenNotGoHome(bot) == true, 'unarmed: STAY')
    assert(bot:WasRecentlyDamagedByAnyHero(3.0) == false,
        'again no hero involved -- the shipped clauses cannot see this')

    local J2, bot2 = world(B_FIX, B_HERO, GATE)
    assert(J2.IsFieldRegenSituation(bot2) == false, 'armed: vetoed')
    assert(J2.ShouldRegenNotGoHome(bot2) == false, 'armed: no longer STAY')
end

-- ------------------------------------------------------- negative controls --

tests['N1: creep damage OUTSIDE the lookback does not veto (pins the 3.0)'] = function()
    local fx = dofile(N1_FIX)
    local dts = {}
    for _, u in ipairs(fx.units) do
        if u.name == N1_HERO then
            for _, d in ipairs(u.recent_damage or {}) do
                if d.kind == 'creep' then dts[#dts + 1] = d.dt end
            end
        end
    end
    assert(#dts == 1 and dts[1] > 3.0 and dts[1] < 6.0,
        'this frame must carry exactly one creep hit, outside 3.0 and inside '
        .. 'the 6s window the fixture recorded -- otherwise it is not a test '
        .. 'of the constant. got ' .. #dts .. ' hits')

    local J, bot = world(N1_FIX, N1_HERO, nil)
    assert(J.IsFieldRegenSituation(bot) == true, 'unarmed: situation holds')
    local J2, bot2 = world(N1_FIX, N1_HERO, GATE)
    assert(J2.IsFieldRegenSituation(bot2) == true,
        'armed: a hit 4.3s ago is not "a creep is on me" -- no veto')
end

tests['N2: hero-kind damage does not veto (owner P2 own frame, regression guard)'] = function()
    -- f_260822_063722_lina_tp_home is the frame owner priority P2 is pinned
    -- to. If this fix suppressed it, the fix would have eaten the thing the
    -- family was built for.
    local J, bot = world(N2_FIX, N2_HERO, nil)
    assert(J.IsFieldRegenSituation(bot) == true, 'unarmed: the P2 frame holds')
    assert(bot:WasRecentlyDamagedByCreep(3.0) == false, 'no creep touched her')
    local J2, bot2 = world(N2_FIX, N2_HERO, GATE)
    assert(J2.IsFieldRegenSituation(bot2) == true,
        'armed: the P2 evidence frame is untouched')

    local J3, bot3 = rf.load(N2_FIX, N2_HERO)
    J3.IsSoakCandidate = function(id) return id == 'stayfield' or id == GATE end
    assert(J3.ShouldRegenNotTpHome(bot3) == true,
        'and the decision it exists to make still stands')
end

-- ------------------------------------------------------------------ gates --

tests['gate: a wrong id arms nothing'] = function()
    local J, bot = world(A_FIX, A_HERO, 'stayfield')
    assert(J.IsFieldRegenSituation(bot) == true,
        'the situation must not move for an unrelated id')
    local J2, bot2 = world(A_FIX, A_HERO, 'notanid')
    assert(J2.IsFieldRegenSituation(bot2) == true, 'nor for a nonsense id')
end

tests['gate: the clause names its id and can only ever return false'] = function()
    local src = read_file(JMZ)
    local sit = src:match('function J%.IsFieldRegenSituation%(.-\nend')
    assert(sit, 'could not locate J.IsFieldRegenSituation')
    -- This REPLACES the older "the situation must stay gate-free" contract
    -- (test_replay_260822_fieldbuy_supply.lua), which this round turned over
    -- on purpose. The point of that contract was that the predicate must not
    -- be able to SHIP behaviour on its own; a gate that can only narrow the
    -- domain keeps that property, and this is the assertion that enforces it.
    local ids = {}
    for id in sit:gmatch("J%.IsSoakCandidate%(%s*'([%w_]+)'%s*%)") do
        ids[#ids + 1] = id
    end
    assert(#ids == 1 and ids[1] == GATE,
        "exactly one gate, named '" .. GATE .. "', may live in the situation")
    local _, nCalls = sit:gsub('J%.IsSoakCandidate%(', '')
    assert(nCalls == 1, 'and it may be asked exactly once, found ' .. nCalls)
    -- The gated branch's body: `return false`, nothing else. An append-only
    -- narrowing clause cannot make the unarmed default answer differently.
    local body = sit:match("J%.IsSoakCandidate%(%s*'" .. GATE .. "'%s*%).-then(.-)end")
    assert(body and body:find('return false', 1, true),
        'the gated branch must return false')
    assert(not body:find('return true', 1, true),
        'the gated branch must never widen the domain')
end

tests['[reverse] the lookback is the hero clause lookback, not a new constant'] = function()
    -- The claim in the source comment is that this is the missing half of the
    -- hero clause, sharing its window. If someone tunes one of them, that
    -- claim stops being true and this fails.
    local src = read_file(JMZ)
    local sit = src:match('function J%.IsFieldRegenSituation%(.-\nend')
    local hero = sit:match('WasRecentlyDamagedByAnyHero%(%s*([%d%.]+)%s*%)')
    local creep = sit:match('WasRecentlyDamagedByCreep%(%s*([%d%.]+)%s*%)')
    assert(hero and creep, 'both lookbacks must be literals in this function')
    assert(hero == creep,
        'the two lookbacks drifted apart: hero ' .. hero .. ' vs creep ' .. creep)
    assert(tonumber(creep) == 3.0, 'and the shared value is 3.0')
end

tests['wiring: the situation still has exactly its two wrapper consumers'] = function()
    local src = read_file(JMZ)
    local _, n = src:gsub('J%.IsFieldRegenSituation%(', '')
    assert(n == 3,
        'definition + ShouldRegenNotGoHome + ShouldFieldBuyRegen = 3, found ' .. n)
    local elsewhere = read_file('bots/item_purchase_generic.lua')
        .. read_file('bots/ability_item_usage_generic.lua')
        .. read_file('bots/mode_retreat_generic.lua')
    assert(not elsewhere:find('IsFieldRegenSituation', 1, true),
        'a call site calls the situation predicate directly')
end

-- ------------------------------------------------------------- the census --

local function sweep()
    local p = assert(io.popen('lua5.1 tests/_fieldcreep_sweep.lua 2>/dev/null'))
    local text = p:read('*a')
    p:close()
    assert(text:find('\nDONE\n') or text:find('^DONE\n'),
        'the corpus sweep subprocess did not finish (no DONE line)')
    local c, rows, band = {}, {}, {}
    for line in text:gmatch('[^\n]+') do
        local k, v = line:match('^C ([%w_]+) (%-?%d+)$')
        if k then c[k] = tonumber(v) end
        local bk, bv = line:match('^BAND ([%w%-]+) (%d+)$')
        if bk then band[bk] = tonumber(bv) end
        local f, h, hp, cr, he, dm =
            line:match('^ROW (%S+) (%S+) ([%d%.]+) (%d) (%d) (%d+)$')
        if f then
            rows[#rows + 1] = { fix = f, hero = h, hp = tonumber(hp),
                creep = cr == '1', heal = he == '1', dmg = tonumber(dm) }
        end
    end
    return c, rows, band
end

local SWEEP_C, SWEEP_ROWS, SWEEP_BAND = sweep()

tests['census: the corpus the numbers are quoted from'] = function()
    assert(SWEEP_C.fixtures == 100, 'corpus size moved: ' .. tostring(SWEEP_C.fixtures))
    assert(SWEEP_C.live == 930, 'live hero frames moved: ' .. tostring(SWEEP_C.live))
    assert(SWEEP_C.lookback_x10 == 30,
        'the sweep read a lookback other than 3.0 out of the source')
end

tests['census: the domain, split by what the corpus can and cannot answer'] = function()
    assert(SWEEP_C.situation == 50, 'situation frames: ' .. tostring(SWEEP_C.situation))
    -- The bound that matters: two thirds of the domain cannot be asked.
    assert(SWEEP_C.sit_v1 == 34, 'v1 (unaskable) frames: ' .. tostring(SWEEP_C.sit_v1))
    assert(SWEEP_C.sit_v2 == 16, 'v2 (askable) frames: ' .. tostring(SWEEP_C.sit_v2))
    assert(SWEEP_C.sit_v1 + SWEEP_C.sit_v2 == SWEEP_C.situation, 'the split must partition')
    -- Of the askable ones, 7 carry a history and 9 are genuinely quiet.
    assert(SWEEP_C.sit_askable == 7, 'frames with a history: ' .. tostring(SWEEP_C.sit_askable))
    assert(SWEEP_C.sit_v2_silent == 9, 'quiet frames: ' .. tostring(SWEEP_C.sit_v2_silent))
    assert(SWEEP_C.sit_askable + SWEEP_C.sit_v2_silent == SWEEP_C.sit_v2,
        'and those two must exhaust the askable half')
end

tests['census: 5 of the 50 are vetoed, and the veto never widens'] = function()
    assert(SWEEP_C.vetoed == 5, 'vetoed frames: ' .. tostring(SWEEP_C.vetoed))
    assert(SWEEP_C.situation_armed == 45, 'armed domain: ' .. tostring(SWEEP_C.situation_armed))
    assert(SWEEP_C.situation - SWEEP_C.vetoed == SWEEP_C.situation_armed,
        'the armed domain must be the unarmed one minus exactly the vetoes')
    assert(SWEEP_C.IMPOSSIBLE_widened == nil,
        'the clause turned a frame ON somewhere -- it is no longer narrowing-only')
    -- Which half of the family each veto lands in: 2 have a drink (the
    -- decision-side ids' domain), 3 do not (the supply id's domain). Both ends
    -- of owner P2's family are affected, which is why this is one clause in
    -- the shared predicate and not three copies.
    assert(SWEEP_C.vetoed_heal == 2, 'with a heal: ' .. tostring(SWEEP_C.vetoed_heal))
    assert(SWEEP_C.vetoed_dry == 3, 'without: ' .. tostring(SWEEP_C.vetoed_dry))
end

tests['census: the seven askable rows, and the two that must NOT be vetoed'] = function()
    assert(#SWEEP_ROWS == 7, 'expected 7 rows, got ' .. #SWEEP_ROWS)
    local vetoed, spared = {}, {}
    for _, r in ipairs(SWEEP_ROWS) do
        if r.creep then vetoed[#vetoed + 1] = r else spared[#spared + 1] = r end
    end
    assert(#vetoed == 5 and #spared == 2, 'expected 5 vetoed / 2 spared')
    -- Every vetoed row took real damage inside the window; every spared row
    -- took none. A row with dmg == 0 that is still vetoed would mean the
    -- loader and the fixture disagree.
    local lo, hi = math.huge, 0
    for _, r in ipairs(vetoed) do
        assert(r.dmg > 0, r.hero .. ' vetoed with 0 creep damage in the window')
        if r.dmg < lo then lo = r.dmg end
        if r.dmg > hi then hi = r.dmg end
    end
    for _, r in ipairs(spared) do
        assert(r.dmg == 0, r.hero .. ' spared while carrying creep damage in the window')
    end
    assert(lo == 14 and hi == 132,
        'the quoted 14..132 range moved: ' .. lo .. '..' .. hi)
    -- The two spared rows are the two negative controls above, by name.
    local names = {}
    for _, r in ipairs(spared) do names[r.hero] = r.fix end
    assert(names[N1_HERO] == N1_FIX, 'N1 is no longer one of the spared rows')
    assert(names[N2_HERO] == N2_FIX, 'N2 is no longer one of the spared rows')
end

tests['census: per-hit creep damage is a heavy tail, not two clean modes'] = function()
    -- The source comment claims a mass at or below 24 with a thin 25-45 tail.
    -- Stated this way BECAUSE the histogram does not support calling it
    -- bimodal -- the mode is 10-14 and the middle band is populated.
    local mass, tail, max = SWEEP_BAND['mass-le24'], SWEEP_BAND['tail-ge25'],
        SWEEP_BAND['max-hit']
    assert(mass == 256, 'mass rows: ' .. tostring(mass))
    assert(tail == 26, 'tail rows: ' .. tostring(tail))
    assert(max == 45, 'largest single creep hit: ' .. tostring(max))
    -- "Thin" is worth a number: under a tenth of all rows (26 of 282 = 9.2%).
    assert(tail * 10 < mass + tail,
        'the tail is no longer under a tenth of the rows: ' .. tail .. '/' .. (mass + tail))
end

return tests

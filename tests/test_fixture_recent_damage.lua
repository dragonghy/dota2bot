-- [mock fidelity] Every fixture world used to assert "nobody here has been hit
-- by anything recently".
--
-- `tests/mock/bot_api.lua` answers `false` for any uncovered `Is*/Has*/Can*/Was*`
-- getter. `WasRecentlyDamagedByAnyHero` and its three siblings are read at 670
-- sites under `bots/` (527 of them the AnyHero one), so that default was an
-- undeclared world assumption in EVERY fixture, in the same family as the
-- pre-2026-08-19 blanket `HasModifier == false` and the `GetTower` /
-- `GetIncomingTrackingProjectiles` gaps recorded in test_set.md §F.
--
-- Two silent consequences, both of which this file pins:
--   (1) shipped branches that are ENTERED through "am I under fire" were
--       structurally unreachable -- most pointedly `J.ShouldAbandonTpChannel`
--       (this group's gated `tpwatch`, in the eligible set), whose third line is
--       `WasRecentlyDamagedByAnyHero(1.5)`;
--   (2) a test could assert a calm-frame decision on a frame where the hero was
--       in fact being focused by two enemies.
--
-- `observed.damage` could not close it: that block looks FORWARD from t (ground
-- truth about what followed), while these readers look BACKWARD (what the bot
-- already knows at t).
--
-- REAL FRAME: f_260819_222030_jugg_tp_eaten -- game 20260819_222030_slot1 at
-- t=439.5 (7:19), subject juggernaut 313/1155 hp deep in dire territory,
-- 2.5s into a 3.0s TP channel, with viper and lich on him and a dire T1 that
-- hit him at the instant the channel began. Every kind the engine distinguishes
-- (hero / tower) is genuinely present on this one frame.

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')

local tests = {}

local F_EATEN = 'tests/fixtures/f_260819_222030_jugg_tp_eaten.lua'
local F_START = 'tests/fixtures/f_260819_222030_jugg_tp_start.lua'
-- A fixture generated before the recent_damage block existed.
local F_V1 = 'tests/fixtures/f_232228_wk_ownhalf_standoff.lua'

local JUGG = 'npc_dota_hero_juggernaut'
local VIPER = 'npc_dota_hero_viper'
local LICH = 'npc_dota_hero_lich'
local CM = 'npc_dota_hero_crystal_maiden'

local function fixture(path)
    local f = loadfile(path)
    assert(f, 'fixture not loadable: ' .. path)
    return f()
end

-- ---------------------------------------------------------------------------
-- The frame itself: the premises this file rests on are ASSERTED.
-- ---------------------------------------------------------------------------

tests['REAL FRAME: the generator recorded who hit the subject, and when'] = function()
    local fx = fixture(F_EATEN)
    assert(math.abs(fx.time - 439.5) < 1e-9, 'fixture pinned at t=439.5')
    assert(fx.recent_window == 6.0, 'the lookback must be declared; got '
        .. tostring(fx.recent_window))

    local subj
    for _, u in ipairs(fx.units) do if u.name == JUGG then subj = u end end
    assert(subj ~= nil and subj.recent_damage ~= nil,
        'the subject must carry a recent_damage block')

    local kinds, actors, nearest = {}, {}, nil
    local prev = -1
    for _, d in ipairs(subj.recent_damage) do
        kinds[d.kind] = (kinds[d.kind] or 0) + 1
        if d.actor then actors[d.actor] = true end
        assert(d.dt >= prev, 'entries must be sorted by dt ascending (the reader '
            .. 'breaks out of the loop on the first entry past the interval)')
        prev = d.dt
        assert(d.dt > 0 and d.dt <= fx.recent_window,
            'dt is seconds BEFORE t and inside the declared lookback; got ' .. d.dt)
        if nearest == nil then nearest = d.dt end
    end
    assert(kinds.hero and kinds.hero > 0, 'viper and lich were hitting him')
    assert(kinds.tower == 1, 'the dire T1 tagged him once, at the channel start')
    assert(actors[VIPER] and actors[LICH], 'both attackers recorded by name')
    assert(actors[JUGG] == nil, 'self damage is dropped by design')
    assert(nearest <= 0.7, 'the most recent hit is well inside 1.5s; got '
        .. tostring(nearest))
end

-- ---------------------------------------------------------------------------
-- The four readers, on the real frame.
-- ---------------------------------------------------------------------------

tests['the loader answers all four WasRecentlyDamagedBy* readers'] = function()
    local _, bot, heroes = rf.load(F_EATEN)
    assert(bot:WasRecentlyDamagedByAnyHero(1.5) == true,
        'two enemies hit him 0.5s and 0.7s ago')
    assert(bot:WasRecentlyDamagedByTower(1.5) == false,
        'the tower hit was 2.5s ago -- outside a 1.5s query')
    assert(bot:WasRecentlyDamagedByTower(3.0) == true,
        '...and inside a 3.0s one')
    assert(bot:WasRecentlyDamagedByCreep(6.0) == false,
        'no creep touched him in the lookback')
    assert(bot:WasRecentlyDamagedByHero(heroes[VIPER], 1.5) == true,
        'viper specifically')
    assert(bot:WasRecentlyDamagedByHero(heroes[LICH], 1.5) == true,
        'lich specifically')
    assert(bot:WasRecentlyDamagedByHero(heroes[CM], 6.0) == false,
        'his own team mate never hit him -- the per-hero reader is not a '
        .. 'rename of the AnyHero one')
end

tests['the interval is honoured, not rounded to "recently"'] = function()
    local _, bot = rf.load(F_EATEN)
    -- Nearest hero hit is 0.5s ago; the next distinct step up is the tower at
    -- 2.5s. So the AnyHero answer must flip exactly across 0.5.
    assert(bot:WasRecentlyDamagedByAnyHero(0.4) == false,
        'nothing hit him inside 0.4s')
    assert(bot:WasRecentlyDamagedByAnyHero(0.5) == true,
        'the 0.5s-old lich tick is inside a 0.5s query')
end

tests['a hero nobody touched still answers false, for the right reason'] = function()
    local fx = fixture(F_EATEN)
    local quiet
    for _, u in ipairs(fx.units) do
        if u.name == CM then quiet = u end
    end
    assert(quiet ~= nil, 'crystal maiden is in the frame')
    assert(quiet.recent_damage == nil,
        'she was at her own fountain -- the generator omits the empty block')
    local _, _, heroes = rf.load(F_EATEN)
    assert(heroes[CM]:WasRecentlyDamagedByAnyHero(6.0) == false,
        'and the mock default then stands, which is the same answer')
end

-- ---------------------------------------------------------------------------
-- REGRESSION GUARD: fixtures generated before this block keep their old world.
-- ---------------------------------------------------------------------------

tests['REGRESSION: a pre-recent_damage fixture is untouched'] = function()
    local fx = fixture(F_V1)
    assert(fx.recent_window == nil, 'the v1 fixture carries no lookback')
    for _, u in ipairs(fx.units) do
        assert(u.recent_damage == nil,
            u.name .. ' must have no recent_damage block')
    end
    local _, bot = rf.load(F_V1)
    assert(bot:WasRecentlyDamagedByAnyHero(5.0) == false,
        'so every old assertion in this repo keeps the world it was written in')
end

-- ---------------------------------------------------------------------------
-- REVERSE: if the wiring is ever removed, this file must go red rather than
-- quietly return to the blanket-false world.
-- ---------------------------------------------------------------------------

tests['REVERSE: the readers must come from the fixture, not from a stub'] = function()
    local _, bot = rf.load(F_START)
    -- The channel-start frame is 2.4s earlier and the burst had not landed yet,
    -- so the SAME subject in the SAME game answers differently. A stub that
    -- hardcoded `true` (or `false`) cannot produce both.
    assert(bot:WasRecentlyDamagedByAnyHero(0.4) == true,
        'at the cast instant viper had just hit him (0.2s)')
    assert(bot:WasRecentlyDamagedByCreep(6.0) == false, 'still no creep damage')
    local _, eaten = rf.load(F_EATEN)
    assert(eaten:WasRecentlyDamagedByAnyHero(0.4) == false,
        'and 2.4s later the same query answers the other way')
end

return tests

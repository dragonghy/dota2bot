-- [strategy] GH #437 -- `wandbleed` reads a departed hero's DoT tick as "I am
-- being focused". Real-frame validation for the `wandbleed2` narrowing
-- (J.IsWandBleedSourcePresent: a live enemy hero inside 4000).
--
-- WHAT THE DESK SAW (GH #437, W39, frame by frame). seed 2877,
-- spot_20260902_153226 / 20260902_154755_slot4, crystal_maiden t=474.40: HP
-- RISING (30.7% -> 41.0% over the previous three seconds, plus a +225 heal on
-- the same tick), mana 97.9%, nearest visible enemy 8381 away -- and six wand
-- charges spent, because a venomancer who had long since left was still
-- ticking 13 a second on her. The other attributable trigger in that wave
-- (slardar, an enemy at 1497, five charges, survived) is the case the id
-- exists for. 1 of 2.
--
-- WHAT THIS FILE BUYS AND WHAT IT DOES NOT, before the assertions rather than
-- after them. That exact frame is NOT in this repo -- it lives in a batch
-- timeline, and freezing it into tests/fixtures/ is the desk's baton on GH
-- #437. What the local corpus does hold is a real frame for each answer of the
-- predicate, and -- this is the part that moved the constant -- the measurement
-- that picks the constant at all:
--
--   * KEEP, the case the id exists for: juggernaut t=439.5, 313/1155 HP
--     (27.1%), lich 590 away and viper 615 away, both having hit him inside
--     the last second.
--   * KEEP, and the reason this ring is not the 2000 the issue proposed:
--     crystal_maiden at 60/1224 HP (4.9%) carrying modifier_maledict from a
--     witch doctor 3011.7 away -- a live hero killing her at range. At 2000
--     the narrowing would take the wand away from her.
--   * BLOCK, the motivating shape reproduced locally: viper (97.7%) and zuus
--     (49.9%) at t=599.5, both taking fresh damage from an ember spirit who is
--     DEAD, with no live enemy inside 8195 / 8382.
--
-- What it CANNOT buy: the desk's residue comes from a caster who walked away,
-- the corpus's comes from a caster who died. Same predicate, same answer, but
-- no local frame carries the first kind -- so this file does not witness the
-- frame that motivated the change. Do not read it as if it did.
--
-- ONE MORE CAVEAT, inherited from tests/test_replay_181441_wand_limbo.lua: the
-- dumper does not record item charges, so a charge count is the one number
-- that would have to come from outside a frame. Nothing here needs one -- the
-- narrowing is a pure position predicate -- and no test below sets one.

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')
-- Every corpus number below goes through this module rather than through an
-- equality on the live fixture count: appending a fixture may only ADD to a
-- per-fixture sum, and GH #106 / #127 are what happens when a census pins the
-- corpus size instead. The one number that is genuinely a ceiling -- how far a
-- LIVE attacker gets -- is asserted as one, because the shipped 4000 is read
-- off it and a future fixture beyond it must go red.
local cs = require('corpus_scale')

local LIVE_FIRE = 'tests/fixtures/f_260819_222030_jugg_tp_eaten.lua'
local EMPTY_RING = 'tests/fixtures/f_260819_142047_zuus_ult_denied.lua'
local RANGED_KILL = 'tests/fixtures/f_260820_043524_wd_defend_alone.lua'
local DEAD_CASTER = 'tests/fixtures/f_260820_043120_viper_defend_paired.lua'

local tests = {}

local function armed(J, ids)
    J.IsSoakCandidate = function(id)
        for _, want in ipairs(ids) do
            if id == want then return true end
        end
        return false
    end
end

local function nearest_enemy(bot, heroes)
    local best = nil
    for _, h in pairs(heroes) do
        if h ~= bot and h:GetTeam() ~= bot:GetTeam() and h:IsAlive() then
            local d = GetUnitToUnitDistance(bot, h)
            if best == nil or d < best then best = d end
        end
    end
    return best
end

-- Raw corpus read, off the fixture tables themselves (no mock). Two uses: it
-- is the census the assertions ratchet, and it is what finds the frames the
-- mock is then loaded on. Reading the TABLE rather than the file text is
-- deliberate -- the first cut of this census was a python regex over the same
-- files and it under-read the denominator by 43% (563 of 993 hero-frames, 6 of
-- 80 fresh-damage frames) while looking exactly like a clean reading. The
-- frames it dropped included both residue frames below, i.e. the entire
-- witness for this change.
local function corpus()
    local p = assert(io.popen('ls tests/fixtures'))
    local files = {}
    for f in p:lines() do
        if f:match('^f_.*%.lua$') then files[#files + 1] = 'tests/fixtures/' .. f end
    end
    p:close()
    table.sort(files)

    local function dist(a, b)
        local dx, dy = a.x - b.x, a.y - b.y
        return math.sqrt(dx * dx + dy * dy)
    end

    local out = { files = #files, alive_frames = 0, fresh_frames = {}, pairs = {} }
    for _, path in ipairs(files) do
        local fx = dofile(path)
        local by = {}
        for _, u in ipairs(fx.units) do by[u.name] = u end
        for _, u in ipairs(fx.units) do
            if u.alive and (u.max_hp or 0) > 0 then
                out.alive_frames = out.alive_frames + 1
                local fresh, seen, live_attackers = false, {}, 0
                for _, d in ipairs(u.recent_damage or {}) do
                    if d.kind == 'hero' and d.dt <= 2.0 then
                        fresh = true
                        if d.actor and not seen[d.actor] then
                            seen[d.actor] = true
                            local a = by[d.actor]
                            if a ~= nil then
                                if a.alive then live_attackers = live_attackers + 1 end
                                out.pairs[#out.pairs + 1] = {
                                    d = dist(u, a), alive = a.alive,
                                    path = path, victim = u.name, actor = d.actor,
                                }
                            end
                        end
                    end
                end
                if fresh then
                    out.fresh_frames[#out.fresh_frames + 1] = {
                        path = path, name = u.name, live_attackers = live_attackers,
                    }
                end
            end
        end
    end
    return out
end

tests['ground truth: the live-fire frame is jugg at 27.1% HP with lich 590 away, hitting him'] = function()
    local J, bot, heroes, fx = rf.load(LIVE_FIRE)
    assert(fx.self == 'npc_dota_hero_juggernaut', 'subject')
    assert(fx.time == 439.5, 'frame time')
    assert(bot:GetHealth() == 313 and bot:GetMaxHealth() == 1155, 'real HP')
    assert(bot:GetHealth() / bot:GetMaxHealth() < 0.45,
        'the wandbleed HP leg really holds on this frame')
    assert(bot:FindItemSlot('item_magic_wand') >= 0, 'he really carries a wand')
    -- The leg this whole issue is about: TRUE here, and for the right reason.
    assert(bot:WasRecentlyDamagedByAnyHero(2.0) == true, 'fresh hero damage')
    local d = nearest_enemy(bot, heroes)
    assert(d > 585 and d < 595, 'nearest enemy really is ~590, got ' .. tostring(d))
    assert(GetUnitToUnitDistance(bot, heroes['npc_dota_hero_lich']) < 600, 'lich is on him')
    assert(GetUnitToUnitDistance(bot, heroes['npc_dota_hero_viper']) < 700, 'viper is on him')
end

tests['gate OFF (not turbo): answers true, blocks nothing'] = function()
    local J, bot = rf.load(EMPTY_RING)
    armed(J, { 'wandbleed', 'wandbleed2' })
    GetGameMode = function() return 1 end -- set after load(); install() forces turbo
    assert(J.IsWandBleedSourcePresent(bot) == true,
        'outside turbo the narrowing must not be in force')
end

tests['gate OFF (turbo, wandbleed2 not armed): answers true, blocks nothing'] = function()
    local J, bot = rf.load(EMPTY_RING)
    armed(J, { 'wandbleed' })
    assert(J.IsWandBleedSourcePresent(bot) == true,
        'arming wandbleed alone must leave its domain exactly as it is today')
end

tests['gate ON: the live-fire frame survives the narrowing (negative control)'] = function()
    local J, bot = rf.load(LIVE_FIRE)
    armed(J, { 'wandbleed', 'wandbleed2' })
    assert(J.IsWandBleedSourcePresent(bot) == true,
        'two enemies inside 700 are exactly the case the id exists for')
    -- Position only: it must not start reading HP through the back door.
    rawget(bot, '__spec').GetHealth = 1100
    assert(J.IsWandBleedSourcePresent(bot) == true, 'position only')
end

-- The frame that moved the constant from the issue's 2000 to 4000.
tests['gate ON: a live hero killing her from 3011 still counts (the maledict frame)'] = function()
    local J, bot, heroes = rf.load(RANGED_KILL, 'npc_dota_hero_crystal_maiden')
    assert(bot:GetHealth() == 60 and bot:GetMaxHealth() == 1224, 'real HP: 4.9%')
    assert(bot:WasRecentlyDamagedByAnyHero(2.0) == true, 'she is being hit right now')
    assert(bot:HasModifier('modifier_maledict'), 'and this is what is doing it')
    local wd = heroes['npc_dota_hero_witch_doctor']
    local d = GetUnitToUnitDistance(bot, wd)
    assert(d > 3000 and d < 3025, 'the witch doctor really is ~3011 away, got ' .. tostring(d))
    assert(wd:IsAlive(), 'and he is alive -- this is a live threat, not residue')
    armed(J, { 'wandbleed', 'wandbleed2' })
    assert(J.IsWandBleedSourcePresent(bot) == true,
        'at 60 HP under a live ranged kill the wand must NOT be taken away')
    -- Stated as an assertion because it is the whole argument for the number:
    -- the issue's suggested 2000 would have blocked this frame.
    assert(#J.GetNearbyHeroes(bot, 2000, true, BOT_MODE_NONE) == 0,
        'and a 2000 ring would have been empty here')
end

tests['gate ON: fresh damage from a DEAD ember spirit is residue (both frames)'] = function()
    for _, subject in ipairs({ 'npc_dota_hero_zuus', 'npc_dota_hero_viper' }) do
        local J, bot, heroes, fx = rf.load(DEAD_CASTER, subject)
        assert(fx.time == 599.5, 'frame time')
        assert(bot:WasRecentlyDamagedByAnyHero(2.0) == true,
            subject .. ': the shipped wandbleed leg is TRUE here')
        local ember = heroes['npc_dota_hero_ember_spirit']
        assert(ember:IsAlive() == false, 'and the only thing that hit him is dead')
        local d = nearest_enemy(bot, heroes)
        assert(d > 8000, subject .. ': no live enemy inside 8000, got ' .. tostring(d))
        armed(J, { 'wandbleed', 'wandbleed2' })
        assert(J.IsWandBleedSourcePresent(bot) == false,
            subject .. ': nobody alive is anywhere near -- this is residue')
    end
end

tests['ground truth: the empty-ring frame is zuus at 40.5% HP with nobody inside 7478'] = function()
    local J, bot, heroes, fx = rf.load(EMPTY_RING)
    assert(fx.self == 'npc_dota_hero_zuus', 'subject')
    assert(bot:GetHealth() == 369 and bot:GetMaxHealth() == 911, 'real HP')
    assert(bot:GetHealth() / bot:GetMaxHealth() < 0.45, 'the wandbleed HP leg holds here too')
    assert(bot:FindItemSlot('item_magic_wand') >= 0, 'wand in the inventory')
    local d = nearest_enemy(bot, heroes)
    assert(d > 7400 and d < 7550, 'nearest enemy really is ~7478, got ' .. tostring(d))
    -- DECLARED: nothing hit him, so the shipped wandbleed leg is false here and
    -- the narrowing is not what keeps the branch shut on this frame.
    assert(bot:WasRecentlyDamagedByAnyHero(2.0) == false,
        'no fresh hero damage on this frame -- see the header')
    armed(J, { 'wandbleed', 'wandbleed2' })
    assert(J.IsWandBleedSourcePresent(bot) == false, 'empty ring answers false')
end

-- The corpus census, with its denominators. This is the local answer to "what
-- does the narrowing take away".
tests['corpus: 78 of the 80 fresh-damage frames keep their answer, and the 2 blocked have no live attacker'] = function()
    local c = corpus()
    cs.corpus(c.files, 'live fixture corpus')
    cs.ratchet(c.alive_frames, 993, 'alive hero-frames')
    cs.ratchet(#c.fresh_frames, 80, 'frames with fresh hero damage')
    cs.ratchet(#c.pairs, 101, 'victim/attacker pairs with fresh hero damage')

    -- The ruler the constant is read off: how far away a LIVE attacker gets.
    local max_live, n_dead = 0, 0
    for _, pr in ipairs(c.pairs) do
        if pr.alive then
            if pr.d > max_live then max_live = pr.d end
        else
            n_dead = n_dead + 1
        end
    end
    -- Registered at 3011.7 (crystal_maiden under maledict from 3011 away). It
    -- may rise with the corpus -- but not past the shipped ring, because the
    -- ring's whole justification is that it clears this number.
    cs.ratchet(math.floor(max_live), 3011, 'furthest LIVE attacker')
    cs.ceiling(math.floor(max_live), 3999, 'furthest LIVE attacker vs the shipped 4000 ring')
    cs.ratchet(n_dead, 2, 'pairs whose attacker is dead')

    -- Every one of those 80 real frames, through the shipped predicate.
    local blocked = {}
    for _, hit in ipairs(c.fresh_frames) do
        local J, bot = rf.load(hit.path, hit.name)
        armed(J, { 'wandbleed', 'wandbleed2' })
        if J.IsWandBleedSourcePresent(bot) ~= true then
            blocked[#blocked + 1] = hit
            -- The only frames it may take are frames where NOTHING ALIVE hit
            -- the bot. A blocked frame with a live attacker would mean the ring
            -- is cutting into real fire, which is the failure this file exists
            -- to catch.
            assert(hit.live_attackers == 0,
                'blocked a frame with a LIVE attacker: ' .. hit.path .. ' / ' .. hit.name)
        end
    end
    cs.ratchet(#blocked, 2, 'frames the narrowing blocks')
    -- The zero stays an equality on purpose (corpus_scale's own carve-out): a
    -- blocked frame with a live attacker MUST turn this red the day the corpus
    -- grows one, because that is the finding this file is arguing from.
    for _, hit in ipairs(blocked) do
        assert(hit.live_attackers == 0, 'blocked with a live attacker: ' .. hit.name)
    end
end

local GEN = (function()
    local fh = assert(io.open('bots/ability_item_usage_generic.lua', 'r'))
    local src = fh:read('*a'); fh:close()
    return src
end)()

local JMZ = (function()
    local fh = assert(io.open('bots/FunLib/jmz_func.lua', 'r'))
    local src = fh:read('*a'); fh:close()
    return src
end)()

tests['source: the narrowing is a conjunct of the wandbleed branch, not a separate rule'] = function()
    local at = GEN:find("if J.IsModeTurbo() and J.IsSoakCandidate('wandbleed')", 1, true)
    assert(at ~= nil, 'the wandbleed branch moved')
    local cond = GEN:sub(at, GEN:find('\n\tthen\n', at, true))
    -- Every leg the branch shipped with is still there ...
    assert(cond:find('nHPrate < 0.45', 1, true), 'HP leg')
    assert(cond:find('nCharges >= 5', 1, true), 'charge leg')
    assert(cond:find('bot:WasRecentlyDamagedByAnyHero(2.0)', 1, true), 'damage leg')
    -- ... and the narrowing joins them with `and`, i.e. it can only ever
    -- REMOVE frames from this branch, never add one.
    assert(cond:find('and J.IsWandBleedSourcePresent( bot )', 1, true),
        'the narrowing must be a conjunct of this branch')
end

tests['source: the gate fails OPEN, which is why promoting it means deleting the line'] = function()
    local at = JMZ:find('function J.IsWandBleedSourcePresent( bot )', 1, true)
    assert(at ~= nil, 'the helper moved')
    local body = JMZ:sub(at, JMZ:find('\nend\n', at, true))
    assert(body:find('if not J.IsModeTurbo() then return true end', 1, true),
        'turbo-only, and non-turbo must be the NO-OP answer')
    assert(body:find("if not J.IsSoakCandidate( 'wandbleed2' ) then return true end", 1, true),
        'unarmed must be the NO-OP answer -- a narrowing fails open')
    assert(body:find('J.GetNearbyHeroes( bot, 4000, true, BOT_MODE_NONE ) >= 1', 1, true),
        'the armed answer is "a live enemy inside 4000"')
    -- The trap this pins: a promoted id is in no armed string, so a promote
    -- done by editing soak_side.lua alone would freeze this helper at TRUE --
    -- the narrowing silently un-narrows on the day it is promoted, and nothing
    -- goes red. ('pullcad' inverted: there a promoted id froze a lever FALSE.)
    assert(JMZ:find("PROMOTING 'wandbleed2' MEANS DELETING THE GATE LINE", 1, true),
        'that trap must stay written where the promoter will read it')
end

return tests

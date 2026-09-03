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
--   * BLOCK, the frame the issue was written from, frozen 2026-09-03 by the
--     replay desk under the director's ruling on GH #437 (owed_executions.json
--     :wandbleed2_cond_a_frame): f_260902_154755_cm_wandbleed_residue.lua,
--     crystal_maiden t=473.5, HP 41.0% and RISING at her own fountain, mana
--     97.9%, nearest enemy 8381 -- and one second later she spends six charges,
--     because a venomancer 10138 away is still ticking poison sting on her.
--
-- That last one closes what the paragraph here used to say could not be bought:
-- the desk's residue comes from a caster who WALKED AWAY, the corpus's from a
-- caster who DIED. Both are now in the corpus, and the difference between them
-- is not cosmetic -- it falsified an invariant this file used to assert.
--
-- WHAT THE NEW FRAME BROKE, and why the replacement is stronger rather than
-- looser. The census below used to assert two things that were true only
-- because every residue frame it had came from a DEAD caster:
--
--   (1) `blocked => the bot had no live attacker at all`, and
--   (2) `the furthest LIVE attacker in the corpus (3011.7) sits inside the
--        shipped 4000 ring`, read as "the ring cuts nothing real".
--
-- A departed caster is alive. Both went red on the new fixture, and (2) is the
-- one that matters: "live attacker" was standing in for "live threat", and a
-- venomancer who left is the counter-example. What the corpus actually shows is
-- a GAP -- live attackers on frames the narrowing KEEPS reach 3011.7; the one
-- live attacker on a frame it BLOCKS is 10138.1 away; nothing lies between, and
-- the shipped 4000 sits in that empty band. That is the argument for the
-- constant, and it is now stated as two assertions with the band between them
-- (a ceiling on the kept side, a floor on the blocked side) instead of one
-- assertion that happened to hold while every residue caster was a corpse.
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
local GONE_CASTER = 'tests/fixtures/f_260902_154755_cm_wandbleed_residue.lua'

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
                local live_dists = {}
                for _, d in ipairs(u.recent_damage or {}) do
                    if d.kind == 'hero' and d.dt <= 2.0 then
                        fresh = true
                        if d.actor and not seen[d.actor] then
                            seen[d.actor] = true
                            local a = by[d.actor]
                            if a ~= nil then
                                if a.alive then
                                    live_attackers = live_attackers + 1
                                    live_dists[#live_dists + 1] = dist(u, a)
                                end
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
                        live_dists = live_dists,
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

-- The frame GH #437 was written from, and the one the ruling ordered frozen.
-- Everything here is read off the real frame; the charge count is the one number
-- that is not (the dumper does not record charges), so it is not asserted -- the
-- +90 magic_wand heal one second later, in the same combat log, is what says six.
tests['gate ON: the desk frame -- a LIVE venomancer 10138 away is still residue'] = function()
    local J, bot, heroes, fx = rf.load(GONE_CASTER)
    assert(fx.self == 'npc_dota_hero_crystal_maiden', 'subject')
    assert(fx.time == 473.5, 'frame time: the last frame before the wand goes off at 474.4')
    assert(bot:GetHealth() == 347 and bot:GetMaxHealth() == 846, 'real HP: 41.0%')
    assert(bot:GetHealth() / bot:GetMaxHealth() < 0.45,
        'the shipped wandbleed HP leg holds -- 41.0% is under 45%, which is why it fires')
    assert(bot:GetMana() / bot:GetMaxMana() > 0.97, 'and she is at 97.9% mana: nothing to burn it on')
    assert(bot:FindItemSlot('item_magic_wand') >= 0, 'wand in the inventory')
    -- The leg that misfires: fresh HERO damage, from a hero who is not there.
    assert(bot:WasRecentlyDamagedByAnyHero(2.0) == true,
        'the shipped wandbleed damage leg is TRUE here -- this is the whole issue')
    assert(bot:HasModifier('modifier_venomancer_poison_sting'), 'and this is what is doing it')
    assert(bot:HasModifier('modifier_fountain_aura_buff'),
        'she is standing in her own fountain while it ticks')
    local veno = heroes['npc_dota_hero_venomancer']
    assert(veno:IsAlive(), 'the caster is ALIVE -- this is the case the dead-ember frames cannot make')
    local dv = GetUnitToUnitDistance(bot, veno)
    assert(dv > 10100 and dv < 10175, 'and he is ~10138 away, got ' .. tostring(dv))
    local d = nearest_enemy(bot, heroes)
    assert(d > 8350 and d < 8410, 'nearest enemy of any kind is ~8381, got ' .. tostring(d))
    -- The two readings the ruling names (owed_executions.json:wandbleed2_cond_a_frame).
    armed(J, { 'wandbleed', 'wandbleed2' })
    assert(#J.GetNearbyHeroes(bot, 4000, true, BOT_MODE_NONE) == 0,
        'zero live enemies inside the shipped 4000 ring')
    assert(J.IsWandBleedSourcePresent(bot) == false,
        'nobody alive is within reach of her -- the wand must not fire on a departed DoT')
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
tests['corpus: 78 of the 81 fresh-damage frames keep their answer, and the shipped ring sits in the gap'] = function()
    local c = corpus()
    cs.corpus(c.files, 'live fixture corpus')
    -- Re-measured 2026-09-03, after f_260902_154755_cm_wandbleed_residue.lua:
    -- 1012 alive hero-frames, 81 with fresh hero damage, 102 victim/attacker
    -- pairs (was 993 / 80 / 101).
    cs.ratchet(c.alive_frames, 1012, 'alive hero-frames')
    cs.ratchet(#c.fresh_frames, 81, 'frames with fresh hero damage')
    cs.ratchet(#c.pairs, 102, 'victim/attacker pairs with fresh hero damage')

    local n_dead = 0
    for _, pr in ipairs(c.pairs) do
        if not pr.alive then n_dead = n_dead + 1 end
    end
    cs.ratchet(n_dead, 2, 'pairs whose attacker is dead')

    -- Every one of those real frames, through the shipped predicate. The two
    -- populations are read SEPARATELY, because that is the correction the desk
    -- frame forced: a live attacker is not the same thing as a live threat, so
    -- "the furthest live attacker anywhere" is not a ruler for the ring.
    local blocked, kept_live_max, blocked_live_min = {}, 0, math.huge
    for _, hit in ipairs(c.fresh_frames) do
        local J, bot = rf.load(hit.path, hit.name)
        armed(J, { 'wandbleed', 'wandbleed2' })
        local keep = J.IsWandBleedSourcePresent(bot)
        if keep ~= true then blocked[#blocked + 1] = hit end
        for _, d in ipairs(hit.live_dists) do
            if keep then
                if d > kept_live_max then kept_live_max = d end
            else
                if d < blocked_live_min then blocked_live_min = d end
                -- The failure this file exists to catch: the ring cutting into
                -- real fire. A live attacker INSIDE the ring on a frame the
                -- narrowing takes would be exactly that, and it is also an
                -- independent cross-check -- this distance comes from the
                -- fixture table, the verdict from the shipped helper's own
                -- GetNearbyHeroes read.
                assert(d >= 4000, string.format(
                    'blocked a frame with a LIVE attacker %.1f INSIDE the 4000 ring: %s / %s',
                    d, hit.path, hit.name))
            end
        end
    end
    -- Was 2 (both dead-ember residue); 3 since the desk frame, whose attacker is
    -- alive and 10138.1 away.
    cs.ratchet(#blocked, 3, 'frames the narrowing blocks')

    -- The two KINDS of residue, counted separately, because "the attacker is
    -- dead" and "the attacker left" are the two ways a frame gets here and the
    -- distance floor above can only see the second. Without this split, a census
    -- that stopped asking whether an attacker is alive would keep passing: the
    -- dead ember spirit is 8195/8382 away, i.e. outside the ring as well.
    local dead_only, live_far = 0, 0
    for _, hit in ipairs(blocked) do
        if hit.live_attackers == 0 then dead_only = dead_only + 1 else live_far = live_far + 1 end
    end
    cs.ratchet(dead_only, 2, 'blocked frames whose attackers are all DEAD')
    cs.ratchet(live_far, 1, 'blocked frames with a LIVE attacker outside the ring')

    -- The two halves of the argument for 4000, with the empty band between them:
    --   kept side, registered 3011.7 -- crystal_maiden under maledict from a
    --     witch doctor 3011 away, the furthest a live attacker gets on a frame
    --     the narrowing keeps. It may rise with the corpus, but not past the
    --     ring: that would mean the ring is about to cut real fire.
    --   blocked side, registered 10138.1 -- the nearest live attacker on any
    --     blocked frame, i.e. the margin the narrowing actually enjoys today
    --     (2.5x the ring). Asserted as a floor rather than a ratchet on purpose:
    --     a min over a growing corpus may legitimately FALL, and a residue
    --     caster who only walked 4200 away is a real frame this file should
    --     accept. What it may never do is fall inside the ring.
    cs.ceiling(math.floor(kept_live_max), 3999, 'furthest LIVE attacker on a KEPT frame')
    assert(math.floor(kept_live_max) >= 3011, string.format(
        'furthest LIVE attacker on a KEPT frame FELL to %.1f (registered 3011.7) -- the '
        .. 'maledict frame is the reason the ring is 4000 and not 2000; re-read the finding',
        kept_live_max))
    assert(blocked_live_min >= 4000, string.format(
        'nearest LIVE attacker on a BLOCKED frame is %.1f, inside the shipped 4000 ring',
        blocked_live_min))
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

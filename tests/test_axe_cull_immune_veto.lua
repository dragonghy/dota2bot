-- [hero] GH #146 / `axecull` -- the Culling Blade execute branch refuses a
-- spell-immune target, and Culling Blade pierces spell immunity.
--
-- THE DEFECT
-- ----------
-- bots/BotLib/hero_axe.lua X.ConsiderR has exactly one firing branch, and its
-- guard list carried
--
--     and not npcEnemy:IsMagicImmune() --V BUG
--
-- `--V BUG` is the ONLY occurrence of that marker anywhere under bots/ (grep,
-- 2026-08-23): an upstream author saw this and left it. The datafeed agrees with
-- him. axe_culling_blade is `bkbpierce: "Yes"`, damage type Pure
-- (odota/dotaconstants build/abilities.json package 10.8.0, read 2026-08-23 --
-- the same source the 2026-08-23T09:50Z round anchored the duplicate-component
-- laws on). Killing a hero through BKB is the ability's whole point; the shipped
-- bot declines exactly then.
--
-- This is not the stale-constant lever in tests/test_axe_culling_threshold_preflight.lua
-- and it is not the +200 ring lever registered in that file's section 3. Three
-- separate levers now live in this one branch; only this one is written, and it
-- is written GATED (`axecull`, turbo-only, unarmed).
--
-- WHY IT WAS WRITTEN AND THE THRESHOLD LEVER WAS NOT
-- --------------------------------------------------
-- The threshold lever died as NARROW-BAND-UNMEASURABLE: its domain is a 25-point
-- strip on a continuous quantity, which a frame corpus cannot size at any
-- realistic corpus size. This one is an EXISTENCE question ("was the target
-- spell-immune"), which a corpus can size in principle and an event-side
-- detector can size cheaply. What stops the reading here is SUPPLY, and section 2
-- measures the supply rather than asserting it:
--
--     104 fixture frames. THREE spell-immune hero-instants in the whole corpus
--     (all `modifier_juggernaut_blade_fury`, all in games with no Axe in them),
--     and ZERO Black King Bars in any item slot of any hero at any instant.
--     26 frames carry an Axe; 20 have Culling learned, off cooldown and paid for
--     (blocked: 4 unlearned, 1 cooldown, 1 mana -- the same funnel the threshold
--     pre-flight measured). The (ready Axe) x (immune enemy) pair count is 0, so
--     the domain count is 0 for a reason that says nothing about how often this
--     happens in a game.
--
-- The counts above are a SNAPSHOT taken 2026-08-23, and the ratchets on them in
-- section 2 are one-sided because the corpus is meant to grow. Measured
-- 2026-08-31: 107 frames, 28 Axe units, immune instants unchanged at 3, Black
-- King Bars in tests/fixtures/ still 0. Those four are pinned live in
-- tests/test_axe_bkb_supply_staged_frame.lua section 4, so growth stays
-- distinguishable from drift without re-deriving them here.
--
-- Recorded as SUPPLY-STARVED-IN-CORPUS, not as an empty domain. The distinction
-- is the stream's Y.2 rule (a desk or fixture read can show EMPTY, never RARE)
-- with the extra note that here it cannot honestly show EMPTY either: the corpus
-- was cut at instants between 0:51 and 11:30 of turbo games that were themselves
-- capped at 10 game-minutes, and a Black King Bar is a 4050-gold item. GH #108
-- raised the batch cap to 25 game-minutes; the supply this scan reports is from
-- BEFORE that change, which is precisely why the sizing has to be bought on a
-- wave (iterations/queue.json: hero-9) and not argued from here.
--
-- THE FIVE/SEVEN KNOWN COLLAPSE MODES, checked at the desk (section 3 ratchets
-- each one so the reasoning cannot rot):
--   * UPSTREAM-SIBLING (wkqaim / liondrain): no. One firing branch in the whole
--     function, and nothing above it in X.SkillsComplement -- ConsiderR is that
--     function's FIRST consumer.
--   * DOWNSTREAM-DOMINATED (WK Lever A): no. Nothing runs after the branch.
--   * CONSUMER-SIDE-UNREACHABLE (zusultx): no. desire > 0 is turned into
--     ActionQueue_UseAbilityOnEntity( abilityR, target ) on the next line.
--   * A STRONGER GUARD ALREADY DOING IT (wkreincarnmp): no. This clause IS the
--     only guard on immunity; note X.HasSpecialModifier does NOT list
--     modifier_black_king_bar_immune, so nothing else covers the frames.
--   * CARRIER-UNAVAILABLE (Tiny): no. Axe is a focus hero and in the soak pool.
--   * SUPPLY-STARVED: UNKNOWN, and that is the honest verdict. Section 2 is the
--     tripwire that will say so the day it changes.
--
-- THE COST SIDE
-- -------------
-- Every other guard stays: aegis, invulnerability, X.HasSpecialModifier
-- (Linken's / Lotus / Aeon Disk / Winter's Curse / spell shield / illusion), and
-- the health test. The frames this opens are exactly "a visible enemy hero inside
-- the branch's 375u ring whose effective health is already below the execute
-- threshold, who happens to be spell-immune" -- on which the cast is a kill and
-- the kill refunds Culling's cooldown. That bounded downside is why this lever is
-- worth a wave slot at all; it is NOT a claim that the wave will find frames.
--
-- HONEST BOUNDS -- READ BEFORE QUOTING ANY NUMBER FROM HERE
--   * The immune-target case in section 1 is a COUNTERFACTUAL: a real frame with
--     ONE field flipped (skywrath_mage made spell-immune). No frame of an Axe
--     next to a spell-immune enemy exists in the corpus, so there is nothing else
--     to pin against. Precedent and its label: f_232320_wk_od_burst, where the WK
--     round moved one integer (hero level 6 -> 7) on a real frame. Everything
--     else on the frame -- positions, health, cooldowns, mana, modifiers,
--     abilities -- is the replay's.
--   * The corpus immunity scan uses the SAME eleven modifier names
--     bots/FunLib/aba_global_overrides.lua feeds its IsMagicImmune override,
--     read out of that file at test time rather than copied, so the two cannot
--     drift apart silently.
--   * The datafeed anchor (bkbpierce, Pure, cast range 175, damage 275/375/475)
--     is RECORDED. This test cannot reach the network.
--   * Corpus counts come from `dofile` on each fixture, never from a regex over
--     the files -- the threshold pre-flight's first pass under-counted the Axe
--     frames 10 to 26 exactly that way.
--   * Section 2's rings ignore vision, which makes them UPPER bounds; a "nothing
--     reaches it" claim measured against an over-large ring errs safe.

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')

local SRC = 'bots/BotLib/hero_axe.lua'
local OVERRIDES = 'bots/FunLib/aba_global_overrides.lua'
local FIXTURE = 'tests/fixtures/f_260820_043637_axe_ring_close.lua'
local AXE = 'npc_dota_hero_axe'
local SKY = 'npc_dota_hero_skywrath_mage'
local CULLING = 'axe_culling_blade'

-- Recorded 2026-08-23 from odota/dotaconstants build/abilities.json (10.8.0).
local R_DAMAGE = { 275, 375, 475 }
local R_MANA = { 100, 125, 150 }
local RING = 175 + 200      -- the branch iterates GetAroundEnemyHeroList(cast+200)
local DESIRE_HIGH = 0.75    -- BOT_ACTION_DESIRE_HIGH

local tests = {}

local function read_file(path)
    local fh = assert(io.open(path, 'r'), 'cannot open ' .. path)
    local body = fh:read('*a')
    fh:close()
    return body
end

local function consider_r_body(src)
    local from = src:find('function X%.ConsiderR%s*%(%s*%)')
    assert(from, 'X.ConsiderR not found in ' .. SRC)
    local rest = src:sub(from)
    local to = rest:find('\nfunction X%.')
    return to and rest:sub(1, to) or rest
end

--- Load the real frame, optionally arm `axecull`, optionally flip skywrath's
--- spell immunity, then drive the REAL X.ConsiderR.
--- Returns desire, target handle, motive, plus the world for further assertions.
local function bid(bArmed, bImmune, bNonTurbo)
    local J, bot, heroes, fx = rf.load(FIXTURE)
    J.IsSoakCandidate = function(id) return bArmed and id == 'axecull' end
    if bNonTurbo then
        -- rf.load's install() forces turbo; undo it AFTER load, exactly as
        -- tests/test_replay_260819_cm_r_range.lua does.
        GetGameMode = function() return 1 end
    end
    if bImmune then
        rawget(heroes[SKY], '__spec').IsMagicImmune = true  -- MUTATION, see HONEST BOUNDS
    end
    local X = rf.load_hero('axe')
    local d, t, m = X.ConsiderR()
    return d, t, m, J, bot, heroes, fx, X
end

-- ---------------------------------------------------------------- section 1 --
-- The real frame, and the one-field counterfactual on it.

tests['ground truth: 6:33, skywrath on 221 hp stands 188u from a ready Culling'] = function()
    local _, _, _, _, bot, heroes, fx = bid(false, false)
    assert(fx.self == AXE and fx.time == 393.4, 'the decision instant')
    assert(bot:GetLevel() == 6 and bot:GetMana() == 286, 'real Axe state')
    local r = bot:GetAbilityByName(CULLING)
    assert(r:GetLevel() == 1, 'Culling really is rank 1 here')
    assert(r:IsFullyCastable(), 'and really is off cooldown and affordable')
    assert(bot:GetMana() >= R_MANA[1], 'mana covers the recorded rank-1 cost')

    local sky = heroes[SKY]
    assert(sky:GetTeam() ~= bot:GetTeam(), 'skywrath is the enemy on this frame')
    assert(sky:GetHealth() == 221 and sky:GetMaxHealth() == 940, 'real health')
    assert(sky:GetHealth() < 150 + 100 * 1,
        'and it is below even the shipped (stale) execute threshold of 250 -- '
        .. 'this is what makes the frame a FIRING frame rather than a near miss')
    local d = GetUnitToUnitDistance(bot, sky)
    assert(d > 187 and d < 189, 'skywrath really is ~188u away, got ' .. tostring(d))
    assert(d <= RING, 'inside the branch effective ring of ' .. RING)
end

tests['ground truth: nobody on this frame is spell-immune -- the mutation is the only change'] = function()
    local _, _, _, _, _, heroes = bid(false, false)
    for name, h in pairs(heroes) do
        assert(h:IsMagicImmune() == false,
            name .. ' reads spell-immune on the untouched frame; the counterfactual '
            .. 'below would then not be isolating what it claims to isolate')
    end
end

tests['shipped path: the branch fires on the untouched frame'] = function()
    local d, t = bid(false, false)
    assert(d == DESIRE_HIGH, 'shipped desire, got ' .. tostring(d))
    assert(t ~= nil and t:GetUnitName() == SKY, 'and it culls skywrath')
end

tests['gate OFF: identical to the shipped path on the untouched frame'] = function()
    -- Not a tautology: it is the anti-regression half. Whatever the gate does, it
    -- must do NOTHING on a frame where nobody is immune -- which is every frame in
    -- this corpus and the overwhelming majority of frames in a game.
    local dOff, tOff = bid(false, false)
    local dOn, tOn = bid(true, false)
    assert(dOn == dOff, 'armed desire drifted on a non-immune frame: '
        .. tostring(dOn) .. ' vs ' .. tostring(dOff))
    assert(tOn:GetUnitName() == tOff:GetUnitName(), 'armed target drifted')
end

tests['COUNTERFACTUAL, gate OFF: a spell-immune skywrath is refused -- the defect'] = function()
    local d, t = bid(false, true)
    assert(d == 0, 'shipped code declines the guaranteed kill, got ' .. tostring(d))
    assert(t == nil, 'and names no target')
end

tests['COUNTERFACTUAL, gate ON: the same frame culls through the immunity'] = function()
    local d, t, m = bid(true, true)
    assert(d == DESIRE_HIGH, 'armed desire, got ' .. tostring(d))
    assert(t ~= nil and t:GetUnitName() == SKY, 'and the target is the immune skywrath')
    assert(type(m) == 'string' and m:find('R%-'), 'motive still reported, got ' .. tostring(m))
end

tests['gate ON but NOT turbo: still refused'] = function()
    -- The turbo half of the gate carries the whole "shipped normal-mode behaviour
    -- is unchanged" promise; without this case a gate could be turbo-less and every
    -- other test here would still pass.
    local d, t = bid(true, true, true)
    assert(d == 0, 'outside turbo the candidate must be inert, got ' .. tostring(d))
    assert(t == nil, 'and no target')
end

tests['the gate helper itself is turbo AND candidate, not either'] = function()
    -- Each leg gets a FRESH world. J.IsModeTurbo memoises into bModeTurboCache on
    -- its first call (jmz_func.lua:8760 -- re-anchored 20260824 from :8474; most
    -- of that ~280-line drift predates the GH #117 §4 insertion, which moved it
    -- only 83 lines -- a prose pointer nobody re-reads goes stale silently), so
    -- flipping GetGameMode after the helper
    -- has run once changes nothing -- the first draft of this case asserted against
    -- a stale cache and read as a broken gate.
    local _, _, _, _, _, _, _, Xturbo = bid(true, false)
    assert(type(Xturbo.IsCullPierceOn) == 'function', 'X.IsCullPierceOn is gone or renamed')
    assert(Xturbo.IsCullPierceOn() == true, 'armed + turbo must be on')

    local _, _, _, _, _, _, _, Xnormal = bid(true, false, true)
    assert(Xnormal.IsCullPierceOn() == false, 'armed but not turbo must be off')

    local _, _, _, _, _, _, _, Xdisarmed = bid(false, false)
    assert(Xdisarmed.IsCullPierceOn() == false, 'turbo but not armed must be off')
end

-- ---------------------------------------------------------------- section 2 --
-- The supply, on real frames. A TRIPWIRE on a universal, so more fixtures can
-- only strengthen it; the day one reaches the domain it goes red and NAMES the
-- frame, which is the real frame this lever needs before anyone promotes it.

--- The eleven names aba_global_overrides.lua's IsMagicImmune override consults,
--- read out of that file so this scan cannot drift away from the shipped reader.
local function immunity_modifiers()
    local src = read_file(OVERRIDES)
    local from = src:find('function CDOTA_Bot_Script:IsMagicImmune%(%)')
    assert(from, 'the IsMagicImmune override is gone from ' .. OVERRIDES
        .. '; this scan was reading its modifier list out of it')
    local rest = src:sub(from)
    local body = rest:sub(1, rest:find('\nend') or #rest)
    local set, n = {}, 0
    for name in body:gmatch("HasModifier%('([%w_]+)'%)") do
        if not set[name] then set[name], n = true, n + 1 end
    end
    assert(n >= 11, string.format(
        'the shipped override now consults %d modifier names, was 11 -- re-read it '
        .. 'before quoting any supply number from this file', n))
    return set, n
end

local function fixture_files()
    local files = {}
    local p = assert(io.popen('ls tests/fixtures'))
    for line in p:lines() do
        if line:match('^.+%.lua$') then files[#files + 1] = 'tests/fixtures/' .. line end
    end
    p:close()
    table.sort(files)
    return files
end

local function ability_of(unit, name)
    for _, a in ipairs(unit.abilities or {}) do
        if a.name == name then return a end
    end
    return nil
end

--- Walk a list of loaded frames and return the funnel. Pure table reads on the
--- same `dofile` the loader uses; no regex over the files.
---
--- Split out from the corpus walk on purpose (hero backlog section 24, raised by
--- the 2026-08-23T09:50Z round): a scan that asserts an EMPTY result has no live
--- positive path once the tree is clean, so every mutation to its reporting half
--- escapes. Handing it a synthetic frame is the only way to prove it can still
--- report. `scan_frames` is that seam; the synthetic drivers are at the end of
--- section 2.
local function scan_frames(frames, IMMUNE)
    local c = {
        frames = 0, axe = 0, ready = 0, immune_units = 0, bkb_items = 0,
        pairs_ = 0, in_ring = 0, domain = 0,
    }
    local hits, immune_rows = {}, {}
    for _, fx in ipairs(frames) do
        if type(fx) == 'table' and type(fx.units) == 'table' then
            c.frames = c.frames + 1
            local immunes = {}
            for _, u in ipairs(fx.units) do
                for _, it in ipairs(u.items or {}) do
                    if it == 'black_king_bar' then c.bkb_items = c.bkb_items + 1 end
                end
                for _, m in ipairs(u.modifiers or {}) do
                    if IMMUNE[m.name] then
                        immunes[#immunes + 1] = { u = u, mod = m.name }
                        c.immune_units = c.immune_units + 1
                        immune_rows[#immune_rows + 1] = string.format(
                            '%s t=%s %s (%s)', tostring(fx.game), tostring(fx.time),
                            u.name, m.name)
                        break
                    end
                end
            end
            for _, me in ipairs(fx.units) do
                if me.name == AXE then
                    c.axe = c.axe + 1
                    local r = ability_of(me, CULLING)
                    local lv = (r and r.level) or 0
                    if me.alive and lv >= 1 and (r.cd or 0) <= 0
                        and (me.mp or 0) >= R_MANA[math.min(lv, 3)] then
                        c.ready = c.ready + 1
                        for _, e in ipairs(immunes) do
                            if e.u.team ~= me.team and e.u.alive then
                                c.pairs_ = c.pairs_ + 1
                                local dx, dy = e.u.x - me.x, e.u.y - me.y
                                local d = math.sqrt(dx * dx + dy * dy)
                                if d <= RING then
                                    c.in_ring = c.in_ring + 1
                                    if e.u.hp < 150 + 100 * lv then
                                        c.domain = c.domain + 1
                                        hits[#hits + 1] = string.format(
                                            '%s t=%s %s on %d hp, %.0fu, %s',
                                            tostring(fx.game), tostring(fx.time),
                                            e.u.name, e.u.hp, d, e.mod)
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end
    return c, hits, immune_rows
end

--- The corpus walk: load every fixture once, then run the same scan_frames the
--- synthetic drivers run.
local function census()
    local IMMUNE = immunity_modifiers()
    local frames = {}
    for _, path in ipairs(fixture_files()) do
        local ok, fx = pcall(dofile, path)
        if ok then frames[#frames + 1] = fx end
    end
    return scan_frames(frames, IMMUNE)
end

-- NOTE on the idiom: `if not cond then error(...) end`, never
-- `assert(cond, string.format(...))`. Lua evaluates BOTH arguments of assert, so a
-- message that indexes the row the condition proves absent blows up on the PASSING
-- path -- the threshold pre-flight lost a draft to exactly that.
tests['section 2: no fixture frame reaches the domain -- THIS is what is unsized'] = function()
    local _, hits = census()
    if #hits > 0 then
        error('DOMAIN REACHED: ' .. hits[1] .. ' -- the corpus now holds a frame where a '
            .. 'ready Culling faces a spell-immune enemy inside ' .. RING .. 'u and below the '
            .. 'execute threshold. That is the real frame `axecull` needs: cut it with '
            .. 'make_fixture.py, pin it here in place of the counterfactual in section 1, '
            .. 'and re-read the SUPPLY-STARVED verdict in this header -- it is now wrong')
    end
end

tests['section 2: the zero above is SUPPLY, and here is the supply'] = function()
    -- Without this the section-2 universal is true for the wrong reason and the
    -- header's "supply-starved, not empty" verdict is unfalsifiable prose.
    local c, _, rows = census()
    if c.frames < 100 then
        error(string.format('only %d fixtures loaded; the scan behind this file read 104', c.frames))
    end
    if c.axe < 26 or c.ready < 20 then
        error(string.format(
            'Axe frames %d (was 26) / Culling-ready %d (was 20). The carrier half of the '
            .. 'verdict was measured on those numbers', c.axe, c.ready))
    end
    if c.immune_units > 3 then
        error(string.format(
            'the corpus now holds %d spell-immune hero-instants, was 3:\n   %s\nRe-read the '
            .. 'SUPPLY-STARVED verdict: more supply may mean the domain is now sizeable here',
            c.immune_units, table.concat(rows, '\n   ')))
    end
    if c.pairs_ > 0 then
        error(string.format(
            'there are now %d (ready Axe) x (spell-immune enemy) pairs, was 0. The domain '
            .. 'scan above is no longer vacuous -- go read what it says', c.pairs_))
    end
end

tests['section 2: zero Black King Bars anywhere in the corpus'] = function()
    -- GH #108 (10 -> 25 game-minute cap) did overturn this, on a frame that is
    -- staged rather than admitted, and the reading was taken 2026-08-31 in
    -- tests/test_axe_bkb_supply_staged_frame.lua (GH #357 row 3). READ THAT FILE
    -- BEFORE ACTING ON THIS RATCHET GOING RED. Its finding:
    --
    --   THIS ZERO WAS NEVER THE LOAD-BEARING ONE. The sentence that used to
    --   stand here called it "the single most load-bearing supply fact"; it is a
    --   PROXY for the fact that is -- the ACTIVE-IMMUNITY zero measured by the
    --   two cases above -- and the two come apart as soon as the count is not 0:
    --     * NOT SUFFICIENT. The shipped IsMagicImmune override reads MODIFIERS
    --       and no items, so an item in a slot cannot make it answer true. The
    --       staged frame carries 2 Black King Bars and 0 immune instants.
    --     * NOT NECESSARY. All 3 immune instants in this corpus are
    --       modifier_juggernaut_blade_fury, and 3 of 3 carry no Black King Bar.
    --     * WRONG COUNT ANYWAY. Both staged slots are structurally out of the
    --       domain: one is the CASTER's own (the clause reads npcEnemy), one is
    --       on a DEAD enemy. A count that does not split by (enemy) x (alive)
    --       over-reports the supply it claims to measure.
    --
    -- The SUPPLY-STARVED-IN-CORPUS verdict in this header is therefore UNCHANGED
    -- by that frame, and hero-9 is still the way to size this lever. The ratchet
    -- below stays as it is: it correctly reports that the corpus composition
    -- changed, and that is worth a look every time. What changed is the standing
    -- response to it -- no longer "the verdict may now be wrong", but "check the
    -- immunity count and the carrier split; an item count alone re-decides
    -- nothing".
    local c = census()
    if c.bkb_items > 0 then
        error(string.format(
            'the corpus now carries %d Black King Bar item-slots, was 0. The claim that '
            .. 'this lever cannot be sized locally rested on that zero -- re-run the domain '
            .. 'scan and re-read the header', c.bkb_items))
    end
end

-- The synthetic drivers. Everything above asserts an ABSENCE, which on a clean
-- tree is also what a scan that reports nothing at all asserts. These feed
-- scan_frames a frame it MUST report, and three near misses it must NOT, so the
-- reporting half is exercised by data that exists rather than by hope.

local SYNTH_IMMUNE = { modifier_black_king_bar_immune = true }

--- One synthetic frame: an Axe with a ready rank-1 Culling and one enemy.
local function synth(enemy)
    return {
        game = 'SYNTHETIC', time = 1.0,
        units = {
            { name = AXE, team = 3, x = 0, y = 0, hp = 1000, max_hp = 1000,
              mp = 500, max_mp = 500, alive = true,
              abilities = { { name = CULLING, level = 1, cd = 0 } } },
            enemy,
        },
    }
end

local function synth_enemy(over)
    local e = { name = 'npc_dota_hero_lina', team = 2, x = 100, y = 0, hp = 50,
                max_hp = 900, mp = 0, max_mp = 900, alive = true,
                modifiers = { { name = 'modifier_black_king_bar_immune' } } }
    for k, v in pairs(over or {}) do e[k] = v end
    return e
end

tests['section 2 self-test: the scan REPORTS a synthetic offender'] = function()
    local c, hits = scan_frames({ synth(synth_enemy()) }, SYNTH_IMMUNE)
    assert(c.domain == 1, 'synthetic offender not counted, got ' .. tostring(c.domain))
    assert(#hits == 1, 'expected exactly one reported hit, got ' .. tostring(#hits))
    assert(hits[1]:find('npc_dota_hero_lina', 1, true), 'the hit must name the unit: ' .. hits[1])
    assert(hits[1]:find('modifier_black_king_bar_immune', 1, true),
        'and name the immunity that put it there: ' .. hits[1])
end

tests['section 2 self-test: the three near misses are NOT reported'] = function()
    -- Each flips exactly one of the three clauses that define the domain.
    local far = scan_frames({ synth(synth_enemy({ x = RING + 1 })) }, SYNTH_IMMUNE)
    assert(far.domain == 0 and far.pairs_ == 1,
        'an immune enemy just outside the ring must be a pair but not a hit')
    local healthy = scan_frames({ synth(synth_enemy({ hp = 400 })) }, SYNTH_IMMUNE)
    assert(healthy.domain == 0 and healthy.in_ring == 1,
        'an immune enemy above the execute threshold must be in-ring but not a hit')
    local mortal = scan_frames({ synth(synth_enemy({ modifiers = {} })) }, SYNTH_IMMUNE)
    assert(mortal.domain == 0 and mortal.pairs_ == 0,
        'a non-immune enemy is not this domain at all -- the shipped code already culls it')
end

tests['section 2 self-test: an Axe who cannot cast is not a carrier'] = function()
    -- The funnel's own upstream: guard against a future edit that counts frames
    -- where the ability is unavailable and inflates the "carrier is present" half.
    local f = synth(synth_enemy())
    f.units[1].abilities[1].cd = 12
    local cd = scan_frames({ f }, SYNTH_IMMUNE)
    assert(cd.axe == 1 and cd.ready == 0 and cd.domain == 0, 'cooldown must block the funnel')

    local g = synth(synth_enemy())
    g.units[1].mp = 10
    local mana = scan_frames({ g }, SYNTH_IMMUNE)
    assert(mana.ready == 0, 'a rank-1 Culling costs ' .. R_MANA[1] .. '; 10 mana cannot pay it')
end

-- ---------------------------------------------------------------- section 3 --
-- Structural ratchets on the source: each one pins a step of the desk pre-flight,
-- so a later edit to ConsiderR cannot invalidate the reasoning silently.

tests['section 3: X.ConsiderR still has exactly ONE firing branch'] = function()
    local body = consider_r_body(read_file(SRC))
    local n = 0
    for _ in body:gmatch('return BOT_ACTION_DESIRE_HIGH') do n = n + 1 end
    assert(n == 1, string.format(
        'X.ConsiderR now has %d firing branches, not 1. The UPSTREAM-SIBLING and '
        .. 'CONSUMER-SIDE-UNREACHABLE rule-outs in this header assumed there is nothing '
        .. 'else in the function that could take these frames', n))
end

tests['section 3: the immunity clause is the gated disjunction, not a bare veto'] = function()
    local body = consider_r_body(read_file(SRC))
    assert(body:find('not npcEnemy:IsMagicImmune%(%) or X%.IsCullPierceOn%(%)'), [[
The gated immunity clause is gone from X.ConsiderR.

If it was PROMOTED (the veto deleted outright), that is the intended end state --
delete this assertion, drop the `axecull` row from iterations/state.json, and note
in the promotion that the domain was sized on a wave, because nothing in this file
ever sized it. If the bare `not npcEnemy:IsMagicImmune()` veto was restored, read
the header first: Culling Blade is bkbpierce Yes.]])
end

tests['section 3: nothing else on the branch already covers spell immunity'] = function()
    -- The wkreincarnmp shape: a stronger guard upstream making the domain empty by
    -- construction. X.HasSpecialModifier is the only other modifier reader here, and
    -- it does not list the BKB buff.
    local src = read_file(SRC)
    local from = src:find('function X%.HasSpecialModifier')
    assert(from, 'X.HasSpecialModifier is gone; re-check what guards the execute branch')
    local rest = src:sub(from)
    local body = rest:sub(1, rest:find('\nfunction X%.') or #rest)
    for _, name in ipairs({ 'modifier_black_king_bar_immune', 'modifier_juggernaut_blade_fury',
                            'modifier_life_stealer_rage', 'modifier_magic_immune' }) do
        assert(not body:find(name, 1, true), string.format(
            'X.HasSpecialModifier now vetoes on %s. It did not when `axecull` was written, '
            .. 'and if it does now the gate is dominated by it and the domain IS empty', name))
    end
end

tests['section 3: ConsiderR is still the FIRST consumer in X.SkillsComplement'] = function()
    -- The consumer-side rule-out: desire > 0 becomes an order immediately, and no
    -- earlier bid can take the frame away.
    local src = read_file(SRC)
    local from = src:find('function X%.SkillsComplement')
    assert(from, 'X.SkillsComplement is gone from ' .. SRC)
    local rest = src:sub(from)
    local body = rest:sub(1, rest:find('\nfunction X%.') or #rest)
    local iR = body:find('castRDesire, castRTarget, sMotive = X%.ConsiderR%(%)')
    local iQ = body:find('X%.ConsiderQ%(%)')
    local iW = body:find('X%.ConsiderW%(%)')
    assert(iR, 'SkillsComplement no longer calls X.ConsiderR')
    assert(iQ and iR < iQ, 'ConsiderQ now runs before ConsiderR')
    assert(iW and iR < iW, 'ConsiderW now runs before ConsiderR')
    assert(body:find('ActionQueue_UseAbilityOnEntity%( abilityR, castRTarget %)'),
        'the R bid no longer turns into a cast order on the target it names')
end

return tests

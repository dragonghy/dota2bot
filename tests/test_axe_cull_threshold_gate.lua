-- [hero] `cullthresh` -- Axe's Culling Blade execute threshold, read off the
-- ability instead of hardcoded.  The registered `hero-2` lever, WRITTEN 2026-09-05
-- and GATED (turbo-only, unarmed).  GH #115 section 5.
--
-- THE DEFECT, and this file is the first time it is read off a REAL FRAME.
-- ----------------------------------------------------------------------------
-- bots/BotLib/hero_axe.lua X.ConsiderR estimated its own finisher with
--
--     local nKillDamage = 150 + 100 * nSkillLV          -- 250 / 350 / 450
--
-- and culls when a target's effective health falls BELOW it.  The game's own KV
-- says axe_culling_blade / AbilityValues / damage = `275 375 475`
-- (tests/mock/special_value_shapes.lua, generated from npc_dota_hero_axe.txt), so
-- the estimate is 25 LOW at every rank and the bot declines a guaranteed kill
-- whenever the target sits in the band (150 + 100*lv, damage[lv]].
--
-- Until 2026-09-04 that gap could only be quoted from a datafeed: an offline frame
-- answered 0 for every GetSpecialValue read.  `kvgetters` changed that for the
-- focus five, and section 1 below takes the reading on a real Axe instant --
-- tests/fixtures/f_260820_043637_axe_ring_close.lua, Culling rank 1, off cooldown,
-- 286 mana against a 100 cost -- where the ability answers 275 against the
-- formula's 250.  The 25 is now MEASURED on the same frame the decision runs on,
-- not carried in from odota.
--
-- WHAT THIS FILE DOES NOT BUY, stated first so it cannot be quoted as if it did.
-- ----------------------------------------------------------------------------
-- NOT a flipping frame.  On this frame the shipped branch ALREADY fires (the
-- Skywrath at 188u holds 221 hp, under both thresholds), and across the whole
-- corpus the band is occupied ZERO times -- 29 Axe instants, 23 of them with Culling
-- learned, off cooldown AND affordable, 3 in-ring enemy rows (measured 2026-09-05;
-- the August pre-flight measured 26/20/3/0 on the same funnel, so it grew and the
-- zero did not).  That
-- zero is the SAME zero tests/test_axe_culling_threshold_preflight.lua recorded as
-- NARROW-BAND-UNMEASURABLE, and its section 2 tripwire is deliberately left in
-- place to keep naming the frame the day one appears.  Section 5 here re-reads the
-- funnel so this file cannot drift away from that one.
--
-- SO WHY IS IT WRITTEN NOW, when the pre-flight declined to write it.
-- ----------------------------------------------------------------------------
-- The pre-flight's verdict was UNDERPOWERED, and it is worth being exact about
-- which half of it expired:
--
--   * "A frame corpus cannot size a 25-point band."  STILL TRUE, and section 5
--     obeys it: this file asserts the funnel and the zero, it does not read the
--     zero as an empty domain.
--   * "...so size it on the EVENT side."  tests/test_axe_culling_band_power.lua
--     (2026-08-30) priced that: a crossing on a 1 Hz timeline is caught with
--     p = min(1, band/(v*dt)), which contains no health-pool term -- 2.3 crossings
--     per hit at the corpus's median burst.  Sizing this is a CROSSING count on
--     archived timelines, and it is cheap.
--   * What blocked the crossing count was carrier supply: the batch desk measured
--     npc_dota_hero_axe in 0 of 306 archived games (2026-08-23), so there was
--     nothing to count crossings in.  THAT IS NOW FALSE.
--     tests/fixtures/tl_260905_010226_axe_outchan.json is a verbatim slice of an
--     archived dumper timeline (seed 4763, run spot_20260905_003250) whose subject
--     IS an Axe.  Section 6 pins that file, because it is the fact that moves this
--     lever from "cannot be sized" to "not yet sized".
--
-- A lever that can be sized but is not yet sized is exactly what the gate is for:
-- it rides the branch, inert in every shipped game, until a wave arms it.  The
-- change is STRICTLY WIDENING (armed threshold >= shipped threshold at every rank,
-- section 3), so the only way it can hurt is by culling a target the ability then
-- fails to kill -- which cannot happen while the armed value IS the ability's own
-- threshold.  Do NOT promote it on this argument alone; the wave still owes the
-- crossing count and the kill-landed brake.
--
-- THE TWO TRAPS THIS FILE PINS
-- ----------------------------------------------------------------------------
-- (1) DOUBLE-COUNTING THE TALENT.  special_bonus_unique_axe_5 (+150) lives INSIDE
--     axe_culling_blade / damage, where the engine folds it.  The shipped
--     `talent8` line added it AGAIN from a hero-unique talent handle that owns no
--     KV block and therefore answers 0 -- harmless only because it answers 0.  The
--     armed path returns the ability's own value and never that sum.  Section 4
--     pins it on the world the ENGINE would actually present if the talent were
--     trained (handle 150 AND ability 425), which is the world where a second
--     addition shows up -- not a world where only the handle moves, which the
--     engine never produces.
--
-- (2) THE DEGENERATE READ, and the guard that answers it is not the obvious one.
--     A getter that silently answers 0 is how `zusboltcap` (GH #175) turned an AoE
--     health filter into "is anyone there at all".  Here a degenerate read would
--     collapse the armed threshold and stop Axe culling ENTIRELY -- a silent
--     regression in the OPPOSITE direction to the one being fixed, and one no
--     in-domain counter would ever report.  The first draft guarded it with
--     `nLive > 0`; section 3 caught that this is NOT enough -- a small positive
--     read (1) still narrows the test -- so the shipped value is the floor:
--     the armed read is taken only when it is STRICTLY GREATER.  That turns "this
--     lever can only add casts" from a claim about the data into a property of the
--     code.  Section 2 pins the fallback and section 3 pins the floor.
--
-- EXTERNAL ANCHORS -- what does not come from the frame:
--   * Culling Blade's KV damage ladder 275/375/475 and the +150 talent bonus, from
--     tests/mock/special_value_shapes.lua (the game's own KV, snapshotted).  Rank 1
--     of it is CROSS-CHECKED against the live frame read in section 1, so the
--     anchor and the loader have to agree.
--   * Nothing else.  Cast range (175), rank, cooldown and mana all come from the
--     frame.

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')

local SRC     = 'bots/BotLib/hero_axe.lua'
local FRAME   = 'tests/fixtures/f_260820_043637_axe_ring_close.lua'
local TIMELINE = 'tests/fixtures/tl_260905_010226_axe_outchan.json'
local AXE     = 'npc_dota_hero_axe'
local CULLING = 'axe_culling_blade'

-- The KV ladder, from tests/mock/special_value_shapes.lua axe / axe_culling_blade
-- / damage = '275 375 475'.  Section 1 makes the loader agree with it at rank 1.
local R_DAMAGE = { 275, 375, 475 }
local R_MANA   = { 100, 125, 150 }

local tests = {}

local function read_file(path)
    local fh = assert(io.open(path, 'r'), 'cannot open ' .. path)
    local body = fh:read('*a')
    fh:close()
    return body
end

--- The body of one X.<name> function, so a source ratchet cannot be satisfied by a
--- matching string elsewhere in the file.
local function fn_body(src, name)
    local from = src:find('function X%.' .. name .. '%s*%(')
    assert(from, 'X.' .. name .. ' not found in ' .. SRC)
    local rest = src:sub(from)
    local to = rest:find('\nfunction X%.')
    return to and rest:sub(1, to) or rest
end

--- Load the real frame with `tArmed` armed.  `bTurbo == false` puts the game back
--- into all-pick AFTER rf.load (which forces turbo), which is the only way to test
--- the mode half of the gate.
local function load_axe(tArmed, bTurbo)
    local J, bot, heroes, fx = rf.load(FRAME)

    local sAbilityList = J.Skill.GetAbilityList(bot)
    assert(sAbilityList[6] == CULLING,
        'the ultimate must be reachable in the fixture world (GH #36)')
    local abilityR = bot:GetAbilityByName(sAbilityList[6])

    if bTurbo == false then
        GetGameMode = function() return GAMEMODE_ALLPICK end
    end
    local tOn = {}
    for _, id in ipairs(tArmed or {}) do tOn[id] = true end
    J.IsSoakCandidate = function(id) return tOn[id] == true end

    local X = rf.load_hero('axe')
    return X, J, bot, heroes, abilityR, fx
end

local function ability_of(unit, name)
    for _, a in ipairs(unit.abilities or {}) do
        if a.name == name then return a end
    end
    return nil
end

local function dist(a, b)
    local dx, dy = a.x - b.x, a.y - b.y
    return math.sqrt(dx * dx + dy * dy)
end

--- Every (frame, living Axe) row in the corpus where Culling is genuinely
--- castable, with the in-ring enemies and the band occupancy.  Deliberately the
--- same funnel tests/test_axe_culling_threshold_preflight.lua runs, over both
--- frame directories rather than one, so section 5 can be compared with it.
local function corpus_rows()
    -- Two LITERAL commands rather than one built from a loop variable: the walk
    -- audit in tests/test_bots_walk_farm_only.py resolves an io.popen argument
    -- statically and reports anything it cannot read, and a two-element loop is not
    -- worth spending a hand-read exemption on.
    local files = {}
    local function collect(dir, p)
        if p == nil then return end
        for line in p:lines() do
            if line:match('^f_.+%.lua$') then files[#files + 1] = dir .. '/' .. line end
        end
        p:close()
    end
    collect('tests/fixtures', io.popen('ls tests/fixtures'))
    collect('tests/frames', io.popen('ls tests/frames'))
    table.sort(files)

    local axe_instants, ready, in_ring, band = 0, 0, 0, {}
    for _, path in ipairs(files) do
        local ok, fx = pcall(dofile, path)
        if ok and type(fx) == 'table' and type(fx.units) == 'table' then
            for _, me in ipairs(fx.units) do
                if me.name == AXE then
                    axe_instants = axe_instants + 1
                    local r = ability_of(me, CULLING)
                    local lv = (r and r.level) or 0
                    if me.alive and lv >= 1 and (r.cd or 0) <= 0
                        and (me.mp or 0) >= R_MANA[math.min(lv, 3)]
                    then
                        ready = ready + 1
                        local stale = 150 + 100 * lv
                        local live = R_DAMAGE[math.min(lv, 3)]
                        for _, u in ipairs(fx.units) do
                            if u.name:match('^npc_dota_hero_') and u.team ~= me.team
                                and u.alive and dist(u, me) <= 375
                            then
                                in_ring = in_ring + 1
                                if u.hp > stale and u.hp <= live then
                                    band[#band + 1] = {
                                        path = path, t = fx.time, unit = u,
                                        lv = lv, stale = stale, live = live,
                                        d = dist(u, me),
                                    }
                                end
                            end
                        end
                    end
                end
            end
        end
    end
    return axe_instants, ready, in_ring, band
end

-- ---------------------------------------------------------------- section 1 --
-- The reading, on the real frame.  This is the half the pre-flight could not take.

tests['section 1: the frame really is a ready Culling Blade, not a staged one'] = function()
    local _, _, _, _, abilityR = load_axe({})
    assert(abilityR:GetName() == CULLING, 'wrong ability handle: ' .. abilityR:GetName())
    assert(abilityR:GetLevel() == 1,
        'the frame carries Culling at rank 1, got ' .. abilityR:GetLevel())
    assert(abilityR:IsFullyCastable(),
        'X.ConsiderR early-returns on a non-castable R, so a non-castable frame '
        .. 'would make every assertion below vacuous')
    assert(abilityR:GetCastRange() == 175, string.format(
        'AbilityCastRange is 175 in KV; the loader answered %s', tostring(abilityR:GetCastRange())))
end

tests['section 1: the ability answers 275 where the shipped formula says 250'] = function()
    local _, _, _, _, abilityR = load_axe({})
    local lv = abilityR:GetLevel()
    local live = abilityR:GetSpecialValueInt('damage')
    assert(live == R_DAMAGE[lv], string.format(
        'the loader answered %d for axe_culling_blade/damage at rank %d, the KV snapshot '
        .. 'says %d.  One of the two moved -- do not paper over it, the 25-point gap IS '
        .. 'the lever', live, lv, R_DAMAGE[lv]))
    assert(live - (150 + 100 * lv) == 25, string.format(
        'the gap on this frame is %d, not the 25 the lever is about', live - (150 + 100 * lv)))
end

tests['section 1: the gap is exactly 25 at every rank, not just this one'] = function()
    for lv = 1, 3 do
        assert(R_DAMAGE[lv] - (150 + 100 * lv) == 25, string.format(
            'rank %d: KV %d vs constant %d is a gap of %d.  The ladder changed -- re-read '
            .. 'the KV and re-size the band, because the band width IS the lever',
            lv, R_DAMAGE[lv], 150 + 100 * lv, R_DAMAGE[lv] - (150 + 100 * lv)))
    end
end

-- ---------------------------------------------------------------- section 2 --
-- The gate.  Off in every shipped game; on only in turbo and only when armed.

tests['gate OFF: unarmed, the threshold is the shipped constant byte for byte'] = function()
    local X = load_axe({})
    assert(X.CullKillThreshold(1) == 250, 'rank 1 unarmed must be 250, got ' .. X.CullKillThreshold(1))
    assert(X.CullKillThreshold(2) == 350, 'rank 2 unarmed must be 350, got ' .. X.CullKillThreshold(2))
    assert(X.CullKillThreshold(3) == 450, 'rank 3 unarmed must be 450, got ' .. X.CullKillThreshold(3))
end

tests['gate OFF: armed but NOT turbo is inert'] = function()
    local X = load_axe({ 'cullthresh' }, false)
    assert(X.IsCullThresholdOn() == false, 'the mode half of the gate did not hold')
    assert(X.CullKillThreshold(1) == 250,
        'outside turbo the threshold must stay shipped, got ' .. X.CullKillThreshold(1))
end

tests['gate OFF: a different armed candidate does not move it'] = function()
    local X = load_axe({ 'axecull' })
    assert(X.CullKillThreshold(1) == 250, 'only cullthresh arms cullthresh')
end

tests['gate ON: armed in turbo, the threshold becomes the ability value'] = function()
    local X, _, _, _, abilityR = load_axe({ 'cullthresh' })
    assert(X.IsCullThresholdOn() == true, 'positive control: the gate must be open here')
    local live = abilityR:GetSpecialValueInt('damage')
    assert(X.CullKillThreshold(1) == live, string.format(
        'armed must return the ability value %d, got %d', live, X.CullKillThreshold(1)))
    assert(X.CullKillThreshold(1) == 275, 'and on this frame that value is 275')
end

tests['gate ON: the rank argument survives as the FLOOR, and that is deliberate'] = function()
    -- Worth stating because the first draft asserted the opposite.  The armed path
    -- reads the handle, but the shipped value is still computed and still wins when
    -- it is larger -- so the rank argument has not stopped mattering, it has become
    -- the floor.  On this frame (handle at rank 1) that shows up as:
    local X = load_axe({ 'cullthresh' })
    assert(X.CullKillThreshold(1) == 275,
        'rank 1: the handle read (275) is above the floor (250), so it wins')
    assert(X.CullKillThreshold(3) == 450, string.format(
        'rank 3 against a rank-1 handle: the floor (450) is above the read (275), so the '
        .. 'floor wins and armed == shipped.  Got %d', X.CullKillThreshold(3)))

    -- That combination is NOT a world the engine produces, and the next case is why
    -- it cannot leak into a game: ConsiderR passes the handle's own level.
end

tests['gate ON: X.ConsiderR passes the handle its own rank, so read and floor agree'] = function()
    local body = fn_body(read_file(SRC), 'ConsiderR')
    assert(body:find('local nSkillLV = abilityR:GetLevel%(%)'),
        'nSkillLV is no longer the handle\'s own level.  The armed read and the shipped '
        .. 'floor are then indexed by DIFFERENT ranks, and the floor could mask a correct '
        .. 'read at the hero\'s real rank')
    assert(body:find('X%.CullKillThreshold%( nSkillLV %)'),
        'ConsiderR passes something other than nSkillLV to the helper')
end

tests['section 2: the shipped floor, not luck, is what keeps armed safe'] = function()
    local X, _, _, _, abilityR = load_axe({ 'cullthresh' })
    local spec = rawget(abilityR, '__spec')

    spec.GetSpecialValueInt = function() return 0 end
    assert(X.CullKillThreshold(1) == 250, string.format(
        'a degenerate 0 read must fall back to shipped, got %d.  Without this Axe stops '
        .. 'culling entirely -- the zusboltcap shape (GH #175), silent and in the '
        .. 'opposite direction to the fix', X.CullKillThreshold(1)))

    spec.GetSpecialValueInt = function() return nil end
    assert(X.CullKillThreshold(2) == 350,
        'a nil read must fall back to shipped, got ' .. tostring(X.CullKillThreshold(2)))

    spec.GetSpecialValueInt = function() return -40 end
    assert(X.CullKillThreshold(1) == 250,
        'a negative read must fall back to shipped, got ' .. tostring(X.CullKillThreshold(1)))
end

-- ---------------------------------------------------------------- section 3 --
-- Direction.  The change may only ADD casts; it must never remove one.

tests['section 3: armed is never NARROWER than shipped, at any rank or any read'] = function()
    local X, _, _, _, abilityR = load_axe({ 'cullthresh' })
    local spec = rawget(abilityR, '__spec')
    local Xoff = load_axe({})
    for _, read in ipairs({ 0, 1, 100, 249, 250, 251, 275, 475, 1000 }) do
        spec.GetSpecialValueInt = function() return read end
        for lv = 1, 3 do
            local shipped = Xoff.CullKillThreshold(lv)
            local armed = X.CullKillThreshold(lv)
            assert(armed >= shipped, string.format(
                'rank %d with a %d read: armed %d < shipped %d.  This lever is allowed to '
                .. 'widen the execute test and nothing else', lv, read, armed, shipped))
        end
    end
end

-- ---------------------------------------------------------------- section 4 --
-- The talent, on the world where the double-count would be visible.

tests['section 4: armed does NOT add the talent on top of the folded KV value'] = function()
    local X, J, bot, _, abilityR = load_axe({ 'cullthresh' })
    local sTalentList = J.Skill.GetTalentList(bot)
    local hTalent = bot:GetAbilityByName(sTalentList[8])
    assert(hTalent ~= nil, 'the talent8 handle must exist for this test to mean anything')

    -- The world the ENGINE would actually present if that talent were trained: the
    -- handle answers its 150 AND the +150 is already inside the ability's own
    -- `damage` read, because that is where the KV puts it
    -- (special_bonus_unique_axe_5, tests/mock/special_value_shapes.lua).  Building
    -- the consistent world matters: a world where only the handle moves is one the
    -- engine never produces, and a test written against it would be pinning an
    -- artefact.  On the shipped tree the handle answers 0, which is why the
    -- double-count has been invisible rather than absent.
    local tspec = rawget(hTalent, '__spec')
    tspec.IsTrained = function() return true end
    tspec.GetSpecialValueInt = function() return 150 end
    rawget(abilityR, '__spec').GetSpecialValueInt = function() return 425 end

    local live = abilityR:GetSpecialValueInt('damage')
    assert(live == 425, 'the folded read was not installed')
    assert(X.CullKillThreshold(1) == live, string.format(
        'armed answered %d against an ability value of %d -- the talent was added a second '
        .. 'time on top of the value the engine already folds it into',
        X.CullKillThreshold(1), live))
end

tests['section 4: the SHIPPED path still carries the talent term (gate-off is byte-equal)'] = function()
    local X, J, bot = load_axe({})
    local sTalentList = J.Skill.GetTalentList(bot)
    local tspec = rawget(bot:GetAbilityByName(sTalentList[8]), '__spec')
    tspec.IsTrained = function() return true end
    tspec.GetSpecialValueInt = function() return 150 end
    assert(X.CullKillThreshold(1) == 400, string.format(
        'unarmed must reproduce the shipped arithmetic INCLUDING its talent term '
        .. '(250 + 150 = 400), got %d.  Dropping the term while unarmed would be a '
        .. 'behaviour change outside the gate', X.CullKillThreshold(1)))
end

-- ---------------------------------------------------------------- section 5 --
-- The domain that is still owed.  A one-sided funnel plus the band zero, so this
-- file cannot drift away from the pre-flight's tripwire.

tests['section 5: the corpus funnel is at least as large as when the band was last sized'] = function()
    local axe_instants, ready, in_ring = corpus_rows()
    assert(axe_instants >= 29, string.format(
        'only %d Axe instants in the corpus; the 2026-09-05 reading was 29.  A shrinking '
        .. 'corpus makes the zero below weaker, not stronger', axe_instants))
    assert(ready >= 23, string.format(
        'only %d ready-Culling Axe instants (learned, off cooldown AND affordable); the '
        .. '2026-09-05 reading was 23', ready))
    assert(in_ring >= 3, string.format(
        'only %d in-ring enemy rows; the 2026-09-05 reading was 3.  With 0 of them the '
        .. 'band assertion below would pass because Axe is never near anyone, not because '
        .. 'the band is empty -- do not quote it then', in_ring))
end

tests['section 5: the band is still occupied ZERO times -- so no frame flips yet'] = function()
    local _, _, _, band = corpus_rows()
    if #band > 0 then
        local h = band[1]
        error(string.format(
            'DOMAIN REACHED: %s t=%.1f -- %s at %d hp, %.0fu away, sits in (%d, %d] with '
            .. 'Culling rank %d ready.  This is the flipping frame `cullthresh` has never '
            .. 'had: pin it, assert that armed casts and shipped does not, and say so on '
            .. 'GH #115 / iterations/queue.json hero-2',
            h.path, h.t or -1, h.unit.name, h.unit.hp, h.d, h.stale, h.live, h.lv))
    end
end

tests['section 5: on THIS frame the two thresholds agree, and that is registered'] = function()
    -- The honest statement of what the real frame shows: the branch fires either
    -- way here.  Anyone quoting this file as "validated on a real decision" is
    -- quoting something it does not say.
    local X, _, bot, heroes = load_axe({ 'cullthresh' })
    local Xoff = load_axe({})
    local nBelowBoth = 0
    for _, h in pairs(heroes) do
        if h:GetTeam() ~= bot:GetTeam() and h:IsAlive()
            and GetUnitToUnitDistance(bot, h) <= 375
        then
            local hp = h:GetHealth()
            assert(not (hp > Xoff.CullKillThreshold(1) and hp <= X.CullKillThreshold(1)),
                'this frame was believed NOT to flip; it does now -- pin it as the '
                .. 'flipping frame instead of quoting section 5')
            if hp < Xoff.CullKillThreshold(1) then nBelowBoth = nBelowBoth + 1 end
        end
    end
    assert(nBelowBoth == 1, string.format(
        'exactly one in-ring enemy (the 221 hp Skywrath) is under BOTH thresholds on this '
        .. 'frame, got %d.  That is why the frame proves the READ and not the DECISION',
        nBelowBoth))
end

-- ---------------------------------------------------------------- section 6 --
-- The supply fact that moved this lever, pinned so it cannot rot back into prose.

tests['section 6: the archive now holds a timeline whose subject is an Axe'] = function()
    local body = read_file(TIMELINE)
    assert(body:find('"seed": 4763', 1, true) or body:find('"seed":4763', 1, true),
        TIMELINE .. ' no longer carries seed 4763 -- the supply claim in the header '
        .. 'names that run; re-read it before quoting "the archive has Axe now"')
    assert(body:find('"hero": "axe"', 1, true) or body:find('axe', 1, true),
        TIMELINE .. ' no longer names an axe subject')
    assert(body:find('spot_20260905_003250', 1, true),
        'the run id in the header is not in the file any more')
end

-- ---------------------------------------------------------------- section 7 --
-- Source ratchets.  The gate has to keep being a gate.

tests['section 7: the helper is turbo-gated and reads its own id'] = function()
    local body = fn_body(read_file(SRC), 'IsCullThresholdOn')
    assert(body:find('J%.IsModeTurbo%(%)'), 'the mode half of the gate is gone')
    assert(body:find("J%.IsSoakCandidate%( 'cullthresh' %)"), 'it must read its own id')
end

tests['section 7: the gate does not name a SIBLING id (the pullcad trap)'] = function()
    local body = fn_body(read_file(SRC), 'CullKillThreshold')
        .. fn_body(read_file(SRC), 'IsCullThresholdOn')
    for id in body:gmatch("IsSoakCandidate%(%s*'([%w_]+)'") do
        assert(id == 'cullthresh', string.format(
            "this gate names '%s' as well as its own id.  A condition that names another "
            .. "candidate freezes FALSE the day that candidate is promoted (AGENTS.md, "
            .. "the pullcad trap) -- express the dependency as a VALUE, not an id", id))
    end
end

tests['section 7: X.ConsiderR routes through the helper and keeps no second copy'] = function()
    local src = read_file(SRC)
    local body = fn_body(src, 'ConsiderR')
    assert(body:find('X%.CullKillThreshold%( nSkillLV %)'),
        'X.ConsiderR no longer calls the helper -- the gate is bypassed')
    assert(not body:find('150 %+ 100 %*'), string.format(
        'the stale constant is back inside X.ConsiderR.  There must be exactly ONE '
        .. 'threshold expression in this file and it must be behind the gate'))
    -- `talent8:` and not the bare word: the comment left at the call site names the
    -- old line on purpose, and a ratchet that a COMMENT can trip is a ratchet
    -- whoever edits the prose will end up loosening.
    assert(not body:find('talent8:'),
        'the talent term is back inside X.ConsiderR; it belongs in the helper, below '
        .. 'the shipped constant and above the armed read, or the armed path can '
        .. 'double-count it')
end

tests['section 7: the shipped arithmetic still lives, unchanged, in the helper'] = function()
    local body = fn_body(read_file(SRC), 'CullKillThreshold')
    assert(body:find('local nKillDamage = 150 %+ 100 %* nSkillLV'),
        'the gate-off path must reproduce the shipped constant literally, or "inert '
        .. 'when unarmed" stops being checkable by reading')
    assert(body:find('talent8:GetSpecialValueInt%( .value. %)'),
        'the gate-off path dropped the shipped talent term -- that is a behaviour '
        .. 'change OUTSIDE the gate')
    assert(body:find('nLive > nKillDamage'),
        'the shipped-value floor is gone.  A `nLive > 0` guard is NOT equivalent -- '
        .. 'section 3 shows a small positive read narrows the execute test under it')
end

return tests

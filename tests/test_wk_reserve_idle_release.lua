-- [wksaveidle] Wraith King holds 220 mana back for a death nothing on the frame
-- threatens.
--
-- WHAT IS UNDER TEST.  X.ShouldSaveMana (bots/BotLib/hero_skeleton_king.lua) is
-- SHIPPED and un-gated, and it is consulted on the FIRST line of both
-- X.ConsiderQ and X.ConsiderW -- so when it says true, Wraithfire Blast AND Bone
-- Guard are both off the table for that frame.  It decides on five reads: hero
-- level, two non-nil handles, R's cooldown, and the arithmetic.  None of them
-- asks whether this Wraith King is in any danger of dying, which is the only
-- event that ever spends the mana it is protecting.  `wksaveidle` adds a release
-- -- full health AND no visible enemy hero inside 1600u -- gated and turbo-only.
--
-- THE DOMAIN IS MEASURED, NOT ARGUED.  On the 33 priced Wraith King fixtures the
-- reserve fires on 6, and exactly 2 of those 6 hold a full-health Wraith King
-- with zero enemies visible in 1600u.  Section 3 walks the whole corpus and
-- section 2 reads the two frames one at a time.
--
-- ⛔ DIRECTION.  This lever is a WIDENING: armed, the bot casts MORE.  A negative
-- wave reads "the extra casts were bad" and never "N reincarnations were lost"
-- -- the reserve does not cause a reincarnation, it only preserves the mana for
-- one, and no offline stand can price a death that did not happen.  Section 3
-- proves the direction over the corpus through ONE tally called twice with its
-- legs swapped, so the 0 that must hold in one direction is produced by a
-- counter proved able to count (the M14 lesson of the 'staytower' round: a
-- counter whose content is all zeros cannot tell "the direction holds" from "the
-- tally never ran").
--
-- ⚠️ WHAT THIS FILE DOES NOT CLAIM, stated before anyone quotes a number:
--   * Not a frequency.  2/33 is a DOMAIN over a corpus of instants cut for other
--     investigations; how often the shape occurs in a game needs a wave
--     (iterations/queue.json hero-41).
--   * Not a cast count.  tests/test_wk_save_mana_lock_census.lua section 5
--     measured that the shipped X.ConsiderQ answers 0 on all 33 priced frames
--     whether the reserve is on or off, so "the reserve is released" must never
--     be read as "a blast is cast".  Section 6 below re-derives that on the two
--     domain frames rather than citing it, so the boundary cannot rot silently.
--   * Nothing about the RANK blindness in the same function (nLV >= 6 standing
--     in for "R is learned").  That gap belongs to the census file's section 6
--     and to the separate candidate 'wkreinctr' at the retreat site; section 7
--     asserts this lever did not quietly close it.

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')

local WK_SRC = 'bots/BotLib/hero_skeleton_king.lua'
local WK = 'npc_dota_hero_skeleton_king'
-- The ENGINE name.  `skeleton_king_wraithfire_blast` is the display name and the
-- mock answers a blank handle for it; a blank handle reads rank 0 / cost 0, i.e.
-- exactly like a real unlearned Q (the mistake that cost the 2026-09-01 probe
-- round, recorded in tests/test_wk_save_mana_lock_census.lua).
local Q = 'skeleton_king_hellfire_blast'
local R = 'skeleton_king_reincarnation'
local CAND = 'wksaveidle'

-- The two frames the release fires on.  Named, not globbed: if a corpus edit
-- moves the domain, section 3's count moves too and both must be re-read
-- together.
local DOMAIN = {
    'tests/fixtures/f_114311_drow_pushguard_silent.lua',
    'tests/fixtures/f_260820_103216_cm_es_aftershock.lua',
}

local tests = {}

local function read_file(path)
    local fh = assert(io.open(path, 'r'), 'cannot open ' .. path)
    local s = fh:read('*a')
    fh:close()
    return s
end

local function short(path) return (path:gsub('^tests/fixtures/', '')) end

--- Every fixture holding a Wraith King WITH an abilities list.  Same split, and
--- for the same reason, as tests/test_wk_save_mana_lock_census.lua section 1: a
--- fixture without abilities hands out blank handles, and a blank handle answers
--- rank 0 / cooldown 0 / cost 0 -- three readings indistinguishable from
--- "unlearned, ready, free".  Counting those as "the reserve did not fire" would
--- put an absence into every ratio in this file.
local function priced_corpus()
    local out = {}
    local p = assert(io.popen('ls tests/fixtures'))
    local files = {}
    for line in p:lines() do
        if line:match('%.lua$') then files[#files + 1] = 'tests/fixtures/' .. line end
    end
    p:close()
    table.sort(files)
    for _, path in ipairs(files) do
        local ok, fx = pcall(dofile, path)
        if ok and type(fx) == 'table' and type(fx.units) == 'table' then
            for _, u in ipairs(fx.units) do
                if u.name == WK then
                    if type(u.abilities) == 'table' then out[#out + 1] = path end
                    break
                end
            end
        end
    end
    return out
end

--- Load one real frame, optionally arm the candidate, optionally leave turbo,
--- and hand back the REAL helpers.  Nothing here re-implements the decision:
--- every answer below comes out of X.ShouldSaveMana / X.IsReincarnationReserveIdle
--- themselves.
local function frame(path, opt)
    opt = opt or {}
    local J, bot = rf.load(path, WK)
    -- `== true` and not a bare comparison: an absent id must read false, and a
    -- typo in the id must arm nothing rather than everything.
    J.IsSoakCandidate = function(id) return (opt.arm == true and id == CAND) end
    if opt.nonTurbo then
        -- rf.load's install() forces turbo; undo it AFTER load, exactly as
        -- tests/test_axe_call_immune_veto.lua does.
        GetGameMode = function() return 1 end
    end
    local X = rf.load_hero('skeleton_king')
    pcall(function() X.SkillsComplement() end)   -- primes the file-level nLV
    return X, bot, J
end

local function reserve(path, opt)
    local X, bot = frame(path, opt)
    return X.ShouldSaveMana(bot:GetAbilityByName(Q)) and true or false
end

-- ---------------------------------------------------------------------------
-- 1. The shipped rule has no danger term at all.  Structural, so that a future
--    edit that adds one makes this file red instead of leaving its whole
--    premise silently obsolete.

tests['[section 1] the shipped reserve reads level, handles, cooldown, mana -- never danger'] =
function()
    local src = read_file(WK_SRC)
    local body = src:match('function X%.ShouldSaveMana%b()(.-)\nend')
    assert(body ~= nil, 'cannot find X.ShouldSaveMana in ' .. WK_SRC
        .. '; this section reads its body, so a rename breaks the reading')
    local live = {}
    for line in body:gmatch('[^\n]+') do
        if not line:match('^%s*%-%-') then live[#live + 1] = line end
    end
    local text = table.concat(live, '\n')
    for _, needle in ipairs({ 'nLV >= 6', 'abilityR ~= nil',
                              'GetCooldownTimeRemaining', 'GetManaCost' }) do
        assert(text:find(needle, 1, true),
            'the reserve rule no longer contains "' .. needle .. '"; its operands '
            .. 'moved and every reading in this file is of a different function')
    end
    -- The shipped predicate must be a single bound expression: the release below
    -- is only sound because it is consulted AFTER that expression already said
    -- true.  If the binding disappears the direction argument goes with it.
    assert(text:find('local bShipped', 1, true),
        'the shipped predicate is no longer bound to bShipped; the true -> false '
        .. 'direction was a property of that shape, not of the arithmetic')
    assert(text:find('if bShipped and X.IsReincarnationReserveIdle()', 1, true),
        'the release is no longer guarded by the shipped answer, so the armed leg '
        .. 'can now invent a reserve the shipped leg never asked for')
    -- Read the release helper for the two operands the whole lever rests on.
    local rel = src:match('function X%.IsReincarnationReserveIdle%b()(.-)\nend')
    assert(rel ~= nil, 'X.IsReincarnationReserveIdle is gone')
    assert(rel:find('J.IsModeTurbo()', 1, true), 'the release lost its turbo guard')
    assert(rel:find("J.IsSoakCandidate( '" .. CAND .. "' )", 1, true),
        'the release no longer names ' .. CAND .. ', so a wave arming that string '
        .. 'would move nothing while check_armed_wiring.py still calls it wired')
    assert(rel:find('J.GetHP( bot ) < 0.95', 1, true), 'the health term moved')
    assert(rel:find('J.GetNearbyHeroes( bot, 1600, true, BOT_MODE_NONE )', 1, true),
        'the visible-enemy term moved.  The radius is X.ConsiderW\'s own; a '
        .. 'second radius invented here would be a number nobody measured')
end

-- ---------------------------------------------------------------------------
-- 2. The two domain frames, read one at a time on their real numbers.

tests['[section 2] f_114311: level 7, full hp, 271 mana, ZERO visible enemies'] =
function()
    local X, bot, J = frame(DOMAIN[1])
    assert(bot:GetLevel() == 7, 'level, got ' .. tostring(bot:GetLevel()))
    assert(bot:GetHealth() == 1044 and bot:GetMaxHealth() == 1044,
        'full health, got ' .. bot:GetHealth() .. '/' .. bot:GetMaxHealth())
    assert(bot:GetMana() == 271, 'mana, got ' .. tostring(bot:GetMana()))
    local hQ, hR = bot:GetAbilityByName(Q), bot:GetAbilityByName(R)
    assert(hQ:GetManaCost() == 95 and hR:GetManaCost() == 220,
        'the two prices this frame is decided on')
    assert(hR:GetCooldownTimeRemaining() == 0, 'R is ready, so the reserve applies')
    -- 271 - 95 = 176 < 220: the shipped rule refuses.
    assert(X.ShouldSaveMana(hQ) == true, 'the SHIPPED reserve must fire here')
    assert(#J.GetNearbyHeroes(bot, 1600, true, BOT_MODE_NONE) == 0,
        'and it fires with no enemy hero visible anywhere inside 1600u')
end

tests['[section 2] f_260820_103216: level 8, full hp, 280 mana, ZERO visible enemies'] =
function()
    local X, bot, J = frame(DOMAIN[2])
    assert(bot:GetLevel() == 8, 'level, got ' .. tostring(bot:GetLevel()))
    assert(bot:GetHealth() == 1110 and bot:GetMaxHealth() == 1110, 'full health')
    assert(bot:GetMana() == 280, 'mana, got ' .. tostring(bot:GetMana()))
    local hQ = bot:GetAbilityByName(Q)
    assert(X.ShouldSaveMana(hQ) == true, 'the SHIPPED reserve must fire here')
    assert(#J.GetNearbyHeroes(bot, 1600, true, BOT_MODE_NONE) == 0, 'nobody in sight')
end

tests['[section 2] armed, both frames release -- and only because BOTH terms hold'] =
function()
    for _, path in ipairs(DOMAIN) do
        assert(reserve(path, { arm = true }) == false,
            short(path) .. ': armed, the reserve must let the cast through')
        -- Each term alone must not be enough.  Rather than argue it, break one
        -- term at a time on the real frame and re-drive the real helper.
        local X, bot, J = frame(path, { arm = true })
        local spec = rawget(bot, '__spec')
        local hp = bot:GetHealth()
        -- Both readers, because J.GetHP takes the OriginalGet* pair for a unit on
        -- your own team and GetHealth for anyone else.  Moving only one of them
        -- would leave the helper reading full health while the test believed it
        -- had injected a wound -- a no-op injection passing as a finding.
        spec.GetHealth = math.floor(hp * 0.5)
        spec.OriginalGetHealth = math.floor(hp * 0.5)
        assert(J.GetHP(bot) < 0.95, short(path) .. ': the wound must actually '
            .. 'reach J.GetHP, or the assertion below is vacuous.  Got '
            .. string.format('%.2f', J.GetHP(bot)))
        assert(X.ShouldSaveMana(bot:GetAbilityByName(Q)) == true,
            short(path) .. ': at half health the release must NOT fire -- a hurt '
            .. 'Wraith King is exactly who the reserve is for')
    end
end

tests['[section 2] one visible enemy is enough to keep the reserve on'] =
function()
    -- The enemy term, broken the other way round, with ONE labelled flip and no
    -- invented unit: f_114311 already carries an ALLIED Earthshaker 825u from
    -- this Wraith King, so flipping that one hero's team hands the loader's own
    -- GetNearbyHeroes a real, live, visible enemy at a real distance.  (The
    -- nearest actual enemy on the untouched frame is a Phantom Assassin at
    -- 2616u, so the zero this lever reads has margin -- it is not a hero sitting
    -- one unit outside the ring.)
    local J, bot, heroes = rf.load(DOMAIN[1], WK)
    J.IsSoakCandidate = function(id) return id == CAND end
    local es = heroes['npc_dota_hero_earthshaker']
    assert(es ~= nil and es:GetTeam() == bot:GetTeam(),
        'the flip below assumes Earthshaker starts as an ALLY on this frame')
    assert(GetUnitToUnitDistance(bot, es) < 1600,
        'and that he stands inside the 1600u ring, got '
        .. string.format('%.1f', GetUnitToUnitDistance(bot, es)))
    rawget(es, '__spec').GetTeam = 3 - bot:GetTeam()
    local X = rf.load_hero('skeleton_king')
    pcall(function() X.SkillsComplement() end)
    assert(#J.GetNearbyHeroes(bot, 1600, true, BOT_MODE_NONE) == 1,
        'the flipped hero must actually reach the helper as an enemy, or the '
        .. 'assertion below is vacuous')
    assert(X.ShouldSaveMana(bot:GetAbilityByName(Q)) == true,
        'with one enemy hero in sight the release must NOT fire')
end

-- ---------------------------------------------------------------------------
-- 3. The corpus walk: the domain, and the direction, over all 33 priced frames.

tests['[section 3] 33 priced WK frames; the reserve fires on 6; armed releases 2'] =
function()
    local corpus = priced_corpus()
    assert(#corpus == 33, 'the priced corpus holds ' .. #corpus .. ' Wraith King '
        .. 'frames, recorded 33.  Fixtures were added or removed; re-read every '
        .. 'count in this file before quoting one')

    -- ONE tally, called twice with the legs SWAPPED.  The first call must report
    -- 0 for the forbidden direction; the second call reports the WHOLE domain
    -- through the same code path, so a tally that never ran cannot masquerade as
    -- a direction that holds.
    local function tally(a, b, sDown, sUp, into)
        if a and not b then into[sDown] = into[sDown] + 1 end
        if b and not a then into[sUp] = into[sUp] + 1 end
    end

    local n = { ship = 0, arm = 0, t2f = 0, f2t = 0, swap_t2f = 0, swap_f2t = 0 }
    local released = {}
    for _, path in ipairs(corpus) do
        local s = reserve(path)
        local a = reserve(path, { arm = true })
        if s then n.ship = n.ship + 1 end
        if a then n.arm = n.arm + 1 end
        tally(s, a, 't2f', 'f2t', n)
        tally(a, s, 'swap_f2t', 'swap_t2f', n)   -- legs swapped, same function
        if s and not a then released[#released + 1] = short(path) end
    end

    assert(n.ship == 6, 'the shipped reserve fires on ' .. n.ship
        .. ' priced frames, recorded 6')
    assert(n.arm == 4, 'armed it fires on ' .. n.arm .. ', recorded 4')
    assert(n.t2f == 2, 'the armed leg releases ' .. n.t2f .. ' frames, recorded 2')
    -- The forbidden direction, and the proof the counter can count: the swapped
    -- call routes the same 2 frames through the branch that must read 0 above.
    assert(n.f2t == 0, 'the armed leg turned the reserve ON somewhere ('
        .. n.f2t .. ' frames).  This lever may only release, never impose')
    assert(n.swap_t2f == 2 and n.swap_f2t == 0,
        'the swapped call read ' .. n.swap_t2f .. '/' .. n.swap_f2t
        .. ', recorded 2/0 -- if this is 0/0 the tally never ran and the zero '
        .. 'asserted just above is vacuous')

    table.sort(released)
    local expect = { short(DOMAIN[1]), short(DOMAIN[2]) }
    table.sort(expect)
    assert(table.concat(released, ', ') == table.concat(expect, ', '),
        'the released frames are now {' .. table.concat(released, ', ')
        .. '}, recorded {' .. table.concat(expect, ', ') .. '}')
end

tests['[section 3] the 4 frames left alone are the ones with enemies in sight'] =
function()
    -- The negative half of the domain, asserted rather than assumed: every frame
    -- where the reserve still fires under arming must have at least one visible
    -- enemy or be short of full health.  Without this, "released 2" would be
    -- consistent with the helper answering by accident.
    local corpus = priced_corpus()
    local kept = 0
    for _, path in ipairs(corpus) do
        if reserve(path) and reserve(path, { arm = true }) then
            kept = kept + 1
            local _, bot, J = frame(path, { arm = true })
            local seen = #J.GetNearbyHeroes(bot, 1600, true, BOT_MODE_NONE)
            local hp = bot:GetHealth() / bot:GetMaxHealth()
            assert(seen > 0 or hp < 0.95, short(path) .. ' keeps the reserve with '
                .. seen .. ' visible enemies at ' .. string.format('%.2f', hp)
                .. ' health -- neither term explains it, so the helper is '
                .. 'answering for some third reason')
        end
    end
    assert(kept == 4, kept .. ' frames keep the reserve under arming, recorded 4')
end

-- ---------------------------------------------------------------------------
-- 4. Inertness.  A gated fix that is not inert is a defaults change wearing a
--    candidate's name.

tests['[section 4] unarmed, every priced frame answers exactly as shipped'] =
function()
    -- The whole corpus, not a sample: "inert" is a claim about all of it.  This
    -- is the assertion that fails if the release ever escapes its gate.
    for _, path in ipairs(priced_corpus()) do
        local _, bot = frame(path)
        local X2 = rf.load_hero('skeleton_king')
        assert(X2.IsReincarnationReserveIdle() == false,
            short(path) .. ': the release answered true with nothing armed')
        assert(bot ~= nil)
    end
end

tests['[section 4] armed but OUTSIDE turbo, the two domain frames do not move'] =
function()
    for _, path in ipairs(DOMAIN) do
        assert(reserve(path, { arm = true, nonTurbo = true }) == true,
            short(path) .. ': outside turbo the candidate must be inert')
    end
end

tests['[section 4] arming a DIFFERENT id moves nothing'] =
function()
    -- The typo control.  A gate that answers true for any armed string would
    -- pass every test above while being armed by every wave in the lab.
    for _, path in ipairs(DOMAIN) do
        local J, bot = rf.load(path, WK)
        J.IsSoakCandidate = function(id) return id == 'wkrosh' end
        local X = rf.load_hero('skeleton_king')
        pcall(function() X.SkillsComplement() end)
        assert(X.ShouldSaveMana(bot:GetAbilityByName(Q)) == true,
            short(path) .. ': the reserve released on someone else\'s candidate id')
    end
end

-- ---------------------------------------------------------------------------
-- 5. The reserve is spent on BOTH abilities.  This is why the lever is worth
--    anything at all, and it is a fact about call sites, not about this helper.

tests['[section 5] the reserve is consulted on the first line of ConsiderQ AND ConsiderW'] =
function()
    local src = read_file(WK_SRC)
    local _, n = src:gsub('X%.ShouldSaveMana%(%s*ability[QW]%s*%)', '')
    assert(n == 2, 'X.ShouldSaveMana is consulted at ' .. n .. ' ability call '
        .. 'sites, recorded 2 (abilityQ in X.ConsiderQ, abilityW in X.ConsiderW).  '
        .. 'If a site was added or removed, the cost of a firing reserve moved')
    for _, fn in ipairs({ 'ConsiderQ', 'ConsiderW' }) do
        local body = src:match('function X%.' .. fn .. '%b()(.-)\n\tlocal ')
            or src:match('function X%.' .. fn .. '%b()(.-)\nend')
        assert(body:find('X.ShouldSaveMana', 1, true),
            fn .. ' no longer consults the reserve')
        assert(body:find('DESIRE_NONE', 1, true) or body:find('return 0', 1, true),
            fn .. "'s reserve clause no longer returns a refusal")
    end
end

-- ---------------------------------------------------------------------------
-- 6. The boundary this file must not be quoted past.

tests['[section 6] releasing the reserve is NOT casting a blast'] =
function()
    -- Re-derived here rather than cited: on both domain frames the shipped
    -- X.ConsiderQ answers 0 with the reserve released, for reasons downstream of
    -- this lever.  Anyone reading "2 frames released" as "2 blasts cast" is
    -- reading past the meter, and this assertion is what says so.
    for _, path in ipairs(DOMAIN) do
        local X = frame(path, { arm = true })
        local d = X.ConsiderQ()
        assert(d == 0, short(path) .. ': X.ConsiderQ now answers ' .. tostring(d)
            .. ' with the reserve released.  That is a NEW fact -- the corpus '
            .. 'used to be silent downstream, and a domain reading in this file '
            .. 'can now be about casts.  Re-read the header before quoting it')
    end
end

tests['[section 7] this lever did not touch the rank blindness'] =
function()
    -- The neighbouring gap, kept visibly open.  tests/test_wk_save_mana_lock_census.lua
    -- section 6 owns it; if it is ever closed here by accident, that file and
    -- this one must move together rather than silently disagree.
    local src = read_file(WK_SRC)
    local body = src:match('function X%.ShouldSaveMana%b()(.-)\nend')
    assert(not body:find('abilityR:GetLevel', 1, true),
        'the reserve rule now asks R\'s rank.  That is a different lever '
        .. "('wkreinctr' is its sibling at the retreat site); if it was closed "
        .. 'deliberately, update the census file section 6 in the same change')
    local rel = src:match('function X%.IsReincarnationReserveIdle%b()(.-)\nend')
    assert(not rel:find('IsTrained', 1, true) and not rel:find('GetLevel', 1, true),
        'the release helper now reads the ultimate\'s rank; that is the other '
        .. 'gap and it must not ride in on this id')
end

return tests

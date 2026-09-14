-- [hero] [ratchet] `cmrspeed` -- Crystal Maiden's Freezing Field hurt-count
-- ring SUBTRACTS A SPEED FROM A DISTANCE.
--
-- THE DEFECT, in one line of shipped source (X.ConsiderR, branch 1's quality
-- loop):
--
--     J.IsInRange( bot, enemy, nRadius * 0.82 - enemy:GetCurrentMovementSpeed() )
--
-- The left term is units.  GetCurrentMovementSpeed() is units PER SECOND.  A
-- displacement is speed x time, so the shipped expression carries an unwritten
-- factor of exactly 1.0 SECOND.  ⚠️ Said honestly rather than conveniently: the
-- ability does carry a 1.0 -- `slow_duration` -- and that is the duration of the
-- slow an explosion applies, not a time between the decision and the damage.
-- The claim is about what 1.0 MEANS here, not that the token is absent from
-- the KV.  Section 2 asserts both halves of that sentence.
--
-- WHAT THE UNWRITTEN SECOND COSTS (section 3, driven off the KV and the anchor):
-- base ring 835 * 0.88 * 0.82 = 602.536u, so the admitted ring is
-- `602.536 - speed` -- 302.5u at 300, 102.5u at 500, and NEGATIVE above 602.6,
-- where J.IsInRange can never be true.  Above that speed the conjunct is not a
-- filter, it is an off-switch.
--
-- THE REPAIR reads the horizon off the ability: Freezing Field has
-- AbilityCastPoint 0 and detonates every `explosion_interval` (0.1s), so the
-- soonest damage instant is one interval out.  Direction is WIDENING by
-- construction (section 4): shipped is bound first, the armed horizon is refused
-- unless it lies in [0, 1.0], and speed is non-negative.
--
-- ⛔ WHAT THIS FILE DOES NOT CLAIM.  Not that CM should ult on the collision
-- frame of section 6 -- the frame's ground truth is `died_after = 0.2` and what
-- was wrong with it is a SAFETY fact (0.30 HP, zero allies, three enemies).
-- `aoeCanHurtCount` is a damage-REACH meter; the unwritten second corrupts it
-- into an accidental safety meter, and repairing the meter removes the accident.
-- The safety terms are `cmrsolo` and `cmrcrowd`, and section 6 is why this id
-- must not be co-armed with `cmrcrowd`.
--
-- ⚠️ TWO OFFLINE METERS, declared and asserted in section 7 rather than assumed:
--   * `GetAOERadius()` is not served by the fixture loader, so every distance
--     here rides the 835 ANCHOR of tests/test_replay_260819_cm_r_range.lua
--     (GH #502), written in by this test exactly as tests/test_cm_r_crowd_release
--     .lua writes it.
--   * `GetCurrentMovementSpeed()` is not in the dump (GH #786); the mock answers
--     a flat 300 for every unit on every frame.  ⇒ NO FREQUENCY CLAIM is
--     available from this corpus and none is made; condition (a) is requested in
--     iterations/queue.json, not claimed here.

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')

local SRC  = 'bots/BotLib/hero_crystal_maiden.lua'
local CAND = 'cmrspeed'

-- External anchor, see the header.  Same number, same provenance, as
-- tests/test_replay_260819_cm_r_range.lua and tests/test_cm_r_crowd_release.lua.
local FIELD_RADIUS = 835

-- The frame tests/test_cm_r_crowd_release.lua pins for `cmrcrowd`.  It is reused
-- here because it is the frame on which the two ids COLLIDE.
local PIN = 'tests/fixtures/f_260820_043039_cm_cask_close.lua'

-- Every Crystal-Maiden-SUBJECT fixture, listed rather than globbed so a new one
-- is a deliberate edit.  Same list tests/test_cm_r_crowd_release.lua carries.
local CM_FRAMES = {
    'tests/fixtures/f_113638_cm_chain_rescue.lua',
    'tests/fixtures/f_260819_003005_cm_selfpreserve.lua',
    'tests/fixtures/f_260819_004858_cm_centaur_far.lua',
    'tests/fixtures/f_260820_042009_cm_cask_far.lua',
    'tests/fixtures/f_260820_043039_cm_cask_close.lua',
    'tests/fixtures/f_260820_102645_cm_es_reach.lua',
    'tests/fixtures/f_260820_102645_cm_laning_release.lua',
    'tests/fixtures/f_260820_103216_cm_es_aftershock.lua',
    'tests/fixtures/f_260902_154755_cm_wandbleed_residue.lua',
    'tests/fixtures/f_260903_101254_cm_farm_stealcamp.lua',
}

local tests = {}

local function read_file(path)
    local fh = assert(io.open(path, 'r'), 'cannot open ' .. path)
    local body = fh:read('*a')
    fh:close()
    return body
end

--- Comments stripped, so a ratchet counting code shapes cannot be satisfied by
--- prose that merely mentions the expression.
local function strip_comments(s)
    return (s:gsub('%-%-[^\n]*', ''))
end

--- The contiguous `---` note block immediately ABOVE one X.<name> function.
--- fn_body below starts at the `function` keyword and therefore cannot see the
--- header; a claim that has to be READABLE AT ARM TIME lives in the header, so
--- it needs its own reader.
local function fn_note(src, name)
    local from = src:find('function X%.' .. name .. '%s*%(')
    assert(from, 'X.' .. name .. ' not found in ' .. SRC)
    local head = src:sub(1, from - 1)
    -- Walk back over the unbroken run of `---` lines that ends at the function.
    -- ⚠️ NOT `gmatch('[^\n]*')`: in Lua 5.1 that pattern also matches the empty
    -- string at each position after a match, so it yields "line", "", "line",
    -- "" ... and the backward walk below stops on the first interleaved blank.
    -- The first draft of this file did exactly that and kept ONE line.
    local lines, keep = {}, {}
    for line in (head .. '\n'):gmatch('([^\n]*)\n') do lines[#lines + 1] = line end
    for i = #lines, 1, -1 do
        if lines[i]:match('^%-%-%-') then
            table.insert(keep, 1, lines[i])
        elseif lines[i]:match('^%s*$') and #keep == 0 then
            -- trailing blank between note and function: skip
        else
            break
        end
    end
    return table.concat(keep, '\n')
end

--- The source of one X.<name> function, comments included.
local function fn_body(src, name)
    local from = src:find('function X%.' .. name .. '%s*%(')
    assert(from, 'X.' .. name .. ' not found in ' .. SRC)
    local rest = src:sub(from)
    local to = rest:find('\nfunction X%.')
    return to and rest:sub(1, to) or rest
end

--- Load a frame, arm/disarm, anchor the AoE radius.  The ONLY injection is the
--- AoE-radius anchor; nobody is moved, no cooldown is cleared, no HP is edited.
local function on_frame(path, opt)
    opt = opt or {}
    local J, bot, heroes, fx = rf.load(path)
    J.IsSoakCandidate = function(id)
        return opt.armed == true and id == (opt.cand or CAND)
    end
    if opt.nonTurbo then
        GetGameMode = function() return 1 end
    end
    local sAbilityList = J.Skill.GetAbilityList(bot)
    assert(sAbilityList[6] == 'crystal_maiden_freezing_field',
        path .. ': the ultimate must be reachable in the fixture world (GH #36)')
    local abilityR = bot:GetAbilityByName(sAbilityList[6])
    if not opt.noAnchor then
        rawget(abilityR, '__spec').GetAOERadius = FIELD_RADIUS
    end
    local X = rf.load_hero('crystal_maiden')
    return X, J, bot, heroes, fx, abilityR
end

--- Re-derive branch 1's hurt count from the same helpers the shipped code uses,
--- routing the ring through the helper under test.  Deliberately a
--- RE-DERIVATION rather than a read of the shipped loop's own answer.
local function hurt_count(X, J, bot, abilityR)
    local nRadius = abilityR:GetAOERadius() * 0.88
    local inRange = J.GetNearbyHeroes(bot, nRadius, true, BOT_MODE_NONE)
    local hurt, dists = 0, {}
    for _, e in pairs(inRange) do
        if J.IsValid(e) and J.CanCastOnNonMagicImmune(e) then
            dists[#dists + 1] = GetUnitToUnitDistance(bot, e)
            if J.IsDisabled(e)
                or J.IsInRange(bot, e,
                    X.cm_GetFieldHurtRing(nRadius * 0.82,
                                          e:GetCurrentMovementSpeed(), abilityR))
            then
                hurt = hurt + 1
            end
        end
    end
    return hurt, #inRange, nRadius, dists
end

--- ---------------------------------------------------------------- section 1 --
--- The defect and the repair, pinned in the SOURCE.  These say what the shipped
--- tree looks like, so a later edit that quietly re-types the bare expression at
--- the call site turns this file red rather than silently un-levering it.

tests['1.1: the bare speed subtraction is GONE from the call site'] = function()
    local code = strip_comments(read_file(SRC))
    local _, n = code:gsub('%*%s*0%.82%s*%-%s*[%w_]+:GetCurrentMovementSpeed%(%)', '')
    assert(n == 0,
        'the shipped bare expression `* 0.82 - <unit>:GetCurrentMovementSpeed()` is '
        .. 'back at a call site (' .. n .. ' occurrence(s)). It must go through '
        .. 'X.cm_GetFieldHurtRing, or the lever is bypassed on that line.')
end

tests['1.2: the call site still owns 0.82, and the helper never types it'] = function()
    local code = strip_comments(read_file(SRC))
    local _, nSite = code:gsub('cm_GetFieldHurtRing%(%s*nRadius%s*%*%s*0%.82', '')
    assert(nSite == 1,
        'expected exactly one call site passing `nRadius * 0.82` as the base '
        .. 'ring, found ' .. nSite .. '. The 0.82 is read off ONE place on '
        .. 'purpose (same rule as `cmrflee`\'s 0.38).')
    local body = strip_comments(fn_body(read_file(SRC), 'cm_GetFieldHurtRing'))
    assert(not body:find('0%.82'),
        'X.cm_GetFieldHurtRing types 0.82 itself. It must not: a second copy can '
        .. 'drift from the call site.')
end

tests['1.3: the helper binds the shipped ring FIRST (the direction guarantee)'] = function()
    local body = strip_comments(fn_body(read_file(SRC), 'cm_GetFieldHurtRing'))
    local iShipped = body:find('local%s+nShipped%s*=')
    local iGate    = body:find('IsSoakCandidate')
    assert(iShipped and iGate and iShipped < iGate,
        'the shipped ring must be computed and BOUND before the gate is read. '
        .. 'That ordering is what makes "armed can only widen" a property of the '
        .. 'shape rather than of today\'s KV.')
end

tests['1.4: the gate names exactly one id, and no sibling (the pullcad trap)'] = function()
    local body = strip_comments(fn_body(read_file(SRC), 'cm_GetFieldHurtRing'))
    local seen = {}
    for id in body:gmatch("IsSoakCandidate%(%s*'([%w_]+)'%s*%)") do seen[#seen + 1] = id end
    assert(#seen == 1 and seen[1] == CAND,
        'X.cm_GetFieldHurtRing must name exactly one soak id and it must be '
        .. CAND .. '; found {' .. table.concat(seen, ', ') .. '}. A gate naming a '
        .. 'sibling freezes FALSE the day that sibling is promoted.')
    for _, sib in ipairs({ 'cmrcrowd', 'cmrsolo', 'cmrflee', 'cmrself', 'cmrcap' }) do
        assert(not body:find(sib, 1, true),
            'sibling id ' .. sib .. ' appears inside this helper.')
    end
end

tests['1.5: the helper is turbo-gated'] = function()
    local body = strip_comments(fn_body(read_file(SRC), 'cm_GetFieldHurtRing'))
    assert(body:find('IsModeTurbo'),
        'behaviour changes ship turbo-only (AGENTS.md).')
end

--- ---------------------------------------------------------------- section 2 --
--- The dimensional fact, read off the game's own KV rather than re-typed.

tests['2.1: the ability carries explosion_interval, and it is 0.1'] = function()
    local _, _, _, _, _, abilityR = on_frame(PIN)
    local nInterval = abilityR:GetSpecialValueFloat('explosion_interval')
    assert(math.abs(nInterval - 0.1) < 1e-9,
        'crystal_maiden_freezing_field/explosion_interval read ' .. tostring(nInterval)
        .. ', expected 0.1. The repair\'s horizon is READ off this key; if the KV '
        .. 'moved, the lever\'s arithmetic moved with it and the note must be re-read.')
end

tests['2.2: the cast point really is 0 (so it is not the horizon)'] = function()
    local _, _, _, _, _, abilityR = on_frame(PIN)
    assert(abilityR:GetCastPoint() == 0,
        'AbilityCastPoint is no longer 0. The note argues the soonest damage '
        .. 'instant is one explosion_interval BECAUSE the cast point is 0; if '
        .. 'that changed, the horizon argument has to be redone.')
end

tests['2.3: the 1.0 the shipped source implies is slow_duration, and that is NOT a travel horizon'] = function()
    local _, _, _, _, _, abilityR = on_frame(PIN)
    -- The honest half of the header: the token 1.0 IS in this ability's KV.
    assert(math.abs(abilityR:GetSpecialValueFloat('slow_duration') - 1.0) < 1e-9,
        'slow_duration is no longer 1.0. The header says plainly that the '
        .. 'ability carries a 1.0 and that it is this one; keep the note true.')
    -- ...and it is the slow's duration, not a time-to-damage, which is why the
    -- repair does not read it.  Asserted as a SOURCE fact so nobody quietly
    -- repoints the horizon at it.
    local body = strip_comments(fn_body(read_file(SRC), 'cm_GetFieldHurtRing'))
    assert(not body:find('slow_duration', 1, true),
        'the horizon must not be read from slow_duration -- that key is the '
        .. 'duration of the slow an explosion applies, not a time to damage.')
end

--- ---------------------------------------------------------------- section 3 --
--- What the unwritten second costs, as arithmetic.  Driven through the helper,
--- unarmed, so these numbers ARE the shipped tree's numbers.

local BASE = FIELD_RADIUS * 0.88 * 0.82   -- 602.536

tests['3.1: the shipped ring at ordinary hero movespeeds'] = function()
    local X = on_frame(PIN)
    local rows = {}
    for _, s in ipairs({ 300, 400, 500, 600, 700 }) do
        rows[#rows + 1] = string.format('%d -> %.1f', s, X.cm_GetFieldHurtRing(BASE, s, nil))
    end
    -- Each entry is the shipped `602.536 - speed`; the point of the table is
    -- the LAST two rows, not the first.
    assert(math.abs(X.cm_GetFieldHurtRing(BASE, 300, nil) - (BASE - 300)) < 1e-9,
        'unarmed the helper must be the shipped expression: ' .. table.concat(rows, ', '))
    assert(X.cm_GetFieldHurtRing(BASE, 700, nil) < 0,
        'at 700 movespeed the shipped ring must be NEGATIVE -- that is the '
        .. 'off-switch this lever is about. Table: ' .. table.concat(rows, ', '))
end

tests['3.2: the shipped ring crosses zero inside the reachable movespeed range'] = function()
    local X = on_frame(PIN)
    -- The crossover is BASE itself; it is asserted as a bracket rather than a
    -- typed constant so a moved anchor moves the claim with it.
    local lo = math.floor(BASE)
    assert(X.cm_GetFieldHurtRing(BASE, lo, nil) > 0
       and X.cm_GetFieldHurtRing(BASE, lo + 1, nil) < 0,
        string.format('the shipped ring must change sign between %d and %d '
            .. 'movespeed (base ring %.3f)', lo, lo + 1, BASE))
end

--- ---------------------------------------------------------------- section 4 --
--- Direction, on a grid rather than on one frame: armed is never narrower.

tests['4.1: armed >= shipped on the whole grid (WIDENING by construction)'] = function()
    local Xoff = on_frame(PIN, { armed = false })
    local Xon  = on_frame(PIN, { armed = true })
    local _, _, _, _, _, abilityR = on_frame(PIN, { armed = true })
    local nWider = 0
    for base = 0, 900, 75 do
        for speed = 0, 800, 50 do
            local off = Xoff.cm_GetFieldHurtRing(base, speed, abilityR)
            local on  = Xon.cm_GetFieldHurtRing(base, speed, abilityR)
            assert(on >= off - 1e-9, string.format(
                'armed NARROWED at base=%d speed=%d: %.3f < %.3f', base, speed, on, off))
            if on > off + 1e-9 then nWider = nWider + 1 end
        end
    end
    assert(nWider > 0,
        'armed never widened anywhere on the grid -- the lever would be a no-op '
        .. 'in every wave and a verdict of "tested, no effect" would be the '
        .. 'gate\'s zero, not the game\'s.')
end

--- ⭐ THIS ASSERTION EXISTS BECAUSE A MUTANT SURVIVED WITHOUT IT (2026-09-14).
--- mutstand_cmrspeed.sh M4 repoints the horizon at `AbilityCastPoint`, which
--- this ability declares as 0, so the armed ring becomes the FULL base ring --
--- a different and much larger lever wearing this id.  The first draft of this
--- file could not see it, and the reason is a 6.9u coincidence rather than
--- anything about the lever: section 6's third enemy stands at 609.4u and the
--- full base ring is 602.536u, so he falls outside EITHER way and the frame
--- still reads 2.  A corpus that cannot separate 0.1 from 0 needs the helper's
--- output pinned directly, against a horizon the TEST reads for itself.
tests['4.3: the armed ring is the base minus exactly one explosion_interval of travel'] = function()
    local Xon = on_frame(PIN, { armed = true })
    local _, _, _, _, _, abilityR = on_frame(PIN, { armed = true })
    local nHorizon = abilityR:GetSpecialValueFloat('explosion_interval')
    for _, s in ipairs({ 0, 300, 450, 800 }) do
        local got = Xon.cm_GetFieldHurtRing(BASE, s, abilityR)
        assert(math.abs(got - (BASE - s * nHorizon)) < 1e-9, string.format(
            'armed at speed %d answered %.4f, expected %.4f = base - speed * '
            .. 'explosion_interval(%.3f). A horizon read from some OTHER key '
            .. '(AbilityCastPoint is declared 0) is a different lever wearing '
            .. 'this id.', s, got, BASE - s * nHorizon, nHorizon))
    end
    assert(Xon.cm_GetFieldHurtRing(BASE, 300, abilityR) < BASE - 1e-9,
        'armed must still subtract SOMETHING at 300 movespeed; answering the '
        .. 'bare base ring means the horizon collapsed to 0.')
end

tests['4.2: at speed 0 the two legs agree exactly (the degenerate case)'] = function()
    local Xoff = on_frame(PIN, { armed = false })
    local Xon  = on_frame(PIN, { armed = true })
    local _, _, _, _, _, abilityR = on_frame(PIN, { armed = true })
    assert(Xoff.cm_GetFieldHurtRing(BASE, 0, abilityR)
        == Xon.cm_GetFieldHurtRing(BASE, 0, abilityR),
        'a stationary enemy must be priced identically by both legs; the whole '
        .. 'difference is a displacement.')
end

--- ---------------------------------------------------------------- section 5 --
--- Gate off, byte for byte -- including the two degeneracies.

tests['5.1: unarmed turbo is the shipped expression'] = function()
    local X = on_frame(PIN, { armed = false })
    local _, _, _, _, _, abilityR = on_frame(PIN, { armed = false })
    for _, s in ipairs({ 0, 137, 300, 450, 602, 1000 }) do
        assert(X.cm_GetFieldHurtRing(BASE, s, abilityR) == BASE - s,
            'unarmed, speed ' .. s .. ': the helper must be `base - speed` exactly.')
    end
end

tests['5.2: armed but NOT turbo is the shipped expression'] = function()
    local X = on_frame(PIN, { armed = true, nonTurbo = true })
    local _, _, _, _, _, abilityR = on_frame(PIN, { armed = true, nonTurbo = true })
    for _, s in ipairs({ 0, 300, 602 }) do
        assert(X.cm_GetFieldHurtRing(BASE, s, abilityR) == BASE - s,
            'outside turbo the lever must be inert (speed ' .. s .. ').')
    end
end

tests['5.3: a handle that cannot answer the key degenerates to shipped'] = function()
    local X = on_frame(PIN, { armed = true })
    assert(X.cm_GetFieldHurtRing(BASE, 300, nil) == BASE - 300,
        'a nil handle must fall back to the shipped ring, not to a bare base.')
    local dud = { GetSpecialValueFloat = function() return nil end }
    assert(X.cm_GetFieldHurtRing(BASE, 300, dud) == BASE - 300,
        'a handle answering nil must fall back to the shipped ring.')
    local silly = { GetSpecialValueFloat = function() return 9.0 end }
    assert(X.cm_GetFieldHurtRing(BASE, 300, silly) == BASE - 300,
        'a horizon ABOVE the shipped 1.0 must be refused -- otherwise the armed '
        .. 'leg could narrow, and the direction guarantee is gone.')
    local neg = { GetSpecialValueFloat = function() return -1 end }
    assert(X.cm_GetFieldHurtRing(BASE, 300, neg) == BASE - 300,
        'a negative horizon must be refused.')
end

tests['5.4: a negative speed is refused (the direction proof assumes speed >= 0)'] = function()
    local X = on_frame(PIN, { armed = true })
    local _, _, _, _, _, abilityR = on_frame(PIN, { armed = true })
    assert(X.cm_GetFieldHurtRing(BASE, -50, abilityR) == BASE + 50,
        'with a negative speed the helper must answer the shipped expression, '
        .. 'which is the one case where armed-widens would not follow from the '
        .. 'shape.')
end

--- ---------------------------------------------------------------- section 6 --
--- THE COLLISION, on real frames.  This is the section to read before quoting
--- any wave verdict that armed BOTH this id and `cmrcrowd`.

tests['6.1: the pin frame -- shipped admits nobody, armed admits two'] = function()
    local Xoff, Joff, botOff, _, _, aOff = on_frame(PIN, { armed = false })
    local Xon,  Jon,  botOn,  _, _, aOn  = on_frame(PIN, { armed = true })

    local hOff, nInOff, nRadius, dists = hurt_count(Xoff, Joff, botOff, aOff)
    local hOn,  nInOn                   = hurt_count(Xon,  Jon,  botOn,  aOn)

    table.sort(dists)
    local shown = {}
    for i, d in ipairs(dists) do shown[i] = string.format('%.1f', d) end
    local ctx = string.format(
        'frame %s: field radius %.1f, %d castable enemies at {%s}u; '
        .. 'shipped ring %.1f, armed ring %.1f',
        PIN, nRadius, nInOff, table.concat(shown, ', '),
        Xoff.cm_GetFieldHurtRing(nRadius * 0.82, 300, aOff),
        Xon.cm_GetFieldHurtRing(nRadius * 0.82, 300, aOn))

    assert(nInOff == 3 and nInOn == 3, ctx .. ' -- expected 3 enemies in the field')
    assert(hOff == 0, ctx .. ' -- shipped hurt count must be 0 (this is what makes '
        .. '`cmrcrowd`\'s head-count disjunct the SOLE reason for that bid)')
    assert(hOn == 2, ctx .. ' -- armed hurt count must be 2, i.e. `aoeCanHurtCount '
        .. '>= 2` fires branch 1 through the OTHER disjunct on the very frame '
        .. '`cmrcrowd` removes it from. THIS IS THE COLLISION: the two ids must '
        .. 'not be armed in the same leg.')
end

tests['6.2: the collision is registered in the source, not only here'] = function()
    local note = fn_note(read_file(SRC), 'cm_GetFieldHurtRing')
    assert(note ~= '' and note:find('cmrcrowd', 1, true),
        'the helper\'s note must name `cmrcrowd` and the co-arm ban. A collision '
        .. 'that lives only in a test file is one nobody reads at arm time.')
    assert(note:find('f_260820_043039_cm_cask_close', 1, true),
        'the note must name the frame the collision was MEASURED on, so the '
        .. 'reader can re-run it rather than take the sentence on trust.')
end

tests['6.3: the corpus-wide hurt-count table, armed vs shipped'] = function()
    -- ⭐ THE DENOMINATOR IS PINNED FIRST, and that is also why this assertion
    -- exists: mutstand_cmrspeed.sh M12 deletes a frame from the list, and a
    -- census whose only claim is "moved >= 1" stays green while its population
    -- silently shrinks. A rate whose denominator can move without saying so is
    -- not a reading.
    assert(#CM_FRAMES == 10,
        'the CM-subject frame list is no longer 10 frames (' .. #CM_FRAMES
        .. '). Adding or removing one is a deliberate edit -- update this count '
        .. 'and re-read every number in this file that quotes the population.')
    local hasPin = false
    for _, p in ipairs(CM_FRAMES) do if p == PIN then hasPin = true end end
    assert(hasPin, 'the pin frame ' .. PIN .. ' has left the corpus list; '
        .. 'section 6.1 and this census would stop measuring the same population.')

    local moved, rows = 0, {}
    for _, path in ipairs(CM_FRAMES) do
        local Xoff, Joff, botOff, _, _, aOff = on_frame(path, { armed = false })
        local Xon,  Jon,  botOn,  _, _, aOn  = on_frame(path, { armed = true })
        local hOff, nIn = hurt_count(Xoff, Joff, botOff, aOff)
        local hOn       = hurt_count(Xon,  Jon,  botOn,  aOn)
        assert(hOn >= hOff, path .. ': armed hurt count went DOWN (' .. hOff
            .. ' -> ' .. hOn .. '), which the construction forbids.')
        if hOn ~= hOff then moved = moved + 1 end
        rows[#rows + 1] = string.format('%s in=%d %d->%d',
            path:match('f_[%w_]+'), nIn, hOff, hOn)
    end
    -- ⛔ A DOMAIN, NOT A RATE.  Ten frames is not ten games, and the movespeed
    -- every one of them answers is the mock's flat 300 (section 7).  The
    -- assertion is only that the domain is NON-EMPTY, so a later harness change
    -- that silently empties it says so here.
    assert(moved >= 1,
        'the lever moved the hurt count on ZERO of ' .. #CM_FRAMES .. ' CM frames. '
        .. 'Table: ' .. table.concat(rows, ' | '))
end

--- ---------------------------------------------------------------- section 7 --
--- The two offline meters, asserted rather than assumed.  If either becomes
--- readable, every distance in this file has to be re-read.

tests['7.1: GetAOERadius is still NOT served by the loader (the anchor is load-bearing)'] = function()
    local _, _, _, _, _, abilityR = on_frame(PIN, { noAnchor = true })
    assert(rawget(abilityR, '__spec').GetAOERadius == nil,
        'the loader now serves GetAOERadius. WHERE FROM decides what to do: a '
        .. 'dumped frame value retires the 835 anchor, a KV read does NOT (GH #502).')
    assert(abilityR:GetAOERadius() == 0,
        'unanchored, GetAOERadius answers the generic `^Get` 0 -- which is why '
        .. 'this file writes the anchor in.')
end

tests['7.2: GetCurrentMovementSpeed is the mock flat 300, on every unit of every frame'] = function()
    local seen = {}
    for _, path in ipairs(CM_FRAMES) do
        local _, J, bot = on_frame(path)
        seen[bot:GetCurrentMovementSpeed()] = true
        for _, e in pairs(J.GetNearbyHeroes(bot, 3000, true, BOT_MODE_NONE)) do
            seen[e:GetCurrentMovementSpeed()] = true
        end
    end
    local vals = {}
    for v in pairs(seen) do vals[#vals + 1] = v end
    assert(#vals == 1 and vals[1] == 300,
        'the corpus no longer answers a single flat movespeed (saw {'
        .. table.concat(vals, ', ') .. '}). If the dumper started carrying speed '
        .. '(GH #786), section 6\'s table becomes a real reading and the '
        .. '"no frequency claim" line in the header can finally be retired.')
end

return tests

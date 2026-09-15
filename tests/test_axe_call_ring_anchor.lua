-- [ratchet] [hero] `axecallring` -- Berserker's Call is decided by the RING, not
-- by the one hero Axe happens to be committing on.  Written 2026-09-15 under
-- OWNER_PRIORITIES P4.4 (i): the work unit's body is a bots/ behaviour change.
--
-- WHAT THIS LEVER IS, IN ONE SENTENCE, AND WHAT IT IS NOT
-- ------------------------------------------------------
-- X.ConsiderQ's initiation firing point asks `J.IsValidHero( botTarget ) and
-- J.IsInRange( botTarget, bot, nRadius - 90 )` -- one unit -- before casting a
-- no-target AoE taunt that takes every enemy hero inside 315u.  This id adds a
-- SECOND firing point, after the shipped one, that asks the ring instead.
--
-- ⚠️ IT IS NOT `axecallbkb_ii` RE-STATED.  That id widens which ANSWER the one
-- interrogated unit may give (a spell-immune botTarget stops vetoing); it leaves
-- the anchor where it is.  This one moves the anchor and touches no immunity
-- term at all -- section 3 drives the counter applying the SHIPPED
-- J.CanCastOnNonMagicImmune to each ring member.  Section 7 asserts the two ids
-- stay independent in source (the `pullcad` trap) and that arming (ii) alone
-- does not fire this branch.
--
-- ⛔ TWO DOMAINS, TWO NUMBERS, AND THEY ARE NOT THE SAME NUMBER
-- ------------------------------------------------------------
--   * BRANCH-LEVEL domain = 1 instant.  Of the 28 Call-READY Axe hero rows in
--     tests/fixtures/ + tests/frames/, exactly one holds >= 2 live enemy heroes
--     inside the 225u ring (section 2 counts them rather than quoting them).
--   * END-TO-END domain = 0, and section 5 asserts it in the direction that can
--     go red.  On that same frame X.SkillsComplement asks X.ConsiderR FIRST and
--     Culling Blade wins the arm order, so arming this id changes no ACTION on
--     any frame this corpus can produce.  A round that reported the branch
--     number as if it were the end-to-end number would be reporting a cast that
--     does not happen.
--
-- HONEST BOUNDS -- READ BEFORE QUOTING ANY NUMBER FROM HERE
-- ---------------------------------------------------------
--   * ONE READER IS REPAIRED, in section 4 only.  J.IsGoingOnSomeone reads
--     bot:GetActiveMode(), and the behav dumper's snapshot schema carries no
--     active-mode channel, so it is false on EVERY frame make_fixture.py can
--     produce (GH #577 section 5).  Section 4 sets GetActiveMode to
--     BOT_MODE_ATTACK.  ⚠️ That repair has the WEAKER of the two standings
--     tests/test_axe_call_staged_frames.lua distinguishes: there is no shipped
--     criterion for it to agree with, so it rests on the FRAME's own ground
--     truth -- that frame's recent_damage carries four 19-point Axe attack
--     instances on Shadow Shaman inside the window, i.e. Axe is committing on an
--     enemy hero at that instant.  It is labelled weaker here and anyone
--     quoting section 4 carries this bullet with it.
--   * NOTHING ELSE IS INVENTED.  Call is rank 3 at cd 0 in the replay, mana 319
--     against a 110 cost, and every distance, health and modifier below is the
--     replay's.
--   * THE FRAME IS STAGED, NOT ADMITTED.  f_260828_002127_axe_call_bkb_ring.lua
--     lives in tests/frames/ and is loaded BY NAME; its admission price to
--     tests/fixtures/ is not measured here.  Same disposition as the two frames
--     tests/test_axe_call_staged_frames.lua drives.

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')

local SRC = 'bots/BotLib/hero_axe.lua'
local FIXTURE_DIR = 'tests/fixtures'
local STAGED_DIR = 'tests/frames'
local FRAME = 'tests/frames/f_260828_002127_axe_call_bkb_ring.lua'

local AXE = 'npc_dota_hero_axe'
local LINA = 'npc_dota_hero_lina'
local NECRO = 'npc_dota_hero_necrolyte'
local SS = 'npc_dota_hero_shadow_shaman'
local CALL = 'axe_berserkers_call'
local CAND = 'axecallring'
local CAND_II = 'axecallbkb_ii'

local Q_RADIUS = 315              -- the cast radius; the AoE taunt reaches this far
local SEARCH_RING = Q_RADIUS - 50 -- 265, the list X.ConsiderQ builds
local ANCHOR_RING = Q_RADIUS - 90 -- 225, the margin the shipped anchor test uses
local DESIRE_HIGH = 0.75

local tests = {}

local function read_file(path)
    local fh = assert(io.open(path, 'r'), 'cannot open ' .. path)
    local body = fh:read('*a')
    fh:close()
    return body
end

--- Every .lua frame in the two corpus directories.  Both directory names are
--- literals in this file; nothing here enumerates bots/.
local function corpus_paths()
    local out = {}
    for _, dir in ipairs({ FIXTURE_DIR, STAGED_DIR }) do
        local p = assert(io.popen('ls ' .. dir .. ' 2>/dev/null'))
        for line in p:lines() do
            if line:match('%.lua$') then out[#out + 1] = dir .. '/' .. line end
        end
        p:close()
    end
    table.sort(out)
    return out
end

--- The body of one `function X.<name>` in the hero file, cut at the column-0
--- `end` rather than at the next `function X.` -- cutting at the next header
--- swallows it, which makes an assertion about what is NOT in a function wrong.
local function fn_code(src, sName)
    local from = src:find('function X%.' .. sName .. '%(')
    assert(from, 'X.' .. sName .. ' is gone from ' .. SRC)
    local rest = src:sub(from)
    local to = rest:find('\nend')
    assert(to, 'X.' .. sName .. ' has no column-0 end')
    return rest:sub(1, to)
end

--- Load the staged frame, arm a chosen id (or none), optionally repair the one
--- blind reader section 4 measures, and return the real hero module.
---
--- `sArm` is a single id and not a boolean: arming this id, arming
--- `axecallbkb_ii` and arming neither are three different worlds, and GH #577
--- split those ids precisely so they cannot be collapsed into one.
local function bid(sArm, bRepairMode)
    assert(sArm == nil or sArm == CAND or sArm == CAND_II,
        'bid() asked to arm ' .. tostring(sArm) .. ', which is neither of the two ids '
        .. 'this file reasons about -- a typo here would arm nothing and look like a finding')
    local J, bot, heroes, fx = rf.load(FRAME)
    J.IsSoakCandidate = function(id) return sArm ~= nil and id == sArm end
    if bRepairMode then
        rawget(bot, '__spec').GetActiveMode = BOT_MODE_ATTACK
    end
    local X = rf.load_hero('axe')
    return X, J, bot, heroes, fx
end

local function dist2d(a, b)
    local dx, dy = a.x - b.x, a.y - b.y
    return math.sqrt(dx * dx + dy * dy)
end

-- ---------------------------------------------------------------- section 1 --
-- Ground truth.  All of it off the replay; nothing here is repaired.

tests['\194\1671.1 the frame is Axe at 16:22 with Call rank 3 READY and the mana for it'] = function()
    local _, _, bot, _, fx = bid()
    assert(fx.self == AXE and fx.time == 982.1,
        'the decision instant moved: ' .. tostring(fx.self) .. ' @ ' .. tostring(fx.time))
    assert(bot:GetLevel() == 22, 'real Axe level, got ' .. tostring(bot:GetLevel()))
    local q = bot:GetAbilityByName(CALL)
    assert(q ~= nil, 'no ' .. CALL .. ' handle on the frame')
    assert(q:GetLevel() == 3, 'Call rank, got ' .. tostring(q:GetLevel()))
    assert(q:GetCooldownTimeRemaining() == 0,
        'Call is on cooldown here after all (' .. tostring(q:GetCooldownTimeRemaining())
        .. 's) -- every section below would then be a counterfactual, not a reading')
    assert(q:IsFullyCastable(), 'and the shipped first line of X.ConsiderQ does not bail')
    assert(bot:GetMana() == 319 and bot:GetMana() >= q:GetManaCost(),
        'real mana against the real cost, got ' .. tostring(bot:GetMana())
        .. ' against ' .. tostring(q:GetManaCost()))
    assert(q:GetSpecialValueInt('radius') == Q_RADIUS,
        'the KV radius this file prices the two rings off moved, got '
        .. tostring(q:GetSpecialValueInt('radius')))
end

tests['\194\1671.2 the ring holds TWO castable enemies and the hero Axe is hitting is OUTSIDE it'] = function()
    local _, J, bot, heroes = bid()
    local d = {}
    for _, name in ipairs({ LINA, NECRO, SS }) do
        local h = heroes[name]
        assert(h ~= nil, name .. ' is not on this frame')
        d[name] = GetUnitToUnitDistance(bot, h)
        assert(h:IsAlive(), name .. ' is dead on this frame')
        assert(J.CanCastOnNonMagicImmune(h),
            name .. ' fails the SHIPPED castability reader here; section 3 counts with it')
    end
    -- The two inside the anchor ring.
    assert(d[LINA] < 76 and d[LINA] <= ANCHOR_RING,
        'lina moved: ' .. string.format('%.1f', d[LINA]))
    assert(d[NECRO] > 165 and d[NECRO] <= ANCHOR_RING,
        'necrolyte moved: ' .. string.format('%.1f', d[NECRO]))
    -- ⭐ THE VALUE COLUMN.  Shadow Shaman is the enemy Axe is actually hitting
    -- (section 1.3), he is inside the TAUNT, and he is outside the test the
    -- shipped branch would run on him.
    assert(d[SS] > ANCHOR_RING, 'shadow shaman is inside the 225u anchor ring after all ('
        .. string.format('%.1f', d[SS]) .. ') -- then the shipped branch would fire on him '
        .. 'and this frame is no longer the defect')
    assert(d[SS] <= Q_RADIUS, 'shadow shaman is outside the 315u taunt ('
        .. string.format('%.1f', d[SS]) .. ') -- then he is not in the AoE the header claims')
end

tests['\194\1671.3 the frame says Axe is committing on shadow shaman -- four attack instances'] = function()
    local fx = dofile(FRAME)
    local ss
    for _, u in ipairs(fx.units) do if u.name == SS then ss = u end end
    assert(ss ~= nil, SS .. ' left the frame')
    local nAxeHits, nDamage = 0, 0
    for _, ev in ipairs(ss.recent_damage or {}) do
        if ev.kind == 'hero' and ev.actor == AXE then
            nAxeHits = nAxeHits + 1
            nDamage = nDamage + (ev.value or 0)
        end
    end
    -- This is the ONLY ground truth section 4's mode repair rests on.  If it
    -- shrinks, that repair loses its footing and section 4's label is wrong.
    assert(nAxeHits >= 4, 'only ' .. nAxeHits .. ' Axe damage instances on ' .. SS
        .. ' in the window, was 4 -- section 4 repairs GetActiveMode on the strength '
        .. 'of exactly this, so re-read that section before lowering this bar')
    assert(nDamage >= 70, 'Axe dealt only ' .. nDamage .. ' to ' .. SS .. ', was 76')
end

-- ---------------------------------------------------------------- section 2 --
-- The branch-level domain, COUNTED over the corpus rather than quoted.

--- Live Axe hero rows whose Berserker's Call is learned and off cooldown, with
--- the count of live enemy heroes inside a given ring.
---
--- `alive ~= false` is load-bearing, not hygiene: a dead row carries hp 0 and no
--- level, and the whole WK family of censuses was reddened by exactly one of
--- them (GH #794).
local function call_ready_rows(nRing)
    local nRows, hist = 0, {}
    for _, path in ipairs(corpus_paths()) do
        local ok, fx = pcall(dofile, path)
        if ok and type(fx) == 'table' and type(fx.units) == 'table' then
            for _, u in ipairs(fx.units) do
                if u.name == AXE and u.alive ~= false then
                    local q
                    for _, a in ipairs(u.abilities or {}) do
                        if a.name == CALL then q = a end
                    end
                    if q and (q.level or 0) >= 1 and (q.cd or 0) <= 0 then
                        nRows = nRows + 1
                        local n = 0
                        for _, e in ipairs(fx.units) do
                            if e.team ~= u.team and e.name:match('^npc_dota_hero_')
                                and e.alive ~= false and dist2d(e, u) <= nRing
                            then
                                n = n + 1
                            end
                        end
                        hist[n] = (hist[n] or 0) + 1
                    end
                end
            end
        end
    end
    return nRows, hist
end

tests['\194\1672.1 28 Call-ready Axe rows, and the 225u ring holds >= 2 on exactly ONE'] = function()
    local nRows, hist = call_ready_rows(ANCHOR_RING)
    assert(nRows >= 28, 'the corpus holds ' .. nRows .. ' Call-ready Axe rows, recorded 28. '
        .. 'Frames were added or removed; re-read every count in this file before quoting one')
    local nQuorum = 0
    for n, c in pairs(hist) do if n >= 2 then nQuorum = nQuorum + c end end
    assert(nQuorum >= 1, 'no Axe row in the corpus holds 2 enemies inside the ring any more -- '
        .. 'the branch-level domain has gone to 0 and section 4 is driving nothing')
    -- Recorded as what it was when measured, in the direction that can only be
    -- widened by new frames.  It is a DOMAIN, not a frequency: how often a real
    -- Turbo game puts two heroes inside Axe's Call ring is a wave question
    -- (iterations/queue.json hero-91).
    assert((hist[0] or 0) >= 24, 'rows with an EMPTY ring: ' .. tostring(hist[0]) .. ', was 24')
    assert((hist[1] or 0) >= 3, 'rows with exactly one in the ring: ' .. tostring(hist[1])
        .. ', was 3 -- these are the rows a quorum of 1 would have added, which the '
        .. 'header refuses on purpose')
end

tests['\194\1672.2 the one row that reaches quorum is the staged frame this file drives'] = function()
    local _, histAnchor = call_ready_rows(ANCHOR_RING)
    local _, histTaunt = call_ready_rows(Q_RADIUS)
    local nAnchor, nTaunt = 0, 0
    for n, c in pairs(histAnchor) do if n >= 2 then nAnchor = nAnchor + c end end
    for n, c in pairs(histTaunt) do if n >= 2 then nTaunt = nTaunt + c end end
    assert(nAnchor == 1 and nTaunt == 1,
        'quorum-reaching rows: ' .. nAnchor .. ' at 225u, ' .. nTaunt .. ' at 315u; both were 1. '
        .. 'If these have diverged, the -90 margin has started to matter to the domain and '
        .. 'the header\'s "one term moves" sentence needs re-reading')
    -- And that one row is reachable by name: section 4 drives it.
    local fx = dofile(FRAME)
    assert(fx.self == AXE, 'the staged frame is no longer an Axe-subject frame')
end

-- ---------------------------------------------------------------- section 3 --
-- The counter, driven on the real frame.  This is the half of the lever that
-- fixtures CAN size, and it is the term the change touches.

tests['\194\1673.1 the counter answers the real ring, and rises exactly where the enemies stand'] = function()
    local X, J, bot, heroes = bid()
    local list = J.GetAroundEnemyHeroList(SEARCH_RING)
    assert(#list == 2, 'the shipped 265u search list holds ' .. #list .. ' enemies, was 2')
    local dNecro = GetUnitToUnitDistance(bot, heroes[NECRO])
    -- A ladder, not a single value: a single-value assertion is the shape that
    -- let `cullthresh`'s first wrong guard through.
    assert(X.axe_CountCallRingTargets(list, dNecro - 1) == 1,
        'one enemy just inside necrolyte')
    assert(X.axe_CountCallRingTargets(list, dNecro + 1) == 2,
        'two enemies just outside necrolyte')
    assert(X.axe_CountCallRingTargets(list, ANCHOR_RING) == 2,
        'the anchor ring holds two')
    assert(X.axe_CountCallRingTargets(list, Q_RADIUS) == 2,
        'the counter cannot exceed the list it was handed: shadow shaman at 276.9u is '
        .. 'inside the 315u taunt but NOT inside the 265u list X.ConsiderQ builds, so a 3 '
        .. 'here means the call site changed which list it passes')
end

tests['\194\1673.2 a nil list answers 0 -- the restrictive default, asserted not assumed'] = function()
    local X = bid()
    assert(X.axe_CountCallRingTargets(nil, ANCHOR_RING) == 0,
        'a caller that forgot its argument would fire this branch on every frame')
    assert(X.axe_CountCallRingTargets({}, ANCHOR_RING) == 0, 'an empty list answers 0')
end

tests['\194\1673.3 the shipped vetoes are inside the counter: immunity and disable each drop one'] = function()
    local X, J, bot, heroes = bid()
    local list = J.GetAroundEnemyHeroList(SEARCH_RING)
    assert(X.axe_CountCallRingTargets(list, ANCHOR_RING) == 2, 'baseline is two')
    -- Immunity: the CONSERVATIVE reading this lever keeps.  `axecallbkb_ii` is
    -- the id that argues about this term; this one does not touch it.
    rawget(heroes[NECRO], '__spec').IsMagicImmune = true
    assert(X.axe_CountCallRingTargets(list, ANCHOR_RING) == 1,
        'a spell-immune ring member is still not counted -- if this is 2, this lever has '
        .. 'silently absorbed ' .. CAND_II .. "'s premise and the two are no longer separable")
    rawget(heroes[NECRO], '__spec').IsMagicImmune = false
    -- Disable: taunting a hero who is already locked down buys nothing.
    rawget(heroes[NECRO], '__spec').IsStunned = true
    assert(X.axe_CountCallRingTargets(list, ANCHOR_RING) == 1,
        'a disabled ring member is still counted -- the not-J.IsDisabled veto is gone')
    assert(J.IsDisabled(heroes[NECRO]), 'and the shipped reader agrees he is disabled')
end

-- ---------------------------------------------------------------- section 4 --
-- The 2x2 on the real frame.  ⚠️ One reader is repaired here; section 1.3 is its
-- entire footing and the file header states its standing.

tests['\194\1674.1 SHIPPED refuses this frame, with and without the mode repair'] = function()
    local X1 = bid(nil, false)
    local d1, m1 = X1.ConsiderQ()
    assert(d1 == 0 and m1 == nil, 'gate down, mode as recorded: expected 0, got '
        .. tostring(d1) .. ' / ' .. tostring(m1))
    local X2 = bid(nil, true)
    local d2, m2 = X2.ConsiderQ()
    -- This is the defect, stated as a reading: Axe is committed, three enemies
    -- are in the AoE, Call is ready -- and the shipped code says no, because the
    -- one hero it interrogates is 276.9u away.
    assert(d2 == 0 and m2 == nil, 'gate down, mode repaired: expected 0, got '
        .. tostring(d2) .. ' / ' .. tostring(m2)
        .. ' -- if the shipped branch fires here the defect this file is about is gone')
end

tests['\194\1674.2 ARMED fires, and only with the mode repair -- the other cell is inert'] = function()
    local X1, J1, bot1 = bid(CAND, false)
    assert(not J1.IsGoingOnSomeone(bot1),
        'J.IsGoingOnSomeone is TRUE on an unrepaired frame -- then the structural blocker '
        .. 'GH #577 recorded has gone away and this file should stop repairing anything')
    local d1 = X1.ConsiderQ()
    assert(d1 == 0, 'armed but not committing: expected 0, got ' .. tostring(d1))

    local X2, J2, bot2 = bid(CAND, true)
    assert(J2.IsGoingOnSomeone(bot2), 'the repair did not take')
    local d2, m2 = X2.ConsiderQ()
    assert(d2 == DESIRE_HIGH, 'armed and committing: expected ' .. DESIRE_HIGH
        .. ', got ' .. tostring(d2))
    -- The motive carries the count, so a wave replay can tell this firing point
    -- apart from the shipped one by name.
    assert(m2 == 'Q-环2', 'motive, got ' .. tostring(m2))
end

tests['\194\1674.3 the quorum is load-bearing: one in the ring is not enough'] = function()
    local X, _, _, heroes = bid(CAND, true)
    assert(X.nCallRingQuorum == 2, 'the quorum moved to ' .. tostring(X.nCallRingQuorum)
        .. ' -- every count in sections 2 and 3 is priced against 2')
    -- Take lina out of the ring by the only means the frame allows without
    -- moving anybody: make her unseeable, which is a veto the shipped reader
    -- already owns.
    rawget(heroes[LINA], '__spec').CanBeSeen = false
    local d = X.ConsiderQ()
    assert(d == 0, 'one castable enemy in the ring still fired the branch (' .. tostring(d)
        .. ') -- the quorum test is not doing any work')
end

-- ---------------------------------------------------------------- section 5 --
-- ⛔ The end-to-end domain, asserted in the direction that can go red.

tests['\194\1675.1 END-TO-END the armed frame casts CULLING BLADE, not Call -- domain 0'] = function()
    local X, _, bot = bid(CAND, true)
    local log = rf.record_actions(bot)
    X.SkillsComplement()
    local casts = {}
    for _, e in ipairs(log) do
        if e.fn:find('UseAbility') then
            local h = e.args[1]
            casts[#casts + 1] = (h and h.GetName and h:GetName()) or '?'
        end
    end
    assert(#casts == 1, 'expected exactly one ability cast out of X.SkillsComplement, got '
        .. #casts .. ' (' .. table.concat(casts, ', ') .. ')')
    assert(casts[1] == 'axe_culling_blade',
        'X.SkillsComplement asks X.ConsiderR FIRST and the ultimate won the arm order on '
        .. 'this frame; it now casts ' .. casts[1] .. '.  If this has become '
        .. CALL .. ', the END-TO-END domain has left 0 and the header\'s two-number '
        .. 'paragraph must be re-measured before anyone quotes it')
end

tests['\194\1675.2 and the shipped leg casts the SAME thing -- arming changes no action here'] = function()
    local Xa, _, botA = bid(CAND, true)
    local logA = rf.record_actions(botA)
    Xa.SkillsComplement()
    local Xb, _, botB = bid(nil, true)
    local logB = rf.record_actions(botB)
    Xb.SkillsComplement()
    assert(#logA == #logB, 'armed issued ' .. #logA .. ' orders, shipped ' .. #logB)
    for i = 1, #logA do
        assert(logA[i].fn == logB[i].fn, 'order ' .. i .. ' differs: '
            .. logA[i].fn .. ' vs ' .. logB[i].fn)
    end
end

-- ---------------------------------------------------------------- section 6 --
-- Source-level wiring.  These are the assertions a mutation stand shoots at.

tests['\194\1676.1 the gate is turbo-only and names EXACTLY its own id'] = function()
    local src = read_file(SRC)
    local body = fn_code(src, 'IsCallRingOn')
    assert(body:find('J.IsModeTurbo()', 1, true),
        'X.IsCallRingOn lost its turbo conjunct -- the id would then be live in normal mode')
    assert(body:find("IsSoakCandidate( '" .. CAND .. "' )", 1, true),
        'X.IsCallRingOn no longer names ' .. CAND)
    -- The pullcad trap, in the direction that catches it: count the ids named,
    -- then name them, so a WRONG MESSAGE cannot come out of a bare match.
    local named, n = {}, 0
    for id in body:gmatch("IsSoakCandidate%(%s*'([%w_]+)'%s*%)") do
        named[#named + 1] = id
        n = n + 1
    end
    assert(n == 1, 'X.IsCallRingOn names ' .. n .. ' soak ids (' .. table.concat(named, ', ')
        .. '), must name exactly 1 -- a gate that names a sibling freezes FALSE the day '
        .. 'the sibling is promoted, and check_armed_wiring.py still calls it WIRED')
    assert(named[1] == CAND, 'and the one it names is ' .. named[1])
end

tests['\194\1676.2 the firing point is a SEPARATE if after the shipped branch'] = function()
    local src = read_file(SRC)
    local body = fn_code(src, 'ConsiderQ')
    local iShipped = body:find("'Q-先手'", 1, true)
    local iRing = body:find('X.IsCallRingOn()', 1, true)
    assert(iRing, 'the [axecallring] firing point is gone from X.ConsiderQ')
    assert(iShipped, 'the shipped initiation motive is gone from X.ConsiderQ -- this '
        .. 'section prices the ORDER of the two firing points off it')
    assert(iShipped < iRing, 'the ring firing point now runs BEFORE the shipped branch. '
        .. 'The direction-by-construction claim ("arming can only ADD a Call") is priced '
        .. 'on the shipped branch being evaluated and returning first')
    -- And the shipped anchor test itself is untouched.
    assert(body:find('J.IsInRange( botTarget, bot, nRadius - 90 )', 1, true),
        'the shipped anchor test has been EDITED.  This lever adds a firing point; it does '
        .. 'not rewrite the shipped one, and gate-off byte-identity is priced on that')
end

tests['\194\1676.3 the call site passes the shipped list and the shipped margin'] = function()
    local src = read_file(SRC)
    local body = fn_code(src, 'ConsiderQ')
    assert(body:find('X.axe_CountCallRingTargets( nInRangeEnemyList, nRadius - 90 )', 1, true),
        'the call site no longer hands the counter the shipped 265u list and the shipped '
        .. '-90 margin -- the "one term moves" claim in the header is then false')
    assert(body:find('nRingTargets >= X.nCallRingQuorum', 1, true),
        'the quorum is no longer read off the named field, so this file and the source can '
        .. 'drift apart silently (the stale-mirror family)')
end

-- ---------------------------------------------------------------- section 7 --
-- Independence from `axecallbkb_ii`.  Same ring, different question.

tests['\194\1677.1 arming axecallbkb_ii ALONE does not fire the ring branch'] = function()
    local X, J, bot = bid(CAND_II, true)
    assert(J.IsGoingOnSomeone(bot), 'the repair did not take')
    local d, m = X.ConsiderQ()
    assert(d == 0 and m == nil, 'arming ' .. CAND_II .. ' alone fired something here ('
        .. tostring(d) .. ' / ' .. tostring(m) .. ').  The two ids would then be '
        .. 'inseparable in a wave and neither reading would be attributable')
end

tests['\194\1677.2 neither gate names the other id, in source'] = function()
    local src = read_file(SRC)
    for _, pair in ipairs({ { 'IsCallRingOn', CAND_II }, { 'IsCallPierceInitiateOn', CAND },
                            { 'IsCallPierceInterruptOn', CAND } }) do
        local body = fn_code(src, pair[1])
        assert(not body:find("'" .. pair[2] .. "'", 1, true),
            'X.' .. pair[1] .. ' now names ' .. pair[2] .. ' -- the pullcad trap')
    end
end

tests['\194\1677.3 the retired umbrella string stays absent from bots/'] = function()
    local src = read_file(SRC)
    -- Quoted literals, because `axecallbkb` is a PREFIX of both live ids and a
    -- bare match reports a finding on an unmutated tree.
    assert(not src:find("'axecallbkb'", 1, true),
        "the retired umbrella id 'axecallbkb' is back in " .. SRC
        .. ' -- GH #577 retired it because a wave arming it could not see branch (i)')
    assert(src:find("'axecallbkb_i'", 1, true) and src:find("'axecallbkb_ii'", 1, true),
        'one of the two split ids has left the file; section 7.1 then proves nothing')
end

return tests

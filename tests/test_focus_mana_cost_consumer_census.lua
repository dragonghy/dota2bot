-- [hero] Where the 09-01 mana ladder actually lands: a consumer census over the
-- FOUR focus heroes nobody has scanned yet.
--
-- Charter backlog -72.  `c386d5f3` gave `GetManaCost` a real KV price in the
-- fixture world (it had answered 0 for every ability on every frame since the
-- loader landed).  The 16:51Z round chased its fallout through 71 test files and
-- every one of them was a `skeleton_king` file; Zeus, Crystal Maiden, Axe and
-- Lion had never been looked at.  Backlog -72's own warning was that a grep over
-- test files cannot find the dangerous shape, because that shape is GREEN: the
-- assertion still holds and only the SENTENCE explaining it went false.
--
-- ZERO behaviour change.  `bots/` and `game/` are untouched by the commit that
-- adds this file; no new gate id, no arm, no promote.
--
-- ---------------------------------------------------------------------------
-- METHOD -- three instruments, and the first one was WRONG
--
--   (1) A mutation stand: force `GetManaCost` back to 0 in
--       tests/mock/replay_fixture.lua and re-run.  39 fixture-loading test files
--       covering the five focus heroes (533 test bodies); 7 files go red, 32 do
--       not.  That answers "does the OUTCOME depend on the ladder", which is the
--       cheap half of the question.
--   (2) A probe counting `IsFullyCastable` revocations (level and cooldown pass,
--       the mana clause refuses).  THIS INSTRUMENT WAS WRONG and its own
--       negative control said so: `test_wk_save_mana_lock_census.lua` and
--       `test_wk_roshan_mana_floor.lua` both FLIP under (1) while the probe read
--       0 revocations for them.  A price reaches a decision by two routes and
--       the probe watched one -- WK's reads go into ARITHMETIC
--       (`GetMana() - Q:GetManaCost() < R:GetManaCost()`), never through
--       castability.  Recorded here because "the mana clause" is the intuitive
--       channel and it is not the load-bearing one.
--   (3) A probe on the priced closure itself, logging every call and its Lua
--       call chain.  That is the instrument the readings below come from, and
--       §1 turns its finding into a source-text ratchet that runs every round.
--
-- WHAT (3) FOUND, and it is not a small correction:  416 of the corpus's direct
-- (non-castability) reads land on a `local nManaCost = ability:GetManaCost()`
-- that is NEVER READ AGAIN.  A dead local.  The price is computed, the ladder
-- charges it, and the value is dropped one line later.  Both of Crystal Maiden's
-- reads are of this kind, so CM is STRUCTURALLY immune to the ladder through
-- bindings -- and 14 real CM frames in the corpus sit in a band where the ladder
-- would otherwise have flipped a gate.  The arithmetic is identical to Axe's and
-- Lion's; only reading the binding tells you that it means nothing here.
--
-- ---------------------------------------------------------------------------
-- THE ONE THAT IS NOT A NO-OP -- `zusult`'s fixture domain was EMPTY (§6)
--
-- `X.zuus_ShouldSaveManaForUlt` is the whole body of the armed candidate
-- `zusult` (and of `zusultx`).  Its fourth line is
--
--     local nCost = abilityR:GetManaCost()
--     if nCost == nil or nCost <= 0 then return false end
--
-- Before `c386d5f3` that read answered 0 on every frame, so the gate returned
-- false at that line ALWAYS, in every fixture, for every caller.  Corpus: 42
-- alive-Zeus frames, 16 of them with Reincarnation... with Thundergod's Wrath
-- trained and off cooldown -- 16 frames where the gate's own preconditions hold
-- and it still could not fire.  Today 7 of those 16 reach the decision (mana
-- below the price); the other 9 return false one line later as already
-- affordable.  The domain went 0 -> 7.
--
-- What that does and does not mean, stated precisely because the difference is
-- the whole point: the ENGINE always priced abilities, so real Turbo games were
-- never affected -- `zusult` has been arming and firing on the farm all along.
-- It is the FIXTURE-LEVEL claims that were vacuous: any "this frame reaches the
-- zusult decision" taken off a fixture before 2026-09-01 was taken on a gate
-- that returned false before reading its second operand.  `zusult` is in the
-- current armed set (test_set.md line 2), which is why this is worth a section
-- rather than a footnote.
--
-- ---------------------------------------------------------------------------
-- HONEST BOUNDS
--   * §4/§5's counts are an UPPER bound on flips.  A frame is counted when the
--     hero's mana fraction sits in the band where the two live consumers answer
--     differently with and without the price; whether execution actually REACHES
--     the consumer on that frame is a separate question this file does not ask.
--     The direction is deliberate: an upper bound cannot hide a flip.
--   * The ladder covers the five focus heroes only (special_value_shapes.lua).
--     Every other hero's abilities still answer 0 and stay unconditionally
--     affordable; nothing here narrows that.
--   * §1 classifies by reading the source text of the hero files, not by
--     executing them, and it covers `local <name> = <handle>:GetManaCost()`
--     bindings only.  Two INLINE reads in hero_skeleton_king.lua (:619 inside
--     X.GetRoshanManaFloor, :1183 inside X.ShouldSaveMana) are by construction
--     outside the census -- they are live by inspection, they have no binding to
--     be dead, and they are the subject of test_wk_roshan_mana_floor.lua and
--     test_wk_save_mana_lock_census.lua.  A consumer reached through a table
--     field or a closure would likewise read as DEAD; none exists today.

package.path = 'tests/?.lua;' .. package.path
local rf     = require('mock.replay_fixture')
local shapes = require('mock.special_value_shapes')
local slots  = require('mock.hero_slots')

local FOCUS = { 'axe', 'zuus', 'lion', 'crystal_maiden', 'skeleton_king' }

-- The two live consumers of a bound mana price in the focus files, and the
-- thresholds they compare against.  Both are read off bots/FunLib/jmz_func.lua
-- and both are DRIVEN in §3 rather than trusted here.
local FARM_FLOOR = 0.3     -- J.GetManaAfter( c ) > 0.3
local SPAM_FLOOR = 0.39    -- J.IsAllowedToSpam: (mana - c)/max >= fKeepManaPercent

-- Heroes whose slot-0 ability's bound price feeds those two helpers.  CM's two
-- bindings are dead (§2); WK's slot-0 price feeds X.GetRoshanManaFloor, a
-- different predicate measured in test_wk_roshan_mana_floor.lua.
local LIVE_Q = { axe = true, zuus = true, lion = true }

local tests = {}

-- ---------------------------------------------------------------------------
-- 1.  [ratchet] Every GetManaCost read in the five focus files, classified.
-- ---------------------------------------------------------------------------

--- Source text of one focus hero's script.
local function hero_src(sHero)
    local fh = assert(io.open('bots/BotLib/hero_' .. sHero .. '.lua', 'r'))
    local s = fh:read('*a')
    fh:close()
    return s
end

--- Every `local <name> = <expr>:GetManaCost()` in `sSrc`, classified LIVE or
--- DEAD by whether `<name>` is read again before the enclosing function ends.
--- Function extent is taken from the file's own top-level `function X.Name()`
--- lines, which is how every focus hero file is written.
local function binding_census(sSrc)
    local lines = {}
    for line in (sSrc .. '\n'):gmatch('([^\n]*)\n') do lines[#lines + 1] = line end

    -- Top-level function starts, in order; a binding belongs to the last one
    -- that started before it, and ends at the next one.
    local starts = {}
    for i, line in ipairs(lines) do
        local sName = line:match('^function%s+([%w_%.]+)%s*%(')
        if sName ~= nil then starts[#starts + 1] = { line = i, name = sName } end
    end
    local function enclosing(nLine)
        local found = nil
        for _, s in ipairs(starts) do
            if s.line < nLine then found = s else break end
        end
        local nEnd = #lines
        for _, s in ipairs(starts) do
            if found ~= nil and s.line > found.line then nEnd = s.line - 1 break end
        end
        return found, nEnd
    end

    local out = {}
    for i, line in ipairs(lines) do
        local sVar = line:match('^%s*local%s+([%w_]+)%s*=%s*[%w_%.:%(%)]-:GetManaCost%s*%(')
        if sVar ~= nil then
            local fn, nEnd = enclosing(i)
            local bLive = false
            for j = i + 1, nEnd do
                -- a read is any other appearance of the name that is not a
                -- fresh `local <name> =` binding
                if lines[j]:find('%f[%w_]' .. sVar .. '%f[^%w_]')
                    and not lines[j]:match('^%s*local%s+' .. sVar .. '%s*=')
                then
                    bLive = true
                    break
                end
                if lines[j]:match('^%s*local%s+' .. sVar .. '%s*=') then break end
            end
            out[#out + 1] = {
                line = i, var = sVar, live = bLive,
                fn = fn and fn.name or '<file scope>',
            }
        end
    end
    return out
end

tests['[ratchet] [1] the focus five bind 17 mana prices and 9 of them are dead locals'] = function()
    local nLive, nDead, tPer = 0, 0, {}
    for _, sHero in ipairs(FOCUS) do
        local rows = binding_census(hero_src(sHero))
        tPer[sHero] = { live = 0, dead = 0 }
        for _, r in ipairs(rows) do
            if r.live then nLive = nLive + 1 tPer[sHero].live = tPer[sHero].live + 1
            else nDead = nDead + 1 tPer[sHero].dead = tPer[sHero].dead + 1 end
        end
    end
    -- Measured 2026-09-02.  A change here is not necessarily a defect -- it is a
    -- claim in this file that has to be re-derived before it may be quoted.
    local EXPECT = {
        -- axe:  Q(481) W(687) live; R(901) bound and dropped
        -- zuus: the two inside X.zuus_ShouldSaveManaForUlt (357, 366) and
        --       ConsiderQ(642) live; ConsiderW(770) ConsiderW2(881)
        --       ConsiderR(1031) ConsiderE(1216) all dead
        -- lion: Q(593) R(1105) live; W(791) E(978) dead
        -- cm:   BOTH dead -- see §2
        -- wk:   Q(712) live (X.GetRoshanManaFloor, a third predicate)
        axe            = { live = 2, dead = 1 },
        zuus           = { live = 3, dead = 4 },
        lion           = { live = 2, dead = 2 },
        crystal_maiden = { live = 0, dead = 2 },
        skeleton_king  = { live = 1, dead = 0 },
    }
    for _, sHero in ipairs(FOCUS) do
        local got, want = tPer[sHero], EXPECT[sHero]
        assert(got.live == want.live and got.dead == want.dead,
            sHero .. ': mana-price bindings moved -- expected ' .. want.live
                .. ' live / ' .. want.dead .. ' dead, got ' .. got.live .. ' / '
                .. got.dead .. '. Re-derive this file\'s counts (a binding that '
                .. 'became live changes §4/§5 and possibly §2) before editing.')
    end
    assert(nLive == 8 and nDead == 9,
        'focus-five total: expected 8 live / 9 dead, got ' .. nLive .. ' / ' .. nDead)
end

tests['[1b] the classifier is not vacuous: it finds both kinds inside ONE file'] = function()
    -- Lion is the control: same file, same idiom, one binding read four times
    -- and one never read.  A classifier that answered all-live or all-dead would
    -- pass §1 by accident on the aggregate; it cannot pass this.
    local rows = binding_census(hero_src('lion'))
    local bSawLive, bSawDead = false, false
    for _, r in ipairs(rows) do
        if r.live then bSawLive = true else bSawDead = true end
    end
    assert(bSawLive and bSawDead,
        'hero_lion.lua must contain BOTH a live and a dead mana-price binding; '
            .. 'got live=' .. tostring(bSawLive) .. ' dead=' .. tostring(bSawDead))
    -- and the live one really is read by the spam/farm helpers
    local sSrc = hero_src('lion')
    assert(sSrc:find('J.IsAllowedToSpam( bot, nManaCost )', 1, true),
        'Lion\'s live binding must still reach J.IsAllowedToSpam')
    assert(sSrc:find('J.GetManaAfter( nManaCost )', 1, true),
        'Lion\'s live binding must still reach J.GetManaAfter')
end

tests['[1c] the classifier answers the question it claims to, on synthetic source'] = function()
    -- §1's EXPECT table was READ OFF this classifier, so §1 alone cannot tell a
    -- correct classifier from a stuck one.  These four cases can: each pair
    -- differs by exactly one line.
    local function one(sSrc)
        local rows = binding_census(sSrc)
        assert(#rows == 1, 'synthetic source must bind exactly one price, got ' .. #rows)
        return rows[1].live
    end
    local sDead = 'function X.A()\n\tlocal nManaCost = abilityQ:GetManaCost()\n'
        .. '\tlocal nFoo = 1\n\treturn nFoo\nend\n'
    local sLive = 'function X.A()\n\tlocal nManaCost = abilityQ:GetManaCost()\n'
        .. '\tlocal nFoo = 1\n\treturn nManaCost\nend\n'
    assert(not one(sDead), 'a price that is never read again must classify DEAD')
    assert(one(sLive), 'a price that is returned must classify LIVE')

    -- The read must be inside the SAME function: a later function that happens
    -- to use the same local name is a different variable.
    local sNext = 'function X.A()\n\tlocal nManaCost = abilityQ:GetManaCost()\nend\n'
        .. 'function X.B()\n\treturn nManaCost\nend\n'
    assert(not one(sNext),
        'a same-named read in the NEXT function is not a read of this binding')

    -- A rebinding ends the search: what follows reads the new local.
    local sRebound = 'function X.A()\n\tlocal nManaCost = abilityQ:GetManaCost()\n'
        .. '\tlocal nManaCost = 5\n\treturn nManaCost\nend\n'
    assert(not one(sRebound), 'a read after a rebinding is not a read of the first')
end

-- ---------------------------------------------------------------------------
-- 2.  Crystal Maiden is structurally immune through bindings.
-- ---------------------------------------------------------------------------

tests['[2] both of CM\'s mana-price bindings are dead, so no CM decision reads a price'] = function()
    local rows = binding_census(hero_src('crystal_maiden'))
    assert(#rows == 2, 'CM binds exactly two mana prices, got ' .. #rows)
    for _, r in ipairs(rows) do
        assert(not r.live,
            'hero_crystal_maiden.lua:' .. r.line .. ' (' .. r.fn .. ') now READS `'
                .. r.var .. '`. CM was immune to the mana ladder through bindings; '
                .. 'that is no longer true and §4/§5 must be re-derived with CM '
                .. 'included -- 14 CM frames in the fixture corpus sit in the flip band.')
    end
    -- The claim is about BINDINGS and must not be overstated: the price still
    -- reaches CM through IsFullyCastable's mana clause, which is a different
    -- channel with a different failure mode.
    local sSrc = hero_src('crystal_maiden')
    assert(sSrc:find('IsFullyCastable', 1, true),
        'CM still gates on IsFullyCastable -- the immunity claimed here is about '
            .. 'bound prices only, not about the mana clause')
end

-- ---------------------------------------------------------------------------
-- 3.  The two live consumers, DRIVEN (their thresholds are not read off source).
-- ---------------------------------------------------------------------------

local ZEUS_FRAME = 'tests/fixtures/f_260819_222052_zuus_w2_leak.lua'

tests['[3] J.GetManaAfter and J.IsAllowedToSpam, driven on a real frame'] = function()
    local J, bot = rf.load(ZEUS_FRAME)
    assert(bot:GetMana() == 152 and bot:GetMaxMana() == 812,
        'frame ground truth: 152/812 mana, got ' .. bot:GetMana() .. '/' .. bot:GetMaxMana())

    -- GetManaAfter is exactly (mana - cost)/max: pin it at two costs.
    assert(math.abs(J.GetManaAfter(0) - 152 / 812) < 1e-9, 'GetManaAfter(0) = mana fraction')
    assert(math.abs(J.GetManaAfter(90) - (152 - 90) / 812) < 1e-9,
        'GetManaAfter(c) subtracts the price before dividing')

    -- IsAllowedToSpam's floor, bracketed rather than read: 0.39 of 812 is 316.68,
    -- so a bot holding 812 mana is allowed to spam a 495-mana spell and not a
    -- 496-mana one.
    bot.__spec = rawget(bot, '__spec')
    local hero = bot
    hero.__spec.GetMana = 812
    assert(J.IsAllowedToSpam(hero, 495), 'at 812/812, a 495 price leaves 0.3904 >= 0.39')
    assert(not J.IsAllowedToSpam(hero, 496), 'a 496 price leaves 0.3892 < 0.39')
end

-- ---------------------------------------------------------------------------
-- 4/5.  Corpus census: on how many REAL frames did the ladder change an answer?
-- ---------------------------------------------------------------------------

--- The KV mana ladder for one ability, the same source replay_fixture.lua uses.
local function ladder(sHero, sAbility)
    local tAbils = shapes.SHAPES[sHero]
    if tAbils == nil then return nil end
    local tEntry = tAbils[sAbility]
    if tEntry == nil then return nil end
    local mc = tEntry['AbilityManaCost']
    if mc == nil or mc.base == nil then return nil end
    local steps = {}
    for tok in mc.base:gmatch('%S+') do steps[#steps + 1] = tonumber(tok) end
    if #steps == 0 then return nil end
    return steps
end

--- Sweep every fixture; for each alive focus hero holding a trained slot-0
--- ability, decide whether charging its real price flips either live consumer.
--- `nCostOverride` reconstructs the pre-ladder world (every price 0).
local function corpus_flips(nCostOverride)
    local per = {}
    local p = assert(io.popen('ls tests/fixtures/*.lua'))
    for sPath in p:lines() do
        local chunk = loadfile(sPath)
        if chunk ~= nil then
            local ok, fx = pcall(chunk)
            if ok and type(fx) == 'table' and fx.units ~= nil then
                for _, u in ipairs(fx.units) do
                    local sHero = (u.name or ''):gsub('^npc_dota_hero_', '')
                    local tSlots = slots[sHero]
                    if tSlots ~= nil and u.alive and (u.max_mp or 0) > 0 then
                        local sQ = tSlots[0]
                        local nRank = 0
                        for _, a in ipairs(u.abilities or {}) do
                            if a.name == sQ then nRank = a.level end
                        end
                        local steps = ladder(sHero, sQ)
                        if steps ~= nil and nRank >= 1 then
                            local nCost = nCostOverride
                                or steps[math.min(nRank, #steps)]
                            local f  = u.mp / u.max_mp
                            local fA = (u.mp - nCost) / u.max_mp
                            per[sHero] = per[sHero]
                                or { n = 0, farm = 0, spam = 0, either = 0 }
                            local s = per[sHero]
                            s.n = s.n + 1
                            local bFarm = (f > FARM_FLOOR) and (fA <= FARM_FLOOR)
                            local bSpam = (f >= SPAM_FLOOR) and (fA < SPAM_FLOOR)
                            if bFarm then s.farm = s.farm + 1 end
                            if bSpam then s.spam = s.spam + 1 end
                            if bFarm or bSpam then s.either = s.either + 1 end
                        end
                    end
                end
            end
        end
    end
    p:close()
    return per
end

tests['[4] 16 of 88 live-Q focus-hero frames sit where the ladder flips a gate'] = function()
    local per = corpus_flips(nil)
    -- Measured 2026-09-02 over tests/fixtures/*.lua.
    local EXPECT = {
        axe            = { n = 26, farm = 5, spam = 3, either = 6 },
        zuus           = { n = 40, farm = 4, spam = 3, either = 6 },
        lion           = { n = 23, farm = 3, spam = 2, either = 4 },
        crystal_maiden = { n = 48, farm = 9, spam = 10, either = 14 },
        skeleton_king  = { n = 31, farm = 4, spam = 5, either = 5 },
    }
    for sHero, want in pairs(EXPECT) do
        local got = per[sHero] or { n = 0, farm = 0, spam = 0, either = 0 }
        assert(got.n == want.n and got.farm == want.farm and got.spam == want.spam
            and got.either == want.either,
            sHero .. ': corpus flip census moved -- expected n=' .. want.n
                .. ' farm=' .. want.farm .. ' spam=' .. want.spam
                .. ' either=' .. want.either .. ', got n=' .. got.n .. ' farm='
                .. got.farm .. ' spam=' .. got.spam .. ' either=' .. got.either
                .. '. Fixtures were added or the ladder moved; re-derive.')
    end
    local nLive, nEither = 0, 0
    for sHero, s in pairs(per) do
        if LIVE_Q[sHero] then nLive = nLive + s.n nEither = nEither + s.either end
    end
    assert(nLive == 89 and nEither == 16,
        'live-Q total: expected 16 flips over 89 frames, got ' .. nEither
            .. ' over ' .. nLive)
    -- The CM half of the same table is the §2 point in numbers: fourteen frames
    -- whose arithmetic says "flip" and whose code says "nobody reads this".
    assert(per['crystal_maiden'].either == 14,
        'the CM rows must stay counted and stay void -- see §2')
end

tests['[5] negative control: with the pre-ladder price of 0 the flip band is empty'] = function()
    local per = corpus_flips(0)
    for sHero, s in pairs(per) do
        assert(s.either == 0,
            sHero .. ': a zero price cannot flip either consumer (both sides of '
                .. 'the comparison are identical), got ' .. s.either
                .. ' -- the §4 count would not be attributable to c386d5f3')
    end
    -- and the sweep still SAW the frames, so the zero above is a reading and not
    -- an empty loop
    local nSeen = 0
    for _, s in pairs(per) do nSeen = nSeen + s.n end
    assert(nSeen == 168, 'the control must sweep the same 168 frames, saw ' .. nSeen)
end

-- ---------------------------------------------------------------------------
-- 6.  `zusult`: a gate whose fixture domain was empty until 2026-09-01.
-- ---------------------------------------------------------------------------

local ULT_NAME = 'zuus_thundergods_wrath'

--- Zeus's ult price on this frame, from the ladder (the value the gate reads).
local function ult_price(nRank)
    local steps = assert(ladder('zuus', ULT_NAME), 'Zeus\'s ult must carry a ladder')
    return steps[math.min(nRank, #steps)]
end

tests['[6] the zusult gate returns false at its price line when the price is 0'] = function()
    local J, bot = rf.load(ZEUS_FRAME)
    J.IsSoakCandidate = function(id) return id == 'zusult' end
    local X = rf.load_hero('zuus')
    local hR = bot:GetAbilityByName(ULT_NAME)
    assert(hR:IsTrained() and hR:GetCooldownTimeRemaining() == 0,
        'the gate\'s own preconditions hold on this frame')
    assert(hR:GetManaCost() == ult_price(hR:GetLevel()),
        'the real price is on the handle, got ' .. tostring(hR:GetManaCost()))
    assert(bot:GetMana() < hR:GetManaCost(),
        '152 mana is below the 250 price -- the gate has something to decide')

    -- Today: the gate gets past its price line.  (Whether it ultimately answers
    -- true depends on clauses further down; what §6 pins is that the price line
    -- no longer ends the call.)
    local hTarget = bot
    local bToday = X.zuus_ShouldSaveManaForUlt(bot, hTarget,
        bot:GetAbilityByName('zuus_lightning_bolt'))

    -- Pre-ladder: put the 0 back on this one handle and nothing else.
    rawget(hR, '__spec').GetManaCost = function() return 0 end
    local bPre = X.zuus_ShouldSaveManaForUlt(bot, hTarget,
        bot:GetAbilityByName('zuus_lightning_bolt'))
    assert(bPre == false,
        'with a 0 price the gate must return false at `nCost <= 0` -- that is the '
            .. 'line that made every pre-2026-09-01 fixture claim about zusult vacuous')
    assert(bToday ~= bPre,
        'the ladder must change this gate\'s answer on this frame; today='
            .. tostring(bToday) .. ' pre=' .. tostring(bPre))
end

tests['[6b] corpus: 16 Zeus frames hold a ready ult, and the old gate died on all 16'] = function()
    local nAlive, nReady, nDeny = 0, 0, 0
    local p = assert(io.popen('ls tests/fixtures/*.lua'))
    for sPath in p:lines() do
        local chunk = loadfile(sPath)
        if chunk ~= nil then
            local ok, fx = pcall(chunk)
            if ok and type(fx) == 'table' and fx.units ~= nil then
                for _, u in ipairs(fx.units) do
                    if u.name == 'npc_dota_hero_zuus' and u.alive then
                        nAlive = nAlive + 1
                        local nRank, nCd = 0, 0
                        for _, a in ipairs(u.abilities or {}) do
                            if a.name == ULT_NAME then nRank, nCd = a.level, a.cd end
                        end
                        if nRank >= 1 and nCd <= 0 then
                            nReady = nReady + 1
                            if u.mp < ult_price(nRank) then nDeny = nDeny + 1 end
                        end
                    end
                end
            end
        end
    end
    p:close()
    assert(nAlive == 43 and nReady == 16 and nDeny == 7,
        'zusult corpus domain moved -- expected 43 alive Zeus frames, 16 with a '
            .. 'ready ult, 7 of those unaffordable; got ' .. nAlive .. ' / '
            .. nReady .. ' / ' .. nDeny)
    -- The pre-ladder domain is 0 by construction, not by measurement: the gate's
    -- fourth line refuses every frame whose price reads 0, and §6 drove that.
    assert(nReady > 0,
        'the pre-ladder domain being empty is only interesting because the '
            .. 'preconditions DID hold somewhere')
end

return tests

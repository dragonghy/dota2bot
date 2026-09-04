-- [hero] The fixture world answers the rest of its own KV -- and the ledger of
-- where it still answers 0.
--
-- WHY THIS FILE EXISTS (hero 2026-09-04)
-- --------------------------------------
-- tests/mock/replay_fixture.lua learned to charge the KV mana price on
-- 2026-09-01 (tests/test_fixture_mana_price.lua), and the finding that round
-- wrote down was general: "a silent 0 out of an unspecced getter is not a small
-- number, it is a DIFFERENT PREDICATE".  It then specced exactly one getter.
--
-- Three more sat on mock/bot_api.lua's generic `^Get` default, answering 0 for
-- every ability on every frame -- and the KV that answers them was already in
-- the SAME snapshot the mana ladder reads:
--
--     GetSpecialValueInt / GetSpecialValueFloat   AbilityValues/<key>/value
--     GetCastRange                                AbilityCastRange
--
-- So this is not "the offline world cannot know ability specials", which is how
-- three separate levers recorded it as a structural wall (GH #162 `lionsplash`,
-- `zusaether` 2026-09-04, and the `hero-2` preflight).  It is one snapshot and
-- two unspecced getters.
--
-- MEASURED BEFORE THE CHANGE, over tests/fixtures + tests/frames -- section 4
-- holds the line on every one of these:
--   * 110 files, 4811 ability handles.
--   * 872 handles belong to a focus hero; 779 of those carry a KV block here.
--     The 93 that do not are innates (lion_innate_to_hell_and_back 24,
--     skeleton_king_innate_vampiric_spirit 34) and GENERIC talent rows (35),
--     which live in npc_abilities.txt and are outside this snapshot by
--     construction, not by omission.
--   * 402 of the 779 declare an AbilityCastRange -- 402 handles whose
--     GetCastRange() answered 0.
--   * 5306 (handle, key) pairs declare a base value -- every GetSpecialValue*
--     read on them answered 0.
--
-- THE WORKED EXAMPLE IS THE REGISTERED `hero-2` LEVER'S OWN BRANCH.
-- hero_axe.lua X.ConsiderR reads `nCastRange = abilityR:GetCastRange()` and then
-- iterates `J.GetAroundEnemyHeroList( nCastRange + 200 )`.  Culling Blade's cast
-- range is 175, so the engine walks a 375u ring -- and the ring every
-- fixture-driven run of that branch has ever walked is 200u, 47% short.  A
-- claim of the form "no frame in the corpus reaches ConsiderR's kill loop" was
-- taken through the short ring.  Section 5 pins both numbers.
--
-- THE FAILURE DIRECTION.  A getter stuck at 0 makes a search radius SMALLER and
-- a damage threshold LOWER, so it understates reach and understates lethality:
-- it manufactures "this branch is not reached" readings.  That is the opposite
-- direction from the mana defect (which manufactured reachability), and it is
-- the direction that quietly retires levers.
--
-- HONEST BOUNDS -- section 3 is the ledger, and it is the important half
-- ---------------------------------------------------------------------
--   * Only the `base` string is served.  The conditional half --
--     special_bonus_*, LinkedSpecialBonus, scepter/shard rows -- is NOT applied.
--     In game the engine FOLDS a trained talent into the base before the handle
--     answers, so a read taken on a hero who trained the row is UNDERSTATED
--     here.  Section 3 asserts that on Culling Blade, whose +150 talent row is
--     precisely the fold hero_axe.lua's t25 note is filed on.
--   * A key with no base (NO-BASE, e.g. lion_finger_of_death/splash_radius) and
--     a key absent from the ability (splash_radius_scepter) both answer 0 --
--     which is what the ENGINE answers, and is the entire content of GH #162.
--     Section 2 pins both so nobody reads this change as having repaired them.
--   * Non-focus heroes are untouched.  There is no block for them in the
--     snapshot, no spec is installed, and they still answer 0.  A reading taken
--     on one must not be quoted as though the KV were charged.
--   * AbilityCastPoint and AbilityCooldown were the next small batch, and were
--     served on 2026-09-04 -- sections 7 and 8, with their own measurements.
--     Section 4e now counts the population each one moved (575 / 723) rather
--     than the residue.
--
-- THE SECOND BATCH'S TWO FINDINGS, because neither generalises from the first
-- ------------------------------------------------------------------------
--   * GetCastPoint is served and DORMANT.  Its only downstream is
--     `GetHealthRegen() * nDelay` inside J.WillMagicKillTarget, and
--     GetHealthRegen is itself unspecced -- no dump carries a health-regen
--     field, so the product is 0 * anything.  Measured, not assumed: 13 Lion
--     frames, 58 living enemy pairs, 0 verdict flips (section 7d).  Same shape
--     as backlog -88's `0 == 0` charge check: a reading with an identically-zero
--     factor downstream measures the CONJUNCTION.  Closing it needs a DUMPER
--     change -- health regen is per-frame unit state, not ability KV -- so it
--     is not this snapshot's to close.
--   * GetCooldown has TWO failure directions off the SAME 0, because the 0 sat
--     on both sides of `remaining >= ultCD / 2`.  J.CanUseRefresherOrb's clause
--     vacated (permissive: true on 36 corpus frames, 3 under the real cooldown)
--     while J.CanUseRefresherShard's became `remaining <= -2` (impossible: 0
--     frames, 6 under the real cooldown).  Section 8 pins both.  Any rule of
--     thumb of the form "an unspecced getter makes guards permissive" is wrong
--     in one of its halves here whichever way it is written.
--   * The ladder is a KV DECLARATION, not a frame reading.  Where a replay
--     measured a value, the measurement outranks this (same rule the mana
--     ladder states for the 246-vs-250 Zeus ultimate).
--
-- LIMITS
--   * Every count here is a property of THIS corpus, which is curated for other
--     investigations and holds near-duplicate instants from single games.  None
--     of it is a frequency estimate about real games.
--   * The floors below are floors, not equalities: the corpus grows.  A ceiling
--     would go red on every added fixture and teach the next reader to raise a
--     number instead of to look at one.

package.path = 'tests/?.lua;' .. package.path

local rf = require('mock.replay_fixture')
local shapes = require('mock.special_value_shapes')

local tests = {}

local AXE_FRAME = 'tests/fixtures/f_260820_043637_axe_ring_close.lua'
local CULL      = 'axe_culling_blade'
local CALL      = 'axe_berserkers_call'

-- A focus hero and a non-focus hero that share one frame, so section 2's
-- "non-focus still answers 0" is taken on the same loader call as the served
-- reads and cannot be a different world.
local LION_FRAME = 'tests/fixtures/f_222428_lion_lich_burst.lua'
local FINGER     = 'lion_finger_of_death'

local RING_PAD = 200  -- ConsiderR's own widening of the cast-range list

--- The KV ladder read straight off the snapshot -- deliberately a SECOND
--- implementation of the loader's `value_ladder`.  A test that called the
--- loader's copy would agree with it by construction and could not notice it
--- going wrong; this one can.
local function ladder(sHero, sAbility, sKey)
    local abils = shapes.SHAPES[sHero]
    if abils == nil then return nil end
    local e = abils[sAbility]
    if e == nil or e[sKey] == nil or e[sKey].base == nil then return nil end
    local steps = {}
    for tok in e[sKey].base:gmatch('%S+') do
        local n = tonumber(tok)
        if n == nil then return nil end
        steps[#steps + 1] = n
    end
    if #steps == 0 then return nil end
    return steps
end

local function corpus_files()
    local out = {}
    for _, d in ipairs({ 'tests/fixtures', 'tests/frames' }) do
        local p = assert(io.popen('ls ' .. d .. ' 2>/dev/null'))
        for l in p:lines() do
            if l:match('%.lua$') then out[#out + 1] = d .. '/' .. l end
        end
        p:close()
    end
    table.sort(out)
    return out
end

--- One pass over the corpus, counting the population each getter serves.  Every
--- counter is reported even when zero: the defect this file exists for is a
--- reader that answered 0 while nothing said whether its population was empty.
local function scan()
    local c = {
        files = 0, handles = 0,
        focus = 0, focus_block = 0, focus_no_block = 0,
        cast_range = 0, value_keys = 0,
        -- still unserved, counted so the residue is a number
        cast_point = 0, cooldown = 0,
        nonfocus = 0,
    }
    for _, f in ipairs(corpus_files()) do
        local ok, fx = pcall(dofile, f)
        if ok and type(fx) == 'table' and fx.units then
            c.files = c.files + 1
            for _, u in ipairs(fx.units) do
                local short = tostring(u.name):gsub('^npc_dota_hero_', '')
                local blk = shapes.SHAPES[short]
                for _, a in ipairs(u.abilities or {}) do
                    c.handles = c.handles + 1
                    if blk == nil then
                        c.nonfocus = c.nonfocus + 1
                    else
                        c.focus = c.focus + 1
                        local ent = blk[a.name]
                        if ent == nil then
                            c.focus_no_block = c.focus_no_block + 1
                        else
                            c.focus_block = c.focus_block + 1
                            if ladder(short, a.name, 'AbilityCastRange') then
                                c.cast_range = c.cast_range + 1
                            end
                            if ladder(short, a.name, 'AbilityCastPoint') then
                                c.cast_point = c.cast_point + 1
                            end
                            if ladder(short, a.name, 'AbilityCooldown') then
                                c.cooldown = c.cooldown + 1
                            end
                            for k, v in pairs(ent) do
                                if k:sub(1, 7) ~= 'Ability' and v.base ~= nil then
                                    c.value_keys = c.value_keys + 1
                                end
                            end
                        end
                    end
                end
            end
        end
    end
    return c
end

local cached_scan
local function census()
    if cached_scan == nil then cached_scan = scan() end
    return cached_scan
end

local function axe_cull()
    local J, bot, heroes = rf.load(AXE_FRAME)
    return J, bot, bot:GetAbilityByName(CULL), heroes
end

-- ===================================================================
-- 1.  What is served.

tests['1a: Culling Blade damage is the KV value, not 0'] = function()
    local _, _, cull = axe_cull()
    local steps = assert(ladder('axe', CULL, 'damage'), 'no damage ladder in the KV snapshot')
    local rank = cull:GetLevel()
    assert(rank >= 1, 'this frame carries a trained Culling Blade, got rank ' .. tostring(rank))
    assert(cull:GetSpecialValueInt('damage') == steps[rank],
        'served damage should be the KV step for the handle rank: expected '
        .. tostring(steps[rank]) .. ', got ' .. tostring(cull:GetSpecialValueInt('damage')))
    assert(cull:GetSpecialValueInt('damage') > 0,
        'the whole point: this read used to be 0 on every frame in the tree')
end

tests['1b: the read is RANK-INDEXED and clamped, not a frozen constant'] = function()
    local _, _, cull = axe_cull()
    local steps = assert(ladder('axe', CULL, 'damage'))
    local spec = rawget(cull, '__spec')
    local saved = spec.GetLevel
    for rank = 1, #steps do
        spec.GetLevel = rank
        assert(cull:GetSpecialValueInt('damage') == steps[rank],
            'rank ' .. rank .. ' should read ' .. tostring(steps[rank]))
    end
    -- Past the ladder's end (talent rows and 3-step ultimate ladders both hit
    -- this) the last step is paid, never nil.  Read through the Float getter on
    -- purpose: the Int one compares the value to 0 to pick its truncation, so a
    -- nil would surface as a raw "attempt to compare number with nil" instead of
    -- as this sentence -- red for a reason the reader cannot act on.
    spec.GetLevel = #steps + 4
    local nPast = cull:GetSpecialValueFloat('damage')
    assert(nPast == steps[#steps],
        'a rank past the ladder pays its last step (' .. tostring(steps[#steps])
        .. '), got ' .. tostring(nPast))
    -- Untrained reads step 1 rather than erroring; callers gate on IsTrained.
    spec.GetLevel = 0
    local nZero = cull:GetSpecialValueFloat('damage')
    assert(nZero == steps[1], 'rank 0 reads step 1, got ' .. tostring(nZero))
    spec.GetLevel = saved
end

tests['1c: GetCastRange answers the KV cast range'] = function()
    local _, _, cull = axe_cull()
    local steps = assert(ladder('axe', CULL, 'AbilityCastRange'),
        'Culling Blade declares an AbilityCastRange in the snapshot')
    assert(cull:GetCastRange() == steps[math.min(cull:GetLevel(), #steps)],
        'cast range should be the KV value, got ' .. tostring(cull:GetCastRange()))
    assert(cull:GetCastRange() > 0, 'this read used to be 0 for all 402 handles')
end

tests['1d: Float and Int agree, and Int truncates toward zero'] = function()
    local _, _, cull = axe_cull()
    local f = cull:GetSpecialValueFloat('armor_per_stack')
    local i = cull:GetSpecialValueInt('armor_per_stack')
    assert(type(f) == 'number' and type(i) == 'number', 'both getters answer numbers')
    assert(i == math.floor(f), 'Int is the truncation of Float: ' .. tostring(i)
        .. ' vs ' .. tostring(f))
end

-- ===================================================================
-- 2.  What is refused -- and why each refusal is the TRUTHFUL answer.

tests['2a: a NO-BASE key still reads 0 (GH #162 is not repaired by this)'] = function()
    local _, bot = rf.load(LION_FRAME, 'npc_dota_hero_lion')
    local finger = bot:GetAbilityByName(FINGER)
    local entry = shapes.SHAPES['lion'][FINGER]['splash_radius']
    assert(entry ~= nil and entry.base == nil,
        'splash_radius is the NO-BASE entry this repo reasons about; if the KV '
        .. 'gave it a base, re-anchor GH #162 and the `lionsplash` gate')
    assert(finger:GetSpecialValueInt('splash_radius') == 0,
        'the engine answers 0 for a key with no base value, and so does this')
end

tests['2b: a key ABSENT from the ability still reads 0'] = function()
    local _, bot = rf.load(LION_FRAME, 'npc_dota_hero_lion')
    local finger = bot:GetAbilityByName(FINGER)
    assert(shapes.SHAPES['lion'][FINGER]['splash_radius_scepter'] == nil,
        'splash_radius_scepter is the stale key GH #162 found; it is absent')
    assert(finger:GetSpecialValueInt('splash_radius_scepter') == 0,
        'an absent key reads 0 -- silently, which is the defect GH #162 named')
end

tests['2c: a NON-FOCUS hero is untouched and still reads 0'] = function()
    local _, _, heroes, fx = rf.load(LION_FRAME, 'npc_dota_hero_lion')
    local other_name, ability_name
    for _, u in ipairs(fx.units) do
        local short = tostring(u.name):gsub('^npc_dota_hero_', '')
        if shapes.SHAPES[short] == nil and u.abilities and u.abilities[1] then
            other_name, ability_name = u.name, u.abilities[1].name
        end
    end
    assert(other_name ~= nil,
        'this frame carries a non-focus hero with abilities to take the bound on')
    local ab = heroes[other_name]:GetAbilityByName(ability_name)
    assert(ab ~= nil, 'handle for ' .. tostring(other_name) .. ' / ' .. tostring(ability_name))
    assert(ab:GetSpecialValueInt('damage') == 0 and ab:GetCastRange() == 0,
        'no snapshot block for ' .. tostring(other_name) .. ', so nothing is served '
        .. '-- this NARROWS the vacuity, it does not close it')
end

-- ===================================================================
-- 3.  The conditional fold is NOT applied, and that is a stated bound.

tests['3a: a trained special_bonus_* row is NOT folded into the served base'] = function()
    local _, _, cull = axe_cull()
    local steps = assert(ladder('axe', CULL, 'damage'))
    local bonus = shapes.SHAPES['axe'][CULL]['damage'].bonus
    assert(bonus ~= nil and bonus['special_bonus_unique_axe_5'] ~= nil,
        'Culling Blade damage carries the +150 talent row this bound is about')
    local spec = rawget(cull, '__spec')
    local saved = spec.GetLevel
    spec.GetLevel = 3
    assert(cull:GetSpecialValueInt('damage') == steps[3],
        'the served read is the BASE step (' .. tostring(steps[3]) .. '), never '
        .. 'base+150 -- the engine folds a trained talent in game, this loader '
        .. 'does not, so a fold-dependent test must drive the fold itself')
    spec.GetLevel = saved
end

-- ===================================================================
-- 4.  The corpus census: the population each getter serves, with floors.

tests['4a: the scan actually ran (a bare 0 must not look like a clean bill)'] = function()
    local c = census()
    assert(c.files >= 100, 'corpus files, got ' .. c.files)
    assert(c.handles >= 4500, 'ability handles, got ' .. c.handles)
    assert(c.nonfocus > 0, 'the corpus holds non-focus heroes -- section 2c depends on it')
end

tests['4b: recorded -- the focus-five handle population and its residue'] = function()
    local c = census()
    -- Measured 2026-09-04: focus 872 = block 779 + no_block 93 (innates 58 +
    -- generic talent rows 35).  Floors, because the corpus grows.
    assert(c.focus >= 850, 'focus-hero handles, got ' .. c.focus)
    assert(c.focus_block >= 750, 'focus handles with a KV block, got ' .. c.focus_block)
    assert(c.focus == c.focus_block + c.focus_no_block,
        'the split is exhaustive: ' .. c.focus .. ' ~= ' .. c.focus_block
        .. ' + ' .. c.focus_no_block)
    assert(c.focus_no_block > 0,
        'innates and GENERIC talent rows live in npc_abilities.txt, outside this '
        .. 'snapshot BY CONSTRUCTION; a zero here means the snapshot widened and '
        .. 'the residue sentence in the header needs re-measuring')
end

tests['4c: recorded -- 402+ handles whose GetCastRange() used to be 0'] = function()
    local c = census()
    assert(c.cast_range >= 380,
        'handles carrying an AbilityCastRange base, got ' .. c.cast_range)
    assert(c.cast_range < c.focus_block,
        'not every ability declares a cast range (passives do not) -- '
        .. c.cast_range .. ' of ' .. c.focus_block)
end

tests['4d: recorded -- 5306+ (handle, key) pairs that used to read 0'] = function()
    local c = census()
    assert(c.value_keys >= 5000,
        'AbilityValues keys with a base, got ' .. c.value_keys)
end

tests['4e: recorded -- the second batch\'s population, now served'] = function()
    local c = census()
    -- Was the residue.  2026-09-04 (second batch) served both; the counts are
    -- the population each one moved, kept as floors because the corpus grows.
    -- Measured: 575 AbilityCastPoint handles, 723 AbilityCooldown handles.
    assert(c.cast_point >= 550, 'AbilityCastPoint handles, got ' .. c.cast_point)
    assert(c.cooldown >= 700, 'AbilityCooldown handles, got ' .. c.cooldown)
    assert(c.cooldown > c.cast_point,
        'more abilities declare a cooldown than a cast point (instants and '
        .. 'passives carry a cooldown and no cast point) -- ' .. c.cooldown
        .. ' vs ' .. c.cast_point)
    assert(c.cast_point < c.focus_block and c.cooldown < c.focus_block,
        'neither key is on every handle -- ' .. c.cast_point .. '/' .. c.cooldown
        .. ' of ' .. c.focus_block)
end

-- ===================================================================
-- 5.  The worked example: ConsiderR's ring was 200u, the engine's is 375u.

tests['5a: the ring hero_axe.lua X.ConsiderR walks was 47% short'] = function()
    local _, _, cull = axe_cull()
    local nCastRange = cull:GetCastRange()
    assert(nCastRange == 175,
        'Culling Blade cast range, got ' .. tostring(nCastRange))
    assert(nCastRange + RING_PAD == 375,
        'the list ConsiderR iterates is GetCastRange() + 200')
    -- Before this change GetCastRange() answered 0, so the same expression
    -- produced 200.  The old ring is asserted as ARITHMETIC, not re-measured:
    -- it is what `0 + 200` is.
    assert(0 + RING_PAD == 200 and (0 + RING_PAD) / (nCastRange + RING_PAD) < 0.54,
        'the ring the fixture world used to walk was 200 of 375')
end

tests['5b: the ring is not the only branch that moved -- 402 handles did'] = function()
    local c = census()
    assert(c.cast_range >= 380,
        'every one of these handles fed a search radius that read 0: ' .. c.cast_range)
end

--- Every tests/fixtures frame carrying an Axe, driven end to end through the
--- loader: how many enemy heroes sit in each ring, and how many of them are in
--- the `hero-2` band.  Restricted to tests/fixtures on purpose -- that is the
--- population tests/test_axe_culling_band_power.lua sized, and the point of
--- this reading is that the two AGREE.
local function axe_ring_sweep()
    local p = assert(io.popen('ls tests/fixtures'))
    local files = {}
    for l in p:lines() do
        if l:match('%.lua$') then files[#files + 1] = 'tests/fixtures/' .. l end
    end
    p:close()
    table.sort(files)
    local s = { frames = 0, ready = 0, ring_short = 0, ring_true = 0, band = 0 }
    for _, f in ipairs(files) do
        local ok, fx = pcall(dofile, f)
        local has = false
        if ok and type(fx) == 'table' and fx.units then
            for _, u in ipairs(fx.units) do
                if u.name == 'npc_dota_hero_axe' then has = true end
            end
        end
        if has then
            s.frames = s.frames + 1
            local ok2, _, bot, heroes = pcall(rf.load, f, 'npc_dota_hero_axe')
            if ok2 then
                local cull = bot:GetAbilityByName(CULL)
                if cull and cull:GetLevel() > 0 and cull:IsFullyCastable() then
                    s.ready = s.ready + 1
                    local rank = cull:GetLevel()
                    local shipped = 150 + 100 * rank          -- hero_axe.lua's constant
                    local kv = cull:GetSpecialValueInt('damage')
                    local ring = cull:GetCastRange() + RING_PAD
                    for _, h in pairs(heroes) do
                        if h ~= bot and h:GetTeam() ~= bot:GetTeam() then
                            local d = (h:GetLocation() - bot:GetLocation()):Length2D()
                            if d <= 0 + RING_PAD then s.ring_short = s.ring_short + 1 end
                            if d <= ring then
                                s.ring_true = s.ring_true + 1
                                local eff = h:GetHealth() + h:GetHealthRegen() * 0.8
                                if eff > shipped and eff <= kv then s.band = s.band + 1 end
                            end
                        end
                    end
                end
            end
        end
    end
    return s
end

tests['5c: driven end to end, the corrected ring reproduces the sibling sizing'] = function()
    local s = axe_ring_sweep()
    -- tests/test_axe_culling_band_power.lua derived its rings by parsing the KV
    -- DIRECTLY, bypassing the loader, and recorded 22 ready frames (20 rank 1,
    -- 2 rank 2) with 3 in-ring enemy-frames.  Driving the same population
    -- through the loader now lands on the same numbers -- which is the check
    -- that matters: agreement between an instrument and a hand computation that
    -- did not use it.
    assert(s.frames >= 25, 'Axe-carrying fixtures, got ' .. s.frames)
    assert(s.ready >= 20, 'Culling-ready frames, got ' .. s.ready)
    assert(s.ring_true == 3, 'in-ring enemy-frames at the true 375u ring, got '
        .. s.ring_true .. ' -- the sibling file records 3')
    assert(s.ring_short == 2, 'and 2 at the 200u ring the loader used to walk, got '
        .. s.ring_short)
    assert(s.ring_short < s.ring_true,
        'the short ring UNDERSTATES reach, which is the failure direction this '
        .. 'file exists for')
    -- And the band is still empty, exactly as the power calculation predicted
    -- (~0.07 expected hits on 3 in-ring frames).  This is NOT the frame `hero-2`
    -- is waiting for; it is the statement that correcting the instrument did not
    -- conjure one.  If this ever goes non-zero the lever HAS its frame -- cut it
    -- with make_fixture.py and say so, do not relax the assertion.
    assert(s.band == 0, 'band-occupied in-ring frames, got ' .. s.band
        .. ' -- a non-zero here is the `hero-2` frame, not a regression')
end

-- ===================================================================
-- 6.  Independence: this file does not import the loader's own reader.

tests['6a: the ladder here is a second implementation, not the loader\'s'] = function()
    local src = assert(io.open('tests/mock/replay_fixture.lua', 'r'))
    local s = src:read('*a'); src:close()
    assert(s:find('local function value_ladder', 1, true) ~= nil,
        'the loader still owns a `value_ladder`; if it was renamed, re-anchor '
        .. 'this assertion rather than deleting it')
    assert(s:find('sp.GetSpecialValueInt', 1, true) ~= nil
        and s:find('sp.GetCastRange', 1, true) ~= nil,
        'the loader still installs the two getters this file measures')
    assert(s:find('sp.GetCastPoint', 1, true) ~= nil
        and s:find('sp.GetCooldown ', 1, true) ~= nil,
        'the loader still installs the SECOND batch\'s two getters (sections 7 '
        .. 'and 8); `sp.GetCooldown ` is anchored with its trailing space so it '
        .. 'cannot be satisfied by the pre-existing sp.GetCooldownTimeRemaining')
    -- The focus-five guard.  Pinned as SOURCE, because it is not load-bearing
    -- for the ANSWER: with the guard removed a non-focus hero still reads 0,
    -- since value_ladder finds no block and returns nil.  Section 2c therefore
    -- cannot see the guard go (measured: mutant M7 of
    -- tools/agent/mutstand_kvgetters.sh survives 2c and is caught only here).
    -- It stays because dropping it installs three closures per handle on ~3900
    -- non-focus handles for no answer at all, and because the intent -- "this
    -- narrows the vacuity, it does not close it" -- is worth being able to read
    -- off the code.  Removing it should be a decision, not a drift.
    assert(s:find('has_kv(u.name)', 1, true) ~= nil,
        'the loader dropped its focus-five guard; that is a decision with a cost '
        .. '(see this case), not a cleanup -- re-anchor here if it was taken')
    -- And this file reaches the snapshot directly, never through the loader.
    local own = assert(io.open('tests/test_fixture_kv_getters.lua', 'r'))
    local t = own:read('*a'); own:close()
    assert(t:find('rf%.value_ladder') == nil and t:find('rf%.rank_step') == nil,
        'this file must not borrow the loader\'s reader -- it would agree by '
        .. 'construction and could not notice it going wrong')
end

-- ===================================================================
-- 7.  The SECOND batch, half one: GetCastPoint -- served, and DORMANT.
--
-- The reads move (section 7a), but not one kill projection in the corpus moves
-- with them, and that is the finding rather than a caveat.  nDelay reaches
-- J.WillMagicKillTarget as `GetHealthRegen() * nDelay`, and GetHealthRegen is
-- ITSELF on the generic `^Get` default -- it appears nowhere in the loader and
-- no dump carries a health-regen field.  So the product is `0 * anything` and
-- the cast point cannot yet change a verdict.
--
-- This is the shape backlog -88 wrote down on `max_skeleton_charges`: a reading
-- whose downstream carries an identically-zero factor measures the CONJUNCTION,
-- and nothing inside the file can separate the two until the other factor stops
-- being zero.  The difference here is that it was measured on purpose before
-- the claim was made, not discovered afterwards.
--
-- And unlike the first batch this one CANNOT be closed from this snapshot:
-- health regen is per-frame unit state (base + items + talents), not ability
-- KV.  It needs the dumper to emit it -- ball with the replay group.

local CP_FRAMES = {
    -- (frame, hero, ability, KV cast point) -- one per distinct shape served
    { 'tests/fixtures/f_222428_lion_lich_burst.lua', 'npc_dota_hero_lion',
      'lion_finger_of_death', 0.3 },
    { 'tests/fixtures/f_230952_zuus_ult_hoard.lua', 'npc_dota_hero_zuus',
      'zuus_thundergods_wrath', 0.4 },
}

tests['7a: GetCastPoint answers the KV, where it used to answer 0'] = function()
    local _, _, cull = axe_cull()
    assert(cull:GetCastPoint() == 0.3,
        'Culling Blade cast point, got ' .. tostring(cull:GetCastPoint()))
    for _, f in ipairs(CP_FRAMES) do
        local _, bot = rf.load(f[1], f[2])
        local h = bot:GetAbilityByName(f[3])
        assert(h ~= nil, f[3] .. ' handle missing on ' .. f[1])
        assert(h:GetCastPoint() == f[4],
            f[3] .. ' cast point, want ' .. f[4] .. ' got ' .. tostring(h:GetCastPoint()))
    end
end

tests['7b: a KV-declared 0 is the ENGINE\'s answer, not an absent spec'] = function()
    -- Three focus abilities declare AbilityCastPoint 0.  Reading 0 off them is
    -- correct and is INDISTINGUISHABLE from "nothing was installed" if you only
    -- look at the read -- so this case looks at the snapshot too, which is the
    -- only place the difference exists.
    local zeroes = {
        { 'crystal_maiden', 'crystal_maiden_freezing_field' },
        { 'lion',           'lion_voodoo' },
        { 'zuus',           'zuus_lightning_hands' },
    }
    for _, z in ipairs(zeroes) do
        local steps = ladder(z[1], z[2], 'AbilityCastPoint')
        assert(steps ~= nil, z[2] .. ' should DECLARE a cast point ladder')
        for i, v in ipairs(steps) do
            assert(v == 0, z[2] .. ' step ' .. i .. ' should be 0, got ' .. v)
        end
    end
    -- The consequence, stated so nobody re-derives it: hero_crystal_maiden.lua
    -- X.ConsiderW passes this very read into J.WillMagicKillTarget as nDelay.
    -- Its value was 0 before this change and is 0 after it.  A CM freezing-field
    -- reading is NOT evidence that this batch did or did not move anything.
end

tests['7c: nothing downstream can move yet -- GetHealthRegen is the zero factor'] = function()
    -- The other operand, measured rather than asserted from the source.
    local _, bot, heroes = rf.load(CP_FRAMES[1][1], CP_FRAMES[1][2])
    local seen, nonzero = 0, 0
    for _, h in pairs(heroes) do
        if h.GetHealthRegen ~= nil then
            seen = seen + 1
            if h:GetHealthRegen() ~= 0 then nonzero = nonzero + 1 end
        end
    end
    assert(seen > 0, 'the frame holds units to read regen off')
    assert(nonzero == 0,
        'GetHealthRegen still answers 0 for every unit; ' .. nonzero .. ' of '
        .. seen .. ' now answer otherwise. A NON-ZERO HERE IS GOOD NEWS: the '
        .. 'dumper started carrying health regen, so the cast point stopped '
        .. 'being dormant. Re-run the Lion Finger sweep in section 7d and '
        .. 'replace the recorded 0 flips with what it now measures -- do not '
        .. 'relax this into `>= 0`')
    -- And the loader must not have quietly specced it, which would make the
    -- reading above a statement about a stub instead of about the dump.
    -- Anchored on the ASSIGNMENT form, not on the bare name: this file's own
    -- prose and the loader's header both mention GetHealthRegen, so a bare-name
    -- check is satisfiable by a comment and would pass while the loader served
    -- it (mutant M12 installs exactly `GetHealthRegen = 12,`).
    local src = assert(io.open('tests/mock/replay_fixture.lua', 'r'))
    local s = src:read('*a'); src:close()
    assert(s:find('GetHealthRegen%s*=') == nil,
        'the loader now installs GetHealthRegen -- update this section, it is '
        .. 'measuring the wrong world')
    assert(bot ~= nil)
end

tests['7d: recorded -- 0 kill-verdict flips over the Lion Finger sweep'] = function()
    -- The sweep the claim above rests on: every corpus frame carrying a Lion
    -- with a trained Finger, every living enemy hero on it, the KV damage, and
    -- the two nDelay values ConsiderR would pass (0 + 0.25 before this change,
    -- GetCastPoint() + 0.25 after).  Measured 2026-09-04: 13 frames, 58 pairs,
    -- 5 kills either way, 0 flips, and 0 targets with a non-zero regen.
    local frames, npairs, kills_old, kills_new, flips, regen_pos = 0, 0, 0, 0, 0, 0
    for _, f in ipairs(corpus_files()) do
        local okf, fx = pcall(dofile, f)
        if okf and type(fx) == 'table' and fx.units then
            for _, u in ipairs(fx.units) do
                if u.name == 'npc_dota_hero_lion' then
                    local ok, J, bot, heroes = pcall(function()
                        local a, b, c = rf.load(f, u.name); return a, b, c
                    end)
                    if ok and bot ~= nil then
                        local r = bot:GetAbilityByName(FINGER)
                        if r ~= nil and r:GetLevel() > 0 then
                            frames = frames + 1
                            local cp = r:GetCastPoint()
                            local dmg = r:GetSpecialValueInt('damage')
                            for _, h in pairs(heroes) do
                                if h ~= bot and h.GetTeam ~= nil
                                    and h:GetTeam() ~= bot:GetTeam() and h:IsAlive()
                                then
                                    npairs = npairs + 1
                                    if h:GetHealthRegen() > 0 then regen_pos = regen_pos + 1 end
                                    local old = J.WillMagicKillTarget(bot, h, dmg, 0 + 0.25)
                                    local new = J.WillMagicKillTarget(bot, h, dmg, cp + 0.25)
                                    if old then kills_old = kills_old + 1 end
                                    if new then kills_new = kills_new + 1 end
                                    if old ~= new then flips = flips + 1 end
                                end
                            end
                        end
                    end
                end
            end
        end
    end
    assert(frames >= 13, 'Lion frames with a trained Finger, got ' .. frames)
    assert(npairs >= 50, 'living enemy-hero pairs, got ' .. npairs)
    assert(kills_old == kills_new,
        'the two nDelay values must agree while regen is 0: ' .. kills_old
        .. ' vs ' .. kills_new)
    assert(flips == 0, 'kill-verdict flips, got ' .. flips
        .. ' -- non-zero means regen arrived; see section 7c')
    assert(regen_pos == 0, 'targets with a non-zero regen, got ' .. regen_pos)
end

-- ===================================================================
-- 8.  The SECOND batch, half two: GetCooldown -- and the two directions.
--
-- Unlike the cast point this one is NOT dormant, and it does not have one
-- failure direction.  The same 0 sat on BOTH sides of a comparison in
-- jmz_func.lua and pushed two neighbouring guards opposite ways:
--
--   J.CanUseRefresherOrb   requires  remaining >= ultCD / 2
--       ultCD = 0  =>  remaining >= 0, TRUE BY CONSTRUCTION.  The clause
--       vacates and the guard is unconditionally permissive.
--   J.CanUseRefresherShard requires  remaining >= ultCD / 2  AND
--                                    ultCD - remaining >= 2
--       ultCD = 0  =>  remaining <= -2, IMPOSSIBLE.  The branch was
--       structurally dead in every fixture-driven run ever taken.
--
-- Measured over the corpus (194 focus-hero frames carrying a non-passive
-- ultimate): Orb was true on 36 frames and is true on 3 -- 33 of the 36 were
-- pure vacuity.  Shard was true on 0 frames and is true on 6.
--
-- A file that reported "the refresher branch never fires here" was reporting an
-- arithmetic impossibility it created, and a file that reported "the refresher
-- branch fires here" was, 92% of the time, reporting an absent clause.

--- One pass over the corpus, evaluating the two refresher guards' cooldown
--- arithmetic on every focus-hero frame with a live ultimate, under the served
--- cooldown and under the 0 that preceded it.  The 0 leg is arithmetic on the
--- real frame, not a second world: only ultCD is replaced.
local function refresher_sweep()
    local s = { frames = 0, orb_now = 0, orb_zero = 0, shard_now = 0, shard_zero = 0 }
    for _, f in ipairs(corpus_files()) do
        local okf, fx = pcall(dofile, f)
        if okf and type(fx) == 'table' and fx.units then
            for _, u in ipairs(fx.units) do
                local short = tostring(u.name):gsub('^npc_dota_hero_', '')
                if shapes.SHAPES[short] ~= nil then
                    local ok, J, bot = pcall(function()
                        local a, b = rf.load(f, u.name); return a, b
                    end)
                    if ok and bot ~= nil then
                        local ult = J.GetUltimateAbility(bot)
                        if ult ~= nil and ult:IsPassive() == false then
                            s.frames = s.frames + 1
                            local cd = ult:GetCooldown()
                            local rem = ult:GetCooldownTimeRemaining()
                            local mc, mana = ult:GetManaCost(), bot:GetMana()
                            if mana >= mc + 375 then
                                if rem >= cd / 2 then s.orb_now = s.orb_now + 1 end
                                if rem >= 0 then s.orb_zero = s.orb_zero + 1 end
                            end
                            if mana >= mc * 2 then
                                if rem >= cd / 2 and cd - rem >= 2 then
                                    s.shard_now = s.shard_now + 1
                                end
                                if rem >= 0 and 0 - rem >= 2 then
                                    s.shard_zero = s.shard_zero + 1
                                end
                            end
                        end
                    end
                end
            end
        end
    end
    return s
end

local cached_refresher
local function refresher()
    if cached_refresher == nil then cached_refresher = refresher_sweep() end
    return cached_refresher
end

tests['8a: GetCooldown answers the KV, where it used to answer 0'] = function()
    local _, bot = rf.load('tests/fixtures/f_230952_zuus_ult_hoard.lua', 'npc_dota_hero_zuus')
    local ult = bot:GetAbilityByName('zuus_thundergods_wrath')
    assert(ult:GetCooldown() == 130,
        'Thundergod\'s Wrath cooldown, got ' .. tostring(ult:GetCooldown()))
    local _, _, cull = axe_cull()
    assert(cull:GetCooldown() == 80,
        'Culling Blade rank-1 cooldown, got ' .. tostring(cull:GetCooldown()))
    -- Rank-indexed like every other ladder: the 3-step ultimate ladders are the
    -- reason rank_step clamps rather than returning nil.
    assert(ladder('axe', 'axe_culling_blade', 'AbilityCooldown')[3] == 70,
        'the ladder itself is 80 75 70')
end

tests['8b: GetCooldown is a DIFFERENT quantity from the remaining time'] = function()
    -- The dump supplies the remaining time; the KV supplies the full cooldown.
    -- Nothing reconciles them and nothing should: Octarine, a scepter row and a
    -- talent all move the real cooldown and none of them are folded here.
    local _, bot = rf.load('tests/fixtures/f_212636_tide_ancient.lua', 'npc_dota_hero_zuus')
    local ult = bot:GetAbilityByName('zuus_thundergods_wrath')
    assert(ult:GetCooldownTimeRemaining() > 0 and ult:GetCooldown() == 130,
        'this frame has both a live remaining time and the KV base')
    assert(ult:GetCooldownTimeRemaining() ~= ult:GetCooldown(),
        'the two reads are independent -- if they ever became equal by '
        .. 'construction, one of them stopped being measured')
end

tests['8c: recorded -- the Orb clause was vacuous on 33 of 36 frames'] = function()
    local s = refresher()
    assert(s.frames >= 190,
        'focus-hero frames with a live ultimate, got ' .. s.frames)
    -- Measured 2026-09-04: 194 frames, orb_zero 36, orb_now 3.
    assert(s.orb_zero >= 30, 'frames where the ultCD=0 Orb guard passed, got ' .. s.orb_zero)
    assert(s.orb_now < s.orb_zero,
        'serving the cooldown must REMOVE Orb passes, not add them: '
        .. s.orb_now .. ' now vs ' .. s.orb_zero .. ' at ultCD=0')
    assert(s.orb_now <= 5, 'Orb passes under the real cooldown, got ' .. s.orb_now)
end

tests['8d: recorded -- the Shard branch was arithmetically impossible'] = function()
    local s = refresher()
    -- `ultCD - remaining >= 2` with ultCD = 0 is `remaining <= -2`, and a
    -- remaining time is never negative.  0 is not "no frame happened to match";
    -- it is the only value that expression could take.
    assert(s.shard_zero == 0,
        'the ultCD=0 Shard branch cannot pass on any frame, got ' .. s.shard_zero
        .. ' -- if this is non-zero the arithmetic changed, re-derive it')
    assert(s.shard_now >= 5,
        'Shard passes under the real cooldown, got ' .. s.shard_now
        .. ' -- the branch went from dead to live, that is the whole finding')
    assert(s.shard_now > s.shard_zero, 'and the direction is the opposite of 8c\'s')
end

tests['8e: the two guards moved in OPPOSITE directions off the same 0'] = function()
    local s = refresher()
    -- Stated as one assertion because it is one finding.  A rule of thumb of
    -- the form "an unspecced getter makes guards permissive" (or restrictive)
    -- is wrong here in one of its two halves whichever way it is written: the 0
    -- sits on BOTH sides of `remaining >= ultCD / 2`, and which way it pushes
    -- depends on which side the other clause reads.
    assert(s.orb_now < s.orb_zero and s.shard_now > s.shard_zero,
        'Orb ' .. s.orb_zero .. '->' .. s.orb_now .. ', Shard '
        .. s.shard_zero .. '->' .. s.shard_now .. ' -- these must have opposite '
        .. 'signs; equal signs means one of them stopped being driven')
end

tests['8f: the unfolded conditional half OVERSTATES a cooldown'] = function()
    -- Opposite sign from the value keys, where an unfolded `+N` talent
    -- understates.  Cooldown bonus rows are REDUCTIONS, so refusing to fold
    -- them leaves the number too big -- and too big is the SAFE direction for
    -- "this ability is not ready" and the unsafe one for "it is".
    local e = shapes.SHAPES['zuus']['zuus_arc_lightning']['AbilityCooldown']
    assert(e.base == '1.6', 'the base is unconditional, got ' .. tostring(e.base))
    assert(e.bonus['special_bonus_unique_zeus_6'] == '-20%',
        'and the conditional row is a REDUCTION, which is what makes the '
        .. 'unfolded read an overstatement')
    local _, bot = rf.load('tests/fixtures/f_230952_zuus_ult_hoard.lua', 'npc_dota_hero_zuus')
    local arc = bot:GetAbilityByName('zuus_arc_lightning')
    assert(arc:GetCooldown() == 1.6,
        'the served read is the unfolded base, got ' .. tostring(arc:GetCooldown()))
end

-- ===================================================================
-- 9.  The THIRD batch -- and the residue turns out to be empty but for one.
--
-- Sections 4, 7 and 8 each closed a key and left "what is still unserved" as a
-- number.  A number invites the reading "a queue, work it off".  It is not one:
-- the six `Ability*` keys still on the generic `^Get` default fail for THREE
-- disjoint reasons, and five of the six cannot be served at all.
--
--   AbilityModifierSupportValue  308 handles  no getter exists in the bot API
--   AbilityChargeRestoreTime      51 handles  no getter exists in the bot API
--   AbilityChannelTime            80 handles  GetChannelTime, 0 focus callers
--   AbilityDuration               56 handles  GetDuration, 0 focus callers
--   AbilityCharges                51 handles  GetCurrentCharges is item-only
--   AbilityDamage                 29 handles  GetAbilityDamage -- BOTH halves
--
-- Only the last one has both a getter and a caller among the five heroes the
-- loader specs, and serving it moves no read at all: the one focus ability that
-- declares the key is axe_berserkers_call at `0 0 0 0`, and the focus files that
-- call the getter call it on abilities that declare nothing.  What changes is
-- the REASON the 0 comes back, which is load-bearing for `lionqdmg` and
-- `zusboltcap` -- both of them are built on "the shipped read is a hard 0", and
-- until now a fixture-driven reading of that 0 came out of mock/bot_api.lua's
-- generic default rather than out of the game's KV.
--
-- 9c is the ratchet that matters: it fires the day a focus hero gains a non-zero
-- AbilityDamage, and it names the three ids that must be re-read then.

local RESIDUE = {
    -- key, corpus handles floor, which of the three reasons
    { 'AbilityModifierSupportValue', 308, 'no-getter' },
    { 'AbilityChannelTime',           80, 'no-focus-caller' },
    { 'AbilityDuration',              56, 'no-focus-caller' },
    { 'AbilityCharges',               51, 'no-focus-caller' },
    { 'AbilityChargeRestoreTime',     51, 'no-getter' },
    { 'AbilityDamage',                29, 'served' },
}

local FOCUS = { 'axe', 'zuus', 'skeleton_king', 'lion', 'crystal_maiden' }

--- One pass over the corpus counting the residual keys, so the table above is a
--- measurement rather than a caption.  Same corpus and same shape as section 4.
local cached_residue
local function residue()
    if cached_residue ~= nil then return cached_residue end
    local c = {}
    for _, row in ipairs(RESIDUE) do c[row[1]] = 0 end
    for _, f in ipairs(corpus_files()) do
        local ok, fx = pcall(dofile, f)
        if ok and type(fx) == 'table' and fx.units then
            for _, u in ipairs(fx.units) do
                local short = tostring(u.name):gsub('^npc_dota_hero_', '')
                if shapes.SHAPES[short] ~= nil then
                    for _, a in ipairs(u.abilities or {}) do
                        for _, row in ipairs(RESIDUE) do
                            if ladder(short, a.name, row[1]) then
                                c[row[1]] = c[row[1]] + 1
                            end
                        end
                    end
                end
            end
        end
    end
    cached_residue = c
    return c
end

local cached_bots_src
local function bots_src()
    if cached_bots_src ~= nil then return cached_bots_src end
    local out = {}
    local p = assert(io.popen('ls bots/BotLib/hero_*.lua bots/FunLib/*.lua bots/*.lua 2>/dev/null'))
    for l in p:lines() do
        local fh = io.open(l, 'r')
        if fh then out[l] = fh:read('*a'); fh:close() end
    end
    p:close()
    cached_bots_src = out
    return out
end

--- Call sites of one getter across shipped Lua, split into focus-hero files and
--- the rest.  Comment lines are dropped: hero_sniper.lua:244 documents
--- GetCurrentCharges' item-only rule in prose and would otherwise be counted as
--- a caller of the thing it says nobody can call.
local function call_sites(sGetter)
    local focus, other = {}, {}
    for path, src in pairs(bots_src()) do
        local isfocus = false
        for _, h in ipairs(FOCUS) do
            if path == 'bots/BotLib/hero_' .. h .. '.lua' then isfocus = true end
        end
        for line in src:gmatch('[^\n]+') do
            local code = line:match('^(.-)%-%-') or line
            if code:find(':' .. sGetter .. '%(') then
                if isfocus then focus[#focus + 1] = path else other[#other + 1] = path end
            end
        end
    end
    return focus, other
end

tests['9a: the residual key population is measured, not asserted'] = function()
    local c = residue()
    for _, row in ipairs(RESIDUE) do
        -- A floor, never `==`: the corpus grows every time a fixture lands, and
        -- a ceiling written as equality is the GH #457 shape.  A count that
        -- FELL means a key left the snapshot -- re-derive, do not lower this.
        assert(c[row[1]] >= row[2], row[1] .. ' handles fell to ' .. c[row[1]]
            .. ', floor is ' .. row[2] .. ' -- a residual key left the snapshot, '
            .. 'which changes section 9 rather than this number')
    end
    -- And the scan is not vacuous: a broken ladder reader would zero every row
    -- above and each floor would then fail, but a broken CORPUS walk would zero
    -- them silently before any floor was reached.
    assert(#corpus_files() >= 100, 'corpus files, got ' .. #corpus_files())
end

tests['9b: GetAbilityDamage is served off the KV, and reads 0 for two reasons'] = function()
    local _, _, cull, heroes = axe_cull()
    -- (i) declared, and declared ZERO: axe_berserkers_call carries the field at
    -- `0 0 0 0`.  Culling Blade carries none.  Both answer 0.
    assert(ladder('axe', 'axe_berserkers_call', 'AbilityDamage') ~= nil,
        'axe_berserkers_call must still declare AbilityDamage -- if it stopped, '
        .. 'this section lost the only served handle in the corpus')
    assert(ladder('axe', 'axe_culling_blade', 'AbilityDamage') == nil,
        'Culling Blade must still declare no AbilityDamage')
    assert(cull:GetAbilityDamage() == 0,
        'Culling Blade, got ' .. tostring(cull:GetAbilityDamage()))
    local call = heroes['npc_dota_hero_axe']:GetAbilityByName('axe_berserkers_call')
    assert(call:GetAbilityDamage() == 0,
        "Berserker's Call, got " .. tostring(call:GetAbilityDamage()))
    -- (ii) And the 0 is now this loader's answer rather than
    -- mock/bot_api.lua's generic `^Get` -- which is the entire content of this
    -- landing, since the VALUE did not move.  The two are indistinguishable from
    -- the read, so the check is deliberately white-box: a reader must actually
    -- be installed on the handle.  Without this the section would pass on a
    -- loader that never learned the key.
    for _, pair in ipairs({ { cull, CULL }, { call, 'axe_berserkers_call' } }) do
        local spec = rawget(pair[1], '__spec')
        assert(type(spec) == 'table' and type(spec.GetAbilityDamage) == 'function',
            pair[2] .. ' has no GetAbilityDamage installed -- its 0 is the '
            .. 'generic default again, which is the state this section ended')
    end
end

tests['9c: RATCHET -- no focus hero declares a non-zero AbilityDamage'] = function()
    -- Two independently generated sources have to agree here, and they are built
    -- from different input: this snapshot covers the five focus heroes'
    -- abilities, tests/mock/ability_damage.lua covers all 128 shipped heroes and
    -- lists only the NON-zero declarations.
    local nonzero = assert(dofile('tests/mock/ability_damage.lua').NONZERO,
        'ability_damage.lua has no NONZERO table')
    local n = 0
    for _ in pairs(nonzero) do n = n + 1 end
    assert(n >= 16, 'the independent census must be populated, got ' .. n
        .. ' heroes -- an empty one would agree with anything')
    for _, h in ipairs(FOCUS) do
        assert(nonzero[h] == nil, h .. ' now declares a NON-ZERO AbilityDamage. '
            .. 'This is not a test bug and must not be relaxed: X.GetImpaleKillDamage '
            .. '(`lionqdmg`) and X.GetBoltKillHealthCap (`zusboltcap`) are both '
            .. 'built on that read being a hard 0, and `zusboltdom` switches on '
            .. "the CAP'S VALUE -- a non-zero cap makes it a no-op BY DESIGN. "
            .. 'Re-read all three before touching this line.')
    end
    -- The same statement taken off this snapshot rather than off that census.
    for _, h in ipairs(FOCUS) do
        for ab in pairs(shapes.SHAPES[h]) do
            local steps = ladder(h, ab, 'AbilityDamage')
            if steps ~= nil then
                for i, v in ipairs(steps) do
                    assert(v == 0, h .. '/' .. ab .. ' step ' .. i .. ' = ' .. v
                        .. ' -- see the message above')
                end
            end
        end
    end
end

tests['9d: the four refused keys are refused for a REASON, and it is checked'] = function()
    local api = io.open('docs/BOT_API_REFERENCE.md', 'r')
    local doc = assert(api, 'docs/BOT_API_REFERENCE.md'):read('*a')
    api:close()
    -- Two of them have no reader at all.  Named negatively on purpose: the day
    -- the engine grows one, this line is what says "now it can be served".
    assert(doc:find('GetAbilityDamage', 1, true),
        'the API reference must still document the getter this section serves '
        .. '-- otherwise the two negatives below prove nothing about the doc')
    for _, g in ipairs({ 'GetChargeRestoreTime', 'GetModifierSupportValue' }) do
        assert(not doc:find(g, 1, true), g .. ' now appears in the API reference '
            .. '-- AbilityChargeRestoreTime / AbilityModifierSupportValue became '
            .. 'reachable, re-price them')
    end
    -- Two have a getter and no caller among the five heroes this loader specs.
    for _, g in ipairs({ 'GetChannelTime', 'GetDuration' }) do
        local focus, other = call_sites(g)
        assert(#other >= 4, g .. ' call sites outside the focus five, got '
            .. #other .. ' -- an empty scan would satisfy the next assert for '
            .. 'the wrong reason')
        assert(#focus == 0, g .. ' now has a focus-hero caller (' ..
            table.concat(focus, ', ') .. ') -- wiring it stopped being a dead '
            .. 'reader, serve it off the snapshot')
    end
    -- And the charge getter is item-only, which is a harder wall than "no
    -- caller": AbilityCharges is KV, GetCurrentCharges is per-frame state, so
    -- the snapshot could not answer it even for a hero that asked.
    local focus_ch = call_sites('GetCurrentCharges')
    assert(#focus_ch == 0, 'a focus hero now calls GetCurrentCharges on a handle '
        .. '-- check whether it is an item or an ability before serving anything')
end

return tests

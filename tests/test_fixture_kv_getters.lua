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
--   * AbilityCastPoint and AbilityCooldown are still on the generic default.
--     Deliberate: one small batch at a time, each with its own measurement of
--     what it turns red.  Section 4 counts the residue so it is a number and
--     not a habit.
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

tests['4e: recorded -- the residue still on the generic default'] = function()
    local c = census()
    -- NOT served this round, on purpose.  These two are the next small batch;
    -- the numbers are here so that is a decision with a size, not a habit.
    assert(c.cast_point > 0, 'AbilityCastPoint handles still unserved, got ' .. c.cast_point)
    assert(c.cooldown > 0, 'AbilityCooldown handles still unserved, got ' .. c.cooldown)
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

return tests

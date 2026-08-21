-- [bug] Absolute hit points compared against a fraction: the units-mismatch
-- class, and the gated repair of its one reachable member.
--
-- WHAT THE DEFECT IS
-- ------------------
-- `ability_item_usage_generic.lua` buyback path 1 asked
--     if ancient ~= nil and ancient:GetHealth() < 0.8 then
-- GetHealth() returns HIT POINTS. An ancient carries thousands of them, so the
-- test is false for every ancient that is still standing -- it can only pass at
-- hp <= 0, by which time the game is over. The branch is dead code.
--
-- It is the expensive one of the three to lose. Paths 2 and 3 sit under
-- `if nFullRespawnTime < 60 then return end`; path 1 is the only automatic
-- buyback the tree can reach at all, and the state it exists for -- "they are
-- hitting our ancient, more than one of them, nobody of ours is home, and I
-- have 20+ seconds left dead" -- is the state where a buyback decides the game.
--
-- THE INTENDED FORM IS NOT A GUESS
-- --------------------------------
-- The same predicate, about the same object, with the same 0.8 literal, is
-- already written correctly in the shipped tree:
--     mode_roshan_generic.lua:46   J.GetHP(GetAncient(bot:GetTeam())) < 0.8
-- That call site also disposes of the only implementation worry: J.GetHP reads
-- the un-hooked OriginalGet* getters for own-team units, and it has been
-- running against the ancient every frame of roshan mode all along.
--
-- WHY THE REPAIR IS GATED AND WHY IT IS NOT IN test_set.md
-- --------------------------------------------------------
-- Fixing it does not restore behaviour, it ADDS behaviour, so per the standing
-- rule it ships dark behind `bbancient` and the shipped default stays
-- byte-identical (asserted below, both directions).
--
-- Validating it is the part this project cannot currently do, and that fact is
-- structural rather than a property of this rule. `tools/batch_test/soak/
-- soak_loop.sh` runs a referee that fires `dota_dev forcewin` at SOAK_CAP_MIN
-- (10 game-minutes): every recorded game is guillotined before a siege, and the
-- winner is then overridden with the economic leader. So no game we have ever
-- bought contains an ancient under attack. The archive agrees -- section 4
-- measures it: 58 ancient snapshots, 51 fixtures, 6 timelines, EVERY ONE at
-- hp = 1.0. The domain is not rare here, it is untouched.
--
-- That is a fourth disposition, distinct from the three the team already names.
-- It is not "never arm" (the rule is right), not DOMAIN-NOT-REACHED (the domain
-- is live in real turbo games, which do end by an ancient dying), and not
-- DOMAIN-REACHED-BUT-VANISHING (the density is not small, it is zero BY
-- CONSTRUCTION OF OUR HARNESS). Call it HARNESS-BLIND: no wave, no arm, no
-- test_set slot, because no wave we can buy could answer condition (a).
--
-- The acceptance below is therefore source-level and frame-level, on the model
-- of test_retreat_priority_order.lua: a real frame proves the mismatch is real
-- (the two readings of the SAME ancient differ by three orders of magnitude)
-- and proves the shipped branch cannot fire at ANY live hp; the hurt-ancient
-- frames are ANNOTATED, and are labelled as such rather than passed off as
-- observations.

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')

local tests = {}

-- A real frame that carries the building table (and therefore both ancients).
local FRAME = 'tests/fixtures/f_260819_122930_lina_landed_dead.lua'

local function read_file(path)
    local fh = assert(io.open(path, 'r'), 'cannot open ' .. path)
    local src = fh:read('*a')
    fh:close()
    return src
end

-- Load a real frame and hand back J plus the subject's own ancient.
local function own_ancient(armed_ids, turbo)
    local J, bot = rf.load(FRAME)
    local armed = {}
    for _, id in ipairs(armed_ids or {}) do armed[id] = true end
    J.IsSoakCandidate = function(id) return armed[id] == true end
    J.IsModeTurbo = function() return turbo ~= false end
    local ancient = GetAncient(bot:GetTeam())  -- luacheck: ignore
    assert(ancient ~= nil, 'fixture supplied no ancient for the subject team')
    return J, ancient
end

-- Re-point a unit's four health getters. Used only to ANNOTATE a frame into a
-- state our archive does not contain; every call site below says so.
local function set_hp(unit, cur, max)
    unit.GetHealth = function() return cur end
    unit.GetMaxHealth = function() return max end
    unit.OriginalGetHealth = function() return cur end
    unit.OriginalGetMaxHealth = function() return max end
end

-- ---------------------------------------------------------------------------
-- 1. [real frame] the mismatch is real, on an ancient nobody annotated.

tests['[real frame] the two readings of one ancient differ by 1000x'] = function()
    local J, ancient = own_ancient({}, true)
    assert(ancient:GetHealth() == 1000,
        'expected the loader\'s absolute hp scale, got ' .. tostring(ancient:GetHealth()))
    assert(J.GetHP(ancient) == 1.0,
        'expected the fractional read to be 1.0, got ' .. tostring(J.GetHP(ancient)))
    -- The literal 0.8 can only have meant one of these two, and only one of
    -- them can ever be below it.
    assert(ancient:GetHealth() > 0.8, 'absolute read is already below the literal')
    assert(J.GetHP(ancient) <= 1.0, 'fractional read is out of range')
end

-- ---------------------------------------------------------------------------
-- 2. [dead branch] the shipped test is false at EVERY live hp, not merely at
--    the hp this frame happens to carry. 1 hit point is the lowest an alive
--    unit can hold, and the shipped form is still false there.

tests['[dead branch] shipped predicate is false down to 1 hit point'] = function()
    local J, ancient = own_ancient({}, true)
    for _, hp in ipairs({ 4500, 1000, 100, 10, 1 }) do
        set_hp(ancient, hp, 4500)     -- ANNOTATED: our archive holds none of these
        assert(J.IsAncientBadlyHurt(ancient) == false,
            'shipped form fired at ' .. hp .. ' hp; it is supposed to be unreachable')
    end
    -- ... and it "passes" only once the ancient is already gone.
    set_hp(ancient, 0, 4500)
    assert(J.IsAncientBadlyHurt(ancient) == true,
        'the shipped form should pass at 0 hp -- i.e. only after the game is lost')
end

-- ---------------------------------------------------------------------------
-- 3. [gate] armed, the repair fires on the states the rule was written for;
--    unarmed, it is the shipped expression to the letter.

tests['[gate] armed in turbo, the fraction decides'] = function()
    local J, ancient = own_ancient({ 'bbancient' }, true)
    -- ANNOTATED frames: 79% and 81% of a 4500-hp ancient.
    set_hp(ancient, 3555, 4500)
    assert(J.IsAncientBadlyHurt(ancient) == true, 'armed gate missed a 79% ancient')
    set_hp(ancient, 3645, 4500)
    assert(J.IsAncientBadlyHurt(ancient) == false, 'armed gate fired on an 81% ancient')
end

tests['[gate] unarmed is byte-identical to the shipped branch'] = function()
    local J, ancient = own_ancient({}, true)
    set_hp(ancient, 3555, 4500)   -- ANNOTATED
    assert(J.IsAncientBadlyHurt(ancient) == false,
        'unarmed behaviour changed -- the shipped default must not move')
    -- ...and neither does arming some OTHER candidate.
    local J2, ancient2 = own_ancient({ 'capmono', 'roamstale' }, true)
    set_hp(ancient2, 3555, 4500)
    assert(J2.IsAncientBadlyHurt(ancient2) == false, 'an unrelated id armed this gate')
end

tests['[gate] outside turbo the repair stays off'] = function()
    local J, ancient = own_ancient({ 'bbancient' }, false)
    set_hp(ancient, 3555, 4500)   -- ANNOTATED
    assert(J.IsAncientBadlyHurt(ancient) == false, 'gate escaped the turbo condition')
end

tests['[gate] a nil ancient is false, not an error'] = function()
    local J = own_ancient({ 'bbancient' }, true)
    assert(J.IsAncientBadlyHurt(nil) == false, 'nil ancient must not fire or throw')
end

-- ---------------------------------------------------------------------------
-- 4. [corpus] why no wave can answer condition (a): the archive contains no
--    hurt ancient at all. Counted here rather than quoted, so it self-updates
--    into a failure the day a fixture with a besieged ancient lands -- which is
--    exactly the day this gate becomes armable.

tests['[corpus] every ancient snapshot in the archive is at full health'] = function()
    local lfs_ok, dirs = pcall(function()
        local names, ph = {}, io.popen('ls tests/fixtures/*.lua 2>/dev/null')
        if ph == nil then return nil end
        for line in ph:lines() do names[#names + 1] = line end
        ph:close()
        return names
    end)
    assert(lfs_ok and dirs ~= nil and #dirs > 0, 'could not enumerate tests/fixtures')

    local snapshots, files_with, timelines, below = 0, 0, {}, 0
    for _, path in ipairs(dirs) do
        local src = read_file(path)
        local seen_here = false
        for hp in src:gmatch("name = 'ancient'[^}]-hp = ([%d%.]+)") do
            snapshots = snapshots + 1
            seen_here = true
            if tonumber(hp) < 0.8 then below = below + 1 end
        end
        if seen_here then
            files_with = files_with + 1
            local tl = src:match('tl_(%d+)')
            if tl ~= nil then timelines[tl] = true end
        end
    end
    local n_tl = 0
    for _ in pairs(timelines) do n_tl = n_tl + 1 end

    -- COUNTED, NOT QUOTED, and the first draft of this test got it wrong in a
    -- way worth leaving a scar for: 51 fixtures carry a `buildings` block but
    -- only 29 of those tables actually include the ancient (61 merely mention
    -- the word). Two ancients per such fixture => 58 snapshots. "Has buildings"
    -- and "has an ancient" are different denominators, and in the other 22 the
    -- loader's GetAncient hands back nil.
    assert(snapshots >= 58, 'ancient snapshots fell below the recorded 58: ' .. snapshots)
    assert(files_with >= 29, 'fixtures carrying an ancient fell below 29: ' .. files_with)
    assert(n_tl >= 5, 'timelines carrying an ancient fell below 5: ' .. n_tl)
    -- THE point. When this flips, HARNESS-BLIND is over for this gate and
    -- `bbancient` can be proposed for test_set.md with real frames behind it.
    assert(below == 0,
        below .. ' ancient snapshot(s) are now under 80% -- `bbancient` has a domain; '
        .. 'see tests/test_ancient_hp_unit.lua section 4 and propose it for test_set.md')
end

-- ---------------------------------------------------------------------------
-- 5. [class] the units-mismatch class itself, pinned so a third member cannot
--    arrive unnoticed. The scan is mechanical: a GetHealth() call compared
--    DIRECTLY against a literal in (0, 1]. The correct idioms are excluded by
--    construction, not by whitelist -- `x:GetHealth() <= 0.65 * y:GetMaxHealth()`
--    scales the fraction by a max-health term, and `dmg / x:GetHealth() > 0.2`
--    is a ratio, so neither is a direct comparison against the literal.

local CLASS = {
    -- The member repaired by this file. It is listed with the REPAIRED text:
    -- the raw comparison now lives in J.IsAncientBadlyHurt.
    { file = 'bots/FunLib/jmz_func.lua',
      text = 'return hAncient:GetHealth() < 0.8',
      why = 'buyback path 1; the shipped default preserved verbatim behind `bbancient`.' },
    -- The second member, hero_tiny.lua X.ConsiderTreeGrab's
    -- `and bot:GetHealth() > 0.15`, is GONE as of GH #88 -- deleted, not
    -- repaired. It failed the permissive way (true on every frame it could be
    -- evaluated in), so deleting it is behaviour-equivalent, while repairing it
    -- to `J.GetHP(bot) > 0.15` would be a new veto on a hero the soak farm
    -- cannot draft and therefore cannot buy condition (a) evidence for. The
    -- reasoning, the decision at 1 hp, and a tripwire on the draft pool live in
    -- tests/test_tiny_treegrab_hp_noop.lua; that file also refuses a silent
    -- re-tightening of the same function. The census below now expects ONE
    -- site, which is the repaired one above.
}

tests['[class] every known units-mismatch site is exactly where recorded'] = function()
    for _, m in ipairs(CLASS) do
        local src = read_file(m.file)
        assert(src:find(m.text, 1, true),
            m.file .. ' no longer contains: ' .. m.text)
    end
end

tests['[class] no third site has appeared in bots/'] = function()
    local ph = assert(io.popen("ls bots/*.lua bots/*/*.lua bots/*/*/*.lua 2>/dev/null"))
    local files = {}
    for line in ph:lines() do files[#files + 1] = line end
    ph:close()
    assert(#files > 100, 'the bots/ enumeration collapsed: ' .. #files .. ' files')

    local found = {}
    for _, path in ipairs(files) do
        for line in read_file(path):gmatch('[^\n]+') do
            -- Comment lines are prose ABOUT the defect (this repair added
            -- several); they are not code and must not be counted.
            if not line:match('^%s*%-%-') then
                local head, lit, rest = line:match('()GetHealth%(%)%s*[<>]=?%s*([%d%.]+)(.*)')
                local v = tonumber(lit or '')
                if v ~= nil and v > 0 and v <= 1
                    -- `x <= 0.65 * y:GetMaxHealth()` scales the fraction by a
                    -- max-health term: correct idiom, not a direct comparison.
                    and not rest:match('^%s*%*')
                    -- `dmg / x:GetHealth() > 0.2` is a RATIO -- the GetHealth
                    -- call is the divisor, so the literal is being compared
                    -- against a quotient and the units are already fractional.
                    and not line:sub(1, head - 1):match('/%s*[%w_%.%(%)%[%]]*:?$')
                then
                    found[#found + 1] = path .. ': ' .. line:gsub('^%s+', '')
                end
            end
        end
    end
    assert(#found == #CLASS,
        'units-mismatch site count moved from ' .. #CLASS .. ' to ' .. #found
        .. ':\n  ' .. table.concat(found, '\n  '))
end

return tests

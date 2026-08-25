-- [hero] axis `VALSHAPE` -- what a GetSpecialValue read ANSWERS, not whether
-- its key exists.  Source ratchet + the machine check GH #162's own repair was
-- still missing.  ZERO behaviour change: this file adds no gate and touches no
-- bot logic; the focus five hold no defect on this axis today, and that is the
-- finding it freezes.
--
-- THE AXIS
--
-- GH #162 built a ruler that asks one question of a `GetSpecialValue*` read:
-- is the key in the owning hero's KV at all?  A present key comes back clean.
-- Two shapes slip through that question and land on the same silent number the
-- `0DMG` / `0SELL` family lands on -- no error, nothing a bot-side print could
-- show (AGENTS.md):
--
--   * LOSSY-INT -- the key is present and its value is FRACTIONAL, and the call
--     site reads it with GetSpecialValueInt.  `0.8` is not 0.8 there.  Below
--     0.5 the read collapses whichever way the engine casts (truncate or
--     round); above it, it is merely lossy, and the direction of the loss
--     depends on the cast, which is why this file never claims a magnitude.
--   * NO-BASE -- the key is present but its KV entry carries NO base `value`,
--     only conditional `special_bonus_*` entries.  The read is 0 for every
--     caster that does not satisfy the condition.
--
-- MEASURED (tools/agent/special_value_shape_census.py, 2026-08-25, 700 reads
-- over 128 hero files): 7 LOSSY-INT (2 of them collapsing: ursa hop_duration
-- 0.25, snapfire jump_duration 0.484), 4 NO-BASE, 25 MISSING (that last bucket
-- is #162's axis, unchanged).  IN THE FOCUS FIVE: zero LOSSY-INT, and the only
-- NO-BASE read is the one this tree makes on purpose -- see §2.  The other
-- hero files are outside this stream's polish mandate (the #168 convention:
-- each needs its own reasoning and its own id) and are reported on the issue.
--
-- WHY THIS FILE EXISTS EVEN THOUGH THE AXIS IS EMPTY HERE
--
-- Because "empty" is a measurement with an expiry date.  A patch that turns one
-- of these 22 focus-five reads fractional, or strips a base value off a key,
-- produces no error and no behavioural signal we could see -- exactly the
-- failure mode #162 spent a round finding by hand.  The ratchet turns the next
-- one red at desk time.
--
-- AND BECAUSE OF §2, WHICH IS NOT A RATCHET BUT A CHECK ON OUR OWN REPAIR
--
-- GH #162 moved Lion's splash read from `splash_radius_scepter` (absent) to
-- `splash_radius`.  The key census can only say the new key is PRESENT.  It
-- cannot tell "we fixed it" from "we swapped one silent zero for another",
-- because the new key's entry has no base value at all.  Here it is read
-- against the KV shape: base = nil, special_bonus_scepter = 325 -- 0 without a
-- scepter, 325 with one -- and the consumer sits inside `if bot:HasScepter()`.
-- So the repair holds, and now something says so when a patch changes it.
-- (tests/test_lion_r_splash_radius_key.lua §5 asserts the key's PRESENCE and
-- states this shape in prose; the prose was never machine-checked.)
--
-- ⚠️ LIMITS -- what a green run here does NOT say
--
--   1. ONE-DIRECTIONAL, like every census in this family.  A read is judged
--      only when EVERY ability of that hero declaring the key has the bad
--      shape; the script does not resolve which ability a Lua handle points
--      at.  `duration` is fractional on axe_berserkers_call and integral on
--      axe_battle_hunger, so hero_axe.lua's Int read of it is UNRESOLVED here
--      even though the file's own binding settles it (§4 pins that case).
--      Findings are real; SILENCE IS NOT A CLEAN BILL OF HEALTH.
--   2. Nothing here is a claim about a BRANCH.  A truncated or zeroed value can
--      widen a branch as easily as kill it (the `0DMG` lesson: the same 0
--      widens FindAoELocation's nMaxHealth and kills J.WillMagicKillTarget).
--   3. The snapshot is the focus five only.  The other 123 hero files are
--      covered by the Python census, which nothing in CI runs.
--   4. This reads SOURCE, not a frame.  No fixture can see any of it: the mock
--      answers 0 for every GetSpecialValue key alike (test_lion_r_splash_radius
--      _key.lua §4 measured that), which is the same reason the axis needs a
--      desk ruler in the first place.

package.path = 'tests/?.lua;' .. package.path

local SNAPSHOT = 'tests/mock/special_value_shapes.lua'
local BOTLIB   = 'bots/BotLib/'

-- AGENTS.md's five polish targets, by hero unit short name.
local FOCUS_FIVE = { 'axe', 'zuus', 'skeleton_king', 'lion', 'crystal_maiden' }

-- talentN:GetSpecialValueInt('value') -- talents are special_bonus_* abilities
-- in npc_abilities.txt, not in the hero KV.  Same exemption the key census makes.
local TALENT_KEYS = { ['value'] = true }

-- The single NO-BASE read this tree makes on purpose, and the gate it rides.
local LION_NOBASE_KEY = 'splash_radius'
local LION_STALE_KEY  = 'splash_radius_scepter'
local LION_CAND_ID    = 'lionsplash'

local function read_file(sPath)
    local fh = assert(io.open(sPath, 'r'), 'cannot open ' .. sPath)
    local s = fh:read('*a'); fh:close()
    return s
end

--- Strip Lua line comments BEFORE keys are picked out.  The block above names
--- both lion keys while explaining them; a parser that reads prose reports the
--- prose (GH #136's first census made exactly that mistake), so the census and
--- its own self-test share this one function.
local function strip_comments(src)
    return (src:gsub('%-%-[^\n]*', ''))
end

--- [{ line = n, kind = 'Int'|'Float', key = s }] for one source string.
local function reads_in(src)
    local out = {}
    local n = 0
    for line in (strip_comments(src) .. '\n'):gmatch('([^\n]*)\n') do
        n = n + 1
        for sKind, sKey in line:gmatch("GetSpecialValue(%a+)%s*%(%s*['\"]([%w_]+)['\"]") do
            out[#out + 1] = { line = n, kind = sKind, key = sKey }
        end
    end
    return out
end

--- Every numeric per-level token of a KV value string ('140 220 300' -> {...}).
local function numbers(sValue)
    local out = {}
    for sTok in tostring(sValue):gmatch('[^%s]+') do
        local n = tonumber((sTok:gsub('^%+', '')))
        if n ~= nil then out[#out + 1] = n end
    end
    return out
end

local function is_fractional(n)
    local d = n - math.floor(n + 0.5)
    return d > 1e-9 or d < -1e-9
end

--- THE VERDICT, factored out so it has somewhere to be tested (§4).
--- tShapes is one hero's { ability -> key -> { base = s?, bonus = {} } }.
--- Returns 'MISSING' | 'NO-BASE' | 'LOSSY-INT' | 'LOSSY-INT/COLLAPSE' | 'OK'.
local function classify(sKind, sKey, tShapes)
    local tHolders = {}
    for _, tKeys in pairs(tShapes) do
        if tKeys[sKey] ~= nil then tHolders[#tHolders + 1] = tKeys[sKey] end
    end
    if #tHolders == 0 then return 'MISSING' end

    local bAnyBase = false
    for _, tEntry in ipairs(tHolders) do
        if tEntry.base ~= nil then bAnyBase = true end
    end
    if not bAnyBase then return 'NO-BASE' end

    if sKind == 'Int' then
        local nLevels, bAllFrac, bAllTiny = 0, true, true
        for _, tEntry in ipairs(tHolders) do
            for _, n in ipairs(numbers(tEntry.base or '')) do
                nLevels = nLevels + 1
                if not is_fractional(n) then bAllFrac = false end
                if not (n > 0 and n < 0.5) then bAllTiny = false end
            end
        end
        if nLevels > 0 and bAllFrac then
            if bAllTiny then return 'LOSSY-INT/COLLAPSE' end
            return 'LOSSY-INT'
        end
    end
    return 'OK'
end

local tests = {}

-- ---------------------------------------------------------------------------
-- 1. The ratchet: no focus-five Int read lands on a value that is fractional
--    on every ability that declares it.

tests['[hero] no focus-five GetSpecialValueInt read is proven lossy'] = function()
    local tShapes = assert(dofile(SNAPSHOT).SHAPES, 'no SHAPES in the snapshot')
    local tOffenders = {}
    for _, sHero in ipairs(FOCUS_FIVE) do
        local tHero = assert(tShapes[sHero], 'no snapshot for ' .. sHero)
        for _, tRead in ipairs(reads_in(read_file(BOTLIB .. 'hero_' .. sHero .. '.lua'))) do
            if not TALENT_KEYS[tRead.key] then
                local sVerdict = classify(tRead.kind, tRead.key, tHero)
                if sVerdict == 'LOSSY-INT' or sVerdict == 'LOSSY-INT/COLLAPSE' then
                    tOffenders[#tOffenders + 1] = string.format(
                        'hero_%s.lua:%d %s(%s) -> %s', sHero, tRead.line, tRead.kind,
                        tRead.key, sVerdict)
                end
            end
        end
    end
    assert(#tOffenders == 0, 'GetSpecialValueInt on a fractional value: '
        .. table.concat(tOffenders, '; ') .. ' -- an Int read of a fractional KV value '
        .. 'silently truncates or rounds; read it with GetSpecialValueFloat, or state '
        .. 'why the integer is the intended quantity')
end

tests['[hero] the only NO-BASE read in the focus five is the registered one'] = function()
    local tShapes = assert(dofile(SNAPSHOT).SHAPES)
    local tFound = {}
    for _, sHero in ipairs(FOCUS_FIVE) do
        for _, tRead in ipairs(reads_in(read_file(BOTLIB .. 'hero_' .. sHero .. '.lua'))) do
            if not TALENT_KEYS[tRead.key]
                and classify(tRead.kind, tRead.key, tShapes[sHero]) == 'NO-BASE'
            then
                tFound[#tFound + 1] = sHero .. ':' .. tRead.key
            end
        end
    end
    assert(#tFound == 1, 'expected exactly one registered NO-BASE read, got '
        .. #tFound .. ' (' .. table.concat(tFound, ', ') .. ') -- a key with no base value '
        .. 'answers 0 unless its conditional bonus applies, so a new one needs a call '
        .. 'site that already checks that condition, or it is a silent zero')
    assert(tFound[1] == 'lion:' .. LION_NOBASE_KEY, 'unexpected NO-BASE read ' .. tFound[1])
end

-- ---------------------------------------------------------------------------
-- 2. GH #162's repair, checked against the value rather than the key name.

tests['[hero] lion splash_radius is scepter-only by SHAPE, not merely present'] = function()
    local tLion = assert(dofile(SNAPSHOT).SHAPES['lion'], 'no lion snapshot')
    local tFinger = assert(tLion['lion_finger_of_death'], 'no lion_finger_of_death')
    local tEntry = assert(tFinger[LION_NOBASE_KEY], LION_NOBASE_KEY .. ' must be a key of '
        .. 'lion_finger_of_death -- that is what GH #162 moved the read to')

    assert(tEntry.base == nil, LION_NOBASE_KEY .. ' is expected to carry NO base value; '
        .. 'a patch that gave it one changes what the shipped-key-first shape means')
    assert(tEntry.bonus['special_bonus_scepter'] == '325',
        'the scepter bonus is what makes the read nonzero at all; got '
        .. tostring(tEntry.bonus['special_bonus_scepter']))

    -- The stale key is absent -- so the shipped read really is 0 and the gated
    -- leg is the only one that can answer.  (Same fact test_lion_r_splash_radius
    -- _key.lua asserts off the key snapshot; asserted here off a second file so
    -- one bad fetch cannot make both go quiet.)
    assert(tFinger[LION_STALE_KEY] == nil and tLion['lion_impale'][LION_STALE_KEY] == nil,
        LION_STALE_KEY .. ' must not exist -- its absence is the whole of GH #162')
end

tests['[hero] the NO-BASE read sits behind the gate and behind HasScepter'] = function()
    local src = strip_comments(read_file(BOTLIB .. 'hero_lion.lua'))
    local sBody = src:match("function X%.GetAbilityRSplashRadius%(%)(.-)\nend")
    assert(sBody ~= nil, 'X.GetAbilityRSplashRadius not found -- GH #162 moved or renamed it')
    -- Quoted, not bare: a bare find('lionsplash') is satisfied by 'lionsplashX'
    -- too, and a renamed id is exactly the mutation this assertion is here for
    -- (measured -- the first draft of this line let that mutation escape).
    assert(sBody:find("'" .. LION_CAND_ID .. "'", 1, true) ~= nil
        or sBody:find('"' .. LION_CAND_ID .. '"', 1, true) ~= nil,
        'the ' .. LION_NOBASE_KEY .. ' read must stay behind soak candidate ' .. LION_CAND_ID)

    -- The consumer that can be reached at all is scepter-gated; without that,
    -- a NO-BASE key would be a silent zero on the ordinary path.
    local sConsider = src:match("function X%.ConsiderR%(%)(.-)\nend") or src
    assert(sConsider:find('HasScepter', 1, true) ~= nil
        or src:find('HasScepter', 1, true) ~= nil,
        'the splash branch must be reachable only with a scepter')
end

-- ---------------------------------------------------------------------------
-- 3. Snapshot integrity -- a truncated fetch must not read as "all clean".

tests['[hero] the shape snapshot covers all five focus heroes and is not a stub'] = function()
    local tShapes = assert(dofile(SNAPSHOT).SHAPES)
    for _, sHero in ipairs(FOCUS_FIVE) do
        local tHero = assert(tShapes[sHero], 'missing ' .. sHero)
        local nAbilities, nKeys, nBases = 0, 0, 0
        for _, tKeys in pairs(tHero) do
            nAbilities = nAbilities + 1
            for _, tEntry in pairs(tKeys) do
                nKeys = nKeys + 1
                if tEntry.base ~= nil then nBases = nBases + 1 end
            end
        end
        assert(nAbilities >= 4, sHero .. ' has only ' .. nAbilities .. ' abilities in the '
            .. 'snapshot; a half-parsed file would make §1 pass by having nothing to judge')
        assert(nKeys >= 25, sHero .. ' has only ' .. nKeys .. ' keys in the snapshot')
        assert(nBases >= 20, sHero .. ' has only ' .. nBases .. ' keys WITH a base value; '
            .. 'a parser that lost the "value" lines would turn every read NO-BASE')
    end
end

tests['[hero] every focus-five read resolves against the snapshot, or is a known absence'] = function()
    local tShapes = assert(dofile(SNAPSHOT).SHAPES)
    local tUnknown = {}
    for _, sHero in ipairs(FOCUS_FIVE) do
        for _, tRead in ipairs(reads_in(read_file(BOTLIB .. 'hero_' .. sHero .. '.lua'))) do
            if not TALENT_KEYS[tRead.key]
                and classify(tRead.kind, tRead.key, tShapes[sHero]) == 'MISSING'
                and tRead.key ~= LION_STALE_KEY
            then
                tUnknown[#tUnknown + 1] = sHero .. ':' .. tRead.line .. ' ' .. tRead.key
            end
        end
    end
    assert(#tUnknown == 0, 'reads whose key is in no ability of the hero (GH #162 axis, '
        .. 'new offender): ' .. table.concat(tUnknown, ', ') .. ' -- regenerate the '
        .. 'snapshots after a patch (python3 tools/agent/special_value_shape_census.py '
        .. '--snapshot) before treating this as a defect')
end

-- ---------------------------------------------------------------------------
-- 4. The ruler tested on its own: the verdicts, and the two ways it stays quiet.

tests['[hero] classify: the four verdicts'] = function()
    local tShapes = {
        ability_a = {
            frac_only  = { base = '0.25', bonus = {} },
            frac_big   = { base = '2.5 3.5', bonus = {} },
            integral   = { base = '315', bonus = {} },
            no_base    = { base = nil, bonus = { special_bonus_scepter = '325' } },
        },
    }
    assert(classify('Int', 'frac_only', tShapes) == 'LOSSY-INT/COLLAPSE')
    assert(classify('Int', 'frac_big', tShapes) == 'LOSSY-INT')
    assert(classify('Int', 'integral', tShapes) == 'OK')
    assert(classify('Int', 'no_base', tShapes) == 'NO-BASE')
    assert(classify('Int', 'absent', tShapes) == 'MISSING')
    -- A Float read of a fractional value is the CORRECT reader, not a finding.
    assert(classify('Float', 'frac_only', tShapes) == 'OK')
end

tests['[hero] classify: a mixed key is UNRESOLVED, not a finding (the axe duration case)'] = function()
    local tShapes = assert(dofile(SNAPSHOT).SHAPES['axe'])
    -- Real data, not a fixture: axe_berserkers_call/duration is 2.1 2.4 2.7 3.0
    -- and axe_battle_hunger/duration is 12.0.  hero_axe.lua reads `duration`
    -- with Int off abilityW (= sAbilityList[2] = battle hunger), which is
    -- integral -- but this ruler does not resolve handles, so it must answer OK
    -- rather than manufacture a finding out of the OTHER ability's value.
    assert(tShapes['axe_berserkers_call']['duration'].base == '2.1 2.4 2.7 3.0',
        'the fractional half of the mixed case moved; re-read the case before trusting §1')
    assert(tShapes['axe_battle_hunger']['duration'].base == '12.0',
        'the integral half of the mixed case moved')
    assert(classify('Int', 'duration', tShapes) == 'OK',
        'a key that is clean on ANY declaring ability must not be reported')
end

tests['[hero] the reader ignores prose and counts lines'] = function()
    local src = "local a = 1\n-- explains GetSpecialValueInt( 'frac_only' ) in prose\n"
             .. "local x = h:GetSpecialValueInt( 'radius' )\n"
    local tRead = reads_in(src)
    assert(#tRead == 1, 'comment-stripping failed: got ' .. #tRead .. ' reads')
    assert(tRead[1].key == 'radius' and tRead[1].kind == 'Int')
    assert(tRead[1].line == 3, 'line number is wrong: ' .. tRead[1].line)
end

tests['[hero] numbers() survives per-level lists and signed bonuses'] = function()
    local t = numbers('140 220 300 380')
    assert(#t == 4 and t[1] == 140 and t[4] == 380)
    assert(#numbers('') == 0)
    assert(numbers('+85')[1] == 85)
    assert(is_fractional(0.484) and not is_fractional(3.0) and not is_fractional(12))
end

return tests

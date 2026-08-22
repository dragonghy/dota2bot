-- [hero] Lion's t10 talent pair, decided on PAYOFF REACHABILITY.
--
-- THE CHANGE THIS FILE DEFENDS
-- ---------------------------
-- hero_lion.lua's t10 row went {0,10} -> {10,0} on 2026-08-22, i.e. from
--   [1] special_bonus_unique_lion_6      +10 percentage points of Mana Drain slow
-- to
--   [2] special_bonus_movement_speed_20  +20 movement speed.
-- It is a pure-number change: the stream charter lets those ship without a gate,
-- on condition that the reasoning is written into the hero file.  It is, and this
-- file is the machine-checkable half of it.
--
-- THE RULER (the same one that flipped Zeus's t15 and left CM's alone, GH #122)
-- --------------------------------------------------------------------------
-- A talent pair cannot be sized by measuring a domain, because neither side is a
-- gate -- there is no armed/shipped pair of arms to diff.  What CAN be asked is
-- where each payout is COLLECTED, and whether this codebase ever gets there:
--
--   [1] is collected only while X.ConsiderE is channelling Mana Drain ON AN ENEMY
--       HERO.  ConsiderE has four returns and only two of them are enemy heroes:
--       the mana top-up branch takes a CREEP and requires #hEnemyList == 0, and the
--       illusion branch takes an illusion.  Both hero branches sit below
--         if X.IsOtherAbilityFullyCastable() or nSkillLV <= 1 then return 0 end
--       so they are a RESIDUAL action -- Earth Spike, Hex and Finger of Death all
--       have to be unavailable first -- and then they still need an enemy hero
--       within 850u holding more than 200 mana, undisabled, and not killable.
--   [2] is collected on every frame the hero moves.  There is no predicate.
--
-- Section 1 pins that structure from the source, because the whole argument is a
-- statement about ConsiderE's shape rather than about any one frame.  Section 2 is
-- the fixture-corpus illustration.
--
-- HONEST BOUNDS -- READ BEFORE QUOTING ANY NUMBER FROM HERE
--   * The fixture library was cut for OTHER investigations; it is not a sample of
--     turbo play.  Every count in section 2 is an EXISTENCE read, not a density
--     (the stream's standing §Y.2 limit: a desk or fixture read can show EMPTY, it
--     cannot show RARE).  How many enemy-hero drain channels a real game contains
--     is an open corpus question -- queue.json hero-4.
--   * The abandoned side is at its LARGEST single payout exactly when the talent is
--     picked: the shipped build has Mana Drain at rank 4 by hero level 10, where the
--     slow is 30% and [1] would make it 40%.  We give that up on frequency grounds.
--     Section 3 pins the build fact so the honest bound cannot quietly rot.
--   * +20 move speed is measured against a 290 base (datafeed hero_id 26, read
--     2026-08-22) and this hero's pos_4/pos_5 outfit macro carries Arcane Boots
--     (aba_item.lua, item_priest_outfit), so the RELATIVE gain in play is about
--     +6%, not +7%.  The absolute +20 does not shrink; the percentage does.
--   * Nothing here measures how often the slow CHANGES AN OUTCOME once collected.
--     The claim is about reachability only.
--
-- THE t15 ROW WAS EXAMINED IN THE SAME PASS AND DELIBERATELY LEFT ALONE
--   [3] -2s Hex cooldown pays only on a cast that arrives inside the last 2s of a
--   cooldown that the shipped build keeps at rank 1 (24s) until hero level 12 --
--   a narrow band on a continuous quantity, where a corpus zero has to be recorded
--   as UNDERPOWERED, not EMPTY (the lesson from Axe's Culling threshold, GH #115).
--   [4] +15% To Hell and Back amp pays inside two windows -- after a respawn until
--   the next kill or assist, and after a kill/assist while that hero is dead --
--   which the dumper cannot see at all (it does not dump modifiers, GH #27).
--   Neither side is measurable offline and both ultimately buy the same thing (Hex
--   disable: [3] more casts, [4] longer ones), so there is no reachability
--   asymmetry to spend.  Default holds: no flip.  Section 4 pins the build fact the
--   [3] side rests on; section 5 keeps the reasoning in the hero file.

package.path = 'tests/?.lua;' .. package.path

local LION_SRC = 'bots/BotLib/hero_lion.lua'
local LION = 'npc_dota_hero_lion'

-- Recorded 2026-08-22 from https://www.dota2.com/datafeed/herodata?hero_id=26.
-- This test cannot reach the network; these are used only to decide castability.
local Q_MANA = { 90, 110, 130, 150 }   -- lion_impale
local W_MANA = { 110, 140, 170, 200 }  -- lion_voodoo
local R_MANA = { 200, 400, 600 }       -- lion_finger_of_death
local E_CAST_RANGE = 850               -- lion_mana_drain
-- Ability index map of this hero file: 1 Impale, 2 Hex, 3 Mana Drain, 6 Finger.
local IDX_HEX, IDX_DRAIN = 2, 3

local function read_file(path)
    local fh = assert(io.open(path, 'r'), 'cannot open ' .. path)
    local s = fh:read('*a')
    fh:close()
    return s
end

--- The body of one `function X.<name>()` in a source string.
local function function_body(src, name)
    local body = src:match('\nfunction X%.' .. name .. '%b()(.-)\nend\n')
    assert(body, 'X.' .. name .. ' not found in ' .. LION_SRC)
    return body
end

local tests = {}

-- ---------------------------------------------------------------------------
-- 1. Where the +10pp slow can be collected, read out of X.ConsiderE.
--
-- Every claim below is about the SHAPE of the function.  If any of it changes the
-- talent decision has to be redone -- which is exactly what these assertions are
-- for, and why they name the consequence in their messages.

tests['[hero] X.ConsiderE gates both enemy-hero drains behind "no other ability is castable"'] = function()
    local body = function_body(read_file(LION_SRC), 'ConsiderE')

    local gate = body:find('X.IsOtherAbilityFullyCastable() or nSkillLV <= 1 then return 0 end', 1, true)
    assert(gate, 'X.ConsiderE no longer early-returns on '
        .. '`X.IsOtherAbilityFullyCastable() or nSkillLV <= 1`. That guard is the '
        .. 'load-bearing half of the t10 argument: it makes an enemy-hero drain a '
        .. 'RESIDUAL action (Earth Spike, Hex and Finger all unavailable), which is '
        .. 'why the +10pp Mana Drain slow talent was passed over for +20 move speed. '
        .. 'Re-argue the t10 row in hero_lion.lua before landing this.')

    -- The two returns that hand back an enemy hero.  Their Chinese motive strings are
    -- the stable handles here; the surrounding predicates change more often.
    for _, motive in ipairs({ 'E-团战吸篮', 'E-抽篮' }) do
        local at = body:find(motive, 1, true)
        assert(at, 'X.ConsiderE no longer has the "' .. motive .. '" branch; the t10 '
            .. 'reachability argument enumerates the enemy-hero drains by these two '
            .. 'motives, so it has to be re-read.')
        assert(at > gate, 'the "' .. motive .. '" branch of X.ConsiderE now sits ABOVE '
            .. 'the IsOtherAbilityFullyCastable early return. That promotes an '
            .. 'enemy-hero drain from a residual action to a first-class one and '
            .. 'directly strengthens the +10pp Mana Drain slow talent this file '
            .. 'argued against. Re-decide the t10 row.')
    end
end

tests['[hero] the mana top-up branch of X.ConsiderE takes a creep and only with no enemy hero around'] = function()
    local body = function_body(read_file(LION_SRC), 'ConsiderE')
    local at = assert(body:find('E-补篮', 1, true), 'the "E-补篮" branch is gone from X.ConsiderE')
    local head = body:sub(1, at)
    assert(head:find('#hEnemyList == 0', 1, true),
        'the mana top-up branch of X.ConsiderE no longer requires #hEnemyList == 0. '
        .. 'That requirement is why the most common drain in this file cannot collect '
        .. 'a hero slow at all -- there is no hero in range to slow. Re-decide t10.')
    assert(head:find('GetNearbyCreeps', 1, true),
        'the mana top-up branch no longer targets a creep; the t10 argument counts it '
        .. 'as a non-collecting drain on that basis.')
end

tests['[hero] X.ConsiderE has no ally-target branch, so the talent ally half is unreachable'] = function()
    local body = function_body(read_file(LION_SRC), 'ConsiderE')
    -- Mana Drain can feed an ALLY (mana and move speed at 50% rate), and the talent
    -- raises that half too.  This file never uses it, which is why the rationale
    -- block calls the ally half unreachable "either way" -- true for both talents.
    assert(not body:find('hAllyList', 1, true) and not body:find('GetAllies', 1, true),
        'X.ConsiderE now reads an ally list. Mana Drain can target allies, and the '
        .. '+10pp talent raises the ally movement bonus as well as the enemy slow -- '
        .. 'so an ally-drain branch adds a second place where the abandoned t10 talent '
        .. 'would be collected. Re-decide the t10 row in hero_lion.lua.')
end

-- ---------------------------------------------------------------------------
-- 2. The fixture-corpus illustration.
--
-- Deliberately NOT a census equality (GH #106 filed pinning corpus size as an
-- equation as a hazard).  What is asserted is an anti-vacuum floor -- so the scan
-- can never pass by reading nothing -- and the inequality the argument rests on:
-- strictly fewer frames can collect [1] than can collect [2].  Adding fixtures can
-- only make the illustration richer.

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

local function dist(a, b)
    local dx, dy = a.x - b.x, a.y - b.y
    return math.sqrt(dx * dx + dy * dy)
end

local function ability(unit, name)
    for _, a in ipairs(unit.abilities or {}) do
        if a.name == name then return a end
    end
    return nil
end

--- IsFullyCastable, reproduced from the frame: trained, off cooldown, affordable.
local function castable(a, costs, mp)
    if a == nil then return false end
    local lv = a.level or 0
    if lv < 1 then return false end
    if (a.cd or 0) > 0 then return false end
    if costs and mp < costs[lv] then return false end
    return true
end

local function scan()
    local rows = { alive = 0, gate_open = 0, chain = 0, drain_learned = 0, detail = {} }
    for _, path in ipairs(fixture_files()) do
        local ok, fx = pcall(dofile, path)
        if ok and type(fx) == 'table' and type(fx.units) == 'table' then
            for _, me in ipairs(fx.units) do
                if me.name == LION and me.alive then
                    rows.alive = rows.alive + 1
                    local q = ability(me, 'lion_impale')
                    local w = ability(me, 'lion_voodoo')
                    local e = ability(me, 'lion_mana_drain')
                    local r = ability(me, 'lion_finger_of_death')
                    local elv = (e and e.level) or 0
                    if elv >= 1 then rows.drain_learned = rows.drain_learned + 1 end
                    -- X.IsOtherAbilityFullyCastable(): Q or W or R castable.
                    local other = castable(q, Q_MANA, me.mp) or castable(w, W_MANA, me.mp)
                        or castable(r, R_MANA, me.mp)
                    local open = not other
                    if open then rows.gate_open = rows.gate_open + 1 end
                    -- The rest of the chain both hero branches share: drain itself
                    -- castable, rank >= 2, and an enemy hero in cast range holding
                    -- more than 200 mana.  (The ring ignores vision, so it is an
                    -- UPPER bound -- the approximation runs in the safe direction
                    -- for a claim that the chain is hard to reach.)
                    local rich = 0
                    for _, u in ipairs(fx.units) do
                        if u.name:match('^npc_dota_hero_') and u.team ~= me.team and u.alive
                            and dist(u, me) <= E_CAST_RANGE and (u.mp or 0) > 200
                        then
                            rich = rich + 1
                        end
                    end
                    local chain = open and castable(e, nil, me.mp) and elv > 1 and rich >= 1
                    if chain then rows.chain = rows.chain + 1 end
                    rows.detail[#rows.detail + 1] = string.format(
                        '%s t=%.1f herolv=%s drainlv=%d gate_open=%s rich_enemies=%d chain=%s',
                        path:gsub('.*/', ''), fx.time or -1, tostring(me.level), elv,
                        tostring(open), rich, tostring(chain))
                end
            end
        end
    end
    return rows
end

tests['[hero] the fixture library actually contains Lion frames (anti-vacuum)'] = function()
    local rows = scan()
    assert(rows.alive >= 10, 'only ' .. rows.alive .. ' living-Lion frames in '
        .. 'tests/fixtures; this scan is reading almost nothing and any count it '
        .. 'produces is noise. (This is a FLOOR, not the corpus size -- see GH #106.)')
    assert(rows.drain_learned >= 5, 'Mana Drain is learned on only ' .. rows.drain_learned
        .. ' living-Lion frames; the t10 scan has nothing to talk about.')
end

tests['[hero] fewer frames can collect the Mana Drain slow than can collect move speed'] = function()
    local rows = scan()
    assert(rows.chain < rows.alive, 'every living-Lion frame in the library now '
        .. 'satisfies the enemy-hero drain chain (' .. rows.chain .. '/' .. rows.alive
        .. '). That is the one reading that would overturn the t10 argument, which '
        .. 'rests on [1] being collectible on a subset of the frames where [2] is. '
        .. 'Frames:\n  ' .. table.concat(rows.detail, '\n  '))
    -- The gate alone already cuts the field, before the per-target predicates.
    assert(rows.gate_open < rows.alive, 'X.IsOtherAbilityFullyCastable is open on '
        .. 'every living-Lion frame in the library, i.e. Earth Spike, Hex and Finger '
        .. 'are simultaneously unavailable everywhere. Re-read the scan before '
        .. 'trusting any t10 conclusion.')
end

-- ---------------------------------------------------------------------------
-- 3. The build fact the honest bound rests on: Mana Drain is rank 4 at level 10.

--- The shipped ability build as a list of ability indices, level 1..15.
local function shipped_build()
    local src = read_file(LION_SRC)
    local block = src:match('local tAllAbilityBuildList = (%b{})')
    assert(block, 'tAllAbilityBuildList not found in ' .. LION_SRC)
    local builds = {}
    for row in block:gmatch('{([%d,%s]+)}') do
        local order = {}
        for n in row:gmatch('%d+') do order[#order + 1] = tonumber(n) end
        if #order > 0 then builds[#builds + 1] = order end
    end
    assert(#builds >= 1, 'no ability build rows parsed out of ' .. LION_SRC)
    return builds
end

--- Rank of ability index `idx` once `level` points have been spent.
local function rank_at(order, idx, level)
    local n = 0
    for i = 1, math.min(level, #order) do
        if order[i] == idx then n = n + 1 end
    end
    return n
end

tests['[hero] every shipped build has Mana Drain at rank 4 by hero level 10'] = function()
    for i, order in ipairs(shipped_build()) do
        local rank = rank_at(order, IDX_DRAIN, 10)
        assert(rank == 4, 'build #' .. i .. ' has Mana Drain at rank ' .. rank
            .. ' at hero level 10, not 4. The t10 honest bound says the abandoned '
            .. 'talent is at its LARGEST payout when the pick happens (slow 30 -> 40); '
            .. 'at a lower rank the give-up is smaller and the argument gets STRONGER, '
            .. 'at a higher rank it does not exist. Either way, rewrite the bound in '
            .. 'hero_lion.lua rather than deleting this test.')
    end
end

-- ---------------------------------------------------------------------------
-- 4. The build fact the t15 non-change rests on: Hex stays rank 1 deep into turbo.

tests['[hero] Hex does not reach rank 2 before hero level 12 in any shipped build'] = function()
    for i, order in ipairs(shipped_build()) do
        local second = nil
        local n = 0
        for lvl = 1, #order do
            if order[lvl] == IDX_HEX then
                n = n + 1
                if n == 2 then
                    second = lvl
                    break
                end
            end
        end
        assert(second == nil or second >= 12, 'build #' .. i .. ' takes the second '
            .. 'point of Hex at hero level ' .. tostring(second) .. '. The t15 '
            .. 'decision (leave the row alone) rests on Hex sitting at rank 1 -- a '
            .. '24 second cooldown -- for the whole turbo-reachable level range, '
            .. 'which is what makes the -2s talent a 2-in-24 band. Re-decide t15.')
    end
end

-- ---------------------------------------------------------------------------
-- 5. An ungated talent pick IS its rationale: the file has to keep carrying it.

--- Lines with comments stripped, so a ratchet on live code never trips on prose.
local function live_lines(src)
    local out = {}
    for line in src:gsub('%-%-%[%[.-%]%]', ''):gmatch('[^\n]+') do
        if not line:match('^%s*%-%-') then out[#out + 1] = line end
    end
    return out
end

tests['[hero] the lion t10/t15 rationale is still in the hero file'] = function()
    local src = read_file(LION_SRC)
    for _, needle in ipairs({
        'special_bonus_movement_speed_20',   -- what is taken
        'special_bonus_unique_lion_6',       -- what is given up
        'RESIDUAL action',                   -- why it is rarely collected
        'HONEST BOUNDS',                     -- what the argument does not show
        'datafeed',                          -- where the numbers came from
        't15 DELIBERATELY NOT CHANGED',      -- the half that did NOT move
    }) do
        assert(src:find(needle, 1, true),
            'the talent rationale block in hero_lion.lua no longer mentions "' .. needle
            .. '". A talent pick that ships without a gate IS its rationale -- the '
            .. 'hero file is the only place that reasoning lives.')
    end
end

tests['[hero] hero_lion.lua binds talent handles {4,5,8} and consumes none of the t10/t15 pair'] = function()
    local live = live_lines(read_file(LION_SRC))
    local reads = {}
    for _, line in ipairs(live) do
        for idx in line:gmatch('talent(%d)') do reads[tonumber(idx)] = true end
        for idx in line:gmatch('sTalentList%[(%d)%]') do reads[tonumber(idx)] = true end
    end
    local seen = {}
    for idx in pairs(reads) do seen[#seen + 1] = idx end
    table.sort(seen)
    local got = table.concat(seen, ',')
    assert(got == '4,5,8', 'hero_lion.lua now binds talent handles {' .. got .. '}, '
        .. 'not {4,5,8}. Indices 1-4 are the t10/t15 pairs -- the only two tiers turbo '
        .. 'reaches (GH #84) -- so anything new here needs its own accounting.')

    -- The binding is not a consumption.  talent4 is sTalentList[4], i.e. the t15
    -- pick this pass deliberately kept; its ONLY use in the file is commented out
    -- (the aether-range line just below the bind), so no branch in this hero reads
    -- a turbo-reachable talent and the t10 change is a pure engine effect.
    -- Recorded, not acted on: that commented line asks for
    -- GetSpecialValueInt("value") on special_bonus_unique_lion_11, whose datafeed
    -- special values are named bonus_spell_amp / bonus_debuff_amp -- the same
    -- mis-keyed-talent shape as hero_zuus.lua's talent5 (GH #122).  Uncommenting it
    -- would read 0, not a cast-range bonus.
    for _, line in ipairs(live) do
        for idx in line:gmatch('talent(%d):') do
            assert(tonumber(idx) >= 5, 'hero_lion.lua now CALLS talent' .. idx
                .. ', a handle from the t10/t15 pairs: ' .. line .. '\nThat turns a '
                .. 'talent pick into a branch condition, and the t10 change of '
                .. '2026-08-22 was argued as a pure engine effect with no consumer in '
                .. 'this file. Re-argue the row in hero_lion.lua.')
        end
    end
end

return tests

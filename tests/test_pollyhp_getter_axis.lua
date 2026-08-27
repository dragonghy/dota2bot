-- GH #254 -- the polliwog charm's ally gate is the one health read in this
-- family that goes through the OVERRIDDEN getters, and the round's finding is
-- that "which side should the four sites be unified onto?" is the wrong
-- question, twice over.
--
-- WRONG THE FIRST TIME: the override is not one thing. aba_global_overrides.lua
-- replaces CDOTA_Bot_Script:GetHealth with a SENTINEL (the literal 666 for a
-- unit that cannot be seen) AND a MODEL (Medusa's health plus the damage her
-- current mana absorbs). A sentinel is never a measurement; a model is a
-- measurement of the thing it models. They do not belong on the same side, so
-- "unify the getter" cannot be one atom -- it splits by COMPONENT.
--
-- WRONG THE SECOND TIME: inside this single consider the two reads want
-- opposite sides. The gate asks how much health is missing, and the charm
-- restores HEALTH -- so absorbed damage does not belong in it. The selection
-- line four lines below asks who is nearest to dying, and there absorbed damage
-- does belong. One consider, two answers, and no file-wide unification can give
-- both.
--
-- THE DEFECT IS ARITHMETIC. Under the overridden pair the missing amount is
--     (maxHealth - health) + (maxMana - mana) * k
-- so an ally missing only MANA reads as missing health. On the archive this is
-- not a rarity but the whole domain: all FIVE (holder, allied Medusa inside the
-- charm's 1000 cast range) pairs are admitted by the shipped gate and refused
-- by the Original pair, at 98.7%-100.0% of her REAL health.
--
-- WHAT IS PINNED RATHER THAN ASSUMED:
--   [I1] THE INSTRUMENT CANNOT SEE THIS DIVERGENCE, AND THAT IS WHY THE NUMBERS
--        BELOW ARE COMPUTED FROM THE SHIPPED SOURCE RATHER THAN READ THROUGH
--        THE LOADER. tests/mock/bot_api.lua defines CDOTA_Bot_Script as an
--        empty table, so nothing in the suite ever installs the override, and
--        tests/mock/replay_fixture.lua assigns u.hp to GetHealth and to
--        OriginalGetHealth in the SAME statement. Through the loader the two
--        getters are the same number on every unit of every fixture, by
--        construction -- so an armed-vs-baseline fixture read of THIS lever is
--        a no-op by construction, and a green one would mean nothing. [instrument]
--        asserts that collapse instead of quietly relying on it.
--   [I2] the frame numbers are real: the Medusa rows, their mana, their level
--        and the distances all come out of tests/fixtures/. What is replayed on
--        top of them is the shipped override FUNCTION, whose four constants are
--        read out of aba_global_overrides.lua rather than retyped here.
--   [I3] the sentinel half is unreachable AT THIS CALL SITE, and that is a
--        statement about the source, not about the corpus: the loop's first
--        conjunct is J.IsValidHero -> utils.IsValidUnit, which requires
--        CanBeSeen(). [source] reads it out of both files.
--   [I4] no archived unit holds a polliwog charm (0 of 1050), so the frames
--        below witness the PREDICATE's divergence, not a cast that flipped.
--        The end-to-end frame is not in the corpus and is not claimed.

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')
local cs = require('corpus_scale')

local JMZ       = 'bots/FunLib/jmz_func.lua'
local AIUG      = 'bots/ability_item_usage_generic.lua'
local OVERRIDES = 'bots/FunLib/aba_global_overrides.lua'
local UTILS     = 'bots/FunLib/utils.lua'
local MOCK_API  = 'tests/mock/bot_api.lua'
local MOCK_FX   = 'tests/mock/replay_fixture.lua'
local SIDE_PATH = 'bots/Customize/soak_side.lua'   -- gitignored, farm-only

local CAND   = 'pollyhp'
local MEDUSA = 'npc_dota_hero_medusa'

-- The anchor: the archive's closest holder/Medusa pair, and the one where the
-- shipped gate is furthest from the truth. Obsidian Destroyer's frame at
-- t=631.5 carries a level-11 Medusa at 227/230 -- 98.7% health -- 122u from her
-- allied Lich, with modifier_medusa_mana_shield ACTIVE on her (elapsed 706.4),
-- so the model the override applies is not hypothetical on this frame.
local FIX       = 'tests/fixtures/f_260819_222559_od_eclipse_pair.lua'
local ANCHOR_HP, ANCHOR_MAXHP = 227, 230
local ANCHOR_MP, ANCHOR_MAXMP = 569, 930
local ANCHOR_LEVEL            = 11

local tests = {}

local function read_file(path)
    local f = assert(io.open(path, 'r'))
    local s = f:read('*a')
    f:close()
    return s
end

local function charm_consider()
    local body = read_file(AIUG)
    local fn = body:match('X%.ConsiderItemDesire%["item_polliwog_charm"%].-\n\nend')
    assert(fn ~= nil, 'the polliwog consider is no longer findable in ' .. AIUG)
    return body, fn
end

-- Every number the model needs is READ OUT OF THE TREE. A retyped copy of a
-- constant is a second source of truth that no edit ever touches -- and this
-- suite has already been bitten by containment (`= 0.5` is a substring of
-- `= 0.55`), so each one is converted with tonumber and compared as a NUMBER.
local SENTINEL, DPM, RATE_HIGH, RATE_LOW, LEVEL_CUT
do
    local src = read_file(OVERRIDES)
    local fn = src:match('function CDOTA_Bot_Script:GetHealth%(%).-\nend')
    assert(fn ~= nil, 'the GetHealth override is no longer findable in ' .. OVERRIDES)
    SENTINEL  = tonumber(fn:match('not self:CanBeSeen%(%) then%s*\n%s*return (%d+)'))
    DPM       = tonumber(fn:match('local damagePerMana = ([%d%.]+)'))
    RATE_HIGH = tonumber(fn:match('local manaAbsorptionRate = ([%d%.]+)'))
    RATE_LOW  = tonumber(fn:match('GetLevel%(%) < %d+ then manaAbsorptionRate = ([%d%.]+)'))
    LEVEL_CUT = tonumber(fn:match('GetLevel%(%) < (%d+) then manaAbsorptionRate'))
    assert(SENTINEL and DPM and RATE_HIGH and RATE_LOW and LEVEL_CUT, string.format(
        'could not read the override constants out of the source (%s %s %s %s %s)',
        tostring(SENTINEL), tostring(DPM), tostring(RATE_HIGH), tostring(RATE_LOW),
        tostring(LEVEL_CUT)))
end

-- and the charm's own two numbers, likewise.
local CAST_RANGE, FLOOR
do
    local _, fn = charm_consider()
    CAST_RANGE = tonumber(fn:match('local nCastRange = (%d+)'))
    FLOOR      = tonumber(fn:match('J%.PolliwogAllyMissingHealth%(%s*allyHero%s*%) > (%d+)'))
    assert(CAST_RANGE and FLOOR, string.format(
        'could not read the charm constants out of the source (%s %s)',
        tostring(CAST_RANGE), tostring(FLOOR)))
end

-- The shipped override, replayed on a fixture row. Only the Medusa branch can
-- differ here; [source] proves the sentinel branch cannot reach the call site.
local function overridden_reads(u)
    if u.name ~= MEDUSA or (u.hp or 0) <= 0 then return u.hp, u.max_hp end
    local k = ((u.level or 0) < LEVEL_CUT) and RATE_LOW or RATE_HIGH
    return u.hp + (u.mp or 0) * DPM * k, u.max_hp + (u.max_mp or 0) * DPM * k
end

local function load_with(sCand, sSide)
    if sCand == nil then
        os.remove(SIDE_PATH)
    else
        local f = assert(io.open(SIDE_PATH, 'w'))
        f:write("return { side = '" .. (sSide or 'dire') .. "', cand = '" .. sCand .. "' }\n")
        f:close()
    end
    local J, bot, heroes = rf.load(FIX)
    assert(heroes[MEDUSA] ~= nil, 'the anchor fixture no longer carries a Medusa')
    return J, bot, heroes[MEDUSA]
end

local function with(sCand, fn, sSide)
    local J, bot, medusa = load_with(sCand, sSide)
    local ok, err = pcall(fn, J, bot, medusa)
    os.remove(SIDE_PATH)
    if not ok then error(err, 0) end
end

----------------------------------------------------------------------
-- The corpus. A fixture IS `return { ... }`, so the census costs one
-- dofile per file and never a mock world.
----------------------------------------------------------------------

local function fixtures()
    local p = assert(io.popen('ls tests/fixtures/*.lua 2>/dev/null'))
    local out = {}
    for line in p:lines() do out[#out + 1] = line end
    p:close()
    return out
end

local function dist(a, b)
    local dx, dy = a.x - b.x, a.y - b.y
    return math.sqrt(dx * dx + dy * dy)
end

-- pairs = (a living ally inside the charm's own cast range, a living Medusa).
-- Anyone on her team can be the holder; the archive says who actually carries
-- one, and the answer is nobody (see [domain]).
local function census()
    local c = {
        fixtures = 0, units = 0, medusa = 0, medusa_alive = 0,
        pairs = 0, diverge = 0, holders = 0, seen_by = 0,
        full_health_admitted = 0, worst_phantom = 0,
    }
    for _, path in ipairs(fixtures()) do
        local ok, fx = pcall(dofile, path)
        if ok and type(fx) == 'table' and type(fx.units) == 'table' then
            c.fixtures = c.fixtures + 1
            for _, u in ipairs(fx.units) do
                c.units = c.units + 1
                if u.seen_by ~= nil then c.seen_by = c.seen_by + 1 end
                if u.name == MEDUSA then
                    c.medusa = c.medusa + 1
                    if u.alive then c.medusa_alive = c.medusa_alive + 1 end
                end
            end
            for _, m in ipairs(fx.units) do
                if m.name == MEDUSA and m.alive then
                    for _, a in ipairs(fx.units) do
                        if a ~= m and a.team == m.team and a.alive
                           and dist(a, m) <= CAST_RANGE
                        then
                            c.pairs = c.pairs + 1
                            local cur, max = overridden_reads(m)
                            local bShipped  = (max - cur) > FLOOR
                            local bOriginal = (m.max_hp - m.hp) > FLOOR
                            if bShipped ~= bOriginal then c.diverge = c.diverge + 1 end
                            if bShipped and m.hp == m.max_hp then
                                c.full_health_admitted = c.full_health_admitted + 1
                            end
                            local nPhantom = (max - cur) - (m.max_hp - m.hp)
                            if nPhantom > c.worst_phantom then c.worst_phantom = nPhantom end
                            for _, sItem in ipairs(a.items or {}) do
                                if sItem == 'polliwog_charm' then c.holders = c.holders + 1 end
                            end
                        end
                    end
                end
            end
        end
    end
    return c
end

local CENSUS = census()

----------------------------------------------------------------------
-- [source] -- the tree still says what this lever is about
----------------------------------------------------------------------

tests['[source] the gate routes through the helper and the floor is untouched'] = function()
    local _, fn = charm_consider()
    assert(fn:find('and (J.PolliwogAllyMissingHealth( allyHero ) > 100)', 1, true),
        'the charm gate no longer reads through J.PolliwogAllyMissingHealth')
    assert(FLOOR == 100, 'the charm floor moved to ' .. tostring(FLOOR)
        .. ' -- the floor is NOT this lever; re-argue it before changing it')
    assert(CAST_RANGE == 1000, 'the charm cast range moved to ' .. tostring(CAST_RANGE))
end

tests['[source] the SELECTION line still reads the overridden getter, on purpose'] = function()
    -- The other half of the ruling, asserted so a later tidy-up that "unifies
    -- the file" trips instead of passing. This line asks who is nearest to
    -- dying, and for that question the absorbed-damage model belongs.
    local _, fn = charm_consider()
    assert(fn:find('if allyHero:GetHealth() < nNeedHealAllyHealth then', 1, true),
        'the charm SELECTION line changed. This round ruled that the gate and '
        .. 'the selection want OPPOSITE getters -- the gate asks what a heal can '
        .. 'restore, the selection asks who is in danger. Re-argue GH #254 before '
        .. 'unifying them.')
    assert(fn:find('OriginalGetHealth') == nil,
        'the selection line was moved onto the Original getter without re-arguing it')
end

tests['[source] the 666 sentinel cannot reach this call site'] = function()
    local _, fn = charm_consider()
    -- first conjunct of the loop
    assert(fn:find('if J.IsValidHero(allyHero)', 1, true),
        'the loop no longer opens with J.IsValidHero -- the sentinel argument in '
        .. 'jmz_func lapses with it')
    -- and the chain that makes it a vision test
    local jmz = read_file(JMZ)
    assert(jmz:find('function J.IsValidHero( nTarget )\n\treturn J.Utils.IsValidHero(nTarget)', 1, true),
        'J.IsValidHero no longer delegates to J.Utils.IsValidHero')
    local utils = read_file(UTILS)
    local sUnit = utils:match('function ____exports%.IsValidUnit.-\nend')
    assert(sUnit ~= nil, 'IsValidUnit is no longer findable in ' .. UTILS)
    assert(sUnit:find('target:CanBeSeen()', 1, true),
        'IsValidUnit no longer requires CanBeSeen() -- the 666 sentinel can now '
        .. 'reach the charm gate, and the one-directional argument must be redone')
    assert(SENTINEL == 666, 'the unseen-unit sentinel moved to ' .. tostring(SENTINEL))
end

tests['[source] the override packs exactly the two components this ruling splits'] = function()
    local src = read_file(OVERRIDES)
    local fn = src:match('function CDOTA_Bot_Script:GetHealth%(%).-\nend')
    assert(fn:find('CanBeSeen', 1, true), 'the sentinel component left GetHealth')
    assert(fn:find('npc_dota_hero_medusa', 1, true), 'the model component left GetHealth')
    -- and the un-overridden reads the armed branch uses are still passthroughs
    assert(src:find('function CDOTA_Bot_Script:OriginalGetHealth()\n    return original_GetHealth(self)\nend', 1, true),
        'OriginalGetHealth is no longer the un-overridden read')
    assert(src:find('function CDOTA_Bot_Script:OriginalGetMaxHealth()\n    return originalGetMaxHealth(self)\nend', 1, true),
        'OriginalGetMaxHealth is no longer the un-overridden read')
    -- the constants the model above replays
    assert(DPM == 2.6 and RATE_HIGH == 0.95 and RATE_LOW == 0.5 and LEVEL_CUT == 12,
        string.format('the mana-shield constants moved: %s %s %s %s',
            tostring(DPM), tostring(RATE_HIGH), tostring(RATE_LOW), tostring(LEVEL_CUT)))
end

tests['[gate] one candidate id, one mode predicate, and nothing else'] = function()
    local jmz = read_file(JMZ)
    local fn = jmz:match('function J%.PolliwogAllyMissingHealth.-\nend')
    assert(fn ~= nil, 'J.PolliwogAllyMissingHealth is no longer findable')
    assert(select(2, fn:gsub('IsSoakCandidate', '')) == 1,
        'the gate names IsSoakCandidate more than once -- a conjunction of two '
        .. 'candidate ids freezes FALSE the day either one is promoted (GH #207)')
    assert(fn:find("J.IsModeTurbo() and J.IsSoakCandidate( 'pollyhp' )", 1, true),
        'the gate shape changed')
    -- the body carries no number at all: this lever has no threshold to fit.
    local sBody = fn:match('then\n(.-)\n\tend')
    assert(sBody ~= nil and select(2, sBody:gsub('%d', '')) == 0,
        'a number appeared in the armed branch -- this lever changes an AXIS, '
        .. 'not a constant')
end

tests['[gate] each branch reads the pair it is named for'] = function()
    -- The loader collapses the two pairs into one number ([instrument]), so
    -- NOTHING that runs can tell a neutered armed branch from a live one. The
    -- only instrument left is the source, and it is used here rather than
    -- assumed: an armed branch quietly rewritten back to the overridden getters
    -- would otherwise pass every other row in this file.
    local jmz = read_file(JMZ)
    local fn = jmz:match('function J%.PolliwogAllyMissingHealth.-\nend')
    local sArmed    = fn:match('IsSoakCandidate%(%s*\'pollyhp\'%s*%) then\n(.-)\n\tend')
    local sFallback = fn:match('\n\tend\n(.-)\nend')
    assert(sArmed ~= nil and sFallback ~= nil, 'the helper no longer has two branches')
    assert(sArmed:find('OriginalGetMaxHealth() - hAlly:OriginalGetHealth()', 1, true),
        'the ARMED branch does not read the Original pair: ' .. sArmed)
    assert(sArmed:find('hAlly:GetMaxHealth()', 1, true) == nil,
        'the armed branch still reads an overridden getter: ' .. sArmed)
    assert(sFallback:find('hAlly:GetMaxHealth() - hAlly:GetHealth()', 1, true),
        'the UNARMED branch no longer reads the shipped pair -- the shipped '
        .. 'default must stay byte-identical: ' .. sFallback)
    assert(sFallback:find('Original', 1, true) == nil,
        'the unarmed branch reads an Original getter -- that is the fix shipping '
        .. 'ungated: ' .. sFallback)
end

----------------------------------------------------------------------
-- [instrument] -- why the frames below are replayed rather than read
----------------------------------------------------------------------

tests['[instrument] the loader collapses the two getters into one number'] = function()
    -- Asserted at the SOURCE, because on a clean tree a swept `== 0` divergence
    -- count is indistinguishable from `>= 0` -- the lesson GH #248 (iii) paid
    -- for. The construction is the evidence: one statement, one value, two keys.
    local mock = read_file(MOCK_FX)
    assert(mock:find('GetHealth = u.hp, GetMaxHealth = u.max_hp,\n'
                     .. '            OriginalGetHealth = u.hp, OriginalGetMaxHealth = u.max_hp,', 1, true),
        'the fixture loader no longer assigns the SAME expression to both getter '
        .. 'pairs. If it now models the override, this file\'s [replayed] rows can '
        .. 'and should become a direct armed-vs-baseline read -- go do that.')
    -- and nothing installs the shipped override layer over it
    local api = read_file(MOCK_API)
    assert(api:find('G.CDOTA_Bot_Script = {}', 1, true),
        'CDOTA_Bot_Script is no longer an empty table in the mock -- re-check '
        .. 'whether aba_global_overrides now reaches test worlds')
end

tests['[instrument] and the collapse is visible through the loader on the anchor'] = function()
    with(nil, function(_, _, medusa)
        assert(medusa:GetHealth() == medusa:OriginalGetHealth(),
            'the loader now separates the getters -- see [instrument] above')
        assert(medusa:GetHealth() == ANCHOR_HP,
            'the anchor Medusa reads ' .. tostring(medusa:GetHealth())
            .. ', registered as ' .. ANCHOR_HP)
        assert(medusa:GetMaxHealth() == ANCHOR_MAXHP,
            'the anchor Medusa pool moved to ' .. tostring(medusa:GetMaxHealth()))
    end)
end

tests['[instrument] armed and baseline are therefore IDENTICAL through the loader'] = function()
    -- Stated as a test rather than as a footnote: a green armed-vs-baseline
    -- fixture read of this lever would be a no-op passing itself off as
    -- validation. The divergence is real; this instrument cannot show it.
    local nBase, nArmed
    with(nil, function(J, _, medusa) nBase = J.PolliwogAllyMissingHealth(medusa) end)
    with(CAND, function(J, _, medusa) nArmed = J.PolliwogAllyMissingHealth(medusa) end)
    assert(nBase == nArmed, 'the loader began to separate the getters -- rewrite '
        .. 'the [replayed] rows as direct reads')
    assert(nBase == ANCHOR_MAXHP - ANCHOR_HP,
        'the loader reads missing ' .. tostring(nBase) .. ', expected '
        .. tostring(ANCHOR_MAXHP - ANCHOR_HP))
end

----------------------------------------------------------------------
-- [replayed] -- real frame numbers, shipped override function
----------------------------------------------------------------------

tests['[replayed] the anchor frame carries the numbers this ruling is argued from'] = function()
    local fx = dofile(FIX)
    local m, lich
    for _, u in ipairs(fx.units) do
        if u.name == MEDUSA then m = u end
        if u.name == 'npc_dota_hero_lich' then lich = u end
    end
    assert(m ~= nil and lich ~= nil, 'the anchor fixture lost a hero')
    assert(m.hp == ANCHOR_HP and m.max_hp == ANCHOR_MAXHP,
        'the anchor Medusa health moved: ' .. m.hp .. '/' .. m.max_hp)
    assert(m.mp == ANCHOR_MP and m.max_mp == ANCHOR_MAXMP,
        'the anchor Medusa mana moved: ' .. m.mp .. '/' .. m.max_mp)
    assert(m.level == ANCHOR_LEVEL, 'the anchor Medusa level moved: ' .. tostring(m.level))
    assert(m.team == lich.team and m.alive and lich.alive, 'the anchor pair is no longer a living ally pair')
    assert(dist(m, lich) < CAST_RANGE,
        'the anchor pair is no longer inside the charm range: ' .. dist(m, lich))
    -- the shield is actually running on this frame, so the model is not
    -- hypothetical here.
    local bShield = false
    for _, mod in ipairs(m.modifiers or {}) do
        if mod.name == 'modifier_medusa_mana_shield' then bShield = true end
    end
    assert(bShield, 'the anchor Medusa no longer carries modifier_medusa_mana_shield')
end

tests['[replayed] the shipped gate admits a Medusa at 98.7% of her real health'] = function()
    local fx = dofile(FIX)
    local m
    for _, u in ipairs(fx.units) do if u.name == MEDUSA then m = u end end
    local cur, max = overridden_reads(m)
    local nShipped  = max - cur
    local nOriginal = m.max_hp - m.hp
    -- 3 real health missing, and 469.3 of absorbed-damage capacity she is not
    -- missing health for. The gate asks for 100.
    assert(nOriginal == 3, 'the anchor real deficit moved: ' .. nOriginal)
    assert(math.abs(nShipped - 472.3) < 0.05,
        'the anchor overridden deficit moved: ' .. nShipped)
    assert(nShipped > FLOOR and nOriginal <= FLOOR,
        'the anchor no longer separates the two readings')
    -- every point of the difference is mana, by construction
    local k = (m.level < LEVEL_CUT) and RATE_LOW or RATE_HIGH
    assert(math.abs((nShipped - nOriginal) - (m.max_mp - m.mp) * DPM * k) < 1e-9,
        'the phantom deficit is not exactly the mana term')
end

tests['[source] one-directionality is a property of the OVERRIDE, not of this model'] = function()
    -- ⚠ THE MUTATION THAT SURVIVED, AND WHY THE REPAIR IS A DIFFERENT
    -- INSTRUMENT RATHER THAN ANOTHER ASSERTION. The sweep below walks every row
    -- of the corpus and confirms the overridden deficit is never smaller than
    -- the real one -- and it stayed green when the SOURCE was mutated to build
    -- its max term out of CURRENT mana, because the sweep asks
    -- `overridden_reads`, which is this file's own model of the override. A
    -- control built out of the thing under test is a tautology (GH #248 (ii)).
    -- What the one-directional argument in jmz_func actually rests on is a fact
    -- about the source: maxMana on the max side, mana on the current side, same
    -- coefficient on both. So that is read out of the source here, and the
    -- sweep below is demoted to what it really is -- an arithmetic check of the
    -- model on real numbers.
    local src = read_file(OVERRIDES)
    local sCur = src:match('function CDOTA_Bot_Script:GetHealth%(%).-\nend')
    local sMax = src:match('function CDOTA_Bot_Script:GetMaxHealth%(%).-\nend')
    assert(sCur ~= nil and sMax ~= nil, 'the two overrides are no longer findable')
    assert(sCur:find('local mana = self:GetMana()', 1, true),
        'the current-health override no longer reads CURRENT mana')
    assert(sCur:find('self:GetMaxMana()', 1, true) == nil,
        'the current-health override now reads MAX mana -- the armed reading can '
        .. 'no longer be proved to be the smaller one; redo the argument in jmz_func')
    assert(sMax:find('self:GetMaxMana() * damagePerMana * manaAbsorptionRate', 1, true),
        'the max-health override no longer builds its term from MAX mana -- the '
        .. 'one-directional argument in jmz_func is VOID: arming could now admit '
        .. 'a candidate the shipped gate refused')
    -- same coefficient on both sides, or the difference is not a mana term
    for _, sBranch in ipairs({ sCur, sMax }) do
        assert(tonumber(sBranch:match('local damagePerMana = ([%d%.]+)')) == DPM,
            'the two overrides no longer share damagePerMana')
        assert(tonumber(sBranch:match('local manaAbsorptionRate = ([%d%.]+)')) == RATE_HIGH,
            'the two overrides no longer share manaAbsorptionRate')
    end
end

tests['[replayed] the modelled reading is never the smaller one on any archived row'] = function()
    -- The arithmetic half of the claim above, on real numbers rather than on a
    -- grid. It cannot catch a change to the override itself -- that is what the
    -- [source] row before it is for.
    local nRows = 0
    for _, path in ipairs(fixtures()) do
        local ok, fx = pcall(dofile, path)
        if ok and type(fx) == 'table' and type(fx.units) == 'table' then
            for _, u in ipairs(fx.units) do
                local cur, max = overridden_reads(u)
                nRows = nRows + 1
                assert((max - cur) >= (u.max_hp - u.hp) - 1e-9, string.format(
                    'the overridden reading is SMALLER than the original on %s in %s '
                    .. '-- the one-directional argument in jmz_func is void',
                    u.name, path))
            end
        end
    end
    cs.ratchet(nRows, 1050, 'rows checked for one-directionality')
end

----------------------------------------------------------------------
-- [domain] -- what the archive says the lever is worth
----------------------------------------------------------------------

tests['[domain] every archived holder/Medusa pair is a false admission'] = function()
    cs.corpus(CENSUS.fixtures, 'pollyhp census')
    cs.ratchet(CENSUS.units, 1050, 'units swept')
    cs.ratchet(CENSUS.medusa, 17, 'Medusa rows')
    cs.ratchet(CENSUS.pairs, 5, 'holder/Medusa pairs inside the cast range')
    -- the sharp one: not "some of them", ALL of them.
    cs.universal(CENSUS.diverge, CENSUS.pairs, 'pairs where the two getters disagree', 5)
    cs.ratchet(CENSUS.full_health_admitted, 4, 'pairs admitted at FULL health')
    assert(CENSUS.worst_phantom > 490 and CENSUS.worst_phantom < 500,
        'the worst phantom deficit moved to ' .. CENSUS.worst_phantom)
end

tests['[domain] no archived unit holds the charm, so no cast is claimed to flip'] = function()
    -- [I4]. The predicate divergence is witnessed 5 of 5; the end-to-end frame
    -- (a bot with the charm in its slots and a Medusa in range) is NOT in the
    -- corpus, and this lever does not claim it. Neutral items do not appear in
    -- the dumped item slots at all -- so this zero is about the DUMP FORMAT,
    -- not about turbo.
    assert(CENSUS.holders == 0, string.format(
        'a charm holder appeared in the archive (%d) -- GO LAND THE END-TO-END '
        .. 'FIXTURE: the consider can now be run on a real frame instead of '
        .. 'having its gate replayed', CENSUS.holders))
end

tests['[domain] the fog leg of the loader has never been exercised'] = function()
    -- Registered, not fixed, and it is the second reason the sentinel component
    -- is out of reach locally: no fixture carries `seen_by`, so even a loader
    -- that DID install the override would have nothing invisible to apply it
    -- to. Turns red the day a v2 vision fixture lands, which is exactly when
    -- the sentinel half becomes answerable here.
    assert(CENSUS.seen_by == 0, string.format(
        '%d fixture rows now carry vision data -- the sentinel component of the '
        .. 'override is testable locally for the first time; re-read GH #254',
        CENSUS.seen_by))
end

----------------------------------------------------------------------
-- [inert] -- the shipped default is byte-for-byte the old behaviour
----------------------------------------------------------------------

tests['[inert] unarmed, wrong side, and other ids all read the shipped pair'] = function()
    local nShipped
    with(nil, function(J, _, medusa) nShipped = J.PolliwogAllyMissingHealth(medusa) end)
    assert(nShipped == ANCHOR_MAXHP - ANCHOR_HP, 'baseline reading moved')

    -- the anchor subject is dire; arming radiant must not reach it
    with(CAND, function(J, _, medusa)
        assert(J.PolliwogAllyMissingHealth(medusa) == nShipped,
            'the gate fired on the wrong side')
    end, 'radiant')

    -- five unrelated ids, including two sisters from the same file
    for _, sId in ipairs({ 'salvepool', 'salveally', 'salveyield', 'campgrade', 'pullcamp' }) do
        with(sId, function(J, _, medusa)
            assert(J.PolliwogAllyMissingHealth(medusa) == nShipped,
                'the gate fired under id ' .. sId)
        end)
    end
end

tests['[inert] the armed branch is reached only under turbo'] = function()
    -- The mode predicate is the other conjunct, and the fixture loader is
    -- turbo, so the check that it is CONSULTED has to be made on the source.
    local jmz = read_file(JMZ)
    local fn = jmz:match('function J%.PolliwogAllyMissingHealth.-\nend')
    assert(fn:find('J.IsModeTurbo()', 1, true), 'the turbo conjunct left the gate')
    assert(fn:find('J.IsModeTurbo() and J.IsSoakCandidate', 1, true),
        'the mode predicate is no longer the FIRST conjunct -- an unarmed non-turbo '
        .. 'game would start paying for the soak-file read')
end

return tests

-- GH #237 -- the THIRD defect in X.ConsiderItemDesire["item_flask"], and the
-- first one that is not about a constant: between the salve's two halves there
-- is NO ARBITRATION AT ALL.
--
-- The self branch returns the instant its own conjuncts hold, so the ally
-- branch forty lines below is not outranked, it is never reached. The self
-- floor is an ABSOLUTE missing amount, so on a large pool it is satisfied while
-- the bot is still comfortable: at the archive's largest pool (2566), missing
-- 501 leaves the bot at 80.5% health -- and that is enough to drink the salve
-- on itself with a teammate at 14% standing 400u away. Nothing in the function
-- compares the two heroes.
--
-- WHY THERE IS NO CONSTANT HERE, AND WHY THE AXIS IS NOT CHOSEN. Ratio and
-- absolute health disagree about who is worse off, and for a FIXED-amount heal
-- neither reading is obviously right (the ratio picks whoever is nearest death
-- as a fraction; the absolute picks whoever dies to the smallest burst; 400
-- health is most of a support's pool and a sliver of a carry's). This lever
-- therefore yields only under DOMINANCE -- the ally must be worse off on BOTH
-- readings at once. That is the intersection of the two candidate rules, hence
-- the most conservative of them by construction, and it introduces no threshold
-- to fit. [refusal] below pins what the single-axis rules would have bought.
--
-- ⚠ THE CRITERION THIS ROUND EXISTS TO WRITE DOWN. A `limits` note that says a
-- conjunct is UNMODELLABLE is itself a claim about the dump, and it has to be
-- checked against the dump rather than inherited. GH #231's [W1] listed four
-- heal modifiers and WasRecentlyDamagedByAnyHero as "NOT in any dump". Two of
-- those five ARE in the dump -- `modifiers` on 41% of archive units and
-- `recent_damage` on 17% -- and modelling them halves the top two rows of that
-- round's published domain table (6 -> 3, 2 -> 1). It also decides THIS
-- round's headline: the one pair that survives every other conjunct is killed
-- by the ally's own recent-damage guard, so this lever's end-to-end domain is
-- 1 under GH #231's modelling convention and 0 under the corrected one.
-- [w1correction] asserts both readings, and the published table is reproduced
-- here first so the correction is a delta against a number this file can show,
-- not against a number it remembers.
--
-- WHAT IS PINNED RATHER THAN ASSUMED:
--   [V1] `IsIllusion` / `IsChanneling` really are absent from the dump, and the
--        fountain guard (DistanceFromFountain < 3000 returns early) is not
--        modelled either -- fixtures carry no fountain. Every count below is
--        therefore still an UPPER bound on real reachability. What changed is
--        that two conjuncts moved OUT of this list, not that the list is gone.
--   [V2] the heal-modifier and recent-damage conjuncts are modelled only where
--        the dump carries the field. A unit with no `recent_damage` key is
--        treated as "unknown, not excluded", which keeps the corrected counts
--        upper bounds as well. The coverage fractions are asserted so a future
--        dump change cannot silently turn a partial model into a claimed full
--        one.
--   [V3] the never-drops property is a statement about the SOURCE, not about
--        this model: the guard is handed the ally branch's own firing condition
--        from the same frame. [nodrop] reads that out of the tree.

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')
local cs = require('corpus_scale')

local JMZ  = 'bots/FunLib/jmz_func.lua'
local AIUG = 'bots/ability_item_usage_generic.lua'
local ss = require('mock.soak_side')
local SIDE_PATH = ss.PATH                          -- gitignored, farm-only

local CAND = 'salveyield'

-- The anchor: the archive's only frame where a salve holder's self branch fires
-- with a strictly worse-off teammate inside the branch's own 700 radius.
local FIX     = 'tests/fixtures/f_260820_043140_luna_ring_bid.lua'
local HOLDER  = 'npc_dota_hero_tidehunter'
local ALLY    = 'npc_dota_hero_silencer'
local HOLDER_HP, HOLDER_MAXHP = 80, 1455      --  5.5%
local ALLY_HP,   ALLY_MAXHP   = 43, 1229      --  3.5%

-- The shipped constants of the two sibling levers, written out so the model is
-- comparable against the source rather than against a memory of it. [source]
-- pins each one.
local SELF_FLOOR = 500
local ALLY_FLOOR = 550

local tests = {}

local function read_file(path)
    local f = assert(io.open(path, 'r'))
    local s = f:read('*a')
    f:close()
    return s
end

local function salve_consider()
    local body = read_file(AIUG)
    local fn = body:match('X%.ConsiderItemDesire%["item_flask"%].-\n\nend')
    assert(fn ~= nil, 'the salve consider is no longer findable in ' .. AIUG)
    return body, fn
end

-- The radii the model needs are READ OUT OF THE SOURCE rather than typed here a
-- second time. GH #231 learned this the hard way: a hard-coded copy of the
-- quiet radius could be mutated 1000 -> 1600 with every assertion still green,
-- because on this archive the two radii happen to select the same pairs.
local PAIR_DIST_MAX, QUIET_RADIUS, SELF_QUIET_RADIUS
do
    local body, fn = salve_consider()
    PAIR_DIST_MAX     = tonumber(fn:match('J%.GetAlliesNearLoc%(%s*bot:GetLocation%(%),%s*(%d+)%s*%)'))
    SELF_QUIET_RADIUS = tonumber(fn:match('local nCastRange = (%d+)'))
    QUIET_RADIUS      = tonumber(body:match('hNearbyEnemyHeroList = J%.GetNearbyHeroes%(bot,%s*(%d+),'))
    assert(PAIR_DIST_MAX and SELF_QUIET_RADIUS and QUIET_RADIUS, string.format(
        'could not read the radii out of the source (ally %s, self %s, quiet %s)',
        tostring(PAIR_DIST_MAX), tostring(SELF_QUIET_RADIUS), tostring(QUIET_RADIUS)))
end

-- The two recent-damage windows the branch uses, likewise read from the source.
local SELF_DMG_WINDOW, ALLY_DMG_WINDOW
do
    local _, fn = salve_consider()
    SELF_DMG_WINDOW = tonumber(fn:match('bot:WasRecentlyDamagedByAnyHero%(%s*([%d%.]+)%s*%)'))
    ALLY_DMG_WINDOW = tonumber(fn:match('npcAlly:WasRecentlyDamagedByAnyHero%(%s*([%d%.]+)%s*%)'))
    assert(SELF_DMG_WINDOW and ALLY_DMG_WINDOW, 'could not read the damage windows out of the source')
end

-- The four heal modifiers, also read from the source rather than retyped.
local HEAL_MODS
do
    local _, fn = salve_consider()
    HEAL_MODS = {}
    for sMod in fn:gmatch('HasModifier%(%s*"([%w_]+)"%s*%)') do HEAL_MODS[sMod] = true end
end

-- [GH #365 §3 / GH #229] Arming goes through tests/mock/soak_side.lua, the
-- switch's one owner: the write is read back, the unarmed leg ASSERTS the
-- switch is absent instead of deleting whatever it finds, and the switch is
-- re-read after each case body so a concurrent removal is reported as itself
-- rather than as this file's own unarmed `== false`.
local function load_with(sCand, sSide)
    if sCand == nil then
        ss.assert_clean('test_salveyield_arbitration unarmed leg')
    else
        ss.arm(sCand, sSide or 'dire')
    end
    local J, bot, heroes = rf.load(FIX, HOLDER)
    assert(bot ~= nil, 'fixture no longer carries ' .. HOLDER)
    assert(heroes[ALLY] ~= nil, 'fixture no longer carries ' .. ALLY)
    return J, bot, heroes[ALLY]
end

local function with(sCand, fn, sSide)
    local J, bot, ally = load_with(sCand, sSide)
    local ok, err = pcall(fn, J, bot, ally)
    ss.finish(ok, err)
end

----------------------------------------------------------------------
-- The corpus. A fixture IS `return { ... }`, so the census costs one
-- dofile per file and never a mock world.
----------------------------------------------------------------------

local function dist(a, b)
    local dx, dy = a.x - b.x, a.y - b.y
    return math.sqrt(dx * dx + dy * dy)
end

local function holds_salve(u)
    for _, sItem in ipairs(u.items or {}) do
        if sItem == 'flask' then return true end
    end
    return false
end

-- [V2] "unknown, not excluded": a unit with no `modifiers` key is not treated
-- as healed, and a unit with no `recent_damage` key is not treated as hit.
local function healed(u)
    for _, m in ipairs(u.modifiers or {}) do
        if HEAL_MODS[m.name] then return true end
    end
    return false
end

local function hit_recently(u, nWindow)
    if u.recent_damage == nil then return false end
    for _, d in ipairs(u.recent_damage) do
        if d.dt > nWindow then break end
        if d.kind == 'hero' then return true end
    end
    return false
end

local corpus_cache = nil
local function corpus()
    if corpus_cache ~= nil then return corpus_cache end
    local pairs_, nFiles, nUnits, nWithMods, nWithDmg, nHealUnits = {}, 0, 0, 0, 0, 0
    local p = assert(io.popen('ls tests/fixtures/*.lua 2>/dev/null'))
    for path in p:lines() do
        local ok, fx = pcall(dofile, path)
        if ok and type(fx) == 'table' and fx.units then
            nFiles = nFiles + 1
            for _, u in ipairs(fx.units) do
                nUnits = nUnits + 1
                if u.modifiers      ~= nil then nWithMods = nWithMods + 1 end
                if u.recent_damage  ~= nil then nWithDmg  = nWithDmg  + 1 end
                if healed(u)               then nHealUnits = nHealUnits + 1 end
            end
            for _, h in ipairs(fx.units) do
                if h.alive and h.max_hp and h.max_hp > 0 and holds_salve(h) then
                    local bQuietSelf, bQuietAlly = true, true
                    for _, v in ipairs(fx.units) do
                        if v ~= h and v.alive and v.team ~= h.team then
                            local d = dist(v, h)
                            if d <= SELF_QUIET_RADIUS then bQuietSelf = false end
                            if d <= QUIET_RADIUS      then bQuietAlly = false end
                        end
                    end
                    for _, a in ipairs(fx.units) do
                        if a ~= h and a.alive and a.team == h.team
                            and a.max_hp and a.max_hp > 0
                            and dist(a, h) <= PAIR_DIST_MAX
                        then
                            pairs_[#pairs_ + 1] = {
                                file = path, holder = h.name, ally = a.name,
                                holder_hp = h.hp, holder_max = h.max_hp,
                                ally_hp = a.hp, ally_max = a.max_hp,
                                self_fires  = (h.max_hp - h.hp) > SELF_FLOOR,
                                ally_missing_ok = (a.max_hp - a.hp) > ALLY_FLOOR,
                                quiet_self  = bQuietSelf,
                                quiet_ally  = bQuietAlly,
                                -- the two conjuncts GH #231's [W1] called unmodellable
                                self_clean  = (not healed(h)) and (not hit_recently(h, SELF_DMG_WINDOW)),
                                ally_clean  = (not healed(a)) and (not hit_recently(a, ALLY_DMG_WINDOW)),
                                -- kept apart so the correction can be decomposed
                                ally_healed = healed(a),
                                ally_hit    = hit_recently(a, ALLY_DMG_WINDOW),
                            }
                        end
                    end
                end
            end
        end
    end
    p:close()
    assert(nFiles > 0, 'no fixtures readable; every census below would be a vacuous pass')
    corpus_cache = { pairs = pairs_, files = nFiles, units = nUnits,
                     with_mods = nWithMods, with_dmg = nWithDmg,
                     heal_units = nHealUnits }
    return corpus_cache
end

-- The two candidate axes, and the rule actually shipped (their intersection).
local function lower_abs(r)   return r.ally_hp < r.holder_hp end
local function lower_ratio(r) return r.ally_hp * r.holder_max < r.holder_hp * r.ally_max end
local function dominates(r)   return lower_abs(r) and lower_ratio(r) end

local function count(fPred)
    local n = 0
    for _, r in ipairs(corpus().pairs) do
        if fPred(r) then n = n + 1 end
    end
    return n
end

----------------------------------------------------------------------
-- [source] the constants and shapes this file models, read off the tree
----------------------------------------------------------------------

tests['[source] the modelled radii and windows match the branch'] = function()
    assert(PAIR_DIST_MAX == 700, 'ally radius moved: ' .. tostring(PAIR_DIST_MAX))
    assert(SELF_QUIET_RADIUS == 900, 'self enemy radius moved: ' .. tostring(SELF_QUIET_RADIUS))
    assert(QUIET_RADIUS == 1000, 'file-level enemy radius moved: ' .. tostring(QUIET_RADIUS))
    assert(SELF_DMG_WINDOW == 2.2, 'self damage window moved: ' .. tostring(SELF_DMG_WINDOW))
    assert(ALLY_DMG_WINDOW == 3.0, 'ally damage window moved: ' .. tostring(ALLY_DMG_WINDOW))
end

tests['[source] all four heal modifiers were read out of the branch'] = function()
    local n = 0
    for _ in pairs(HEAL_MODS) do n = n + 1 end
    assert(n == 4, 'expected 4 heal modifiers in the consider, read ' .. n)
    for _, sMod in ipairs({ 'modifier_filler_heal', 'modifier_elixer_healing',
                            'modifier_flask_healing', 'modifier_juggernaut_healing_ward_heal' }) do
        assert(HEAL_MODS[sMod], 'heal modifier no longer in the branch: ' .. sMod)
    end
end

tests['[source] the guard body carries no threshold constant'] = function()
    local body = read_file(JMZ)
    local fn = body:match('function J%.ShouldYieldSalveToAlly.-\nend')
    assert(fn ~= nil, 'J.ShouldYieldSalveToAlly is no longer findable in ' .. JMZ)
    -- Zero is the only numeral allowed: it is the positivity guard that keeps
    -- the cross-multiplication's direction valid, not a tunable.
    for sNum in fn:gmatch('%d+%.?%d*') do
        assert(sNum == '0', 'a threshold constant appeared in the guard body: ' .. sNum)
    end
end

tests['[source] the guard reads each pool and each health exactly once'] = function()
    local body = read_file(JMZ)
    local fn = body:match('function J%.ShouldYieldSalveToAlly.-\nend')
    local function occurrences(s, sPat)
        local n = 0
        for _ in s:gmatch(sPat) do n = n + 1 end
        return n
    end
    -- two heroes x two getters, once each: the comparison cannot end up reading
    -- two different numbers for the same hero.
    assert(occurrences(fn, 'OriginalGetMaxHealth%(%)') == 2,
        'pool is no longer read exactly twice (once per hero)')
    assert(occurrences(fn, 'OriginalGetHealth%(%)') == 2,
        'health is no longer read exactly twice (once per hero)')
end

----------------------------------------------------------------------
-- [nodrop] the property that makes this lever a re-target, never a drop
----------------------------------------------------------------------

tests['[nodrop] the guard is handed the ally branch\'s own firing condition'] = function()
    local _, fn = salve_consider()
    local sCond = fn:match('local bAllyBranchOpen%s*=%s*([^\n]+)')
    assert(sCond ~= nil, 'bAllyBranchOpen is no longer computed in the consider')
    assert(sCond:find('hNeedHealAlly ~= nil', 1, true),
        'bAllyBranchOpen no longer requires a selected ally: ' .. sCond)
    assert(sCond:find('#hNearbyEnemyHeroList == 0', 1, true),
        'bAllyBranchOpen no longer requires the enemy list to be empty: ' .. sCond)
    -- and the ally branch must fire on exactly that condition and nothing more
    assert(fn:find('if bAllyBranchOpen\n\tthen', 1, true),
        'the ally branch no longer fires on exactly bAllyBranchOpen')
    -- and the guard must be handed it
    assert(fn:find('J.ShouldYieldSalveToAlly( bot, hNeedHealAlly, bAllyBranchOpen )', 1, true),
        'the self branch no longer passes the ally branch condition to the guard')
end

tests['[nodrop] the guard short-circuits to false when the ally branch is shut'] = function()
    with(CAND, function(J, bot, ally)
        assert(J.ShouldYieldSalveToAlly(bot, ally, false) == false,
            'armed, the guard yielded with the ally branch shut -- that would DROP the cast')
        assert(J.ShouldYieldSalveToAlly(bot, nil, true) == false,
            'armed, the guard yielded with no ally selected -- that would DROP the cast')
    end)
end

tests['[nodrop] the ally scan is hoisted above the self branch'] = function()
    local _, fn = salve_consider()
    local nScan  = fn:find('J.GetAlliesNearLoc', 1, true)
    local nSelf  = fn:find('J.SalveSelfMissingFloor', 1, true)
    local nAlly  = fn:find('if bAllyBranchOpen', 1, true)
    assert(nScan and nSelf and nAlly, 'the consider no longer has all three landmarks')
    assert(nScan < nSelf, 'the ally scan is no longer hoisted above the self branch')
    assert(nSelf < nAlly, 'the self branch no longer precedes the ally branch')
end

----------------------------------------------------------------------
-- [gate] unarmed is literally false; the gate is one conjunct on turbo
----------------------------------------------------------------------

tests['[gate] unarmed, the guard is false on the anchor frame'] = function()
    with(nil, function(J, bot, ally)
        assert(J.ShouldYieldSalveToAlly(bot, ally, true) == false,
            'the guard fired with no soak side file -- shipped behaviour changed')
    end)
end

tests['[gate] armed on the anchor frame, the guard yields'] = function()
    with(CAND, function(J, bot, ally)
        assert(J.ShouldYieldSalveToAlly(bot, ally, true) == true,
            'armed, the guard did not yield to an ally worse off on BOTH readings')
    end)
end

tests['[gate] five other candidate ids leave the guard false'] = function()
    for _, sOther in ipairs({ 'salvepool', 'salveally', 'creeppull', 'bbfight', 'campdanger' }) do
        with(sOther, function(J, bot, ally)
            assert(J.ShouldYieldSalveToAlly(bot, ally, true) == false,
                'the guard fired while a DIFFERENT id was armed: ' .. sOther)
        end)
    end
end

tests['[gate] arming the wrong side leaves the guard false'] = function()
    -- the anchor's holder is dire; arming radiant must not reach him
    with(CAND, function(J, bot, ally)
        assert(J.ShouldYieldSalveToAlly(bot, ally, true) == false,
            'the guard fired for a subject on the other side')
    end, 'radiant')
end

tests['[gate] the gate is a single conjunct against a mode predicate'] = function()
    local body = read_file(JMZ)
    local fn = body:match('function J%.ShouldYieldSalveToAlly.-\nend')
    local sGate = fn:match('if not %(([^\n]-)%) then return false end')
    assert(sGate ~= nil, 'the gate line is no longer findable in the guard')
    assert(sGate:find("J.IsSoakCandidate( '" .. CAND .. "' )", 1, true),
        'the gate no longer names ' .. CAND .. ': ' .. sGate)
    assert(sGate:find('J.IsModeTurbo()', 1, true), 'the gate is no longer turbo-only: ' .. sGate)
    -- GH #207 / pullcad: a gate that names another CANDIDATE id freezes false
    -- the day that id is promoted. This one names only a mode predicate.
    local nCands = 0
    for _ in sGate:gmatch('IsSoakCandidate') do nCands = nCands + 1 end
    assert(nCands == 1, 'the gate conjoins more than one candidate id: ' .. sGate)
end

----------------------------------------------------------------------
-- [anchor] the real frame, through the real helpers
----------------------------------------------------------------------

tests['[anchor] the fixture still carries the frame this lever was found on'] = function()
    with(nil, function(J, bot, ally)
        assert(bot:OriginalGetHealth() == HOLDER_HP and bot:OriginalGetMaxHealth() == HOLDER_MAXHP,
            'the holder moved off the anchored health')
        assert(ally:OriginalGetHealth() == ALLY_HP and ally:OriginalGetMaxHealth() == ALLY_MAXHP,
            'the ally moved off the anchored health')
        assert(GetUnitToUnitDistance(bot, ally) <= PAIR_DIST_MAX,
            'the ally left the branch\'s own radius')
    end)
end

tests['[anchor] the self branch really does fire here, under both self floors'] = function()
    with(nil, function(J, bot)
        local mx = bot:OriginalGetMaxHealth()
        assert(mx - bot:OriginalGetHealth() > J.SalveSelfMissingFloor(mx),
            'shipped: the self branch does not fire on the anchor -- there is nothing to pre-empt')
    end)
    with('salvepool', function(J, bot)
        local mx = bot:OriginalGetMaxHealth()
        assert(mx - bot:OriginalGetHealth() > J.SalveSelfMissingFloor(mx),
            'salvepool-armed: the self branch does not fire on the anchor')
    end)
end

tests['[anchor] the ally is worse off on BOTH readings, so no axis was chosen'] = function()
    local r = { ally_hp = ALLY_HP, ally_max = ALLY_MAXHP,
                holder_hp = HOLDER_HP, holder_max = HOLDER_MAXHP }
    assert(lower_abs(r),   'the anchor ally is not lower on absolute health')
    assert(lower_ratio(r), 'the anchor ally is not lower on remaining ratio')
end

tests['[anchor] shipped, this is the frame where the salve goes to the wrong hero'] = function()
    -- 5.5% drinking it himself with a 3.5% teammate 596u away, and no line in
    -- the function comparing the two.
    assert(HOLDER_HP / HOLDER_MAXHP > ALLY_HP / ALLY_MAXHP,
        'the anchor no longer shows the holder better off than the ally')
    with(nil, function(J, bot, ally)
        assert(J.ShouldYieldSalveToAlly(bot, ally, true) == false,
            'shipped, something already arbitrates -- the defect would not exist')
    end)
end

----------------------------------------------------------------------
-- [w1correction] the round's main product: a `limits` note checked
-- against the dump instead of inherited
----------------------------------------------------------------------

tests['[w1correction] two of GH #231 [W1]\'s five conjuncts ARE in the dump'] = function()
    local c = corpus()
    assert(c.units > 0, 'no units read')
    -- The claim was "NOT in any dump". These are the coverage counts that
    -- falsify it. Pinned so a dump change cannot turn a partial model into a
    -- silently claimed full one. [V2]
    --
    -- Ratchets, not equalities (GH #106 / GH #127 doctrine, tests/corpus_scale.lua).
    -- Every one of these is a SUM OVER FIXTURES -- this file's own `corpus()`
    -- sweeps `tests/fixtures/*.lua` and adds what each one carries -- so landing
    -- the next fixture raises them without anything they measure having moved.
    -- The falsification they exist for is a count going DOWN (a lost fixture, or
    -- these modifiers vanishing from the dump), and ratchet catches that exactly.
    -- The file-count line was the one the [detector] in test_corpus_scale.lua
    -- could see, because it is the corpus size itself; the three above it are the
    -- same defect in quantities that detector cannot name.
    cs.ratchet(c.with_mods, 433, 'units carrying `modifiers`')
    cs.ratchet(c.with_dmg,  181, 'units carrying `recent_damage`')
    cs.ratchet(c.units,    1050, 'archive unit count')
    cs.corpus(c.files, 'archive file count')
end

tests['[w1correction] GH #231\'s published table reproduces exactly, unmodelled'] = function()
    -- Reproduced FIRST, so the correction below is a delta against a number
    -- this file can show rather than one it remembers. GH #231 published
    -- 6 / 2 / 1 for (ally floor) / (+quiet) / (+self does NOT pre-empt).
    local n1 = count(function(r) return r.ally_missing_ok end)
    local n2 = count(function(r) return r.ally_missing_ok and r.quiet_ally end)
    local n3 = count(function(r)
        return r.ally_missing_ok and r.quiet_ally and not (r.self_fires and r.quiet_self)
    end)
    assert(#corpus().pairs == 73, 'the pair axis moved: ' .. #corpus().pairs)
    assert(n1 == 6 and n2 == 2 and n3 == 1, string.format(
        'GH #231 published 6/2/1; this census reads %d/%d/%d', n1, n2, n3))
end

tests['[w1correction] the correction decomposes onto ONE of the two conjuncts'] = function()
    -- ⚠ Written because a mutation SURVIVED: neutering the heal-modifier half
    -- of the corrected model changed nothing. GH #231's own lesson applies --
    -- the answer to a surviving mutation is not another assertion aimed at the
    -- mutation, it is to make the file say the thing that was silently true.
    -- Here that thing is a zero: on the pair axis the heal-modifier conjunct
    -- excludes NOTHING, and the whole 6 -> 3 delta is recent damage alone.
    local nBase, nHeal, nDmg = 0, 0, 0
    for _, r in ipairs(corpus().pairs) do
        if r.ally_missing_ok then
            nBase = nBase + 1
            local a_healed = r.ally_healed
            local a_hit    = r.ally_hit
            if a_healed then nHeal = nHeal + 1 end
            if a_hit    then nDmg  = nDmg  + 1 end
        end
    end
    assert(nBase == 6, 'pairs over the ally floor moved: ' .. nBase)
    assert(nDmg == 3, 'recent damage no longer accounts for the whole delta: ' .. nDmg)
    assert(nHeal == 0, 'the heal-modifier conjunct now excludes pairs: ' .. nHeal)
    -- and the zero above is about REACHABILITY, not about an empty dump: the
    -- archive really does carry these modifiers, just never on a pair that
    -- survives the other conjuncts. If this count ever reaches a pair, the
    -- assertion above turns red and the model stops being a no-op silently.
    assert(corpus().heal_units == 9,
        'units carrying one of the four heal modifiers moved: ' .. corpus().heal_units)
end

tests['[w1correction] modelling the two halves the top two rows'] = function()
    local n1 = count(function(r) return r.ally_missing_ok and r.ally_clean end)
    local n2 = count(function(r) return r.ally_missing_ok and r.ally_clean and r.quiet_ally end)
    local n3 = count(function(r)
        return r.ally_missing_ok and r.ally_clean and r.quiet_ally
           and not (r.self_fires and r.quiet_self)
    end)
    assert(n1 == 3 and n2 == 1 and n3 == 1, string.format(
        'corrected table expected 3/1/1, read %d/%d/%d', n1, n2, n3))
    -- The deepest row -- GH #231's CONTROL, the one its conclusion rested on --
    -- is unchanged. The correction narrows that round's domain numbers; it does
    -- not overturn its verdict, and this file must not be read as saying so.
end

----------------------------------------------------------------------
-- [domain] this lever's own axis, nested, three questions three numbers
----------------------------------------------------------------------

local function d1(r) return r.self_fires end
local function d2(r) return d1(r) and r.quiet_self end
local function d3(r) return d2(r) and r.self_clean end
local function d4(r) return d3(r) and r.quiet_ally end
local function d5(r) return d4(r) and r.ally_missing_ok end
local function d6(r) return d5(r) and r.ally_clean end

tests['[domain] the nesting down to this lever\'s own conjunct'] = function()
    assert(count(d1) == 9, 'self branch fires: ' .. count(d1))
    assert(count(d2) == 3, '+ holder quiet at 900: ' .. count(d2))
    assert(count(d3) == 2, '+ holder not healed/hit: ' .. count(d3))
    assert(count(d4) == 2, '+ holder quiet at 1000: ' .. count(d4))
    assert(count(d5) == 1, '+ ally over the ally floor: ' .. count(d5))
end

tests['[domain] end-to-end is 1 under GH #231\'s convention and 0 under the corrected one'] = function()
    -- The whole reason the [w1correction] rows above are not bookkeeping.
    local nOld = count(function(r) return d5(r) and dominates(r) end)
    local nNew = count(function(r) return d6(r) and dominates(r) end)
    assert(nOld == 1, 'expected 1 pair under the inherited convention, read ' .. nOld)
    assert(nNew == 0, 'expected 0 pairs once the ally guard is modelled, read ' .. nNew)
    -- and the single pair is the anchor, not some other frame
    for _, r in ipairs(corpus().pairs) do
        if d5(r) and dominates(r) then
            assert(r.holder == HOLDER and r.ally == ALLY,
                'the surviving pair is no longer the anchor: ' .. r.holder .. '/' .. r.ally)
            assert(r.ally_clean == false,
                'the anchor ally is no longer excluded by its own recent-damage guard')
        end
    end
end

tests['[domain] this lever proposes no admission and no wave, and says why'] = function()
    -- Zero end-to-end under the corrected convention. The control item that
    -- makes this a statement about THIS lever rather than about the branch:
    -- the branch's own ally path is reachable elsewhere in the archive.
    assert(count(function(r) return r.ally_missing_ok and r.ally_clean and r.quiet_ally end) == 1,
        'the branch itself is unreachable in this archive -- then the zero says nothing about this lever')
end

----------------------------------------------------------------------
-- [refusal] what the single-axis rules would have bought, written down
----------------------------------------------------------------------

tests['[refusal] the looser single-axis rules buy no more, and are refused anyway'] = function()
    -- GH #227 set the rule: a refusal must state the size of what it gave up,
    -- or it is not a refusal, it is an untested claim.
    local nDom   = count(function(r) return d5(r) and dominates(r) end)
    local nAbs   = count(function(r) return d5(r) and lower_abs(r) end)
    local nRatio = count(function(r) return d5(r) and lower_ratio(r) end)
    assert(nDom == 1 and nAbs == 1 and nRatio == 1, string.format(
        'expected 1/1/1 for dominance/absolute/ratio, read %d/%d/%d', nDom, nAbs, nRatio))
    -- On THIS archive the three rules are indistinguishable, so the corpus
    -- offers no reason to prefer any of them -- which is exactly why the choice
    -- was made on conservatism instead of on a reading. Had they differed, the
    -- dominance rule is the intersection and therefore still the smallest.
end

tests['[refusal] dominance is a subset of each single-axis rule, on every pair'] = function()
    for _, r in ipairs(corpus().pairs) do
        if dominates(r) then
            assert(lower_abs(r) and lower_ratio(r),
                'dominance fired where a single-axis rule did not: ' .. r.holder .. '/' .. r.ally)
        end
    end
end

----------------------------------------------------------------------
-- [model] the shipped guard vs the model, on a grid
--
-- Every assertion above this point either drives the guard on ONE frame or
-- exercises the model alone, so a guard whose arithmetic was rewritten -- the
-- two pools swapped in the cross-multiplication, say -- could stay green
-- throughout: the anchor happens to satisfy the wrong formula too. This is the
-- only place the two are made to agree on states the archive does not carry.
----------------------------------------------------------------------

-- The guard calls exactly two methods per hero, so a plain table is a
-- sufficient stand-in and the grid costs no mock world.
local function fake(nHealth, nMaxHealth)
    return {
        OriginalGetHealth    = function() return nHealth end,
        OriginalGetMaxHealth = function() return nMaxHealth end,
    }
end

tests['[model] guard and model agree on every state of a pinned grid'] = function()
    local POOLS = { 538, 692, 1000, 1229, 1455, 2566 }
    local STEPS = 24
    with(CAND, function(J)
        local nStates, nFired = 0, 0
        for _, mBot in ipairs(POOLS) do
            for _, mAlly in ipairs(POOLS) do
                for i = 0, STEPS do
                    for j = 0, STEPS do
                        local hBot  = math.floor(mBot  * i / STEPS)
                        local hAlly = math.floor(mAlly * j / STEPS)
                        nStates = nStates + 1
                        local r = { holder_hp = hBot, holder_max = mBot,
                                    ally_hp = hAlly, ally_max = mAlly }
                        local bWant = dominates(r)
                        local bGot  = J.ShouldYieldSalveToAlly(
                            fake(hBot, mBot), fake(hAlly, mAlly), true)
                        assert(bGot == bWant, string.format(
                            'guard/model disagree at bot %d/%d ally %d/%d: guard=%s model=%s',
                            hBot, mBot, hAlly, mAlly, tostring(bGot), tostring(bWant)))
                        if bWant then nFired = nFired + 1 end
                    end
                end
            end
        end
        assert(nStates == #POOLS * #POOLS * (STEPS + 1) * (STEPS + 1),
            'the grid did not sweep what it claims')
        assert(nStates == 22500, 'the swept state count moved: ' .. nStates)
        -- A grid on which the guard never fires would make the agreement above
        -- vacuous; a grid on which it always fires would too.
        assert(nFired > 0 and nFired < nStates,
            'the grid no longer straddles the guard: fired on ' .. nFired .. '/' .. nStates)
    end)
end

tests['[model] the guard rejects a non-positive pool rather than flipping'] = function()
    with(CAND, function(J)
        -- the cross-multiplication's direction is only valid for positive
        -- pools; the guard must refuse, not invert.
        assert(J.ShouldYieldSalveToAlly(fake(10, 0), fake(1, 100), true) == false,
            'the guard accepted a zero-pool bot')
        assert(J.ShouldYieldSalveToAlly(fake(10, 100), fake(1, 0), true) == false,
            'the guard accepted a zero-pool ally')
    end)
end

----------------------------------------------------------------------
-- [structural] the arithmetic, which needs no corpus at all
----------------------------------------------------------------------

tests['[structural] the guard is antisymmetric and never yields to an equal'] = function()
    -- Exhaustive over a grid, with the swept width pinned so that shrinking the
    -- bound cannot leave a subset silently green. (GH #231's second surviving
    -- mutation was exactly that.)
    local POOLS = { 500, 538, 692, 1000, 1229, 1455, 2566 }
    local STEPS = 40
    local nStates, nSelfYield = 0, 0
    for _, mA in ipairs(POOLS) do
        for _, mB in ipairs(POOLS) do
            for i = 1, STEPS do
                for j = 1, STEPS do
                    local hA = math.floor(mA * i / STEPS)
                    local hB = math.floor(mB * j / STEPS)
                    nStates = nStates + 1
                    local ab = (hB < hA) and (hB * mA < hA * mB)
                    local ba = (hA < hB) and (hA * mB < hB * mA)
                    assert(not (ab and ba), 'the guard yielded in both directions')
                    if mA == mB and hA == hB then
                        assert(not ab, 'the guard yielded to an identical hero')
                        nSelfYield = nSelfYield + 1
                    end
                end
            end
        end
    end
    assert(nStates == #POOLS * #POOLS * STEPS * STEPS, 'the grid did not sweep what it claims')
    assert(nStates == 78400, 'the swept state count moved: ' .. nStates)
    assert(nSelfYield == #POOLS * STEPS, 'the identical-hero diagonal was not swept: ' .. nSelfYield)
end

tests['[structural] equal ratios never yield, whatever the pools'] = function()
    -- The case the ratio axis alone would call a tie and the absolute axis
    -- would decide: a support at 10% of 700 and a carry at 10% of 2600. The
    -- dominance rule refuses both directions.
    for _, mA in ipairs({ 700, 1000, 2600 }) do
        for _, mB in ipairs({ 700, 1000, 2600 }) do
            for _, f in ipairs({ 0.1, 0.25, 0.5, 0.9 }) do
                local hA, hB = mA * f, mB * f
                assert(not ((hB < hA) and (hB * mA < hA * mB)),
                    'yielded on an exact ratio tie')
            end
        end
    end
end

return tests

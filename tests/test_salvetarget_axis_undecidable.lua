-- GH #242 -- the FOURTH and last unread place in X.ConsiderItemDesire["item_flask"]:
-- the ally branch's TARGET SELECTION, which picks the teammate with the lowest
-- ABSOLUTE current health rather than the lowest remaining RATIO.
--
-- The charter registered this as the next lever, together with a standing
-- objection that had to be answered before anything was landed. This file is
-- that answer, and the answer is DO NOT LAND IT. There is no gated id here and
-- no line of bots/ changed; the ruling is the deliverable, and this test is what
-- keeps it from being quietly re-opened.
--
-- ⚠ THE CRITERION THIS ROUND EXISTS TO WRITE DOWN.
-- The three preceding levers on this same function (`salvepool` GH #227,
-- `salveally` GH #231, `salveyield` GH #237) all ended in a change because a
-- construction was available: where two candidate readings of "who is worse
-- off" disagree and neither is derivable, act only under DOMINANCE -- the
-- intersection of the two candidate rules, which is the most conservative of
-- them by construction and fits no threshold.
--
-- THAT CONSTRUCTION IS UNAVAILABLE HERE, AND IT IS UNAVAILABLE BY ARITHMETIC.
-- Dominance needs a candidate that is worse than the incumbent's pick on BOTH
-- axes at once. The incumbent here IS the argmin of one of those axes, so no
-- candidate can be strictly lower on it. The intersection is empty for every
-- candidate set that exists or could exist -- not rare, EMPTY, and empty in the
-- `bbfight` sense rather than the "too thin to measure" sense.
--
-- Generalised ([criterion] below states it as a table over four incumbents):
--     the dominance construction can only fire against an incumbent that is
--     NOT the argmin of either competing axis.
-- `salveyield` fired precisely because its incumbent -- "the holder drinks it
-- himself" -- is a constant rule and therefore the argmin of neither axis. The
-- difference between that round and this one is structural, not a matter of how
-- hard anyone looked.
--
-- SO THE ONLY CHANGE AVAILABLE HERE IS A BARE CHOICE OF AXIS, i.e. a fit, which
-- is what the [refusal] row of tests/test_salvepool_missing_floor.lua exists to
-- forbid. And the objection shows the choice is not free even on the merits: the
-- salve is a FIXED-amount heal, so the ratio rule can hand it to the hero the
-- fixed amount helps least. [objection] pins that arithmetic parametrically, so
-- it does not depend on the patch's current salve value.
--
-- ⚠ AND A SECOND, SMALLER CRITERION (a near-miss this round actually had):
-- AN ARGMIN DISAGREEMENT COUNT IS NOT A DISAGREEMENT COUNT UNTIL TIES ARE
-- SEPARATED OUT. Swept ungated, the archive shows exactly one frame where the
-- two axes' argmins differ -- and on that frame both allies are at 100% health,
-- so the ratio axis is TIED and the "disagreement" is iteration order. Reported
-- raw it would have read "the archive does show the axes disagreeing", which is
-- the opposite of the truth. [ties] asserts both readings.
--
-- WHAT IS PINNED RATHER THAN ASSUMED:
--   [W1] Same modelling convention as GH #237 after its correction: the heal
--        modifiers and WasRecentlyDamagedByAnyHero ARE modelled where the dump
--        carries the field, and a unit missing the key is "unknown, not
--        excluded". IsIllusion / IsChanneling / the fountain guard are still not
--        in any dump, so every count here remains an UPPER bound on real
--        reachability -- which only strengthens a result whose content is a zero.
--   [W2] The end-to-end axis is the HOLDER FRAME (file x salve holder), not the
--        pair, because selection is a property of a SET: it can only discriminate
--        where two or more allies pass the gate on one frame. GH #231's lesson
--        applies in full -- the structural proof above is true on its own axis
--        and buys zero cells on this one, and those are two separate sentences.

package.path = 'tests/?.lua;' .. package.path
local cs = require('corpus_scale')

local AIUG = 'bots/ability_item_usage_generic.lua'
local JMZ  = 'bots/FunLib/jmz_func.lua'

-- The shipped constants of the branch, written out so the model is comparable
-- against the source rather than against a memory of it. [source] pins them.
local ALLY_FLOOR      = 550
local ALLY_POOL_RATIO = 0.55     -- the `salveally` armed form: Min(550, max*0.55)
local PAIR_DIST_MAX   = 700      -- the ally scan radius
local QUIET_RADIUS    = 1000     -- hNearbyEnemyHeroList, the ally branch's own
local ALLY_DMG_WINDOW = 3.0

local tests = {}

local function read_file(path)
    local f = assert(io.open(path, 'r'))
    local s = f:read('*a')
    f:close()
    return s
end

-- ⚠ A `find` on a source substring is a PIN only if the substring is UNIQUE in
-- the file, and this round's mutation batch is what proved it is not. Three of
-- four mutations of the salve's own selection lines SURVIVED, because the exact
-- same three-line block appears four times in this file (see [census]) and the
-- plain-text find matched a copy the mutation had not touched. Same family as
-- GH #237's `"10 failures"` contains `"0 failures"` lesson, one level up:
-- containment there, UNIQUENESS here. So every source pin below reads the
-- salve's own function body, sliced out first.
local slice_cache = nil
local function salve_body()
    if slice_cache ~= nil then return slice_cache end
    local src = read_file(AIUG)
    local i = src:find('X.ConsiderItemDesire["item_flask"] = function( hItem )', 1, true)
    assert(i ~= nil, 'the salve consider is gone from ' .. AIUG)
    -- the next consider, or the sibling lotus helper, whichever comes first
    local j = src:find('\nX.ConsiderItemDesire[', i + 1, true)
    local k = src:find('\nlocal function ConsiderHealingLotus', i + 1, true)
    if j == nil or (k ~= nil and k < j) then j = k end
    assert(j ~= nil, 'could not find the end of the salve consider')
    slice_cache = src:sub(i, j)
    -- anti-vacuum: a slice that collapsed would make every pin below pass or
    -- fail for the wrong reason.
    assert(#slice_cache > 800 and #slice_cache < 4000,
        'the salve slice is ' .. #slice_cache .. ' bytes -- that is not one consider')
    return slice_cache
end

--- Every place in AIUG that picks an ally by LOWEST CURRENT HEALTH, tagged with
--- the item whose consider it sits in. Used by [census]; also the reason the
--- pins above must slice.
local function selection_sites()
    local sites, sItem = {}, nil
    for line in read_file(AIUG):gmatch('[^\n]*') do
        local sFound = line:match('X%.ConsiderItemDesire%["([%w_]+)"%]')
        if sFound then sItem = sFound end
        local sGetter = line:match('if%(?%s*%w+:(%w*GetHealth)%(%) < nNeedHealAllyHealth')
        if sGetter then
            sites[#sites + 1] = { item = sItem, getter = sGetter }
        end
    end
    return sites
end

----------------------------------------------------------------------
-- The corpus. A fixture IS `return { ... }`, so the census costs one
-- dofile per file and never a mock world.
----------------------------------------------------------------------

local HEAL_MODS = {
    modifier_filler_heal                  = true,
    modifier_elixer_healing               = true,
    modifier_flask_healing                = true,
    modifier_juggernaut_healing_ward_heal = true,
}

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

-- [W1] "unknown, not excluded".
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

-- [W2] the unit of account is the HOLDER FRAME, because selection is a property
-- of a set. Each group carries every ally the branch's own 700 scan would see.
local corpus_cache = nil
local function corpus()
    if corpus_cache ~= nil then return corpus_cache end
    local groups, nFiles, nUnits, nPairs, nHealUnits = {}, 0, 0, 0, 0
    local nPoolMin, nPoolMax = math.huge, -math.huge
    local p = assert(io.popen('ls tests/fixtures/*.lua 2>/dev/null'))
    for path in p:lines() do
        local ok, fx = pcall(dofile, path)
        if ok and type(fx) == 'table' and fx.units then
            nFiles = nFiles + 1
            for _, u in ipairs(fx.units) do
                nUnits = nUnits + 1
                if healed(u) then nHealUnits = nHealUnits + 1 end
            end
            for _, h in ipairs(fx.units) do
                if h.alive and h.max_hp and h.max_hp > 0 and holds_salve(h) then
                    local bQuiet = true
                    for _, v in ipairs(fx.units) do
                        if v ~= h and v.alive and v.team ~= h.team
                            and dist(v, h) <= QUIET_RADIUS then bQuiet = false end
                    end
                    local g = { file = path, holder = h.name, quiet = bQuiet, allies = {} }
                    for _, a in ipairs(fx.units) do
                        if a ~= h and a.alive and a.team == h.team
                            and a.max_hp and a.max_hp > 0
                            and dist(a, h) <= PAIR_DIST_MAX
                        then
                            if a.max_hp < nPoolMin then nPoolMin = a.max_hp end
                            if a.max_hp > nPoolMax then nPoolMax = a.max_hp end
                            nPairs = nPairs + 1
                            g.allies[#g.allies + 1] = {
                                name  = a.name, hp = a.hp, max = a.max_hp,
                                -- the shipped ally gate, and the `salveally`-armed one
                                gate_ship  = (a.max_hp - a.hp) > ALLY_FLOOR,
                                gate_armed = (a.max_hp - a.hp)
                                             > math.min(ALLY_FLOOR, a.max_hp * ALLY_POOL_RATIO),
                                -- kept apart so [decompose] can split the guard
                                healed = healed(a),
                                hit    = hit_recently(a, ALLY_DMG_WINDOW),
                                clean  = (not healed(a))
                                         and (not hit_recently(a, ALLY_DMG_WINDOW)),
                            }
                        end
                    end
                    groups[#groups + 1] = g
                end
            end
        end
    end
    p:close()
    assert(nFiles > 0, 'no fixtures readable; every census below would be a vacuous pass')
    corpus_cache = { groups = groups, files = nFiles, units = nUnits, pairs = nPairs,
                     heal_units = nHealUnits, pool_min = nPoolMin, pool_max = nPoolMax }
    return corpus_cache
end

----------------------------------------------------------------------
-- The two candidate axes, and the selection rules built on them.
-- `first wins on tie` mirrors the shipped loop's strict `<`.
----------------------------------------------------------------------

local function argmin_abs(set)
    local best = nil
    for _, a in ipairs(set) do
        if best == nil or a.hp < best.hp then best = a end
    end
    return best
end

local function argmin_ratio(set)
    local best = nil
    for _, a in ipairs(set) do
        if best == nil or a.hp * best.max < best.hp * a.max then best = a end
    end
    return best
end

-- worse off on the absolute reading AND on the remaining-ratio reading: the
-- shipped `salveyield` predicate, reused verbatim in shape.
local function worse_on_both(x, y)
    return x.hp < y.hp and x.hp * y.max < y.hp * x.max
end

local function subset(g, fPred)
    local out = {}
    for _, a in ipairs(g.allies) do if fPred(a) then out[#out + 1] = a end end
    return out
end

local GATES = {
    { key = 'ship',        pred = function(a) return a.gate_ship end },
    { key = 'armed',       pred = function(a) return a.gate_armed end },
    { key = 'ship_clean',  pred = function(a) return a.gate_ship and a.clean end },
    { key = 'armed_clean', pred = function(a) return a.gate_armed and a.clean end },
}

----------------------------------------------------------------------
-- [source] -- the tree still says what this ruling is about
----------------------------------------------------------------------

-- ⚠ Containment, a third time in one round. `find(needle, 1, true)` is satisfied
-- by any line that CONTAINS the needle, so `x = h()` passes a pin written for it
-- even after it becomes `x = h() - 100` -- which is not an equivalent mutant, it
-- corrupts the running minimum. The repair is the same one the numeric pins got:
-- isolate the WHOLE line and compare it exactly, so containment cannot be the
-- thing that passes. (GH #237's `"0 failures"`; this file's own [census]; here.)
local function exact_line(body, sNeedle, sLabel)
    local i = body:find(sNeedle, 1, true)
    assert(i ~= nil, sLabel .. ': not found at all')
    local iStart = (body:sub(1, i):find('\n[^\n]*$')) or 0
    local sLine = body:sub(iStart + 1):match('^[^\n]*')
    return (sLine:gsub('^%s+', ''):gsub('%s+$', ''))
end

tests['[source] the selection is still argmin of ABSOLUTE current health'] = function()
    local src = salve_body()
    assert(exact_line(src, 'local nNeedHealAllyHealth = 99999', 'sentinel')
           == 'local nNeedHealAllyHealth = 99999',
        'the selection sentinel moved; re-read GH #242 before changing the rule')
    assert(exact_line(src, 'if( npcAlly:OriginalGetHealth() < nNeedHealAllyHealth )', 'comparison')
           == 'if( npcAlly:OriginalGetHealth() < nNeedHealAllyHealth )',
        'THE SELECTION RULE CHANGED. This file rules that the ratio rule must not '
        .. 'be landed here (GH #242): the dominance construction is empty against '
        .. 'an argmin incumbent, so any change is a bare choice of axis. Re-argue '
        .. 'it, do not re-baseline this line.')
    assert(exact_line(src, 'nNeedHealAllyHealth = npcAlly:OriginalGetHealth()', 'bookkeeping')
           == 'nNeedHealAllyHealth = npcAlly:OriginalGetHealth()',
        'the selection bookkeeping moved -- the running minimum is no longer the '
        .. 'selected ally\'s own health')
    -- the sentinel is a sentinel: it must precede the comparison, or the loop
    -- would compare against a value the first candidate had already set.
    assert(src:find('local nNeedHealAllyHealth = 99999', 1, true)
           < src:find('if( npcAlly:OriginalGetHealth() < nNeedHealAllyHealth )', 1, true),
        'the sentinel no longer precedes the comparison')
end

tests['[source] the selection line names one hero and no pool at all'] = function()
    local src = salve_body()
    local sLine = src:match('\n[^\n]-if%( npcAlly:OriginalGetHealth%(%)[^\n]-\n')
    assert(sLine ~= nil, 'could not isolate the selection line')
    -- The whole finding in one assertion: the comparison reads current health
    -- twice and a pool zero times. If a pool term ever appears on this line the
    -- axis was chosen, which is the thing being refused.
    assert(sLine:find('OriginalGetMaxHealth') == nil,
        'a pool term appeared on the selection line -- the axis was chosen: ' .. sLine)
    assert(select(2, sLine:gsub('%d', '')) == 0,
        'a number appeared on the selection line -- a threshold was fitted: ' .. sLine)
end

tests['[source] the scan radius, the gate, and the branch guard are as modelled'] = function()
    local body = salve_body()
    -- the radius is READ OUT of the tree and compared as a number, never
    -- concatenated into a plain find: `= 0.5` is a substring of `= 0.55`, and a
    -- pin written that way passes on a tree it was meant to reject. That is the
    -- fourth survivor this round's mutation batch turned up (M23), and it is the
    -- same containment shape as GH #237's `"0 failures"`.
    local nRadius = tonumber(body:match('J%.GetAlliesNearLoc%( bot:GetLocation%(%), (%d+) %)'))
    assert(nRadius == PAIR_DIST_MAX,
        'the ally scan radius is ' .. tostring(nRadius) .. ', modelled as ' .. PAIR_DIST_MAX)
    assert(body:find('and J.SalveAllyMissingEnough( npcAlly )', 1, true),
        'the ally gate is no longer J.SalveAllyMissingEnough')
    assert(body:find('local bAllyBranchOpen = hNeedHealAlly ~= nil and #hNearbyEnemyHeroList == 0', 1, true),
        'the ally branch firing condition moved')
    local nQuiet = tonumber(read_file(AIUG):match(
        'hNearbyEnemyHeroList = J%.GetNearbyHeroes%(bot, (%d+),'))
    assert(nQuiet == QUIET_RADIUS,
        'the ally branch quiet radius is ' .. tostring(nQuiet) .. ', modelled as ' .. QUIET_RADIUS)
end

tests['[source] the shipped floors this model reuses are unchanged'] = function()
    local src = read_file(JMZ)
    -- read out and compared numerically, for the containment reason above.
    local nFloor = tonumber(src:match('J%.SALVE_ALLY_MISSING_FLOOR%s*=%s*([%d%.]+)'))
    local nRatio = tonumber(src:match('J%.SALVE_ALLY_POOL_RATIO%s*=%s*([%d%.]+)'))
    assert(nFloor == ALLY_FLOOR,
        'the ally floor is ' .. tostring(nFloor) .. ', modelled as ' .. ALLY_FLOOR)
    assert(nRatio == ALLY_POOL_RATIO,
        'the salveally armed ratio is ' .. tostring(nRatio) .. ', modelled as ' .. ALLY_POOL_RATIO)
end

tests['[census] the absolute-health selection is a FILE-WIDE convention, not a salve quirk'] = function()
    -- The fact the broken pins turned up, and an independent third reason not to
    -- land the ratio rule here. FOUR consumable considers in this one file pick
    -- an ally by lowest absolute current health, using the identical three-line
    -- block. Changing the salve's copy alone would leave the file answering one
    -- question two ways -- which is precisely the complaint GH #227/#231 filed
    -- against the salve's THRESHOLDS ("one line, opposite meanings"). Whatever
    -- the right axis is, it is not a per-item choice.
    local sites = selection_sites()
    local seen = {}
    for _, s in ipairs(sites) do seen[s.item] = s.getter end
    assert(seen.item_flask == 'OriginalGetHealth',
        'the salve site is missing from the census: ' .. tostring(seen.item_flask))
    for _, sItem in ipairs({ 'item_essence_distiller', 'item_urn_of_shadows',
                            'item_polliwog_charm' }) do
        assert(seen[sItem] ~= nil,
            'a sibling absolute-health selection site vanished: ' .. sItem
            .. ' -- if it was converted to a ratio, GH #242 must be re-read, because '
            .. 'its whole point is that this axis is decided file-wide or not at all')
    end
    assert(#sites == 4, 'the selection-site census moved to ' .. #sites .. ' (was 4)')
    -- and one asymmetry recorded rather than fixed: three sites read the
    -- Original* getters (illusion- and buff-proof) and the fourth does not.
    -- Out of scope for this round, but it is not going to be noticed twice.
    assert(seen.item_polliwog_charm == 'GetHealth',
        'the polliwog site changed getter to ' .. tostring(seen.item_polliwog_charm)
        .. ' -- register it, this census claimed it was the odd one out')
end

tests['[source] this round introduced no gate and no candidate id'] = function()
    -- The ruling is "do not land it", so a soak id for it would be the ruling
    -- being ignored. Named explicitly so the absence is asserted, not assumed.
    local p = assert(io.popen('grep -rl "salvetarget" bots/ 2>/dev/null | head -5'))
    local sHits = p:read('*a')
    p:close()
    assert(sHits == '', 'a `salvetarget` id appeared in bots/: ' .. sHits)
end

----------------------------------------------------------------------
-- [dominance] -- the construction is empty against THIS incumbent,
-- by arithmetic, with no corpus involved
----------------------------------------------------------------------

tests['[dominance] nothing dominates the argmin of an axis it is the argmin of'] = function()
    local POOLS  = { 538, 692, 979, 1066, 1229, 1455, 1872, 2566 }
    local STEPS  = 12
    local nSets, nChecks, nDominating = 0, 0, 0
    -- every ordered pair of (pool, health) states, taken as a two-candidate set,
    -- then a three-candidate set built from the same grid.
    for _, mA in ipairs(POOLS) do
        for _, mB in ipairs(POOLS) do
            for i = 1, STEPS do
                for j = 1, STEPS do
                    local set = {
                        { hp = math.floor(mA * i / STEPS), max = mA },
                        { hp = math.floor(mB * j / STEPS), max = mB },
                    }
                    nSets = nSets + 1
                    local pick = argmin_abs(set)
                    for _, x in ipairs(set) do
                        nChecks = nChecks + 1
                        if worse_on_both(x, pick) then nDominating = nDominating + 1 end
                    end
                end
            end
        end
    end
    -- the swept width is pinned so shrinking the bound cannot leave a subset
    -- silently green (GH #231's second surviving mutation).
    assert(nSets == #POOLS * #POOLS * STEPS * STEPS, 'the grid did not sweep what it claims')
    assert(nSets == 9216, 'the swept set count moved: ' .. nSets)
    assert(nChecks == 2 * nSets, 'not every candidate was checked: ' .. nChecks)
    assert(nDominating == 0,
        'a candidate dominated the absolute-argmin -- the arithmetic of this '
        .. 'ruling is wrong, re-read it: ' .. nDominating)
end

tests['[dominance] and it is empty against the ratio-argmin too'] = function()
    -- Stated for the mirror rule as well, because the criterion below is about
    -- argmins in general and not about this particular axis.
    local POOLS = { 538, 979, 1229, 1872, 2566 }
    local STEPS = 14
    local nSets, nDominating = 0, 0
    for _, mA in ipairs(POOLS) do
        for _, mB in ipairs(POOLS) do
            for i = 1, STEPS do
                for j = 1, STEPS do
                    local set = {
                        { hp = math.floor(mA * i / STEPS), max = mA },
                        { hp = math.floor(mB * j / STEPS), max = mB },
                    }
                    nSets = nSets + 1
                    local pick = argmin_ratio(set)
                    for _, x in ipairs(set) do
                        -- dominance is symmetric in the two axes, so the same
                        -- predicate serves; only the incumbent changed.
                        if worse_on_both(x, pick) then nDominating = nDominating + 1 end
                    end
                end
            end
        end
    end
    assert(nSets == #POOLS * #POOLS * STEPS * STEPS, 'the grid did not sweep what it claims')
    assert(nSets == 4900, 'the swept set count moved: ' .. nSets)
    assert(nDominating == 0, 'a candidate dominated the ratio-argmin: ' .. nDominating)
end

tests['[control] the same construction is NOT empty against a constant incumbent'] = function()
    -- Without this row the two zeros above would be indistinguishable from a
    -- broken `worse_on_both`. The witness is GH #237's archive anchor: the salve
    -- holder is Tidehunter at 80/1455 and the teammate is Silencer at 43/1229 --
    -- worse on both readings, which is exactly why `salveyield` exists.
    local holder = { hp = 80, max = 1455 }
    local ally   = { hp = 43, max = 1229 }
    assert(worse_on_both(ally, holder),
        'the dominance predicate no longer fires on the salveyield anchor -- the '
        .. 'zeros above are then about the predicate, not about the incumbent')
    -- and the same set under an argmin incumbent yields nothing, on the very
    -- same two heroes: the difference is the incumbent alone.
    local set = { holder, ally }
    local pick = argmin_abs(set)
    for _, x in ipairs(set) do
        assert(not worse_on_both(x, pick),
            'the argmin incumbent was dominated on the anchor set')
    end
end

tests['[criterion] the rule stated as a table over four incumbents'] = function()
    -- THE REUSABLE SENTENCE: dominance can only fire against an incumbent that
    -- is the argmin of NEITHER competing axis. Four incumbent rules, two of
    -- which are argmins, are swept over the same sets; the two argmins buy zero
    -- and the two non-argmins buy a positive number. A future round facing this
    -- shape can read its own case off this table instead of rediscovering it.
    local POOLS = { 538, 979, 1229, 2566 }
    local STEPS = 10
    local INCUMBENTS = {
        { key = 'argmin_abs',   argmin = true,  pick = argmin_abs },
        { key = 'argmin_ratio', argmin = true,  pick = argmin_ratio },
        -- not argmins: "whoever the loop saw first", and "a hero outside the set"
        { key = 'first_seen',   argmin = false, pick = function(set) return set[1] end },
        { key = 'outsider',     argmin = false,
          pick = function(_set) return { hp = 1200, max = 1500 } end },
    }
    local nHits, nSets = {}, 0
    for _, inc in ipairs(INCUMBENTS) do nHits[inc.key] = 0 end
    for _, mA in ipairs(POOLS) do
        for _, mB in ipairs(POOLS) do
            for i = 1, STEPS do
                for j = 1, STEPS do
                    local set = {
                        { hp = math.floor(mA * i / STEPS), max = mA },
                        { hp = math.floor(mB * j / STEPS), max = mB },
                    }
                    nSets = nSets + 1
                    for _, inc in ipairs(INCUMBENTS) do
                        local pick = inc.pick(set)
                        for _, x in ipairs(set) do
                            if worse_on_both(x, pick) then
                                nHits[inc.key] = nHits[inc.key] + 1
                            end
                        end
                    end
                end
            end
        end
    end
    assert(nSets == #POOLS * #POOLS * STEPS * STEPS, 'the grid did not sweep what it claims')
    assert(nSets == 1600, 'the swept set count moved: ' .. nSets)
    for _, inc in ipairs(INCUMBENTS) do
        if inc.argmin then
            assert(nHits[inc.key] == 0,
                inc.key .. ' is an argmin yet was dominated ' .. nHits[inc.key] .. ' times')
        else
            assert(nHits[inc.key] > 0,
                inc.key .. ' is not an argmin yet was never dominated -- the sweep is '
                .. 'not exercising the construction at all')
        end
    end
end

----------------------------------------------------------------------
-- [objection] -- the charter's registered objection, as arithmetic
----------------------------------------------------------------------

tests['[objection] the ratio rule can pick the hero a fixed heal helps least'] = function()
    -- The salve restores a FLAT amount, so "who is worse off" and "who gains
    -- most" are different questions. Written parametrically over the heal amount
    -- H so this row does not depend on the patch's current salve value.
    local support = { hp = 100, max = 692 }
    local core    = { hp = 300, max = 2600 }
    local set     = { support, core }

    -- the two rules genuinely disagree here: this is a real disagreement and
    -- not a tie, which [ties] below shows is a distinction that matters.
    assert(argmin_abs(set)   == support, 'the absolute rule stopped picking the support')
    assert(argmin_ratio(set) == core,    'the ratio rule stopped picking the core')
    assert(support.hp * core.max ~= core.hp * support.max, 'the two are a ratio tie here')

    -- and for every fixed heal in the range a salve plausibly occupies, the
    -- ratio rule's pick ends the heal in worse shape than the absolute rule's.
    local nChecked = 0
    for H = 200, 800, 25 do
        local fSupport = math.min(support.max, support.hp + H) / support.max
        local fCore    = math.min(core.max,    core.hp    + H) / core.max
        assert(fSupport > fCore,
            'at H=' .. H .. ' the ratio rule\'s pick is no longer the worse-served one')
        nChecked = nChecked + 1
    end
    assert(nChecked == 25, 'the heal sweep did not cover what it claims: ' .. nChecked)
end

----------------------------------------------------------------------
-- [domain] -- what the selection rule can actually decide on the archive
----------------------------------------------------------------------

tests['[domain] the selection loop never has two candidates to choose between'] = function()
    local c = corpus()
    -- Selection is a property of a SET: with 0 or 1 gate-passing allies the two
    -- axes return the same hero (or none), so no axis choice is observable.
    -- Stated as the MAXIMUM eligible set size rather than as a count over some
    -- threshold, so the row carries no free constant a mutation could relax:
    -- `== 1` says both that the branch does select somebody (not a dead sweep)
    -- and that it never once has a second candidate to weigh.
    for _, gate in ipairs(GATES) do
        local nMaxSet = 0
        for _, g in ipairs(c.groups) do
            local k = #subset(g, gate.pred)
            if k > nMaxSet then nMaxSet = k end
        end
        -- a claim whose whole content is a zero stays an EQUALITY (corpus_scale
        -- doctrine): it must go red the day the corpus grows a counter-example.
        assert(nMaxSet == 1,
            'gate world `' .. gate.key .. '` now peaks at ' .. nMaxSet .. ' eligible '
            .. 'all(y/ies) on one holder frame. At 0 the branch is unreachable and '
            .. 'this file measures nothing; at 2+ the selection axis became '
            .. 'observable and GH #242 must be re-read.')
    end
end

tests['[domain] the singleton counts, so the zero is not a dead sweep'] = function()
    local c = corpus()
    local nSingle = {}
    for _, gate in ipairs(GATES) do
        local n = 0
        for _, g in ipairs(c.groups) do
            if #subset(g, gate.pred) == 1 then n = n + 1 end
        end
        nSingle[gate.key] = n
    end
    -- Sums over fixtures, so ratchets. These are what makes the zero above a
    -- statement about SET SIZE rather than about the branch being unreachable:
    -- the branch does select somebody, it just never has a choice.
    cs.ratchet(nSingle.ship,        6, 'holder frames with exactly one shipped-gate ally')
    cs.ratchet(nSingle.armed,       8, 'holder frames with exactly one armed-gate ally')
    cs.ratchet(nSingle.ship_clean,  3, 'holder frames, shipped gate + clean, one ally')
    cs.ratchet(nSingle.armed_clean, 5, 'holder frames, armed gate + clean, one ally')
    -- arming `salveally` widens the eligible set, as its own [source] claims;
    -- asserted here because this file is the first place both worlds are swept
    -- side by side and could have silently read the same number.
    assert(nSingle.armed > nSingle.ship,
        'arming salveally no longer widens the eligible set: '
        .. nSingle.armed .. ' vs ' .. nSingle.ship)
    -- and the clean guard has bite: without it the two gate worlds read 6 and 8,
    -- so `clean` is not a decoration that could be neutered unnoticed.
    assert(nSingle.ship_clean  < nSingle.ship,
        'the clean guard stopped excluding anything under the shipped gate')
    assert(nSingle.armed_clean < nSingle.armed,
        'the clean guard stopped excluding anything under the armed gate')
end

tests['[decompose] the clean guard\'s bite is ALL recent-damage and NO heal-modifier'] = function()
    -- GH #237's method lesson, applied before it could bite again: a conjunct
    -- that quietly excludes nothing will let a mutation of it pass, and the fix
    -- is to WRITE THE ZERO DOWN rather than to add another assertion around it.
    -- Here the split is total -- heal modifiers exclude 0 holder frames and
    -- recent damage does the whole 6 -> 3 and 8 -> 5 -- so both numbers are
    -- asserted, and the zero is qualified by a reachability control below.
    local c = corpus()
    local function single(fPred)
        local n = 0
        for _, g in ipairs(c.groups) do
            if #subset(g, fPred) == 1 then n = n + 1 end
        end
        return n
    end
    local nShip      = single(function(a) return a.gate_ship end)
    local nShipNoHeal = single(function(a) return a.gate_ship and not a.healed end)
    local nShipNoHit  = single(function(a) return a.gate_ship and not a.hit end)
    assert(nShipNoHeal == nShip,
        'the heal-modifier conjunct now excludes holder frames (' .. nShip .. ' -> '
        .. nShipNoHeal .. ') -- the registered zero moved, re-read it')
    assert(nShipNoHit < nShip,
        'the recent-damage conjunct stopped excluding anything: ' .. nShipNoHit)

    -- THE CONTROL that makes the zero mean something. The archive really does
    -- carry these modifiers -- on 9 units -- so "excludes 0" is a statement
    -- about which units are REACHABLE on the holder-frame axis, not a statement
    -- that the dump is missing the field. Without this row the zero would be
    -- indistinguishable from a modelling gap.
    cs.ratchet(c.heal_units, 9, 'archive units carrying one of the four heal modifiers')
end

tests['[reachable] the multi-ally SHAPE does exist -- the gate is what empties it'] = function()
    local c = corpus()
    local nMulti, nMaxSet = 0, 0
    for _, g in ipairs(c.groups) do
        if #g.allies >= 2 then nMulti = nMulti + 1 end
        if #g.allies > nMaxSet then nMaxSet = #g.allies end
    end
    -- This is the control the [domain] zero needs. GH #231's lesson: a zero has
    -- to say WHICH axis it sits on. Ungated, the archive carries frames with two
    -- and three allies inside the scan radius, so "the loop never chooses" is a
    -- fact about the ally FLOOR, not about salve holders standing alone.
    cs.ratchet(nMulti, 4, 'holder frames with 2+ allies inside the 700 scan (ungated)')
    cs.ratchet(nMaxSet, 3, 'largest ungated ally set on one holder frame')
end

tests['[ties] the archive\'s only axis disagreement is a tie, not a disagreement'] = function()
    local c = corpus()
    local nRawDisagree, nRealDisagree = 0, 0
    for _, g in ipairs(c.groups) do
        if #g.allies >= 2 then
            local a1, a2 = argmin_abs(g.allies), argmin_ratio(g.allies)
            if a1 ~= a2 then
                nRawDisagree = nRawDisagree + 1
                -- a real disagreement requires the ratio axis to have a STRICT
                -- winner; equal ratios make the argmin iteration order, not a
                -- reading of the frame.
                if a1.hp * a2.max ~= a2.hp * a1.max then
                    nRealDisagree = nRealDisagree + 1
                end
            end
        end
    end
    -- Both readings are asserted, which is the whole point of this row: the raw
    -- count is what a careless sweep reports, and it says the opposite thing.
    cs.ratchet(nRawDisagree, 1, 'holder frames where the two argmins differ (raw)')
    assert(nRealDisagree == 0,
        'the archive now carries a NON-TIED disagreement between the two axes ('
        .. nRealDisagree .. ') -- the ruling in GH #242 rests on there being none, '
        .. 're-read it')
end

----------------------------------------------------------------------
-- [ratchet] -- the corpus this file measured, so a later reader can tell
-- growth from behaviour movement
----------------------------------------------------------------------

tests['[ratchet] the corpus this reading was taken over'] = function()
    local c = corpus()
    cs.corpus(c.files, 'archive file count')
    cs.ratchet(c.units,   1050, 'archive unit count')
    cs.ratchet(#c.groups,  121, 'salve holder frames')
    cs.ratchet(c.pairs,     73, 'holder x ally pairs inside the 700 scan')
    -- the pool range the ally axis actually spans, which is what makes the
    -- ratio/absolute question non-trivial in the first place.
    assert(c.pool_min <= 582, 'the smallest ally pool rose above 582: ' .. c.pool_min)
    assert(c.pool_max >= 1872, 'the largest ally pool fell below 1872: ' .. c.pool_max)
end

return tests

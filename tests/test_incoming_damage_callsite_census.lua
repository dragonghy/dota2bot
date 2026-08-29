-- [detector] Who else was living inside "GetActualIncomingDamage answers 0"?
--
-- THE BATON.  On 2026-08-29 the hero stream fixed a mock default: the generic
-- `^Get` fallthrough in `tests/mock/bot_api.lua` answered **0** for
-- `GetActualIncomingDamage`, i.e. "no amount of damage of any type ever reaches
-- this unit".  The finding was written up, correctly, as *every magical and
-- physical kill-confirm in the tree was structurally false on every frame*, and
-- the round closed with an explicit next step it could not afford to run:
-- ENUMERATE the call sites and name which other assertions' green was that zero.
-- This file is that enumeration.  (Charter `iterations/streams/hero.md` -44;
-- the fix and its ratchet: `tests/test_mock_incoming_damage_default.lua`,
-- `iterations/state.json:mockdmg_ZERO_20260829`.)
--
-- WHAT THE ENUMERATION CHANGES ABOUT THE FINDING.  Two things, both of which
-- make the blast radius wider than "kill-confirms declined":
--
--   1. THE ZERO HAD TWO POLARITIES, AND ONLY ONE WAS NAMED.  32 of the 41 call
--      expressions put the call result where a zero makes the predicate FALSE
--      (a kill-confirm that never confirms, a threat guard that never trips) --
--      that is the half already written up.  But **2 sites put it on the other
--      side of the comparison**, where a zero makes the predicate TRUE:
--
--        mode_retreat_generic.lua     `nDamage / botTarget:GetHealth() < 0.88`
--                                     -> X.RetreatWhenTowerTargetedDesire()
--                                        returned 0.9 unconditionally
--        ability_item_usage_generic   `... < bot:GetHealth()`
--                                     -> the metamorphic_mandible desire
--                                        returned DESIRE_HIGH unconditionally
--
--      This matters for reading the fix's fallout, not just its history: on the
--      always-FALSE half the fix can only turn a red green or leave it, but on
--      these two it can turn a **green red**, and nobody was watching that
--      direction.  A test that asserted "the retreat desire is 0.9 here" or
--      "the mandible wants to fire here" may have been reading the mock.
--
--      DRIVEN SINCE (`tests/test_zero_true_sites_driven.lua`, the -45 baton),
--      and the drive amends this paragraph in one direction: the polarity
--      reading is RIGHT, but on a fixture frame the fix turns neither green red,
--      because each site has a SECOND unmodelled zero UPSTREAM of the call (the
--      subject's own outgoing damage estimate; every enemy's attack damage and
--      speed).  Both branches still fire unconditionally with the fixed default
--      in place -- so "may have been reading the mock" is still true today, only
--      via a different mock datum.  Supply the upstream datum before citing
--      either path.
--
--   2. A FURTHER 4 SITES FAILED AS "PICK NOBODY", NOT AS "DECLINE".  They are
--      argmax/argmin selection loops scoring candidates BY the incoming damage.
--      Under the zero every candidate scored 0, the running best started at 0,
--      and `>` never fired -- so the loop returned nil having examined a full
--      list.  `FunLib/minion_lib/utils.lua` is the sharp one: it *divides* by
--      the call (`GetHealth() / GetActualIncomingDamage(3000, ...)`), so under
--      the zero every candidate scored `inf` (`0/0 -> nan` for a corpse) and
--      `killUnitTime < minKillTime` was false for arithmetic reasons.  §5 drives
--      that one end to end -- it is the only class member with a proof rather
--      than a reading, and `minion_lib/` has no other test in the repo.
--
-- AND ONE CORRECTION TO A NUMBER THREE FILES REPEAT.  "42 call sites under
-- bots/" is the output of `grep -c`, i.e. a count of LINES THAT MENTION THE
-- IDENTIFIER.  It is not the number of call sites (40 lines call it; two of the
-- 42 are prose -- the `hero_axe.lua` header comments), and it is not the number
-- of calls (41; `hero_silencer.lua` has two on one line).  §1 derives all three
-- numbers instead of asserting the folklore one.  The direction of the error is
-- the harmless one, but the census below is per-CALL, so the two counts have to
-- be told apart before anything can be checked against them.
--
-- LIMITS (say them here rather than let a reader infer precision).
--   * The class of each site is a READING of the enclosing expression, made by
--     hand and recorded below; only §5 is driven.  A reading can be wrong in a
--     way this file cannot catch.
--   * "Comment" means a whole-line `--`.  A call with a trailing comment on the
--     same line is still a call and is counted; an identifier mentioned in a
--     trailing comment would be miscounted.  Neither shape exists today (§1
--     would go red if one appeared, which is the point).
--   * This census says which assertions COULD have been green off the zero.  It
--     does not say which ones were: that is the ~100min full suite (GH #124),
--     and this file is cheap precisely so it does not have to be.

package.path = 'tests/?.lua;' .. package.path
local api = require('mock.bot_api')

local CALL = 'GetActualIncomingDamage'

--- What the OLD zero did to the predicate this call feeds.
local ZERO_FALSE  = 'ZERO_FALSE'   -- the branch could never fire
local ZERO_PURE   = 'ZERO_PURE'    -- ditto, but the damage handed in is PURE:
                                   -- J.CanKillTarget short-circuits PURE before
                                   -- the engine call, these do not, so the
                                   -- "every non-PURE kill-confirm" phrasing in
                                   -- the mock header does not cover them.
local ZERO_TRUE   = 'ZERO_TRUE'    -- the branch fired unconditionally
local ZERO_NOBODY = 'ZERO_NOBODY'  -- a selection loop that then picked nobody
local ZERO_VALUE  = 'ZERO_VALUE'   -- a returned estimate, judged by its callers

--- One entry per CALL EXPRESSION.  Keyed by a distinctive substring of the call
--- rather than a line number: line pins in files everybody edits are GH #221,
--- and this file would be the third to relearn it.  `n` is how many times the
--- key is expected to appear (the two jmz_func projectile/activity helpers are
--- byte-identical lines).
local CENSUS = {
    -- ---- the half already written up: a zero makes the predicate false ----
    { 'BotLib/hero_witch_doctor.lua',  'botTarget:GetActualIncomingDamage( bot:GetOffensivePower() * 2, DAMAGE_TYPE_ALL )', ZERO_FALSE },
    { 'BotLib/hero_sniper.lua',        'nEnemy:GetActualIncomingDamage( zAbilityDamage + nDamage, DAMAGE_TYPE_MAGICAL )', ZERO_FALSE },
    { 'BotLib/hero_legion_commander.lua', 'GetActualIncomingDamage( nDamage, nDamageType )', ZERO_FALSE },
    { 'BotLib/hero_legion_commander.lua', 'npcEnemy:GetActualIncomingDamage( nDamage, DAMAGE_TYPE_PHYSICAL )', ZERO_FALSE },
    { 'BotLib/hero_chaos_knight.lua',  'nEnemysHeroesInCastRange[i]:GetActualIncomingDamage( nDamage, DAMAGE_TYPE_MAGICAL )', ZERO_FALSE },
    { 'FunLib/rubick_hero/chaos_knight.lua', 'nEnemysHeroesInCastRange[i]:GetActualIncomingDamage( nDamage, DAMAGE_TYPE_MAGICAL )', ZERO_FALSE },
    { 'BotLib/hero_zuus.lua',          'targetRanged:GetActualIncomingDamage( nDamage + targetRanged:GetHealth()', ZERO_FALSE },
    { 'BotLib/hero_zuus.lua',          'e:GetActualIncomingDamage( nEstDamage * 2.28, nDamageType )', ZERO_FALSE },
    { 'BotLib/hero_crystal_maiden.lua', 'npcTarget:GetActualIncomingDamage( bot:GetOffensivePower() * 1.5, DAMAGE_TYPE_MAGICAL )', ZERO_FALSE },
    { 'FunLib/rubick_hero/crystal_maiden.lua', 'npcTarget:GetActualIncomingDamage( bot:GetOffensivePower() * 1.5, DAMAGE_TYPE_MAGICAL )', ZERO_FALSE },
    { 'BotLib/hero_viper.lua',         'nWeakestEnemyHeroInCastRange:GetActualIncomingDamage(nDamage * nDuration, DAMAGE_TYPE_MAGICAL)', ZERO_FALSE },
    { 'BotLib/hero_dazzle.lua',        'botTarget:GetActualIncomingDamage(nDamage, DAMAGE_TYPE_ALL) / bot:GetHealth()', ZERO_FALSE },
    { 'BotLib/hero_silencer.lua',      'unit:GetActualIncomingDamage( nAttackDamage, DAMAGE_TYPE_PHYSICAL )', ZERO_FALSE },
    { 'mode_team_roam_generic.lua',    'nCreep:GetActualIncomingDamage(nDamage, DAMAGE_TYPE_PHYSICAL) + J.GetCreepAttackProjectileWillRealDamage', ZERO_FALSE },
    { 'FunLib/jmz_func.lua',           'return npcTarget:GetActualIncomingDamage( dmg, dmgType ) >= npcTarget:GetHealth()', ZERO_FALSE },
    { 'FunLib/jmz_func.lua',           'local nTotalDamage = npcTarget:GetActualIncomingDamage( dmg, dmgType ) + nRealBonus', ZERO_FALSE },
    { 'FunLib/jmz_func.lua',           'nRealPhysicalDamge = npcTarget:GetActualIncomingDamage', ZERO_FALSE },
    { 'FunLib/jmz_func.lua',           'nRealMagicalDamge = npcTarget:GetActualIncomingDamage', ZERO_FALSE },
    { 'FunLib/jmz_func.lua',           'local nRealDamage = npcTarget:GetActualIncomingDamage( EstDamage, nDamageType )', ZERO_FALSE },
    { 'FunLib/override_generic/mode_attack_generic.lua', 'creepDmg = creepDmg + (bot:GetActualIncomingDamage', ZERO_FALSE },
    { 'FunLib/override_generic/mode_attack_generic.lua', 'unitDamage = unitDamage + bot:GetActualIncomingDamage', ZERO_FALSE },
    { 'FunLib/aba_push.lua',           'local bDangerous = bot:GetActualIncomingDamage', ZERO_FALSE },
    { 'FunLib/aba_push.lua',           'totalDamage = totalDamage + hUnit:GetActualIncomingDamage(', ZERO_FALSE },
    { 'mode_retreat_generic.lua',      'local towerDamage = bot:GetActualIncomingDamage', ZERO_FALSE },
    { 'mode_retreat_generic.lua',      'creepDamage = creepDamage + bot:GetActualIncomingDamage', ZERO_FALSE },
    { 'mode_retreat_generic.lua',      'local illusionDamage = bot:GetActualIncomingDamage', ZERO_FALSE },
    { 'mode_retreat_generic.lua',      'local golemsDamage = bot:GetActualIncomingDamage', ZERO_FALSE },
    { 'mode_retreat_generic.lua',      'local spiderlingsDamage = bot:GetActualIncomingDamage', ZERO_FALSE },
    { 'mode_retreat_generic.lua',      'local eidolonDamage = bot:GetActualIncomingDamage', ZERO_FALSE },
    { 'ability_item_usage_generic.lua', 'if bot:GetHealth() < bot:GetActualIncomingDamage( nProDamage', ZERO_FALSE },

    -- ---- PURE damage handed straight to the engine call ----
    { 'BotLib/hero_silencer.lua',      'unit:GetActualIncomingDamage( nAbilityDamage, DAMAGE_TYPE_PURE )', ZERO_PURE },
    { 'FunLib/jmz_func.lua',           'nRealPureDamge = npcTarget:GetActualIncomingDamage', ZERO_PURE },

    -- ---- the OTHER polarity: a zero SATISFIES the predicate ----
    -- `cmp` is the comparison the zero satisfies. It is pinned separately
    -- because on the retreat site it lives on the NEXT line, which is exactly
    -- the shape a one-line reading would miss.
    { 'mode_retreat_generic.lua',      'nDamage = botTarget:GetActualIncomingDamage(nDamage, DAMAGE_TYPE_ALL)', ZERO_TRUE,
      cmp = 'nDamage / botTarget:GetHealth() < 0.88' },
    { 'ability_item_usage_generic.lua', 'if bot:GetActualIncomingDamage(enemyDamage * 1.5, DAMAGE_TYPE_PHYSICAL) < bot:GetHealth() then', ZERO_TRUE,
      cmp = '< bot:GetHealth() then' },

    -- ---- selection loops that then picked nobody ----
    { 'BotLib/hero_largo.lua',         'local creepScore = creep:GetActualIncomingDamage', ZERO_NOBODY },
    { 'BotLib/hero_morphling.lua',     'local enemyHeroDamage = enemyHero:GetActualIncomingDamage', ZERO_NOBODY },
    { 'BotLib/hero_morphling.lua',     'local creepDamage = creep:GetActualIncomingDamage', ZERO_NOBODY },
    { 'FunLib/minion_lib/utils.lua',   'unit:GetHealth() / unit:GetActualIncomingDamage( 3000', ZERO_NOBODY },

    -- ---- estimates returned to a caller ----
    { 'mode_team_roam_generic.lua',    'return nCreep:GetActualIncomingDamage(nDamage, DAMAGE_TYPE_PHYSICAL);', ZERO_VALUE },
    -- J.GetCreepAttackProjectileWillRealDamage / ...ActivityWillRealDamage: two
    -- byte-identical return lines.  Their zero fed BOTH sides of WillKillTarget:
    -- it emptied `nRealBonus` from the damage sum (false-ward) and made that
    -- function's second conjunct `nRealBonus < targetHealth - 1` true-ward.
    { 'FunLib/jmz_func.lua',           'return nUnit:GetActualIncomingDamage( nDamage, DAMAGE_TYPE_PHYSICAL )', ZERO_VALUE, 2 },
}

--- Every `.lua` under bots/, relative to bots/.
local function bots_files()
    local out = {}
    local p = io.popen("find bots -name '*.lua' -type f | sort")
    for line in p:lines() do out[#out + 1] = line end
    p:close()
    assert(#out > 100, 'the file walk found ' .. #out .. ' lua files under bots/, expected the whole tree')
    return out
end

local function read(path)
    local f = assert(io.open(path), 'cannot read ' .. path)
    local s = f:read('*a')
    f:close()
    return s
end

--- Count occurrences of `needle` in `hay` (plain, non-overlapping).
local function count(hay, needle)
    local n, at = 0, 1
    while true do
        local i = hay:find(needle, at, true)
        if not i then return n end
        n = n + 1
        at = i + 1
    end
end

--- Walk bots/ and split mentions of the engine call into calls and prose.
local function scan()
    local r = { lines = 0, code_lines = 0, comment_lines = 0, calls = 0, by_file = {} }
    for _, path in ipairs(bots_files()) do
        for line in read(path):gmatch('[^\n]*') do
            local hits = count(line, CALL)
            if hits > 0 then
                r.lines = r.lines + 1
                if line:match('^%s*%-%-') then
                    r.comment_lines = r.comment_lines + 1
                else
                    r.code_lines = r.code_lines + 1
                    r.calls = r.calls + hits
                    local rel = path:gsub('^bots/', '')
                    r.by_file[rel] = (r.by_file[rel] or 0) + hits
                end
            end
        end
    end
    return r
end

local tests = {}

tests['[detector] the three counts are derived, and "42 call sites" is none of them'] = function()
    local r = scan()
    -- Derivation, not folklore: lines that mention it = code lines + prose lines,
    -- and calls = code lines + however many share a line.
    assert(r.lines == r.code_lines + r.comment_lines,
        'line bookkeeping: ' .. r.lines .. ' ~= ' .. r.code_lines .. ' + ' .. r.comment_lines)
    assert(r.comment_lines >= 1,
        'the prose mentions are the reason the grep count is not the call count; '
        .. 'if they are gone, say so in the header rather than deleting this line')
    assert(r.calls >= r.code_lines,
        'a line cannot hold fewer than one call')
    assert(r.calls > r.code_lines,
        'hero_silencer.lua puts two calls on one line -- that is why calls > lines')
    -- The published figure. Kept as a NAMED comparison so a reader who arrives
    -- from the mock header or from state.json sees which number they were given.
    local published = 42
    assert(r.lines == published,
        'the published 42 is a grep line count; it now reads ' .. r.lines
        .. ' -- update the mock header, this file and state.json together')
    assert(r.calls ~= published,
        'the whole point of this section: the call count (' .. r.calls
        .. ') is not the grep count (' .. published .. ')')
end

tests['[detector] every call expression is claimed by exactly one census entry'] = function()
    local r = scan()
    local claimed, seen = 0, {}
    for _, e in ipairs(CENSUS) do
        local file, key, class, n = e[1], e[2], e[3], e[4] or 1
        assert(class, 'entry for ' .. file .. ' has no class')
        assert(key:find(CALL, 1, true),
            'a census key must name the call it classifies: ' .. file .. ' | ' .. key)
        local tag = file .. '||' .. key
        assert(not seen[tag], 'duplicate census entry: ' .. tag)
        seen[tag] = true
        local hits = count(read('bots/' .. file), key)
        assert(hits == n,
            'census key matched ' .. hits .. ' times, expected ' .. n .. ' in '
            .. file .. ' | ' .. key .. ' -- the source moved under the census')
        claimed = claimed + n
    end
    assert(claimed == r.calls,
        'the census claims ' .. claimed .. ' call expressions but bots/ has '
        .. r.calls .. '. A NEW CALL SITE MUST BE CLASSIFIED: read what the old '
        .. 'mock zero would have done to the predicate it feeds (see the header '
        .. 'classes) and add a row. This assertion is meant to break on growth.')
end

tests['[detector] the always-TRUE polarity is exactly two sites, and they are these'] = function()
    local by_class, zero_true = {}, {}
    for _, e in ipairs(CENSUS) do
        local n = e[4] or 1
        by_class[e[3]] = (by_class[e[3]] or 0) + n
        if e[3] == ZERO_TRUE then zero_true[#zero_true + 1] = e[1] end
    end
    -- The headline. If a third site joins this class the fix's fallout in the
    -- green->red direction grew, and whoever added it should say where.
    assert(#zero_true == 2, 'expected 2 ZERO_TRUE sites, found ' .. #zero_true)
    table.sort(zero_true)
    assert(zero_true[1] == 'ability_item_usage_generic.lua', 'got ' .. zero_true[1])
    assert(zero_true[2] == 'mode_retreat_generic.lua', 'got ' .. zero_true[2])
    -- Both put the call on the SMALL side of a `<`, which is precisely what
    -- makes a zero satisfy the comparison. The comparison is pinned per entry
    -- and looked for in the statement the call opens, not just its line: on the
    -- retreat site the `<` is on the line AFTER the call.
    for _, e in ipairs(CENSUS) do
        if e[3] == ZERO_TRUE then
            assert(e.cmp, 'a ZERO_TRUE entry must pin the comparison it satisfies: ' .. e[1])
            local src = read('bots/' .. e[1])
            local at = assert(src:find(e[2], 1, true))
            local window = src:sub(at, at + 200)
            assert(window:find(e.cmp, 1, true),
                'the pinned comparison is no longer within the statement in '
                .. e[1] .. ': ' .. e.cmp)
        end
    end
    assert(by_class[ZERO_FALSE] == 30, 'ZERO_FALSE = ' .. tostring(by_class[ZERO_FALSE]))
    assert(by_class[ZERO_PURE] == 2, 'ZERO_PURE = ' .. tostring(by_class[ZERO_PURE]))
    assert(by_class[ZERO_NOBODY] == 4, 'ZERO_NOBODY = ' .. tostring(by_class[ZERO_NOBODY]))
    assert(by_class[ZERO_VALUE] == 3, 'ZERO_VALUE = ' .. tostring(by_class[ZERO_VALUE]))
end

tests['[detector] the PURE sites are outside the mock header\'s "non-PURE" phrasing'] = function()
    -- J.CanKillTarget returns before the engine call for PURE damage, which is
    -- where "every non-PURE kill-confirm" comes from. These two hand PURE damage
    -- straight to the engine call, so the zero reached them anyway.
    local jmz = read('bots/FunLib/jmz_func.lua')
    assert(jmz:find('if dmgType == DAMAGE_TYPE_PURE then', 1, true),
        'J.CanKillTarget must keep its PURE short-circuit -- it is the reason the '
        .. '"non-PURE" phrasing exists')
    local n = 0
    for _, e in ipairs(CENSUS) do
        if e[3] == ZERO_PURE then
            n = n + 1
            local line = read('bots/' .. e[1]):match(e[2]:gsub('[%(%)%.%%%+%-%*%?%[%]%^%$]', '%%%0') .. '[^\n]*')
            assert(line and line:find('DAMAGE_TYPE_PURE', 1, true),
                'a ZERO_PURE site must pass PURE into the call: ' .. tostring(line))
        end
    end
    assert(n == 2, 'expected 2 PURE call sites, found ' .. n)
end

tests['[detector] ZERO_NOBODY, driven: minion target selection returned nil for every list'] = function()
    -- The one class member with a proof rather than a reading. `U.GetWeakest`
    -- divides by the call, so the old zero made every candidate score `inf` and
    -- `killUnitTime < minKillTime` false for arithmetic reasons -- a full list in,
    -- nobody out. minion_lib/ has no other test in the repo, so this behaviour
    -- was never once observed.
    api.reset_modules()
    api.install({ bot = api.MakeHero('npc_dota_hero_zuus') })
    local U = require(GetScriptDirectory() .. '/FunLib/minion_lib/utils')

    local function target(hp, name)
        return api.MakeUnit({ GetHealth = hp, GetUnitName = name, IsAlive = true,
            IsNull = false, CanBeSeen = true, IsInvulnerable = false,
            IsAttackImmune = false })
    end
    local tough, weak = target(900, 'tough'), target(300, 'weak')

    local picked = U.GetWeakest({ tough, weak })
    assert(picked ~= nil, 'with the fixed default the loop must pick somebody')
    assert(picked:GetUnitName() == 'weak',
        'and it must be the one that dies soonest, got ' .. picked:GetUnitName())

    -- Reinstate the old world on these two units only, via the same __spec door
    -- a test would use to model real armour.
    rawget(tough, '__spec').GetActualIncomingDamage = function() return 0 end
    rawget(weak, '__spec').GetActualIncomingDamage = function() return 0 end
    assert(U.GetWeakest({ tough, weak }) == nil,
        'under the legacy zero the same non-empty list yields no target at all')
end

tests['[detector] the census names the file the fix lives in, so a revert is loud'] = function()
    -- Cheap cross-reference: if the mock default is reverted, the ratchet in
    -- test_mock_incoming_damage_default.lua goes red on the fix and this file
    -- goes red on the pointer. Two files, one revert.
    local mock = read('tests/mock/bot_api.lua')
    assert(mock:find("if key == 'GetActualIncomingDamage' then", 1, true),
        'the explicit default is gone -- every row of this census is live again')
    local u = api.MakeUnit({ GetHealth = 100 })
    assert(u:GetActualIncomingDamage(250, 'DAMAGE_TYPE_MAGICAL') == 250,
        'and the default must still answer the damage itself')
end

return tests

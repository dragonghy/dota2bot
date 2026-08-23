-- [hero] Axe t15: +8 Battle Hunger damage-per-second  vs  +10 Berserker's Call
-- armor.  The last undecided pair of the focus-five talent ladder re-anchor
-- (stream backlog section 18; the other four were settled 2026-08-22).
--
-- VERDICT 2026-08-23: NOT FLIPPED.  The row stays {0,10} = index [3], the
-- Battle Hunger dps talent.  This file exists so that verdict is not
-- re-litigated on taste -- the same job tests/test_cm_t10_payoff.lua does for
-- Crystal Maiden's t10.
--
-- THE RULER (the one the other four pairs were decided with): payoff
-- REACHABILITY.  Not "which single payout is bigger" but "how much of the game
-- is each talent's payoff condition actually true for".  A talent on an ability
-- that is up a quarter of the time buys a quarter as many chances to pay.
--
-- WHAT IS MEASURED HERE, both sides through the same procedure
--   (1) STRUCTURAL CEILING -- duration / cooldown at the rank each ability holds
--       at level 15, where the rank comes from THIS FILE'S OWN build row, parsed
--       out of hero_axe.lua rather than restated (the M13 lesson).  Battle
--       Hunger runs 12s on a 5s cooldown at rank 4: ceiling 1.00, i.e. it can be
--       live continuously.  Berserker's Call runs 3.0s on a 12s cooldown at
--       rank 4: ceiling 0.25.
--   (2) CORPUS -- the modifiers this repo's fixtures actually dumped.  On the 16
--       Axe frames that carry modifier data, an enemy hero is carrying
--       modifier_axe_battle_hunger on 5, and Axe is carrying
--       modifier_axe_berserkers_call_armor on 1.
--   (3) CHANNEL HEALTH -- each side's observed count against its own structural
--       ceiling summed over the same 16 frames (GH #115's rule: a small number
--       has to be readable as SATURATED or as UNDERPOWERED, not guessed at).
--       The Call side is at roughly half its ceiling with a ceiling of ~1.9
--       frames; the Battle Hunger side is at roughly a third of a ceiling of
--       14 frames.  So the gap is not the bot under-using Call -- Call simply
--       cannot be up more.
--   (4) CONSUMER ASYMMETRY -- whether either talent also moves a DECISION.
--       damage_per_second is read by X.ConsiderW and multiplied into the damage
--       claim handed to J.WillMagicKillTarget; bonus_armor is read by nothing.
--
-- HONEST BOUNDS (all four cut against the strength of this reading, and the
-- first one is load-bearing)
--   * NO FRAME IN THIS CORPUS IS IN DOMAIN.  The highest level any Axe reaches
--     in a fixture is 14; a t15 talent exists at 15.  Everything above is a
--     PROXY measured one level below the talent, and it is pinned as such.
--   * n = 1 on the Call side.  One frame against a ceiling of ~1.9 frames
--     carries no statistical weight at all; it corroborates the structural
--     arithmetic, it does not establish anything by itself.
--   * The comparison of magnitudes (about +96 raw magic damage over a full
--     Battle Hunger, versus the physical damage +10 armor turns away during a
--     3s taunt) is arithmetic on the datafeed, NOT measured here: fixtures do
--     not dump armor, and recent_damage does not carry a damage type.
--   * Battle Hunger "deals damage over time until the target kills another
--     unit" -- so its 12s is an upper bound and the dps talent's realised
--     payoff is smaller than 12 x 8.  Nothing in this corpus measures how much
--     smaller (see the elapsed test at the bottom for why the obvious way to
--     measure it does not work).
--   * Pick-rate corroboration could not be fetched again (dotabuff 403).
--     Condition (c) rests on the mechanism, not on a guide.
--
-- THE OTHER SIDE'S BEST CASE, stated so the next reader does not have to
-- reconstruct it: [4] is the bigger RELATIVE buff (15 -> 25 bonus armor, +67%,
-- against 24 -> 32 dps, +33%), a taunt guarantees that the attacks its armor
-- reduces actually arrive, and Axe's innate One Man Army converts 50% of his
-- armor into Strength while no ally is within 700 -- which the farming branch
-- of X.ConsiderQ (taunt 3+ neutrals, requires no enemy hero within 1600) puts
-- him in.  It loses on frequency, not on quality.
--
-- EXTERNAL ANCHORS -- https://www.dota2.com/datafeed/herodata?language=english&hero_id=2
-- read 2026-08-23.  Fixtures do not carry ability specs, so these cannot be
-- derived from the corpus.

package.path = 'tests/?.lua;' .. package.path
local api = require('mock.bot_api')

local HERO_SRC = 'bots/BotLib/hero_axe.lua'

-- datafeed hero_id=2, 2026-08-23.  Index = ability rank.
local CALL = {
    cooldown = { 18, 16, 14, 12 },
    duration = { 2.1, 2.4, 2.7, 3.0 },
    bonus_armor = { 12, 13, 14, 15 },
}
local HUNGER = {
    cooldown = { 20, 15, 10, 5 },
    duration = { 12, 12, 12, 12 },
    damage_per_second = { 12, 16, 20, 24 },
}
local TALENT_ARMOR_BONUS = 10   -- special_bonus_unique_axe_7,  [4]
local TALENT_DPS_BONUS   = 8    -- special_bonus_unique_axe,    [3]
local TALENT_LEVEL       = 15

local tests = {}

local function read_file(path)
    local fh = assert(io.open(path, 'r'), 'cannot open ' .. path)
    local s = fh:read('*a')
    fh:close()
    return s
end

local function live_lines(src)
    local out = {}
    for line in src:gsub('%-%-%[%[.-%]%]', ''):gmatch('[^\n]+') do
        if not line:match('^%s*%-%-') then out[#out + 1] = line end
    end
    return out
end

--- The rank each ability holds at `level`, computed from hero_axe.lua's own
--- build row.  The row lists sAbilityList indices in level order, and
--- hero_axe.lua binds abilityQ = sAbilityList[1] (Berserker's Call) and
--- abilityW = sAbilityList[2] (Battle Hunger) -- both of which are read out of
--- the source here too, so re-pointing a handle moves this number.
local function ranks_at(level)
    local src = read_file(HERO_SRC)
    local row = src:match('local tAllAbilityBuildList = {%s*{(.-)}')
    assert(row, HERO_SRC .. ' has no tAllAbilityBuildList literal')
    local order = {}
    for n in row:gmatch('%d+') do order[#order + 1] = tonumber(n) end
    assert(#order >= level, 'the build row is only ' .. #order .. ' levels long')

    local slot = {}
    for name, idx in src:gmatch('local (ability[QWER])%s*=%s*bot:GetAbilityByName%(%s*sAbilityList%[(%d)%]') do
        slot[name] = tonumber(idx)
    end
    assert(slot.abilityQ and slot.abilityW,
        HERO_SRC .. ' no longer binds abilityQ/abilityW from sAbilityList')

    local count = {}
    for i = 1, level do count[order[i]] = (count[order[i]] or 0) + 1 end
    return count[slot.abilityQ] or 0, count[slot.abilityW] or 0
end

--- Fraction of wall-clock an ability can be live at a given rank, if it were
--- re-cast the instant it came off cooldown.
local function ceiling(spec, rank)
    if rank == 0 then return 0 end
    local up = spec.duration[rank] / spec.cooldown[rank]
    return (up > 1) and 1 or up
end

local function fixture_paths()
    local p = assert(io.popen('ls tests/fixtures'))
    local files = {}
    for f in p:lines() do
        if f:match('^f_.*%.lua$') then files[#files + 1] = 'tests/fixtures/' .. f end
    end
    p:close()
    table.sort(files)
    return files
end

local function has_modifier(unit, sName)
    for _, m in ipairs(unit.modifiers or {}) do
        if m.name == sName then return m end
    end
    return nil
end

local function ability_rank(unit, sName)
    for _, a in ipairs(unit.abilities or {}) do
        if a.name == sName then return a.level or 0 end
    end
    return 0
end

--- One pass over the corpus.  Only fixtures that actually carry modifier data
--- can answer the uptime question; the rest are counted apart so a zero is
--- never read as "it never happened" when it means "it was never dumped".
local function scan()
    local r = {
        fixtures = 0, with_modifiers = 0,
        axe_frames = 0, axe_frames_with_modifiers = 0,
        max_level = 0, in_domain = 0,
        hunger_live = 0, call_live = 0,
        hunger_ceiling = 0, call_ceiling = 0,
        overrun = {},
    }
    for _, path in ipairs(fixture_paths()) do
        local fx = dofile(path)
        if type(fx) == 'table' and fx.units then
            r.fixtures = r.fixtures + 1
            local axe, enemies, bMods = nil, {}, false
            for _, u in ipairs(fx.units) do
                if u.modifiers ~= nil then bMods = true end
                if u.name == 'npc_dota_hero_axe' and u.alive then axe = u end
            end
            if bMods then r.with_modifiers = r.with_modifiers + 1 end
            if axe ~= nil then
                r.axe_frames = r.axe_frames + 1
                if (axe.level or 0) > r.max_level then r.max_level = axe.level end
                if (axe.level or 0) >= TALENT_LEVEL then r.in_domain = r.in_domain + 1 end
                if bMods then
                    r.axe_frames_with_modifiers = r.axe_frames_with_modifiers + 1
                    for _, u in ipairs(fx.units) do
                        if u.team ~= axe.team then enemies[#enemies + 1] = u end
                    end

                    local nCall = ability_rank(axe, 'axe_berserkers_call')
                    local nHunger = ability_rank(axe, 'axe_battle_hunger')
                    r.call_ceiling = r.call_ceiling + ceiling(CALL, nCall)
                    r.hunger_ceiling = r.hunger_ceiling + ceiling(HUNGER, nHunger)

                    local mArmor = has_modifier(axe, 'modifier_axe_berserkers_call_armor')
                    if mArmor ~= nil then
                        r.call_live = r.call_live + 1
                        if nCall > 0 and (mArmor.elapsed or 0) + (mArmor.remaining or 0)
                            > CALL.duration[nCall] + 0.05 then
                            r.overrun[#r.overrun + 1] = path .. ' call'
                        end
                    end
                    local bHunger = false
                    for _, e in ipairs(enemies) do
                        local m = has_modifier(e, 'modifier_axe_battle_hunger')
                        if m ~= nil then
                            bHunger = true
                            if nHunger > 0 and (m.elapsed or 0) + (m.remaining or 0)
                                > HUNGER.duration[nHunger] + 0.05 then
                                r.overrun[#r.overrun + 1] = path .. ' ' .. e.name
                            end
                        end
                    end
                    if bHunger then r.hunger_live = r.hunger_live + 1 end
                end
            end
        end
    end
    return r
end

local CORPUS = scan()

-- ---------------------------------------------------------------------------
-- 1. What the row selects, and that the reasoning travels with it.

tests['[hero] axe t15 still selects [3] +8 Battle Hunger dps'] = function()
    local rows = {}
    local body = read_file(HERO_SRC):match('local tTalentTreeList = {(.-)\n}')
    assert(body, HERO_SRC .. ' has no tTalentTreeList literal')
    for tier, a, b in body:gmatch("%['(t%d+)'%]%s*=%s*{%s*(%d+)%s*,%s*(%d+)%s*}") do
        rows[tier] = { tonumber(a), tonumber(b) }
    end
    api.reset_modules()
    api.install({ bot = api.MakeHero('npc_dota_hero_axe') })
    local J = require(GetScriptDirectory() .. '/FunLib/jmz_func')
    local pick = J.Skill.GetTalentBuild(rows)[2]
    assert(pick == 3,
        'axe now takes talent index ' .. pick .. ' at level 15, not [3] '
        .. 'special_bonus_unique_axe (+8 Battle Hunger dps).  Index [4] is '
        .. 'special_bonus_unique_axe_7 (+10 Berserker\'s Call armor), which this '
        .. 'file adjudicated on 2026-08-23 and did NOT take.  If you are flipping '
        .. 'it, re-take the two readings below first -- the verdict rested on '
        .. 'Battle Hunger being live about 5x as often, and on Berserker\'s Call '
        .. 'already sitting near its own structural ceiling.')
end

tests['[hero] the axe t15 verdict is written into the hero file, not only here'] = function()
    local src = read_file(HERO_SRC)
    assert(src:find('t15', 1, true), HERO_SRC .. ' no longer mentions t15 at all')
    assert(src:find('special_bonus_unique_axe_7', 1, true),
        HERO_SRC .. ' no longer names the talent it rejected at t15.  A talent row '
        .. 'is an ungated, shipped change; the stream charter requires the reasoning '
        .. 'to live next to it, so the next reader does not re-derive it.')
    assert(not src:find('needs its own work unit', 1, true),
        HERO_SRC .. ' still says the t15 pair needs its own work unit.  That work '
        .. 'unit ran on 2026-08-23 -- replace the note with the verdict.')
end

-- ---------------------------------------------------------------------------
-- 2. Structural ceiling: the half of the argument that does not need a corpus.

tests['[hero] axe t15: both abilities are rank 4 by level 15, read from the build row'] = function()
    local nCall, nHunger = ranks_at(TALENT_LEVEL)
    assert(nHunger == 4, 'Battle Hunger is rank ' .. nHunger .. ' at level '
        .. TALENT_LEVEL .. ', not 4.  The talent adds a flat ' .. TALENT_DPS_BONUS
        .. ' dps, so the rank decides what fraction that is -- re-take the reading.')
    assert(nCall == 4, 'Berserker\'s Call is rank ' .. nCall .. ' at level '
        .. TALENT_LEVEL .. ', not 4.  Its rank sets both the duration and the '
        .. 'cooldown that the uptime ceiling is computed from.')
end

tests['[hero] axe t15: Battle Hunger can be live 4x as much of the game as Berserker\'s Call'] = function()
    local nCall, nHunger = ranks_at(TALENT_LEVEL)
    local cCall, cHunger = ceiling(CALL, nCall), ceiling(HUNGER, nHunger)
    assert(math.abs(cHunger - 1.00) < 0.01,
        'Battle Hunger uptime ceiling is now ' .. cHunger .. ', not 1.00 (12s '
        .. 'duration on a 5s cooldown).  Re-read the datafeed.')
    assert(math.abs(cCall - 0.25) < 0.01,
        'Berserker\'s Call uptime ceiling is now ' .. cCall .. ', not 0.25 (3.0s '
        .. 'duration on a 12s cooldown).  Re-read the datafeed.')
    assert(cHunger >= 4 * cCall,
        'the uptime ratio that carried the t15 verdict has collapsed: Battle '
        .. 'Hunger ' .. cHunger .. ' vs Berserker\'s Call ' .. cCall .. '.  The '
        .. 'verdict was "the dps talent gets about four times as many chances to '
        .. 'pay"; if that is no longer true the pair is open again.')
end

tests['[hero] axe t15: the relative size of each talent, which is the OTHER side\'s argument'] = function()
    local nCall, nHunger = ranks_at(TALENT_LEVEL)
    local rDps = TALENT_DPS_BONUS / HUNGER.damage_per_second[nHunger]
    local rArmor = TALENT_ARMOR_BONUS / CALL.bonus_armor[nCall]
    -- Pinned deliberately the "wrong" way round: the rejected talent IS the
    -- bigger relative buff, and a reading that forgot to say so would be
    -- arguing against a strawman.
    assert(rArmor > rDps,
        'the +10 Call armor talent is no longer the bigger relative buff '
        .. '(armor +' .. string.format('%.0f%%', rArmor * 100) .. ' vs dps +'
        .. string.format('%.0f%%', rDps * 100) .. ').  It used to be, and the '
        .. 't15 verdict rejected it anyway on frequency -- if it is now smaller '
        .. 'on both axes the verdict is only more settled, but say so.')
    assert(math.abs(rDps - 1 / 3) < 0.01 and math.abs(rArmor - 2 / 3) < 0.01,
        'expected +33% dps and +67% armor at rank 4; got '
        .. string.format('%.2f / %.2f', rDps, rArmor))
end

-- ---------------------------------------------------------------------------
-- 3. Corpus channel, and its health.

tests['[hero] axe t15 corpus: Battle Hunger is live on 5 axe frames, Call armor on 1'] = function()
    assert(CORPUS.axe_frames == 26,
        'the corpus now holds ' .. CORPUS.axe_frames .. ' live-Axe frames, not 26. '
        .. 'The t15 reading is a count over exactly these frames -- re-take it '
        .. '(this test does the counting; just update the three numbers together).')
    assert(CORPUS.axe_frames_with_modifiers == 16,
        'modifier data now covers ' .. CORPUS.axe_frames_with_modifiers
        .. ' of the Axe frames, not 16.  That is the denominator of both counts below.')
    assert(CORPUS.hunger_live == 5,
        'Battle Hunger is live on ' .. CORPUS.hunger_live .. ' Axe frames, not 5.')
    assert(CORPUS.call_live == 1,
        'Berserker\'s Call armor is live on ' .. CORPUS.call_live .. ' Axe frames, not 1.')
    assert(CORPUS.hunger_live > CORPUS.call_live,
        'the corpus no longer corroborates the structural ceiling: Battle Hunger '
        .. CORPUS.hunger_live .. ' frames vs Call armor ' .. CORPUS.call_live .. '.')
end

tests['[hero] axe t15 corpus health: Call is near its ceiling, Battle Hunger is not'] = function()
    -- GH #115: a small count has to be readable.  Call being live on 1 of 16
    -- frames is not the bot neglecting it -- summed over the ranks these frames
    -- actually held, Call could not have been live on much more than 2.
    assert(math.abs(CORPUS.call_ceiling - 1.94) < 0.05,
        'the summed Berserker\'s Call uptime ceiling over the modifier-carrying '
        .. 'Axe frames is now ' .. string.format('%.2f', CORPUS.call_ceiling)
        .. ', not ~1.94.  This is the number that makes "live on 1 frame" read as '
        .. 'SATURATED rather than as NEGLECTED.')
    assert(math.abs(CORPUS.hunger_ceiling - 14.00) < 0.05,
        'the summed Battle Hunger uptime ceiling is now '
        .. string.format('%.2f', CORPUS.hunger_ceiling) .. ', not ~14.00.')
    assert(CORPUS.call_live / CORPUS.call_ceiling > CORPUS.hunger_live / CORPUS.hunger_ceiling,
        'the direction that settled t15 has reversed.  It was: Call realises a '
        .. 'LARGER share of its (tiny) ceiling than Battle Hunger does of its '
        .. '(large) one -- so the gap between them is not slack the bot could '
        .. 'take up by casting Call more, it is the ceiling itself.')
end

tests['[hero] axe t15 is measured OUT OF DOMAIN: no fixture Axe ever reaches level 15'] = function()
    assert(CORPUS.max_level == 14,
        'the highest Axe level in the corpus is now ' .. CORPUS.max_level
        .. ', not 14.  If it is >= 15 the t15 reading can finally be taken IN '
        .. 'domain, which is strictly better than the proxy this file pins -- '
        .. 're-take it and say so.')
    assert(CORPUS.in_domain == 0,
        CORPUS.in_domain .. ' Axe frames are now at level >= ' .. TALENT_LEVEL
        .. '.  Every number in this file was measured below the level at which '
        .. 'either talent exists; that caveat is load-bearing and has to be '
        .. 'restated or retired deliberately.')
end

-- ---------------------------------------------------------------------------
-- 4. Consumer asymmetry -- only one of the two talents also moves a decision.

tests['[hero] axe t15: the dps talent feeds a kill predicate, the armor talent feeds nothing'] = function()
    local nDps, nArmor = 0, 0
    for _, line in ipairs(live_lines(read_file(HERO_SRC))) do
        if line:find('damage_per_second', 1, true) then nDps = nDps + 1 end
        if line:find('bonus_armor', 1, true) then nArmor = nArmor + 1 end
    end
    assert(nDps == 1,
        'hero_axe.lua reads damage_per_second on ' .. nDps .. ' live lines, not 1. '
        .. 'That single read is X.ConsiderW multiplying it by the duration into '
        .. 'the damage claim it hands J.WillMagicKillTarget -- so the dps talent '
        .. 'is not purely an engine effect, it also widens a kill predicate that '
        .. 'already claims a whole 12s DoT as if it lands now.  That is a COST of '
        .. 'keeping [3], recorded here on purpose.')
    assert(nArmor == 0,
        'hero_axe.lua now reads bonus_armor on ' .. nArmor .. ' live lines.  It '
        .. 'read it on none when t15 was adjudicated, which is why the armor '
        .. 'talent was a pure engine effect with no decision-layer risk.  A new '
        .. 'consumer changes that side of the ledger.')
end

-- ---------------------------------------------------------------------------
-- 5. Two facts about the corpus itself that this work unit turned up.

tests['[harness] fixtures DO carry modifiers -- the "dumper does not dump them" claim is stale'] = function()
    -- Recorded 2026-08-23.  Several stream notes (backlog 3, 18) say modifier
    -- state is invisible to fixtures and park work on that basis; fixtures cut
    -- from 2026-08-19 onward carry modifiers with name/remaining/elapsed/stacks,
    -- and this whole file is built on them.  Older fixtures do not, so a
    -- corpus-wide zero still has to be split by coverage -- which is exactly
    -- what CORPUS.with_modifiers is for.
    assert(CORPUS.with_modifiers >= 45,
        'only ' .. CORPUS.with_modifiers .. ' of ' .. CORPUS.fixtures
        .. ' fixtures carry modifier data; it was 45 of 101 on 2026-08-23 and '
        .. 'coverage should only grow.  If it shrank, a regenerated fixture lost '
        .. 'the field and every uptime reading built on it is now under-counting.')
    assert(CORPUS.with_modifiers < CORPUS.fixtures,
        'every fixture now carries modifier data.  Good -- but the split that '
        .. 'this file uses to keep a "never observed" honest is gone, so drop '
        .. 'the coverage denominator rather than leaving it silently trivial.')
end

tests['[harness] modifier `elapsed` is NOT time-since-application'] = function()
    -- npc_dota_hero_lich carries modifier_axe_battle_hunger with elapsed 13.1
    -- and remaining 9.6 -- 22.7s of a 12s debuff.  Battle Hunger does not stack
    -- (should_stack 0 in the datafeed), so a re-cast REFRESHES it, and `elapsed`
    -- keeps counting from the first application while `remaining` restarts.
    -- Anything that computes "how long has this been running" as elapsed, or
    -- "how long will it have run" as elapsed+remaining, is wrong for every
    -- refreshable modifier.  Only `remaining` is safe.
    assert(#CORPUS.overrun >= 1,
        'no modifier instance in the corpus now has elapsed + remaining greater '
        .. 'than its own duration.  That over-run is the evidence that `elapsed` '
        .. 'survives a refresh -- if it is gone, either the dumper changed or the '
        .. 'frame did, and the warning above should be re-checked before some '
        .. 'other reading starts trusting elapsed.')
end

return tests

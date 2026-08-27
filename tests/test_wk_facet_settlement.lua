-- [hero] Wraith King's t20/t25 pair, 2026-08-27 -- the FACET blocker settled,
-- and both rows KEPT.  This is the last hero of the TALENTPRICE baton (GH #238
-- section 6), and the only one that shipped a written refusal to price:
--
--     "Note both of his t20/t25 alternatives at [2] and [6] are FACET rows, and
--      nothing in this repo reads which facet the game rolled -- settle that
--      before pricing the pair."   -- hero_skeleton_king.lua, until this round
--
-- WHAT SETTLED IT (tools/agent/facet_census.py, over the game's own
-- npc_heroes.txt -- the same file this project already takes talent slot order
-- from, GH #214):
--
--   * 0 of 339 facet entries in the WHOLE ROSTER name a special_bonus_* row or
--     an AbilityIndex inside the talent run (10..17).  A facet block carries
--     Icon / Color / GradientID / Deprecated and at most an `Abilities`
--     sub-block that GRANTS an ability.  No facet can move a talent slot for
--     any hero, so the blocker never applied -- to Wraith King or to the other
--     four.  Section 1.
--   * Wraith King has exactly two facet entries and BOTH are `Deprecated true`,
--     so there is no roll to read in the first place.  Neither have the other
--     four focus heroes: zero live facets between the five.  Section 2.
--   * The deprecated pair is load-bearing history, not trivia.  One granted
--     skeleton_king_bone_guard (which is why Bone Guard is a plain Ability2
--     today) and one granted skeleton_king_spectral_blade -- the MECHANISM for
--     a fact this repo had only observed, that the name resolves to nil on
--     every load.  Section 3.
--
-- WHY THAT MATTERS TO THE PRICE, and not only to tidiness: hero_skeleton_king
-- binds `talent6 = bot:GetAbilityByName( sTalentList[6] )` and reads
-- `talent6:IsTrained()` twice inside X.ConsiderW as a bank-threshold bypass.  A
-- facet-dependent slot 6 would make that bypass mean different things in
-- different games.  Section 1 is what says it cannot.
--
-- THE PRICE, pinned so it is not re-litigated on taste (sections 4 and 5):
--   t20 KEEPS [6] special_bonus_unique_wraith_king_facet_3 (+5 Bone Guard
--       skeletons spawned) over [5] special_bonus_attack_speed_50.  REACHABILITY:
--       [6] is the only talent in this hero's tree the decision layer reads, and
--       what it unblocks is the bank threshold this file's own GH #17 block
--       argues is near-unreachable.  Moving to [5] would freeze
--       talent6:IsTrained() false forever -- Lion's GH #166 hazard -- and throw
--       away the fix as well as the wiring.
--   t25 KEEPS [7] ..._wraith_king_10 (Mortal Strike cooldown 5 -> 3) over [8]
--       ..._wraith_king_4 (Reincarnation casts Wraithfire Blast).  Neither is
--       read anywhere, so size decides: [7] is a RATE paid on every attack, [8]
--       is an EVENT needing a death with enemies inside 900 off a 120s rank-3
--       cooldown, inside a window that starts in the last minutes of a turbo
--       game -- and [8] REPLACES a 4s -75% slow rather than adding to it, while
--       its 1.6s stun expires 1.4s before reincarnate_time 3 puts him back on
--       his feet.
--
-- HONEST BOUNDS, carried here because they travel with the decision:
--   * No frame in this repo shows a Wraith King at level 25.  The window length
--     behind the t25 argument is inferred from ONE post-cap game (GH #235).
--     Nothing below asserts a window length.
--   * "How often does Reincarnation trigger with enemies inside 900" is a
--     corpus question nobody has asked.  If it is high, [8]'s case improves and
--     the row should be re-priced; section 5 says so in its failure text rather
--     than pretending the question is closed.
--   * The KV facts come from tests/mock/*.lua, snapshots taken by
--     tools/agent/*_census.py --snapshot.  A patch that reworks the hero moves
--     them and this file is meant to go red when it does.
--   * `Deprecated` is read as the literal KV key.  A facet made unreachable
--     some other way would still be counted live here.

package.path = 'tests/?.lua;' .. package.path

local FACETS = require('mock.hero_facets')
local SLOTS = require('mock.talent_slots').SLOTS

local HERO = 'bots/BotLib/hero_skeleton_king.lua'
local FOCUS_FIVE = { 'axe', 'zuus', 'skeleton_king', 'lion', 'crystal_maiden' }

local tests = {}

local function read_file(path)
    local fh = assert(io.open(path, 'r'), 'cannot open ' .. path)
    local src = fh:read('*a')
    fh:close()
    return src
end

--- The source with every comment removed.  MANDATORY, for the reason the CM
--- round found the hard way: this round wrote the entire facet argument -- names,
--- counts and all -- into the hero file's own header, so a scan of the raw text
--- would read its own documentation back and call the code present.
local function live_source(src)
    local out = {}
    for line in src:gsub('%-%-%[%[.-%]%]', ''):gmatch('[^\n]+') do
        if not line:match('^%s*%-%-') then out[#out + 1] = line end
    end
    return table.concat(out, '\n')
end

--- { t10 = {a,b}, ... } read out of the shipped literal.
local function talent_rows(src)
    local body = src:match('local tTalentTreeList = {(.-)\n}')
    assert(body, HERO .. ' has no tTalentTreeList literal')
    local rows = {}
    for tier, a, b in body:gmatch("%['(t%d+)'%]%s*=%s*{%s*(%d+)%s*,%s*(%d+)%s*}") do
        rows[tier] = { tonumber(a), tonumber(b) }
    end
    return rows
end

local WK_SLOTS = SLOTS['skeleton_king']

-- ---------------------------------------------------------------------------
-- 0. Anti-vacuum.  Every section below is a scan or a table lookup and each of
--    them passes trivially if what it reads is empty -- and this round already
--    watched exactly that happen once: the census's own hero regex was compiled
--    without re.M, matched nothing, and printed "focus five with a LIVE facet:
--    none", which is the SAME sentence the correct run prints.

tests['[hero] the facet snapshot and the hero source this file prices from are non-empty'] = function()
    local live = live_source(read_file(HERO))
    assert(#live > 4000, 'only ' .. #live .. ' bytes of live (comment-stripped) '
        .. HERO .. ' -- every source scan below would pass by finding nothing')
    assert(FACETS.ROSTER and FACETS.ROSTER.facet_entries and FACETS.ROSTER.facet_entries > 200,
        'tests/mock/hero_facets.lua reports only '
        .. tostring(FACETS.ROSTER and FACETS.ROSTER.facet_entries)
        .. ' facet entries across the roster. A census that parsed nothing reports zero '
        .. 'of everything, and "0 facet blocks name a talent row" is then vacuously '
        .. 'true -- which is the exact failure this round hit while writing the tool. '
        .. 'Re-run: python3 tools/agent/facet_census.py --snapshot')
    assert(FACETS.FOCUS and FACETS.LIVE_FACET_HEROES, 'hero_facets.lua lost a table')
    assert(WK_SLOTS and #WK_SLOTS == 8,
        'tests/mock/talent_slots.lua no longer carries eight skeleton_king slots')
end

-- ---------------------------------------------------------------------------
-- 1. THE SETTLEMENT, roster-wide.  This is the assertion that retires the
--    blocker for the whole TALENTPRICE axis rather than for one hero.

tests['[hero] no facet block anywhere in the roster names a talent row'] = function()
    assert(FACETS.ROSTER.names_talent_row == 0,
        FACETS.ROSTER.names_talent_row .. ' facet block(s) now name a special_bonus_* '
        .. 'row or an AbilityIndex inside the talent run (10..17). That reopens the '
        .. 'question hero_skeleton_king.lua parked in its source and this round closed: '
        .. 'if a facet can move a talent slot, then sTalentList[N] is game-dependent, '
        .. 'every t20/t25 price in the focus five is an argument about a row the game '
        .. 'may not ship, and -- worst -- talent6:IsTrained() in X.ConsiderW binds a '
        .. 'different talent in different games. Run '
        .. 'python3 tools/agent/facet_census.py and read which hero did it.')
end

tests['[hero] the roster still has LIVE facets -- the settlement is not "facets are dead"'] = function()
    -- The control.  If this ever reads zero, the tempting shortcut ("facets got
    -- removed, stop asking") would be indistinguishable from a broken parse, and
    -- section 1 would be proving nothing.
    assert(FACETS.ROSTER.live > 0,
        'tests/mock/hero_facets.lua now reports ZERO live facets roster-wide. Either '
        .. 'Valve removed the system or the census broke; until you know which, section '
        .. "1's zero means nothing.")
    local n = 0
    for _ in pairs(FACETS.LIVE_FACET_HEROES) do n = n + 1 end
    assert(n > 0, 'LIVE_FACET_HEROES is empty while ROSTER.live is '
        .. FACETS.ROSTER.live .. ' -- the snapshot disagrees with itself')
    -- Candidate-pool warning, asserted rather than written in prose so it cannot
    -- be skimmed past: these are on docs/PROJECT.md's later-heroes list AND they
    -- roll a facet, so their talent pricing does not inherit this settlement's
    -- easy half (section 2), only its roster-wide half (section 1).
    for _, hero in ipairs({ 'lich', 'tidehunter', 'witch_doctor' }) do
        assert(FACETS.LIVE_FACET_HEROES[hero],
            hero .. ' no longer reports a live facet. It is in this project\'s candidate '
            .. 'hero pool, and the reason it is named here is that a hero WITH a live '
            .. 'facet has to re-ask the per-hero half of this settlement when it joins '
            .. 'the focus five. If the fact changed, good -- update the note in '
            .. 'hero_skeleton_king.lua that names these three.')
    end
end

-- ---------------------------------------------------------------------------
-- 2. THE SETTLEMENT, per hero.  No focus hero has a facet that can be rolled.

tests['[hero] every focus hero facet entry is Deprecated -- there is no roll to read'] = function()
    for _, hero in ipairs(FOCUS_FIVE) do
        local list = FACETS.FOCUS[hero]
        assert(list, 'tests/mock/hero_facets.lua has no entry for ' .. hero)
        for _, f in ipairs(list) do
            assert(f.deprecated,
                hero .. ' now has a ROLLABLE facet: ' .. f.name .. '. Section 1 still '
                .. 'says a facet cannot move a talent SLOT, so the t20/t25 index does '
                .. 'not change -- but a live facet can gate a talent VALUE through '
                .. '`required_facet` inside AbilityValues, and it can grant an ability '
                .. 'that changes what the pricing argument is about. Re-price this '
                .. "hero's rows before shipping anything else.")
        end
    end
end

tests['[hero] Wraith King has exactly the two deprecated facets the pricing rests on'] = function()
    local list = FACETS.FOCUS['skeleton_king']
    assert(#list == 2, 'skeleton_king now has ' .. #list .. ' facet entries, not 2')
    local seen = {}
    for _, f in ipairs(list) do seen[f.name] = f end
    assert(seen['skeleton_king_facet_bone_guard'], 'the bone_guard facet is gone')
    assert(seen['skeleton_king_facet_cursed_blade'], 'the cursed_blade facet is gone')
end

-- ---------------------------------------------------------------------------
-- 3. The mechanism the deprecated pair explains.  Both halves were recorded in
--    hero_skeleton_king.lua as observations; this is what turns them into causes.

tests['[hero] the deprecated cursed_blade facet is why spectral_blade resolves to nil'] = function()
    local list = FACETS.FOCUS['skeleton_king']
    local granted = nil
    for _, f in ipairs(list) do
        if f.name == 'skeleton_king_facet_cursed_blade' then
            granted = table.concat(f.grants, ',')
        end
    end
    assert(granted and granted:find('skeleton_king_spectral_blade', 1, true),
        'skeleton_king_facet_cursed_blade no longer grants skeleton_king_spectral_blade. '
        .. 'That grant is the whole explanation for why the name exists in the KV yet '
        .. 'resolved to nil on every load (the abilityW note). If the facet became live '
        .. 'or the grant moved, the ability may now EXIST -- and the W path, which today '
        .. 'rides a fallback, has a second candidate handle.')
    -- And the other one, which is why Bone Guard is a plain ability today.
    for _, f in ipairs(list) do
        if f.name == 'skeleton_king_facet_bone_guard' then
            assert(table.concat(f.grants, ','):find('skeleton_king_bone_guard', 1, true),
                'skeleton_king_facet_bone_guard no longer grants skeleton_king_bone_guard')
        end
    end
end

tests['[hero] the file records the settlement, not the refusal it replaced'] = function()
    local src = read_file(HERO)
    assert(not src:find('settle that before pricing the pair', 1, true),
        HERO .. ' still carries the sentence "settle that before pricing the pair". '
        .. 'That question was answered on 2026-08-27 (this file, sections 1-3). If the '
        .. 'sentence came back, either the settlement was reverted -- say why -- or a '
        .. 'merge resurrected it.')
    assert(src:find('facet_census.py', 1, true),
        HERO .. ' no longer points at tools/agent/facet_census.py, which is the only '
        .. 'thing that can re-derive the settlement after a patch.')
end

-- ---------------------------------------------------------------------------
-- 4. t20 -- the row, and the premise that decides it.

tests['[hero] WK t20 stays on the Bone Guard skeleton-floor talent'] = function()
    local rows = talent_rows(read_file(HERO))
    assert(rows.t20, HERO .. ' has no t20 row')
    assert(rows.t20[1] == 10 and rows.t20[2] == 0,
        'WK t20 is {' .. rows.t20[1] .. ',' .. rows.t20[2] .. '}, i.e. moved to the ODD '
        .. 'index [5] = special_bonus_attack_speed_50. Read this before keeping that: '
        .. 'slot [6] is the ONLY talent in this tree the decision layer reads, via '
        .. 'talent6:IsTrained() in X.ConsiderW, and moving the row FREEZES that '
        .. 'predicate false in every game -- the same defect GH #166 found in Lion. It '
        .. 'also throws away what the bypass buys: min_skeleton_spawn 0 -> 5 turns Bone '
        .. "Guard from \"fires when a bank this file's own GH #17 block argues is "
        .. 'near-unreachable is full" into "fires on its flat 42s cooldown". If +50 '
        .. 'attack speed really is worth more, the bypass has to be rewired to something '
        .. 'that is not a talent handle FIRST.')
end

tests['[hero] the t20 premise is live: talent6 is still read as an OR-bypass in ConsiderW'] = function()
    local live = live_source(read_file(HERO))
    assert(live:find('local talent6 = bot:GetAbilityByName( sTalentList[6] )', 1, true),
        HERO .. ' no longer binds talent6 from sTalentList[6]. The t20 pricing rests '
        .. 'entirely on that handle being read; if the binding moved, re-price the row.')
    local n = 0
    for _ in live:gmatch('talent6:IsTrained%(%)') do n = n + 1 end
    assert(n == 2, 'talent6:IsTrained() is read ' .. n .. ' times in live code, not 2. '
        .. 'The t20 argument is "this is the only talent that changes a command here", '
        .. 'and it is sized on BOTH branches of X.ConsiderW. A different count means '
        .. 'the argument is about a different piece of code than the one it was written '
        .. 'against.')
    -- The bypass is an OR, not an AND: that is what makes a trained talent6 LOOSEN
    -- the release rule rather than tighten it.  If it ever becomes an AND the t20
    -- payoff inverts, so pin the shape, not just the presence.
    assert(live:find("or talent6:IsTrained()", 1, true),
        'talent6:IsTrained() is no longer joined with `or`. As an AND it would make '
        .. 'the talent a REQUIREMENT for releasing skeletons instead of a bypass, which '
        .. 'reverses the sign of the whole t20 argument.')
end

tests['[hero] slot 5 and slot 6 are still the talents the t20 argument names'] = function()
    assert(WK_SLOTS[5].name == 'special_bonus_attack_speed_50',
        'WK slot 5 is now ' .. WK_SLOTS[5].name .. ', not special_bonus_attack_speed_50 '
        .. '-- the rejected t20 side changed and the pricing is about a stale pair')
    assert(WK_SLOTS[6].name == 'special_bonus_unique_wraith_king_facet_3',
        'WK slot 6 is now ' .. WK_SLOTS[6].name
        .. ', not special_bonus_unique_wraith_king_facet_3 -- talent6:IsTrained() in '
        .. 'X.ConsiderW now binds a DIFFERENT talent and the bypass may no longer be '
        .. 'coherent with what it bypasses')
    local mods = table.concat(WK_SLOTS[6].mods, ' | ')
    assert(mods:find('min_skeleton_spawn', 1, true),
        'WK slot 6 no longer modifies skeleton_king_bone_guard/min_skeleton_spawn. '
        .. 'That flat floor is the ONLY surviving half of the talent (its other half, '
        .. 'spectral_blade/curse_cooldown, is dead because that ability is granted only '
        .. 'by a deprecated facet -- section 3), and it is what makes "release on an '
        .. 'empty bank" coherent instead of a bug.')
end

-- ---------------------------------------------------------------------------
-- 5. t25 -- the row, and the two facts its size argument rests on.

tests['[hero] WK t25 stays on the Mortal Strike cooldown talent'] = function()
    local rows = talent_rows(read_file(HERO))
    assert(rows.t25, HERO .. ' has no t25 row')
    assert(rows.t25[1] == 0 and rows.t25[2] == 10,
        'WK t25 is {' .. rows.t25[1] .. ',' .. rows.t25[2] .. '}, i.e. moved to the EVEN '
        .. 'index [8] = special_bonus_unique_wraith_king_4, "Reincarnation casts '
        .. 'Wraithfire Blast". That is not forbidden -- neither side is read by any '
        .. 'decision layer, so it is a pure size call -- but the 2026-08-27 pricing '
        .. 'rejected it on three grounds and a flip should answer them: (i) [8] is an '
        .. 'EVENT off a 120s rank-3 cooldown needing a death with enemies inside 900, '
        .. 'inside a window that opens in the last minutes of a turbo game, while [7] '
        .. 'is a RATE paid on every attack in it; (ii) [8] REPLACES the shipped 4s '
        .. '-75%% move / -75 attack slow rather than adding to it, and its stun expires '
        .. 'before reincarnate_time 3 puts him back on his feet; (iii) this is a '
        .. 'right-click hero whose only damage ability is Mortal Strike, so [7] '
        .. 'compounds with the item build and [8] does not. The measurement that would '
        .. 'settle it honestly is how often Reincarnation triggers with enemies in '
        .. 'range -- nobody has it.')
end

tests['[hero] neither t25 side is visible to this file -- what makes it a pure size call'] = function()
    local live = live_source(read_file(HERO))
    assert(not live:find('talent7', 1, true) and not live:find('talent8', 1, true),
        HERO .. ' now binds a talent7/talent8 handle. The t25 pricing rests on NEITHER '
        .. 'side being readable here, which is what reduced the choice to combat power. '
        .. 'A handle changes that: re-price with the read in it.')
    assert(not live:find('trigger_wraithfire_blast', 1, true),
        HERO .. " now reads reincarnation/trigger_wraithfire_blast. That was [8]'s "
        .. 'invisible half; if the decision layer can see it, [8] stops being a talent '
        .. 'the bot cannot exploit.')
end

tests['[hero] slot 7 and slot 8 are still the talents the t25 argument names'] = function()
    assert(WK_SLOTS[7].name == 'special_bonus_unique_wraith_king_10',
        'WK slot 7 is now ' .. WK_SLOTS[7].name .. ', not special_bonus_unique_wraith_king_10')
    assert(WK_SLOTS[8].name == 'special_bonus_unique_wraith_king_4',
        'WK slot 8 is now ' .. WK_SLOTS[8].name .. ', not special_bonus_unique_wraith_king_4')
    assert(table.concat(WK_SLOTS[7].mods, ' | '):find('AbilityCooldown', 1, true),
        'WK slot 7 no longer modifies skeleton_king_mortal_strike/AbilityCooldown -- the '
        .. 'whole "rate, paid on every attack" half of the t25 argument was about that key')
    assert(table.concat(WK_SLOTS[8].mods, ' | '):find('trigger_wraithfire_blast', 1, true),
        'WK slot 8 no longer modifies skeleton_king_reincarnation/trigger_wraithfire_blast')
end

return tests

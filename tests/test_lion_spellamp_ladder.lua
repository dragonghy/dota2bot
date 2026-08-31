-- [hero] Which spell-amp column is REACHABLE for this repo's Lion.  GH #359 §5,
-- taken 2026-08-31.
--
-- WHAT WAS ASKED.  The `lionqdmg` (a)-reading priced Earth Spike's kill claim in
-- three columns -- 0% / 15% / 20% spell amp -- and recorded that "which column is
-- really reachable is a fact the hero stream owes" (director §CO, restated in
-- GH #359 §5).  This file is that fact, and it does not need a game to settle:
-- every source of `bot:GetSpellAmp()` a bot Lion can hold is either bought from
-- a list in bots/BotLib/hero_lion.lua, dropped from the neutral pool this repo
-- maps in bots/FunLib/aba_item.lua, or granted by his own innate.
--
-- THE ANSWER, and it is not one of the three columns
-- --------------------------------------------------
--   0%    the default, and the whole of the support build.  NOT ONE ITEM in
--         Lion's pos_4 / pos_5 lists carries a `spell_amp` attribute -- checked
--         attribute-by-attribute against odota dotaconstants build/items.json,
--         not by name recognition.
--   +20%  his INNATE, `lion_to_hell_and_back`: `spell_amp 20` for `duration 90`
--         seconds after respawning or resurrecting, ending early on his next
--         kill or assist (dota2.com datafeed, hero_id=26, read 2026-08-31 --
--         the same source this file's talent ladder is anchored to).  Level 1,
--         no purchase, applied by the engine.  So the 20% column IS reachable,
--         and its predicate is COUNTABLE from a dump: respawn time plus the
--         next kill/assist, or directly the modifier -- this repo's fixture
--         corpus already carries `modifier_lion_to_hell_and_back_respawn_buff`
--         on 1 of the 10 modifier-bearing Lion frames
--         (tests/test_lion_t15_payoff.lua).
--   +35%  the same window from level 15 on, because the shipped t15 row trains
--         [4] = special_bonus_unique_lion_11, "+15% To Hell And Back Debuff/
--         Spell Amp" (odota dotaconstants; the datafeed leaves talent
--         special_values empty).  The talent's own name binds it to the
--         innate's numbers, so it ADDS inside the window and grants nothing
--         outside it.
--
-- ⚠️ 15% IS NOT A STATE.  Under the additive reading the in-window value is 35%,
-- not 15%; under the only other reading anyone could argue (the talent REPLACES
-- the innate's 20) it would be 15% -- which is LOWER than the untalented window
-- and which no source supports.  Either way there is no configuration of this
-- hero that stands at 15%, so GH #359's middle column is a pricing convention,
-- never a frame state.  The honest grid is { 0, 0.20, 0.35 }.
--
-- DOES THE CORRECTED GRID MOVE THE (乙) VERDICT?  No, and that is arithmetic on
-- GH #359's OWN published ladder, not a new corpus read.  The kill claim scales
-- linearly with (1 + amp), so the top of the grid multiplies the `mr25` claim by
-- 1.35, which sits strictly inside the issue's `<= 1.5x` bucket: 7 of 665 ready
-- frames.  The count moves from 2 to AT MOST 7 of 665 (~1.05%) -- still the "one
-- episode per ten games" shape the verdict was written on.
--
-- WHAT THIS FILE DOES NOT SETTLE
--   * Whether `bot:GetSpellAmp()` REPORTS the innate's window buff.  The API doc
--     (docs/BOT_API_REFERENCE.md:1155) says "spell amplification as a fraction"
--     and says nothing about conditional modifiers, and the fixture dumper does
--     not dump spell amp at all (tests/test_lion_t15_payoff.lua honest bounds).
--     It matters in ONE direction only: if the engine hides the window from the
--     API, `J.WillMagicKillTarget` UNDER-claims inside it, which makes the
--     `lionqdmg` lever weaker than priced, never stronger.  Handed back on #359.
--   * How often a real turbo game is inside a window.  A predicate is not a
--     frequency.
--   * Anything about Lion's CORE builds in play: pos_1 / pos_2 / pos_3 do carry
--     Kaya (10%) and Kaya & Sange (12%), and this file pins that they are the
--     only two, but says nothing about whether the harness ever routes Lion
--     there.  The corpus side of that is #359's own 0/665 amp-item reading.

package.path = 'tests/?.lua;' .. package.path

local scan = require('lua_source_scan')

local HERO = 'bots/BotLib/hero_lion.lua'
local ITEMLIB = 'bots/FunLib/aba_item.lua'

-- Items in Lion's five lists that grant the OWNER spell amplification, with the
-- magnitude odota dotaconstants records.  Debuff-side amp (Bloodthorn,
-- Mage Slayer: they amplify damage taken by the TARGET, key `spell_amp_debuff`)
-- is deliberately NOT here -- it is not `bot:GetSpellAmp()`.
local AMP_ITEMS = {
    item_kaya = 10,
    item_kaya_and_sange = 12,
    item_yasha_and_kaya = 12,
    item_ethereal_blade = 0,   -- listed so a future edit that adds it is caught
    item_meteor_hammer = 10,
    item_veil_of_discord = 10,
}

-- The three items GH #359's caliber counted that carry NO spell_amp attribute
-- at all.  Aether Lens is cast range (the issue says so itself); Scepter is
-- +10 all stats / hp / mana; Shard has no attribute block.  Their presence in
-- the caliber made that reading a SUPERSET on this side, so its 0 is safe --
-- but "Lion has a spell-amp item" must not be read off them later.
local NOT_AMP = { 'item_aether_lens', 'item_ultimate_scepter', 'item_aghanims_shard' }

--- Every quoted `item_*` name inside `sRoleItemsBuyList['<role>'] = { ... }`.
-- Commented-out entries are cut by the shared scanner, which is the correct
-- semantics: a commented line is not bought.
local function buy_list(role)
    local want = "sRoleItemsBuyList%['" .. role .. "'%]%s*=%s*{"
    local inside, out = false, {}
    for _, line in ipairs(scan.stripped_lines(HERO)) do
        if not inside then
            if line:match(want) then inside = true end
        else
            if line:match('^%s*}') then break end
            for name in line:gmatch('"(item_[%w_]+)"') do out[#out + 1] = name end
            for name in line:gmatch("'(item_[%w_]+)'") do out[#out + 1] = name end
        end
    end
    return out
end

--- Expansion of an outfit macro, read out of aba_item.lua's own table.
local function outfit(name)
    local src = assert(io.open(ITEMLIB)):read('*a')
    local body = src:match("Item%['" .. name .. "'%]%s*=%s*{(.-)}")
    assert(body, ITEMLIB .. ': no expansion found for ' .. name)
    local out = {}
    for item in body:gmatch("'(item_[%w_]+)'") do out[#out + 1] = item end
    return out
end

local function amp_items_in(list)
    local found = {}
    for _, item in ipairs(list) do
        if AMP_ITEMS[item] then found[#found + 1] = item end
    end
    return found
end

local function join(t) return '{' .. table.concat(t, ', ') .. '}' end

local tests = {}

tests['[ratchet] Lion\'s support builds carry no spell-amp item at all'] = function()
    -- The load-bearing half of the answer to GH #359 §5: on pos_4 / pos_5 the
    -- reachable item amp is zero, so the 0% column is the shipped default and
    -- every non-zero column has to come from the innate.
    for _, role in ipairs({ 'pos_4', 'pos_5' }) do
        local list = buy_list(role)
        assert(#list > 0, HERO .. ": " .. role .. " buy list parsed empty -- the " ..
            'table shape changed, so this claim would be vacuously true')
        local found = amp_items_in(list)
        assert(#found == 0, HERO .. ': ' .. role .. ' now buys a spell-amp item ' ..
            join(found) .. ' -- GH #359 §5\'s answer ("support Lion stands at ' ..
            '0% amp from items") is no longer true and the write-up above must ' ..
            'be redone')
    end
end

tests['[ratchet] the outfit macros the support builds buy carry none either'] = function()
    -- pos_4 buys item_priest_outfit and pos_5 buys item_mage_outfit; both are
    -- macros that expand to a basket elsewhere.  Reading only the hero file
    -- would miss anything hidden in the expansion, which is exactly the shape
    -- of defect this desk keeps finding (a claim checked on the wrong text).
    for _, macro in ipairs({ 'item_priest_outfit', 'item_mage_outfit' }) do
        local items = outfit(macro)
        assert(#items > 0, ITEMLIB .. ': ' .. macro .. ' expanded to nothing')
        local found = amp_items_in(items)
        assert(#found == 0, ITEMLIB .. ': ' .. macro .. ' now expands to a ' ..
            'spell-amp item ' .. join(found))
    end
end

tests['[ratchet] Kaya lives only on the core lists, and it is exactly two items'] = function()
    -- The other half: the amp items are not absent from the file, they are
    -- fenced onto pos_1 / pos_2 (pos_3 is assigned pos_2's table).  If a future
    -- round moves one onto a support list, the test above goes red; if a round
    -- deletes them from the core lists, this one does, and the "core Lion can
    -- hold amp" leg of the §5 answer has to be rewritten.
    local expected = { item_kaya = true, item_kaya_and_sange = true }
    for _, role in ipairs({ 'pos_1', 'pos_2' }) do
        local found = amp_items_in(buy_list(role))
        assert(#found == 2, HERO .. ': ' .. role .. ' now carries ' .. #found ..
            ' spell-amp item(s) ' .. join(found) .. ', expected 2')
        for _, item in ipairs(found) do
            assert(expected[item], HERO .. ': ' .. role .. ' carries an ' ..
                'unexpected spell-amp item ' .. item)
        end
    end
    local src = assert(io.open(HERO)):read('*a')
    assert(src:match("sRoleItemsBuyList%['pos_3'%]%s*=%s*sRoleItemsBuyList%['pos_2'%]"),
        HERO .. ': pos_3 no longer aliases pos_2 -- it needs its own check above')
end

tests['[ratchet] the three items #359\'s caliber counted grant no spell amp'] = function()
    -- Pinned as a fact about the CALIBER, not about Lion: Aether Lens, Scepter
    -- and Shard carry no spell_amp attribute in dotaconstants, so a future
    -- reader must not conclude "Lion had amp" from holding one.  They are all
    -- three genuinely in the support builds, which is why the confusion is
    -- available at all -- so assert that too, or this note is about nothing.
    local list = buy_list('pos_4')
    local seen = {}
    for _, item in ipairs(list) do seen[item] = true end
    for _, item in ipairs(NOT_AMP) do
        assert(seen[item], HERO .. ': pos_4 no longer buys ' .. item ..
            ' -- the caliber note above is stale')
        assert(AMP_ITEMS[item] == nil, 'internal: ' .. item ..
            ' is registered as an amp item and as a non-amp item at once')
    end
end

tests['[ratchet] exactly one neutral in this patch\'s pool is a self-amp source'] = function()
    -- The neutral path is the one GH #359's caliber does not cover at all, and
    -- it is a real path: a neutral is DROPPED, not bought, so no buy list can
    -- exclude it.  Checked once against dotaconstants (2026-08-31): of the 49
    -- neutrals this repo maps, exactly one carries `spell_amp` --
    -- item_harmonizer, +6%, TIER 5, which no ~20-minute turbo game reaches.
    -- The map's SIZE is asserted so that a patch update that grows the pool
    -- goes red here and the constants check is re-run rather than assumed.
    local src = assert(io.open(ITEMLIB)):read('*a')
    local block = src:match('local tNeutralItemLevelList = {(.-)\n}')
    assert(block, ITEMLIB .. ': the neutral tier map changed shape')
    local n, tier = 0, {}
    for item, lvl in block:gmatch("%['(item_[%w_]+)'%]%s*=%s*(%d)") do
        n = n + 1
        tier[item] = tonumber(lvl)
    end
    assert(n == 49, 'the neutral pool held 49 entries when the spell-amp check ' ..
        'was run against dotaconstants, now ' .. n .. ' -- re-run that check ' ..
        'before trusting the "only Harmonizer" claim above')
    assert(tier['item_harmonizer'] == 5, 'item_harmonizer is the only neutral ' ..
        'spell-amp source in the pool and it must still be tier 5; it now reads ' ..
        tostring(tier['item_harmonizer']))
end

tests['[ratchet] the shipped t15 row still trains the amp talent'] = function()
    -- The +35% rung exists only because this build takes t15 index [4].  The
    -- {10,0} -> [4] wiring itself is arithmetic inside J.Skill.GetTalentBuild
    -- and is read out in tests/test_focus_talent_anchor.lua; what is pinned
    -- here is only that Lion's row still asks for it.
    local src = assert(io.open(HERO)):read('*a')
    local row = src:match("%['t15'%]%s*=%s*{%s*(%d+)%s*,%s*(%d+)%s*}")
    assert(row, HERO .. ': the t15 row is gone or changed shape')
    local a, b = src:match("%['t15'%]%s*=%s*{%s*(%d+)%s*,%s*(%d+)%s*}")
    assert(a == '10' and b == '0', HERO .. ': t15 now reads {' .. a .. ', ' .. b ..
        '} -- if the amp talent is no longer trained, the +35% rung of the ' ..
        'GH #359 §5 ladder is gone and the header above is wrong')
end

tests['[ratchet] the ladder arithmetic, including why 15% is not a rung'] = function()
    -- Constants with provenance: innate from the datafeed, talent from odota.
    local INNATE_SPELL_AMP = 20      -- lion_to_hell_and_back, special value
    local INNATE_DURATION = 90       -- seconds after respawn/resurrect
    local TALENT_BONUS = 15          -- special_bonus_unique_lion_11
    local ladder = { 0, INNATE_SPELL_AMP / 100,
                     (INNATE_SPELL_AMP + TALENT_BONUS) / 100 }

    assert(ladder[2] == 0.20, 'the untalented window rung must be the innate value')
    assert(math.abs(ladder[3] - 0.35) < 1e-9,
        'the talented window rung must be innate + talent, got ' .. ladder[3])
    assert(INNATE_DURATION == 90, 'window length is part of the countable predicate')

    -- 15% is neither rung: it is below the untalented window and above zero, so
    -- no configuration of this hero produces it.
    for _, rung in ipairs(ladder) do
        assert(math.abs(rung - 0.15) > 1e-9,
            '0.15 turned into a reachable rung -- if a patch made it one, the ' ..
            'GH #359 §5 answer changes and this file says so first')
    end

    -- The bound the verdict rests on, computed on GH #359's own ladder: the
    -- claim scales with (1 + amp), and 1.35 sits inside the published <= 1.5x
    -- bucket, so the top rung moves the kill-claim count from 2 to at most 7
    -- of 665 ready frames.
    local top_multiplier = 1 + ladder[3]
    assert(top_multiplier > 1.0 and top_multiplier < 1.5,
        'the top rung no longer lands inside the <= 1.5x bucket of GH #359\'s ' ..
        'neighbour ladder (2 / 7 / 15 / 50 frames at 1.0 / 1.5 / 2.0 / 3.0x), ' ..
        'so the "at most 7 of 665" bound has to be re-derived from a new read')
end

return tests

-- [hero] The fixture world charges for mana -- and the ledger of where it still
-- does not.
--
-- WHY THIS FILE EXISTS (hero 2026-09-01, backlog -43a's Zeus direction)
-- --------------------------------------------------------------------
-- tests/mock/replay_fixture.lua has specified `IsFullyCastable` as
--
--     GetLevel() > 0 and GetCooldownTimeRemaining() <= 0
--                    and owner:GetMana() >= (self:GetManaCost() or 0)
--
-- since test_set.md §F, and the comment above it names the exact case the mana
-- term was written for: "a 246-mana ultimate reading 'fully castable' while the
-- hero held 190 mana, which is the real reason X.ConsiderR bails on its first
-- line in game."
--
-- That term had never once been able to fire.  `GetManaCost` was on no ability
-- spec, so it fell through to mock/bot_api.lua's generic `^Get` default and
-- answered 0 -- for every ability, on every frame in the tree.  `GetMana() >= 0`
-- is a tautology, so the conjunction reduced to level-and-cooldown and the
-- fixture world handed out every ability for free.
--
-- MEASURED BEFORE THE FIX (the numbers section 1 and 2 now hold the line on):
--   * 4376 of 4376 ability handles in the corpus answered GetManaCost() == 0.
--     Not one answered anything else, so this was not a gap with exceptions --
--     it was total.
--   * Restricted to the five focus heroes (the only heroes this repository
--     holds a KV mana ladder for), 40 of 381 trained-and-"fully castable"
--     readings -- 10.5% -- are revoked once the real price is charged.
--   * The loader comment's OWN worked example is one of the 40:
--     f_260819_142047_zuus_ult_denied.lua holds 190 mana against a 250-mana
--     Thundergod's Wrath and read CASTABLE.  So did a Zeus holding 11 mana
--     (f_260820_103644_necro_pinned_dying.lua), and so did the ultimate on
--     f_260819_142047_zuus_ult_manalock.lua -- a fixture whose NAME is the mana
--     lock -- at 99 mana.
--
-- THE FAILURE DIRECTION IS THE DANGEROUS ONE.  A vacuous clause OVERSTATES how
-- often a decision branch is reachable, so every fixture-driven claim of the
-- shape "this frame reaches branch X" that passed through IsFullyCastable was
-- resting on free mana.  Same family as the GetActualIncomingDamage zero (hero
-- 2026-08-29) and the GetAbilityDamage zero (GH #175): a silent 0 out of an
-- unspecced getter is not a small number, it is a DIFFERENT PREDICATE.
--
-- WHAT IT ALREADY CAUGHT, and the reason this is not a bookkeeping change:
-- tests/test_replay_260819_zuus_ult_manalock.lua asserted that shipped Zeus
-- fires LIGHTNING BOLT on the lock frame, and was green -- while that same
-- file's header records the replay's ground truth as "he spends 94 on ARC
-- LIGHTNING".  The assertion and the observation named different spells and
-- nothing raised a hand, because Lightning Bolt (120) is unaffordable at 99
-- mana and only the free-mana world let it outbid Arc Lightning (95).  Charging
-- the price moved the simulation ONTO the observed behaviour.
--
-- HONEST BOUNDS -- section 3 is the ledger, and it is the important half
-- -------------------------------------------------------------------------
--   * tests/mock/special_value_shapes.lua is a snapshot of the FIVE FOCUS
--     HEROES only.  Every other hero's abilities still answer 0 and remain
--     unconditionally affordable.  This NARROWS the vacuity; it does not close
--     it.  Section 3 asserts the residue is real and counted, so nobody reads
--     "the fixture world charges for mana" as a tree-wide fact.
--   * The ladder is the KV declaration, not a frame reading.  make_fixture.py
--     extracts no ability specs, so no fixture can supply a cost; where a
--     replay measured one, the measurement outranks this (see the 246 anchored
--     by hand in the manalock file, against KV's 250).
--   * Nothing here says a reduction (Arcane Rune, a cost talent, Octarine) is
--     modelled.  None is.  The price charged is the base ladder, so the world
--     is still OPTIMISTIC about affordability wherever one applies -- the same
--     direction as before, just very much smaller.

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')
local shapes = require('mock.special_value_shapes')

local tests = {}

local FOCUS = {
    zuus = true, axe = true, lion = true,
    crystal_maiden = true, skeleton_king = true,
}

local function corpus_files()
    local out = {}
    for _, d in ipairs({ 'tests/fixtures', 'tests/frames' }) do
        local p = assert(io.popen('ls ' .. d .. ' 2>/dev/null'))
        for l in p:lines() do
            if l:match('^.+%.lua$') then out[#out + 1] = d .. '/' .. l end
        end
        p:close()
    end
    table.sort(out)
    return out
end

--- The KV mana ladder, read straight off the snapshot -- deliberately a SECOND
--- implementation of the loader's own `mana_ladder`.  A test that imported the
--- loader's copy would agree with it by construction and could not notice it
--- going wrong; this one can.
local function ladder(unit_name, ability_name)
    local short = unit_name:gsub('^npc_dota_hero_', '')
    local abils = shapes.SHAPES[short]
    if abils == nil then return nil end
    local e = abils[ability_name]
    if e == nil or e['AbilityManaCost'] == nil or e['AbilityManaCost'].base == nil then
        return nil
    end
    local steps = {}
    for tok in e['AbilityManaCost'].base:gmatch('%S+') do
        local n = tonumber(tok)
        if n == nil then return nil end
        steps[#steps + 1] = n
    end
    if #steps == 0 then return nil end
    return steps
end

--- One pass over the corpus.  Every counter is reported even when zero, because
--- the whole point of this file is a clause that read as satisfied while its
--- population was empty: a bare 0 here must never be indistinguishable from a
--- scan that never ran.
local function scan()
    local c = {
        files = 0, frames_with_units = 0,
        handles = 0, priced = 0, free = 0,
        focus_trained = 0, focus_castable = 0, focus_unaffordable = 0,
        nonfocus_handles = 0,
        -- The focus-five residue, split by CAUSE.  Counting free handles was
        -- the wrong proxy (it conflates "no snapshot" with "declared free"),
        -- and saying so cost this file one red on its first run.
        focus_free = 0,          -- reads 0
        focus_free_no_entry = 0, --   ... and the snapshot has no such ability (innate / talent)
        focus_free_no_key = 0,   --   ... or the ability declares no AbilityManaCost (passive)
        focus_free_kv_zero = 0,  --   ... or the KV price genuinely IS 0
        focus_free_unexplained = 0, -- ... none of the above: a REAL gap
    }
    for _, f in ipairs(corpus_files()) do
        c.files = c.files + 1
        local fx = dofile(f)
        if fx.units and #fx.units > 0 then
            c.frames_with_units = c.frames_with_units + 1
            local _, bot = rf.load(f)
            local by_name = {}
            if bot ~= nil then by_name[bot:GetUnitName()] = bot end
            for _, lst in ipairs({ UNIT_LIST_ALLIED_HEROES, UNIT_LIST_ENEMY_HEROES }) do
                for _, x in pairs(GetUnitList(lst)) do by_name[x:GetUnitName()] = x end
            end
            for _, u in ipairs(fx.units) do
                local unit = by_name[u.name]
                local short = u.name:gsub('^npc_dota_hero_', '')
                if unit ~= nil then
                    for _, a in ipairs(u.abilities or {}) do
                        if a.name ~= '' then
                            local h = unit:GetAbilityByName(a.name)
                            if h ~= nil then
                                c.handles = c.handles + 1
                                local cost = h:GetManaCost()
                                if cost ~= nil and cost > 0 then
                                    c.priced = c.priced + 1
                                else
                                    c.free = c.free + 1
                                end
                                if not FOCUS[short] then
                                    c.nonfocus_handles = c.nonfocus_handles + 1
                                elseif cost == nil or cost == 0 then
                                    c.focus_free = c.focus_free + 1
                                    local abils = shapes.SHAPES[short] or {}
                                    local e = abils[a.name]
                                    if e == nil then
                                        c.focus_free_no_entry = c.focus_free_no_entry + 1
                                    elseif e['AbilityManaCost'] == nil then
                                        c.focus_free_no_key = c.focus_free_no_key + 1
                                    elseif (ladder(u.name, a.name) or { -1 })[1] == 0 then
                                        c.focus_free_kv_zero = c.focus_free_kv_zero + 1
                                    else
                                        c.focus_free_unexplained = c.focus_free_unexplained + 1
                                    end
                                end
                                local steps = ladder(u.name, a.name)
                                if FOCUS[short] and steps ~= nil and a.level > 0 then
                                    c.focus_trained = c.focus_trained + 1
                                    local real = steps[math.min(a.level, #steps)]
                                    if unit:GetMana() < real then
                                        c.focus_unaffordable = c.focus_unaffordable + 1
                                        -- The clause under test: an ability the
                                        -- hero cannot pay for must NOT read
                                        -- fully castable.
                                        if h:IsFullyCastable() then
                                            c.focus_castable = c.focus_castable + 1
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end
    return c
end

local C = scan()

-- ---------------------------------------------------------------------------
-- 1. The scan ran at all.  Denominators first, for the reason in the header.

tests['[hero] the corpus scan reached frames, units and ability handles'] = function()
    assert(C.files >= 100,
        'the corpus is ~108 frames; a small number here means the scan, not the tree, '
        .. 'is what shrank. got ' .. C.files)
    assert(C.frames_with_units == C.files,
        'every corpus file carries units, got ' .. C.frames_with_units .. '/' .. C.files)
    assert(C.handles > 4000,
        'the tree holds ~4376 ability handles; an empty scan and a clean result are '
        .. 'the same integer, which is the defect this file exists for. got ' .. C.handles)
end

-- ---------------------------------------------------------------------------
-- 2. The clause is live: nobody casts what they cannot pay for.

tests['[hero] no focus-hero ability reads castable while unaffordable'] = function()
    assert(C.focus_trained > 300,
        'the focus five hold ~381 trained abilities with a KV price; got '
        .. C.focus_trained .. '. A collapse here empties the population section 2 '
        .. 'tests, and an empty population passes it vacuously.')
    assert(C.focus_unaffordable > 0,
        'at least some frames must be unaffordable or this assertion proves nothing '
        .. '(measured: 40). got ' .. C.focus_unaffordable)
    assert(C.focus_castable == 0,
        C.focus_castable .. ' focus-hero abilities read IsFullyCastable() while the '
        .. 'owner cannot pay the KV price. The mana term of IsFullyCastable is '
        .. 'vacuous again -- check that replay_fixture.lua still puts GetManaCost '
        .. 'on the ability spec, because bot_api answers 0 for anything it does not.')
end

tests['[hero] the priced population is real, and it is the focus five'] = function()
    assert(C.priced > 500,
        'about 566 handles carry a KV price; got ' .. C.priced)
    assert(C.priced + C.free == C.handles, 'priced + free must exhaust the handles')
end

-- ---------------------------------------------------------------------------
-- 3. The ledger of what is STILL free.  This section is the honest bound, and
--    it is written as an assertion so the bound cannot quietly go stale: the
--    day the snapshot widens past the focus five, this goes red and the header's
--    "narrows, does not close" has to be rewritten to match.

tests['[hero] LEDGER: non-focus heroes are still unpriced, and that is declared'] = function()
    assert(C.free > 0,
        'the residue must be non-empty -- if it is not, the snapshot has widened '
        .. 'and this file\'s honest bound is stale. got ' .. C.free)
    assert(C.nonfocus_handles > 0,
        'the corpus must contain non-focus heroes for the bound to be about anything')
    -- The bound is about SNAPSHOT COVERAGE, so it is stated on the heroes the
    -- snapshot does not cover.  Measured: 3589 of the 3810 free handles.
    assert(C.nonfocus_handles >= 3000,
        'the unpriced residue is supposed to be dominated by heroes outside the '
        .. 'focus-five snapshot; got only ' .. C.nonfocus_handles)
end

--- Written after this file's own first red, and the correction is the point.
--- Section 3 originally asserted `free <= nonfocus_handles`, i.e. it priced the
--- gap by COUNTING free handles.  That is the wrong proxy: it reads a passive, a
--- talent and an ability whose KV price genuinely IS 0 as evidence of a missing
--- price.  It went red at 3810 > 3589 and the 221-handle "gap" turned out to be
--- 110 passives (counter_helix, brilliance_aura, mortal_strike), 85 innates and
--- talent rows the snapshot does not carry, and 26 handles -- lion_mana_drain
--- and zuus_lightning_hands -- that declare `AbilityManaCost = '0'` and are
--- therefore correctly free.  Every one explained; zero real gaps.
--- The right statement is per-handle and by cause, so it stays true as the
--- corpus grows and goes red only on an ability that HAS a price and is not
--- being charged it.
tests['[hero] LEDGER: every free focus-five handle is free for a stated reason'] = function()
    assert(C.focus_free > 0, 'the focus five do hold costless abilities (measured 221)')
    assert(C.focus_free_unexplained == 0,
        C.focus_free_unexplained .. ' focus-five ability handle(s) read 0 mana while '
        .. 'the KV snapshot gives them a nonzero price ladder. That is the vacuity '
        .. 'coming back inside the covered set -- check mana_ladder() in '
        .. 'tests/mock/replay_fixture.lua.')
    assert(C.focus_free_no_entry + C.focus_free_no_key + C.focus_free_kv_zero
            + C.focus_free_unexplained == C.focus_free,
        'the four causes must exhaust the residue')
    -- Each cause is non-empty, so a classifier that silently stopped matching
    -- one of them cannot pass this by routing everything into another bucket.
    assert(C.focus_free_no_entry > 0, 'innates/talents are in the residue')
    assert(C.focus_free_no_key > 0, 'passives with no AbilityManaCost are in the residue')
    assert(C.focus_free_kv_zero > 0,
        'abilities whose KV price is literally 0 are in the residue '
        .. '(lion_mana_drain, zuus_lightning_hands)')
end

-- ---------------------------------------------------------------------------
-- 4. The worked example the loader comment names, driven end to end.

tests['[hero] the loader comment\'s own example: 190 mana does not pay for the ult'] = function()
    local F = 'tests/fixtures/f_260819_142047_zuus_ult_denied.lua'
    local _, bot = rf.load(F, 'npc_dota_hero_zuus')
    assert(bot:GetMana() == 190, 'real frame mana, got ' .. bot:GetMana())
    local ult = bot:GetAbilityByName('zuus_thundergods_wrath')
    assert(ult:GetLevel() == 1 and ult:GetCooldownTimeRemaining() == 0,
        'trained and off cooldown -- only mana is missing, which is the whole point')
    assert(ult:GetManaCost() == 250, 'KV rank-1 price is 250, got ' .. ult:GetManaCost())
    assert(not ult:IsFullyCastable(),
        '190 mana cannot pay 250; before 2026-09-01 this read CASTABLE and the '
        .. 'loader comment describing the bug was sitting six lines above the '
        .. 'clause that could not enforce it')
end

return tests

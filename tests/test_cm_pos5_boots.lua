-- [hero] Crystal Maiden's pos_5 boots: tranquil -> arcane, and the Boots of
-- Bearing terminus that has to go with it.  GATED 'cmboots' (turbo-only) since
-- 2026-08-23; the reasoning is pinned here as assertions either way.
--
-- WHY IT IS GATED AND NOT SHIPPED (GH #144, director ruling 2026-08-23).  This
-- landed ungated in 9fa4898 and had to be walked back into a gate, for a
-- mechanical reason rather than a doubt about the case: the mirrored A/B
-- reports a difference of differences, so a change present on BOTH arms of
-- BOTH waves cancels term-for-term and is invisible to the instrument in
-- either direction, however many waves run.  A shipped ungated build change
-- can therefore never buy condition (b).  Component-count repairs (GH #136
-- double branches, GH #139 double gauntlets) stay gate-free -- they restore an
-- intended-but-structurally-unreachable state -- but a choice of WHAT to buy
-- is a design decision and ships dark first.
--
-- WHAT ELSE CAME BACK WITH IT.  9fa4898 also edited item_crystal_maiden_outfit
-- in aba_item.lua (second tango added, tDefineItemRealName sentinel moved from
-- item_magic_wand to item_arcane_boots) on the stated premise that the outfit
-- was "referenced by nothing since before the fork".  The premise is false --
-- sixteen other hero files carry it in a live buy list -- so that edit was an
-- unmeasurable live change to sixteen non-focus heroes, and the sentinel move
-- in particular ended their openers two entries early.  Both are reverted
-- byte-for-byte; the arcane variant now lives in its own item_mage_arcane_
-- outfit, referenced only from the gated branch.  Asserted below.
--
-- GH #126 part two asked for this measurement in so many words: "tranquil vs
-- arcane on the SAME frames (mana pool, disposable mana above the nKeepMana
-- floor, share of ready slots that can pay), and the tranquil side's regen and
-- movement speed recorded too -- not just the mana half."
--
-- WHAT THE CORPUS SAYS
--
-- 1. COUNTERFACTUAL (upper bound, not a rate).  On the 23 CM frames carrying
--    tranquil boots, 12 of 45 ready ability slots -- trained AND off cooldown
--    -- cannot pay their own mana cost.  Arcane's flat +125 unblocks 9 of the
--    12; +275 (arcane plus one Replenish, cd 55s) unblocks all 12.
-- 2. OBSERVATIONAL, and this is the half the t10 pair never had.  Seven CM
--    frames in the same corpus already carry ARCANE boots -- the pos_4
--    priest_outfit line -- and 0 of their 14 ready slots are unaffordable,
--    against 12 of 45 on the tranquil arm, at a mean hero level of 8.14 vs
--    8.13.  Under the tranquil arm's own rate a clean 14 comes up with
--    probability 0.7333^14 = 0.013.  Confounded (pos_4 differs in the whole
--    build, not just the boots) and small; suggestive, not decisive.
-- 3. Arcane's STATIC half is +125 mana -- LESS than the +144 that this same
--    desk judged insufficient at t10 the day before (tests/test_cm_t10_payoff
--    .lua).  The case therefore does not rest on the flat mana.  It rests on
--    Replenish: 150 mana to the caster AND every ally within 1200, every 55
--    seconds, which the shipped tree already knows how to fire without a line
--    of new code (ability_item_usage_generic.lua's ConsiderItemDesire for
--    item_arcane_boots: self at <58% mana, team when two allies are short
--    180+).  A repeatable team-wide refill is a different kind of object from
--    a one-off pool bump, and the corpus cannot see it at all (GH #100: no
--    item Consider runs in the fixture world), so it is argued, not measured.
--
-- WHY THE SAME RULER FLIPS THIS PAIR AND NOT t10
--
-- At t10 the measured side (mana) and condition (c) pointed in OPPOSITE
-- directions -- standard play wants +200 health on the squishiest hero on the
-- map -- and the health side had no channel at all, so the pair was left
-- alone.  Here they point the SAME way: Crystal Maiden is the textbook Arcane
-- Boots support (the largest mana costs of any support: Nova 175 / Frostbite
-- 155 / Freezing Field 600 at max rank), the repo's own pos_4 CM already buys
-- arcane, and an unreferenced item_crystal_maiden_outfit carrying arcane boots
-- had been sitting in aba_item.lua since before this project forked.
--
-- WHAT IT COSTS, STATED RATHER THAN WAVED OFF
--
--   * Tranquil's 14 hp/s of field regen is gone.  That cuts against owner
--     priority P2 (stay out, sustain in the field, do not walk home), and the
--     corpus cannot price it: hp regen has no channel in an instantaneous
--     frame.  UNDERPOWERED, not empty -- the GH #115 rule, applied against the
--     side this file takes.  Two things blunt it: the regen is lost for 13s on
--     ANY hit taken or hero attacked (opendota constants, 2026-08-23), and
--     while broken tranquil's 40 movement speed is BELOW arcane's 45.
--   * 600 gold more for the boots, and one item slot of the opener spent
--     earlier in the game.
--   * Boots of Bearing (4225g, = tranquil_boots + ancient_janggo +
--     ring_of_tarrasque) left the pos_5 list, because with arcane in the
--     opener its recipe would buy a second pair of boots and movement speed
--     does not stack.  No unit in the corpus owns one -- but the corpus ends
--     at t=690.5 (11:30) and Bearing is a fifth item, so that zero is
--     OUT-OF-WINDOW, not EMPTY.
--   * A test elsewhere paid for it: the role discriminator in
--     tests/test_replay_260820_cm_es_aftershock.lua used to read "pos_5 has
--     tranquil, pos_4 has arcane, they share no basic".  Both openers carry
--     arcane now, so that half of the discriminator is dead and the surviving
--     halves (blood_grenade and null_talisman on pos_5, urn_of_shadows on
--     pos_4) carry it alone.  Frames recorded before today hold tranquil boots
--     because that is what the build bought then.
--
-- WHAT WOULD REOPEN IT (assertions below, not promises)
--   * the corpus gaining a Boots of Bearing owner, or its window extending
--     past ~11:30 (the 25-minute batch cap, GH #108) -- either makes the
--     removed terminus priceable instead of unpriceable;
--   * the arcane arm's unaffordable-slot count ceasing to be zero;
--   * the tranquil arm's shortfall closing on its own (a mana item arriving
--     elsewhere in the pos_5 line, or nKeepMana moving).

package.path = 'tests/?.lua;' .. package.path
local api = require('mock.bot_api')

local HERO   = 'bots/BotLib/hero_crystal_maiden.lua'
local ITEMS  = 'bots/FunLib/aba_item.lua'
local SIDE_PATH = 'bots/Customize/soak_side.lua'   -- gitignored, farm-only
local CAND   = 'cmboots'

local function read_file(path)
    local fh = assert(io.open(path, 'r'), 'cannot open ' .. path)
    local s = fh:read('*a'); fh:close()
    return s
end

local function sweep()
    local p = assert(io.popen('lua5.1 tests/_cm_pos5_boots_sweep.lua 2>/dev/null'))
    local text = p:read('*a')
    p:close()
    assert(text:find('\nDONE\n') or text:find('^DONE\n'),
        'the corpus sweep subprocess did not finish (no DONE line)')
    local c, arm, delta, rows, slots, bearing = {}, {}, {}, {}, {}, {}
    local window
    for line in text:gmatch('[^\n]+') do
        local k, v = line:match('^C ([%w_]+) (%-?%d+)$')
        if k then c[k] = tonumber(v) end
        local ak, an, alv, as, ab = line:match('^ARM (%a) (%d+) (%d+) (%d+) (%d+)$')
        if ak then
            arm[ak] = { n = tonumber(an), lv = tonumber(alv),
                slots = tonumber(as), blocked = tonumber(ab) }
        end
        local dk, dv = line:match('^DELTA (%d+) (%d+)$')
        if dk then delta[tonumber(dk)] = tonumber(dv) end
        local wmin, wmed, wmax = line:match('^WINDOW ([%d%.]+) ([%d%.]+) ([%d%.]+)$')
        if wmin then
            window = { min = tonumber(wmin), med = tonumber(wmed), max = tonumber(wmax) }
        end
        local bf, bu = line:match('^BEARING (%S+) (%S+)$')
        if bf then bearing[#bearing + 1] = { fix = bf, unit = bu } end
        local rf_, ra, rlv, rmp, rmaxmp, rhp, rmaxhp, rs, rb, rj =
            line:match('^ROW (%S+) (%a) (%d+) (%d+) (%d+) (%d+) (%d+) (%d+) (%d+) (%d)$')
        if rf_ then
            rows[#rows + 1] = { fix = rf_, arm = ra, lv = tonumber(rlv),
                mp = tonumber(rmp), maxmp = tonumber(rmaxmp), hp = tonumber(rhp),
                maxhp = tonumber(rmaxhp), slots = tonumber(rs),
                blocked = tonumber(rb), janggo = rj == '1' }
        end
        local sf, sa, sab, sr, sc, smp, sb =
            line:match('^SLOT (%S+) (%a) (%S+) (%d+) (%d+) (%d+) (%d)$')
        if sf then
            slots[#slots + 1] = { fix = sf, arm = sa, ability = sab,
                rank = tonumber(sr), cost = tonumber(sc), mp = tonumber(smp),
                blocked = sb == '1' }
        end
    end
    return c, arm, delta, rows, slots, bearing, window
end

local C, ARM, DELTA, ROWS, SLOTS, BEARING, WINDOW = sweep()

--- The shipped pos_5 list, read out of the hero source rather than restated.
--- (The M13 lesson: a census that copies the constant it measures reports the
--- old world unmoved after the constant moves.)
local function pos5_list()
    local src = read_file(HERO)
    local body = src:match("sRoleItemsBuyList%['pos_5'%]%s*=%s*{(.-)\n}")
    assert(body, 'cannot find the pos_5 list in ' .. HERO)
    local t = {}
    for s in body:gmatch("['\"](item_[%w_]+)['\"]") do t[#t + 1] = s end
    return t
end

--- One outfit macro's component list, read out of aba_item.lua.
local function outfit(sName)
    local src = read_file(ITEMS)
    local body = src:match("Item%['" .. sName .. "'%]%s*=%s*{(.-)}")
    assert(body, 'cannot find ' .. sName .. ' in ' .. ITEMS)
    local t = {}
    for s in body:gmatch("['\"](item_[%w_]+)['\"]") do t[#t + 1] = s end
    return t
end

local function has(t, s)
    for _, v in ipairs(t) do if v == s then return true end end
    return false
end

--- Load the hero file with the gate in a chosen state and hand back its X.
--- Both GetTeam()s must agree or J.IsSoakCandidateSide and Role.GetPosition
--- disagree about which side this bot is on (the axe_blink_build lesson).
local function load_cm(bTurbo, nRole)
    api.reset_modules()
    local bot = api.MakeHero('npc_dota_hero_crystal_maiden', { CanBeSeen = true })
    bot.assignedRole = nRole or 5
    api.install({ bot = bot })
    GetTeam = function() return TEAM_RADIANT end
    bot.GetTeam = function() return TEAM_RADIANT end
    GetGameMode = function() return bTurbo == false and 1 or GAMEMODE_TURBO end
    return dofile(HERO)
end

local function with_candidate(sId, fn)
    local f = assert(io.open(SIDE_PATH, 'w'))
    f:write("return { side = 'radiant', cand = '" .. sId .. "' }\n")
    f:close()
    local ok, err = pcall(fn)
    os.remove(SIDE_PATH)
    if not ok then error(err, 0) end
end

--- The SHIPPED pos_5 list, transcribed byte-for-byte from the hero file as it
--- stood before 9fa4898.  Acceptance criterion 1 of GH #144: adding the gate
--- must not itself move the stable version.
local SHIPPED_POS5 = {
    'item_blood_grenade',
    'item_mage_outfit',
    'item_ancient_janggo',
    'item_glimmer_cape',
    'item_boots_of_bearing',
    'item_pipe',
    'item_shivas_guard',
    'item_cyclone',
    'item_sheepstick',
    'item_aghanims_shard',
    'item_wind_waker',
    'item_moon_shard',
    'item_ultimate_scepter_2',
}

local function assert_same_list(tGot, tWant, sWhat)
    assert(type(tGot) == 'table', sWhat .. ': buy list is not a table')
    assert(#tGot == #tWant,
        sWhat .. ': expected ' .. #tWant .. ' entries, got ' .. #tGot)
    for i = 1, #tWant do
        assert(tGot[i] == tWant[i], sWhat .. ': entry ' .. i .. ' is '
            .. tostring(tGot[i]) .. ', expected ' .. tostring(tWant[i]))
    end
end

local tests = {}

-- ---------------------------------------------------------------------------
-- 1. The GATE, run rather than read.  Prose about a line must not be the only
--    thing holding that line (the 2026-08-22 21:48Z lesson), and a build gate
--    is cheap to actually execute, so these load the hero file both ways.

tests['[hero] gate off: pos_5 is the shipped tranquil list byte for byte'] = function()
    -- No soak_side file exists -> IsSoakCandidate('cmboots') is false.
    local X = load_cm(true, 5)
    assert_same_list(X.sBuyList, SHIPPED_POS5, 'pos_5 gate off, turbo')
end

tests['[hero] gate off: the other two CM roles are untouched'] = function()
    -- Acceptance criterion 1 of GH #144 covers all three role lists, not just
    -- the one the candidate edits.  pos_1/pos_2/pos_4 alias or stand alone;
    -- the transform must not have leaked into any of them.
    local tPos3 = load_cm(true, 3).sBuyList
    local tPos4 = load_cm(true, 4).sBuyList
    assert(tPos3[1] == 'item_mage_outfit',
        'pos_3 must still open on the mage outfit; got ' .. tostring(tPos3[1]))
    assert(tPos4[1] == 'item_priest_outfit',
        'pos_4 must still open on the priest outfit; got ' .. tostring(tPos4[1]))
    assert_same_list(load_cm(true, 1).sBuyList, tPos3, 'pos_1 aliases pos_3')
    assert_same_list(load_cm(true, 2).sBuyList, tPos3, 'pos_2 aliases pos_3')
end

tests['[hero] armed in NORMAL mode leaves the shipped list (turbo-only)'] = function()
    with_candidate(CAND, function()
        assert_same_list(load_cm(false, 5).sBuyList, SHIPPED_POS5,
            'pos_5 armed but normal mode')
    end)
end

tests['[hero] a different armed candidate leaves the shipped list'] = function()
    with_candidate('wkbuild', function()
        assert_same_list(load_cm(true, 5).sBuyList, SHIPPED_POS5,
            'pos_5 with another candidate armed')
    end)
end

tests['[hero] armed in turbo: the arcane opener, and Bearing gone with it'] = function()
    with_candidate(CAND, function()
        local t = load_cm(true, 5).sBuyList
        assert(t[1] == 'item_blood_grenade',
            'the grenade still opens the list; got ' .. tostring(t[1]))
        assert(t[2] == 'item_mage_arcane_outfit',
            'the opener must become the arcane variant; got ' .. tostring(t[2]))
        assert(not has(t, 'item_mage_outfit'),
            'the tranquil outfit must be gone, not carried alongside')
        assert(not has(t, 'item_boots_of_bearing'),
            'Boots of Bearing must leave with the tranquils. Its recipe consumes '
            .. 'a pair of TRANQUIL boots, so with arcane in the opener it buys a '
            .. 'second pair and movement speed does not stack.')
        assert(#t == #SHIPPED_POS5 - 1,
            'exactly one entry (Bearing) may leave; got ' .. #t)
        -- Derived, not duplicated: every other entry keeps its relative order.
        local tRest = {}
        for _, s in ipairs(SHIPPED_POS5) do
            if s ~= 'item_boots_of_bearing' and s ~= 'item_mage_outfit' then
                tRest[#tRest + 1] = s
            end
        end
        local tGot = {}
        for _, s in ipairs(t) do
            if s ~= 'item_mage_arcane_outfit' then tGot[#tGot + 1] = s end
        end
        assert_same_list(tGot, tRest, 'armed list minus the outfit')
    end)
end

tests['[hero] armed: the swap moves the boots and nothing else'] = function()
    local tMage, tArc = outfit('item_mage_outfit'), outfit('item_mage_arcane_outfit')
    assert(#tMage == #tArc,
        'the two outfits must stay entry-for-entry comparable so the boots are '
        .. 'the only lever; got ' .. #tMage .. ' vs ' .. #tArc)
    local nDiff = 0
    for i = 1, #tMage do if tMage[i] ~= tArc[i] then nDiff = nDiff + 1 end end
    assert(nDiff == 1, 'exactly one entry may differ between the two outfits; '
        .. nDiff .. ' do. mage=' .. table.concat(tMage, ',')
        .. ' arcane=' .. table.concat(tArc, ','))
    assert(has(tMage, 'item_tranquil_boots') and has(tArc, 'item_arcane_boots'),
        'and the one entry must be the boots')
    assert(not has(tArc, 'item_tranquil_boots'),
        'the arcane outfit must not carry both pairs')
    local src = read_file(ITEMS)
    local sSentinel = src:match("%['item_mage_arcane_outfit'%]%s*=%s*\"(item_[%w_]+)\"")
    assert(sSentinel == 'item_arcane_boots',
        'tDefineItemRealName decides when an outfit counts as OWNED, so it must '
        .. 'name a component this outfit actually buys; mage points at its '
        .. 'tranquil boots and priest at its arcane boots. This one reads '
        .. tostring(sSentinel))
end

-- ---------------------------------------------------------------------------
-- 1b. The collateral 9fa4898 caused off Crystal Maiden's own file, and why the
--     new macro had to be a separate entry instead of an edit to the old one.
--
--     9fa4898's commit message justified editing item_crystal_maiden_outfit on
--     the premise that it was "referenced by nothing since before the fork".
--     It is referenced by sixteen other hero files.  These pin the premise so
--     it cannot be relied on again by inspection.

tests['[hero] item_crystal_maiden_outfit is other heroes\' property, not CM\'s'] = function()
    local p = assert(io.popen(
        "grep -rlF item_crystal_maiden_outfit bots/BotLib 2>/dev/null"))
    local tFiles = {}
    for line in p:lines() do
        if not line:find('hero_crystal_maiden%.lua$') then tFiles[#tFiles + 1] = line end
    end
    p:close()
    assert(#tFiles >= 16,
        'only ' .. #tFiles .. ' other hero files buy item_crystal_maiden_outfit. '
        .. 'If that has genuinely dropped, re-read GH #144 before treating the '
        .. 'outfit as Crystal Maiden-only -- the whole point of the separate '
        .. 'item_mage_arcane_outfit entry is that this one is shared.')
    -- ... and CM herself must NOT be among them any more.
    local tPos5 = pos5_list()
    assert(not has(tPos5, 'item_crystal_maiden_outfit'),
        'CM\'s shipped pos_5 must not reference the shared outfit: editing it '
        .. 'for her would move sixteen other heroes\' openers with her')
end

tests['[hero] the shared outfit kept its own boots sentinel'] = function()
    local src = read_file(ITEMS)
    local sSentinel = src:match("%['item_crystal_maiden_outfit'%]%s*=%s*\"(item_[%w_]+)\"")
    assert(sSentinel == 'item_magic_wand',
        'item_crystal_maiden_outfit\'s sentinel decides when SIXTEEN other heroes '
        .. 'consider their opener complete, and arcane_boots sits two entries '
        .. 'ahead of the magic wand recipe in the component list -- moving it '
        .. 'there ends their openers early. It reads ' .. tostring(sSentinel)
        .. '. Price it on their frames before moving it.')
    local tShared = outfit('item_crystal_maiden_outfit')
    local nTango = 0
    for _, s in ipairs(tShared) do if s == 'item_tango' then nTango = nTango + 1 end end
    assert(nTango == 1,
        'item_crystal_maiden_outfit buys ' .. nTango .. ' tangos. It bought one '
        .. 'from before the fork until 9fa4898 added a second for Crystal '
        .. 'Maiden\'s sake; that is a live change to sixteen other heroes.')
end

-- ---------------------------------------------------------------------------
-- 2. The corpus the numbers were read off, and the two arms.

tests['[hero] census: the corpus still carries the arms these numbers came from'] = function()
    assert(C.cm_frames >= 42,
        'the corpus lost CM frames (' .. tostring(C.cm_frames) .. ' < 42)')
    assert(ARM.T.n + ARM.A.n + ARM.X.n == C.cm_frames,
        'the boots arms must partition the CM frames')
    assert(ARM.T.n >= 23, 'tranquil arm: ' .. ARM.T.n .. ' frames (was 23)')
    assert(ARM.A.n >= 7, 'arcane arm: ' .. ARM.A.n .. ' frames (was 7)')
    -- The confound this comparison lives or dies on, reported not assumed.
    local lvT, lvA = ARM.T.lv / ARM.T.n, ARM.A.lv / ARM.A.n
    assert(math.abs(lvT - lvA) < 1.0,
        'the two arms are no longer at comparable hero level (' ..
        string.format('%.2f vs %.2f', lvT, lvA) .. '). The observational half of '
        .. 'this decision assumed they were; re-read it before quoting it.')
end

tests['[hero] the shortfall the swap is aimed at'] = function()
    assert(ARM.T.slots >= 45, 'ready slots on the tranquil arm: ' .. ARM.T.slots)
    assert(ARM.T.blocked >= 12,
        'unaffordable ready slots on the tranquil arm: ' .. ARM.T.blocked
        .. ' (was 12 of 45). If this has closed on its own, the change no longer '
        .. 'has a target -- find out what closed it.')
    assert(ARM.T.blocked / ARM.T.slots > 0.2,
        'the tranquil arm cannot pay for '
        .. string.format('%.1f%%', 100 * ARM.T.blocked / ARM.T.slots)
        .. ' of its ready spells')
end

tests['[hero] the observational arm: arcane CMs are not mana-blocked at all'] = function()
    assert(ARM.A.slots >= 14, 'ready slots on the arcane arm: ' .. ARM.A.slots)
    assert(ARM.A.blocked == 0,
        'the arcane arm now has ' .. ARM.A.blocked .. ' unaffordable ready slots '
        .. '(was 0 of 14). That zero is half the case for this build change.')
    -- Stated as the weak claim it is: a clean 14 under the other arm's rate.
    local p = (1 - ARM.T.blocked / ARM.T.slots) ^ ARM.A.slots
    assert(p < 0.05, 'under the tranquil arm\'s own blocked rate a clean arcane '
        .. 'arm has probability ' .. string.format('%.3f', p)
        .. '; it is no longer even suggestive')
end

tests['[hero] how much of the shortfall each mana delta reaches'] = function()
    assert(DELTA[125] and DELTA[144] and DELTA[275], 'all three deltas reported')
    assert(DELTA[125] >= 9, 'arcane\'s flat +125 unblocks ' .. DELTA[125]
        .. ' of the ' .. ARM.T.blocked .. ' blocked slots (was 9 of 12)')
    assert(DELTA[275] >= DELTA[144] and DELTA[144] >= DELTA[125],
        'the deltas must be monotone; got ' .. DELTA[125] .. '/' .. DELTA[144]
        .. '/' .. DELTA[275])
    -- The honest calibration: the flat half of this item is SMALLER than the
    -- talent the t10 file declined. If that ever stops being true, the argument
    -- in the header changes shape.
    assert(DELTA[125] <= DELTA[144],
        'arcane\'s flat +125 now reaches at least as far as the +144 talent; '
        .. 'the header\'s "this does not rest on the flat mana" is stale')
end

-- ---------------------------------------------------------------------------
-- 3. The removed terminus, and why its zero may not be spent as evidence.

tests['[hero] Boots of Bearing: unowned, and out of window rather than empty'] = function()
    assert(#BEARING == 0,
        'a corpus unit owns Boots of Bearing now (' .. tostring((BEARING[1] or {}).fix)
        .. '). The terminus this change removed is priceable at last -- price it '
        .. 'before leaving the removal in place.')
    assert(WINDOW ~= nil, 'the sweep must report its observation window')
    assert(WINDOW.max < 1500,
        'the corpus now reaches t=' .. WINDOW.max .. 's. Past ~11:30 a 4225g '
        .. 'fifth item stops being out-of-window, and the Bearing zero above '
        .. 'starts meaning something. Re-read it.')
    -- The path up to the terminus IS walked, which is what makes the removal a
    -- decision rather than a tidy-up: a third of the CM frames own the drum.
    assert(C.cm_janggo >= 12,
        'CM frames owning ancient_janggo: ' .. tostring(C.cm_janggo)
        .. ' (was 12). The drum is the step before Bearing.')
end

-- ---------------------------------------------------------------------------
-- 4. The anchors, asserted rather than trusted.  With every cost at the mock's
--    default 0 the whole mana channel reads "nothing was ever blocked" -- green,
--    fast, and agreeing with itself.

tests['[hero] the mana-cost anchors reached the sweep'] = function()
    assert(#SLOTS > 0, 'the sweep reported no ready ability slots at all')
    local nCosted, nRanked = 0, 0
    for _, s in ipairs(SLOTS) do
        if s.cost > 0 then nCosted = nCosted + 1 end
        if s.rank > 0 then nRanked = nRanked + 1 end
    end
    assert(nCosted == #SLOTS,
        (#SLOTS - nCosted) .. ' ready slots were priced at 0 mana; the datafeed '
        .. 'anchor is not reaching them')
    assert(nRanked == #SLOTS, 'a ready slot must be a trained one')
    local bBlockedIsReal = false
    for _, s in ipairs(SLOTS) do
        if s.blocked then
            assert(s.mp < s.cost, 'a blocked slot must actually be short of mana')
            bBlockedIsReal = true
        end
    end
    assert(bBlockedIsReal, 'not one blocked slot in the whole corpus -- the '
        .. 'comparison this file rests on has no domain')
end

return tests

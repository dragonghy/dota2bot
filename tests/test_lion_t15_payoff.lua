-- [hero] Lion t15: -2.0s Hex cooldown  vs  +15% To Hell and Back Debuff/Spell
-- Amp.  Backlog section 20 re-opened this pair on 2026-08-23, not because the
-- verdict looked wrong but because one of the two legs it stood on was a false
-- statement about the corpus.
--
-- VERDICT 2026-08-23: STILL NOT FLIPPED.  The row stays {10,0} = index [4],
-- special_bonus_unique_lion_11 (the To Hell and Back amp).  What changes is the
-- REASON: both sides are now measured, where before one side was declared
-- unobservable and the other was priced at the wrong ability rank.
--
-- TWO CORRECTIONS TO THE RECORD, and they are the point of this file
--   (1) "[4]'s two windows are something the dumper cannot see at all (it does
--       not dump modifiers, GH #27)" -- VOID.  Fixtures cut after 2026-08-19 do
--       carry modifiers, and both windows are in this corpus right now: of the
--       Lion frames that carry modifier state, 3 are inside a To Hell and Back
--       window (2 x modifier_lion_to_hell_and_back_buff, 1 x
--       ..._to_hell_and_back_respawn_buff).  GH #27 still holds for ITEM CHARGES;
--       it never held for modifiers.
--   (2) "[3] pays inside the last 2s of a 24 second cooldown, because the build
--       keeps Hex at rank 1 until level 12" -- WRONG RANK, and wrong level.  24s
--       is Hex at rank 1, which is what the CORPUS holds (its Lions top out at
--       level 11).  It is not what the DOMAIN holds: the talent exists only from
--       level 15, and by level 15 this file's own build row has put three points
--       in Hex -- a 16 second cooldown.  The old reading also had rank 2 arriving
--       at level 12; it arrives at 13.  The cause is a mapping bug shared with
--       the Axe t15 reading and now fixed for both in tests/skill_level_map.lua:
--       the build row's index is NOT the hero level, because J.Skill.GetSkillList
--       spends levels 10 and 15 on talents.
--       Corrected, the challenger is WORTH MORE than the old note said: -2.0s off
--       16s is +12.5% Hex casts at the moment of choice (and +16.7% from level 16,
--       when Hex reaches rank 4 and a 12s cooldown), not the +8.3% that a 24s
--       cooldown implies.
--
-- THE RULER (unchanged, the one all five focus heroes' ladders were decided on):
-- payoff REACHABILITY -- how much of the game each talent's payout condition is
-- actually true for, not which single payout is larger.
--
-- WHY THE BIGGER-THAN-ADVERTISED CHALLENGER STILL LOSES.  A cooldown reduction
-- only pays when the cooldown is what stopped a cast.  On the Lion frames in this
-- corpus that have Hex learned, Hex is READY AND AFFORDABLE on 9 of 20 -- Lion is
-- standing around with his disable up nearly half the time, so what is scarce is
-- targets, not Hex charges.  The incumbent has the opposite shape: its amp is a
-- multiplier on the casts that DO happen (and on spell damage), live on about a
-- third of the frames that can be checked for it.
--
-- WHAT IS MEASURED HERE
--   (1) LEVEL MAP -- the rank each ability holds at level 15, obtained by running
--       the shipped J.Skill.GetSkillList, not by counting row entries.
--   (2) STRUCTURAL -- what -2.0s is worth as a fraction of Hex's cast rate at the
--       rank the domain actually holds.
--   (3) CORPUS, incumbent -- how many Lion frames sit inside a To Hell and Back
--       window, against the number of frames that could have shown one.
--   (4) CHANNEL HEALTH, challenger -- how often Hex is ready anyway (the
--       reduction is worthless there), and how often a frame sits in the <= 2s
--       band the talent converts.  A zero in a narrow band is recorded as
--       UNDERPOWERED, never as EMPTY (GH #115).
--
-- HONEST BOUNDS, all of which cut against this reading
--   * NO FRAME IN THIS CORPUS IS IN DOMAIN.  The highest level any Lion reaches
--     in a fixture is 11; the talent exists at 15.  Every corpus number above is
--     a proxy read four levels below the tier, and is pinned as such.
--   * n = 3 windows, out of 10 modifier-bearing Lion frames.  That is an
--     existence read on a fixture library curated for OTHER investigations, not
--     a density (the stream's standing section Y.2 limit).
--   * "Inside a window" is not "collected a payout".  Converting window uptime
--     into damage or into debuff seconds needs the spell amp applied to something;
--     fixtures dump neither spell amp nor damage type.
--   * The ready-Hex count says the cooldown was not binding AT THOSE INSTANTS.  It
--     does not count casts DELAYED by cooldown, which is the event-side question
--     still open as queue.json hero-4.
--   * Talent magnitudes are NOT in the datafeed: special_values is empty for both
--     talents there, so -2.0s and +15% come from odota dotaconstants.  Liquipedia
--     was rate-limited on 2026-08-23 and could not corroborate a third time.
--
-- THE INCUMBENT'S WEAKNESS, stated so the next reader does not have to find it:
-- the respawn half of the innate ends the moment Lion gets a kill or an assist,
-- i.e. it is switched off by success, and the kill half requires having already
-- got one.  Neither window is available in the fight that starts from even
-- footing.  That is the strongest argument for flipping, and it is not enough
-- against a challenger whose resource is idle half the time.
--
-- EXTERNAL ANCHORS, both read 2026-08-23:
--   https://www.dota2.com/datafeed/herodata?language=english&hero_id=26
--     -- ability specs (Hex cooldowns 24/20/16/12, mana 110/140/170/200; the
--        innate's 20% spell amp for 90s and 20% debuff amp), and the talent NAMES.
--   https://raw.githubusercontent.com/odota/dotaconstants/master/build/abilities.json
--     -- the talent VALUES the datafeed omits: special_bonus_unique_lion_5 =
--        "-2.0s Hex Cooldown", special_bonus_unique_lion_11 = "+15% To Hell And
--        Back Debuff/Spell Amp".

package.path = 'tests/?.lua;' .. package.path
local api = require('mock.bot_api')
local cs = require('corpus_scale')
local skillmap = require('skill_level_map')

local HERO_SRC = 'bots/BotLib/hero_lion.lua'
local TALENT_LEVEL = 15

-- datafeed hero_id=26, 2026-08-23.  Index = ability rank.
local HEX = {
    cooldown = { 24, 20, 16, 12 },
    duration = { 2.0, 2.4, 2.8, 3.2 },
    mana = { 110, 140, 170, 200 },
}
-- The innate, whose two windows [4] amplifies.  Flat values, no ranks.
local INNATE = {
    respawn_duration = 90,
    spell_amp = 20,
    debuff_amp = 20,
}
local TALENT_HEX_CD = 2.0   -- odota: special_bonus_unique_lion_5
local TALENT_AMP = 15       -- odota: special_bonus_unique_lion_11

local WINDOW_MODIFIERS = {
    'modifier_lion_to_hell_and_back_buff',          -- killed/assisted, victim dead
    'modifier_lion_to_hell_and_back_respawn_buff',  -- respawned, until kill/assist
}

-- ---------------------------------------------------------------------------
-- Corpus scan.

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

local function ability(unit, sName)
    for _, a in ipairs(unit.abilities or {}) do
        if a.name == sName then return a end
    end
    return nil
end

--- One pass over the corpus.  Frames that carry no modifier data are counted
--- apart, so a zero is never read as "it never happened" when it means "it was
--- never dumped" -- the mistake this whole file exists to undo.
local function scan()
    local r = {
        lion_frames = 0, with_modifiers = 0, max_level = 0, in_domain = 0,
        window_frames = 0, window_by_name = {},
        hex_learned = 0, hex_rank_above_1 = 0,
        hex_ready = 0, hex_ready_affordable = 0,
        hex_on_cooldown = 0, hex_in_band = 0, expected_band = 0,
        respawn_overrun = {},
        slot_names = {},
    }
    for _, m in ipairs(WINDOW_MODIFIERS) do r.window_by_name[m] = 0 end

    for _, path in ipairs(fixture_paths()) do
        local fx = dofile(path)
        if type(fx) == 'table' and fx.units then
            local bMods = false
            local lion = nil
            for _, u in ipairs(fx.units) do
                if u.modifiers ~= nil then bMods = true end
                if u.name == 'npc_dota_hero_lion' and u.alive then lion = u end
            end
            if lion ~= nil then
                r.lion_frames = r.lion_frames + 1
                if (lion.level or 0) > r.max_level then r.max_level = lion.level end
                if (lion.level or 0) >= TALENT_LEVEL then r.in_domain = r.in_domain + 1 end
                for i, a in ipairs(lion.abilities or {}) do
                    r.slot_names[i] = r.slot_names[i] or a.name
                end

                local hex = ability(lion, 'lion_voodoo')
                local nRank = hex and (hex.level or 0) or 0
                if nRank > 0 then
                    r.hex_learned = r.hex_learned + 1
                    if nRank > 1 then r.hex_rank_above_1 = r.hex_rank_above_1 + 1 end
                    local nCd = hex.cd or 0
                    if nCd <= 0 then
                        r.hex_ready = r.hex_ready + 1
                        if (lion.mp or 0) >= HEX.mana[nRank] then
                            r.hex_ready_affordable = r.hex_ready_affordable + 1
                        end
                    else
                        r.hex_on_cooldown = r.hex_on_cooldown + 1
                        -- The band the talent converts: a cast that arrives with
                        -- this much cooldown left would have been legal with it.
                        if nCd <= TALENT_HEX_CD then r.hex_in_band = r.hex_in_band + 1 end
                        -- ... and what a uniformly-timed frame would hit, so the
                        -- observed count can be read as UNDERPOWERED or EMPTY.
                        r.expected_band = r.expected_band
                            + TALENT_HEX_CD / HEX.cooldown[nRank]
                    end
                end

                if bMods and lion.modifiers ~= nil then
                    r.with_modifiers = r.with_modifiers + 1
                    local bWindow = false
                    for _, sName in ipairs(WINDOW_MODIFIERS) do
                        local m = has_modifier(lion, sName)
                        if m ~= nil then
                            bWindow = true
                            r.window_by_name[sName] = r.window_by_name[sName] + 1
                            if sName:find('respawn', 1, true)
                                and (m.remaining or 0) > INNATE.respawn_duration + 0.05 then
                                r.respawn_overrun[#r.respawn_overrun + 1] =
                                    path .. ' remaining=' .. tostring(m.remaining)
                            end
                        end
                    end
                    if bWindow then r.window_frames = r.window_frames + 1 end
                end
            end
        end
    end
    return r
end

local CORPUS = scan()

local tests = {}

-- ---------------------------------------------------------------------------
-- 1. What the row selects, and that the reasoning travels with it.

tests['[hero] lion t15 still selects [4] +15% To Hell and Back amp'] = function()
    local rows = skillmap.talent_rows(skillmap.read_file(HERO_SRC))
    api.reset_modules()
    api.install({ bot = api.MakeHero('npc_dota_hero_lion') })
    local J = require(GetScriptDirectory() .. '/FunLib/jmz_func')
    local pick = J.Skill.GetTalentBuild(rows)[2]
    assert(pick == 4,
        'lion now takes talent index ' .. pick .. ' at level 15, not [4] '
        .. 'special_bonus_unique_lion_11 (+15% To Hell and Back Debuff/Spell Amp). '
        .. 'Index [3] is special_bonus_unique_lion_5 (-2.0s Hex cooldown), which '
        .. 'this file adjudicated on 2026-08-23 and did NOT take.  If you are '
        .. 'flipping it, re-take the readings below first -- the verdict rests on '
        .. 'Hex being ready anyway on nearly half the frames that have it learned, '
        .. 'which is what makes a cooldown reduction cheap to give up.')
end

tests['[hero] the lion t15 verdict is written into the hero file, not only here'] = function()
    -- Each needle is a DISTINCT load-bearing claim of the block, the way the Axe
    -- t15 guard is built.  Needles are matched literally, so a phrase that the
    -- comment wraps across two lines can never be one.
    local src = skillmap.read_file(HERO_SRC)
    for _, needle in ipairs({
        't15 RE-EXAMINED 2026-08-23',       -- the verdict, and when it was taken
        'special_bonus_unique_lion_5',      -- what it rejected, by name
        'rank 3, a 16 second cooldown',     -- the rank correction that re-priced it
        'READY and affordable on 9 of 20',  -- the measured reason the challenger loses
        'level 11',                         -- the proxy caveat
        'tests/test_lion_t15_payoff.lua',   -- where to re-take the reading
    }) do
        assert(src:find(needle, 1, true),
            'the t15 rationale block in ' .. HERO_SRC .. ' no longer mentions "'
            .. needle .. '".  A talent row that ships without a gate IS its '
            .. 'rationale -- the file is the only place that reasoning lives, and '
            .. 'each needle is a separate claim the block has to carry.')
    end
    assert(not src:find('does not dump modifiers', 1, true),
        HERO_SRC .. ' still claims the dumper does not dump modifiers.  That claim '
        .. 'was the load-bearing half of the OLD t15 note and it is false: this '
        .. 'corpus carries ' .. CORPUS.window_frames .. ' To Hell and Back window '
        .. 'frame(s) right now.  GH #27 survives only for item charges.')
end

-- ---------------------------------------------------------------------------
-- 2. The level map -- the correction that re-prices the challenger.

tests['[hero] lion t15: Hex is rank 3 at level 15, not rank 4 and not rank 1'] = function()
    local src = skillmap.read_file(HERO_SRC)
    local row = skillmap.build_row(src)
    local slot = skillmap.ability_slots(src)
    assert(slot.abilityW == 2,
        HERO_SRC .. ' now binds abilityW = sAbilityList[' .. tostring(slot.abilityW)
        .. '].  The HEX spec in this file is the datafeed entry for lion_voodoo and '
        .. 'is attached to a slot, so re-pointing the handle moves the whole reading.')

    local ranks, _, spent =
        skillmap.ranks_at('npc_dota_hero_lion', row, skillmap.talent_rows(src), TALENT_LEVEL)
    assert(spent == 13,
        'by level ' .. TALENT_LEVEL .. ' this build has spent ' .. spent
        .. ' ability points, not 13.  13 is the whole correction: levels 10 and 15 '
        .. 'go to TALENTS in J.Skill.GetSkillList, so a 15-entry row is two entries '
        .. 'short of finished when the t15 choice is made.  If this is 15 again, '
        .. 'someone has gone back to counting row indices as hero levels.')
    assert(ranks[slot.abilityW] == 3,
        'Hex is rank ' .. tostring(ranks[slot.abilityW]) .. ' at level ' .. TALENT_LEVEL
        .. ', not 3.  Its rank sets the cooldown that -2.0s is a fraction OF: rank 1 '
        .. 'is 24s (what the corpus holds, and what the pre-2026-08-23 note wrongly '
        .. 'used for the domain), rank 3 is 16s, rank 4 is 12s.')
end

tests['[hero] lion t15: the 4th Hex point lands at level 16, after the choice'] = function()
    local src = skillmap.read_file(HERO_SRC)
    local row = skillmap.build_row(src)
    local slot = skillmap.ability_slots(src)
    local rows = skillmap.talent_rows(src)
    local at15 = select(1, skillmap.ranks_at('npc_dota_hero_lion', row, rows, 15))
    local at16 = select(1, skillmap.ranks_at('npc_dota_hero_lion', row, rows, 16))
    assert(at15[slot.abilityW] == 3 and at16[slot.abilityW] == 4,
        'Hex goes ' .. tostring(at15[slot.abilityW]) .. ' -> '
        .. tostring(at16[slot.abilityW]) .. ' across level 16, not 3 -> 4.  The '
        .. 'talent is chosen one level BEFORE Hex is maxed, which is why the '
        .. 'domain cooldown is 16s and not 12s.')
end

tests['[hero] lion t15: the corpus dumps Hex where this file says it is'] = function()
    assert(CORPUS.slot_names[2] == 'lion_voodoo',
        'the corpus now dumps Lion ability slot 2 as ' .. tostring(CORPUS.slot_names[2])
        .. ', not lion_voodoo.  That dumped order is the only offline evidence for '
        .. 'what sAbilityList[2] NAMES -- the mock answers synthetic slot names, so '
        .. 'it cannot corroborate this.')
    assert(CORPUS.slot_names[1] == 'lion_impale' and CORPUS.slot_names[3] == 'lion_mana_drain',
        'the corpus Lion ability order is now ' .. tostring(CORPUS.slot_names[1]) .. ' / '
        .. tostring(CORPUS.slot_names[2]) .. ' / ' .. tostring(CORPUS.slot_names[3])
        .. '.  Slots 1 and 3 are pinned too, because a shifted list would leave slot '
        .. '2 correct by accident.')
end

-- ---------------------------------------------------------------------------
-- 3. Structural: what the challenger is worth once priced at the right rank.

tests['[hero] lion t15: -2.0s is +14.3% Hex casts in domain, +20% from level 16'] = function()
    -- Cast rate, not "fraction of the cooldown removed": cutting 2s off 16s does
    -- not buy 12.5% more casts, it buys 16/14 - 1 = 14.3%.  The first draft of
    -- this file asserted 12.5% and the arithmetic caught it.
    local at15 = HEX.cooldown[3]
    local at16 = HEX.cooldown[4]
    local at1 = HEX.cooldown[1]
    local gain15 = at15 / (at15 - TALENT_HEX_CD) - 1
    local gain16 = at16 / (at16 - TALENT_HEX_CD) - 1
    local gain1 = at1 / (at1 - TALENT_HEX_CD) - 1
    assert(math.abs(gain15 - 1 / 7) < 0.002,
        'the in-domain cast-rate gain is now ' .. gain15 .. ', not 0.143 (2.0s off a '
        .. '16s cooldown).  Re-read the datafeed.')
    assert(math.abs(gain16 - 0.20) < 0.002,
        'the rank-4 cast-rate gain is now ' .. gain16 .. ', not 0.20 (2.0s off a '
        .. '12s cooldown).')
    assert(gain15 > gain1 * 1.5,
        'the corrected challenger (' .. gain15 .. ') is no longer worth appreciably '
        .. 'more than the rank-1 reading (' .. gain1 .. ') the pre-2026-08-23 note '
        .. 'used.  That re-pricing is the whole reason this pair was re-opened; if '
        .. 'it has collapsed, the old note was right by accident and this file needs '
        .. 'rewriting.')
end

tests['[hero] lion t15: the incumbent amplifies spell damage too, not only Hex length'] = function()
    -- The pre-2026-08-23 note dismissed the pair as "both sides buy the same
    -- thing (Hex disable: [3] more casts, [4] longer ones)".  Half of the innate
    -- is SPELL amp -- Earth Spike and Finger of Death damage -- so the two sides
    -- are not buying the same thing, and the incumbent's half is the broader one.
    assert(INNATE.spell_amp == 20 and INNATE.debuff_amp == 20,
        'the innate no longer carries 20% / 20%; the talent is a flat +'
        .. TALENT_AMP .. ' percentage points on BOTH, so its relative size moves '
        .. 'with these.  Re-read the datafeed.')
    local relative = TALENT_AMP / INNATE.spell_amp
    assert(math.abs(relative - 0.75) < 0.01,
        'the talent is now ' .. relative .. 'x the innate, not +75%.')
end

-- ---------------------------------------------------------------------------
-- 4. Corpus, incumbent: the windows are observable, and here they are.

tests['[hero] lion t15: To Hell and Back windows ARE in the corpus (GH #27 leg void)'] = function()
    assert(CORPUS.with_modifiers > 0,
        'no Lion frame in this corpus carries modifier state at all.  If that is '
        .. 'true again, the 2026-08-23 correction has been undone and the old '
        .. '"unobservable" note becomes accurate again -- say so explicitly rather '
        .. 'than letting this file assert a measurement it cannot take.')
    -- Ratchets, not equalities (tests/corpus_scale.lua): these are sums over
    -- fixtures, so the corpus may add windows but must never lose one.
    cs.ratchet(CORPUS.window_frames, 3,
        'Lion frames inside a To Hell and Back window (the whole basis for calling '
        .. 'the incumbent measurable at all)')
    cs.ratchet(CORPUS.window_by_name['modifier_lion_to_hell_and_back_buff'], 2,
        'kill-side To Hell and Back windows')
    -- BOTH halves have to be present: one alone only proves half the innate.
    cs.ratchet(CORPUS.window_by_name['modifier_lion_to_hell_and_back_respawn_buff'], 1,
        'respawn-side To Hell and Back windows')
end

tests['[hero] lion t15: window uptime is read against the frames that COULD show it'] = function()
    assert(CORPUS.window_frames <= CORPUS.with_modifiers,
        'more window frames (' .. CORPUS.window_frames .. ') than modifier-bearing '
        .. 'Lion frames (' .. CORPUS.with_modifiers .. '); the denominator is wrong.')
    -- A band, not a floor: the verdict rests on this being a SUBSTANTIAL share of
    -- the game (~30% on 2026-08-23), and a share that ran away upward would mean
    -- the corpus had become a set of post-death frames rather than a sample.
    cs.share(CORPUS.window_frames, CORPUS.with_modifiers, 0.20, 0.60,
        'share of modifier-bearing Lion frames inside a To Hell and Back window', 8)
    -- And the denominator that must NOT be used: total Lion frames, most of which
    -- predate modifier dumping and are structurally silent on this question.
    assert(CORPUS.with_modifiers < CORPUS.lion_frames,
        'every Lion frame now carries modifier state (' .. CORPUS.lion_frames
        .. ' of ' .. CORPUS.lion_frames .. ').  Good -- but this file computes the '
        .. 'share against modifier-bearing frames precisely because that was not '
        .. 'true; re-read the two denominators before trusting the number.')
end

tests['[hero] lion t15: the respawn window respects its own 90s duration'] = function()
    assert(#CORPUS.respawn_overrun == 0,
        'a respawn buff reports more time REMAINING than the innate lasts: '
        .. table.concat(CORPUS.respawn_overrun, ', ') .. '.  Only `remaining` is '
        .. 'usable on a modifier -- `elapsed` keeps counting across refreshes '
        .. '(the Axe Battle Hunger lesson) -- so if even remaining overruns, the '
        .. 'dump or the datafeed duration is wrong, not the arithmetic.')
end

-- ---------------------------------------------------------------------------
-- 5. Channel health, challenger: the measurement that decides the pair.

tests['[hero] lion t15: Hex is ready and affordable on nearly half the frames'] = function()
    cs.ratchet(CORPUS.hex_learned, 20, 'Lion frames with Hex learned')
    assert(CORPUS.hex_ready + CORPUS.hex_on_cooldown == CORPUS.hex_learned,
        'the ready/on-cooldown split (' .. CORPUS.hex_ready .. ' + '
        .. CORPUS.hex_on_cooldown .. ') does not account for all '
        .. CORPUS.hex_learned .. ' Hex-learned frames.')
    -- This count IS the verdict: a cooldown reduction cannot pay on a frame where
    -- the cooldown is already zero.
    cs.ratchet(CORPUS.hex_ready, 9,
        'Lion frames with Hex ALREADY off cooldown (where -2.0s buys nothing)')
    -- Pinned from BOTH ends, so swapping the two branches of the cd test cannot
    -- leave the reading looking healthy: the corpus is 9 ready / 11 on cooldown,
    -- and an inverted split reads 11 / 9.
    cs.ratchet(CORPUS.hex_on_cooldown, 11,
        'Lion frames with Hex ON cooldown (the denominator of the <= 2s band below)')
    cs.universal(CORPUS.hex_ready_affordable, CORPUS.hex_ready,
        'ready-Hex frames that can pay Hex\'s own mana cost', 5)
    assert(CORPUS.hex_ready_affordable == CORPUS.hex_ready,
        'only ' .. CORPUS.hex_ready_affordable .. ' of ' .. CORPUS.hex_ready
        .. ' ready-Hex frames can pay Hex\'s own mana cost.  On 2026-08-23 all of '
        .. 'them could (the poorest was 176 mana against a rank-1 cost of 110), '
        .. 'which is what separates this pair from Crystal Maiden\'s t10, where the '
        .. 'ability was mana-starved rather than idle.  If Hex has become '
        .. 'mana-bound, "the bottleneck is targets" no longer follows.')
end

tests['[hero] lion t15: the <= 2s conversion band is UNDERPOWERED, not EMPTY'] = function()
    assert(CORPUS.hex_on_cooldown > 0,
        'no Lion frame in the corpus has Hex on cooldown, so the band cannot be '
        .. 'read at all this round.')
    assert(CORPUS.hex_in_band == 0,
        CORPUS.hex_in_band .. ' frame(s) now sit within ' .. TALENT_HEX_CD
        .. 's of Hex coming up, where 2026-08-23 measured 0.  A NON-zero band is '
        .. 'evidence FOR the challenger; re-open the pair rather than editing this '
        .. 'number.')
    -- The point of the expectation: 0 hits out of this many on-cooldown frames is
    -- what a coin this thin looks like, so the zero is a sample-size statement and
    -- not a claim that the band is unreachable (GH #115).
    assert(CORPUS.expected_band > 0.5 and CORPUS.expected_band < 2.0,
        'a uniformly-timed frame would land in the band ' .. CORPUS.expected_band
        .. ' times over this corpus.  The 2026-08-23 reading was ~0.9, which is why '
        .. 'the observed 0 was recorded as UNDERPOWERED rather than EMPTY.  If this '
        .. 'expectation has grown past 2, a continued zero starts to mean something '
        .. 'and the band deserves a real look.')
end

-- ---------------------------------------------------------------------------
-- 6. Honest bounds, pinned as assertions rather than left in prose.

-- ⚠️ 2026-09-06 (hero, GH #566): the corpus grew its first late-game Lion frame
-- (tests/fixtures/f_260905_004847_lion_drain_bkb.lua, t=1266.5, Lion level 24,
-- Hex rank 4) and these wires fired as written.  They are ACKNOWLEDGED, NOT
-- RE-TAKEN -- the round that added the frame was withdrawing `liondrainbkb`,
-- not re-measuring t15.  So the counts move to the new numbers and the wires
-- stay live at them; what does NOT change is the standing of every reading in
-- this file, which is still a BELOW-TIER PROXY.  The one in-domain frame is
-- supply for re-taking them for real; nobody has.
tests['[hero] lion t15: nothing in this corpus is in domain'] = function()
    assert(CORPUS.in_domain == 1,
        CORPUS.in_domain .. ' Lion frame(s) have reached level ' .. TALENT_LEVEL
        .. ', was 1 as of 2026-09-06.  Every reading in this file was taken BELOW '
        .. 'the tier as a proxy and has NOT been re-taken; more in-domain frames '
        .. 'mean more supply for doing that, not a changed verdict.')
    cs.ceiling(CORPUS.max_level, 24,
        'highest Lion level in the corpus (every reading here is a proxy taken '
        .. 'below the tier, and a higher level means it can be re-taken for real)')
    assert(CORPUS.hex_rank_above_1 == 1,
        CORPUS.hex_rank_above_1 .. ' corpus frame(s) hold Hex above rank 1, was 1 as '
        .. 'of 2026-09-06 (the same late-game frame).  Every '
        .. 'corpus cooldown number here assumes rank 1 (24s); the DOMAIN number '
        .. '(16s at rank 3) comes from the build row, not from these frames, and '
        .. 'that split is exactly what the old note got wrong.')
end

return tests

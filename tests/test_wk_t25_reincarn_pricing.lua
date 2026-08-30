-- [hero, GH #328] Wraith King's t25 row, re-priced on measured numbers instead
-- of on the hedge that used to stand in place of them.
--
-- THE BATON THIS FILE TAKES
-- -------------------------
-- hero_skeleton_king.lua kept t25 on [7] (`..._wraith_king_10`, Mortal Strike
-- AbilityCooldown 5 -> 3) over [8] (`..._wraith_king_4`, Reincarnation casts
-- Wraithfire Blast instead of the slow) and then wrote its own escape clause:
--
--     "no frame in this repo shows a Wraith King at 25, so the window length is
--      inferred from ONE post-cap game (GH #235), and 'how often does
--      Reincarnation trigger with enemies inside 900' is a corpus question
--      nobody has asked -- if that number turns out high, [8]'s case improves
--      and this row should be re-priced."
--
-- Replay-check asked it (GH #328, report 20260830T071054Z, detector
-- tools/batch_test/behavioral/wk_reincarn_trigger_domain.py over W17 + W17-R:
-- 71/72 WK games wide, 8 frame-by-frame, 261 trigger episodes, 96 WK
-- hero-games) and handed the pricing back here.  The answer came back LOW --
-- 0.408 triggers per level-25 game -- and four of the facts the paragraph rested
-- on were wrong.  The source block now carries the measurement; this file holds
-- it to the KV and to the shipped row.
--
-- WHAT IS PINNED, AND WHY EACH THING IS PINNED THE WAY IT IS
--
--   * Every number the arithmetic runs on is PARSED -- the cooldowns out of
--     tests/mock/special_value_shapes.lua, the talent names out of
--     tests/mock/talent_slots.lua, the corpus readings out of the source comment
--     itself, the shipped pick out of the file's own tTalentTreeList driven
--     through the real J.Skill.GetTalentBuild.  Nothing here is retyped, so a
--     rebalance or an edited sentence MOVES this file's conclusion instead of
--     leaving it confidently stale.
--   * Section 5 asserts the SIGN, not the size.  Today [7] beats [8] by two
--     orders of magnitude; the day an edit makes those numbers say otherwise
--     this file goes red and its failure text says to move the ROW, because a
--     comment that prices [8] above [7] while the tree still takes [7] is the
--     silent half of this hazard, not the loud one.
--   * Section 6 is the part that is stronger than "[8] loses": with the rank-3
--     cooldown parsed from the KV, the measured t25 window cannot physically
--     hold enough triggers to reach break-even.  It carries an EXPIRY text -- a
--     corpus that ever reports a trigger rate above the ceiling has found
--     something this arithmetic does not model, and the failure says so instead
--     of reading as a regression.
--   * Section 3 is a retraction ratchet.  Each of the four withdrawn claims is
--     checked as ABSENT with a message naming what replaced it, so re-pasting an
--     old paragraph (the way stale prose actually comes back) is loud.
--
-- LIMITS -- READ BEFORE QUOTING ANY NUMBER FROM HERE
--   * No frame is loaded.  This is source, KV snapshot, and arithmetic; the
--     corpus readings are RECORDED from GH #328, and what is ratcheted is that
--     the source states them, that they are internally consistent, and that the
--     verdict follows from them.  It cannot re-derive them -- that needs the
--     archived .dem files and the detector.
--   * The comparison is in EVENTS, not damage.  "Extra enemies inside a 1.6s
--     stun that has expired before he stands up" and "extra 280% crits" are not
--     the same unit and nothing offline converts them.  The sign survives the
--     mismatch only because the gap is ~100x and because the [8] side is the
--     GROSS figure, before the deduction its own NET bullet owes it.
--   * [7]'s payout is priced as window/cooldown, i.e. crit OPPORTUNITIES at
--     attack uptime f.  Uptime is not measured anywhere in this repo; f is
--     carried as a free parameter and the verdict is asserted across a band
--     (f = 1 down to f = 0.25), never at a single assumed value.
--   * The 110s rank-3 cooldown is an EXPLANATION of three frames (KV 120 plus
--     the `special_bonus_scepter` -10 that both buy rows can pay for), not a
--     confirmation that the scepter was owned on them.  Section 6 uses the
--     smaller number, which errs in [8]'s favour -- the safe direction for a
--     "[8] cannot get there" claim.

package.path = 'tests/?.lua;' .. package.path
local api = require('mock.bot_api')

local WK_SRC = 'bots/BotLib/hero_skeleton_king.lua'
local SHAPES = 'tests/mock/special_value_shapes.lua'

local tests = {}

local function read_file(path)
    local fh = assert(io.open(path, 'r'), 'cannot open ' .. path)
    local s = fh:read('*a')
    fh:close()
    return s
end

--- Every per-level entry of a KV "a b c" base string.
local function ladder(sBase)
    local t = {}
    for w in tostring(sBase):gmatch('%S+') do t[#t + 1] = tonumber(w) end
    assert(#t > 0, 'no numeric entries in KV base string ' .. tostring(sBase))
    return t
end

local WK_SHAPES = assert(dofile(SHAPES).SHAPES['skeleton_king'],
    'no skeleton_king block in the KV snapshot')

local function kv(sAbility, sKey)
    local ab = assert(WK_SHAPES[sAbility], 'no KV block for ' .. sAbility)
    return assert(ab[sKey], sAbility .. ' has no key ' .. sKey)
end

local SLOTS = assert(require('mock.talent_slots').SLOTS['skeleton_king'],
    'no skeleton_king rows in tests/mock/talent_slots.lua')

local SRC = read_file(WK_SRC)

--- The MEASURED block, isolated so a number that happens to appear elsewhere in
--- this 900-line file cannot answer for one that is supposed to be in the
--- pricing.  NOTE the doubled parentheses: string.find returns TWO values and as
--- the last argument both would expand, turning sub(start) into sub(start, stop).
local MEASURED = (function()
    local at = (SRC:find('MEASURED, 2026%-08%-30'))
    assert(at, 'the MEASURED block is gone from ' .. WK_SRC
        .. ' -- if the t25 axis was re-decided, this file describes a verdict '
        .. 'that no longer exists and has to be rewritten, not deleted quietly.')
    local tail = SRC:sub(at)
    local stop = (tail:find('modifier_skeleton_king_bone_guard', 1, true))
    return tail:sub(1, stop or #tail)
end)()

--- One recorded reading, pulled out of the source prose by an anchored pattern.
--- Parsing rather than retyping is the whole point: editing the sentence edits
--- the arithmetic below, which is what makes section 5 a guard and not a copy.
local function reading(sPattern, sWhat)
    local v = MEASURED:match(sPattern)
    assert(v, 'the MEASURED block no longer states ' .. sWhat
        .. ' in the form this file parses (' .. sPattern .. '). Either the '
        .. 'measurement was restated -- then update the pattern AND re-check the '
        .. 'verdict -- or it was dropped, and the pricing is unsupported again.')
    return tonumber(v)
end

local TRIGGERS   = reading('gross = ([%d%.]+) triggers', 'the trigger rate per level-25 game')
local WINDOW     = reading('n=49: mean (%d+)s', 'the mean t25 window')
local RING_900   = reading('([%d%.]+) against 1%.250', 'the >=25 mean inside 900')
local RING_600   = reading('1%.900 against ([%d%.]+)', 'the >=25 mean inside 600')
local RING_DELTA = reading('x ([%d%.]+) extra enemies', 'the extra enemies per trigger')
local GROSS_8    = reading('= ([%d%.]+) extra enemies touched', "[8]'s gross per-game figure")
local CD_FRAME   = reading('120 %- 10 = (%d+)', 'the frame-read rank-3 cooldown')
local REACH_25   = reading('25 in 60/96 %((%d+%.%d+)%%%)', 'the share of hero-games reaching 25')

-- ---------------------------------------------------------------------------
-- 1. The KV half of [7].  The rate this row buys is a cooldown edit, so it is
--    the KV that decides how big it is -- not the sentence describing it.

tests['[ratchet] [7] is the Mortal Strike cooldown edit the KV says it is'] = function()
    assert(SLOTS[7] and SLOTS[7].name == 'special_bonus_unique_wraith_king_10',
        't25 slot 7 is ' .. tostring(SLOTS[7] and SLOTS[7].name)
        .. ' in tests/mock/talent_slots.lua, not special_bonus_unique_wraith_king_10 '
        .. '-- the source block prices that name, so either the ladder moved or the '
        .. 'block is pricing a talent this hero no longer has.')
    assert(SLOTS[8] and SLOTS[8].name == 'special_bonus_unique_wraith_king_4',
        't25 slot 8 is ' .. tostring(SLOTS[8] and SLOTS[8].name)
        .. ', recorded special_bonus_unique_wraith_king_4.')

    local base  = ladder(kv('skeleton_king_mortal_strike', 'AbilityCooldown').base)[1]
    local bonus = kv('skeleton_king_mortal_strike', 'AbilityCooldown')
                      .bonus['special_bonus_unique_wraith_king_10']
    assert(bonus, 'the KV no longer routes special_bonus_unique_wraith_king_10 through '
        .. 'skeleton_king_mortal_strike/AbilityCooldown -- [7] is then not a rate edit '
        .. 'at all and the QUANTIZATION bullet is void, not merely stale.')

    local with = base + tonumber(bonus)
    assert(base == 5.0 and with == 3.0,
        'Mortal Strike cooldown is now ' .. base .. ' -> ' .. with
        .. ', and the source block prices 5 -> 3. Re-run the pricing: the whole '
        .. '[7] side is window/cooldown, so both numbers move the verdict.')

    -- The source states the arithmetic; the KV has to agree with the operands.
    assert(MEASURED:find(WINDOW .. '/' .. math.floor(with) .. ' - '
        .. WINDOW .. '/' .. math.floor(base), 1, true),
        'the block computes [7] from operands that are not the KV cooldowns ('
        .. base .. ' and ' .. with .. ') over the measured window (' .. WINDOW .. 's).')
end

-- ---------------------------------------------------------------------------
-- 2. The KV half of the cooldown correction, and the one repo fact that makes
--    the -10 reachable at all.

tests['[ratchet] the 110s rank-3 cooldown is KV 120 plus a scepter this hero buys'] = function()
    local cd = ladder(kv('skeleton_king_reincarnation', 'AbilityCooldown').base)
    assert(#cd == 3, 'Reincarnation now has ' .. #cd .. ' ranks of AbilityCooldown, not 3')
    assert(cd[3] == 120, 'rank-3 Reincarnation cooldown is ' .. cd[3]
        .. ' in the KV, and the correction in the source reads "120 - 10".')

    local scepter = kv('skeleton_king_reincarnation', 'AbilityCooldown')
                        .bonus['special_bonus_scepter']
    assert(scepter and tonumber(scepter) == -10,
        'the scepter bonus on Reincarnation/AbilityCooldown is ' .. tostring(scepter)
        .. ', and correction (4) explains the 109-110 frame reading with exactly -10. '
        .. 'Without it the reading is unexplained again -- say so rather than keeping '
        .. 'the sentence.')
    assert(cd[3] + tonumber(scepter) == CD_FRAME,
        'KV ' .. cd[3] .. ' + scepter ' .. scepter .. ' = ' .. (cd[3] + tonumber(scepter))
        .. ', but the source states ' .. CD_FRAME .. '.')

    -- The explanation only applies to a Wraith King who can hold the scepter.
    local nRows = 0
    for row in SRC:gmatch("sRoleItemsBuyList%['pos_%d'%] = {(.-)\n}") do
        nRows = nRows + 1
        assert(row:find('item_ultimate_scepter', 1, true),
            'a buy row no longer carries item_ultimate_scepter, so correction (4)`s '
            .. 'one-parameter explanation of the 110s reading no longer applies to '
            .. 'this hero. Re-read the frames before quoting 110 anywhere.')
    end
    assert(nRows >= 2, 'expected at least two literal buy rows in ' .. WK_SRC
        .. ', parsed ' .. nRows)
end

-- ---------------------------------------------------------------------------
-- 3. Retraction ratchet.  Four claims were withdrawn; a paste that brings any of
--    them back has to fail here rather than quietly re-hedging the row.

tests['[ratchet] none of the four withdrawn t25 claims is back in the source'] = function()
    local WITHDRAWN = {
        { text = 'no frame in this repo shows a Wraith King at 25',
          why  = 'retired by GH #328: he reaches 25 in 60/96 hero-games (62.5%)' },
        { text = 'the window length is inferred from ONE post-cap game',
          why  = 'retired by GH #328: n=49, mean 208s, min 32s, max 453s' },
        { text = 'is a corpus question\nnobody has asked',
          why  = 'it was asked (GH #328); the answer is 0.408 triggers per level-25 game' },
        { text = 'off a 120s rank-3 cooldown',
          why  = 'the frames read 109-110; KV 120 with the scepter -10 explains it' },
    }
    -- A correction in this repo is written by QUOTING the struck clause, so the
    -- test cannot simply demand absence: it has to tell a quotation from a live
    -- claim.  The rule is that every surviving occurrence sits inside the
    -- MEASURED block and is struck within the same breath.
    local STRUCK = { 'is RETIRED', 'no longer', 'was asked', 'the frames read' }
    local at = (SRC:find('MEASURED, 2026%-08%-30'))

    for _, c in ipairs(WITHDRAWN) do
        local from = 1
        while true do
            local i, j = SRC:find(c.text, from, true)
            if not i then break end
            assert(i > at,
                'a withdrawn t25 claim is back in ' .. WK_SRC .. ', ABOVE the '
                .. 'correction block: "' .. c.text .. '". It was ' .. c.why
                .. '. If new evidence reinstates it, that is a new measurement and it '
                .. 'has to arrive with one -- not as a restored sentence.')
            local nearby = SRC:sub(i, j + 120)
            local struck = false
            for _, m in ipairs(STRUCK) do
                if nearby:find(m, 1, true) then struck = true end
            end
            assert(struck,
                'the withdrawn claim "' .. c.text .. '" appears inside the correction '
                .. 'block without being struck there. A quotation is how this repo '
                .. 'retracts; an unmarked repetition is how a retraction gets undone.')
            from = j + 1
        end
    end
end

-- ---------------------------------------------------------------------------
-- 4. The recorded readings have to be consistent with each other.  This is what
--    catches a half-edit: one number nudged, the ones derived from it left alone.

tests['[ratchet] the recorded t25 readings are internally consistent'] = function()
    -- 30 games with no trigger, 18 with one, 1 with two, over 49 games.
    assert(MEASURED:find('thirty never trigger again after 25', 1, true)
       and MEASURED:find('eighteen trigger once, one twice', 1, true),
        'the trigger histogram (30/18/1 over 49) is no longer stated, and '
        .. TRIGGERS .. ' triggers per game is exactly its mean -- keep them together.')
    local mean = (30 * 0 + 18 * 1 + 1 * 2) / 49
    assert(math.abs(mean - TRIGGERS) < 0.001,
        'the histogram gives ' .. string.format('%.3f', mean) .. ' triggers per game '
        .. 'and the block states ' .. TRIGGERS .. '.')

    assert(math.abs((RING_900 - RING_600) - RING_DELTA) < 1e-9,
        'the ring means (' .. RING_900 .. ' vs ' .. RING_600 .. ') differ by '
        .. (RING_900 - RING_600) .. ', and the block prices ' .. RING_DELTA .. '.')

    assert(math.abs(TRIGGERS * RING_DELTA - GROSS_8) < 0.005,
        TRIGGERS .. ' x ' .. RING_DELTA .. ' = '
        .. string.format('%.3f', TRIGGERS * RING_DELTA)
        .. ', and the block states [8]`s gross as ' .. GROSS_8 .. '.')

    assert(math.abs(60 / 96 * 100 - REACH_25) < 0.05,
        '60/96 is ' .. string.format('%.1f', 60 / 96 * 100) .. '%, stated ' .. REACH_25 .. '%')

    -- The prediction that came back FALSE stays recorded as false.  A round that
    -- deletes it is a round that quietly un-learns something it paid for.
    assert(MEASURED:find('came out FALSE', 1, true)
       and MEASURED:find('0.789', 1, true),
        'the falsified pre-registered outcome (radius advantage "on paper only"; '
        .. 'whole-corpus delta 0.789) is no longer recorded.')
end

-- ---------------------------------------------------------------------------
-- 5. THE SIGN.  Recomputed from the parsed constants, across an uptime band,
--    because attack uptime is not measured anywhere in this repo.

tests['[ratchet] [7] outprices [8] across the whole uptime band'] = function()
    local cdBase = ladder(kv('skeleton_king_mortal_strike', 'AbilityCooldown').base)[1]
    local cdWith = cdBase + tonumber(kv('skeleton_king_mortal_strike', 'AbilityCooldown')
                                        .bonus['special_bonus_unique_wraith_king_10'])

    for _, f in ipairs({ 1.00, 0.50, 0.25 }) do
        local gain7 = f * (WINDOW / cdWith - WINDOW / cdBase)
        local gain8 = TRIGGERS * RING_DELTA            -- GROSS, before the NET deduction
        assert(gain7 > gain8,
            'at attack uptime ' .. f .. ' the recomputed price is [7] '
            .. string.format('%.2f', gain7) .. ' against [8] '
            .. string.format('%.3f', gain8) .. ' (gross). The source block keeps t25 '
            .. 'on [7] on the strength of that inequality, so if it has genuinely '
            .. 'flipped, MOVE THE ROW in tTalentTreeList -- do not leave a block '
            .. 'arguing for the talent the tree does not take.')
    end

    -- Break-even, stated as the trigger rate [8] would need.  Reported here so a
    -- future corpus can be compared against a number instead of a feeling.
    local gain7 = WINDOW / cdWith - WINDOW / cdBase
    local breakeven = gain7 / RING_DELTA
    assert(breakeven > 40 and breakeven < 45,
        'break-even is now ' .. string.format('%.1f', breakeven)
        .. ' triggers per level-25 game; the block states 42.6.')
    assert(breakeven / TRIGGERS > 100,
        'the measured trigger rate is ' .. string.format('%.0f', breakeven / TRIGGERS)
        .. 'x below break-even; the block claims two orders of magnitude.')
end

-- ---------------------------------------------------------------------------
-- 6. THE CEILING.  Stronger than "[8] loses": it cannot get there.  Carries its
--    own expiry, because a corpus that beats the ceiling has found physics this
--    arithmetic does not model.

tests['[ratchet] the t25 window cannot physically hold a break-even trigger rate'] = function()
    local cdBase = ladder(kv('skeleton_king_mortal_strike', 'AbilityCooldown').base)[1]
    local cdWith = cdBase + tonumber(kv('skeleton_king_mortal_strike', 'AbilityCooldown')
                                        .bonus['special_bonus_unique_wraith_king_10'])
    local breakeven = (WINDOW / cdWith - WINDOW / cdBase) / RING_DELTA

    -- One trigger is free at the start of the window; the rest are cooldown-paced.
    local ceilMean = math.floor(WINDOW / CD_FRAME) + 1
    local ceilMax  = math.floor(453 / CD_FRAME) + 1
    assert(ceilMean == 2, 'the mean window (' .. WINDOW .. 's) at a ' .. CD_FRAME
        .. 's cooldown holds at most ' .. ceilMean .. ' triggers; the block states 2.')
    assert(ceilMax == 5, 'the longest window in the corpus (453s) holds at most '
        .. ceilMax .. '; the block states 5.')

    assert(ceilMax < breakeven,
        'the PHYSICAL ceiling on triggers (' .. ceilMax .. ' in the longest window '
        .. 'this corpus has) now reaches break-even (' .. string.format('%.1f', breakeven)
        .. '). That is the one reading that reopens [8], and it means the ceiling '
        .. 'argument in correction (6) has expired -- re-price the row, do not '
        .. 'adjust this bound.')

    assert(TRIGGERS <= ceilMean,
        'the measured trigger rate (' .. TRIGGERS .. ') exceeds what the cooldown '
        .. 'permits in the mean window (' .. ceilMean .. '). Either the cooldown '
        .. 'reading is wrong or the window is -- this file`s arithmetic is not the '
        .. 'thing to fix first.')
end

-- ---------------------------------------------------------------------------
-- 7. The shipped row, driven through the repo's own tier arithmetic.  A block
--    that prices [7] over a tree that takes [8] is the failure this catches.

tests['[ratchet] the shipped t25 row still takes [7], and the block still says so'] = function()
    api.reset_modules()
    api.install({ bot = api.MakeHero('npc_dota_hero_skeleton_king') })
    local J = require(GetScriptDirectory() .. '/FunLib/jmz_func')

    -- The file's own literal, parsed out rather than restated.
    local t25 = assert(SRC:match("%['t25'%]%s*=%s*{%s*(%d+)%s*,%s*%d+%s*}"),
        'cannot parse tTalentTreeList.t25 out of ' .. WK_SRC)
    local t20 = assert(SRC:match("%['t20'%]%s*=%s*{%s*(%d+)%s*,%s*%d+%s*}"),
        'cannot parse tTalentTreeList.t20 out of ' .. WK_SRC)
    local picks = J.Skill.GetTalentBuild({
        t10 = { 10, 0 }, t15 = { 10, 0 },
        t20 = { tonumber(t20), 0 }, t25 = { tonumber(t25), 0 },
    })

    assert(picks[4] == 7,
        'the shipped t25 row now resolves to talent index ' .. picks[4]
        .. ', and the source block argues at length for [7]. Whichever of the two '
        .. 'moved, they have to move together: the argument is the record of why '
        .. 'the row is what it is.')
    assert(MEASURED:find('[8] gross', 1, true) and MEASURED:find('[7] over the same', 1, true),
        'the block no longer prices both halves of the pair, so "keeps [7]" is an '
        .. 'assertion again rather than a comparison.')
end

return tests

-- [hero] [ratchet] Wraith King's t15 pair, priced for the first time, and landed
-- as soak candidate `wkt15stun` rather than as a flip.
--
-- THE GAP THIS FILE CLOSES
-- ------------------------
-- t15 is the LAST UNPRICED TIER IN THE FOCUS FIVE.  Axe, Lion, Zeus and Crystal
-- Maiden all have their t15 pair argued in a file (tests/test_axe_t15_payoff.lua,
-- tests/test_lion_t15_payoff.lua, and tests/test_focus_t15_payoff.lua which holds
-- Zeus's flip and CM's deliberate stand-pat).  This hero's t20 and t25 were
-- priced 2026-08-27 and his t10 on 2026-09-14 -- three rounds that each walked
-- past t15 to reach the tier they came for.  The row has carried an OpenHyperAI
-- snapshot default the whole time.
--
-- WHAT IS PINNED, AND WHY IN THIS ORDER
--   1. the pair itself, PARSED out of tests/mock/talent_slots.lua and
--      tests/mock/special_value_shapes.lua -- never retyped, so a rebalance
--      moves this file's arithmetic instead of leaving it confidently stale.
--   2. the resolution, DRIVEN through the real J.Skill.GetTalentBuild and the
--      real J.Skill.GetSkillList: which talent index the shipped table takes at
--      t15, which one the armed leg takes, and -- the part that bounds the
--      lever -- that EXACTLY TWO slots of the level-up queue move.
--   3. the size, DRIVEN through the same skill list: Wraithfire Blast's rank AT
--      HERO LEVEL 15.  Counting entries of tAllAbilityBuildList answers a
--      different question and is off by one per talent already taken (GH #134).
--   4. the corpus ceiling, as a ONE-WAY TRIPWIRE: no Wraith King frame this repo
--      holds is at or past level 15, so no frame can drive this tier.  The
--      assertion is written to go RED the day one lands, because that is the day
--      this pricing becomes drivable rather than argued.
--   5. the inertness ASYMMETRY.  [3] has no reader anywhere in the hero file;
--      [4] moves GetMaxHealth() and the file reads health ratios constantly.
--      Section 5 asserts BOTH halves, because "this lever is inert" is the
--      sentence a later reader would most like to quote and it is only half true.
--   6. the second instrument wall, handed on rather than settled: on a real
--      Wraith King frame J.Skill.GetTalentList answers an EMPTY list.
--   7. the gate shape (turbo-only, names only its own id, shipped default
--      untouched).
--
-- SCOPE.  Nothing here argues for arming, promoting or retiring `wkt15stun`, and
-- no shipped behaviour changes: the id is gated, unarmed and unpromoted, so every
-- shipped game still takes [4].  Its condition (a) is UNBOUGHT and the request is
-- iterations/queue.json hero-87 (zero EC2).

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')
local skillmap = require('skill_level_map')

local WK_SRC = 'bots/BotLib/hero_skeleton_king.lua'
local SHAPES = 'tests/mock/special_value_shapes.lua'
local FRAME  = 'tests/fixtures/f_260823_002103_wk_ancient_camp_634.lua'

local Q_NAME = 'skeleton_king_hellfire_blast'
local CAND   = 'wkt15stun'

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

--- The hero file's own ability build row, as sAbilityList indices.  Read through
--- the shared reader rather than with a local pattern: a bare `%d+` sweep over
--- the literal's body also eats the row's trailing `--pos1,3` comment and hands
--- back a SEVENTEEN-entry row, which silently levels Wraithfire Blast a fifth
--- time and moves every talent slot in section 2.  (Driven out the first time
--- this file ran; the ladder in section 3 is what caught it.)
local function build_row()
    local row = skillmap.build_row(SRC, 1, 'tAllAbilityBuildList')
    assert(#row == 15, 'tAllAbilityBuildList row is ' .. #row
        .. ' entries, not 15; every queue-slot index below is computed off 15 '
        .. 'abilities + 8 talents = 23.')
    return row
end

--- The hero file's own tTalentTreeList literal.
local function talent_tiers()
    local body = assert(SRC:match('local tTalentTreeList = {(.-)\n}'),
        WK_SRC .. ' has no tTalentTreeList literal')
    local t = {}
    for tier, a, b in body:gmatch("%['(t%d+)'%]%s*=%s*{%s*(%d+)%s*,%s*(%d+)%s*}") do
        t[tier] = { tonumber(a), tonumber(b) }
    end
    for _, tier in ipairs({ 't10', 't15', 't20', 't25' }) do
        assert(t[tier], 'tTalentTreeList has no ' .. tier .. ' row')
    end
    return t
end

--- The rewrite the gate performs, PARSED out of its own body rather than
--- retyped: if somebody edits the gate to write a different pair, every reading
--- below moves with it instead of describing a lever that no longer exists.
---
--- ⚠️ EVERY assignment in the gate BODY is applied, not just the t15 one, and
--- that is the whole difference between this reader and the one it replaced.
--- The first version pulled the t15 pair out with a single pattern and left the
--- other three tiers at their shipped values -- so a lever that ALSO rewrote t20
--- was invisible to it, and section 2's "exactly two queue slots move" bound
--- passed on a lever that moved four.  Mutant M6 of
--- tools/agent/mutstand_wkt15stun.sh SURVIVED against that reader; it is the
--- reason this one walks the body.
local function armed_tiers()
    local sBody = SRC:match("IsSoakCandidate%(%s*'" .. CAND .. "'%s*%)[^\n]*then\n(.-)\nend")
    assert(sBody, 'the ' .. CAND .. ' gate no longer has a body this file can '
        .. 'parse.  Either the lever moved -- then re-read every number below -- '
        .. 'or it is gone and this file describes nothing.')

    local t, nWrites = talent_tiers(), 0
    for tier, a, b in sBody:gmatch("tTalentTreeList%['(t%d+)'%]%s*=%s*{%s*(%d+)%s*,%s*(%d+)%s*}") do
        t[tier] = { tonumber(a), tonumber(b) }
        nWrites = nWrites + 1
    end
    assert(nWrites > 0, 'the ' .. CAND .. ' gate body no longer rewrites '
        .. 'tTalentTreeList at all, so the lever writes nothing.')
    assert(t.t15 ~= nil, 'tTalentTreeList has no t15 row after the gate body ran')
    return t, nWrites
end

--- One drive of the real skill-list machinery.  `sTalentList` is supplied from
--- the KV snapshot on purpose: section 6 shows that neither the mock world nor
--- any fixture can produce it, so a drive that took it from the bot would be
--- driving eight nils and asserting nothing.
local function drive(tTiers)
    local J, bot = rf.load(FRAME)
    local sAbilityList = J.Skill.GetAbilityList(bot)
    local sTalentList = {}
    for i = 1, 8 do sTalentList[i] = assert(SLOTS[i], 'no KV row at talent index ' .. i).name end
    local nTalentBuild = J.Skill.GetTalentBuild(tTiers)
    local sSkillList = J.Skill.GetSkillList(sAbilityList, build_row(), sTalentList, nTalentBuild)
    return sSkillList, nTalentBuild, sAbilityList, J, bot
end

-- ---------------------------------------------------------------------------
-- 1. The pair.  Both halves come off the generated KV snapshot; the one number
--    the price runs on (+0.75) is read out of the bonus table keyed by the row's
--    own name, so a row rename cannot leave the bonus silently attached.

tests['[ratchet] the t15 pair is +300 health against +0.75s of Wraithfire Blast stun'] = function()
    assert(SLOTS[3] and SLOTS[3].name == 'special_bonus_unique_wraith_king_11',
        'talent index 3 is ' .. tostring(SLOTS[3] and SLOTS[3].name)
        .. ' in tests/mock/talent_slots.lua, not special_bonus_unique_wraith_king_11. '
        .. 'The t15 pair moved; re-price it rather than editing this line.')
    assert(SLOTS[4] and SLOTS[4].name == 'special_bonus_hp_300',
        'talent index 4 is ' .. tostring(SLOTS[4] and SLOTS[4].name)
        .. ', not special_bonus_hp_300 -- same consequence as above.')

    local bFound = false
    for _, sMod in ipairs(SLOTS[3].mods or {}) do
        if sMod:find('blast_stun_duration', 1, true) then bFound = true end
    end
    assert(bFound, 'the KV row for [3] no longer lists a blast_stun_duration edit, '
        .. 'so "half again as much lockdown" is unsupported.')

    local stun = kv(Q_NAME, 'blast_stun_duration')
    local tBase = ladder(stun.base)
    assert(#tBase == 4, 'blast_stun_duration now has ' .. #tBase
        .. ' ranks, not 4; the per-rank arithmetic below is written for four.')
    assert(tBase[1] == 1.0 and tBase[2] == 1.2 and tBase[3] == 1.4 and tBase[4] == 1.6,
        'the stun ladder is now ' .. stun.base .. ' -- the source block quotes '
        .. '1.0/1.2/1.4/1.6 and its percentages are computed off those.')

    local sBonus = assert(stun.bonus and stun.bonus[SLOTS[3].name],
        'the KV no longer attaches a blast_stun_duration bonus to ' .. SLOTS[3].name
        .. ', so [3] may no longer be the stun row at all.')
    assert(tonumber(sBonus:match('([%d%.]+)')) == 0.75,
        'the stun talent is worth ' .. sBonus .. ' now, not +0.75; every percentage '
        .. 'in the source block is computed off 0.75.')

    -- [4] is a generic row: the KV snapshot carries no per-ability mods for it,
    -- which is itself the reason it has no decision-layer contact by NAME.
    assert(#(SLOTS[4].mods or {}) == 0,
        'special_bonus_hp_300 now carries per-ability mods (' .. #(SLOTS[4].mods)
        .. '); section 5 argues its inertness from the absence of them.')
end

-- ---------------------------------------------------------------------------
-- 2. The resolution, driven.  The interesting assertion is not "slot 15 moved"
--    but that exactly TWO slots move: t15's two rows swap places in the queue and
--    nothing else in the build is touched.  That bound is what lets a wave read
--    be about a talent rather than about a build.

tests['[ratchet] shipped t15 takes [4]; armed takes [3]; exactly two queue slots move'] = function()
    local tShipped = talent_tiers()
    assert(tShipped.t15[1] == 10 and tShipped.t15[2] == 0,
        'the SHIPPED t15 literal is now {' .. tShipped.t15[1] .. ', ' .. tShipped.t15[2]
        .. '}.  A soak candidate may not change gate-off behaviour: if the default '
        .. 'row was flipped, this lever is no longer dark and has to be re-argued.')

    local tArmed, nWrites = armed_tiers()
    assert(tArmed.t15[1] == 0 and tArmed.t15[2] == 10,
        'the armed leg now writes {' .. tArmed.t15[1] .. ', ' .. tArmed.t15[2] .. '}')

    local shipped, buildShipped = drive(tShipped)
    local armed, buildArmed = drive(tArmed)

    assert(buildShipped[2] == 4 and buildShipped[6] == 3,
        'the shipped table resolves t15 to talent index ' .. tostring(buildShipped[2])
        .. ' (expected 4).  aba_skill.lua:139/143 is the selector; if it changed, '
        .. 'every t15 pricing in this repo has to be re-read, not just this one.')
    assert(buildArmed[2] == 3 and buildArmed[6] == 4,
        'the armed table resolves t15 to talent index ' .. tostring(buildArmed[2])
        .. ' (expected 3)')

    local moved, nSeen = {}, 0
    for i = 1, math.max(#shipped, #armed) do
        nSeen = nSeen + 1
        if shipped[i] ~= armed[i] then moved[#moved + 1] = i end
    end
    assert(nSeen >= 23, 'the driven skill list came back ' .. nSeen
        .. ' slots long; a Wraith King queue is 15 abilities + 8 talents = 23. '
        .. 'A short list would make the "exactly two" count vacuous.')
    assert(#moved == 2, 'arming ' .. CAND .. ' moves ' .. #moved
        .. ' queue slots, not 2.  The lever is supposed to swap the two sides of ONE '
        .. 'tier; anything else means it is changing the build as well as the talent '
        .. 'and a wave read could not be attributed to the talent.')
    assert(moved[1] == 15 and moved[2] == 21,
        'the moved slots are ' .. moved[1] .. ' and ' .. moved[2]
        .. ', not 15 and 21.  Slot 15 IS hero level 15 -- that coincidence is what '
        .. 'makes this tier legible -- and 21 is where GetSkillList parks the other '
        .. 'side of the tier once the ability entries run out.')

    assert(nWrites == 1, 'the ' .. CAND .. ' gate body rewrites ' .. nWrites
        .. ' tiers.  One id, one tier: a second rewrite in the same body would '
        .. 'ride this lever into a wave under its name and could not be separated '
        .. 'from it afterwards.')

    assert(shipped[15] == SLOTS[4].name and armed[15] == SLOTS[3].name,
        'hero level 15 takes ' .. tostring(shipped[15]) .. ' shipped and '
        .. tostring(armed[15]) .. ' armed; expected ' .. SLOTS[4].name .. ' then '
        .. SLOTS[3].name)
end

-- ---------------------------------------------------------------------------
-- 3. The size.  A t15 talent is chosen at hero level 15 and at no other moment,
--    so its size is conditional on the rank Q holds THERE.

tests['[ratchet] Q holds rank 3 at hero level 15, so the talent is +53.6% of the stun'] = function()
    local shipped, _, sAbilityList = drive(talent_tiers())

    local sQ = assert(sAbilityList[1], 'the frame gave no sAbilityList[1]')
    assert(sQ == Q_NAME, 'sAbilityList slot 1 on this frame is ' .. tostring(sQ)
        .. ', not ' .. Q_NAME .. '.  The rank ladder below counts occurrences of '
        .. 'slot 1 and calls them Wraithfire Blast.')

    local tAt, nSeen = {}, 0
    for i = 1, #shipped do
        if shipped[i] == Q_NAME then
            nSeen = nSeen + 1
            tAt[nSeen] = i
        end
    end
    -- Liveness: an empty loop asserts nothing (the M10 lesson of
    -- tests/test_wk_save_mana_unreachable_cap.lua section 6.1).
    assert(nSeen == 4, 'the driven queue levels Wraithfire Blast ' .. nSeen
        .. ' times, not 4 -- the ladder below would be reading a truncated list.')
    assert(tAt[1] == 2 and tAt[2] == 13 and tAt[3] == 14 and tAt[4] == 16,
        'the Q ladder is now r1@' .. tAt[1] .. ' r2@' .. tAt[2] .. ' r3@' .. tAt[3]
        .. ' r4@' .. tAt[4] .. '; the source block prices this talent at rank 3 '
        .. 'because rank 3 lands at hero level 14 and rank 4 only at 16.')

    local nRankAt15 = 0
    for _, nLevel in ipairs(tAt) do if nLevel <= 15 then nRankAt15 = nRankAt15 + 1 end end
    assert(nRankAt15 == 3, 'Q holds rank ' .. nRankAt15 .. ' at hero level 15')

    local tStun = ladder(kv(Q_NAME, 'blast_stun_duration').base)
    local nGain = tonumber((kv(Q_NAME, 'blast_stun_duration').bonus[SLOTS[3].name]):match('([%d%.]+)'))

    local function pct(nRank)
        return math.floor((nGain / tStun[nRank]) * 1000 + 0.5) / 10
    end
    local sBlock = assert(SRC:match('THE t15 PRICE.-\n%-%-%- ⛔ THE GATE NAMES ONLY ITS OWN ID'),
        'the t15 pricing block is gone from ' .. WK_SRC
        .. ' -- this file is the record of a decision that block states.')
    assert(sBlock:find(tostring(pct(3)) .. '%', 1, true),
        'the block no longer quotes ' .. pct(3) .. '% for hero 15 (rank 3: '
        .. tStun[3] .. ' -> ' .. (tStun[3] + nGain) .. 's)')
    assert(sBlock:find(tostring(pct(4)) .. '%', 1, true),
        'the block no longer quotes ' .. pct(4) .. '% for hero 16+ (rank 4: '
        .. tStun[4] .. ' -> ' .. (tStun[4] + nGain) .. 's)')

    -- The claim the whole candidacy rests on: this is the hero's only stun.
    local nStunners = 0
    for sAbility, tKeys in pairs(WK_SHAPES) do
        for sKey in pairs(tKeys) do
            if sKey:find('stun_duration', 1, true) then nStunners = nStunners + 1 break end
        end
        if sAbility == nil then break end
    end
    assert(nStunners == 1, 'the KV snapshot now shows ' .. nStunners
        .. ' Wraith King abilities with a stun_duration key.  "The only lockdown" is '
        .. 'the reason a lockdown talent is a candidate at all; if a second one '
        .. 'appeared, re-price.')
end

-- ---------------------------------------------------------------------------
-- 4. The corpus ceiling, as a one-way tripwire.  This is written to FAIL the day
--    a level-15 Wraith King frame lands, because that is the day the tier stops
--    being argued-only.  ⚠️ The ceiling is a fact about the ARCHIVE (cut under
--    the 10-minute economy cap), not about turbo -- GH #108 removed the cap and
--    GH #235's first post-cap frame has this hero at level 26.

tests['[corpus] no Wraith King frame in this repo is at or past level 15'] = function()
    local ok, tFiles = pcall(function()
        local names, ph = {}, io.popen('ls tests/fixtures/*.lua 2>/dev/null')
        if ph == nil then return nil end
        for line in ph:lines() do names[#names + 1] = line end
        ph:close()
        return names
    end)
    assert(ok and tFiles ~= nil and #tFiles > 0, 'could not enumerate tests/fixtures')

    local nRows, nHigh, sHighAt = 0, 0, nil
    for _, path in ipairs(tFiles) do
        local src = read_file(path)
        for sTail in src:gmatch("name = 'npc_dota_hero_skeleton_king'([^\n]*)") do
            nRows = nRows + 1
            local nLevel = tonumber(sTail:match('level = (%d+)') or '')
            if nLevel ~= nil and nLevel > nHigh then nHigh, sHighAt = nLevel, path end
        end
    end

    assert(nRows >= 37, 'the archive holds ' .. nRows .. ' Wraith King hero rows; '
        .. 'this reading was taken at 37 and is asserted as a LOWER bound (GH #106: '
        .. 'a corpus equality is a landmine for whoever adds the next fixture). '
        .. 'Fewer means fixtures were REMOVED -- find out which before quoting any '
        .. 'count in this file.')
    assert(nHigh > 0, 'no Wraith King row in the archive carries a level field')
    assert(nHigh < 15, 'a Wraith King frame at level ' .. nHigh .. ' has landed ('
        .. tostring(sHighAt) .. ').  THIS IS GOOD NEWS, not a regression: the t15 '
        .. 'tier is now drivable on a real frame for the first time.  Re-take the '
        .. 'pricing in bots/BotLib/hero_skeleton_king.lua on that frame and rewrite '
        .. 'this section into the assertion it was standing in for.')
end

-- ---------------------------------------------------------------------------
-- 5. The inertness ASYMMETRY.  Both halves are asserted, because "this lever is
--    inert" is the half a later reader would quote and it is only half true.

tests['[ratchet] [3] has no reader in the hero file; [4] moves a pool the file reads'] = function()
    local nStunReads = 0
    for _ in SRC:gmatch('blast_stun_duration') do nStunReads = nStunReads + 1 end
    -- The name appears in the pricing prose this round added; what must stay at
    -- zero is a READ -- a GetSpecialValue* call naming it.
    local nStunCalls = 0
    for _ in SRC:gmatch("GetSpecialValue%a+%(%s*'blast_stun_duration'") do
        nStunCalls = nStunCalls + 1
    end
    assert(nStunCalls == 0, 'bots/BotLib/hero_skeleton_king.lua now reads '
        .. 'blast_stun_duration ' .. nStunCalls .. ' time(s).  The t15 block claims '
        .. '[3] is inert to the decision layer; with a reader that claim is false '
        .. 'and the lever acquires the t10 pair\'s coupling hazard (GH #228).')
    assert(nStunReads > 0, 'the name blast_stun_duration is gone from the file '
        .. 'entirely, so the pricing prose no longer names what it prices.')

    local nHealthReads = 0
    for _ in SRC:gmatch('Get[MH]%a*Health%(') do nHealthReads = nHealthReads + 1 end
    assert(nHealthReads > 0, 'the hero file reads no health at all now.  The block '
        .. 'registers [4] as NOT inert precisely because health readings are '
        .. 'everywhere; with zero of them the asymmetry it warns about is gone and '
        .. 'the warning should be withdrawn rather than left standing.')
end

-- ---------------------------------------------------------------------------
-- 6. The second instrument wall, DRIVEN and handed on.  A real frame's talent
--    list is EMPTY, so the queue's talent slots are nil on every fixture.  This
--    is direct evidence for the surviving "the stuck queue entry is not a failing
--    head, it is nil" hypothesis left open by
--    iterations/reports/hero/20260914T225854Z.md; it is not this lever's to settle.

tests['[ratchet] a real Wraith King frame yields an EMPTY talent list'] = function()
    local J, bot = rf.load(FRAME)
    local sTalentList = J.Skill.GetTalentList(bot)
    assert(type(sTalentList) == 'table', 'GetTalentList did not answer a table')
    assert(#sTalentList == 0, 'the frame now yields ' .. #sTalentList .. ' talent '
        .. 'name(s).  The dumper learned to record talents, which means (a) this '
        .. 'section is obsolete and (b) the nil-queue-entry hypothesis GH #822 is '
        .. 'chasing can finally be tested on a frame.')

    -- ... and the consequence, driven rather than reasoned about: fed that empty
    -- list, the real GetSkillList parks nil at every talent slot.
    local sAbilityList = J.Skill.GetAbilityList(bot)
    local sSkillList = J.Skill.GetSkillList(sAbilityList, build_row(), sTalentList,
        J.Skill.GetTalentBuild(talent_tiers()))
    local nNil, nChecked = 0, 0
    for _, i in ipairs({ 10, 15, 18, 19, 20, 21, 22, 23 }) do
        nChecked = nChecked + 1
        if sSkillList[i] == nil then nNil = nNil + 1 end
    end
    assert(nChecked == 8, 'the talent-slot list under test is ' .. nChecked .. ' long')
    assert(nNil == 8, 'only ' .. nNil .. ' of the 8 talent slots are nil on a real '
        .. 'frame; section 2 supplies the talent names from the KV snapshot BECAUSE '
        .. 'the frame cannot, and that reason would no longer hold.')
end

-- ---------------------------------------------------------------------------
-- 7. The gate shape.  Turbo-only, one id, its own -- the pullcad trap (AGENTS.md)
--    written as a test rather than as a promise in a comment.

tests['[ratchet] the wkt15stun gate is turbo-only and names only its own id'] = function()
    local nSites = 0
    for _ in SRC:gmatch("IsSoakCandidate%(%s*'" .. CAND .. "'%s*%)") do nSites = nSites + 1 end
    assert(nSites == 1, 'the file holds ' .. nSites .. ' call sites for ' .. CAND
        .. '; a soak candidate with two of them cannot be reasoned about as one lever.')

    local sLine = assert(SRC:match("[^\n]*IsSoakCandidate%(%s*'" .. CAND .. "'%s*%)[^\n]*"),
        'could not isolate the gate line')
    assert(sLine:find('IsModeTurbo', 1, true),
        'the ' .. CAND .. ' gate is no longer turbo-only: ' .. sLine)

    local nOther = 0
    for sId in sLine:gmatch("IsSoakCandidate%(%s*'(%w+)'%s*%)") do
        if sId ~= CAND then nOther = nOther + 1 end
    end
    assert(nOther == 0, 'the ' .. CAND .. ' gate names ' .. nOther .. ' other candidate '
        .. 'id(s) in its own condition.  That is the pullcad trap: the day the other '
        .. 'id is promoted this gate freezes FALSE and check_armed_wiring.py still '
        .. 'calls it WIRED.')

    -- And the neighbour stays a neighbour: wkt10ls must not name this id either.
    local sOther = assert(SRC:match("[^\n]*IsSoakCandidate%(%s*'wkt10ls'%s*%)[^\n]*"),
        "the wkt10ls gate is gone; if t10 was promoted or retired, re-read this "
        .. "file's coupling paragraph.")
    assert(not sOther:find(CAND, 1, true),
        'the wkt10ls gate now names ' .. CAND .. ' -- same trap, other direction.')
end

return tests
